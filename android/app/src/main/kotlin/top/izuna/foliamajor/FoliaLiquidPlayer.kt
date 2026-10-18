package top.izuna.foliamajor

import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.View
import android.view.Choreographer
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.FrameLayout
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas as ComposeCanvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.horizontalDrag
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.drawscope.drawIntoCanvas
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.caverock.androidsvg.SVG
import com.kyant.backdrop.backdrops.rememberCanvasBackdrop
import com.kyant.backdrop.drawBackdrop
import com.kyant.backdrop.effects.blur
import com.kyant.backdrop.effects.lens
import com.kyant.backdrop.effects.vibrancy
import org.json.JSONObject
import kotlin.math.roundToInt

// Native AndroidLiquidGlass surface. Existing renderer handlers remain the authority for every action.
class FoliaLiquidPlayer(private val plugin: FoliaRuntimePlugin, private val web: WebView) {
    private val parent = plugin.activity.findViewById<ViewGroup>(android.R.id.content)
    private val view = ComposeView(plugin.activity)
    private var payload by mutableStateOf(JSONObject())
    // Read only by the draw phase: refreshing the backdrop never recomposes the controls.
    private var drawFrame by mutableIntStateOf(0)
    private var cropX = 0f
    private var cropY = 0f
    private var ready = false
    private var ticking = false
    private var lastFrameTime = 0L
    private val frameClock = Choreographer.getInstance()
    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(time: Long) {
            ticking = false
            if (closed || view.visibility != View.VISIBLE || !web.isShown || !ready) return
            // Do not let a 120/144 Hz phone double the glass effect's GPU cost.
            if (time - lastFrameTime >= 16_000_000L) { drawFrame++; lastFrameTime = time }
            ticking = true
            frameClock.postFrameCallback(this)
        }
    }
    private var closed = false
    private var geometry = ""
    init {
        view.setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
        view.setContent { Player() }
        view.visibility = View.GONE
        parent.addView(view, FrameLayout.LayoutParams(1, 1))
    }
    fun update(next: JSONObject): Boolean {
        if (!next.optBoolean("visible")) {
            view.visibility = View.GONE
            frameClock.removeFrameCallback(frameCallback); ticking = false; ready = false
            return false
        }
        val cssWidth = next.optDouble("viewportWidth", 0.0)
        if (cssWidth <= 0 || web.width <= 0) return false
        val scale = web.width / cssWidth
        val x = next.optDouble("x") * scale
        val y = next.optDouble("y") * scale
        val width = (next.optDouble("width") * scale).roundToInt().coerceAtLeast(1)
        val height = (next.optDouble("height") * scale).roundToInt().coerceAtLeast(1)
        val key = "$x:$y:$width:$height"
        if (key != geometry) {
            val webAt = IntArray(2); val parentAt = IntArray(2)
            web.getLocationInWindow(webAt); parent.getLocationInWindow(parentAt)
            view.layoutParams = FrameLayout.LayoutParams(width, height).apply {
                leftMargin = (webAt[0] - parentAt[0] + x).roundToInt() - parent.paddingLeft
                topMargin = (webAt[1] - parentAt[1] + y).roundToInt() - parent.paddingTop
            }
        }
        geometry = key
        payload = next
        view.visibility = View.VISIBLE
        cropX = x.toFloat(); cropY = y.toFloat()
        if (!ready) {
            // The web controls must have reached Chromium's compositor before recording its hardware tree.
            web.postVisualStateCallback(0, object : WebView.VisualStateCallback() {
                override fun onComplete(requestId: Long) {
                    if (!closed && view.visibility == View.VISIBLE) { ready = true; startFrames() }
                }
            })
        } else startFrames()
        return true
    }
    private fun startFrames() {
        if (!ticking && !closed && ready) { ticking = true; frameClock.postFrameCallback(frameCallback) }
    }
    fun close() {
        closed = true; frameClock.removeFrameCallback(frameCallback)
        view.disposeComposition(); parent.removeView(view)
    }
    private fun action(name: String, position: Double = 0.0) { plugin.onLiquidPlayerAction(name, position) }

    @Composable private fun Player() {
        val data = payload
        val ink = Color(data.optInt("ink", android.graphics.Color.WHITE))
        val daylight = data.optBoolean("daylight")
        val surface = if (daylight) Color.White else Color(0xFF101216)
        val backdrop = rememberCanvasBackdrop {
            drawRect(surface)
            // Record Chromium's hardware display tree directly into Kyant's GPU effect layer.
            // No software WebView.draw(bitmap), screenshots, readback or stale image cache.
            drawFrame
            if (ready) drawIntoCanvas { canvas ->
                val target = canvas.nativeCanvas
                if (target.isHardwareAccelerated) {
                    val saved = target.save()
                    target.clipRect(0f, 0f, size.width, size.height)
                    target.translate(-cropX, -cropY)
                    web.draw(target)
                    target.restoreToCount(saved)
                }
            }
        }
        Column(Modifier.fillMaxSize().drawBackdrop(
            backdrop = backdrop, shape = { RoundedCornerShape(24.dp) },
            effects = { vibrancy(); blur(5.dp.toPx()); lens(12.dp.toPx(), 18.dp.toPx(), chromaticAberration = false) },
            onDrawSurface = { drawRect(surface.copy(alpha = if (daylight) 0.16f else 0.22f)) }
        ).padding(horizontal = 12.dp, vertical = 8.dp), verticalArrangement = Arrangement.SpaceBetween) {
            Row(Modifier.fillMaxWidth().height(44.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f).padding(start = 4.dp).clickable { action("open") }) {
                    BasicText(data.optString("title"), style = TextStyle(color = ink, fontSize = 14.sp, fontWeight = FontWeight.SemiBold), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    val artist = data.optString("artist")
                    if (artist.isNotEmpty()) BasicText(artist, style = TextStyle(color = ink.copy(alpha = 0.65f), fontSize = 12.sp), maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                Button("prev", ink, surface, data)
                Button("play", ink, surface, data)
                Button("next", ink, surface, data)
            }
            Row(Modifier.fillMaxWidth().height(36.dp), verticalAlignment = Alignment.CenterVertically) {
                Button("primary", ink, surface, data, 36)
                val duration = data.optDouble("duration", 0.0).toFloat().coerceAtLeast(0f)
                val position = data.optDouble("position", 0.0).toFloat().coerceIn(0f, maxOf(0f, duration))
                BasicText(time(position), Modifier.width(36.dp), style = TextStyle(color = ink.copy(alpha = 0.6f), fontSize = 10.sp))
                val progress by animateFloatAsState(if (duration > 0f) position / duration else 0f, tween(if (data.optBoolean("playing")) 900 else 0), label = "playback progress")
                var dragging by remember { mutableStateOf<Float?>(null) }
                val enabled = !data.optBoolean("disabled") && duration > 0f
                ComposeCanvas(Modifier.weight(1f).height(32.dp).semantics {
                    contentDescription = data.optString("seekLabel", "")
                    progressBarRangeInfo = ProgressBarRangeInfo(position, 0f..maxOf(1f, duration))
                    if (enabled) setProgress { action("seek", it.coerceIn(0f, duration).toDouble()); true }
                }.pointerInput(duration, enabled) {
                    if (enabled) awaitEachGesture {
                        val down = awaitFirstDown(requireUnconsumed = false)
                        var target = (down.position.x / size.width).coerceIn(0f, 1f)
                        dragging = target
                        val completed = horizontalDrag(down.id) { change ->
                            target = (change.position.x / size.width).coerceIn(0f, 1f)
                            dragging = target; change.consume()
                        }
                        dragging = null
                        if (completed) action("seek", (target * duration).toDouble())
                    }
                }) {
                    val radius = 3.dp.toPx()
                    drawRoundRect(ink.copy(alpha = 0.15f), topLeft = androidx.compose.ui.geometry.Offset(0f, center.y - radius), size = androidx.compose.ui.geometry.Size(size.width, radius * 2), cornerRadius = androidx.compose.ui.geometry.CornerRadius(radius))
                    drawRoundRect(ink, topLeft = androidx.compose.ui.geometry.Offset(0f, center.y - radius), size = androidx.compose.ui.geometry.Size(size.width * (dragging ?: progress), radius * 2), cornerRadius = androidx.compose.ui.geometry.CornerRadius(radius))
                }
                BasicText(time(duration), Modifier.width(36.dp).padding(start = 4.dp), style = TextStyle(color = ink.copy(alpha = 0.6f), fontSize = 10.sp))
                Button("secondary", ink, surface, data, 36)
            }
        }
    }
    @Composable private fun Button(name: String, ink: Color, surface: Color, data: JSONObject, buttonSize: Int = 44) {
        val button = data.optJSONObject("buttons")?.optJSONObject(name) ?: return
        val enabled = !button.optBoolean("disabled")
        val svg = button.optString("svg")
        val icon = remember(svg) {
            try {
                val bitmap = Bitmap.createBitmap(64, 64, Bitmap.Config.ARGB_8888)
                SVG.getFromString(svg).apply { setDocumentWidth(64f); setDocumentHeight(64f); renderToCanvas(Canvas(bitmap)) }
                bitmap.asImageBitmap()
            } catch (_: Exception) { null }
        }
        val fill = name == "play"
        val color = (if (fill) surface else ink).copy(alpha = if (enabled) 1f else 0.3f)
        Box(Modifier.size(buttonSize.dp).clip(CircleShape).background(if (fill) ink else if (button.optBoolean("active")) ink.copy(alpha = 0.12f) else Color.Transparent)
            .clickable(enabled = enabled, role = Role.Button, onClickLabel = button.optString("label")) { action(name) }
            .semantics { contentDescription = button.optString("label") }, contentAlignment = Alignment.Center) {
            ComposeCanvas(Modifier.size(20.dp)) { if (icon != null) drawImage(icon, dstSize = IntSize(size.width.roundToInt(), size.height.roundToInt()), colorFilter = ColorFilter.tint(color)) }
        }
    }
    private fun time(value: Float): String { val seconds = value.toInt().coerceAtLeast(0); return "%02d:%02d".format(seconds / 60, seconds % 60) }
}
