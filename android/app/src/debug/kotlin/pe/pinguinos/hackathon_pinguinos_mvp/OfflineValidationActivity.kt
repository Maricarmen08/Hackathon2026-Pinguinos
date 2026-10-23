package pe.pinguinos.hackathon_pinguinos_mvp

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Debug
import android.os.Process
import android.os.SystemClock
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.widget.TextView
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import org.json.JSONObject
import org.json.JSONArray
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors

/** Debug-only, shell/DUMP protected. No backend, credentials, proposal or financial APIs. */
class OfflineValidationActivity : Activity() {
    private val worker = Executors.newSingleThreadExecutor()
    private var busy = false
    private var reader: com.google.mlkit.vision.text.TextRecognizer? = null
    private var speech: OfflineSpeech? = null
    override fun onCreate(state: Bundle?) { super.onCreate(state); run(intent) }
    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); run(intent) }

    private fun run(request: Intent) {
        if (busy) return
        busy = true
        setContentView(TextView(this).apply { text = "Comprobación local aislada. No crea propuestas ni operaciones." })
        val root = File(filesDir, "offline_validation").apply { mkdirs() }
        val name = request.getStringExtra("input") ?: ""
        val mode = request.getStringExtra("mode") ?: ""
        val file = File(root, name)
        val started = SystemClock.elapsedRealtime()
        val cpu = Process.getElapsedCpuTime()
        val before = Debug.getPss()
        fun report(text: String?, error: String? = null, peak: Long = Debug.getPss(),
                   ocrLines: JSONArray? = null, width: Int? = null, height: Int? = null) {
            val result = JSONObject().put("input", name).put("mode", mode)
                .put("run_id", request.getStringExtra("run_id") ?: "")
                .put("airplane_mode", Settings.Global.getInt(contentResolver, Settings.Global.AIRPLANE_MODE_ON, -1))
                .put("text", text ?: JSONObject.NULL).put("error", error ?: JSONObject.NULL)
                .put("elapsed_ms", SystemClock.elapsedRealtime() - started)
                .put("cpu_ms", Process.getElapsedCpuTime() - cpu)
                .put("pss_before_kb", before).put("pss_loaded_kb", peak)
            if (ocrLines != null) result.put("lines", ocrLines).put("width", width).put("height", height)
            File(root, "result.json.tmp").writeText(result.toString())
            File(root, "result.json.tmp").renameTo(File(root, "result.json"))
            busy = false
            (findViewById<android.view.View>(android.R.id.content) as android.view.ViewGroup)
                .getChildAt(0)?.let { (it as TextView).text = result.toString(2) }
        }
        if (mode == "session") {
            try {
                for (seconds in listOf(3, 5, 10, 45)) {
                    val pcm = PcmRecording()
                    val block = ShortArray(1600)
                    repeat(seconds * 10) { index ->
                        block.indices.forEach { block[it] = ((index * 1600 + it) % 32000).toShort() }
                        pcm.append(block, block.size)
                    }
                    check(pcm.count == seconds * 16000)
                    var accepted = 0; var segment = 0
                    val result = decodePcm(pcm.samples, pcm.count, object : PcmDecoder {
                        override fun accept(chunk: ShortArray, count: Int): Boolean {
                            repeat(count) { check(chunk[it] == ((accepted + it) % 32000).toShort()) }
                            accepted += count
                            return accepted % 9600 == 0 // Many phrase endpoints must not end session.
                        }
                        override fun segment() = "segment${++segment}"
                        override fun tail() = "tail"
                    })
                    check(accepted == pcm.count && result.samples == pcm.count && result.text.endsWith("tail"))
                    check(result.segments == segment + 1)
                    if (seconds == 45) check(pcm.full)
                    var cancelled = false
                    try { decodePcm(pcm.samples, pcm.count, object : PcmDecoder {
                        override fun accept(chunk: ShortArray, count: Int) = error("Must not decode cancelled input")
                        override fun segment() = ""
                        override fun tail() = ""
                    }) { true } } catch (_: InterruptedException) { cancelled = true }
                    check(cancelled)
                }
                report("CORE_OK: 3/5/10/45s; all samples, endpoints, tail, cancellation")
            } catch (e: Exception) { report(null, "CORE_FAILED:${e.javaClass.simpleName}") }
            return
        }
        if (mode == "mic") {
            val seconds = request.getIntExtra("seconds", 3)
            if (seconds !in listOf(3, 5, 10, 45)) { report(null, "INVALID_DURATION"); return }
            val cancel = request.getBooleanExtra("cancel", false)
            val handler = Handler(Looper.getMainLooper())
            val local = OfflineSpeech(applicationContext)
            speech = local
            var captured = 0; var decoded = 0; var completed = false
            local.prepare { ok ->
                if (!ok) { local.close(); report(null, "PREPARE_FAILED") }
                else local.listen({
                    handler.postDelayed({
                        if (cancel) {
                            local.cancel()
                            handler.postDelayed({
                                if (!isDestroyed) report("CANCELLED: no final=${!completed}", if (completed) "UNEXPECTED_FINAL" else null)
                                local.close(); speech = null
                            }, 400)
                        } else if (seconds < 45) local.stop() // 45s exercises native hard limit.
                    }, seconds * 1000L)
                }, {}, { _, error ->
                    completed = true
                    val expected = if (seconds == 45) 45 * 16000 else seconds * 16000
                    val valid = captured == decoded && captured >= expected - 3200 && captured <= expected + 20000
                    report("MIC_${seconds}s captured=$captured decoded=$decoded; speech_error=${error ?: "none"}",
                        if (error != null && error != "NO_SPEECH") error else if (!valid) "FRAME_COUNT_MISMATCH" else null)
                    local.close(); speech = null
                }, { a, b -> captured = a; decoded = b })
            }
            return
        }
        if (!Regex("[a-z0-9_.-]{1,80}").matches(name) || file.canonicalFile.parentFile != root.canonicalFile ||
            !file.isFile || file.length() > 8 * 1024 * 1024) {
            report(null, "INVALID_FIXTURE"); return
        }
        if (mode == "ocr") {
            try {
                val client = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                reader = client
                val input = InputImage.fromFilePath(this, Uri.fromFile(file))
                client.process(input)
                    .addOnSuccessListener { result ->
                        val lines = JSONArray()
                        for (block in result.textBlocks) for (line in block.lines) {
                            val box = line.boundingBox ?: continue
                            lines.put(JSONObject().put("text", line.text).put("left", box.left)
                                .put("top", box.top).put("right", box.right).put("bottom", box.bottom)
                                .put("angle", line.angle))
                        }
                        if (!isDestroyed) report(result.text, ocrLines = lines, width = input.width, height = input.height)
                    }
                    .addOnFailureListener { if (!isDestroyed) report(null, "OCR_ERROR") }
                    .addOnCompleteListener { client.close(); reader = null }
            } catch (_: Exception) { reader?.close(); reader = null; report(null, "OCR_ERROR") }
        } else if (mode == "audio") {
            worker.execute {
                var text: String? = null; var error: String? = null; var peak = before
                try {
                    Model(VoskModelStore(this).ensure().absolutePath).use { model ->
                        Recognizer(model, 16000f).use { decoder ->
                            peak = Debug.getPss()
                            file.inputStream().use { input ->
                                val header = ByteArray(44)
                                if (input.read(header) != 44) throw IllegalArgumentException()
                                val h = ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN)
                                if (String(header, 0, 4) != "RIFF" || String(header, 8, 4) != "WAVE" ||
                                    h.getShort(20).toInt() != 1 || h.getShort(22).toInt() != 1 ||
                                    h.getInt(24) != 16000 || h.getShort(34).toInt() != 16 ||
                                    String(header, 36, 4) != "data") throw IllegalArgumentException()
                                val segments = mutableListOf<String>()
                                val buffer = ByteArray(6400)
                                while (true) {
                                    val n = input.read(buffer); if (n < 0) break
                                    if (decoder.acceptWaveForm(buffer, n)) segments.add(JSONObject(decoder.result).optString("text"))
                                }
                                segments.add(JSONObject(decoder.finalResult).optString("text"))
                                text = segments.filter { it.isNotBlank() }.joinToString(" ")
                            }
                        }
                    }
                } catch (_: Exception) { error = "AUDIO_ERROR" } catch (_: LinkageError) { error = "NATIVE_ABI_ERROR" }
                runOnUiThread { if (!isDestroyed) report(text, error, peak) }
            }
        } else report(null, "INVALID_MODE")
    }
    override fun onDestroy() { speech?.close(); reader?.close(); worker.shutdown(); super.onDestroy() }
}
