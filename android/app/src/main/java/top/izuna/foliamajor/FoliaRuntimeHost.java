package top.izuna.foliamajor;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import android.view.WindowManager;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.security.SecureRandom;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipEntry;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import org.json.JSONObject;

// Shared process host lets Android wallpaper and media components restore the backend without an activity.
final class FoliaRuntimeHost {
    private final Context context;
    private FoliaRuntimeHost(Context context) { this.context = context.getApplicationContext(); }
    private Context getContext() { return context; }
    private static boolean launched;
    private static volatile boolean requestedShutdown;
    private static Context applicationContext;
    static boolean isReady() { return port != 0 && startupError == null; }
    private static String bearer;
    private static volatile int port;
    private static volatile String startupError;
    private static Process nodeProcess;
    static HttpURLConnection openProtocol(String target, java.util.Map<String, String> headers) throws Exception {
        if (port == 0) throw new IOException("Node backend is not ready");
        HttpURLConnection connection = (HttpURLConnection)new URL("http://127.0.0.1:" + port + "/protocol?url="
            + java.net.URLEncoder.encode(target, "UTF-8")).openConnection(java.net.Proxy.NO_PROXY);
        connection.setRequestProperty("Authorization", "Bearer " + bearer);
        if (headers.get("Range") != null) connection.setRequestProperty("Range", headers.get("Range"));
        else if (headers.get("range") != null) connection.setRequestProperty("Range", headers.get("range"));
        connection.setConnectTimeout(10000); connection.setReadTimeout(120000);
        return connection;
    }
    private static byte[] readBytes(InputStream input) throws IOException {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        byte[] buffer = new byte[8192];
        int count;
        while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
        return output.toByteArray();
    }

