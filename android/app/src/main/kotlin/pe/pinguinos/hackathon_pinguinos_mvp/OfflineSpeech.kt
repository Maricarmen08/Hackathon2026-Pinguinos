package pe.pinguinos.hackathon_pinguinos_mvp

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import org.vosk.Model
import org.vosk.Recognizer
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/** All model/decoder work is serial and off the UI thread. No network code. */
class OfflineSpeech(private val context: Context) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val generation = AtomicInteger()
    private var model: Model? = null // accessed only on worker
    @Volatile private var audio: AudioRecord? = null
    @Volatile private var stopping = false
    @Volatile private var cancelled = false
    @Volatile private var closed = false

    fun bundled() = VoskModelStore(context).bundled()

    fun prepare(done: (Boolean) -> Unit) {
        val token = generation.get()
        worker.execute {
            var ok = false
            try {
                model?.close(); model = null
                model = Model(VoskModelStore(context).ensure().absolutePath)
                ok = true
            } catch (_: Exception) { } catch (_: LinkageError) { }
            if (closed || token != generation.get()) {
                model?.close(); model = null
                main.post { done(false) }
            } else {
                val ready = ok
                main.post { done(ready) }
            }
        }
    }

    @SuppressLint("MissingPermission")
    fun listen(ready: () -> Unit, processing: () -> Unit, done: (String?, String?) -> Unit,
               diagnostics: (Int, Int) -> Unit = { _, _ -> }) {
        stopping = false; cancelled = false
        val token = generation.get()
        worker.execute {
            var recognizer: Recognizer? = null
            var result: String? = null
            var error: String? = null
            try {
                if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                    throw SecurityException()
                }
                val loaded = model ?: throw CaptureFailure("OFFLINE_MODEL_UNAVAILABLE")
                val minimum = AudioRecord.getMinBufferSize(16000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
                if (minimum <= 0) throw CaptureFailure("MIC_UNAVAILABLE")
                val recorder = AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, 16000,
                    AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, maxOf(minimum, 32000))
                audio = recorder
                if (recorder.state != AudioRecord.STATE_INITIALIZED) throw CaptureFailure("MIC_UNAVAILABLE")
                if (recorder.sampleRate != PcmRecording.RATE || recorder.channelCount != 1 ||
                    recorder.audioFormat != AudioFormat.ENCODING_PCM_16BIT) throw CaptureFailure("MIC_FORMAT_UNSUPPORTED")
                if (cancelled || closed || token != generation.get()) throw InterruptedException()
                recorder.startRecording()
                if (recorder.recordingState != AudioRecord.RECORDSTATE_RECORDING) throw CaptureFailure("MIC_BUSY")
                val started = SystemClock.elapsedRealtime()
                val pcm = PcmRecording()
                val buffer = ShortArray(1600)
                var readySent = false
                // Capture independently of decoder CPU speed. No VAD/silence endpoint here.
                while (!stopping && !closed && token == generation.get() &&
                    !pcm.full && SystemClock.elapsedRealtime() - started < 45000) {
                    val n = recorder.read(buffer, 0, minOf(buffer.size, pcm.samples.size - pcm.count))
                    if (n < 0) throw CaptureFailure(if (n == AudioRecord.ERROR_DEAD_OBJECT) "MIC_DISCONNECTED" else "MIC_READ_ERROR")
                    if (n == 0) {
                        if (recorder.recordingState != AudioRecord.RECORDSTATE_RECORDING) throw CaptureFailure("MIC_READ_ERROR")
                        continue
                    }
                    pcm.append(buffer, n)
                    if (!readySent) {
                        readySent = true
                        main.post { if (!closed && token == generation.get()) ready() }
                    }
                    if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) throw SecurityException()
                }
                if (cancelled || closed || token != generation.get()) throw InterruptedException()
                // Drain already captured frames before stopping; bounded to internal buffer.
                if (stopping) {
                    var remaining = 16000
                    while (!pcm.full && remaining > 0) {
                        val n = recorder.read(buffer, 0, minOf(buffer.size, pcm.samples.size - pcm.count, remaining), AudioRecord.READ_NON_BLOCKING)
                        if (n <= 0) break
                        pcm.append(buffer, n); remaining -= n
                    }
                }
                recorder.stop(); recorder.release(); audio = null
                main.post { if (!closed && token == generation.get()) processing() }
                normalizePcm(pcm.samples, pcm.count)
                val decoder = Recognizer(loaded, PcmRecording.RATE.toFloat())
                recognizer = decoder
                val decoded = decodePcm(pcm.samples, pcm.count, VoskPcmDecoder(decoder)) {
                    cancelled || closed || token != generation.get()
                }
                Log.i("FinkiSpeech", "PCM16 mono 16000Hz captured=${pcm.count} decoded=${decoded.samples} segments=${decoded.segments} stop=${if (stopping) "manual" else "limit"}")
                main.post { if (!closed && token == generation.get()) diagnostics(pcm.count, decoded.samples) }
                result = decoded.text
                if (result.isNullOrEmpty()) error = "NO_SPEECH"
            } catch (_: SecurityException) { error = "PERMISSION_REQUIRED" }
              catch (_: InterruptedException) { error = "CANCELLED" }
              catch (e: CaptureFailure) { error = e.code }
              catch (_: Exception) { error = if (cancelled) "CANCELLED" else "OFFLINE_SPEECH_ERROR" }
              catch (_: LinkageError) { error = "OFFLINE_SPEECH_ERROR" }
            finally {
                try { audio?.stop() } catch (_: Exception) { }
                try { audio?.release() } catch (_: Exception) { }; audio = null
                recognizer?.close()
                model?.close(); model = null
            }
            val finalText = result; val finalError = error
            main.post { if (!closed && token == generation.get()) done(finalText, finalError) }
        }
    }

    fun stop() {
        stopping = true
    }
    fun cancel() {
        generation.incrementAndGet()
        cancelled = true
        stop()
        try { audio?.stop() } catch (_: Exception) { }
        if (!worker.isShutdown) worker.execute { model?.close(); model = null }
    }
    fun close() { closed = true; cancel(); worker.shutdown() }
    private class CaptureFailure(val code: String) : Exception()
}
