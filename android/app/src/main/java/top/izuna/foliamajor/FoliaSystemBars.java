package top.izuna.foliamajor;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.Build;
import android.view.View;
import android.view.Window;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsControllerCompat;

// Paint behind Android 15+ transparent bars; MainActivity owns the system/cutout/IME insets once.
final class FoliaSystemBars {
    private static final java.util.WeakHashMap<Activity, BarState> states = new java.util.WeakHashMap<>();
    private static final class BarState {
        final String background; final boolean darkIcons;
        BarState(String background, boolean darkIcons) { this.background = background; this.darkIcons = darkIcons; }
    }
    static void restore(Activity activity) {
        BarState state = states.get(activity);
        apply(activity, state == null ? "#09090b" : state.background, state != null && state.darkIcons);
    }
    static void apply(Activity activity, String background, boolean darkIcons) {
        states.put(activity, new BarState(background, darkIcons));
        int color;
        try { color = Color.parseColor(background); }
        catch (IllegalArgumentException error) { color = darkIcons ? Color.WHITE : Color.rgb(9, 9, 11); }
        Window window = activity.getWindow();
        WindowCompat.setDecorFitsSystemWindows(window, false);
        window.setBackgroundDrawable(new ColorDrawable(color));
        View content = activity.findViewById(android.R.id.content);
        if (content != null) content.setBackgroundColor(color);
        window.setStatusBarColor(Color.TRANSPARENT);
        window.setNavigationBarColor(Color.TRANSPARENT);
        if (Build.VERSION.SDK_INT >= 29) {
            window.setStatusBarContrastEnforced(false);
            window.setNavigationBarContrastEnforced(false);
        }
        WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(window, window.getDecorView());
        controller.setAppearanceLightStatusBars(darkIcons);
        controller.setAppearanceLightNavigationBars(darkIcons);
        if (content != null) androidx.core.view.ViewCompat.requestApplyInsets(content);
    }
}
