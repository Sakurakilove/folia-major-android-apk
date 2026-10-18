package top.izuna.foliamajor;

import android.webkit.WebView;
import androidx.appcompat.app.AppCompatActivity;
import com.getcapacitor.*;
import com.getcapacitor.cordova.*;
import org.apache.cordova.*;
import java.util.*;
import androidx.activity.result.*;
import androidx.activity.result.contract.ActivityResultContract;
import androidx.annotation.NonNull;

// Each trusted auxiliary renderer has its own Capacitor message channel and plugin instances.
final class FoliaSecondaryBridge extends Bridge {
    private List<ActivityResultLauncher<?>> registrations;
    @Override public <I, O> ActivityResultLauncher<I> registerForActivityResult(@NonNull ActivityResultContract<I, O> contract, @NonNull ActivityResultCallback<O> callback) {
        ActivityResultLauncher<I> launcher = getActivity().getActivityResultRegistry().register("folia-aux-" + UUID.randomUUID(), contract, callback);
        if (registrations == null) registrations = new ArrayList<>();
        registrations.add(launcher); return launcher;
    }
    @Override public void onDestroy() {
        if (registrations != null) for (ActivityResultLauncher<?> launcher : registrations) launcher.unregister();
        super.onDestroy();
    }
    private FoliaSecondaryBridge(AppCompatActivity activity, WebView view, MockCordovaInterfaceImpl cordova,
            MockCordovaWebViewImpl mock, CordovaPreferences preferences, CapConfig config) {
        super(activity, view, List.of(FoliaRuntimePlugin.class), cordova, mock.getPluginManager(), preferences, config);
        setCordovaWebView(mock);
        if (view instanceof CapacitorWebView) ((CapacitorWebView)view).setBridge(this);
    }
    static FoliaSecondaryBridge create(MainActivity activity, WebView view) {
        ConfigXmlParser parser = new ConfigXmlParser(); parser.parse(activity);
        MockCordovaInterfaceImpl cordova = new MockCordovaInterfaceImpl(activity);
        MockCordovaWebViewImpl mock = new MockCordovaWebViewImpl(activity);
        mock.init(cordova, parser.getPluginEntries(), parser.getPreferences(), view);
        cordova.onCordovaInit(mock.getPluginManager());
        return new FoliaSecondaryBridge(activity, view, cordova, mock, parser.getPreferences(), activity.getBridge().getConfig());
    }
    String bootstrapScript() throws Exception {
        return JSExport.getGlobalJS(getActivity(), false, false) + "\n" + JSExport.getBridgeJS(getActivity()) + "\n" +
            JSExport.getPluginJS(List.of(getPlugin("FoliaRuntime"))) + "\nwindow.WEBVIEW_SERVER_URL='https://localhost';";
    }
}
