package top.izuna.foliamajor;

import android.os.Debug;
import android.os.SystemClock;
import com.getcapacitor.JSObject;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

// Measure the actual Android Java/Chromium host independently of the Node backend and isolated renderer.
final class FoliaProcessMetrics {
    static JSObject measure() throws Exception {
        Debug.MemoryInfo memory=new Debug.MemoryInfo();Debug.getMemoryInfo(memory);
        JSObject result=new JSObject().put("pid",android.os.Process.myPid())
            .put("privateKB",memory.getTotalPrivateClean()+memory.getTotalPrivateDirty())
            .put("sharedKB",memory.getTotalSharedClean()+memory.getTotalSharedDirty())
            .put("cpuMs",android.os.Process.getElapsedCpuTime()).put("elapsedMs",SystemClock.elapsedRealtime());
        String status=new String(Files.readAllBytes(Paths.get("/proc/self/status")),java.nio.charset.StandardCharsets.US_ASCII);
        for(String field:new String[]{"VmRSS","VmHWM"}){
            Matcher value=Pattern.compile("(?m)^"+field+":\\s+(\\d+)").matcher(status);
            if(value.find())result.put(field.equals("VmRSS")?"residentKB":"peakResidentKB",Long.parseLong(value.group(1)));
        }
        return result;
    }
}
