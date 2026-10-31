package top.izuna.foliamajor.next

import android.app.*
import android.content.Intent
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.*
import androidx.media3.common.*
import androidx.media3.exoplayer.ExoPlayer

// The native service owns the only output/focus and continues independently of the Flutter scene.
class PlaybackService : Service() {
    inner class LocalBinder : Binder() { val service get() = this@PlaybackService }
    private val binder = LocalBinder()
    private lateinit var player: ExoPlayer
    private lateinit var session: MediaSession
    private val handler = Handler(Looper.getMainLooper())
    private var listener: ((Map<String, Any?>) -> Unit)? = null
    private var uri: String? = null
    private var title = "Folia"
    private var artist = ""
    private var error: String? = null
    private var closed = false
    private var started = false
    private val tick = object : Runnable {
        override fun run() { publish("clock"); if (player.isPlaying && listener != null) handler.postDelayed(this, 1500) }
    }
    override fun onCreate() {
        super.onCreate()
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel("playback", "Folia", NotificationManager.IMPORTANCE_LOW).apply { setSound(null, null) })
        player = ExoPlayer.Builder(this).build().apply {
            setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MUSIC).build(), true)
            setHandleAudioBecomingNoisy(true)
            setWakeMode(C.WAKE_MODE_LOCAL)
            addListener(object : Player.Listener {
                override fun onEvents(p: Player, events: Player.Events) {
                    if (closed) return
                    p.currentMediaItem?.let { item ->
                        uri = item.mediaId; title = item.mediaMetadata.title?.toString() ?: "Folia"
                        artist = item.mediaMetadata.artist?.toString() ?: ""
                    }
                    publish("state")
                    updateSession()
                    handler.removeCallbacks(tick)
                    if (p.isPlaying && listener != null) handler.postDelayed(tick, 1500)
                }
                override fun onPlayerError(failure: PlaybackException) { error = failure.errorCodeName; publish("error") }
            })
        }
        session = MediaSession(this, "Folia native").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() { player.play() }
                override fun onPause() { player.pause() }
                override fun onSeekTo(pos: Long) { player.seekTo(pos) }
                override fun onSkipToNext() { if (player.hasNextMediaItem()) player.seekToNextMediaItem() }
                override fun onSkipToPrevious() { if (player.hasPreviousMediaItem()) player.seekToPreviousMediaItem() }
                override fun onStop() { player.stop(); stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }
            })
            isActive = true
        }
    }
    fun listen(next: ((Map<String, Any?>) -> Unit)?) {
        listener = next; handler.removeCallbacks(tick)
        if (next != null) { publish("state"); if (player.isPlaying) handler.postDelayed(tick,1500) }
    }
    fun command(method: String, args: Map<*, *>?) {
        when (method) {
            "setQueue" -> {
                val items = (args?.get("items") as? List<*>)?.map { value ->
                    val entry = value as Map<*, *>
                    val source = entry["uri"] as String
                    MediaItem.Builder().setMediaId(source).setUri(source).setMediaMetadata(
                        androidx.media3.common.MediaMetadata.Builder().setTitle(entry["title"] as? String).setArtist(entry["artist"] as? String).build()).build()
                } ?: emptyList()
                val prefix = player.mediaItemCount <= items.size && (0 until player.mediaItemCount).all { player.getMediaItemAt(it).mediaId == items[it].mediaId }
                if (prefix) player.addMediaItems(items.drop(player.mediaItemCount))
                else { val current = items.indexOfFirst { it.mediaId == uri }; player.setMediaItems(items, current.coerceAtLeast(0), player.currentPosition) }
            }
            "play" -> {
                uri = args?.get("uri") as? String ?: throw IllegalArgumentException("Missing URI")
                title = args?.get("title") as? String ?: "Folia"
                artist = args?.get("artist") as? String ?: ""
                error = null
                started = true; startForeground(32, notification())
                val index = (0 until player.mediaItemCount).firstOrNull { player.getMediaItemAt(it).mediaId == uri }
                if (index != null) player.seekToDefaultPosition(index)
                else player.setMediaItem(MediaItem.Builder().setMediaId(uri!!).setUri(uri!!).build())
                player.prepare(); player.play()
            }
            "pause" -> player.pause()
            "resume" -> { if (uri != null) { started = true; startForeground(32, notification()); if (player.playbackState == Player.STATE_IDLE) player.prepare(); player.play() } }
            "seek" -> player.seekTo((args?.get("positionMs") as Number).toLong().coerceAtLeast(0))
            else -> throw IllegalArgumentException("Unsupported playback action")
        }
    }
    private fun snapshot(reason: String) = mapOf<String, Any?>(
        "sampledAtMs" to SystemClock.elapsedRealtimeNanos() / 1_000_000.0, "reason" to reason, "uri" to uri, "playing" to player.isPlaying,
        "positionMs" to player.currentPosition, "durationMs" to player.duration.coerceAtLeast(0),
        "speed" to player.playbackParameters.speed.toDouble(), "error" to error)
    private fun publish(reason: String) { listener?.invoke(snapshot(reason)) }
    private fun action(action: String, id: Int): PendingIntent = PendingIntent.getService(this, id,
        Intent(this, PlaybackService::class.java).setAction(action), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    private fun notification(): Notification {
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val playing = ::player.isInitialized && player.isPlaying
        return Notification.Builder(this, "playback").setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title).setContentText(artist).setContentIntent(open).setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC).setOngoing(playing)
            .addAction(Notification.Action.Builder(if (playing) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                getString(if (playing) R.string.pause else R.string.play), action(if (playing) "pause" else "resume", 1)).build())
            .setStyle(Notification.MediaStyle().setMediaSession(session.sessionToken).setShowActionsInCompactView(0)).build()
    }
    private fun updateSession() {
        if (uri == null) return
        session.setMetadata(MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE, title)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, artist).putLong(MediaMetadata.METADATA_KEY_DURATION, player.duration.coerceAtLeast(0)).build())
        session.setPlaybackState(PlaybackState.Builder().setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or PlaybackState.ACTION_SEEK_TO or PlaybackState.ACTION_STOP or PlaybackState.ACTION_SKIP_TO_NEXT or PlaybackState.ACTION_SKIP_TO_PREVIOUS)
            .setState(if (player.isPlaying) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED, player.currentPosition, if (player.isPlaying) player.playbackParameters.speed else 0f).build())
        if (started) getSystemService(NotificationManager::class.java).notify(32, notification())
        if (!player.playWhenReady) stopForeground(STOP_FOREGROUND_DETACH)
    }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) { "pause" -> player.pause(); "resume" -> { started = true; startForeground(32, notification()); player.play() } }
        return START_NOT_STICKY
    }
    override fun onBind(intent: Intent?) = binder
    override fun onDestroy() {
        closed = true; handler.removeCallbacksAndMessages(null); listener = null
        stopForeground(STOP_FOREGROUND_REMOVE); getSystemService(NotificationManager::class.java).cancel(32)
        session.release(); player.release(); super.onDestroy()
    }
}
