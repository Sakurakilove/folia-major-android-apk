package top.izuna.foliamajor;

import android.app.Activity;
import android.content.*;
import android.net.Uri;
import android.os.*;
import android.view.*;
import android.widget.*;
import org.json.*;
import org.mozilla.geckoview.*;

// A separate Gecko process owns the interactive account browser; no music-app bridge enters its pages.
public final class FoliaYtmSignInActivity extends androidx.activity.ComponentActivity {
    private GeckoRuntime runtime;
    private GeckoSession session;
    private WebExtension.Port extensionPort;
    private Button done;
    private GeckoView browser;
    private androidx.activity.OnBackPressedCallback back;
    private String requestId, outcome = "closed", agent = "";
    private boolean completed, reading, canGoBack;
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final BroadcastReceiver stop = new BroadcastReceiver() {
        @Override public void onReceive(Context context, Intent intent) { requestCookies("stopped"); }
    };
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        requestId = getIntent().getStringExtra("requestId");
        String profile = getIntent().getStringExtra("profile");
        try {
            java.io.File expected = new java.io.File(getFilesDir(), "runtime-data/ytm-sign-in").getCanonicalFile();
            if (requestId == null || profile == null || !new java.io.File(profile).getCanonicalFile().equals(expected)) throw new IllegalArgumentException("Invalid browser profile");
            expected.mkdirs();
        } catch (Exception error) { finish(); return; }
        LinearLayout layout = new LinearLayout(this); layout.setOrientation(LinearLayout.VERTICAL);
        LinearLayout bar = new LinearLayout(this); bar.setGravity(Gravity.CENTER_VERTICAL);
        TextView origin = new TextView(this); origin.setText("YouTube Music"); origin.setPadding(16, 12, 16, 12);
        bar.addView(origin, new LinearLayout.LayoutParams(0, -2, 1));
        done = new Button(this); done.setText(android.R.string.ok); done.setEnabled(false); done.setOnClickListener(view -> requestCookies("closed")); bar.addView(done);
        Button cancel = new Button(this); cancel.setText(android.R.string.cancel); cancel.setOnClickListener(view -> complete("stopped", new JSONArray())); bar.addView(cancel);
        layout.addView(bar);
        browser = new GeckoView(this); layout.addView(browser, new LinearLayout.LayoutParams(-1, 0, 1)); setContentView(layout);
        ViewCompatInsets.install(layout);
        back = new androidx.activity.OnBackPressedCallback(false) {
            private void restore() { browser.animate().translationX(0).scaleX(1).scaleY(1).setDuration(180).start(); }
            @Override public void handleOnBackStarted(androidx.activity.BackEventCompat event) { browser.animate().cancel(); }
            @Override public void handleOnBackProgressed(androidx.activity.BackEventCompat event) {
                float progress = Math.max(0,Math.min(1,event.getProgress()));
                browser.setTranslationX((event.getSwipeEdge()==1 ? -1 : 1)*48*progress); browser.setScaleX(1-.03f*progress); browser.setScaleY(1-.03f*progress);
            }
            @Override public void handleOnBackCancelled() { restore(); }
            @Override public void handleOnBackPressed() { restore(); if (canGoBack && session != null) session.goBack(); }
        };
        getOnBackPressedDispatcher().addCallback(this,back);
        runtime = GeckoRuntime.create(this, new GeckoRuntimeSettings.Builder().arguments(new String[]{"-profile", profile}).build());
        session = new GeckoSession();
        session.setProgressDelegate(new GeckoSession.ProgressDelegate() {
            @Override public void onPageStart(GeckoSession current, String url) { String host = Uri.parse(url).getHost(); origin.setText(host == null ? "YouTube Music" : host); }
        });
        session.setNavigationDelegate(new GeckoSession.NavigationDelegate() {
            @Override public void onCanGoBack(GeckoSession current, boolean value) { canGoBack = value; back.setEnabled(value); }
        });
        session.open(runtime); browser.setSession(session);
        agent = GeckoSession.getDefaultUserAgent();
        runtime.getWebExtensionController().ensureBuiltIn("resource://android/assets/ytmAuthExtension/", "ytm-auth@folia-major").accept(extension -> {
            extension.setMessageDelegate(new WebExtension.MessageDelegate() {
                @Override public void onConnect(WebExtension.Port port) {
                    if (!"ytm-auth@folia-major".equals(port.sender.webExtension.id)) { port.disconnect(); return; }
                    extensionPort = port;
                    port.setDelegate(new WebExtension.PortDelegate() {
                        @Override public void onPortMessage(Object value, WebExtension.Port source) {
                            if (!(value instanceof JSONObject) || !reading || completed) return;
                            JSONObject message = (JSONObject)value;
                            if ("cookies".equals(message.optString("type"))) complete(outcome, message.optJSONArray("cookies"));
                            else if ("error".equals(message.optString("type"))) complete("stopped", new JSONArray());
                        }
                    });
                    done.setEnabled(true);
                }
            }, "foliaYtmAuth");
        }, error -> { android.util.Log.e("FoliaYtmBrowser", "Cannot initialize the sign-in browser extension", error); complete("stopped", new JSONArray()); });
        IntentFilter filter = new IntentFilter(getPackageName() + ".STOP_YTM_SIGNIN");
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(stop, filter, Context.RECEIVER_NOT_EXPORTED); else registerReceiver(stop, filter);
        ui.postDelayed(() -> requestCookies("stopped"), 10 * 60 * 1000);
        session.loadUri("https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fmusic.youtube.com%2F");
    }
    private void requestCookies(String reason) {
        if (completed || reading) return;
        outcome = reason; reading = true; done.setEnabled(false);
        if (extensionPort == null) { complete("stopped", new JSONArray()); return; }
        try { extensionPort.postMessage(new JSONObject().put("type", "read")); }
        catch (Exception error) { complete("stopped", new JSONArray()); }
        ui.postDelayed(() -> { if (!completed) complete("stopped", new JSONArray()); }, 15000);
    }
    private void complete(String reason, JSONArray cookies) {
        if (completed || requestId == null) return;
        completed = true;
        JSONArray selected = new JSONArray();
        if (cookies != null) for (int i=0; i<Math.min(cookies.length(),256); i++) {
            JSONObject cookie = cookies.optJSONObject(i); if (cookie == null) continue;
            String domain = cookie.optString("domain").toLowerCase(java.util.Locale.ROOT);
            if ((domain.equals("youtube.com") || domain.endsWith(".youtube.com")) && cookie.optString("value").length() <= 8192) selected.put(cookie);
        }
        try {
            JSONObject result = new JSONObject().put("outcome", reason).put("cookies", selected).put("userAgent", agent);
            Runnable deliver = () -> new Thread(() -> {
                try {
                    Bundle data = new Bundle(); data.putString("result", result.toString()); data.putInt("pid", android.os.Process.myPid());
                    getContentResolver().call(Uri.parse("content://" + getPackageName() + ".ytmauth"), "complete", requestId, data);
                } finally { if (runtime != null) runtime.shutdown(); android.os.Process.killProcess(android.os.Process.myPid()); }
            }, "FoliaSignInHandoff").start();
            if (session != null) session.close();
            if (runtime != null) runtime.getStorageController().clearData(StorageController.ClearFlags.ALL).accept(ignored -> deliver.run(), error -> deliver.run());
            else deliver.run();
            finish();
        } catch (Exception error) { android.util.Log.e("FoliaYtmBrowser", "Cannot finish sign-in", error); finish(); }
    }
    @Override public void onDestroy() {
        try { unregisterReceiver(stop); } catch (Exception ignored) { }
        if (!completed && requestId != null) complete("stopped", new JSONArray());
        super.onDestroy();
    }
    private static final class ViewCompatInsets {
        static void install(View view) {
            androidx.core.view.ViewCompat.setOnApplyWindowInsetsListener(view, (target, windowInsets) -> {
                androidx.core.graphics.Insets insets = windowInsets.getInsets(androidx.core.view.WindowInsetsCompat.Type.systemBars() | androidx.core.view.WindowInsetsCompat.Type.ime());
                target.setPadding(insets.left, insets.top, insets.right, insets.bottom); return windowInsets;
            });
        }
    }
}