    private byte[] getRuntimeKey() throws Exception {
        KeyStore keyStore = KeyStore.getInstance("AndroidKeyStore");
        keyStore.load(null);
        String alias = "folia-runtime-key";
        if (!keyStore.containsAlias(alias)) {
            KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
            generator.init(new KeyGenParameterSpec.Builder(alias,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
            generator.generateKey();
        }
        SecretKey wrappingKey = (SecretKey)keyStore.getKey(alias, null);
        android.content.SharedPreferences preferences = getContext().getSharedPreferences("runtime-key", Context.MODE_PRIVATE);
        String stored = preferences.getString("sealed", null);
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        if (stored != null) {
            byte[] envelope = Base64.decode(stored, Base64.NO_WRAP);
            byte[] iv = java.util.Arrays.copyOfRange(envelope, 0, 12);
            cipher.init(Cipher.DECRYPT_MODE, wrappingKey, new GCMParameterSpec(128, iv));
            return cipher.doFinal(envelope, 12, envelope.length - 12);
        }
        byte[] key = new byte[32];
        new SecureRandom().nextBytes(key);
        cipher.init(Cipher.ENCRYPT_MODE, wrappingKey);
        byte[] sealed = cipher.doFinal(key);
        ByteArrayOutputStream envelope = new ByteArrayOutputStream();
        envelope.write(cipher.getIV()); envelope.write(sealed);
        if (!preferences.edit().putString("sealed", Base64.encodeToString(envelope.toByteArray(), Base64.NO_WRAP)).commit()) {
            throw new IOException("Cannot persist runtime key");
        }
        return key;
    }

    private static void removeRuntimeTree(File directory) throws IOException {
        if (!directory.exists()) return;
        try (java.util.stream.Stream<java.nio.file.Path> paths = java.nio.file.Files.walk(directory.toPath())) {
            java.util.Iterator<java.nio.file.Path> iterator = paths.sorted(java.util.Comparator.reverseOrder()).iterator();
            while (iterator.hasNext()) java.nio.file.Files.delete(iterator.next());
        }
    }
    private void discardOldRuntimes(File current) {
        File[] entries = getContext().getFilesDir().listFiles();
        if (entries == null) return;
        for (File entry : entries) {
            if (entry.equals(current) || !entry.getName().matches("runtime-[0-9]+\\.[0-9]+\\.[0-9]+(?:-[A-Za-z0-9.-]+)?-[0-9]{13}")) continue;
            if (!new File(entry, ".ready").isFile() || !new File(entry, "main.cjs").isFile()) continue;
            try { removeRuntimeTree(entry); }
            catch (IOException error) { android.util.Log.w("FoliaRuntime", "Cannot remove obsolete runtime files", error); }
        }
    }

    private void extractRuntime(String assetName, File directory) throws Exception {
        File root = directory.getCanonicalFile();
        root.mkdirs();
        try (ZipInputStream zip = new ZipInputStream(getContext().getAssets().open(assetName))) {
            ZipEntry entry;
            byte[] buffer = new byte[65536];
            while ((entry = zip.getNextEntry()) != null) {
                File destination = new File(root, entry.getName()).getCanonicalFile();
                if (!destination.getPath().startsWith(root.getPath() + File.separator)) throw new IOException("Invalid runtime archive");
                if (entry.isDirectory()) { destination.mkdirs(); continue; }
                destination.getParentFile().mkdirs();
                try (FileOutputStream output = new FileOutputStream(destination)) {
                    int read;
                    while ((read = zip.read(buffer)) != -1) output.write(buffer, 0, read);
                }
                if (entry.getName().contains(".so")) destination.setReadOnly();
            }
        }
        File manifest = new File(root, ".folia-runtime-links.json");
        if (manifest.isFile()) {
            JSONObject links;
            try (FileInputStream input = new FileInputStream(manifest)) {
                links = new JSONObject(new String(readBytes(input), StandardCharsets.UTF_8));
            }
            java.util.Iterator<String> keys = links.keys();
            while (keys.hasNext()) {
                String name = keys.next();
                File link = new File(root, name).getCanonicalFile();
                File target = new File(root, links.getString(name)).getCanonicalFile();
                if (!link.getPath().startsWith(root.getPath() + File.separator)
                    || !target.getPath().startsWith(root.getPath() + File.separator) || !target.isFile()) throw new IOException("Invalid runtime link");
                link.getParentFile().mkdirs();
                String relative = link.getParentFile().toPath().relativize(target.toPath()).toString();
                android.system.Os.symlink(relative, link.getPath());
            }
            manifest.delete();
        }
    }

    private File caBundle(File data,File prefix) throws Exception {
        File bundle=new File(data,"tls-ca.pem");
        javax.net.ssl.TrustManagerFactory factory=javax.net.ssl.TrustManagerFactory.getInstance(javax.net.ssl.TrustManagerFactory.getDefaultAlgorithm());
        factory.init((java.security.KeyStore)null);
        try(OutputStream output=new FileOutputStream(bundle)){
            java.nio.file.Files.copy(new File(prefix,"etc/tls/cert.pem").toPath(),output);
            for(javax.net.ssl.TrustManager manager:factory.getTrustManagers())if(manager instanceof javax.net.ssl.X509TrustManager){
                for(java.security.cert.X509Certificate certificate:((javax.net.ssl.X509TrustManager)manager).getAcceptedIssuers()){
                    String pem="\n-----BEGIN CERTIFICATE-----\n"+java.util.Base64.getMimeEncoder(64,new byte[]{10}).encodeToString(certificate.getEncoded())+"\n-----END CERTIFICATE-----\n";
                    output.write(pem.getBytes(java.nio.charset.StandardCharsets.US_ASCII));
                }
            }
        }
        return bundle;
    }
    static void ensureStarted(Context context) throws Exception { applicationContext = context.getApplicationContext(); requestedShutdown = false; new FoliaRuntimeHost(context).start(); }
    private void start() throws Exception {
                File data = new File(getContext().getFilesDir(), "runtime-data");
                synchronized (FoliaRuntimeHost.class) {
                    if (nodeProcess != null && !nodeProcess.isAlive()) { launched = false; startupError = null; port = 0; }
                    if (!launched) {
                        File runtime = new File(getContext().getFilesDir(), "runtime-" + BuildConfig.VERSION_NAME + "-" + getContext().getPackageManager().getPackageInfo(getContext().getPackageName(), 0).lastUpdateTime);
                        File marker = new File(runtime, ".ready");
                        String abi = android.os.Build.SUPPORTED_ABIS[0];
                        File prefix = new File(runtime, "usr");
                        if (!marker.exists()) {
                            removeRuntimeTree(runtime);
                            extractRuntime("node-runtime.zip", runtime);
                            extractRuntime("native-runtime-" + abi + ".zip", prefix);
                            marker.createNewFile();
                        }
                        discardOldRuntimes(runtime);
                        data.mkdirs();
                        new File(data, "ready.json").delete();
                        byte[] nonce = new byte[32];
                        new SecureRandom().nextBytes(nonce);
                        bearer = Base64.encodeToString(nonce, Base64.NO_WRAP);
                        String secret = Base64.encodeToString(getRuntimeKey(), Base64.NO_WRAP);
                        String nativeDirectory = getContext().getApplicationInfo().nativeLibraryDir;
                        ProcessBuilder builder = new ProcessBuilder(new File(nativeDirectory, "libnode-runner.so").getPath(),
                            new File(runtime, "main.cjs").getPath(), data.getPath());
                        builder.directory(data).redirectErrorStream(true);
                        java.util.Map<String, String> environment = builder.environment();
                        environment.put("LD_LIBRARY_PATH", new File(prefix, "lib").getPath() + ":" + nativeDirectory);
                        environment.put("FOLIA_RUNTIME_TOKEN", bearer);
                        environment.put("FOLIA_NATIVE_DISPATCHER", "true");
                        environment.put("FOLIA_RUNTIME_KEY", secret);
                        environment.put("FOLIA_NATIVE_LIB_DIR", nativeDirectory);
                        environment.put("FOLIA_APP_VERSION", BuildConfig.VERSION_NAME);
                        environment.put("FOLIA_LOCALE", getContext().getResources().getConfiguration().getLocales().get(0).toLanguageTag());
                        File addon = new File(runtime, "spotify-addon.node");
                        if (!addon.exists()) android.system.Os.symlink(new File(nativeDirectory, "liblibrespot-addon.so").getPath(), addon.getPath());
                        environment.put("LOX_LIBRESPOT_ADDON_PATH", addon.getPath());
                        environment.put("FOLIA_ANDROID_PYTHON", new File(nativeDirectory, "libpython-runner.so").getPath());
                        environment.put("FOLIA_FFMPEG_PATH", new File(nativeDirectory, "libffmpeg-runner.so").getPath());
                        environment.put("FOLIA_TRANSCODE_FFMPEG_PATH", new File(nativeDirectory, "libffmpeg-runner.so").getPath());
                        environment.put("PYTHONHOME", prefix.getPath());
                        environment.put("FOLIA_ANALYSIS_THREADS", "2");
                        environment.put("OMP_NUM_THREADS", "2");
                        environment.put("OPENBLAS_NUM_THREADS", "2");
                        environment.put("TMPDIR", new File(data, "tmp").getPath());
                        environment.put("SSL_CERT_FILE",caBundle(data,prefix).getPath());
                        environment.merge("NODE_OPTIONS","--use-openssl-ca",(current,extra)->current+" "+extra);
                        environment.put("OPENSSL_MODULES", new File(prefix, "lib/ossl-modules").getPath());
                        final Process launchedProcess = builder.start();
                        nodeProcess = launchedProcess;
                        launched = true;
                        new Thread(() -> {
                            try (BufferedReader logs = new BufferedReader(new InputStreamReader(launchedProcess.getInputStream()))) {
                                String line;
                                while ((line = logs.readLine()) != null) android.util.Log.i("FoliaNode", line);
                                int exit = launchedProcess.waitFor();
                                synchronized (FoliaRuntimeHost.class) { if (nodeProcess == launchedProcess) startupError = "Node runtime stopped (" + exit + ")"; }
                            } catch (Exception error) { synchronized (FoliaRuntimeHost.class) { if (nodeProcess == launchedProcess) startupError = error.getMessage(); } }
                        }, "FoliaNodeLogs").start();
                    }
                }
                File ready = new File(data, "ready.json");
                long deadline = System.currentTimeMillis() + 60000;
                // File existence alone does not mean its JSON has been fully published.
                int readyPort = 0;
                while (startupError == null && System.currentTimeMillis() < deadline) {
                    if (ready.isFile()) {
                        try (FileInputStream input = new FileInputStream(ready)) {
                            String body = new String(readBytes(input), StandardCharsets.UTF_8).trim();
                            if (!body.isEmpty()) readyPort = new JSONObject(body).getInt("port");
                            if (readyPort > 0 && readyPort <= 65535) break;
                        } catch (IOException | org.json.JSONException incomplete) {
                            // Older runtimes may still publish directly; wait for a complete record.
                        }
                    }
                    readyPort = 0;
                    Thread.sleep(100);
                }
                if (startupError != null) throw new IOException(startupError);
                if (readyPort == 0) throw new IOException("Node startup timed out waiting for a valid ready record");
                port = readyPort;
                FoliaNativeDispatcher.start();
    }
    static synchronized void shutdown() throws Exception {
        requestedShutdown = true;
        FoliaNativeDispatcher.stop();
        Process previous = nodeProcess; nodeProcess = null;
        launched = false; port = 0; startupError = null;
        if (previous != null && previous.isAlive()) {
            previous.destroy();
            if (!previous.waitFor(2, java.util.concurrent.TimeUnit.SECONDS)) previous.destroyForcibly();
        }
    }
    static JSONObject rpc(String method, org.json.JSONArray arguments, int windowId) throws Exception {
        HttpURLConnection connection = null;
        try {
                if ((port == 0 || startupError != null) && !requestedShutdown && applicationContext != null) ensureStarted(applicationContext);
                if (port == 0 || startupError != null) throw new IOException("Node backend is not running");
                connection = (HttpURLConnection)new URL("http://127.0.0.1:" + port + "/rpc").openConnection(java.net.Proxy.NO_PROXY);
                connection.setConnectTimeout(10000); connection.setReadTimeout(150000);
                connection.setRequestMethod("POST"); connection.setDoOutput(true);
                connection.setRequestProperty("Authorization", "Bearer " + bearer);
                connection.setRequestProperty("Content-Type", "application/json");
                JSONObject request = new JSONObject().put("method", method).put("args", arguments).put("windowId", windowId);
                try (OutputStream output = connection.getOutputStream()) { output.write(request.toString().getBytes(StandardCharsets.UTF_8)); }
                int status = connection.getResponseCode();
                InputStream input = status < 400 ? connection.getInputStream() : connection.getErrorStream();
                JSONObject response;
                if (input == null) throw new IOException("Runtime " + method + " returned no body (HTTP " + status + ")");
                try (input) {
                    String body = new String(readBytes(input), StandardCharsets.UTF_8).trim();
                    if (body.isEmpty()) throw new IOException("Runtime " + method + " returned an empty body (HTTP " + status + ")");
                    try { response = new JSONObject(body); }
                    catch (org.json.JSONException invalid) { throw new IOException("Runtime " + method + " returned invalid JSON (HTTP " + status + ")", invalid); }
                }
                if (!response.optBoolean("ok")) throw new IOException(response.optString("error", "Runtime request failed"));
            return response;
        } finally { if (connection != null) connection.disconnect(); }
    }
}
