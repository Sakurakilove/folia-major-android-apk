package top.izuna.foliamajor;

import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.BatteryManager;
import android.os.Build;
import android.os.PowerManager;
import android.os.SystemClock;
import com.getcapacitor.JSObject;

// On-demand hardware/process counters. This owns no timers, wake lock, renderer or sensor listener.
final class FoliaPowerSnapshot {
    static JSObject read(Context context) {
        JSObject result = new JSObject()
            .put("elapsedMs", SystemClock.elapsedRealtime())
            .put("hostCpuMs", android.os.Process.getElapsedCpuTime())
            .put("cpuScope", "Android host process; isolated Chromium renderer/GPU and other apps excluded");
        PowerManager power = context.getSystemService(PowerManager.class);
        if (power != null) {
            result.put("powerSaveMode", power.isPowerSaveMode());
            if (Build.VERSION.SDK_INT >= 29) result.put("thermalStatus", power.getCurrentThermalStatus());
        }
        Intent battery = context.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        BatteryManager manager = context.getSystemService(BatteryManager.class);
        if (battery != null && manager != null) {
            int current = manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW);
            int voltage = battery.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0);
            boolean plugged = battery.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) != 0;
            result.put("plugged", plugged).put("voltageMv", voltage);
            // Android defines microamps, but vendor gauges can be unavailable or have coarse updates.
            if (current != Integer.MIN_VALUE) {
                result.put("currentUa", current);
                if (!plugged && voltage > 0) result.put("wholeDeviceWattsEstimate", Math.abs((double)current) * voltage / 1_000_000_000.0);
            }
            result.put("powerScope", "whole-device instantaneous battery gauge; not app-attributed power");
        }
        return result;
    }
}
