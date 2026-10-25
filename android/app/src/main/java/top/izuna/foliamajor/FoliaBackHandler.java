package top.izuna.foliamajor;

import androidx.activity.BackEventCompat;
import androidx.activity.OnBackPressedCallback;
import androidx.appcompat.app.AppCompatActivity;
import com.getcapacitor.JSObject;

// Intercept only application navigation; at the root Android owns the predictive home transition.
public final class FoliaBackHandler {
    public interface Listener { void onBack(JSObject event); }
    private final OnBackPressedCallback callback;
    private final android.view.View viewport;
    private boolean nativeViewport = true, transforming;
    private float initialScaleX, initialScaleY, initialX, initialY;
    private android.animation.ValueAnimator restoring;
    private android.view.View backdrop;
    private void removeBackdrop() {
        if (backdrop != null && backdrop.getParent() instanceof android.view.ViewGroup) {
            ((android.view.ViewGroup)backdrop.getParent()).removeView(backdrop);
        }
        backdrop = null;
    }

    private void begin() {
        restore(false);
        if (!nativeViewport || !(viewport.getParent() instanceof android.view.ViewGroup)) return;
        android.view.ViewGroup parent = (android.view.ViewGroup)viewport.getParent();
        // Preserve the page's native clear colour at the exposed edges, including transparent windows.
        backdrop = new android.view.View(viewport.getContext());
        android.graphics.drawable.Drawable background = viewport.getBackground();
        if (background != null && background.getConstantState() != null) backdrop.setBackground(background.getConstantState().newDrawable());
        else backdrop.setBackgroundColor(android.graphics.Color.rgb(9, 9, 11));
        backdrop.setImportantForAccessibility(android.view.View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        android.view.ViewGroup.LayoutParams original = viewport.getLayoutParams();
        parent.addView(backdrop, parent.indexOfChild(viewport), new android.view.ViewGroup.LayoutParams(original.width, original.height));
        initialScaleX = viewport.getScaleX(); initialScaleY = viewport.getScaleY();
        initialX = viewport.getTranslationX(); initialY = viewport.getTranslationY();
        transforming = true;
    }
    private void progress(BackEventCompat event) {
        if (!transforming) return;
        float p = Math.max(0, Math.min(1, event.getProgress()));
        float direction = event.getSwipeEdge() == BackEventCompat.EDGE_RIGHT ? -1 : 1;
        float distance = Math.min(viewport.getWidth() * .08f, 48 * viewport.getResources().getDisplayMetrics().density);
        viewport.setTranslationX(initialX + direction * p * distance);
        viewport.setScaleX(initialScaleX * (1 - .04f * p));
        viewport.setScaleY(initialScaleY * (1 - .04f * p));
    }
    private void restore(boolean animate) {
        if (restoring != null) { android.animation.ValueAnimator previous = restoring; restoring = null; previous.cancel(); }
        if (!transforming) return;
        float x = viewport.getTranslationX(), sx = viewport.getScaleX(), sy = viewport.getScaleY();
        if (!animate) {
            viewport.setTranslationX(initialX); viewport.setTranslationY(initialY);
            viewport.setScaleX(initialScaleX); viewport.setScaleY(initialScaleY);
            transforming = false; removeBackdrop();
            return;
        }
        restoring = android.animation.ValueAnimator.ofFloat(0, 1);
        restoring.setDuration(180);
        restoring.setInterpolator(new android.view.animation.PathInterpolator(.2f, 0, 0, 1));
        restoring.addUpdateListener(value -> {
            float p = (Float)value.getAnimatedValue();
            viewport.setTranslationX(x + (initialX - x) * p);
            viewport.setScaleX(sx + (initialScaleX - sx) * p);
            viewport.setScaleY(sy + (initialScaleY - sy) * p);
        });
        restoring.addListener(new android.animation.AnimatorListenerAdapter() {
            @Override public void onAnimationEnd(android.animation.Animator animator) {
                if (restoring != animator) return;
                restoring = null; transforming = false; removeBackdrop();
            }
        });
        restoring.start();
    }
    public void close() { restore(false); callback.remove(); }

    public FoliaBackHandler(AppCompatActivity activity, android.view.View viewport, Listener listener) {
        this.viewport = viewport;
        callback = new OnBackPressedCallback(false) {
            @Override public void handleOnBackStarted(BackEventCompat event) {
                begin();
                listener.onBack(payload("start", event).put("nativeViewport", transforming));
            }
            @Override public void handleOnBackProgressed(BackEventCompat event) {
                progress(event);
                if (!transforming) listener.onBack(payload("progress", event).put("nativeViewport", false));
            }
            @Override public void handleOnBackCancelled() {
                boolean handled = transforming; restore(true);
                listener.onBack(new JSObject().put("phase", "cancel").put("progress", 0).put("nativeViewport", handled));
            }
            @Override public void handleOnBackPressed() {
                boolean handled = transforming; restore(true);
                listener.onBack(new JSObject().put("phase", "commit").put("progress", 1).put("nativeViewport", handled));
            }
        };
        activity.getOnBackPressedDispatcher().addCallback(activity, callback);
    }

    private static JSObject payload(String phase, BackEventCompat event) {
        return new JSObject().put("phase", phase).put("progress", event.getProgress())
            .put("edge", event.getSwipeEdge()).put("touchX", event.getTouchX()).put("touchY", event.getTouchY());
    }

    public void setEnabled(boolean enabled, boolean nativeViewport) {
        this.nativeViewport = nativeViewport;
        callback.setEnabled(enabled);
    }
}
