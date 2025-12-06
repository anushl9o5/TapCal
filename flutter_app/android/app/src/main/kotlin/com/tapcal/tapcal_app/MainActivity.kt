package com.tapcal.tapcal_app

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.CalendarContract
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tapcal/accessibility"
    private val NATIVE_CHANNEL = "com.tapcal.tapcal_app/native"
    
    private var methodChannel: MethodChannel? = null
    private var nativeChannel: MethodChannel? = null

    companion object {
        var instance: MainActivity? = null
        const val PREFS_NAME = "tapcal_events"
        const val KEY_EVENT_HISTORY = "event_history"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        instance = this
        
        // Native channel for reading scan history from SharedPreferences
        nativeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NATIVE_CHANNEL)
        nativeChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getScanHistory" -> {
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    val history = prefs.getString(KEY_EVENT_HISTORY, "[]")
                    result.success(history)
                }
                "saveHistory" -> {
                    val historyJson = call.arguments as? String ?: "[]"
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit().putString(KEY_EVENT_HISTORY, historyJson).apply()
                    result.success(true)
                }
                "clearHistory" -> {
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit().remove(KEY_EVENT_HISTORY).apply()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
                "startNotificationService" -> {
                    // Start the notification service if not running
                    if (!TapCalNotificationService.isRunning) {
                        // Prefer starting via accessibility service if available
                        val accessibilityService = TapCalAccessibilityService.instance
                        if (accessibilityService != null) {
                            accessibilityService.startNotificationService()
                        } else {
                            // Fallback: start directly from activity
                            val intent = Intent(this, TapCalNotificationService::class.java)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(intent)
                            } else {
                                startService(intent)
                            }
                        }
                    }
                    result.success(true)
                }
                "stopNotificationService" -> {
                    stopService(Intent(this, TapCalNotificationService::class.java))
                    result.success(true)
                }
                "openCalendarWithEvent" -> {
                    val title = call.argument<String>("title") ?: ""
                    val date = call.argument<String>("date") ?: ""
                    val time = call.argument<String>("time") ?: ""
                    val location = call.argument<String>("location")
                    val description = call.argument<String>("description")
                    
                    openCalendarApp(title, date, time, location, description)
                    result.success(true)
                }
                "isNotificationServiceRunning" -> {
                    result.success(TapCalNotificationService.isRunning)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun openCalendarApp(
        title: String,
        date: String,
        time: String,
        location: String?,
        description: String?
    ) {
        try {
            // Parse date (expected format: "2025-12-25" or "December 25, 2025")
            val calendar = Calendar.getInstance()
            
            // Try to parse various date formats
            try {
                val dateParts = date.split("-", "/", " ")
                if (dateParts.size >= 3) {
                    // Try YYYY-MM-DD format first
                    if (dateParts[0].length == 4) {
                        calendar.set(Calendar.YEAR, dateParts[0].toInt())
                        calendar.set(Calendar.MONTH, dateParts[1].toInt() - 1)
                        calendar.set(Calendar.DAY_OF_MONTH, dateParts[2].toInt())
                    } else {
                        // MM-DD-YYYY or DD-MM-YYYY
                        calendar.set(Calendar.MONTH, dateParts[0].toInt() - 1)
                        calendar.set(Calendar.DAY_OF_MONTH, dateParts[1].toInt())
                        calendar.set(Calendar.YEAR, dateParts[2].toInt())
                    }
                }
            } catch (e: Exception) {
                println("[SnapCal] Could not parse date: $date, using current date")
            }
            
            // Parse time (expected format: "14:00", "2:00 PM", etc)
            try {
                val timeLower = time.lowercase()
                val isPM = timeLower.contains("pm")
                val isAM = timeLower.contains("am")
                val timeCleaned = timeLower.replace("am", "").replace("pm", "").trim()
                val timeParts = timeCleaned.split(":", ".")
                
                if (timeParts.isNotEmpty()) {
                    var hour = timeParts[0].trim().toIntOrNull() ?: 12
                    val minute = if (timeParts.size > 1) timeParts[1].trim().toIntOrNull() ?: 0 else 0
                    
                    if (isPM && hour < 12) hour += 12
                    if (isAM && hour == 12) hour = 0
                    
                    calendar.set(Calendar.HOUR_OF_DAY, hour)
                    calendar.set(Calendar.MINUTE, minute)
                }
            } catch (e: Exception) {
                println("[SnapCal] Could not parse time: $time")
                calendar.set(Calendar.HOUR_OF_DAY, 12)
                calendar.set(Calendar.MINUTE, 0)
            }
            
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            
            val startMillis = calendar.timeInMillis
            val endMillis = startMillis + 60 * 60 * 1000 // 1 hour duration
            
            println("[SnapCal] Opening calendar with:")
            println("[SnapCal]   Title: $title")
            println("[SnapCal]   Date/Time: ${calendar.time}")
            println("[SnapCal]   Location: $location")
            
            // Create Intent to open default calendar app
            val intent = Intent(Intent.ACTION_INSERT).apply {
                data = CalendarContract.Events.CONTENT_URI
                putExtra(CalendarContract.Events.TITLE, title)
                putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startMillis)
                putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endMillis)
                putExtra(CalendarContract.Events.ALL_DAY, false)
                
                if (!location.isNullOrEmpty()) {
                    putExtra(CalendarContract.Events.EVENT_LOCATION, location)
                }
                if (!description.isNullOrEmpty()) {
                    putExtra(CalendarContract.Events.DESCRIPTION, description)
                }
            }
            
            startActivity(intent)
            println("[SnapCal] Calendar app opened!")
            
        } catch (e: Exception) {
            println("[SnapCal] Error opening calendar: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Clean up any stale screenshot files from previous sessions
        cleanupScreenshotFiles()
        handleIntent(intent)
    }
    
    private fun cleanupScreenshotFiles() {
        try {
            val cacheDir = cacheDir
            val screenshotFiles = cacheDir.listFiles { file ->
                file.name.contains("screenshot") && file.extension == "jpg"
            }
            screenshotFiles?.forEach { file ->
                if (file.delete()) {
                    println("[SnapCal] 🗑️ Cleaned up stale screenshot: ${file.name}")
                }
            }
        } catch (e: Exception) {
            println("[SnapCal] Error cleaning up screenshots: ${e.message}")
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        intent?.let {
            val openTab = it.getStringExtra("open_tab")
            if (openTab == "history") {
                println("[SnapCal] Opening app to History tab")
                // Notify Flutter to switch to history tab
                methodChannel?.invokeMethod("openTab", "history")
            }
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val serviceName = "${packageName}/${TapCalAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        
        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)
        
        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.equals(serviceName, ignoreCase = true)) {
                return true
            }
        }
        return false
    }

    private fun openAccessibilitySettings() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        startActivity(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) {
            instance = null
        }
    }
}
