package top.izuna.foliamajor.next.artwork

// A reply ticket is claimed through native FFI; no encoded image or pixel array crosses the platform channel.
object NativeArtworkDescriptors {
    init { System.loadLibrary("folia_artwork") }
    external fun createScope(): Long
    external fun createMemoryFile(): Int
    external fun registerFd(scope: Long, fd: Int): Long
    external fun releaseTicket(ticket: Long)
    external fun releaseScope(scope: Long)
}
