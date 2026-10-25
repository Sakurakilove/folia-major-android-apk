package top.izuna.foliamajor;

import android.app.*;
import android.content.*;
import android.net.Uri;
import android.os.*;
import android.provider.DocumentsContract;
import android.provider.Settings;
import android.widget.*;
import androidx.activity.result.ActivityResult;
import androidx.core.content.FileProvider;
import com.getcapacitor.*;
import com.getcapacitor.annotation.*;
import java.io.*;
import java.util.*;
import org.json.*;

// Native dialogs retain the desktop's confirmation and file selection semantics.
@CapacitorPlugin(name = "FoliaShell", permissions = { @Permission(alias = "localNetwork", strings = { "android.permission.ACCESS_LOCAL_NETWORK" }) })
public class FoliaShellPlugin extends Plugin {
    private final Map<String, Uri> exportTargets = new java.util.concurrent.ConcurrentHashMap<>();
    private final java.util.concurrent.ExecutorService io = java.util.concurrent.Executors.newFixedThreadPool(2);

    private final List<PluginCall> localNetworkRequests = new ArrayList<>();
    @Override protected void handleOnDestroy() {
        for (PluginCall call : new ArrayList<>(localNetworkRequests)) call.reject("Android permission host was closed");
        localNetworkRequests.clear();
        io.shutdown();
        super.handleOnDestroy();
    }
    @PermissionCallback private void localNetworkPermissionResult(PluginCall ignored) {
        boolean granted = getPermissionState("localNetwork") == PermissionState.GRANTED;
        List<PluginCall> pending = new ArrayList<>(localNetworkRequests); localNetworkRequests.clear();
        for (PluginCall call : pending) {
            if (granted) answer(call, true); else call.reject("Allow local network access in Android app permissions to reach this server");
        }
    }

