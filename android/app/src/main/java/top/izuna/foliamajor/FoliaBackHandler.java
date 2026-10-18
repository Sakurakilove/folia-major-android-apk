package top.izuna.foliamajor;

import androidx.activity.BackEventCompat;
import androidx.activity.OnBackPressedCallback;
import androidx.appcompat.app.AppCompatActivity;
import com.getcapacitor.JSObject;

// Intercept only application navigation; at the root Android owns the predictive home transition.
public final class FoliaBackHandler {
    public interface Listener { void onBack(JSObject event); }
    private final OnBackPressedCallback callback;

    public FoliaBackHandler(AppCompatActivity activity, Listener listener) {
        callback = new OnBackPressedCallback(false) {
            @Override public void handleOnBackStarted(BackEventCompat event) {
                listener.onBack(payload("start", event));
            }
            @Override public void handleOnBackProgressed(BackEventCompat event) {
                listener.onBack(payload("progress", event));
            }
            @Override public void handleOnBackCancelled() {
                listener.onBack(new JSObject().put("phase", "cancel").put("progress", 0));
            }
            @Override public void handleOnBackPressed() {
                listener.onBack(new JSObject().put("phase", "commit").put("progress", 1));
            }
        };
        activity.getOnBackPressedDispatcher().addCallback(activity, callback);
    }

    private static JSObject payload(String phase, BackEventCompat event) {
        return new JSObject().put("phase", phase).put("progress", event.getProgress())
            .put("edge", event.getSwipeEdge()).put("touchX", event.getTouchX()).put("touchY", event.getTouchY());
    }

    public void setEnabled(boolean enabled) { callback.setEnabled(enabled); }
}
