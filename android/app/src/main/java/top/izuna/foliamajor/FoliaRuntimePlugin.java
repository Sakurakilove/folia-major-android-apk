package top.izuna.foliamajor;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import android.view.WindowManager;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.security.SecureRandom;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipEntry;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import org.json.JSONObject;

// Own Node's lifetime, authenticated RPC and the Android Keystore wrapping key.
@CapacitorPlugin(name = "FoliaRuntime")
public class FoliaRuntimePlugin extends Plugin {
    private FoliaBackHandler backHandler;
    private FoliaVoiceInput voiceInput;
    private final ExecutorService executor = Executors.newCachedThreadPool();
    static HttpURLConnection openProtocol(String target, java.util.Map<String, String> headers) throws Exception {
        return FoliaRuntimeHost.openProtocol(target, headers);
    }
    private final java.util.Map<String, FileOutputStream> binaryStreams = new java.util.concurrent.ConcurrentHashMap<>();

    private File binaryDirectory() {
        File directory = new File(getContext().getFilesDir(), "runtime-data/bridge-binary");
        directory.mkdirs();
        return directory;
    }

    @PluginMethod public void voiceInput(PluginCall call) {
        if (voiceInput == null) { call.reject("Voice activity monitor belongs to the main window"); return; }
        if (call.getData().has("enabled")) call.resolve(voiceInput.setEnabled(Boolean.TRUE.equals(call.getBoolean("enabled"))));
        else call.resolve(voiceInput.status());
    }
    @Override protected void handleOnPause() {
        super.handleOnPause();
        notifyListeners("appVisibility", new JSObject().put("visible", FoliaWindowHost.mainIsFloating()));
    }
    @Override protected void handleOnResume() {
        super.handleOnResume();
        notifyListeners("appVisibility", new JSObject().put("visible", true));
    }
    private volatile boolean closing;
    private final java.util.Set<PluginCall> visualStateRequests = java.util.concurrent.ConcurrentHashMap.newKeySet();
    private final java.util.concurrent.atomic.AtomicLong visualStateIds = new java.util.concurrent.atomic.AtomicLong();
    @PluginMethod public void visualState(PluginCall call) {
        getActivity().runOnUiThread(() -> {
            if (closing || getActivity().isDestroyed() || getActivity().isFinishing()) { call.reject("Renderer host closed"); return; }
            visualStateRequests.add(call);
            try {
                getBridge().getWebView().postVisualStateCallback(visualStateIds.incrementAndGet(), new android.webkit.WebView.VisualStateCallback() {
                    @Override public void onComplete(long requestId) {
                        if (visualStateRequests.remove(call)) call.resolve();
                    }
                });
            } catch (Exception error) { visualStateRequests.remove(call); call.reject(error.getMessage()); }
        });
    }

