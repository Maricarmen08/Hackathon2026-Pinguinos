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
