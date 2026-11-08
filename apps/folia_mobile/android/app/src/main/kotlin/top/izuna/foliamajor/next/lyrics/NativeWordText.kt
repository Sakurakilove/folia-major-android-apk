package top.izuna.foliamajor.next.lyrics

// Mirror JavaScript UTF-16 even for isolated surrogates and a leading BOM, which Dart's UTF-8 decoder otherwise strips.
internal object NativeWordText {
    fun units(value: Any?): Int? = when (value) {
        is String -> value.length
        is ByteArray -> if (value.size % 2 == 0) value.size / 2 else null
        else -> null
    }
    fun decode(value: Any?): String = when (value) {
        is String -> value
        is ByteArray -> {
            require(value.size % 2 == 0)
            String(CharArray(value.size / 2) { index ->
                ((value[index * 2].toInt() and 255) or ((value[index * 2 + 1].toInt() and 255) shl 8)).toChar()
            })
        }
        else -> error("Invalid UTF-16 text")
    }
    fun encode(text: String): Any {
        if (text.startsWith('\uFEFF')) return bytes(text)
        var index = 0
        while (index < text.length) {
            val c = text[index++]
            if (Character.isHighSurrogate(c)) {
                if (index < text.length && Character.isLowSurrogate(text[index])) index++ else return bytes(text)
            } else if (Character.isLowSurrogate(c)) return bytes(text)
        }
        return text
    }
    private fun bytes(text: String) = ByteArray(text.length * 2) { index ->
        val c = text[index / 2].code
        (if (index % 2 == 0) c and 255 else c ushr 8).toByte()
    }
}
