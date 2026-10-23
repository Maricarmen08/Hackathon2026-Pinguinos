package pe.pinguinos.hackathon_pinguinos_mvp

import android.content.Context
import java.io.File
import java.io.IOException
import java.security.MessageDigest
import java.util.zip.ZipInputStream

/** Versioned, private model files. Contains no downloader and never touches app data. */
class VoskModelStore(private val context: Context) {
    companion object {
        const val NAME = "vosk-model-small-es-0.42"
        const val SHA256 = "09b239888f633ef2f0b4e09736e3d9936acfd810bc65d53fad45261762c6511f"
    }
    fun bundled(): Boolean = try { context.assets.open(NAME + ".zip").use { }; true }
        catch (_: IOException) { false }

    fun ensure(): File { synchronized(VoskModelStore::class.java) {
        val root = File(context.filesDir, "offline_speech").apply { mkdirs() }
        val target = File(root, NAME)
        val marker = File(target, ".ready")
        val required = listOf("am/final.mdl", "graph/HCLr.fst", "graph/Gr.fst", "conf/model.conf")
        if (marker.exists() && marker.readText() == SHA256 && required.all { File(target, it).length() > 0 }) return target
        val digest = MessageDigest.getInstance("SHA-256")
        context.assets.open(NAME + ".zip").use { input ->
            val buffer = ByteArray(65536)
            while (true) { val n = input.read(buffer); if (n < 0) break; digest.update(buffer, 0, n) }
        }
        val hash = digest.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
        if (hash != SHA256) throw IOException("Modelo local no válido")
        val staging = File(root, NAME + ".install")
        // Only these two fixed versioned model folders may be replaced on retry.
        check(staging.canonicalFile.parentFile == root.canonicalFile)
        staging.deleteRecursively()
        staging.mkdirs()
        try {
            var size = 0L
            var count = 0
            ZipInputStream(context.assets.open(NAME + ".zip")).use { zip ->
                while (true) {
                    val entry = zip.nextEntry ?: break
                    if (++count > 100 || !entry.name.startsWith(NAME + "/")) throw IOException("Modelo local no válido")
                    val relative = entry.name.removePrefix(NAME + "/")
                    if (relative.isEmpty()) continue
                    val out = File(staging, relative)
                    if (!out.canonicalPath.startsWith(staging.canonicalPath + File.separator)) throw IOException("Ruta no válida")
                    if (entry.isDirectory) out.mkdirs() else {
                        out.parentFile?.mkdirs()
                        out.outputStream().use { output ->
                            val buffer = ByteArray(65536)
                            while (true) {
                                val n = zip.read(buffer); if (n < 0) break
                                size += n
                                if (size > 100L * 1024 * 1024) throw IOException("Modelo demasiado grande")
                                output.write(buffer, 0, n)
                            }
                        }
                    }
                }
            }
            if (!required.all { File(staging, it).length() > 0 }) throw IOException("Modelo incompleto")
            File(staging, ".ready").writeText(SHA256)
            check(target.canonicalFile.parentFile == root.canonicalFile)
            if (target.exists() && !target.deleteRecursively()) throw IOException("No se pudo preparar el modelo")
            if (!staging.renameTo(target)) throw IOException("No se pudo instalar el modelo")
            return target
        } finally { if (staging.exists()) staging.deleteRecursively() }
    } }
}