    @Override protected void handleOnDestroy() {
        closing = true;
        getActivity().runOnUiThread(() -> { if (backHandler != null) backHandler.close(); });
        for (PluginCall request : visualStateRequests) if (visualStateRequests.remove(request)) request.reject("Renderer host closed");
        visualStateRequests.clear();
        if (FoliaPlaybackService.plugin == this) {
            FoliaPlaybackService.plugin = null;
            getContext().stopService(new Intent(getContext(), FoliaPlaybackService.class));
        }
        executor.shutdownNow();
        if (voiceInput != null) voiceInput.close();
        for (String token : binaryStreams.keySet()) {
            FileOutputStream output = binaryStreams.remove(token);
            if (output == null) continue;
            try { output.close(); } catch (IOException error) { android.util.Log.w("FoliaBinary", "Cannot close abandoned upload", error); }
            new File(binaryDirectory(), token + ".bin").delete();
        }
        super.handleOnDestroy();
    }
    @PluginMethod public void localFonts(PluginCall call){
        executor.execute(()->{
            try{
                java.util.Set<String> families=new java.util.TreeSet<>();
                for(String path:new String[]{"/system/etc/fonts.xml","/system/etc/font_fallback.xml","/product/etc/fonts_customization.xml"}){
                    File config=new File(path);if(!config.isFile() || !config.canRead())continue;
                    try(InputStream input=new FileInputStream(config)){
                        org.xmlpull.v1.XmlPullParser parser=android.util.Xml.newPullParser();parser.setInput(input,"UTF-8");
                        for(int event=parser.getEventType();event!=org.xmlpull.v1.XmlPullParser.END_DOCUMENT;event=parser.next()){
                            if(event!=org.xmlpull.v1.XmlPullParser.START_TAG || !(parser.getName().equals("family") || parser.getName().equals("alias")))continue;
                            String name=parser.getAttributeValue(null,"name");if(name!=null && !name.trim().isEmpty())families.add(name);
                        }
                    }
                }
                com.getcapacitor.JSArray fonts=new com.getcapacitor.JSArray();for(String family:families)fonts.put(new JSObject().put("family",family));
                call.resolve(new JSObject().put("fonts",fonts));
            }catch(Exception error){call.reject(error.getMessage());}
        });
    }
    @PluginMethod public void windowDrag(PluginCall call) {
        getActivity().runOnUiThread(() -> {
            try {
                String phase = call.getString("phase", "");
                if (!phase.equals("start") && !phase.equals("move") && !phase.equals("end")) throw new IOException("Invalid window drag phase");
                float x=call.getFloat("x",0f), y=call.getFloat("y",0f);
                if (!Float.isFinite(x) || !Float.isFinite(y)) throw new IOException("Invalid window drag position");
                boolean active=FoliaWindowHost.drag((MainActivity)getActivity(),FoliaWindowHost.windowId(getBridge().getWebView()),phase,x,y);
                call.resolve(new JSObject().put("active",active));
            } catch (Exception error) { call.reject(error.getMessage()); }
        });
    }
    @PluginMethod public void shell(PluginCall call) {
        FoliaShellPlugin root = (FoliaShellPlugin)((MainActivity)getActivity()).getBridge().getPlugin("FoliaShell").getInstance();
        root.execute(call);
    }

    @PluginMethod public void binaryStart(PluginCall call) {
        try {
            String token = java.util.UUID.randomUUID().toString();
            binaryStreams.put(token, new FileOutputStream(new File(binaryDirectory(), token + ".bin")));
            call.resolve(new JSObject().put("token", token));
        } catch (Exception error) { call.reject(error.getMessage()); }
    }

    @PluginMethod public void binaryAppend(PluginCall call) {
        executor.execute(() -> {
            try {
                FileOutputStream output = binaryStreams.get(call.getString("token"));
                if (output == null) throw new IOException("Unknown binary upload");
                String data = call.getString("data", "");
                if (data.length() > 90000) throw new IOException("Binary chunk is too large");
                output.write(Base64.decode(data, Base64.NO_WRAP));
                call.resolve();
            } catch (Exception error) { call.reject(error.getMessage()); }
        });
    }

    @PluginMethod public void binaryFinish(PluginCall call) {
        try {
            String token = call.getString("token");
            FileOutputStream output = binaryStreams.remove(token);
            if (output == null) throw new IOException("Unknown binary upload");
            output.close();
            call.resolve(new JSObject().put("path", new File(binaryDirectory(), token + ".bin").getPath()));
        } catch (Exception error) { call.reject(error.getMessage()); }
    }

    @PluginMethod public void binaryAbort(PluginCall call) {
        try {
            String token = call.getString("token", "");
            if (!token.matches("[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}")) throw new IOException("Invalid binary upload token");
            FileOutputStream output = binaryStreams.remove(token);
            if (output != null) output.close();
            File file = new File(binaryDirectory(), token + ".bin");
            if (file.exists() && !file.delete()) throw new IOException("Cannot remove aborted binary upload");
            call.resolve();
        } catch (Exception error) { call.reject(error.getMessage()); }
    }

    @PluginMethod public void binaryRelease(PluginCall call) {
        try {
            File file = new File(call.getString("path")).getCanonicalFile();
            if (!file.getParentFile().equals(binaryDirectory().getCanonicalFile())) throw new IOException("Invalid binary file");
            if (file.exists() && !file.delete()) throw new IOException("Cannot remove binary file");
            call.resolve();
        } catch (Exception error) { call.reject(error.getMessage()); }
    }

