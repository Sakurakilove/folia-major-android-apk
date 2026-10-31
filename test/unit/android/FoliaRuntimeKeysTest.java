package top.izuna.foliamajor;

import java.io.IOException;
import java.security.ProviderException;
import java.util.Arrays;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;

// Exercise authenticated recovery with real AES-GCM and injected platform/persistence failures.
public final class FoliaRuntimeKeysTest {
    private static void check(boolean condition, String label) {
        if (!condition) throw new AssertionError(label);
    }
    private static SecretKey wrappingKey() throws Exception {
        KeyGenerator generator = KeyGenerator.getInstance("AES"); generator.init(256);
        return generator.generateKey();
    }
    private static final class Store implements FoliaRuntimeKeys.Store {
        FoliaRuntimeKeys.Envelope active;
        FoliaRuntimeKeys.Envelope preserved;
        final Map<String, SecretKey> keys = new HashMap<>();
        int backups;
        int commits;
        int reads;
        boolean failBackup;
        boolean failCommit;
        boolean recovered;
        Exception firstReadFailure;
        Exception secondReadFailure;
        @Override public FoliaRuntimeKeys.Envelope read() { return active; }
        @Override public SecretKey wrappingKey(String alias, boolean create) throws Exception {
            if (!create) {
                reads++;
                if (reads == 1 && firstReadFailure != null) throw firstReadFailure;
                if (reads == 2 && secondReadFailure != null) throw secondReadFailure;
            }
            if (create) { check(!keys.containsKey(alias), "never overwrite old alias"); keys.put(alias, FoliaRuntimeKeysTest.wrappingKey()); }
            return keys.get(alias);
        }
        @Override public void preserve() throws Exception {
            if (failBackup) throw new IOException("disk failure");
            backups++; preserved = active;
        }
        @Override public void commit(FoliaRuntimeKeys.Envelope record, boolean recovered) throws Exception {
            if (failCommit) throw new IOException("commit failure");
            commits++; active = record; this.recovered = recovered;
        }
    }
    private static Store legacy(byte[] runtimeKey) throws Exception {
        Store store = new Store(); SecretKey wrappingKey = wrappingKey();
        store.keys.put("folia-runtime-key", wrappingKey);
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding"); cipher.init(Cipher.ENCRYPT_MODE, wrappingKey);
        byte[] iv = cipher.getIV(); byte[] ciphertext = cipher.doFinal(runtimeKey);
        byte[] envelope = new byte[iv.length + ciphertext.length];
        System.arraycopy(iv, 0, envelope, 0, iv.length);
        System.arraycopy(ciphertext, 0, envelope, iv.length, ciphertext.length);
        store.active = new FoliaRuntimeKeys.Envelope("folia-runtime-key", Base64.getEncoder().encodeToString(envelope));
        return store;
    }
    public static void main(String[] args) throws Exception {
        byte[] original = new byte[32]; Arrays.fill(original, (byte)37);
        Store healthy = legacy(original);
        check(Arrays.equals(FoliaRuntimeKeys.load(healthy), original), "healthy legacy key remains identical");
        check(healthy.backups == 0 && healthy.commits == 0, "healthy vault unchanged");

        Store mismatch = legacy(original);
        FoliaRuntimeKeys.Envelope old = mismatch.active;
        SecretKey wrongKey = wrappingKey(); mismatch.keys.put(old.alias, wrongKey);
        byte[] recovered = FoliaRuntimeKeys.load(mismatch);
        check(!Arrays.equals(recovered, original) && recovered.length == 32, "mismatched key starts with new authenticated key");
        check(mismatch.backups == 1 && mismatch.commits == 1 && mismatch.recovered, "snapshot precedes recovery commit");
        check(mismatch.preserved == old && mismatch.keys.get(old.alias) == wrongKey, "original record and alias retained");
        check(Arrays.equals(FoliaRuntimeKeys.load(mismatch), recovered) && mismatch.backups == 1, "restart reuses recovered key");

        Store missing = legacy(original); missing.keys.clear();
        FoliaRuntimeKeys.load(missing);
        check(!missing.keys.containsKey("folia-runtime-key") && missing.backups == 1, "missing legacy alias never regenerated in place");

        Store badBackup = legacy(original); badBackup.keys.clear(); badBackup.failBackup = true;
        try { FoliaRuntimeKeys.load(badBackup); throw new AssertionError("backup must fail"); }
        catch (IOException expected) { check(badBackup.commits == 0 && badBackup.keys.isEmpty(), "failed backup cannot rotate vault"); }

        Store transientFailure = legacy(original); transientFailure.firstReadFailure = new ProviderException("service unavailable");
        try { FoliaRuntimeKeys.load(transientFailure); throw new AssertionError("transient failure must propagate"); }
        catch (ProviderException expected) { check(transientFailure.backups == 0 && transientFailure.commits == 0, "transient errors do not rotate"); }

        Store oneTimeFailure = legacy(original); oneTimeFailure.firstReadFailure = new javax.crypto.AEADBadTagException();
        check(Arrays.equals(FoliaRuntimeKeys.load(oneTimeFailure), original) && oneTimeFailure.commits == 0, "retry recovers temporary authentication failure");

        Store retryTransient = legacy(original); retryTransient.firstReadFailure = new javax.crypto.AEADBadTagException();
        retryTransient.secondReadFailure = new ProviderException("service unavailable");
        try { FoliaRuntimeKeys.load(retryTransient); throw new AssertionError("retry transient failure must propagate"); }
        catch (ProviderException expected) { check(retryTransient.backups == 0 && retryTransient.commits == 0, "retry transient errors do not rotate"); }

        Store failedCommit = legacy(original); failedCommit.keys.clear(); failedCommit.failCommit = true;
        FoliaRuntimeKeys.Envelope originalRecord = failedCommit.active;
        try { FoliaRuntimeKeys.load(failedCommit); throw new AssertionError("commit must fail"); }
        catch (IOException expected) { check(failedCommit.active == originalRecord && failedCommit.preserved == originalRecord, "failed commit retains original and backup"); }

        Store fresh = new Store(); byte[] freshKey = FoliaRuntimeKeys.load(fresh);
        check(!fresh.recovered && fresh.backups == 0 && Arrays.equals(FoliaRuntimeKeys.load(fresh), freshKey), "fresh install stable without recovery warning");
        System.out.println("Runtime key authentication/recovery checks passed (9 scenarios)");
    }
}
