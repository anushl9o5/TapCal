package com.tapcal.tapcal_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import android.provider.Settings
import android.text.TextUtils
import android.util.Base64
import android.util.DisplayMetrics
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.Calendar
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tapcal/accessibility"
    private val SCREEN_CAPTURE_REQUEST_CODE = 1001
    
    private var methodChannel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null
    private val handler = Handler(Looper.getMainLooper())
    
    // Screen capture
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var captureFromButton = false

    companion object {
        var instance: MainActivity? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        instance = this
        
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
                "requestScreenCapture" -> {
                    captureFromButton = false
                    requestScreenCapture(result)
                }
                "showFloatingButton" -> {
                    TapCalAccessibilityService.instance?.showButton()
                    result.success(true)
                }
                "hideFloatingButton" -> {
                    TapCalAccessibilityService.instance?.hideButton()
                    result.success(true)
                }
                "analysisComplete" -> {
                    // Analysis done - show button again
                    TapCalAccessibilityService.instance?.showButton()
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
                "showEventsOverlay" -> {
                    @Suppress("UNCHECKED_CAST")
                    val eventsList = call.argument<List<Map<String, String>>>("events")
                    if (eventsList != null) {
                        TapCalAccessibilityService.instance?.showEventsOverlay(eventsList)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Events list is null", null)
                    }
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
                println("[MainActivity] Could not parse date: $date, using current date")
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
                println("[MainActivity] Could not parse time: $time")
                calendar.set(Calendar.HOUR_OF_DAY, 12)
                calendar.set(Calendar.MINUTE, 0)
            }
            
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            
            val startMillis = calendar.timeInMillis
            val endMillis = startMillis + 60 * 60 * 1000 // 1 hour duration
            
            println("[MainActivity] Opening calendar with:")
            println("[MainActivity]   Title: $title")
            println("[MainActivity]   Date/Time: ${calendar.time}")
            println("[MainActivity]   Location: $location")
            
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
            println("[MainActivity] Calendar app opened!")
            
        } catch (e: Exception) {
            println("[MainActivity] Error opening calendar: ${e.message}")
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
                    println("[MainActivity] 🗑️ Cleaned up stale screenshot: ${file.name}")
                }
            }
        } catch (e: Exception) {
            println("[MainActivity] Error cleaning up screenshots: ${e.message}")
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        intent?.let {
            when (it.getStringExtra("action")) {
                "capture_screen" -> {
                    // Legacy: MediaProjection approach for older Android
                    println("[MainActivity] Capture screen request (MediaProjection)")
                    captureFromButton = true
                    handler.postDelayed({
                        requestScreenCaptureForButton()
                    }, 100)
                }
                "process_screenshot" -> {
                    // Legacy: base64 in Intent (small images only)
                    println("[MainActivity] Processing screenshot from intent")
                    val base64Image = it.getStringExtra("screenshot")
                    if (base64Image != null) {
                        println("[MainActivity] Screenshot size: ${base64Image.length} chars")
                        onScreenCaptured(base64Image)
                    } else {
                        println("[MainActivity] No screenshot data!")
                        TapCalAccessibilityService.instance?.showButton()
                    }
                }
                "process_screenshot_file" -> {
                    // New: Read from file (avoids Intent size limit)
                    println("[MainActivity] Processing screenshot from file")
                    val filePath = it.getStringExtra("screenshot_path")
                    if (filePath != null) {
                        try {
                            val file = java.io.File(filePath)
                            if (file.exists()) {
                                val bytes = file.readBytes()
                                val base64Image = Base64.encodeToString(bytes, Base64.NO_WRAP)
                                println("[MainActivity] Screenshot loaded: ${base64Image.length} chars from ${file.length() / 1024}KB file")
                                
                                // PRIVACY: Delete screenshot file immediately after reading
                                if (file.delete()) {
                                    println("[MainActivity] 🗑️ Screenshot file deleted for privacy")
                                }
                                
                                onScreenCaptured(base64Image)
                            } else {
                                println("[MainActivity] Screenshot file not found: $filePath")
                                TapCalAccessibilityService.instance?.showButton()
                            }
                        } catch (e: Exception) {
                            println("[MainActivity] Error reading screenshot: ${e.message}")
                            // Try to delete file even on error
                            try { java.io.File(filePath).delete() } catch (_: Exception) {}
                            TapCalAccessibilityService.instance?.showButton()
                        }
                    } else {
                        println("[MainActivity] No file path provided!")
                        TapCalAccessibilityService.instance?.showButton()
                    }
                }
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

    private fun requestScreenCapture(result: MethodChannel.Result) {
        pendingResult = result
        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(projectionManager.createScreenCaptureIntent(), SCREEN_CAPTURE_REQUEST_CODE)
    }

    private fun requestScreenCaptureForButton() {
        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        startActivityForResult(projectionManager.createScreenCaptureIntent(), SCREEN_CAPTURE_REQUEST_CODE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == SCREEN_CAPTURE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                println("[MainActivity] Screen capture permission granted")
                captureScreen(resultCode, data)
            } else {
                println("[MainActivity] Screen capture denied")
                pendingResult?.success(false)
                pendingResult = null
                // Show button again if capture was denied
                TapCalAccessibilityService.instance?.showButton()
            }
        }
    }

    private fun captureScreen(resultCode: Int, data: Intent) {
        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = projectionManager.getMediaProjection(resultCode, data)
        
        if (mediaProjection == null) {
            println("[MainActivity] Failed to get media projection")
            TapCalAccessibilityService.instance?.showButton()
            return
        }
        
        val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val display = display
            display?.getRealMetrics(metrics)
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getRealMetrics(metrics)
        }
        
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val density = metrics.densityDpi
        
        imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        
        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "TapCalCapture",
            width, height, density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface, null, null
        )
        
        // Capture after a short delay
        handler.postDelayed({
            try {
                val image = imageReader?.acquireLatestImage()
                if (image != null) {
                    val planes = image.planes
                    val buffer = planes[0].buffer
                    val pixelStride = planes[0].pixelStride
                    val rowStride = planes[0].rowStride
                    val rowPadding = rowStride - pixelStride * width
                    
                    val bitmap = Bitmap.createBitmap(
                        width + rowPadding / pixelStride,
                        height,
                        Bitmap.Config.ARGB_8888
                    )
                    bitmap.copyPixelsFromBuffer(buffer)
                    image.close()
                    
                    // Crop to actual size
                    val croppedBitmap = Bitmap.createBitmap(bitmap, 0, 0, width, height)
                    bitmap.recycle()
                    
                    // Convert to base64
                    val outputStream = ByteArrayOutputStream()
                    croppedBitmap.compress(Bitmap.CompressFormat.JPEG, 80, outputStream)
                    val base64Image = Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
                    croppedBitmap.recycle()
                    
                    println("[MainActivity] Screenshot captured: ${base64Image.length} chars")
                    
                    // Send to Flutter
                    onScreenCaptured(base64Image)
                } else {
                    println("[MainActivity] Failed to acquire image")
                    TapCalAccessibilityService.instance?.showButton()
                }
            } catch (e: Exception) {
                println("[MainActivity] Capture error: ${e.message}")
                TapCalAccessibilityService.instance?.showButton()
            } finally {
                releaseMediaProjection()
            }
        }, 300)
    }

    private fun releaseMediaProjection() {
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        mediaProjection?.stop()
        mediaProjection = null
    }

    fun onScreenCaptured(base64Image: String) {
        runOnUiThread {
            methodChannel?.invokeMethod("onScreenCaptured", base64Image)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        releaseMediaProjection()
        if (instance == this) {
            instance = null
        }
    }
}

