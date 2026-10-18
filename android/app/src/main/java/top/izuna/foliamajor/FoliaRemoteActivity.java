package top.izuna.foliamajor;

import android.os.Bundle;
import androidx.appcompat.app.AppCompatActivity;

// Give the remote control its own Android task so its Recents visibility is independent of the player.
public final class FoliaRemoteActivity extends AppCompatActivity {
    private int windowId;
    @Override public void onCreate(Bundle state) {
        windowId = getIntent().getIntExtra("foliaWindowId",0);
        if (!FoliaWindowHost.taskTitlebar(windowId)) supportRequestWindowFeature(android.view.Window.FEATURE_NO_TITLE);
        super.onCreate(state);
        setTitle("Folia");
        if (!FoliaWindowHost.attachTask(this,windowId)) finishAndRemoveTask();
    }
    @Override public void onResume() {
        super.onResume(); FoliaWindowHost.resumeTask(windowId);
    }
    @Override public void onDestroy() {
        FoliaWindowHost.detachTask(this,windowId,isChangingConfigurations());
        super.onDestroy();
    }
}
