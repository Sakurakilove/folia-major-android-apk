package top.izuna.foliamajor;

import android.os.*;
import com.getcapacitor.*;
import java.lang.ref.WeakReference;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import org.json.*;

// Native requests continue while the music WebView is backgrounded; results never need a renderer round trip.
final class FoliaNativeDispatcher {
    private static WeakReference<MainActivity> activity = new WeakReference<>(null);
    private static final ExecutorService replies = Executors.newCachedThreadPool();
    private static boolean running;
    private static Thread requestThread;
    static synchronized void stop() { running = false; if (requestThread != null) requestThread.interrupt(); requestThread = null; }
    static boolean isAttachedTo(MainActivity main) { return activity.get() == main; }
    static void attach(MainActivity main) { activity = new WeakReference<>(main); }
    static synchronized void start() {
        if (running) return; running = true;
        Thread worker = new Thread(() -> {
            while (!Thread.currentThread().isInterrupted()) {
                try {
                    JSONObject response = FoliaRuntimeHost.rpc("_nativePoll", new JSONArray(), 1);
                    JSONObject action = response.optJSONObject("result");
                    if (action != null) dispatch(action);
                    Thread.sleep(action == null ? 150 : 10);
                } catch (InterruptedException error) { Thread.currentThread().interrupt(); }
                catch (Exception error) { try { Thread.sleep(1000); } catch (InterruptedException interrupted) { Thread.currentThread().interrupt(); } }
            }
        }, "FoliaNativeRequests"); worker.setDaemon(true); requestThread = worker; worker.start();
    }
    private static void complete(String id, Object value, String error) {
        replies.execute(() -> {
            try { FoliaRuntimeHost.rpc("_completeNative", new JSONArray().put(id).put(value == null ? JSONObject.NULL : value).put(error == null ? JSONObject.NULL : error), 1); }
            catch (Exception failure) { android.util.Log.w("FoliaNativeRequests", "Cannot deliver native result", failure); }
        });
    }
    private static void dispatch(JSONObject action) {
        String id = action.optString("id"), method = action.optString("method");
        JSONArray args = action.optJSONArray("args");
        if(method.equals("appProcessMemory")){
            replies.execute(()->{try{complete(id,FoliaProcessMetrics.measure(),null);}catch(Exception error){complete(id,null,error.getMessage());}});return;
        }
        if (method.equals("resolveProxy")) {
            replies.execute(() -> { try { complete(id, FoliaNetwork.resolve(args.getString(0)), null); } catch (Exception error) { complete(id, null, error.getMessage()); } }); return;
        }
        MainActivity main = activity.get();
        if (main == null || main.isDestroyed() || main.isFinishing() || main.getBridge() == null) { complete(id, null, "Open Folia before using an interactive Android action"); return; }
        try {
            JSObject options = new JSObject().put("method", method).put("args", args).put("requestId", id);
            AtomicBoolean answered = new AtomicBoolean();
            PluginCall call = new PluginCall(null, "FoliaShell", id, "execute", options) {
                @Override public void resolve(JSObject result) { if (answered.compareAndSet(false,true)) complete(id, result == null ? null : result.opt("result"), null); }
                @Override public void resolve() { resolve(null); }
                @Override public void reject(String message, String code, Exception exception, JSObject data) { if (answered.compareAndSet(false,true)) complete(id, null, message); }
                @Override public void errorCallback(String message) { reject(message); }
            };
            FoliaShellPlugin shell = (FoliaShellPlugin)main.getBridge().getPlugin("FoliaShell").getInstance(); shell.execute(call);
        } catch (Exception error) { complete(id, null, error.getMessage()); }
    }
}
