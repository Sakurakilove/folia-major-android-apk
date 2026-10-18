package top.izuna.foliamajor;

import android.content.Context;
import android.media.*;
import android.os.*;
import com.getcapacitor.JSObject;
import java.util.*;
import java.util.function.Consumer;

// Android exposes anonymized recording activity; audio focus remains the primary interruption signal.
final class FoliaVoiceInput {
    private final AudioManager audio;
    private final Consumer<JSObject> changed;
    private boolean enabled, active;
    private final AudioManager.AudioRecordingCallback callback = new AudioManager.AudioRecordingCallback() {
        @Override public void onRecordingConfigChanged(List<AudioRecordingConfiguration> configurations) { update(configurations); }
    };
    FoliaVoiceInput(Context context, Consumer<JSObject> changed) {
        this.changed = changed; audio = (AudioManager)context.getSystemService(Context.AUDIO_SERVICE);
        audio.registerAudioRecordingCallback(callback, new Handler(Looper.getMainLooper()));
        update(audio.getActiveRecordingConfigurations());
    }
    private void update(List<AudioRecordingConfiguration> configurations) {
        boolean next = !configurations.isEmpty();
        if (active != next) { active = next; changed.accept(status()); }
    }
    JSObject setEnabled(boolean value) { enabled = value; changed.accept(status()); return status(); }
    JSObject status() { return new JSObject().put("active", active && enabled).put("enabled", enabled).put("supported", true); }
    void close() { audio.unregisterAudioRecordingCallback(callback); }
}
