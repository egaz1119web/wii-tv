package com.gathin.tvhome;

import android.accessibilityservice.AccessibilityService;
import android.content.Intent;
import android.os.SystemClock;
import android.view.accessibility.AccessibilityEvent;

/**
 * Makes the Home button, and power-on, land on the channel menu on Amazon Fire TV. Fire OS sends Home
 * only to its own launcher, does not let another app become the default home, and must not have that
 * launcher disabled (Home, the app store and the settings shortcuts all go through it). So the stock
 * launcher stays enabled, and whenever its home screen comes to the front this opens the menu on top.
 *
 * Only the home screen itself is redirected: other Amazon launcher screens (search, the app library,
 * the profile picker) stay reachable. Long-pressing Home still opens the Fire TV quick panel.
 *
 * Enable over adb (launcher/firetv-install.sh does it):
 *   settings put secure enabled_accessibility_services com.gathin.tvhome/.FireTvHomeService
 *   settings put secure accessibility_enabled 1
 */
public class FireTvHomeService extends AccessibilityService {

    static final String AMAZON_LAUNCHER = "com.amazon.tv.launcher";
    /** Activities of the Amazon launcher that are its home screen, by simple class-name prefix. */
    private static final String[] HOME_ACTIVITIES = {"HomeActivity", "MainActivity"};
    /** Ignore repeat window events from the same Home press. */
    private static final long DEBOUNCE_MS = 1500;

    private long lastRedirect;

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        if (event.getEventType() != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return;
        if (!AMAZON_LAUNCHER.contentEquals(String.valueOf(event.getPackageName()))) return;
        if (!isHomeScreen(String.valueOf(event.getClassName()))) return;
        long now = SystemClock.elapsedRealtime();
        if (now - lastRedirect < DEBOUNCE_MS) return;
        lastRedirect = now;
        startActivity(new Intent(this, WiiMenuActivity.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED));
    }

    static boolean isHomeScreen(String className) {
        String simple = className.substring(className.lastIndexOf('.') + 1);
        for (String prefix : HOME_ACTIVITIES) if (simple.startsWith(prefix)) return true;
        return false;
    }

    @Override
    public void onInterrupt() {
    }
}
