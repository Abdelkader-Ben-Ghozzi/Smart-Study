// android/app/src/main/kotlin/com/example/app1/FocusAccessibilityService.kt

package com.example.app1

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.content.SharedPreferences
import android.view.accessibility.AccessibilityEvent
import org.json.JSONArray

class FocusAccessibilityService : AccessibilityService() {

    private lateinit var prefs: SharedPreferences

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)

        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 100
        }
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return

        // Skip our own app
        if (packageName == applicationContext.packageName) return

        val isActive = prefs.getBoolean("flutter.session_active", false)
        if (!isActive) return

        val blockedJson = prefs.getString("flutter.blocked_apps", "[]") ?: "[]"
        val blocked = mutableListOf<String>()
        val arr = JSONArray(blockedJson)
        for (i in 0 until arr.length()) {
            blocked.add(arr.getString(i))
        }

        if (blocked.contains(packageName)) {
    performGlobalAction(GLOBAL_ACTION_BACK)
    performGlobalAction(GLOBAL_ACTION_BACK)
}
    }

    override fun onInterrupt() {}
}