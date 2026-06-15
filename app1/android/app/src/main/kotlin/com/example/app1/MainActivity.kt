package com.example.app1

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Process
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.app1/focus"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                // ── Overlay bubble ────────────────────────────────────────
                "startOverlay" -> {
                    val duration = call.argument<Long>("duration_millis") ?: (50 * 60 * 1000L)
                    val intent = Intent(this, FocusOverlayService::class.java)
                    intent.putExtra("duration_millis", duration)
                    startForegroundService(intent)
                    result.success(null)
                }

                "stopOverlay" -> {
                    stopService(Intent(this, FocusOverlayService::class.java))
                    result.success(null)
                }

                // ── Overlay permission ────────────────────────────────────
                "hasOverlayPermission" ->
                    result.success(Settings.canDrawOverlays(this))

                "requestOverlayPermission" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                    result.success(null)
                }

                // ── Accessibility permission ──────────────────────────────
                "hasAccessibilityPermission" ->
                    result.success(isAccessibilityEnabled())

                "requestAccessibilityPermission" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }

                // ── Usage stats permission ────────────────────────────────
                "hasUsageStatsPermission" ->
                    result.success(hasUsageStatsPermission())

                "requestUsageStatsPermission" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }

                // ── Get usage stats (past 24 h) ───────────────────────────
                "getUsageStats" -> {
                    if (!hasUsageStatsPermission()) {
                        result.success(emptyMap<String, Int>())
                        return@setMethodCallHandler
                    }
                    val usm = getSystemService(Context.USAGE_STATS_SERVICE)
                            as UsageStatsManager
                    val cal = Calendar.getInstance()
                    val endTime = cal.timeInMillis
                    cal.add(Calendar.DAY_OF_YEAR, -1)
                    val startTime = cal.timeInMillis

                    val statsMap = usm.queryAndAggregateUsageStats(startTime, endTime)
                    val out = mutableMapOf<String, Int>()
                    statsMap.forEach { (pkg, stats) ->
                        val minutes = (stats.totalTimeInForeground / 60_000).toInt()
                        if (minutes > 0) out[pkg] = minutes
                    }
                    result.success(out)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val services = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return services.contains("$packageName/com.example.app1.FocusAccessibilityService")
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }
}