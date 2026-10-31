package top.izuna.foliamajor;

import java.io.IOException;
import java.security.SecureRandom;
import java.security.UnrecoverableKeyException;
import java.util.Arrays;
import java.util.Base64;
import java.util.Collections;
import java.util.IdentityHashMap;
import java.util.Set;
import java.util.UUID;
import javax.crypto.AEADBadTagException;
import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

// Preserve an unreadable vault before publishing an independently wrapped replacement key.
final class FoliaRuntimeKeys {
    static final class Envelope {
        final String alias;
        final String sealed;
        Envelope(String alias, String sealed) { this.alias = alias; this.sealed = sealed; }
    }

    interface Store {
        Envelope read() throws Exception;
        SecretKey wrappingKey(String alias, boolean create) throws Exception;
        void preserve() throws Exception;
        void commit(Envelope envelope, boolean recovered) throws Exception;
    }

    private FoliaRuntimeKeys() {}

    static byte[] load(Store store) throws Exception {
        Envelope original = store.read();
        if (original != null) {
            try { return unwrap(store, original); }
            catch (Exception firstFailure) {
                if (!isUnrecoverable(firstFailure)) throw firstFailure;
                // Reload the platform key once; a transient system failure must not rotate the vault.
                try { return unwrap(store, original); }
                catch (Exception retryFailure) {
                    if (!isUnrecoverable(retryFailure)) throw retryFailure;
                    store.preserve();
                }
            }
        }
        byte[] key = new byte[32];
        new SecureRandom().nextBytes(key);
        String alias = "folia-runtime-key-v2-" + UUID.randomUUID();
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, store.wrappingKey(alias, true));
        byte[] iv = cipher.getIV();
        byte[] ciphertext = cipher.doFinal(key);
        byte[] envelope = new byte[iv.length + ciphertext.length];
        System.arraycopy(iv, 0, envelope, 0, iv.length);
        System.arraycopy(ciphertext, 0, envelope, iv.length, ciphertext.length);
        Envelope replacement = new Envelope(alias, Base64.getEncoder().encodeToString(envelope));
        if (!Arrays.equals(key, unwrap(store, replacement))) throw new IOException("New runtime key verification failed");
        store.commit(replacement, original != null);
        return key;
    }

    private static byte[] unwrap(Store store, Envelope envelope) throws Exception {
        byte[] bytes;
        try { bytes = Base64.getDecoder().decode(envelope.sealed); }
        catch (IllegalArgumentException invalid) {
            UnrecoverableKeyException failure = new UnrecoverableKeyException("Invalid runtime key envelope encoding");
            failure.initCause(invalid);
            throw failure;
        }
        // 12-byte IV + 32-byte runtime key + 16-byte authentication tag.
        if (bytes.length != 60) throw new UnrecoverableKeyException("Invalid runtime key envelope length");
        SecretKey wrappingKey = store.wrappingKey(envelope.alias, false);
        if (wrappingKey == null) throw new UnrecoverableKeyException("Runtime wrapping key is missing");
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.DECRYPT_MODE, wrappingKey, new GCMParameterSpec(128, bytes, 0, 12));
        byte[] key = cipher.doFinal(bytes, 12, bytes.length - 12);
        if (key.length != 32) throw new UnrecoverableKeyException("Invalid runtime key size");
        return key;
    }

    private static boolean isUnrecoverable(Throwable failure) {
        Set<Throwable> seen = Collections.newSetFromMap(new IdentityHashMap<Throwable, Boolean>());
        for (Throwable current = failure; current != null && seen.add(current); current = current.getCause()) {
            if (current instanceof AEADBadTagException || current instanceof UnrecoverableKeyException
                || current.getClass().getName().equals("android.security.keystore.KeyPermanentlyInvalidatedException")) return true;
        }
        return false;
    }
}
