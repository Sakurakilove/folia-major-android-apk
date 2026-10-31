package top.izuna.foliamajor;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.AtomicFile;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.security.KeyStore;
import java.util.UUID;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import org.json.JSONObject;

// Android vault adapter: keep legacy records intact and snapshot credentials before recovery.
final class FoliaRuntimeKeyStore implements FoliaRuntimeKeys.Store {
    private final Context context;
    private final SharedPreferences preferences;
    private final AtomicFile activeFile;

    FoliaRuntimeKeyStore(Context context) {
        this.context = context.getApplicationContext();
        preferences = this.context.getSharedPreferences("runtime-key", Context.MODE_PRIVATE);
        activeFile = new AtomicFile(new File(this.context.getNoBackupFilesDir(), "runtime-key-active-v2.json"));
    }

    private JSONObject readActive() throws Exception {
        if (!activeFile.getBaseFile().exists() && !new File(activeFile.getBaseFile().getPath() + ".bak").exists()) return null;
        return new JSONObject(new String(activeFile.readFully(), StandardCharsets.UTF_8));
    }

    @Override public FoliaRuntimeKeys.Envelope read() throws Exception {
        JSONObject active = readActive();
        if (active != null) return new FoliaRuntimeKeys.Envelope(active.getString("alias"), active.getString("sealed"));
        String legacy = preferences.getString("sealed", null);
        return legacy == null ? null : new FoliaRuntimeKeys.Envelope("folia-runtime-key", legacy);
    }

    @Override public SecretKey wrappingKey(String alias, boolean create) throws Exception {
        KeyStore keys = KeyStore.getInstance("AndroidKeyStore");
        keys.load(null);
        if (create) {
            if (keys.containsAlias(alias)) throw new IOException("Refusing to overwrite an existing wrapping key");
            KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
            generator.init(new KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setKeySize(256).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
            generator.generateKey();
        }
        return (SecretKey)keys.getKey(alias, null);
    }

    @Override public void preserve() throws Exception {
        File root = new File(context.getNoBackupFilesDir(), "runtime-key-recovery");
        if (!root.isDirectory() && !root.mkdirs()) throw new IOException("Cannot create key recovery directory");
        String id = System.currentTimeMillis() + "-" + UUID.randomUUID();
        File staging = new File(root, id + ".pending");
        if (!staging.mkdir()) throw new IOException("Cannot create key recovery snapshot");
        // Capture bytes as-is before the new backend can migrate or replace any inaccessible session.
        byte[] metadata = new JSONObject(preferences.getAll()).toString().getBytes(StandardCharsets.UTF_8);
        try (FileOutputStream output = new FileOutputStream(new File(staging, "key-records.json"))) {
            output.write(metadata);
            output.getFD().sync();
        }
        JSONObject active = readActive();
        if (active != null) {
            try (FileOutputStream output = new FileOutputStream(new File(staging, "key-active-v2.json"))) {
                output.write(active.toString().getBytes(StandardCharsets.UTF_8));
                output.getFD().sync();
            }
        }
        File settings = new File(context.getFilesDir(), "runtime-data/settings.json");
        if (Files.exists(settings.toPath(), java.nio.file.LinkOption.NOFOLLOW_LINKS)) {
            if (!settings.isFile() || Files.isSymbolicLink(settings.toPath())) throw new IOException("Invalid settings file for key recovery");
            try (java.io.InputStream input = Files.newInputStream(settings.toPath());
                 FileOutputStream output = new FileOutputStream(new File(staging, "settings.json"))) {
                byte[] buffer = new byte[65536]; int count;
                while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
                output.getFD().sync();
            }
        }
        File published = new File(root, id);
        if (!staging.renameTo(published)) throw new IOException("Cannot publish key recovery snapshot");
        android.util.Log.w("FoliaRuntimeKeyStore", "Preserved unreadable key records and settings in private recovery snapshot");
    }

    // Keep the active record on disk; a failed SharedPreferences commit can still mutate its memory cache.
    private void writeActive(JSONObject record) throws Exception {
        byte[] bytes = record.toString().getBytes(StandardCharsets.UTF_8);
        FileOutputStream output = activeFile.startWrite();
        try {
            output.write(bytes);
            output.getFD().sync();
            activeFile.finishWrite(output);
            if (!java.util.Arrays.equals(bytes, activeFile.readFully())) throw new IOException("Runtime key record verification failed");
        } catch (Exception failure) {
            activeFile.failWrite(output);
            throw failure;
        }
    }

    @Override public void commit(FoliaRuntimeKeys.Envelope envelope, boolean recovered) throws Exception {
        writeActive(new JSONObject().put("alias", envelope.alias).put("sealed", envelope.sealed).put("recoveryNoticePending", recovered));
    }

    boolean needsRecoveryNotice() {
        synchronized (FoliaRuntimeKeyStore.class) {
            try {
                JSONObject record = readActive();
                return record != null && record.optBoolean("recoveryNoticePending");
            } catch (Exception failure) {
                android.util.Log.w("FoliaRuntimeKeyStore", "Cannot read key recovery notice state", failure);
                return false;
            }
        }
    }
    void acknowledgeRecovery() {
        synchronized (FoliaRuntimeKeyStore.class) {
            try {
                JSONObject record = readActive();
                if (record != null) writeActive(record.put("recoveryNoticePending", false));
            } catch (Exception failure) {
                android.util.Log.w("FoliaRuntimeKeyStore", "Cannot acknowledge key recovery notice", failure);
            }
        }
    }
}