    @Override
    public void load() {
        if (FoliaWindowHost.windowId(getBridge().getWebView()) != 1) return;
        getActivity().runOnUiThread(() -> backHandler = new FoliaBackHandler(getActivity(), getBridge().getWebView(),
            event -> notifyListeners("backGesture", event)));
        voiceInput = new FoliaVoiceInput(getContext(), event -> notifyListeners("voiceInputState", event));
    }

    @PluginMethod
    public void backState(PluginCall call) {
        getActivity().runOnUiThread(() -> {
            if (backHandler != null) backHandler.setEnabled(Boolean.TRUE.equals(call.getBoolean("enabled", false)), Boolean.TRUE.equals(call.getBoolean("nativeViewport", true)));
            call.resolve();
        });
    }

    @PluginMethod public void systemBars(PluginCall call) {
        getActivity().runOnUiThread(() -> {
            FoliaSystemBars.apply(getActivity(), call.getString("background", "#09090b"), Boolean.TRUE.equals(call.getBoolean("darkIcons", false)));
            call.resolve();
        });
    }
    // Compatibility response for older renderer bundles; WebView owns phone glass composition.
    @PluginMethod public void liquidPlayer(PluginCall call) {
        call.resolve(new JSObject().put("active", false));
    }
    @PluginMethod public void start(PluginCall call) {
        executor.execute(() -> {
            try {
                FoliaRuntimeHost.ensureStarted(getContext());
                call.resolve(new JSObject().put("ready", true).put("windowId", FoliaWindowHost.windowId(getBridge().getWebView())));
            } catch (Exception error) { call.reject("Android backend startup failed: " + FoliaRuntimeFiles.describe(error)); }
        });
    }
    @PluginMethod public void invoke(PluginCall call) {
        executor.execute(() -> {
            try {
                JSONObject response = FoliaRuntimeHost.rpc(call.getString("method"), call.getArray("args"), FoliaWindowHost.windowId(getBridge().getWebView()));
                call.resolve(new JSObject().put("result", response.opt("result")));
            } catch (Exception error) { call.reject(error.getMessage()); }
        });
    }

    @PluginMethod
    public void screen(PluginCall call) {
        boolean keep = Boolean.TRUE.equals(call.getBoolean("keepAwake", false));
        getActivity().runOnUiThread(() -> {
            if (keep) getActivity().getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            else getActivity().getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            call.resolve(new JSObject().put("active", keep));
        });
    }

    @PluginMethod
    public void minimize(PluginCall call) {
        getActivity().runOnUiThread(() -> { getActivity().moveTaskToBack(true); call.resolve(); });
    }

    @PluginMethod public void taskbarControls(PluginCall call) {
        FoliaPlaybackService.controls(Boolean.TRUE.equals(call.getBoolean("hasActiveTrack")), Boolean.TRUE.equals(call.getBoolean("canGoPrevious")), Boolean.TRUE.equals(call.getBoolean("canGoNext")));
        call.resolve(new JSObject().put("active", true));
    }
    public void sendTaskbarAction(String action) { notifyListeners("taskbarControl", new JSObject().put("action", action)); }
    public void sendMediaAction(String action, double position) {
        notifyListeners("mediaAction", new JSObject().put("action", action).put("position", position));
    }

    @PluginMethod
    public void playback(PluginCall call) {
        FoliaPlaybackService.plugin = this;
        Intent intent = new Intent(getContext(), FoliaPlaybackService.class)
            .putExtra("playing", call.getBoolean("playing", false))
            .putExtra("title", call.getString("title", "Folia"))
            .putExtra("artist", call.getString("artist", ""))
            .putExtra("position", (long)(call.getDouble("position", 0.0) * 1000))
            .putExtra("duration", (long)(call.getDouble("duration", 0.0) * 1000));
        try {
            if (android.os.Build.VERSION.SDK_INT >= 26) getContext().startForegroundService(intent);
            else getContext().startService(intent);
            call.resolve();
        } catch (Exception error) { call.reject(error.getMessage()); }
    }
}
