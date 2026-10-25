package top.izuna.foliamajor;

import android.app.Presentation;
import android.content.Context;
import android.hardware.display.*;
import android.os.*;
import android.service.wallpaper.WallpaperService;
import android.view.*;
import android.webkit.*;
import org.json.*;
import java.util.concurrent.*;

// The desktop OBS renderer receives the same lyric/config/clock feed on a live wallpaper surface.
public final class FoliaWallpaperService extends WallpaperService {
    private static volatile boolean forwardTouch = true;
    static void setTouchForwarding(Context context, boolean enabled) {
        forwardTouch = enabled;
        context.getSharedPreferences("wallpaper", MODE_PRIVATE).edit().putBoolean("forwardTouch", enabled).apply();
    }
    @Override public Engine onCreateEngine() { return new FoliaEngine(); }
    private final class FoliaEngine extends Engine {
        private final Handler ui = new Handler(Looper.getMainLooper());
        private final ExecutorService io = Executors.newSingleThreadExecutor();
        private WebView view;
        private Presentation presentation;
        private VirtualDisplay display;
        private boolean destroyed, rendererGone, visible;
        private int lastFormat,lastWidth,lastHeight;
        @Override public void onCreate(SurfaceHolder holder) { super.onCreate(holder); forwardTouch = getSharedPreferences("wallpaper", MODE_PRIVATE).getBoolean("forwardTouch", true); setTouchEventsEnabled(true); }
        @Override public void onSurfaceChanged(SurfaceHolder holder, int format, int width, int height) {
            if (width < 1 || height < 1) { releaseDisplay(); return; }
            if (display != null && view != null && !rendererGone) {
                display.setSurface(holder.getSurface());
                if (width != lastWidth || height != lastHeight) {
                    display.resize(width, height, getResources().getDisplayMetrics().densityDpi);
                }
                lastFormat=format;lastWidth=width;lastHeight=height;
                return;
            }
            releaseDisplay();lastFormat=format;lastWidth=width;lastHeight=height;rendererGone=false;
            DisplayManager manager = (DisplayManager)getSystemService(Context.DISPLAY_SERVICE);
            display = manager.createVirtualDisplay("Folia live lyrics", width, height, getResources().getDisplayMetrics().densityDpi,
                holder.getSurface(), DisplayManager.VIRTUAL_DISPLAY_FLAG_OWN_CONTENT_ONLY);
            if (display == null) return;
            presentation = new Presentation(FoliaWallpaperService.this, display.getDisplay());
            view = new WebView(presentation.getContext());
            WebSettings settings = view.getSettings(); settings.setJavaScriptEnabled(true); settings.setDomStorageEnabled(true);
            settings.setAllowFileAccess(false); settings.setAllowContentAccess(false); settings.setMediaPlaybackRequiresUserGesture(true);
            view.setWebViewClient(new WebViewClient() {
                @Override public void onPageFinished(WebView renderer, String url) {
                    if (view == renderer && !destroyed) publishVisibility();
                }
                @Override public boolean onRenderProcessGone(WebView renderer,RenderProcessGoneDetail detail){
                    rendererGone=true;releaseDisplay();
                    ui.postDelayed(()->{if(!destroyed && getSurfaceHolder().getSurface().isValid())onSurfaceChanged(getSurfaceHolder(),lastFormat,lastWidth,lastHeight);},1000);
                    return true;
                }
                @Override public boolean shouldOverrideUrlLoading(WebView renderer, WebResourceRequest request) { return true; }
                @Override public WebResourceResponse shouldInterceptRequest(WebView renderer, WebResourceRequest request) { return FoliaWebViewClient.interceptProtocol(request); }
            });
            view.setBackgroundColor(android.graphics.Color.BLACK);
            if (Build.VERSION.SDK_INT >= 35) view.setRequestedFrameRate(60f);
            presentation.setContentView(view); presentation.show();
            if (Build.VERSION.SDK_INT >= 29) getSharedPreferences("wallpaper", MODE_PRIVATE).edit().putInt("activeDisplay", getDisplayContext().getDisplay().getDisplayId()).apply();
            WebView renderer = view;
            io.execute(() -> {
                try {
                    FoliaRuntimeHost.ensureStarted(FoliaWallpaperService.this);
                    JSONObject preferences = FoliaRuntimeHost.rpc("getSettings", new JSONArray(), 1).getJSONObject("result");
                    setTouchForwarding(FoliaWallpaperService.this, preferences.optBoolean("wallpaper_forward_mouse", true));
                    JSONObject response = FoliaRuntimeHost.rpc("setObsBrowserSourceEnabled", new JSONArray().put(true), 1);
                    String url = response.getJSONObject("result").getString("url");
                    ui.post(() -> { if (!destroyed && view == renderer) renderer.loadUrl(android.net.Uri.parse(url).buildUpon().appendQueryParameter("foliaAndroidHost", "wallpaper").build().toString()); });
                } catch (Exception error) { android.util.Log.e("FoliaWallpaper", "Cannot open lyrics renderer", error); }
            });
        }
        private void publishVisibility() {
            if (view == null) return;
            view.evaluateJavascript("window.dispatchEvent(new CustomEvent('folia-android-visibility',{detail:" + visible + "}))", null);
            view.setVisibility(visible ? View.VISIBLE : View.INVISIBLE);
            if (visible) view.onResume(); else view.onPause();
        }
        @Override public void onVisibilityChanged(boolean nextVisible) {
            visible = nextVisible;
            publishVisibility();
        }
        @Override public void onTouchEvent(MotionEvent event) { if (forwardTouch && view != null) view.dispatchTouchEvent(event); }
        private void releaseDisplay() {
            if (view != null) { if(!rendererGone)view.stopLoading();view.destroy();view=null; }
            if (presentation != null) { presentation.dismiss(); presentation = null; }
            if (display != null) { display.release(); display = null; }
        }
        @Override public void onSurfaceDestroyed(SurfaceHolder holder) { releaseDisplay(); super.onSurfaceDestroyed(holder); }
        @Override public void onDestroy() { destroyed = true; releaseDisplay(); io.shutdownNow(); super.onDestroy(); }
    }
}
