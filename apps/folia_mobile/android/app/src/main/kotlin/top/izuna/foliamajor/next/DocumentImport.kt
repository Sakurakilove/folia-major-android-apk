package top.izuna.foliamajor.next

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.OpenableColumns
import java.io.File
import java.security.MessageDigest

// URI audio streams remain direct; only embedded artwork and small lyric text are read here, off UI.
object DocumentImport {
    fun audio(context: Context, uri: Uri): Map<String, Any?> {
        val name = context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
            if (it.moveToFirst()) it.getString(0) else null
        } ?: uri.lastPathSegment.orEmpty()
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(context, uri)
            val picture = retriever.embeddedPicture
            val cover = if (picture != null && picture.size <= 16 * 1024 * 1024) {
                val id = MessageDigest.getInstance("SHA-256").digest(uri.toString().toByteArray()).joinToString("") { "%02x".format(it) }
                val directory = File(context.cacheDir, "artwork").apply { mkdirs() }
                val file = File(directory, "$id.img")
                if (!file.exists()) file.writeBytes(picture)
                file.absolutePath
            } else null
            mapOf("uri" to uri.toString(), "title" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE) ?: name),
                "artist" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST) ?: ""), "coverPath" to cover)
        } finally { retriever.release() }
    }
    fun lyrics(context: Context, uri: Uri): String {
        val bytes = context.contentResolver.openInputStream(uri)!!.use { input ->
            val output = java.io.ByteArrayOutputStream()
            val chunk = ByteArray(8192)
            while (true) {
                val count = input.read(chunk)
                if (count < 0) break
                require(output.size() + count <= 4 * 1024 * 1024) { "Lyric file is too large" }
                output.write(chunk, 0, count)
            }
            output.toByteArray()
        }
        return bytes.toString(Charsets.UTF_8).removePrefix("\uFEFF")
    }
}