    @PluginMethod
    public void execute(PluginCall call) {
        getActivity().runOnUiThread(() -> {
            try {
                String method = call.getString("method");
                JSArray arguments = call.getArray("args", new JSArray());
                switch (method) {
                    case "localNetworkPermission": {
                        if (Build.VERSION.SDK_INT < 37 || getPermissionState("localNetwork") == PermissionState.GRANTED) { answer(call, true); break; }
                        localNetworkRequests.add(call);
                        if (localNetworkRequests.size() == 1) requestPermissionForAlias("localNetwork", call, "localNetworkPermissionResult");
                        break;
                    }
                    case "ytmBrowserOpen": {
                        String requestId = call.getString("requestId");
                        if (requestId == null) throw new IOException("Missing native browser request identity");
                        File profile = new File(arguments.getString(0)).getCanonicalFile();
                        File allowed = new File(getContext().getFilesDir(), "runtime-data/ytm-sign-in").getCanonicalFile();
                        if (!profile.equals(allowed)) throw new IOException("Invalid sign-in browser profile");
                        FoliaYtmAuthProvider.registerPending(requestId, call);
                        getActivity().startActivity(new Intent(getContext(), FoliaYtmSignInActivity.class).putExtra("requestId", requestId).putExtra("profile", profile.getPath()));
                        break;
                    }
                    case "ytmBrowserStop": getContext().sendBroadcast(new Intent(getContext().getPackageName() + ".STOP_YTM_SIGNIN").setPackage(getContext().getPackageName())); answer(call, true); break;
                    case "sandboxEvaluate": FoliaScriptSandbox.evaluate(getActivity(), arguments.getString(0), value -> answer(call, value)); break;
                    case "wallpaperTouch": FoliaWallpaperService.setTouchForwarding(getContext(), arguments.getBoolean(0)); answer(call, arguments.getBoolean(0)); break;
                    case "webDebug": android.webkit.WebView.setWebContentsDebuggingEnabled(arguments.getBoolean(0)); answer(call, new JSObject().put("pid", android.os.Process.myPid())); break;
                    case "resolveProxy": {
                        String target = arguments.getString(0);
                        io.execute(() -> {
                            try {
                                answer(call, FoliaNetwork.resolve(target));
                            } catch (Exception error) { call.reject(error.getMessage()); }
                        }); break;
                    }
                    case "messageBox": messageBox(call, arguments.getJSONObject(0)); break;
                    case "openDialog": openDialog(call, arguments.getJSONObject(0)); break;
                    case "hideTaskbar": {
                        boolean hidden = arguments.getBoolean(0);
                        android.app.ActivityManager manager = (android.app.ActivityManager)getContext().getSystemService(Context.ACTIVITY_SERVICE);
                        boolean found = false;
                        for (android.app.ActivityManager.AppTask task : manager.getAppTasks()) if (task.getTaskInfo().taskId == getActivity().getTaskId()) { task.setExcludeFromRecents(hidden); found = true; }
                        if (!found) throw new IOException("Android did not expose the current app task");
                        answer(call,hidden);break;
                    }
                    case "quitApp": {
                        getContext().stopService(new Intent(getContext(), FoliaPlaybackService.class));
                        FoliaWindowHost.closeAuxiliaryWindows();
                        FoliaWindowHost.restoreMain((MainActivity)getActivity());
                        getContext().sendBroadcast(new Intent(getContext().getPackageName() + ".STOP_YTM_SIGNIN").setPackage(getContext().getPackageName()));
                        getActivity().finishAndRemoveTask(); answer(call, true);
                        android.app.WallpaperInfo wallpaper = android.app.WallpaperManager.getInstance(getContext()).getWallpaperInfo();
                        if (wallpaper == null || !wallpaper.getServiceName().equals(FoliaWallpaperService.class.getName())) io.execute(() -> {
                            try { Thread.sleep(200); if (FoliaNativeDispatcher.isAttachedTo((MainActivity)getActivity())) FoliaRuntimeHost.shutdown(); }
                            catch (Exception error) { android.util.Log.w("FoliaRuntime", "Cannot shut down backend", error); }
                        });
                        break;
                    }
                    case "wallpaperMode": {
                        boolean enabled = arguments.getBoolean(0);
                        Intent select = enabled ? new Intent(android.app.WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER)
                            .putExtra(android.app.WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT, new ComponentName(getContext(), FoliaWallpaperService.class))
                            : new Intent(Intent.ACTION_SET_WALLPAPER);
                        startActivityForResult(call, select, "wallpaperReturned"); break;
                    }
                    case "wallpaperDisplays": answer(call, wallpaperDisplays()); break;
                    case "wallpaperSetDisplay": {
                        int displayId = arguments.isNull(0) ? android.view.Display.DEFAULT_DISPLAY : arguments.getInt(0);
                        android.hardware.display.DisplayManager manager = (android.hardware.display.DisplayManager)getContext().getSystemService(Context.DISPLAY_SERVICE);
                        if (manager.getDisplay(displayId) == null) throw new IOException("This Android display is disconnected");
                        getContext().getSharedPreferences("wallpaper", Context.MODE_PRIVATE).edit().putInt("chosenDisplay", arguments.isNull(0) ? -1 : displayId).apply();
                        if (wallpaperActive() && Build.VERSION.SDK_INT >= 26) {
                            Intent pick = new Intent(android.app.WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).putExtra(android.app.WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT, new ComponentName(getContext(), FoliaWallpaperService.class));
                            getActivity().startActivity(pick, android.app.ActivityOptions.makeBasic().setLaunchDisplayId(displayId).toBundle());
                        }
                        answer(call, wallpaperDisplays()); break;
                    }
                    case "wallpaperStatus": answer(call, wallpaperActive()); break;
                    case "publishExport": publishExport(call, arguments.getString(0)); break;
                    case "installUpdate": installUpdate(call, arguments.getString(0)); break;
                    case "saveDialog": saveDialog(call, arguments.getJSONObject(0)); break;
                    case "openExternal": {
                        Uri uri = Uri.parse(arguments.getString(0));
                        if (!Arrays.asList("https", "http").contains(uri.getScheme())) throw new IOException("Unsupported URL scheme");
                        getActivity().startActivity(new Intent(Intent.ACTION_VIEW, uri));
                        answer(call, true); break;
                    }
                    case "openPath": {
                        File file = new File(arguments.getString(0));
                        if (file.isDirectory()) { FoliaFileBrowser.show(getActivity(), file); answer(call, ""); break; }
                        Uri uri = FileProvider.getUriForFile(getContext(), getContext().getPackageName() + ".fileprovider", file);
                        Intent intent = new Intent(Intent.ACTION_VIEW).setDataAndType(uri, file.isDirectory() ? "resource/folder" : mime(file.getName()))
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                        getActivity().startActivity(intent); answer(call, ""); break;
                    }
                    default: {
                        FoliaWindowHost.execute(getActivity(), method, arguments, value -> answer(call, value), error -> call.reject(error));
                    }
                }
            } catch (Exception error) { call.reject(error.getMessage()); }
        });
    }

