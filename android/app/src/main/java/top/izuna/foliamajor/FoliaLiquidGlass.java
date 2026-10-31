package top.izuna.foliamajor;

import android.graphics.RenderEffect;
import android.graphics.RuntimeShader;
import android.os.Build;
import android.view.Choreographer;
import android.webkit.WebView;
import com.getcapacitor.JSObject;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import org.json.JSONArray;
import org.json.JSONObject;

// Kyant's AGSL optics on a single native WebView output: no capture, bitmap or repeated View.draw.
final class FoliaLiquidGlass implements AutoCloseable {
    private final WebView view;
    private RuntimeShader shader;
    private JSObject pending;
    private boolean scheduled;
    private boolean closed;
    private float[] previous;
    private final Choreographer.FrameCallback frame = time -> {
        scheduled = false;
        if (closed) return;
        JSObject latest = pending;
        pending = null;
        if (latest != null) apply(latest);
    };

    FoliaLiquidGlass(WebView view) { this.view = view; }

    boolean update(JSObject options) {
        if (closed || Build.VERSION.SDK_INT < 33) return false;
        try {
            if (shader == null) {
                try (InputStream input = view.getContext().getAssets().open("shaders/kyantGlass.agsl")) {
                    shader = new RuntimeShader(new String(input.readAllBytes(), StandardCharsets.UTF_8));
                }
            }
            pending = options;
            if (!scheduled) { scheduled = true; Choreographer.getInstance().postFrameCallback(frame); }
            return true;
        } catch (Exception failure) {
            android.util.Log.e("FoliaLiquidGlass", "Cannot initialize Kyant optics", failure);
            return false;
        }
    }

    private void apply(JSObject options) {
        if (Build.VERSION.SDK_INT < 33 || shader == null) return;
        try {
            JSONArray surfaces = options.optJSONArray("surfaces");
            float cssWidth = (float)options.optDouble("viewportWidth", 0);
            if (cssWidth <= 0 || view.getWidth() <= 0) return;
            float scale = view.getWidth() / cssWidth;
            int count = surfaces == null ? 0 : Math.min(8, surfaces.length());
            float[] rectangles = new float[32];
            float[] parameters = new float[16];
            float[] geometry = new float[32];
            float[] signature = new float[52];
            float left = Float.POSITIVE_INFINITY, top = Float.POSITIVE_INFINITY;
            float right = Float.NEGATIVE_INFINITY, bottom = Float.NEGATIVE_INFINITY;
            for (int index = 0; index < count; index++) {
                JSONObject surface = surfaces.getJSONObject(index);
                int r = index * 4, p = index * 2;
                rectangles[r] = (float)surface.getDouble("x") * scale;
                rectangles[r + 1] = (float)surface.getDouble("y") * scale;
                rectangles[r + 2] = (float)surface.getDouble("width") * scale;
                rectangles[r + 3] = (float)surface.getDouble("height") * scale;
                left = Math.min(left, rectangles[r]); top = Math.min(top, rectangles[r + 1]);
                right = Math.max(right, rectangles[r] + rectangles[r + 2]);
                bottom = Math.max(bottom, rectangles[r + 1] + rectangles[r + 3]);
                parameters[p] = (float)surface.getDouble("radius") * scale;
                parameters[p + 1] = (float)surface.optDouble("opacity", 1);
                float halfWidth = rectangles[r + 2] * 0.5f, halfHeight = rectangles[r + 3] * 0.5f;
                float halfMin = Math.min(halfWidth, halfHeight);
                float radius = Math.min(parameters[p], halfMin);
                geometry[r] = halfWidth; geometry[r + 1] = halfHeight;
                geometry[r + 2] = Math.min(7f * scale, halfMin * 0.45f);
                geometry[r + 3] = Math.min(radius * 1.5f, halfMin);
            }
            System.arraycopy(rectangles, 0, signature, 0, 32);
            System.arraycopy(parameters, 0, signature, 32, 16);
            signature[48] = count; signature[49] = scale;
            signature[50] = view.getWidth(); signature[51] = view.getHeight();
            if (Arrays.equals(signature, previous)) return;
            previous = signature;
            if (count == 0) { view.setRenderEffect(null); return; }
            shader.setFloatUniform("glassRects", rectangles);
            shader.setFloatUniform("glassParams", parameters);
            shader.setFloatUniform("surfaceCount", count);
            shader.setFloatUniform("pixelScale", scale);
            shader.setFloatUniform("viewport", view.getWidth(), view.getHeight());
            shader.setFloatUniform("opticalBounds", left, top, right, bottom);
            shader.setFloatUniform("opticalGeometry", geometry);
            view.setRenderEffect(RenderEffect.createRuntimeShaderEffect(shader, "content"));
        } catch (Exception failure) {
            previous = null;
            android.util.Log.e("FoliaLiquidGlass", "Cannot update optical surfaces", failure);
        }
    }

    @Override public void close() {
        closed = true; pending = null;
        if (scheduled) Choreographer.getInstance().removeFrameCallback(frame);
        scheduled = false;
        if (Build.VERSION.SDK_INT >= 31) view.setRenderEffect(null);
    }
}
