package top.izuna.foliamajor.next

import android.content.Context
import android.util.AtomicFile
import java.io.File
import org.json.JSONArray

// Only the new app's URI catalog is persisted; no legacy settings, keys or account data are read.
object LibraryStore {
    private fun file(context: Context) = AtomicFile(File(context.filesDir, "library-v1.json"))
    fun read(context: Context): List<Map<String, Any?>> {
        val store = file(context)
        if (!store.baseFile.exists()) return emptyList()
        val array = store.openRead().use { JSONArray(it.bufferedReader(Charsets.UTF_8).readText()) }
        return (0 until array.length()).map { index ->
            val item = array.getJSONObject(index)
            mapOf("uri" to item.getString("uri"),"title" to item.optString("title"),"artist" to item.optString("artist"),
                "coverPath" to item.optString("coverPath").takeIf { it.isNotEmpty() && File(it).isFile })
        }
    }
    fun write(context: Context, entries: List<*>) {
        val store=file(context);val stream=store.startWrite()
        try { stream.write(JSONArray(entries).toString().toByteArray(Charsets.UTF_8));store.finishWrite(stream) }
        catch (failure: Exception) { store.failWrite(stream);throw failure }
    }
}
