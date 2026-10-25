package top.izuna.foliamajor;

import android.webkit.*;
import android.os.*;
import androidx.appcompat.app.AppCompatActivity;
import com.getcapacitor.JSObject;
import org.json.*;
import java.util.*;
import java.util.function.Consumer;

// Untrusted YouTube player scripts get JavaScript execution only, without files, network or the app bridge.
final class FoliaScriptSandbox {
    private static final Handler ui = new Handler(Looper.getMainLooper());
    private static WebView view;
    private static boolean ready;
    private static long generation;
    private static final Map<String, Request> pending = new LinkedHashMap<>();
    private static final class Request {
        final String code;
        final Consumer<Object> done;
        Runnable timeout;
        boolean sent;
        Request(String code, Consumer<Object> done) { this.code = code; this.done = done; }
    }
    static final class Completion {
        private final long owner;
        Completion(long owner) { this.owner = owner; }
        @JavascriptInterface public void complete(String id, String result) {
            ui.post(() -> {
                if (owner != generation) return;
                Request request = pending.remove(id);
                if (request == null) return;
                ui.removeCallbacks(request.timeout);
                Object value;
                try { value = new JSONObject(result); }
                catch (Exception error) { value = new JSObject().put("error", "Invalid sandbox result"); }
                request.done.accept(value);
            });
        }
    }
    private static void reset(String reason) {
        WebView previous = view;
        view = null; ready = false; generation++;
        List<Request> abandoned = new ArrayList<>(pending.values());
        pending.clear();
        if (previous != null) previous.destroy();
        for (Request request : abandoned) {
            ui.removeCallbacks(request.timeout);
            request.done.accept(new JSObject().put("error", reason));
        }
    }
    static void close() { ui.post(() -> reset("Sandbox host stopped")); }
    static void evaluate(AppCompatActivity activity, String code, Consumer<Object> done) {
        ui.post(() -> {
            if (view == null) {
                ready = false;
                final long owner = ++generation;
                view = new WebView(activity.getApplicationContext());
                WebSettings settings = view.getSettings();
                settings.setJavaScriptEnabled(true); settings.setBlockNetworkLoads(true);
                settings.setAllowFileAccess(false); settings.setAllowContentAccess(false); settings.setDomStorageEnabled(false);
                settings.setJavaScriptCanOpenWindowsAutomatically(false);
                view.addJavascriptInterface(new Completion(owner), "FoliaSandboxResult");
                view.setWebViewClient(new WebViewClient() {
                    @Override public boolean shouldOverrideUrlLoading(WebView renderer, WebResourceRequest request) { return true; }
                    @Override public WebResourceResponse shouldInterceptRequest(WebView renderer, WebResourceRequest request) {
                        return new WebResourceResponse("text/plain", "UTF-8", 403, "Forbidden", Collections.emptyMap(), new java.io.ByteArrayInputStream(new byte[0]));
                    }
                    @Override public void onPageFinished(WebView renderer, String url) {
                        if (owner != generation || renderer != view || ready) return;
                        ready = true;
                        for (String id : new ArrayList<>(pending.keySet())) run(id);
                    }
                    @Override public boolean onRenderProcessGone(WebView renderer, RenderProcessGoneDetail detail) {
                        if (owner == generation && renderer == view) reset("Sandbox renderer exited");
                        return true;
                    }
                });
                view.loadDataWithBaseURL("https://www.youtube.com/", "<!doctype html><meta http-equiv='Content-Security-Policy' content=\"default-src 'none'; script-src 'unsafe-eval' 'unsafe-inline'; connect-src 'none'\"><title></title>", "text/html", "UTF-8", null);
            }
            final long owner = generation;
            String id = UUID.randomUUID().toString();
            Request request = new Request(code, done);
            request.timeout = () -> {
                if (owner == generation && pending.containsKey(id)) reset("Player script timed out");
            };
            pending.put(id, request);
            ui.postDelayed(request.timeout, 15000);
            if (ready) run(id);
        });
    }
    private static void run(String id) {
        Request request = pending.get(id);
        if (view == null || !ready || request == null || request.sent) return;
        request.sent = true;
        view.evaluateJavascript("Promise.resolve().then(()=>(0,eval)(" + JSONObject.quote(request.code) + ")).then(value=>FoliaSandboxResult.complete(" + JSONObject.quote(id) + ",JSON.stringify({value})),()=>FoliaSandboxResult.complete(" + JSONObject.quote(id) + ",JSON.stringify({error:'Player script failed'})))", null);
    }
}
