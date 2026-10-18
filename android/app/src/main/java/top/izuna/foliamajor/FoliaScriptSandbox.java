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
    private static WebView view;
    private static final Map<String, Consumer<Object>> pending = new HashMap<>();
    static final class Completion {
        @JavascriptInterface public void complete(String id, String result) {
            new Handler(Looper.getMainLooper()).post(() -> {
                Consumer<Object> done = pending.remove(id);
                if (done != null) { try { done.accept(new JSONObject(result)); } catch (Exception error) { done.accept(new JSObject().put("error", "Invalid sandbox result")); } }
            });
        }
    }
    static void evaluate(AppCompatActivity activity, String code, Consumer<Object> done) {
        if (view == null) {
            view = new WebView(activity);
            WebSettings settings = view.getSettings(); settings.setJavaScriptEnabled(true); settings.setBlockNetworkLoads(true);
            settings.setAllowFileAccess(false); settings.setAllowContentAccess(false); settings.setDomStorageEnabled(false);
            settings.setJavaScriptCanOpenWindowsAutomatically(false);
            view.addJavascriptInterface(new Completion(), "FoliaSandboxResult");
            view.setWebViewClient(new WebViewClient() {
                @Override public boolean shouldOverrideUrlLoading(WebView webView, WebResourceRequest request) { return true; }
                @Override public WebResourceResponse shouldInterceptRequest(WebView webView, WebResourceRequest request) {
                    return new WebResourceResponse("text/plain", "UTF-8", 403, "Forbidden", Collections.emptyMap(), new java.io.ByteArrayInputStream(new byte[0]));
                }
                @Override public void onPageFinished(WebView webView, String url) { run(code, done); }
            });
            view.loadDataWithBaseURL("https://www.youtube.com/", "<!doctype html><meta http-equiv='Content-Security-Policy' content=\"default-src 'none'; script-src 'unsafe-eval' 'unsafe-inline'; connect-src 'none'\"><title></title>", "text/html", "UTF-8", null);
        } else run(code, done);
    }
    private static void run(String code, Consumer<Object> done) {
        String id = UUID.randomUUID().toString(); pending.put(id, done);
        view.evaluateJavascript("Promise.resolve().then(()=>(0,eval)(" + JSONObject.quote(code) + ")).then(value=>FoliaSandboxResult.complete(" + JSONObject.quote(id) + ",JSON.stringify({value})),()=>FoliaSandboxResult.complete(" + JSONObject.quote(id) + ",JSON.stringify({error:'Player script failed'})))", null);
        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            Consumer<Object> callback = pending.remove(id);
            if (callback != null) { view.destroy(); view = null; callback.accept(new JSObject().put("error", "Player script timed out")); }
        }, 15000);
    }
}
