package top.izuna.foliamajor;

import android.content.*;
import android.database.Cursor;
import android.net.Uri;
import android.os.*;
import com.getcapacitor.*;
import java.io.File;
import java.util.concurrent.*;
import org.json.*;

// Private Binder delivery keeps sign-in cookies out of the music renderer and its Capacitor messages.
public final class FoliaYtmAuthProvider extends ContentProvider {
    static final ConcurrentHashMap<String, PluginCall> pending = new ConcurrentHashMap<>();
    private static final ExecutorService io = Executors.newSingleThreadExecutor();
    private static final Handler expiryHandler = new Handler(Looper.getMainLooper());
    private static final ConcurrentHashMap<String, Runnable> expiries = new ConcurrentHashMap<>();
    static void registerPending(String id, PluginCall call) {
        Runnable previous = expiries.remove(id);
        if (previous != null) expiryHandler.removeCallbacks(previous);
        pending.put(id, call);
        Runnable expiry = () -> {
            expiries.remove(id);
            if (pending.remove(id, call)) call.reject("Sign-in request expired; open sign-in again");
        };
        expiries.put(id, expiry);
        expiryHandler.postDelayed(expiry, 15 * 60 * 1000L);
    }
    private static PluginCall takePending(String id) {
        Runnable expiry = expiries.remove(id);
        if (expiry != null) expiryHandler.removeCallbacks(expiry);
        return pending.remove(id);
    }
    @Override public boolean onCreate() { return true; }
    @Override public Bundle call(String method, String id, Bundle extras) {
        if (Binder.getCallingUid() != android.os.Process.myUid()) throw new SecurityException("Private sign-in handoff");
        if (!"complete".equals(method) || extras == null || !pending.containsKey(id)) throw new IllegalArgumentException("Unknown sign-in request");
        String json = extras.getString("result"); int pid = extras.getInt("pid");
        if (json == null || json.length() > 262144 || pid == android.os.Process.myPid() || pid < 1) throw new IllegalArgumentException("Invalid sign-in result");
        PluginCall call = takePending(id);
        if (call == null) throw new IllegalArgumentException("Sign-in request expired");
        io.execute(() -> {
            try {
                long deadline = System.currentTimeMillis() + 10000;
                while (new File("/proc/" + pid).exists() && System.currentTimeMillis() < deadline) Thread.sleep(50);
                if (new File("/proc/" + pid).exists()) throw new IllegalStateException("The sign-in browser did not finish closing");
                FoliaRuntimeHost.rpc("_completeNative", new JSONArray().put(id).put(new JSONObject(json)).put(JSONObject.NULL), 1);
                call.resolve(new JSObject().put("result", JSONObject.NULL));
            } catch (Exception error) { call.reject(error.getMessage()); }
        });
        return Bundle.EMPTY;
    }
    @Override public Cursor query(Uri uri, String[] columns, String selection, String[] args, String sort) { throw new UnsupportedOperationException(); }
    @Override public String getType(Uri uri) { return null; }
    @Override public Uri insert(Uri uri, ContentValues values) { throw new UnsupportedOperationException(); }
    @Override public int delete(Uri uri, String selection, String[] args) { throw new UnsupportedOperationException(); }
    @Override public int update(Uri uri, ContentValues values, String selection, String[] args) { throw new UnsupportedOperationException(); }
}