    private JSObject wallpaperDisplays() throws Exception {
        android.content.SharedPreferences preferences = getContext().getSharedPreferences("wallpaper", Context.MODE_PRIVATE);
        int selected = preferences.getInt("chosenDisplay", -1), active = preferences.getInt("activeDisplay", 0);
        android.hardware.display.DisplayManager manager = (android.hardware.display.DisplayManager)getContext().getSystemService(Context.DISPLAY_SERVICE);
        JSArray rows = new JSArray(); JSObject choice = null;
        for (android.view.Display display : manager.getDisplays()) {
            if ((display.getFlags() & android.view.Display.FLAG_PRIVATE) != 0) continue;
            android.graphics.Point size = new android.graphics.Point(); display.getRealSize(size);
            JSObject bounds = new JSObject().put("x", 0).put("y", 0).put("width", size.x).put("height", size.y);
            JSObject item = new JSObject().put("id", display.getDisplayId()).put("label", display.getName()).put("bounds", bounds)
                .put("workArea", bounds).put("scaleFactor", getContext().getResources().getDisplayMetrics().density).put("primary", display.getDisplayId() == 0);
            rows.put(item); if (display.getDisplayId() == selected) choice = item;
        }
        return new JSObject().put("displays", rows).put("choice", choice == null ? JSONObject.NULL : choice)
            .put("chosenId", choice == null ? JSONObject.NULL : selected).put("activeId", manager.getDisplay(active) == null ? JSONObject.NULL : active);
    }
    private boolean wallpaperActive() {
        android.app.WallpaperInfo current = android.app.WallpaperManager.getInstance(getContext()).getWallpaperInfo();
        return current != null && current.getComponent().equals(new ComponentName(getContext(), FoliaWallpaperService.class));
    }
    @ActivityCallback private void wallpaperReturned(PluginCall call, ActivityResult result) {
        if (call == null) return;
        answer(call, wallpaperActive());
    }

