package top.izuna.foliamajor;

import android.os.Bundle;
import android.view.View;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;
import com.getcapacitor.BridgeActivity;

// Apply system bar and keyboard insets to the native container.
public class MainActivity extends BridgeActivity {
    private int latestSafeTop;
    void publishWindowInsets(android.webkit.WebView view) {
        view.evaluateJavascript("document.documentElement.style.setProperty('--folia-safe-top',(" + latestSafeTop + "/(window.devicePixelRatio||1))+'px')", null);
    }

    private final android.os.Handler displayHandler=new android.os.Handler(android.os.Looper.getMainLooper());
    private final Runnable displayNotification=()->{
        if(!FoliaRuntimeHost.isReady())return;
        new Thread(()->{
            try{FoliaRuntimeHost.rpc("_androidDisplaysChanged",new org.json.JSONArray(),1);}
            catch(Exception error){android.util.Log.w("FoliaDisplays","Cannot report display change",error);}
        },"Folia displays").start();
    };
    private final android.hardware.display.DisplayManager.DisplayListener displayListener=new android.hardware.display.DisplayManager.DisplayListener(){
        private void changed(){displayHandler.removeCallbacks(displayNotification);displayHandler.postDelayed(displayNotification,150);}
        @Override public void onDisplayAdded(int id){changed();}
        @Override public void onDisplayRemoved(int id){changed();}
        @Override public void onDisplayChanged(int id){changed();}
    };
    @Override public void onDestroy(){
        getSystemService(android.hardware.display.DisplayManager.class).unregisterDisplayListener(displayListener);
        displayHandler.removeCallbacks(displayNotification);super.onDestroy();
    }
    @Override public void onResume() {
        super.onResume();
        getWindow().getDecorView().post(() -> FoliaSystemBars.restore(this));
        if (getBridge() == null) return;
        boolean restored = FoliaWindowHost.restoreMain(this);
        if (restored || FoliaRuntimeHost.isReady()) new Thread(() -> {
            try {
                if (restored) FoliaRuntimeHost.rpc("_androidMainWindowRestored", new org.json.JSONArray(), 1);
                org.json.JSONObject settings = FoliaRuntimeHost.rpc("getSettings", new org.json.JSONArray(), 1).getJSONObject("result");
                boolean hidden = settings.optBoolean("HIDE_TASKBAR_ICON", false);
                runOnUiThread(() -> {
                    if (isDestroyed() || isFinishing()) return;
                    android.app.ActivityManager manager = getSystemService(android.app.ActivityManager.class);
                    for (android.app.ActivityManager.AppTask task : manager.getAppTasks()) if (task.getTaskInfo().taskId == getTaskId()) task.setExcludeFromRecents(hidden);
                });
            } catch (Exception error) { android.util.Log.w("FoliaWindow", "Cannot restore Android window state", error); }
        }, "Folia window restore").start();
    }
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(FoliaRuntimePlugin.class);
        registerPlugin(FoliaFileSystemPlugin.class);
        registerPlugin(FoliaShellPlugin.class);
        super.onCreate(savedInstanceState);
        FoliaNativeDispatcher.attach(this);
        FoliaSystemBars.apply(this, "#09090b", false);
        getSystemService(android.hardware.display.DisplayManager.class).registerDisplayListener(displayListener,displayHandler);
        if (getBridge() != null) { FoliaWindowHost.attachMain(getBridge().getWebView()); getBridge().getWebView().getSettings().setSupportZoom(false); getBridge().getWebView().getSettings().setBuiltInZoomControls(false); getBridge().getWebView().getSettings().setDisplayZoomControls(false); getBridge().setWebViewClient(new FoliaWebViewClient(getBridge())); }
        View content = findViewById(android.R.id.content);
        ViewCompat.setOnApplyWindowInsetsListener(content, (view, windowInsets) -> {
            Insets insets = windowInsets.getInsets(
                WindowInsetsCompat.Type.systemBars() | WindowInsetsCompat.Type.displayCutout()
                    | WindowInsetsCompat.Type.ime());
            view.setPadding(insets.left, 0, insets.right, insets.bottom);
            latestSafeTop = insets.top;
            if (getBridge() != null) publishWindowInsets(getBridge().getWebView());
            return WindowInsetsCompat.CONSUMED;
        });
        ViewCompat.requestApplyInsets(content);
    }
}
