package top.izuna.foliamajor;

import android.app.*;
import android.content.*;
import android.graphics.*;
import android.hardware.display.*;
import android.media.Image;
import android.media.ImageReader;
import android.os.*;
import android.view.*;
import android.webkit.*;
import android.widget.*;
import androidx.appcompat.app.AppCompatActivity;
import com.getcapacitor.*;
import org.json.*;
import java.io.*;
import java.nio.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.Consumer;

// Virtual displays keep hidden export renderers composited: WebGL and requestAnimationFrame remain active.
final class FoliaWindowHost {
    private static ViewGroup mainParent;
    private static ViewGroup.LayoutParams mainLayout;
    private static WindowManager mainOverlayManager;
    private static WindowManager.LayoutParams mainOverlayLayout;
    private static int mainIndex;
    private static int restoredWidth, restoredHeight;
    private static boolean mainBlur, mainTransparent;
    private static final Map<Integer, Host> windows = new HashMap<>();
    private static final Map<String, Consumer<Object>> evaluations = new ConcurrentHashMap<>();
    static boolean mainIsFloating() { return mainOverlayManager != null; }
    static void attachMain(WebView view) { view.addJavascriptInterface(new Evaluation(), "FoliaEvaluation"); }
    static boolean restoreMain(MainActivity activity) {
        if (mainOverlayManager == null) return false;
        WebView view = activity.getBridge().getWebView();
        mainOverlayManager.removeView(view); mainOverlayManager = null;
        mainParent.addView(view, mainIndex, mainLayout); mainParent = null; mainLayout = null; view.setVisibility(View.VISIBLE);
        view.evaluateJavascript("delete document.documentElement.dataset.foliaFloating", null);
        return true;
    }
    static int windowId(WebView view) { Object id = view.getTag(); return id instanceof Integer ? (Integer)id : 1; }
    private static final java.util.Map<Integer, float[]> drags = new java.util.HashMap<>();
    static boolean drag(MainActivity activity, int id, String phase, float x, float y) {
        Host host = windows.get(id);
        boolean floating = id == 1 ? mainOverlayManager != null : host != null && (host.dialog != null || host.taskActivity != null);
        if (!floating) { drags.remove(id); return false; }
        WindowManager.LayoutParams attributes = id == 1 ? mainOverlayLayout : hostWindow(host).getAttributes();
        if (phase.equals("start")) { drags.put(id, new float[]{x,y,attributes.x,attributes.y}); return true; }
        float[] origin = drags.get(id);
        if (origin == null) return false;
        float density = activity.getResources().getDisplayMetrics().density;
        int nextX = Math.round(origin[2]+(x-origin[0])*density), nextY = Math.round(origin[3]+(y-origin[1])*density);
        if (id == 1) {
            // Keep enough of the title region on screen to let the user recover the window.
            android.util.DisplayMetrics display = activity.getResources().getDisplayMetrics();
            int handle = Math.round(48*density);
            attributes.x = Math.max(handle-attributes.width,Math.min(display.widthPixels-handle,nextX));
            attributes.y = Math.max(0,Math.min(display.heightPixels-handle,nextY));
            mainOverlayManager.updateViewLayout(activity.getBridge().getWebView(),attributes);
        } else {
            attributes.x=nextX; attributes.y=nextY;host.x=nextX;host.y=nextY;host.positioned=true;hostWindow(host).setAttributes(attributes);
        }
        if (phase.equals("end")) drags.remove(id);
        return true;
    }
    static boolean rendererGone(MainActivity activity,WebView view){
        int id=windowId(view);Host host=windows.get(id);
        new Thread(()->{try{FoliaRuntimeHost.rpc("_androidRendererExited",new JSONArray().put(id),1);}
            catch(Exception error){android.util.Log.w("FoliaWindow","Cannot report renderer exit",error);}},"Folia renderer exit").start();
        android.util.Log.e("FoliaWindow","WebView renderer exited for window "+id);
        if(host!=null){host.renderGone=true;host.close();notifyClosed(id);return true;}
        if(id!=1)return false;
        if(mainOverlayManager!=null){mainOverlayManager.removeView(view);mainOverlayManager=null;mainParent=null;mainLayout=null;}
        else if(view.getParent() instanceof ViewGroup)((ViewGroup)view.getParent()).removeView(view);
        view.destroy();
        new Handler(Looper.getMainLooper()).post(()->{if(!activity.isFinishing() && !activity.isDestroyed())activity.recreate();});
        return true;
    }
    static void closeAuxiliaryWindows(){for(Host host:new ArrayList<>(windows.values()))host.close();}
    static boolean taskTitlebar(int id) { Host host=windows.get(id); return host == null || host.titlebar; }
    private static Window hostWindow(Host host) {
        return host.dialog != null ? host.dialog.getWindow() : host.taskActivity != null ? host.taskActivity.getWindow()
            : host.presentation == null ? null : host.presentation.getWindow();
    }
    private static void excludeTask(FoliaRemoteActivity activity, boolean excluded) {
        android.app.ActivityManager manager=activity.getSystemService(android.app.ActivityManager.class);
        for (android.app.ActivityManager.AppTask task:manager.getAppTasks()) if(task.getTaskInfo().taskId==activity.getTaskId()) task.setExcludeFromRecents(excluded);
    }
    static boolean attachTask(FoliaRemoteActivity activity,int id) {
        Host host=windows.get(id); if(host==null)return false;
        host.taskActivity=activity; excludeTask(activity,host.skipTaskbar); presentTask(host); return true;
    }
    static void resumeTask(int id) {
        Host host=windows.get(id); if(host==null)return;
        if(host.dialog!=null)host.dialog.show();
    }
    static void detachTask(FoliaRemoteActivity activity,int id,boolean changing) {
        Host host=windows.get(id); if(host==null || host.taskActivity!=activity)return;
        host.taskActivity=null;
        if(!changing){host.close();notifyClosed(id);}
    }
    private static void notifyClosed(int id) {
        new Thread(() -> {
            try { FoliaRuntimeHost.rpc("_androidWindowClosed",new JSONArray().put(id),1); }
            catch(Exception error){android.util.Log.w("FoliaWindow","Window close synchronization failed",error);}
        },"Folia window close").start();
    }
    private static void presentTask(Host host) {
        FoliaRemoteActivity activity=host.taskActivity;
        if(host.dialog!=null){host.dialog.dismiss();host.dialog=null;}
        if(host.view.getParent() instanceof ViewGroup)((ViewGroup)host.view.getParent()).removeView(host.view);
        if(host.top){
            // Overlay windows have no task of their own; retain the controller's real task as its Recents entry.
            android.widget.FrameLayout empty=new android.widget.FrameLayout(activity);activity.setContentView(empty);
            presentDialog(host.owner,host); activity.moveTaskToBack(true);
        }else{
            activity.setContentView(host.view);
            Window window=activity.getWindow();window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);
            window.setBackgroundDrawable(new android.graphics.drawable.ColorDrawable(host.transparent?Color.TRANSPARENT:Color.BLACK));
            float density=activity.getResources().getDisplayMetrics().density;
            window.setLayout(Math.round(host.width*density),Math.round(host.height*density));
            if(host.positioned){WindowManager.LayoutParams attributes=window.getAttributes();attributes.x=host.x;attributes.y=host.y;window.setAttributes(attributes);}
            if(host.fullscreen)androidx.core.view.WindowCompat.getInsetsController(window,host.view).hide(androidx.core.view.WindowInsetsCompat.Type.systemBars());
        }
    }
    private static final class Host {
        int id, width, height; WebView view; FoliaSecondaryBridge bridge;
        MainActivity owner; FoliaRemoteActivity taskActivity; boolean skipTaskbar;
        Dialog dialog; Presentation presentation; VirtualDisplay display; ImageReader images; Image latestImage;
        int x,y; boolean positioned;
        boolean renderGone, fullscreen, top, clickThrough, transparent, privileged, titlebar = true;
        void close() {
            if(view!=null && !renderGone)view.stopLoading();if(bridge!=null)bridge.onDestroy();if(view!=null)view.destroy();
            if (dialog != null) dialog.dismiss();
            if (presentation != null) presentation.dismiss();
            if (display != null) display.release();
            if (latestImage != null) latestImage.close();
            if (images != null) images.close();
            windows.remove(id); drags.remove(id);
            if(taskActivity!=null){FoliaRemoteActivity task=taskActivity;taskActivity=null;task.finishAndRemoveTask();}
        }
    }
    private static void observeCancellation(Host host) {
        host.dialog.setOnCancelListener(dialog -> {
            host.close();
            new Thread(() -> {
                try { FoliaRuntimeHost.rpc("_androidWindowClosed", new JSONArray().put(host.id), 1); }
                catch (Exception error) { android.util.Log.w("FoliaWindow", "Window close synchronization failed", error); }
            }, "Folia window close").start();
        });
    }
    private static void presentDialog(MainActivity activity, Host host) {
        if (host.dialog != null) host.dialog.dismiss();
        if (host.view.getParent() instanceof ViewGroup) ((ViewGroup)host.view.getParent()).removeView(host.view);
        Context base = host.top ? activity.getApplicationContext() : activity;
        host.dialog = new Dialog(new android.view.ContextThemeWrapper(base, R.style.AppTheme_FoliaFloating));
        if (!host.titlebar) host.dialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
        host.dialog.setTitle(R.string.app_name);
        host.dialog.getWindow().setType(host.top ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY : WindowManager.LayoutParams.TYPE_APPLICATION);
        host.dialog.setContentView(host.view); host.dialog.setCanceledOnTouchOutside(false); observeCancellation(host); host.dialog.show();
        Window window = host.dialog.getWindow();
        window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);
        window.addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL);
        window.setBackgroundDrawable(new android.graphics.drawable.ColorDrawable(host.transparent ? Color.TRANSPARENT : Color.BLACK));
        host.view.setBackgroundColor(host.transparent ? Color.TRANSPARENT : Color.BLACK);
        float density = activity.getResources().getDisplayMetrics().density;
        window.setLayout(Math.round(host.width*density), Math.round(host.height*density));
        WindowManager.LayoutParams attributes = window.getAttributes();
        if(host.positioned){attributes.x=host.x;attributes.y=host.y;}
        if (host.clickThrough) attributes.flags |= WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
        attributes.alpha = host.clickThrough ? clickThroughOpacity(activity) : 1;
        window.setAttributes(attributes);
        if (host.fullscreen) androidx.core.view.WindowCompat.getInsetsController(window, host.view).hide(androidx.core.view.WindowInsetsCompat.Type.systemBars());
    }
    private static WebResourceRequest exportAssetRequest(WebResourceRequest request){
        String host=request.getUrl().getHost();
        if(host==null || !host.endsWith(".folia-export.localhost"))return request;
        return new WebResourceRequest(){
            @Override public android.net.Uri getUrl(){return request.getUrl().buildUpon().authority("localhost").build();}
            @Override public boolean isForMainFrame(){return request.isForMainFrame();}
            @Override public boolean isRedirect(){return request.isRedirect();}
            @Override public boolean hasGesture(){return request.hasGesture();}
            @Override public String getMethod(){return request.getMethod();}
            @Override public Map<String,String> getRequestHeaders(){return request.getRequestHeaders();}
        };
    }
    private static final class Evaluation {
        @JavascriptInterface public void complete(String id, String answer) {
            Consumer<Object> callback = evaluations.remove(id);
            if (callback != null) {
                try { callback.accept(new JSONTokener(answer).nextValue()); }
                catch (Exception error) { callback.accept(new JSObject().put("error", error.getMessage())); }
            }
        }
    }
    private static void evaluate(WebView view, String code, Consumer<Object> done) {
        String id = UUID.randomUUID().toString(); evaluations.put(id, done);
        view.evaluateJavascript("Promise.resolve().then(()=>{return (0,eval)(" + JSONObject.quote(code) + ");}).then(value=>FoliaEvaluation.complete(" + JSONObject.quote(id) + ",JSON.stringify({value:value===undefined?null:value})),error=>FoliaEvaluation.complete(" + JSONObject.quote(id) + ",JSON.stringify({error:String(error&&error.stack||error)})))", null);
        new Handler(Looper.getMainLooper()).postDelayed(() -> {
            Consumer<Object> pending = evaluations.remove(id);
            if (pending != null) pending.accept(new JSObject().put("error", "Renderer evaluation timed out"));
        }, 180000);
    }
    private static float clickThroughOpacity(android.content.Context context) {
        if (Build.VERSION.SDK_INT >= 31) return Math.max(0,context.getSystemService(android.hardware.input.InputManager.class).getMaximumObscuringOpacityForTouch()-.01f);
        return 1;
    }
    private static JSObject saveCapture(AppCompatActivity activity, Bitmap bitmap) throws Exception {
        File directory = new File(activity.getFilesDir(), "runtime-data/bridge-binary"); directory.mkdirs();
        File png = File.createTempFile("capture-", ".png", directory), raw = File.createTempFile("capture-", ".bgra", directory);
        try (OutputStream output = new FileOutputStream(png)) { bitmap.compress(Bitmap.CompressFormat.PNG, 100, output); }
        int[] pixels = new int[bitmap.getWidth()*bitmap.getHeight()];
        bitmap.getPixels(pixels, 0, bitmap.getWidth(), 0, 0, bitmap.getWidth(), bitmap.getHeight());
        byte[] bytes = new byte[pixels.length*4];
        for (int i=0; i<pixels.length; i++) { int color=pixels[i]; bytes[4*i]=(byte)color; bytes[4*i+1]=(byte)(color>>8); bytes[4*i+2]=(byte)(color>>16); bytes[4*i+3]=(byte)(color>>24); }
        try (OutputStream output = new FileOutputStream(raw)) { output.write(bytes); }
        return new JSObject().put("png",png.getPath()).put("raw",raw.getPath()).put("width",bitmap.getWidth()).put("height",bitmap.getHeight());
    }
    static void execute(AppCompatActivity activity, String method, JSONArray args, Consumer<Object> done, Consumer<String> failed) {
        try {
            MainActivity main = (MainActivity)activity;
            if (method.equals("windowCreate")) {
                JSONObject options = args.getJSONObject(1);
                Host host = new Host(); host.owner=main; host.skipTaskbar=options.optBoolean("skipTaskbar",false); host.id = args.getInt(0); host.width = options.optInt("width", 1280); host.height = options.optInt("height", 720);
                host.width = Math.max(1, Math.min(host.width, 8192)); host.height = Math.max(1, Math.min(host.height, 8192));
                windows.put(host.id, host);
                if (!options.optBoolean("show", true)) {
                    host.images = ImageReader.newInstance(host.width, host.height, PixelFormat.RGBA_8888, 3);
                    DisplayManager manager = (DisplayManager)activity.getSystemService(Context.DISPLAY_SERVICE);
                    host.display = manager.createVirtualDisplay("Folia export " + host.id, host.width, host.height, 160, host.images.getSurface(), DisplayManager.VIRTUAL_DISPLAY_FLAG_OWN_CONTENT_ONLY);
                    if (host.display == null) throw new IOException("Android refused the export display");
                    host.presentation = new Presentation(activity, host.display.getDisplay());
                    host.view = new WebView(host.presentation.getContext());
                    host.presentation.setContentView(host.view);
                    host.presentation.getWindow().setFormat(options.optBoolean("transparent")?PixelFormat.TRANSLUCENT:PixelFormat.OPAQUE);
                    host.presentation.getWindow().addFlags(WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED);
                    host.presentation.getWindow().setBackgroundDrawable(new android.graphics.drawable.ColorDrawable(options.optBoolean("transparent") ? Color.TRANSPARENT : Color.BLACK));
                    host.view.setBackgroundColor(options.optBoolean("transparent") ? Color.TRANSPARENT : Color.BLACK);
                    host.presentation.show();
                    // Drain old frames while retaining the most recent frame for a capture request.
                    host.images.setOnImageAvailableListener(reader -> {
                        Image latest = reader.acquireLatestImage();
                        if (latest != null) { if (host.latestImage != null) host.latestImage.close(); host.latestImage = latest; }
                    }, new Handler(Looper.getMainLooper()));
                } else {
                    host.view = new CapacitorWebView(activity, null);
                    host.transparent = options.optBoolean("transparent"); host.titlebar = options.optBoolean("frame", true);
                    presentDialog(main, host);
                }
                if(Build.VERSION.SDK_INT>=35)host.view.setRequestedFrameRate(60f);
                host.view.setTag(host.id); host.view.addJavascriptInterface(new Evaluation(), "FoliaEvaluation");
                host.privileged = options.optBoolean("privileged", false);
                if (host.privileged) host.bridge = FoliaSecondaryBridge.create(main, host.view);
                else {
                    WebSettings settings = host.view.getSettings(); settings.setJavaScriptEnabled(true); settings.setDomStorageEnabled(true);
                    settings.setAllowFileAccess(false); settings.setAllowContentAccess(false); settings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
                }
                host.view.stopLoading();
                if(options.optString("name").equals("folia-remote")){
                    Intent task=new Intent(activity,FoliaRemoteActivity.class).putExtra("foliaWindowId",host.id)
                        .setData(android.net.Uri.parse("folia-remote://window/"+host.id))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_DOCUMENT|Intent.FLAG_ACTIVITY_MULTIPLE_TASK);
                    activity.startActivity(task);
                }
                done.accept(host.id); return;
            }
            int id = args.optInt(0, 1); Host host = windows.get(id);
            WebView view = id == 1 ? main.getBridge().getWebView() : host == null ? null : host.view;
            if (view == null) throw new IOException("Renderer window is closed");
            Window window = host == null ? activity.getWindow() : hostWindow(host);
            switch (method) {
                case "windowLoad": {
                    String html = args.getString(1);
                    if (host == null) throw new IOException("Cannot replace the main application document");
                    String script = "Object.defineProperty(window,'__foliaAndroidRenderer',{value:true});";
                    if (host.bridge != null) script += host.bridge.bootstrapScript();
                    String injection = "<script>" + script.replace("</script>", "<\\/script>") + "</script>";
                    int head = html.toLowerCase(Locale.ROOT).indexOf("<head>");
                    html = head < 0 ? injection + html : html.substring(0, head + 6) + injection + html.substring(head + 6);
                    String document = html;
                    if (host.bridge != null) view.setWebViewClient(new FoliaWebViewClient(host.bridge) {
                        @Override public void onPageFinished(WebView webView, String url) { super.onPageFinished(webView, url); done.accept(true); }
                    });
                    else view.setWebViewClient(new WebViewClient() {
                        @Override public boolean onRenderProcessGone(WebView renderer,RenderProcessGoneDetail detail){return rendererGone(main,renderer);}
                        @Override public WebResourceResponse shouldInterceptRequest(WebView webView, WebResourceRequest request) {
                            String path = request.getUrl().getPath();
                            if (path != null && path.startsWith("/_capacitor_")) return new WebResourceResponse("text/plain", "UTF-8", 403, "Private application route", java.util.Collections.emptyMap(), new ByteArrayInputStream(new byte[0]));
                            WebResourceResponse response = FoliaWebViewClient.interceptProtocol(request);
                            return response != null ? response : main.getBridge().getLocalServer().shouldInterceptRequest(exportAssetRequest(request));
                        }
                        @Override public boolean shouldOverrideUrlLoading(WebView webView, WebResourceRequest request) { return true; }
                        @Override public void onPageFinished(WebView webView, String url) { done.accept(true); }
                    });
                    android.net.Uri.Builder address = android.net.Uri.parse(host.privileged?"https://localhost/":"https://export-"+id+".folia-export.localhost/").buildUpon();
                    JSONObject query = args.optJSONObject(2);
                    if (query != null) for (java.util.Iterator<String> keys = query.keys(); keys.hasNext();) { String key = keys.next(); address.appendQueryParameter(key, query.optString(key)); }
                    view.loadDataWithBaseURL(address.build().toString(), document, "text/html", "UTF-8", null); return;
                }
                case "windowEvaluate": evaluate(view, args.getString(1), done); return;
                case "windowCapture": {
                    if (host == null || host.images == null) throw new IOException("Capture requires a virtual export display");
                    Bitmap bitmap = Bitmap.createBitmap(host.width, host.height, Bitmap.Config.ARGB_8888);
                    if (Build.VERSION.SDK_INT >= 26) {
                        // Copy the window buffer before display composition so transparent lyric frames retain alpha.
                        PixelCopy.request(host.presentation.getWindow(), bitmap, result -> {
                            if (result != PixelCopy.SUCCESS) { bitmap.recycle(); failed.accept("Android frame capture failed: " + result); return; }
                            try { done.accept(saveCapture(activity, bitmap)); }
                            catch (Exception error) { failed.accept(error.toString()); }
                            finally { bitmap.recycle(); }
                        }, new Handler(Looper.getMainLooper()));
                    } else {
                        Image image = host.latestImage; host.latestImage = null;
                        if (image == null) { bitmap.recycle(); throw new IOException("The export renderer has not produced a frame"); }
                        try {
                            Image.Plane plane = image.getPlanes()[0]; ByteBuffer source = plane.getBuffer();
                            int[] colors = new int[host.width * host.height];
                            for (int y = 0; y < host.height; y++) for (int x = 0; x < host.width; x++) {
                                int offset = y * plane.getRowStride() + x * plane.getPixelStride();
                                int r = source.get(offset)&255, g = source.get(offset+1)&255, b = source.get(offset+2)&255, a = source.get(offset+3)&255;
                                if (a > 0 && a < 255) { r = Math.min(255, (r*255+a/2)/a); g = Math.min(255,(g*255+a/2)/a); b = Math.min(255,(b*255+a/2)/a); }
                                colors[y*host.width+x] = (a<<24)|(r<<16)|(g<<8)|b;
                            }
                            bitmap.setPixels(colors, 0, host.width, 0, 0, host.width, host.height);
                            done.accept(saveCapture(activity, bitmap));
                        } finally { image.close(); bitmap.recycle(); }
                    }
                    return;
                }
                case "windowClose": if (host == null) { if (mainOverlayManager != null) view.setVisibility(View.GONE); activity.moveTaskToBack(true); } else host.close(); break;
                case "windowShow":
                    if(host!=null && host.taskActivity!=null)host.taskActivity.startActivity(new Intent(host.taskActivity,FoliaRemoteActivity.class)
                        .putExtra("foliaWindowId",host.id).setData(host.taskActivity.getIntent().getData()).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT));
                    if(host!=null && host.dialog!=null)host.dialog.show();break;
                case "windowHide": if (host == null) { if (mainOverlayManager != null) view.setVisibility(View.GONE); activity.moveTaskToBack(true); } else {if(host.dialog!=null)host.dialog.hide();if(host.taskActivity!=null)host.taskActivity.moveTaskToBack(true);} break;
                case "windowBounds": {
                    JSONObject bounds = args.getJSONObject(1);
                    if (host == null) throw new IOException("Android manages the main activity bounds");
                    host.width = bounds.optInt("width", host.width); host.height = bounds.optInt("height", host.height);
                    if (host.dialog != null || host.taskActivity != null) {
                        float density = activity.getResources().getDisplayMetrics().density;
                        hostWindow(host).setLayout(Math.round(host.width*density), Math.round(host.height*density));
                    }
                    else { throw new IOException("Choose the export size when creating the renderer"); }
                    break;
                }
                case "windowIsMaximized": {
                    android.util.DisplayMetrics metrics = activity.getResources().getDisplayMetrics();
                    done.accept(mainOverlayManager == null ? !activity.isInMultiWindowMode() : mainOverlayLayout.width >= metrics.widthPixels && mainOverlayLayout.height >= metrics.heightPixels); return;
                }
                case "windowToggleMaximize": {
                    android.util.DisplayMetrics metrics = activity.getResources().getDisplayMetrics();
                    if (host != null) { window.setLayout(metrics.widthPixels,metrics.heightPixels); done.accept(new JSObject().put("maximized",true).put("floating",false)); return; }
                    if (mainOverlayManager == null) {
                        execute(activity,"windowTop",new JSONArray().put(1).put(true), ignored -> {
                            restoredWidth=Math.max(240,Math.round(metrics.widthPixels*.8f)); restoredHeight=Math.max(240,Math.round(metrics.heightPixels*.75f));
                            mainOverlayLayout.width=restoredWidth; mainOverlayLayout.height=restoredHeight;
                            mainOverlayManager.updateViewLayout(view,mainOverlayLayout);
                            done.accept(new JSObject().put("maximized",false).put("floating",true));
                        },failed); return;
                    }
                    boolean maximized=mainOverlayLayout.width >= metrics.widthPixels && mainOverlayLayout.height >= metrics.heightPixels;
                    if (maximized) { mainOverlayLayout.width=restoredWidth>0?restoredWidth:Math.round(metrics.widthPixels*.8f); mainOverlayLayout.height=restoredHeight>0?restoredHeight:Math.round(metrics.heightPixels*.75f); }
                    else { restoredWidth=mainOverlayLayout.width;restoredHeight=mainOverlayLayout.height;mainOverlayLayout.width=metrics.widthPixels;mainOverlayLayout.height=metrics.heightPixels;mainOverlayLayout.x=0;mainOverlayLayout.y=0; }
                    mainOverlayManager.updateViewLayout(view,mainOverlayLayout);
                    done.accept(new JSObject().put("maximized",!maximized).put("floating",true));return;
                }
                case "windowFullscreen": {
                    boolean active = args.getBoolean(1);
                    if (host != null) host.fullscreen = active;
                    androidx.core.view.WindowInsetsControllerCompat control = androidx.core.view.WindowCompat.getInsetsController(window, view);
                    if (active) control.hide(androidx.core.view.WindowInsetsCompat.Type.systemBars()); else control.show(androidx.core.view.WindowInsetsCompat.Type.systemBars());
                    done.accept(active); return;
                }
                case "windowTop": {
                    boolean enabled = args.getBoolean(1);
                    if (enabled && Build.VERSION.SDK_INT >= 23 && !android.provider.Settings.canDrawOverlays(activity)) {
                        activity.startActivity(new Intent(android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION, android.net.Uri.parse("package:" + activity.getPackageName())));
                        throw new IOException("Grant display over other apps permission, then enable floating mode again");
                    }
                    if (host == null) {
                        if (enabled && mainOverlayManager == null) {
                            mainParent = (ViewGroup)view.getParent(); mainIndex = mainParent.indexOfChild(view); mainLayout = view.getLayoutParams();
                            int width = Math.max(320, view.getWidth()), height = Math.max(240, view.getHeight());
                            mainParent.removeView(view);
                            mainOverlayManager = (WindowManager)activity.getSystemService(Context.WINDOW_SERVICE);
                            mainOverlayLayout = new WindowManager.LayoutParams(width, height,
                                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL, PixelFormat.TRANSLUCENT);
                            mainOverlayLayout.gravity = Gravity.TOP | Gravity.START;
                            if(Build.VERSION.SDK_INT>=31 && mainBlur){mainOverlayLayout.flags|=WindowManager.LayoutParams.FLAG_BLUR_BEHIND;
                                mainOverlayLayout.setBlurBehindRadius(Math.round(32*activity.getResources().getDisplayMetrics().density));}
                            mainOverlayManager.addView(view, mainOverlayLayout);
                            view.evaluateJavascript("document.documentElement.dataset.foliaFloating='true'", null);
                            activity.moveTaskToBack(true);
                        } else if (!enabled && mainOverlayManager != null) {
                            mainOverlayManager.removeView(view); mainOverlayManager = null;
                            mainParent.addView(view, mainIndex, mainLayout); mainParent = null; mainLayout = null;
                            view.evaluateJavascript("delete document.documentElement.dataset.foliaFloating", null);
                            activity.startActivity(new Intent(activity, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT));
                        }
                    } else {
                        host.top=enabled;
                        if(host.taskActivity!=null){presentTask(host);if(!enabled)host.taskActivity.startActivity(new Intent(host.taskActivity,FoliaRemoteActivity.class)
                            .putExtra("foliaWindowId",host.id).setData(host.taskActivity.getIntent().getData()).addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT));}
                        else if(host.dialog!=null)presentDialog(main,host);
                    }
                    break;
                }
                case "windowTitlebar": {
                    if(host==null || (host.dialog==null && host.taskActivity==null))throw new IOException("A visible auxiliary window is required");
                    host.titlebar=args.getBoolean(1);
                    if(host.taskActivity!=null)host.taskActivity.recreate();else presentDialog(main,host);break;
                }
                case "windowSkipTaskbar":{
                    if(host==null)throw new IOException("An auxiliary task is required");
                    host.skipTaskbar=args.getBoolean(1);if(host.taskActivity!=null)excludeTask(host.taskActivity,host.skipTaskbar);break;
                }
                case "windowClickThrough": {
                    boolean enabled = args.getBoolean(1);
                    if (host == null && mainOverlayManager != null) {
                        if (enabled) mainOverlayLayout.flags |= WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
                        else mainOverlayLayout.flags &= ~WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
                        mainOverlayLayout.alpha = enabled ? clickThroughOpacity(activity) : 1;
                    mainOverlayManager.updateViewLayout(view, mainOverlayLayout);
                    } else if (host != null && host.dialog != null && host.dialog.getWindow().getAttributes().type == WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY) {
                        WindowManager.LayoutParams attributes = window.getAttributes();
                        if (enabled) attributes.flags |= WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE; else attributes.flags &= ~WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE;
                        attributes.alpha = enabled ? clickThroughOpacity(activity) : 1; window.setAttributes(attributes);
                    } else {
                        if (enabled) throw new IOException("Enable the floating Android window before click-through");
                        window.clearFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE);
                    }
                    if (host != null) host.clickThrough = enabled;
                    break;
                }
                case "windowTransparent": {
                    boolean enabled = args.getBoolean(1);
                    if (enabled && host == null && mainOverlayManager == null) throw new IOException("Transparent mode requires the floating Android window");
                    if (host != null) host.transparent = enabled; else mainTransparent=enabled;
                    view.setBackgroundColor(enabled ? Color.TRANSPARENT : Color.BLACK);
                    window.setBackgroundDrawable(new android.graphics.drawable.ColorDrawable(enabled ? Color.TRANSPARENT : Color.BLACK));
                    break;
                }
                case "windowBlur": {
                    boolean enabled=args.getBoolean(1);
                    if(enabled && Build.VERSION.SDK_INT<31)throw new IOException("Native cross-window blur requires Android 12 or later");
                    if(host==null)mainBlur=enabled;
                    if(Build.VERSION.SDK_INT>=31){
                        int radius=enabled?Math.round(32*activity.getResources().getDisplayMetrics().density):0;
                        if(host==null && mainOverlayManager!=null){
                            if(enabled)mainOverlayLayout.flags|=WindowManager.LayoutParams.FLAG_BLUR_BEHIND;
                            else mainOverlayLayout.flags&=~WindowManager.LayoutParams.FLAG_BLUR_BEHIND;
                            mainOverlayLayout.setBlurBehindRadius(radius);mainOverlayManager.updateViewLayout(view,mainOverlayLayout);
                        }else window.setBackgroundBlurRadius(radius);
                    }
                    boolean transparent=enabled || (host==null?mainTransparent:host.transparent);
                    view.setBackgroundColor(transparent?Color.TRANSPARENT:Color.BLACK);
                    window.setBackgroundDrawable(new android.graphics.drawable.ColorDrawable(transparent?Color.TRANSPARENT:Color.BLACK));break;
                }
                case "windowTheme": {
                    String theme = args.getString(1);
                    androidx.appcompat.app.AppCompatDelegate.setDefaultNightMode(theme.equals("system")
                        ? androidx.appcompat.app.AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM : theme.equals("dark")
                        ? androidx.appcompat.app.AppCompatDelegate.MODE_NIGHT_YES : androidx.appcompat.app.AppCompatDelegate.MODE_NIGHT_NO);
                    boolean dark = theme.equals("dark") || (theme.equals("system") &&
                        (activity.getResources().getConfiguration().uiMode & android.content.res.Configuration.UI_MODE_NIGHT_MASK)
                            == android.content.res.Configuration.UI_MODE_NIGHT_YES);
                    androidx.core.view.WindowInsetsControllerCompat controller = androidx.core.view.WindowCompat.getInsetsController(window, view);
                    controller.setAppearanceLightStatusBars(!dark); controller.setAppearanceLightNavigationBars(!dark); break;
                }
                default: throw new IOException("Unknown native window operation: " + method);
            }
            done.accept(true);
        } catch (Exception error) { failed.accept(error.toString()); }
    }
}