    private void publishExport(PluginCall call, String path) {
        io.execute(() -> {
            Uri destination = null; boolean gallery = false;
            try {
                File file = new File(path).getCanonicalFile();
                String root = getContext().getFilesDir().getCanonicalPath();
                if (!file.getPath().startsWith(root + "/exports/") && !file.getPath().startsWith(root + "/runtime-data/videos/")) throw new IOException("Invalid export path");
                destination = exportTargets.remove(file.getPath());
                if (destination == null) {
                    ContentValues values = new ContentValues(); values.put(android.provider.MediaStore.Video.Media.DISPLAY_NAME, file.getName());
                    values.put(android.provider.MediaStore.Video.Media.MIME_TYPE, mime(file.getName()));
                    if (Build.VERSION.SDK_INT >= 29) {
                        values.put(android.provider.MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/Folia");
                        values.put(android.provider.MediaStore.Video.Media.IS_PENDING, 1);
                    }
                    destination = getContext().getContentResolver().insert(android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values);
                    if (destination == null) throw new IOException("Android could not create an exported video");
                    gallery = true;
                }
                try (InputStream input = new FileInputStream(file); OutputStream output = getContext().getContentResolver().openOutputStream(destination, "wt")) {
                    byte[] bytes = new byte[65536]; int count;
                    while ((count = input.read(bytes)) >= 0) output.write(bytes, 0, count);
                }
                if (gallery && Build.VERSION.SDK_INT >= 29) {
                    ContentValues values = new ContentValues(); values.put(android.provider.MediaStore.Video.Media.IS_PENDING, 0);
                    getContext().getContentResolver().update(destination, values, null, null);
                }
                answer(call, destination.toString());
            } catch (Exception error) {
                if (gallery && destination != null) getContext().getContentResolver().delete(destination, null, null);
                call.reject(error.getMessage());
            }
        });
    }

    private void installUpdate(PluginCall call, String path) throws Exception {
        File file = new File(path).getCanonicalFile();
        File allowed = new File(getContext().getFilesDir(), "runtime-data/updates").getCanonicalFile();
        if (!file.getParentFile().equals(allowed)) throw new IOException("Invalid update path");
        android.content.pm.PackageManager manager = getContext().getPackageManager();
        int flags = Build.VERSION.SDK_INT >= 28 ? android.content.pm.PackageManager.GET_SIGNING_CERTIFICATES : android.content.pm.PackageManager.GET_SIGNATURES;
        android.content.pm.PackageInfo candidate = manager.getPackageArchiveInfo(file.getPath(), flags);
        android.content.pm.PackageInfo installed = manager.getPackageInfo(getContext().getPackageName(), flags);
        if (candidate == null || !candidate.packageName.equals(installed.packageName)) throw new IOException("APK package does not match this app");
        android.content.pm.Signature[] next = Build.VERSION.SDK_INT >= 28 ? candidate.signingInfo.getApkContentsSigners() : candidate.signatures;
        android.content.pm.Signature[] current = Build.VERSION.SDK_INT >= 28 ? installed.signingInfo.getApkContentsSigners() : installed.signatures;
        if (!Arrays.equals(next, current)) throw new IOException("APK signing identity does not match this app");
        if (Build.VERSION.SDK_INT >= 26 && !manager.canRequestPackageInstalls()) {
            startActivityForResult(call, new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + getContext().getPackageName())), "installPermissionReturned"); return;
        }
        Uri uri = FileProvider.getUriForFile(getContext(), getContext().getPackageName() + ".fileprovider", file);
        getActivity().startActivity(new Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION));
        answer(call, true);
    }
    @ActivityCallback private void installPermissionReturned(PluginCall call, ActivityResult result) {
        if (call == null) return;
        try {
            if (Build.VERSION.SDK_INT >= 26 && !getContext().getPackageManager().canRequestPackageInstalls()) throw new IOException("Android did not grant APK installation permission");
            installUpdate(call, call.getArray("args").getString(0));
        } catch (Exception error) { call.reject(error.getMessage()); }
    }

    private void answer(PluginCall call, Object value) { call.resolve(new JSObject().put("result", value)); }
    private static String mime(String name) {
        int dot = name.lastIndexOf('.');
        String type = dot < 0 ? null : android.webkit.MimeTypeMap.getSingleton().getMimeTypeFromExtension(name.substring(dot + 1).toLowerCase());
        return type == null ? "application/octet-stream" : type;
    }

    private void messageBox(PluginCall call, JSONObject options) throws Exception {
        JSONArray buttons = options.optJSONArray("buttons");
        if (buttons == null) buttons = new JSONArray().put("OK");
        String[] labels = new String[buttons.length()];
        for (int index = 0; index < labels.length; index++) labels[index] = buttons.getString(index);
        LinearLayout contents = new LinearLayout(getActivity()); contents.setOrientation(LinearLayout.VERTICAL); contents.setPadding(32, 16, 32, 16);
        TextView text = new TextView(getActivity());
        text.setText(options.optString("message") + (options.optString("detail").isEmpty() ? "" : "\n\n" + options.optString("detail")));
        contents.addView(text);
        CheckBox checkbox = new CheckBox(getActivity());
        if (options.has("checkboxLabel")) {
            checkbox.setText(options.optString("checkboxLabel")); checkbox.setChecked(options.optBoolean("checkboxChecked")); contents.addView(checkbox);
        }
        ScrollView scroll = new ScrollView(getActivity()); scroll.addView(contents);
        AlertDialog dialog = new AlertDialog.Builder(getActivity()).setTitle(options.optString("title", "Folia")).setView(scroll)
            .setItems(labels, (selected, index) -> answer(call, new JSObject().put("response", index).put("checkboxChecked", checkbox.isChecked())))
            .setOnCancelListener(selected -> answer(call, new JSObject().put("response", options.optInt("cancelId", 1)).put("checkboxChecked", checkbox.isChecked())))
            .create();
        dialog.show();
    }

    private void openDialog(PluginCall call, JSONObject options) throws Exception {
        JSONArray properties = options.optJSONArray("properties");
        boolean directory = properties != null && properties.toString().contains("openDirectory");
        if (directory && Build.VERSION.SDK_INT >= 30 && !Environment.isExternalStorageManager()) {
            Intent permissions = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:" + getContext().getPackageName()));
            startActivityForResult(call, permissions, "storagePermissionReturned");
            return;
        }
        Intent intent = new Intent(directory ? Intent.ACTION_OPEN_DOCUMENT_TREE : Intent.ACTION_OPEN_DOCUMENT);
        if (!directory) { intent.setType("*/*"); intent.addCategory(Intent.CATEGORY_OPENABLE); }
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, properties != null && properties.toString().contains("multiSelections"));
        startActivityForResult(call, intent, "opened");
    }

    @ActivityCallback private void storagePermissionReturned(PluginCall call, ActivityResult result) {
        if (call == null) return;
        try {
            if (Build.VERSION.SDK_INT >= 30 && !Environment.isExternalStorageManager()) {
                answer(call, new JSObject().put("canceled", true).put("filePaths", new JSArray())); return;
            }
            openDialog(call, call.getArray("args").getJSONObject(0));
        } catch (Exception error) { call.reject(error.getMessage()); }
    }

    private String treePath(Uri uri) throws Exception {
        String id = DocumentsContract.getTreeDocumentId(uri);
        int colon = id.indexOf(':');
        String volume = colon < 0 ? id : id.substring(0, colon);
        File root = "primary".equalsIgnoreCase(volume) ? Environment.getExternalStorageDirectory() : new File("/storage", volume);
        File selected = colon < 0 ? root : new File(root, id.substring(colon + 1));
        if (!selected.isDirectory() || !selected.canRead()) throw new IOException("Android did not grant directory access");
        return selected.getCanonicalPath();
    }

    private String copyDocument(Uri uri) throws Exception {
        String name = "document";
        try (android.database.Cursor cursor = getContext().getContentResolver().query(uri, new String[]{"_display_name"}, null, null, null)) {
            if (cursor != null && cursor.moveToFirst()) name = new File(cursor.getString(0)).getName();
        }
        File directory = new File(getContext().getCacheDir(), "picked-documents"); directory.mkdirs();
        File file = new File(directory, UUID.randomUUID() + "-" + name);
        try (InputStream input = getContext().getContentResolver().openInputStream(uri); OutputStream output = new FileOutputStream(file)) {
            byte[] buffer = new byte[65536]; int count;
            while ((count = input.read(buffer)) >= 0) output.write(buffer, 0, count);
        }
        return file.getPath();
    }

    @ActivityCallback private void opened(PluginCall call, ActivityResult result) {
        if (call == null) return;
        if (result.getResultCode() != Activity.RESULT_OK || result.getData() == null) {
            answer(call, new JSObject().put("canceled", true).put("filePaths", new JSArray())); return;
        }
        io.execute(() -> {
            try {
                JSArray paths = new JSArray(); Intent data = result.getData();
                if (data.getClipData() != null) {
                    for (int i = 0; i < data.getClipData().getItemCount(); i++) paths.put(copyDocument(data.getClipData().getItemAt(i).getUri()));
                } else {
                    Uri uri = data.getData();
                    paths.put(uri.getPath().contains("/tree/") ? treePath(uri) : copyDocument(uri));
                }
                answer(call, new JSObject().put("canceled", false).put("filePaths", paths));
            } catch (Exception error) { call.reject(error.getMessage()); }
        });
    }

    private void saveDialog(PluginCall call, JSONObject options) {
        String name = new File(options.optString("defaultPath", "Folia-export.mp4")).getName();
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
            .setType(mime(name)).putExtra(Intent.EXTRA_TITLE, name)
            .addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        startActivityForResult(call, intent, "saved");
    }

    @ActivityCallback private void saved(PluginCall call, ActivityResult result) {
        if (call == null) return;
        if (result.getResultCode() != Activity.RESULT_OK || result.getData() == null) { answer(call, new JSObject().put("canceled", true)); return; }
        try {
            Uri destination = result.getData().getData();
            String name = new File(call.getArray("args").getJSONObject(0).optString("defaultPath", "Folia-export.mp4")).getName();
            File directory = new File(getContext().getFilesDir(), "exports"); directory.mkdirs();
            File file = new File(directory, UUID.randomUUID() + "-" + name);
            exportTargets.put(file.getCanonicalPath(), destination);
            answer(call, new JSObject().put("canceled", false).put("filePath", file.getPath()));
        } catch (Exception error) { call.reject(error.getMessage()); }
    }
}
