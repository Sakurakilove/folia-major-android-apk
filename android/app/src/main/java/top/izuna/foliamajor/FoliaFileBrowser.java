package top.izuna.foliamajor;

import android.app.*;
import android.content.*;
import android.net.Uri;
import android.webkit.MimeTypeMap;
import android.widget.Toast;
import androidx.core.content.FileProvider;
import java.io.File;
import java.util.*;

// Android file managers cannot browse another app's private files; expose the selected folder explicitly.
final class FoliaFileBrowser {
    static void show(Activity activity, File directory) {
        File[] children = directory.listFiles();
        if (children == null) { Toast.makeText(activity, "Cannot read " + directory.getPath(), Toast.LENGTH_LONG).show(); return; }
        Arrays.sort(children, Comparator.comparing(File::isFile).thenComparing(file -> file.getName().toLowerCase(Locale.ROOT)));
        String[] names = new String[children.length];
        for (int i = 0; i < children.length; i++) names[i] = (children[i].isDirectory() ? "▸ " : "") + children[i].getName();
        AlertDialog dialog = new AlertDialog.Builder(activity).setTitle(directory.getPath()).setItems(names, (selected, index) -> {
            File file = children[index];
            if (file.isDirectory()) show(activity, file);
            else {
                try {
                    Uri uri = FileProvider.getUriForFile(activity, activity.getPackageName() + ".fileprovider", file);
                    int dot = file.getName().lastIndexOf('.');
                    String type = dot < 0 ? null : MimeTypeMap.getSingleton().getMimeTypeFromExtension(file.getName().substring(dot + 1).toLowerCase(Locale.ROOT));
                    Intent open = new Intent(Intent.ACTION_VIEW).setDataAndType(uri, type == null ? "application/octet-stream" : type).addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    activity.startActivity(Intent.createChooser(open, file.getName()));
                } catch (Exception error) { Toast.makeText(activity, error.getMessage(), Toast.LENGTH_LONG).show(); }
            }
        }).setNegativeButton(android.R.string.cancel, null).create();
        dialog.show();
    }
}
