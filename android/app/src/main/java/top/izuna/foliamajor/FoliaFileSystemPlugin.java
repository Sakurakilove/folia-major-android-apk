package top.izuna.foliamajor;

import android.app.Activity;
import android.content.Intent;
import android.content.UriPermission;
import android.database.Cursor;
import android.net.Uri;
import android.provider.DocumentsContract;
import androidx.activity.result.ActivityResult;
import com.getcapacitor.*;
import com.getcapacitor.annotation.*;
import java.io.*;

// Use persisted Storage Access Framework grants rather than broad storage permissions.
@CapacitorPlugin(name = "FoliaFileSystem")
public class FoliaFileSystemPlugin extends Plugin {
    private final java.util.Map<String, RandomAccessFile> writes = new java.util.concurrent.ConcurrentHashMap<>();
    private final java.util.Map<String, File> writeFiles = new java.util.concurrent.ConcurrentHashMap<>();
    private final java.util.Map<String, Uri> writeTargets = new java.util.concurrent.ConcurrentHashMap<>();

    private volatile boolean closing;
    private final java.util.concurrent.ThreadPoolExecutor io = new java.util.concurrent.ThreadPoolExecutor(
        1, 1, 0, java.util.concurrent.TimeUnit.MILLISECONDS, new java.util.concurrent.ArrayBlockingQueue<>(128), task -> {
            Thread thread = new Thread(() -> {
                android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_BACKGROUND);
                try { task.run(); } finally { closeWrites(); }
            }, "FoliaDocumentIO");
            thread.setDaemon(true);
            return thread;
        }, new java.util.concurrent.ThreadPoolExecutor.AbortPolicy());
    private void executeIo(PluginCall call, Runnable action) {
        if (closing) { call.reject("Document host is closed"); return; }
        try { io.execute(action); }
        catch (java.util.concurrent.RejectedExecutionException busy) { call.reject("Document IO queue is busy"); }
    }
    private FoliaDirectoryWatch directoryWatch;
    @Override public void load() { directoryWatch = new FoliaDirectoryWatch(getContext()); }
    @PluginMethod public void watchDirectory(PluginCall call) {
        String token=call.getString("token"), raw=call.getString("uri");
        if(token==null || token.isEmpty() || raw==null || !"content".equals(Uri.parse(raw).getScheme())) {
            call.reject("An authorized directory URI and watch token are required"); return;
        }
        directoryWatch.watch(token,Uri.parse(raw),Boolean.TRUE.equals(call.getBoolean("recursive",true)),
            type->notifyListeners("directoryChanged",new JSObject().put("token",token).put("type",type)),
            error->call.reject(error.getMessage()),()->call.resolve());
    }
    @PluginMethod public void unwatchDirectory(PluginCall call) {
        String token=call.getString("token");if(token!=null)directoryWatch.unwatch(token);call.resolve();
    }

    @Override protected void handleOnDestroy() {
        closing = true;
        if (directoryWatch != null) directoryWatch.close();
        // Drain accepted IO before closing descriptors, without blocking the bridge/UI.
        io.shutdown();
        super.handleOnDestroy();
    }
    private void closeWrites() {
        for (String token : writes.keySet()) {
            RandomAccessFile file = writes.remove(token);
            File temporary = writeFiles.remove(token); writeTargets.remove(token);
            if (file != null) try { file.close(); } catch (IOException error) { android.util.Log.w("FoliaFiles", "Cannot close abandoned write", error); }
            if (temporary != null) temporary.delete();
        }
    }

    @PluginMethod public void beginWrite(PluginCall call) {
        executeIo(call, () -> {
            try {
                Uri uri = Uri.parse(call.getString("uri"));
                File temporary = File.createTempFile("saf-write-", ".part", getContext().getCacheDir());
                if (Boolean.TRUE.equals(call.getBoolean("keepExistingData", false))) {
                    try (InputStream input = getContext().getContentResolver().openInputStream(uri); OutputStream output = new FileOutputStream(temporary)) {
                        byte[] bytes = new byte[65536]; int count;
                        while ((count = input.read(bytes)) >= 0) output.write(bytes, 0, count);
                    }
                }
                String token = java.util.UUID.randomUUID().toString();
                writes.put(token, new RandomAccessFile(temporary, "rw")); writeFiles.put(token, temporary); writeTargets.put(token, uri);
                call.resolve(new JSObject().put("token", token));
            } catch (Exception error) { call.reject(error.getMessage()); }

        });
    }
    @PluginMethod public void writeChunk(PluginCall call) {
        executeIo(call, () -> {
            try {
                RandomAccessFile file = writes.get(call.getString("token"));
                if (file == null) throw new IOException("Writable document is closed");
                long position = call.getLong("position", 0L);
                if (position < 0) throw new IOException("Invalid write position");
                String data = call.getString("data", "");
                if (data.length() > 90000) throw new IOException("Write chunk is too large");
                file.seek(position); file.write(android.util.Base64.decode(data, android.util.Base64.NO_WRAP)); call.resolve();
            } catch (Exception error) { call.reject(error.getMessage()); }

        });
    }
    @PluginMethod public void truncateWrite(PluginCall call) {
        executeIo(call, () -> {
            try {
                RandomAccessFile file = writes.get(call.getString("token"));
                if (file == null) throw new IOException("Writable document is closed");
                file.setLength(call.getLong("size", 0L)); call.resolve();
            } catch (Exception error) { call.reject(error.getMessage()); }

        });
    }
    @PluginMethod public void finishWrite(PluginCall call) {
        executeIo(call, () -> {
            String token = call.getString("token");
            File temporary = writeFiles.get(token); Uri target = writeTargets.get(token); RandomAccessFile file = writes.get(token);
            boolean completed = false;
            try {
                if (file == null || temporary == null) throw new IOException("Writable document is closed");
                file.close();
                if (!Boolean.TRUE.equals(call.getBoolean("abort", false))) {
                    try (InputStream input = new FileInputStream(temporary); OutputStream output = getContext().getContentResolver().openOutputStream(target, "wt")) {
                        if (output == null) throw new IOException("Document provider did not open an output stream");
                        byte[] bytes = new byte[65536]; int count;
                        while ((count = input.read(bytes)) >= 0) output.write(bytes, 0, count);
                        output.flush();
                    }
                }
                completed = true;
                call.resolve();
            } catch (Exception error) {
                // Keep the full private copy and the original token available for retry/abort.
                if (temporary != null && temporary.isFile()) {
                    try { writes.put(token, new RandomAccessFile(temporary, "rw")); }
                    catch (IOException reopenError) { android.util.Log.e("FoliaFiles", "Cannot reopen recovery copy", reopenError); }
                }
                call.reject(error.getMessage());
            } finally {
                if (completed) {
                    writes.remove(token); writeTargets.remove(token); writeFiles.remove(token);
                    if (temporary != null) temporary.delete();
                }
            }

        });
    }

    private String permission(Uri uri, boolean write) {
        int flags = Intent.FLAG_GRANT_READ_URI_PERMISSION | (write ? Intent.FLAG_GRANT_WRITE_URI_PERMISSION : 0);
        if (getContext().checkUriPermission(uri, android.os.Process.myPid(), android.os.Process.myUid(), flags) != android.content.pm.PackageManager.PERMISSION_GRANTED) return "prompt";
        try { describe(uri); return "granted"; } catch (Exception error) { return "prompt"; }
    }
    @PluginMethod public void queryDocumentPermission(PluginCall call) {
        executeIo(call, () -> {
            try { call.resolve(new JSObject().put("state", permission(Uri.parse(call.getString("uri")), "readwrite".equals(call.getString("mode"))))); }
            catch (Exception error) { call.reject(error.getMessage()); }

        });
    }
    @PluginMethod public void requestDocumentPermission(PluginCall call) {
        executeIo(call, () -> {
            try {
                Uri uri = Uri.parse(call.getString("uri"));
                if (!"content".equals(uri.getScheme())) throw new IOException("A document URI is required");
                boolean write = "readwrite".equals(call.getString("mode"));
                if ("granted".equals(permission(uri, write))) { call.resolve(new JSObject().put("state", "granted")); return; }
                boolean directory = "directory".equals(call.getString("kind"));
                Intent intent = new Intent(directory ? Intent.ACTION_OPEN_DOCUMENT_TREE : Intent.ACTION_OPEN_DOCUMENT);
                if (!directory) intent.addCategory(Intent.CATEGORY_OPENABLE).setType("*/*");
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                    | (write ? Intent.FLAG_GRANT_WRITE_URI_PERMISSION : 0) | (directory ? Intent.FLAG_GRANT_PREFIX_URI_PERMISSION : 0));
                intent.putExtra(DocumentsContract.EXTRA_INITIAL_URI, uri);
                startActivityForResult(call, intent, "documentPermissionPicked");
            } catch (Exception error) { call.reject(error.getMessage()); }

        });
    }
    @ActivityCallback private void documentPermissionPicked(PluginCall call, ActivityResult result) {
        if (call == null) return;
        try {
            Intent data = result.getData();
            if (result.getResultCode() != Activity.RESULT_OK || data == null || data.getData() == null) { call.resolve(new JSObject().put("state", "denied")); return; }
            int flags = data.getFlags() & (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
            if ((data.getFlags() & Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION) != 0) getContext().getContentResolver().takePersistableUriPermission(data.getData(), flags);
            String state = permission(Uri.parse(call.getString("uri")), "readwrite".equals(call.getString("mode")));
            call.resolve(new JSObject().put("state", "granted".equals(state) ? state : "denied"));
        } catch (Exception error) { call.reject(error.getMessage()); }
    }

    private JSObject describe(Uri uri) throws Exception {
        try (Cursor cursor = getContext().getContentResolver().query(uri, null, null, null, null)) {
            if (cursor == null || !cursor.moveToFirst()) throw new IOException("Document is unavailable");
            String mime = cursor.getString(cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE));
            return new JSObject().put("__foliaAndroidHandle", true).put("uri", uri.toString())
                .put("kind", DocumentsContract.Document.MIME_TYPE_DIR.equals(mime) ? "directory" : "file")
                .put("name", cursor.getString(cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)))
                .put("mimeType", mime)
                .put("size", cursor.getLong(cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_SIZE)))
                .put("lastModified", cursor.getLong(cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_LAST_MODIFIED)));
        }
    }

    @PluginMethod public void pickFiles(PluginCall call){
        Intent intent=new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_WRITE_URI_PERMISSION|Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE,Boolean.TRUE.equals(call.getBoolean("multiple",false)));
        com.getcapacitor.JSArray types=call.getArray("mimeTypes");
        if(types!=null && types.length()>0){java.util.List<String> mime=new java.util.ArrayList<>();
            for(int i=0;i<types.length();i++)mime.add(types.optString(i));intent.putExtra(Intent.EXTRA_MIME_TYPES,mime.toArray(new String[0]));}
        startActivityForResult(call,intent,"filesPicked");
    }
    @ActivityCallback private void filesPicked(PluginCall call,ActivityResult result){
        if(call==null)return;
        if(result.getResultCode()!=Activity.RESULT_OK || result.getData()==null){call.reject("File selection canceled","AbortError");return;}
        try{
            Intent data=result.getData();java.util.List<Uri> selected=new java.util.ArrayList<>();
            if(data.getClipData()!=null)for(int i=0;i<data.getClipData().getItemCount();i++)selected.add(data.getClipData().getItemAt(i).getUri());
            else if(data.getData()!=null)selected.add(data.getData());
            com.getcapacitor.JSArray entries=new com.getcapacitor.JSArray();
            for(Uri uri:selected){getContext().getContentResolver().takePersistableUriPermission(uri,data.getFlags()&(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_WRITE_URI_PERMISSION));entries.put(describe(uri));}
            call.resolve(new JSObject().put("entries",entries));
        }catch(Exception error){call.reject(error.getMessage());}
    }
    @PluginMethod
    public void pickDirectory(PluginCall call) {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION | Intent.FLAG_GRANT_PREFIX_URI_PERMISSION);
        startActivityForResult(call, intent, "directoryPicked");
    }

    @ActivityCallback
    private void directoryPicked(PluginCall call, ActivityResult result) {
        if (call == null) return;
        if (result.getResultCode() != Activity.RESULT_OK || result.getData() == null) { call.reject("Selection cancelled", "ABORT_ERR"); return; }
        try {
            Uri tree = result.getData().getData();
            int flags = result.getData().getFlags() & (Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
            getContext().getContentResolver().takePersistableUriPermission(tree, flags);
            Uri document = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree));
            call.resolve(describe(document));
        } catch (Exception error) { call.reject(error.getMessage()); }
    }

    @PluginMethod
    public void list(PluginCall call) {
        executeIo(call, () -> {
            try {
                Uri parent = Uri.parse(call.getString("uri"));
                Uri children = DocumentsContract.buildChildDocumentsUriUsingTree(parent, DocumentsContract.getDocumentId(parent));
                JSArray items = new JSArray();
                try (Cursor cursor = getContext().getContentResolver().query(children, null, null, null, null)) {
                    while (cursor != null && cursor.moveToNext()) {
                        String id = cursor.getString(cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID));
                        Uri child = DocumentsContract.buildDocumentUriUsingTree(parent, id);
                        String mime = cursor.getString(cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE));
                        items.put(new JSObject().put("__foliaAndroidHandle", true).put("uri", child.toString())
                            .put("kind", DocumentsContract.Document.MIME_TYPE_DIR.equals(mime) ? "directory" : "file")
                            .put("name", cursor.getString(cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME))));
                    }
                }
                call.resolve(new JSObject().put("entries", items));
            } catch (Exception error) { call.reject(error.getMessage()); }

        });
    }

    @PluginMethod
    public void stat(PluginCall call) {
        executeIo(call, () -> {
            try { call.resolve(describe(Uri.parse(call.getString("uri")))); }
            catch (Exception error) { call.reject(error.getMessage(), "NOT_FOUND_ERR"); }

        });
    }

    @PluginMethod
    public void create(PluginCall call) {
        executeIo(call, () -> {
            try {
                Uri uri = DocumentsContract.createDocument(getContext().getContentResolver(), Uri.parse(call.getString("uri")),
                    call.getString("mimeType", "application/octet-stream"), call.getString("name"));
                if (uri == null) throw new IOException("Cannot create document");
                call.resolve(describe(uri));
            } catch (Exception error) { call.reject(error.getMessage()); }

        });
    }

    @PluginMethod
    public void remove(PluginCall call) {
        executeIo(call, () -> {
            try {
                if (!DocumentsContract.deleteDocument(getContext().getContentResolver(), Uri.parse(call.getString("uri")))) throw new IOException("Cannot delete document");
                call.resolve();
            } catch (Exception error) { call.reject(error.getMessage()); }

        });
    }

    @PluginMethod
    public void stage(PluginCall call) {
        executeIo(call, () -> {
            try {
                Uri uri = Uri.parse(call.getString("uri"));
                if (!"content".equals(uri.getScheme())) throw new IOException("A granted document URI is required");
                JSObject info = describe(uri);
                File directory = new File(getContext().getCacheDir(), "picked-documents");
                directory.mkdirs();
                String name = new File(info.getString("name")).getName();
                File destination = new File(directory, java.util.UUID.randomUUID() + "-" + name);
                try (InputStream input = getContext().getContentResolver().openInputStream(uri); OutputStream output = new FileOutputStream(destination)) {
                    byte[] buffer = new byte[65536];
                    int count;
                    while ((count = input.read(buffer)) >= 0) output.write(buffer, 0, count);
                }
                call.resolve(new JSObject().put("path", destination.getPath()));
            } catch (Exception error) { call.reject(error.getMessage()); }

        });
    }
}
