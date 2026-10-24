package pe.pinguinos.hackathon_pinguinos_mvp

/** Fixed format and bounded storage: 45s PCM16 mono, 1.44MB; never persisted. */
class PcmRecording {
    companion object { const val RATE = 16000; const val MAX_SECONDS = 45 }
    val samples = ShortArray(RATE * MAX_SECONDS)
    var count = 0; private set
    val full get() = count == samples.size
    fun append(chunk: ShortArray, length: Int) {
        require(length in 0..chunk.size && count + length <= samples.size)
        chunk.copyInto(samples, count, 0, length)
        count += length
    }
}

/** Sube un audio bajo (micrófonos suaves) antes de reconocerlo. Máximo 6x, sin recortar; el silencio no se amplifica. */
fun normalizePcm(pcm: ShortArray, count: Int, target: Int = 20000, maxGain: Float = 6f) {
    var peak = 0
    for (i in 0 until count) {
        val a = Math.abs(pcm[i].toInt())
        if (a > peak) peak = a
    }
    if (peak < 300) return
    val gain = minOf(maxGain, target.toFloat() / peak)
    if (gain <= 1.05f) return
    for (i in 0 until count) {
        pcm[i] = (pcm[i] * gain).toInt().coerceIn(-32768, 32767).toShort()
    }
}

interface PcmDecoder {
    fun accept(chunk: ShortArray, count: Int): Boolean
    fun segment(): String
    fun tail(): String
}

data class DecodedPcm(val text: String, val samples: Int, val segments: Int)

/** An endpoint ends one phrase, never the full session. Every sample is fed once. */
fun decodePcm(pcm: ShortArray, count: Int, decoder: PcmDecoder,
              cancelled: () -> Boolean = { false }): DecodedPcm {
    require(count in 0..pcm.size)
    val segments = mutableListOf<String>()
    val chunk = ShortArray(3200)
    var offset = 0
    while (offset < count) {
        if (cancelled()) throw InterruptedException()
        val length = minOf(chunk.size, count - offset)
        pcm.copyInto(chunk, 0, offset, offset + length)
        if (decoder.accept(chunk, length)) {
            decoder.segment().trim().takeIf { it.isNotEmpty() }?.let { segments.add(it) }
        }
        offset += length
    }
    if (cancelled()) throw InterruptedException()
    decoder.tail().trim().takeIf { it.isNotEmpty() }?.let { segments.add(it) }
    return DecodedPcm(segments.joinToString(" "), offset, segments.size)
}
