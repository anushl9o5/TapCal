package com.tapcal.tapcal_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.view.accessibility.AccessibilityEvent
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.concurrent.TimeUnit

/**
 * Simplified Accessibility Service for notification-based screenshot capture.
 * 
 * Flow:
 * 1. User taps notification in shade
 * 2. NotificationService collapses shade and calls captureFromNotification()
 * 3. This service takes screenshot using AccessibilityService.takeScreenshot()
 * 4. Sends to API for analysis
 * 5. Stores results in SharedPreferences
 * 6. Updates notification with result count
 */
class TapCalAccessibilityService : AccessibilityService() {
    
    companion object {
        var instance: TapCalAccessibilityService? = null
        var isRunning = false
        private var isCapturing = false
        
        // SharedPreferences key for event history
        const val PREFS_NAME = "tapcal_events"
        const val KEY_EVENT_HISTORY = "event_history"
    }
    
    private val handler = Handler(Looper.getMainLooper())
    
    // API endpoint
    private val API_URL = "https://tap-cal-git-main-anush-kumars-projects-fdf1b16c.vercel.app/api/analyze"
    
    // OkHttp client
    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        isRunning = true
        isCapturing = false
        
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 100
        }
        serviceInfo = info
        
        println("[SnapCal] ========================================")
        println("[SnapCal] Accessibility Service CONNECTED")
        println("[SnapCal] Ready for notification-based capture")
        println("[SnapCal] Note: Notification permission required before starting service")
        println("[SnapCal] ========================================")
        
        // Return to app - it will handle notification permission and service start
        returnToApp()
    }
    
    /**
     * Start notification service - called from MainActivity after permission granted
     */
    fun startNotificationService() {
        try {
            val intent = Intent(this, TapCalNotificationService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            println("[SnapCal] Notification service started from accessibility service")
        } catch (e: Exception) {
            println("[SnapCal] Failed to start notification service: ${e.message}")
            e.printStackTrace()
        }
    }
    
    private fun returnToApp() {
        handler.postDelayed({
            try {
                val intent = Intent(this, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                }
                startActivity(intent)
            } catch (e: Exception) {
                println("[SnapCal] Could not return to app: ${e.message}")
            }
        }, 500)
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not used - we only capture on notification tap
    }
    
    override fun onInterrupt() {
        println("[SnapCal] Service interrupted")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        isRunning = false
        
        // Stop notification service
        stopService(Intent(this, TapCalNotificationService::class.java))
        
        println("[SnapCal] Accessibility Service DESTROYED")
    }
    
    /**
     * Called by CaptureActivity after notification shade has closed.
     * Takes a screenshot and processes it in background.
     */
    fun captureFromNotification() {
        if (isCapturing) {
            println("[SnapCal] ⚠️ Already capturing, ignoring duplicate request")
            return
        }
        
        isCapturing = true
        println("[SnapCal] 📸 Starting screen capture...")
        
        // Step 1: Close notification shade using ONE BACK gesture
        println("[SnapCal] Closing notification shade...")
        performGlobalAction(GLOBAL_ACTION_BACK)
        
        // Step 2: Wait for shade animation to fully complete (800ms), then screenshot
        handler.postDelayed({
            println("[SnapCal] Shade closed, taking screenshot...")
            
            // Take screenshot using Accessibility API (Android 11+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                takeScreenshotWithAccessibility()
            } else {
                println("[SnapCal] ❌ Screenshot requires Android 11+")
                isCapturing = false
                getNotificationService()?.resetToReady()
            }
        }, 800) // Wait 800ms for shade animation to fully complete
    }
    
    private fun takeScreenshotWithAccessibility() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            println("[SnapCal] takeScreenshot requires Android 11+")
            isCapturing = false
            return
        }
        
        println("[SnapCal] Taking screenshot via Accessibility API...")
        
        takeScreenshot(
            android.view.Display.DEFAULT_DISPLAY,
            applicationContext.mainExecutor,
            object : TakeScreenshotCallback {
                override fun onSuccess(screenshot: ScreenshotResult) {
                    println("[SnapCal] ✅ Screenshot captured!")
                    
                    val hardwareBuffer = screenshot.hardwareBuffer
                    val colorSpace = screenshot.colorSpace
                    
                    if (hardwareBuffer != null) {
                        val bitmap = Bitmap.wrapHardwareBuffer(hardwareBuffer, colorSpace)
                        if (bitmap != null) {
                            // Convert to software bitmap for processing
                            val softwareBitmap = bitmap.copy(Bitmap.Config.ARGB_8888, false)
                            bitmap.recycle()
                            hardwareBuffer.close()
                            
                            // Process in background
                            processScreenshot(softwareBitmap)
                        } else {
                            println("[SnapCal] Failed to create bitmap")
                            isCapturing = false
                            getNotificationService()?.resetToReady()
                        }
                    } else {
                        println("[SnapCal] No hardware buffer")
                        isCapturing = false
                        getNotificationService()?.resetToReady()
                    }
                }
                
                override fun onFailure(errorCode: Int) {
                    println("[SnapCal] ❌ Screenshot failed: $errorCode")
                    isCapturing = false
                    getNotificationService()?.resetToReady()
                }
            }
        )
    }
    
    private fun processScreenshot(bitmap: Bitmap) {
        println("[SnapCal] Processing screenshot...")
        
        Thread {
            try {
                // Scale down
                val maxWidth = 1080
                val scaledBitmap = if (bitmap.width > maxWidth) {
                    val scale = maxWidth.toFloat() / bitmap.width
                    val scaledHeight = (bitmap.height * scale).toInt()
                    Bitmap.createScaledBitmap(bitmap, maxWidth, scaledHeight, true)
                } else {
                    bitmap
                }
                
                // Convert to base64
                val outputStream = ByteArrayOutputStream()
                scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 80, outputStream)
                val base64Image = Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
                
                println("[SnapCal] Image encoded: ${base64Image.length / 1024} KB")
                
                // Clean up
                if (scaledBitmap !== bitmap) {
                    scaledBitmap.recycle()
                }
                bitmap.recycle()
                
                // Call API
                val events = callAnalyzeApi(base64Image)
                
                // Store events and update notification
                handler.post {
                    storeEventsInHistory(events)
                    getNotificationService()?.showResultNotification(events.size)
                    isCapturing = false
                }
                
            } catch (e: Exception) {
                println("[SnapCal] Error: ${e.message}")
                e.printStackTrace()
                handler.post {
                    getNotificationService()?.showResultNotification(0)
                    isCapturing = false
                }
            }
        }.start()
    }
    
    private fun callAnalyzeApi(base64Image: String): List<Map<String, String>> {
        val jsonBody = JSONObject().apply {
            put("image", base64Image)
            put("context", "android_notification")
        }
        
        val request = Request.Builder()
            .url(API_URL)
            .post(jsonBody.toString().toRequestBody("application/json".toMediaType()))
            .build()
        
        println("[SnapCal] Calling API...")
        val response = httpClient.newCall(request).execute()
        val responseBody = response.body?.string() ?: ""
        
        println("[SnapCal] API response: ${response.code}")
        
        if (!response.isSuccessful) {
            throw Exception("API error: ${response.code}")
        }
        
        val json = JSONObject(responseBody)
        val events = mutableListOf<Map<String, String>>()
        
        if (json.optBoolean("success", false)) {
            val eventsArray = json.optJSONArray("events") ?: JSONArray()
            
            for (i in 0 until eventsArray.length()) {
                val eventJson = eventsArray.getJSONObject(i)
                events.add(mapOf(
                    "title" to eventJson.optString("title", ""),
                    "date" to eventJson.optString("date", ""),
                    "time" to eventJson.optString("time", ""),
                    "location" to eventJson.optString("location", ""),
                    "description" to eventJson.optString("description", "")
                ))
            }
        }
        
        println("[SnapCal] Found ${events.size} events")
        return events
    }
    
    /**
     * Store events in SharedPreferences as JSON array.
     * Each entry has timestamp for history ordering.
     */
    private fun storeEventsInHistory(events: List<Map<String, String>>) {
        if (events.isEmpty()) {
            println("[SnapCal] No events to store")
            return
        }
        
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val existingJson = prefs.getString(KEY_EVENT_HISTORY, "[]") ?: "[]"
            val historyArray = JSONArray(existingJson)
            
            // Create new history entry
            val entry = JSONObject().apply {
                put("timestamp", System.currentTimeMillis())
                put("events", JSONArray().apply {
                    events.forEach { event ->
                        put(JSONObject().apply {
                            put("title", event["title"])
                            put("date", event["date"])
                            put("time", event["time"])
                            put("location", event["location"])
                            put("description", event["description"])
                        })
                    }
                })
            }
            
            // Add to beginning (most recent first)
            val newHistory = JSONArray()
            newHistory.put(entry)
            for (i in 0 until minOf(historyArray.length(), 49)) { // Keep max 50 entries
                newHistory.put(historyArray.get(i))
            }
            
            // Save
            prefs.edit().putString(KEY_EVENT_HISTORY, newHistory.toString()).apply()
            println("[SnapCal] Stored ${events.size} events in history")
            
        } catch (e: Exception) {
            println("[SnapCal] Failed to store events: ${e.message}")
        }
    }
    
    private fun getNotificationService(): TapCalNotificationService? {
        return TapCalNotificationService.instance
    }
}
