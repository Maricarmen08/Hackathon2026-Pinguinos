package pe.pinguinos.hackathon_pinguinos_mvp

import org.json.JSONObject
import org.vosk.Recognizer

/** Full vocabulary: product/person names are not constrained by a closed grammar. */
class VoskPcmDecoder(private val recognizer: Recognizer) : PcmDecoder {
    override fun accept(chunk: ShortArray, count: Int) = recognizer.acceptWaveForm(chunk, count)
    override fun segment() = JSONObject(recognizer.result).optString("text")
    override fun tail() = JSONObject(recognizer.finalResult).optString("text")
}
