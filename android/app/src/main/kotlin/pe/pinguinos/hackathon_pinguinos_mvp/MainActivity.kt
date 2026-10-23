package pe.pinguinos.hackathon_pinguinos_mvp

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var speechChannel: MethodChannel
    private var speech: SpeechRecognizer? = null
    private var pending: MethodChannel.Result? = null
    private var language = "es-PE"
    private val audioPermissionCode = 7412
    private val handler = Handler(Looper.getMainLooper())
    private var cancelProbe: (() -> Unit)? = null
    private val offlineDelegate = lazy { OfflineSpeech(applicationContext) }
    private val offline by offlineDelegate
    private var engine = "native"
    private var preparing = false

    private fun onDevice(): Boolean = Build.VERSION.SDK_INT >= 31 &&
        SpeechRecognizer.isOnDeviceRecognitionAvailable(this)

    private fun speechIntent() = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
        putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
        putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        speechChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "finki/local_speech")
        speechChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "capabilities" -> {
                    cancelProbe?.invoke()
                    val available = onDevice()
                    if (available && Build.VERSION.SDK_INT >= 33 && pending == null) {
                        var probe: SpeechRecognizer? = null
                        var finished = false
                        var timeout: Runnable? = null
                        fun complete(installed: Boolean?) {
                            if (finished) return
                            finished = true
                            timeout?.let { handler.removeCallbacks(it) }
                            probe?.destroy()
                            cancelProbe = null
                            result.success(mapOf("onDevice" to available, "language" to language,
                                "spanishInstalled" to installed, "offlineModel" to offline.bundled()))
                        }
                        cancelProbe = { complete(null) }
                        timeout = Runnable { complete(null) }
                        handler.postDelayed(timeout!!, 4000)
                        try {
                        val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
                        probe = recognizer
                        recognizer.checkRecognitionSupport(speechIntent(), mainExecutor, object : RecognitionSupportCallback {
                            override fun onSupportResult(support: RecognitionSupport) {
                                val spanish = support.installedOnDeviceLanguages.filter { it.startsWith("es", true) }
                                language = spanish.firstOrNull { it.equals("es-PE", true) }
                                    ?: spanish.firstOrNull { it.equals("es-ES", true) }
                                    ?: spanish.firstOrNull() ?: "es-PE"
                                complete(spanish.isNotEmpty())
                            }
                            override fun onError(error: Int) {
                                complete(null)
                            }
                        })
                        } catch (_: Exception) { complete(null) }
                    } else result.success(mapOf("onDevice" to available, "language" to language,
                        "offlineModel" to offline.bundled()))
                }
                "prepare" -> {
                    if (pending != null || preparing) result.error("BUSY", "Espera a que termine el micrófono", null)
                    else if (call.argument<Boolean>("preferNative") == true && onDevice()) {
                        engine = "native"
                        result.success(mapOf("engine" to engine))
                    } else {
                        preparing = true
                        offline.prepare { ready ->
                            preparing = false
                            if (ready && !isDestroyed) {
                                engine = "vosk"
                                result.success(mapOf("engine" to engine))
                            } else result.error("OFFLINE_MODEL_UNAVAILABLE", "No se pudo preparar la voz en el celular", null)
                        }
                    }
                }
                "listen" -> {
                    if (pending != null) result.error("BUSY", "Ya hay una grabación en curso", null)
                    else if (engine == "native" && !onDevice()) result.error("UNAVAILABLE", "No hay reconocimiento de voz local disponible", null)
                    else {
                        pending = result
                        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), audioPermissionCode)
                        } else beginSpeech()
                    }
                }
                "stop" -> { if (engine == "vosk") offline.stop() else speech?.stopListening(); result.success(null) }
                "cancel" -> { if (offlineDelegate.isInitialized()) offline.cancel(); speech?.cancel(); finish(null, "CANCELLED"); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun finish(text: String?, error: String? = null) {
        val response = pending
        pending = null
        speech?.destroy()
        speech = null
        if (error == null) response?.success(text ?: "")
        else response?.error(error, "No se pudo reconocer el audio localmente. Revisa el idioma español o escribe el registro.", null)
    }

    private fun beginSpeech() {
        if (pending == null) return
        if (engine == "vosk") {
            offline.listen({ if (pending != null) speechChannel.invokeMethod("ready", null) },
                { if (pending != null) speechChannel.invokeMethod("processing", null) },
                { text, error -> if (pending != null) finish(text, error) })
            return
        }
        if (Build.VERSION.SDK_INT < 31) { finish(null, "UNAVAILABLE"); return }
        try {
            speech = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
            speech?.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) { if (pending != null) speechChannel.invokeMethod("ready", null) }
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onError(error: Int) { finish(null, "SPEECH_$error") }
                override fun onResults(results: Bundle?) {
                    finish(results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull())
                }
                override fun onPartialResults(partialResults: Bundle?) {
                    speechChannel.invokeMethod("partial", partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: "")
                }
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
            speech?.startListening(speechIntent())
        } catch (_: Exception) { finish(null, "UNAVAILABLE") }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == audioPermissionCode) {
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) beginSpeech()
            else { if (offlineDelegate.isInitialized()) offline.cancel(); finish(null, "PERMISSION_REQUIRED") }
        }
    }

    override fun onDestroy() {
        cancelProbe?.invoke()
        speech?.cancel()
        finish(null, "CANCELLED")
        if (offlineDelegate.isInitialized()) offline.close()
        super.onDestroy()
    }

    override fun onStop() {
        if (preparing && offlineDelegate.isInitialized()) offline.cancel()
        if (pending != null) {
            if (offlineDelegate.isInitialized()) offline.cancel()
            speech?.cancel()
            finish(null, "AUDIO_INTERRUPTED")
        }
        super.onStop()
    }
}
