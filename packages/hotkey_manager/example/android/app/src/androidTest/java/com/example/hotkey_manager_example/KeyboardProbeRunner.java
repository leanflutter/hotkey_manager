package com.example.hotkey_manager_example;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.ComponentName;
import android.content.Intent;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.InputDevice;
import android.view.KeyCharacterMap;
import android.view.KeyEvent;
import java.io.File;
import java.io.ByteArrayOutputStream;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import org.json.JSONObject;

/** Native events target this Activity only. Private cache files coordinate the
 * test without depending on Flutter Java classes removed/merged by release R8. */
public final class KeyboardProbeRunner extends Instrumentation {
    @Override public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        start();
    }
    private String read(File file) throws Exception {
        try (FileInputStream input = new FileInputStream(file)) {
            ByteArrayOutputStream bytes = new ByteArrayOutputStream();
            byte[] buffer = new byte[4096];
            int count;
            while ((count = input.read(buffer)) != -1) bytes.write(buffer, 0, count);
            return new String(bytes.toByteArray(), StandardCharsets.UTF_8);
        }
    }
    private void write(File directory, String name, String text) throws Exception {
        File temporary = new File(directory, name + ".tmp");
        try (FileOutputStream output = new FileOutputStream(temporary)) {
            output.write(text.getBytes(StandardCharsets.UTF_8));
        }
        if (!temporary.renameTo(new File(directory, name))) {
            throw new IllegalStateException("Cannot publish " + name);
        }
    }
    @Override public void onStart() {
        Activity activity = null;
        String report = "timeout";
        boolean passed = false;
        try {
            File directory = new File(getTargetContext().getCodeCacheDir(), "hotkey_manager_keyboard_probe");
            if (!directory.isDirectory() && !directory.mkdirs()) throw new IllegalStateException("Probe cache");
            File[] oldFiles = directory.listFiles();
            if (oldFiles != null) for (File old : oldFiles) old.delete();
            Intent intent = new Intent(Intent.ACTION_MAIN);
            intent.setComponent(new ComponentName(getTargetContext().getPackageName(), MainActivity.class.getName()));
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            // Hardware keyboard input leaves Android touch mode before dispatch.
            setInTouchMode(false);
            activity = startActivitySync(intent);
            final Activity target = activity;
            AtomicBoolean focused = new AtomicBoolean();
            long focusDeadline = SystemClock.uptimeMillis() + 10000;
            while (!focused.get() && SystemClock.uptimeMillis() < focusDeadline) {
                runOnMainSync(() -> focused.set(target.hasWindowFocus() && target.getCurrentFocus() != null));
                Thread.sleep(20);
            }
            if (!focused.get()) throw new IllegalStateException("Example did not obtain keyboard focus");
            write(directory, "ready.json", "true");
            Map<Integer, Long> downTimes = new HashMap<>();
            File requestFile = new File(directory, "request.json");
            File reportFile = new File(directory, "report.json");
            long deadline = SystemClock.uptimeMillis() + 120000;
            int lastId = 0;
            while (SystemClock.uptimeMillis() < deadline) {
                if (reportFile.exists()) {
                    report = read(reportFile);
                    passed = new JSONObject(report).getBoolean("passed");
                    break;
                }
                if (requestFile.exists()) {
                    JSONObject request = new JSONObject(read(requestFile));
                    int id = request.getInt("id");
                    if (id > lastId) {
                        int code = request.getInt("code");
                        int action = request.getInt("action");
                        long time = SystemClock.uptimeMillis();
                        Long down = downTimes.get(code);
                        if (down == null) { down = time; downTimes.put(code, down); }
                        KeyEvent event = new KeyEvent(down, time, action, code,
                            request.getInt("repeat"), request.getInt("meta"),
                            KeyCharacterMap.VIRTUAL_KEYBOARD, request.getInt("scan"),
                            0, InputDevice.SOURCE_KEYBOARD);
                        // This never uses Instrumentation.sendKeySync or OS input APIs.
                        runOnMainSync(() -> target.dispatchKeyEvent(event));
                        if (action == KeyEvent.ACTION_UP) downTimes.remove(code);
                        lastId = id;
                        write(directory, "reply.json", "{\"id\":" + id + "}");
                    }
                }
                Thread.sleep(5);
            }
        } catch (Exception error) {
            report = "instrumentation error: " + error;
        } finally {
            if (activity != null) {
                final Activity target = activity;
                runOnMainSync(target::finish);
            }
        }
        Bundle output = new Bundle();
        output.putString("stream", "\nHOTKEY_ANDROID_PROBE " + report + "\n");
        finish(passed ? Activity.RESULT_OK : Activity.RESULT_CANCELED, output);
    }
}
