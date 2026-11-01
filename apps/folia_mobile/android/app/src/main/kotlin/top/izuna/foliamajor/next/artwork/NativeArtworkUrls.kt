package top.izuna.foliamajor.next.artwork

// Redirect resolution uses the same WHATWG parser as the original cover helpers, including non-ASCII Location values.
object NativeArtworkUrls {
    init { System.loadLibrary("folia_url") }
    private external fun resolveUtf8(base: ByteArray, value: ByteArray): ByteArray?
    fun resolve(base: String, value: String): String? =
        resolveUtf8(base.toByteArray(Charsets.UTF_8), value.toByteArray(Charsets.UTF_8))?.toString(Charsets.UTF_8)
}
