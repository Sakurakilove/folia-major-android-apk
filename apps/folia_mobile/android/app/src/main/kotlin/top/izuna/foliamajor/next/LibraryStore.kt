package top.izuna.foliamajor.next

import android.content.Context
import android.util.AtomicFile
import java.io.File
import org.json.JSONArray
import org.json.JSONObject

// Only the new app's URI catalog is persisted; no legacy settings, keys or account data are read.
object LibraryStore {
    private fun file(context: Context) = AtomicFile(File(context.filesDir, "library-v1.json"))
    fun read(context: Context): List<Map<String, Any?>> {
        val store = file(context)
        if (!store.baseFile.exists()) return emptyList()
        val array = store.openRead().use { JSONArray(it.bufferedReader(Charsets.UTF_8).readText()) }
        return (0 until array.length()).map { index ->
            val item = array.getJSONObject(index)
            require(item.opt("uri") is String) { "Catalog item has no URI" }
            @Suppress("UNCHECKED_CAST")
            (decode(item) as Map<String, Any?>)
        }
    }
    // StandardMessageCodec cannot carry JSONObject/JSONArray/JSONObject.NULL, including inside unknown nested source fields.
    private fun decode(value: Any?): Any? = when (value) {
        JSONObject.NULL, null -> null
        is JSONObject -> value.keys().asSequence().associateWith { key -> decode(value.get(key)) }
        is JSONArray -> (0 until value.length()).map { index -> decode(value.get(index)) }
        else -> value
    }
    fun write(context: Context, entries: List<*>) {
        val store=file(context);val stream=store.startWrite()
        try { stream.write(JSONArray(entries).toString().toByteArray(Charsets.UTF_8));store.finishWrite(stream) }
        catch (failure: Exception) { store.failWrite(stream);throw failure }
    }
}
