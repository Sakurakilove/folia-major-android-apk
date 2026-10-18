package top.izuna.foliamajor;

import android.app.*;
import android.content.*;
import android.media.MediaMetadata;
import android.media.session.MediaSession;
import android.media.session.PlaybackState;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;

// Keep active WebView playback associated with Android media controls and a foreground service.
public class FoliaPlaybackService extends Service {
    private MediaSession session;
    private static volatile FoliaPlaybackService instance;
    private static boolean canPrevious = true, canNext = true, hasTrack = true;
    static void controls(boolean active, boolean previous, boolean next) {
        hasTrack = active; canPrevious = previous; canNext = next;
        FoliaPlaybackService current = instance;
        if (current != null) new android.os.Handler(android.os.Looper.getMainLooper()).post(() -> current.getSystemService(NotificationManager.class).notify(32, current.notification()));
    }
    private String title = "Folia";
    private String artist = "";
    private boolean playing;
    private PowerManager.WakeLock wakeLock;
    static volatile FoliaRuntimePlugin plugin;

    @Override
    public void onCreate() {
        super.onCreate(); instance = this;
        wakeLock = getSystemService(PowerManager.class).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Folia:Playback");
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel channel = new NotificationChannel("folia-playback", "Folia", NotificationManager.IMPORTANCE_LOW);
            channel.setSound(null, null);
            getSystemService(NotificationManager.class).createNotificationChannel(channel);
        }
        session = new MediaSession(this, "Folia");
        session.setCallback(new MediaSession.Callback() {
            @Override public void onPlay() { send("play"); }
            @Override public void onPause() { send("pause"); }
            @Override public void onSkipToNext() { send("nexttrack"); }
            @Override public void onSkipToPrevious() { send("previoustrack"); }
            @Override public void onSeekTo(long position) {
                if (plugin != null) plugin.sendMediaAction("seekto", position / 1000.0);
            }
        });
        session.setActive(true);
    }

    private void send(String action) {
        if (plugin != null) plugin.sendMediaAction(action, 0);
    }

    private PendingIntent actionIntent(String action, int id) {
        Intent intent = new Intent(this, FoliaPlaybackService.class).setAction(action);
        return PendingIntent.getService(this, id, intent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    private Notification notification() {
        Notification.Builder builder = Build.VERSION.SDK_INT >= 26 ? new Notification.Builder(this, "folia-playback") : new Notification.Builder(this);
        PendingIntent open = PendingIntent.getActivity(this, 0, new Intent(this, MainActivity.class),
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        builder.setSmallIcon(R.drawable.folia_notification).setContentTitle(title).setContentText(artist)
            .setContentIntent(open).setVisibility(Notification.VISIBILITY_PUBLIC).setOngoing(playing);
        int count = 0; java.util.ArrayList<Integer> compact = new java.util.ArrayList<>();
        if (hasTrack && canPrevious) { builder.addAction(new Notification.Action.Builder(android.R.drawable.ic_media_previous, "Previous", actionIntent("previoustrack", 1)).build()); compact.add(count++); }
        if (hasTrack) {
            builder.addAction(new Notification.Action.Builder(playing ? android.R.drawable.ic_media_pause : android.R.drawable.ic_media_play,
                playing ? "Pause" : "Play", actionIntent(playing ? "pause" : "play", 2)).build()); compact.add(count++);
        }
        if (hasTrack && canNext) { builder.addAction(new Notification.Action.Builder(android.R.drawable.ic_media_next, "Next", actionIntent("nexttrack", 3)).build()); compact.add(count++); }
        int[] indices = new int[compact.size()]; for (int i = 0; i < compact.size(); i++) indices[i] = compact.get(i);
        return builder.setStyle(new Notification.MediaStyle().setMediaSession(session.getSessionToken()).setShowActionsInCompactView(indices)).build();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) { stopSelf(); return START_NOT_STICKY; }
        if (intent.getAction() != null) {
            if (plugin != null) plugin.sendTaskbarAction(intent.getAction().equals("previoustrack") ? "previous" : intent.getAction().equals("nexttrack") ? "next" : "play-pause");
            return START_NOT_STICKY;
        }
        title = intent.getStringExtra("title");
        artist = intent.getStringExtra("artist");
        playing = intent.getBooleanExtra("playing", false);
        // Android 15+ requires a top activity or active foreground service for audio focus.
        // Chromium owns focus for its audio output. A second Java focus client would revoke it. Trying
        // to reacquire both clients in response to each other would repeatedly pause the same player.
        startForeground(32, notification());
        if (playing) {
            if (!wakeLock.isHeld()) wakeLock.acquire();
        } else {
            if (wakeLock.isHeld()) wakeLock.release();
        }
        long position = intent.getLongExtra("position", 0);
        long duration = intent.getLongExtra("duration", 0);
        session.setMetadata(new MediaMetadata.Builder().putString(MediaMetadata.METADATA_KEY_TITLE, title)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, artist).putLong(MediaMetadata.METADATA_KEY_DURATION, duration).build());
        session.setPlaybackState(new PlaybackState.Builder().setActions(PlaybackState.ACTION_PLAY | PlaybackState.ACTION_PAUSE
            | PlaybackState.ACTION_SKIP_TO_NEXT | PlaybackState.ACTION_SKIP_TO_PREVIOUS | PlaybackState.ACTION_SEEK_TO)
            .setState(playing ? PlaybackState.STATE_PLAYING : PlaybackState.STATE_PAUSED, position, playing ? 1 : 0).build());
        startForeground(32, notification());
        if (!playing) stopForeground(false);
        return START_NOT_STICKY;
    }

    @Override public void onDestroy() {
        if (wakeLock.isHeld()) wakeLock.release();
        instance = null; session.release();
        super.onDestroy();
    }
    @Override public IBinder onBind(Intent intent) { return null; }
}
