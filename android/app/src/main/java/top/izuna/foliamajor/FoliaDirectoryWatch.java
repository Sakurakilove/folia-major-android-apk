package top.izuna.foliamajor;

import android.content.Context;
import android.database.ContentObserver;
import android.database.Cursor;
import android.net.Uri;
import android.os.*;
import android.provider.DocumentsContract;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.Consumer;

// Observe SAF metadata without opening song contents; polling covers providers with missing notifications.
final class FoliaDirectoryWatch implements AutoCloseable {
    private final Context context;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final ScheduledExecutorService io = Executors.newSingleThreadScheduledExecutor(task -> new Thread(() -> {
        android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_BACKGROUND);
        task.run();
    }, "Folia directory metadata"));
    private final ConcurrentHashMap<String, Watch> watches = new ConcurrentHashMap<>();
    private volatile boolean closed;
    private final class Watch {
        final String token;
        final Uri root;
        final boolean recursive;
        final Consumer<String> changed;
        volatile boolean stopped;
        volatile CancellationSignal reading;
        String fingerprint;
        volatile long lastHint;
        ScheduledFuture<?> poll;
        ContentObserver observer;
        final java.util.concurrent.atomic.AtomicBoolean queued = new java.util.concurrent.atomic.AtomicBoolean();
        Watch(String token, Uri root, boolean recursive, Consumer<String> changed) {
            this.token=token;this.root=root;this.recursive=recursive;this.changed=changed;
        }
        void stop() {
            stopped=true;
            if (poll != null) poll.cancel(true);
            if (reading != null) reading.cancel();
            if (observer != null) context.getContentResolver().unregisterContentObserver(observer);
        }
        void queueCheck() {
            long now=SystemClock.uptimeMillis();
            if (stopped || closed || now-lastHint<250 || !queued.compareAndSet(false, true)) return;
            lastHint=now;
            try { io.execute(() -> { try { check(); } finally { queued.set(false); } }); }
            catch (RejectedExecutionException closing) { queued.set(false); }
        }
        void check() {
            if (stopped || closed) return;
            try {
                String next = fingerprint(this);
                if (stopped || closed) return;
                if (!next.equals(fingerprint)) { fingerprint=next; changed.accept("unknown"); }
            } catch (Exception error) {
                if (!stopped && !closed) { changed.accept("errored"); unwatch(token); }
            }
        }
    }
    FoliaDirectoryWatch(Context context) { this.context=context.getApplicationContext(); }
    void watch(String token, Uri root, boolean recursive, Consumer<String> changed, Consumer<Exception> failed, Runnable ready) {
        if (closed) { failed.accept(new IllegalStateException("Directory watch host is closed")); return; }
        Watch watch = new Watch(token, root, recursive, changed);
        if (watches.putIfAbsent(token, watch) != null) { failed.accept(new IllegalArgumentException("Duplicate directory watch")); return; }
        io.execute(() -> {
            try {
                watch.fingerprint = fingerprint(watch);
                if (closed || watch.stopped) throw new CancellationException("Directory watch was cancelled");
                watch.observer = new ContentObserver(ui) {
                    @Override public void onChange(boolean selfChange) {
                        watch.queueCheck();
                    }
                };
                try { context.getContentResolver().registerContentObserver(root, true, watch.observer); }
                catch (SecurityException unsupported) { watch.observer=null; }
                watch.poll = io.scheduleWithFixedDelay(watch::queueCheck, 30, 30, TimeUnit.SECONDS);
                if (closed || watch.stopped) { watch.stop(); throw new CancellationException("Directory watch was cancelled"); }
                ready.run();
            } catch (Exception error) { unwatch(token); failed.accept(error); }
        });
    }
    void unwatch(String token) { Watch watch=watches.remove(token); if (watch!=null) watch.stop(); }
    @Override public void close() { closed=true;for (String token:new ArrayList<>(watches.keySet())) unwatch(token);io.shutdownNow(); }
    private String fingerprint(Watch watch) throws Exception {
        CancellationSignal signal = new CancellationSignal(); watch.reading=signal;
        Runnable timeout=signal::cancel;
        try {
            MessageDigest digest=MessageDigest.getInstance("SHA-256");
            ArrayDeque<String> directories=new ArrayDeque<>();
            Set<String> visited=new HashSet<>();
            directories.add(DocumentsContract.isDocumentUri(context,watch.root) ? DocumentsContract.getDocumentId(watch.root) : DocumentsContract.getTreeDocumentId(watch.root));
            String[] columns={DocumentsContract.Document.COLUMN_DOCUMENT_ID,DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,DocumentsContract.Document.COLUMN_SIZE,DocumentsContract.Document.COLUMN_LAST_MODIFIED};
            while (!directories.isEmpty()) {
                signal.throwIfCanceled();if(watch.stopped || closed)throw new OperationCanceledException();
                String parent=directories.removeFirst();if(!visited.add(parent))continue;
                Uri children=DocumentsContract.buildChildDocumentsUriUsingTree(watch.root,parent);
                List<String> rows=new ArrayList<>();List<String> nested=new ArrayList<>();
                ui.removeCallbacks(timeout);ui.postDelayed(timeout,15000);
                try(Cursor cursor=context.getContentResolver().query(children,columns,null,null,null,signal)) {
                    if(cursor==null)throw new IllegalStateException("Document provider returned no metadata");
                    while(cursor.moveToNext()) {
                        String id=cursor.getString(0),name=cursor.getString(1),mime=cursor.getString(2);
                        rows.add(parent+"\u0000"+id+"\u0000"+name+"\u0000"+mime+"\u0000"+cursor.getLong(3)+"\u0000"+cursor.getLong(4));
                        if(watch.recursive && DocumentsContract.Document.MIME_TYPE_DIR.equals(mime))nested.add(id);
                    }
                }
                ui.removeCallbacks(timeout);
                Collections.sort(rows);Collections.sort(nested);directories.addAll(nested);
                for(String row:rows){digest.update(row.getBytes(StandardCharsets.UTF_8));digest.update((byte)0xff);}
            }
            return android.util.Base64.encodeToString(digest.digest(),android.util.Base64.NO_WRAP);
        } finally { ui.removeCallbacks(timeout);watch.reading=null; }
    }
}
