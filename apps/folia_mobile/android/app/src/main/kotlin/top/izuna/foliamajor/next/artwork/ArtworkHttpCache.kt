package top.izuna.foliamajor.next.artwork

import android.content.Context
import android.net.http.HttpResponseCache
import android.util.Log
import java.io.File
import java.net.ResponseCache

// Native HTTP cache keeps server Cache-Control/ETag/Vary behavior across restarts instead of downloading the wall's covers on every launch.
object ArtworkHttpCache {
    private var attempted = false
    private var owned: HttpResponseCache? = null
    @Synchronized fun ensure(context: Context) {
        if (attempted) return
        attempted = true
        // Another native transport may already own the process response cache.
        if (ResponseCache.getDefault() != null) return
        try { owned = HttpResponseCache.install(File(context.cacheDir, "folia-artwork-http"), 32L * 1024 * 1024) }
        catch (failure: java.io.IOException) { Log.w("FoliaArtwork", "[Artwork] HTTP cache unavailable", failure) }
    }
    @Synchronized fun clearOwned() {
        val cache = owned ?: return
        try { cache.delete() }
        finally {
            if (ResponseCache.getDefault() === cache) ResponseCache.setDefault(null)
            owned = null; attempted = false
        }
    }
    @Synchronized fun snapshot(): Map<String, Number> = owned?.let {
        mapOf("bytes" to it.size(), "limitBytes" to it.maxSize(), "hits" to it.hitCount,
            "network" to it.networkCount, "requests" to it.requestCount)
    } ?: emptyMap()
}
