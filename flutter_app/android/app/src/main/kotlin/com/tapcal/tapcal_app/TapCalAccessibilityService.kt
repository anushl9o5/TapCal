package com.tapcal.tapcal_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.GradientDrawable
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.DisplayMetrics
import android.view.Display
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.ImageView
import android.widget.FrameLayout
import android.widget.TextView
import java.io.ByteArrayOutputStream

class TapCalAccessibilityService : AccessibilityService() {
    
    companion object {
        var instance: TapCalAccessibilityService? = null
        var isRunning = false
        var isAnalyzing = false // Prevents multiple requests
    }
    
    private var windowManager: WindowManager? = null
    private var floatingButton: View? = null
    private var buttonParams: WindowManager.LayoutParams? = null
    private val handler = Handler(Looper.getMainLooper())
    
    // For dragging
    private var initialX: Int = 0
    private var initialY: Int = 0
    private var initialTouchX: Float = 0f
    private var initialTouchY: Float = 0f
    
    // Media Projection for screen capture
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    
    // Screenshot overlay for tap-to-crop
    private var screenshotOverlay: View? = null
    private var capturedBitmap: Bitmap? = null
    private var overlayParams: WindowManager.LayoutParams? = null
    
    // Crop region height (pixels above and below tap point)
    private val CROP_HEIGHT = 500

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        isRunning = true
        isAnalyzing = false
        
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 100
        }
        serviceInfo = info
        
        // Create the floating button
        createFloatingButton()
        
        println("[TapCal] ========================================")
        println("[TapCal] Accessibility Service CONNECTED")
        println("[TapCal] Floating button ready!")
        println("[TapCal] Tap the button to capture any screen")
        println("[TapCal] ========================================")
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun createFloatingButton() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        // Create button container
        val container = FrameLayout(this)
        
        // Create the circular button
        val button = ImageView(this).apply {
            val size = 140
            layoutParams = FrameLayout.LayoutParams(size, size)
            
            // Circular blue background
            val shape = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xFF1976D2.toInt()) // Blue
                setStroke(6, 0xFFFFFFFF.toInt()) // White border
            }
            background = shape
            
            // Calendar icon
            setImageResource(android.R.drawable.ic_menu_my_calendar)
            setColorFilter(0xFFFFFFFF.toInt())
            scaleType = ImageView.ScaleType.CENTER
            setPadding(35, 35, 35, 35)
        }
        
        container.addView(button)
        floatingButton = container
        
        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }
        
        buttonParams = WindowManager.LayoutParams(
            160,
            160,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 20
            y = 400
        }
        
        // Touch listener for drag and click
        container.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = buttonParams!!.x
                    initialY = buttonParams!!.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    buttonParams!!.x = initialX + (event.rawX - initialTouchX).toInt()
                    buttonParams!!.y = initialY + (event.rawY - initialTouchY).toInt()
                    windowManager?.updateViewLayout(floatingButton, buttonParams)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    val deltaX = Math.abs(event.rawX - initialTouchX)
                    val deltaY = Math.abs(event.rawY - initialTouchY)
                    
                    // If movement is small, treat as click
                    if (deltaX < 20 && deltaY < 20) {
                        onFloatingButtonClick()
                    }
                    true
                }
                else -> false
            }
        }
        
        try {
            windowManager?.addView(floatingButton, buttonParams)
            println("[TapCal] Floating button created")
        } catch (e: Exception) {
            println("[TapCal] Failed to create button: ${e.message}")
        }
    }

    private fun onFloatingButtonClick() {
        // Prevent multiple requests
        if (isAnalyzing) {
            println("[TapCal] Already analyzing, ignoring click")
            return
        }
        
        println("[TapCal] ========================================")
        println("[TapCal] 📸 Button clicked! Capturing screen...")
        println("[TapCal] ========================================")
        
        // Hide button while analyzing
        hideButton()
        isAnalyzing = true
        
        // Use Accessibility Service's built-in screenshot (Android 11+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            takeScreenshotWithAccessibility()
        } else {
            // Fallback for older Android - launch app
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("action", "capture_screen")
            }
            startActivity(intent)
        }
    }
    
    @android.annotation.TargetApi(Build.VERSION_CODES.R)
    private fun takeScreenshotWithAccessibility() {
        println("[TapCal] Using Accessibility takeScreenshot API")
        
        try {
            takeScreenshot(
                Display.DEFAULT_DISPLAY,
                mainExecutor,
                object : TakeScreenshotCallback {
                    override fun onSuccess(screenshot: ScreenshotResult) {
                        println("[TapCal] Screenshot successful!")
                        try {
                            val hardwareBuffer = screenshot.hardwareBuffer
                            val colorSpace = screenshot.colorSpace
                            
                            if (hardwareBuffer != null) {
                                val bitmap = Bitmap.wrapHardwareBuffer(hardwareBuffer, colorSpace)
                                if (bitmap != null) {
                                    // Convert to software bitmap
                                    val softwareBitmap = bitmap.copy(Bitmap.Config.ARGB_8888, false)
                                    bitmap.recycle()
                                    hardwareBuffer.close()
                                    
                                    // Store bitmap and show overlay for tap selection
                                    capturedBitmap = softwareBitmap
                                    showScreenshotOverlay(softwareBitmap)
                                } else {
                                    println("[TapCal] Failed to create bitmap from buffer")
                                    showButton()
                                }
                            } else {
                                println("[TapCal] Hardware buffer is null")
                                showButton()
                            }
                        } catch (e: Exception) {
                            println("[TapCal] Error processing screenshot: ${e.message}")
                            e.printStackTrace()
                            showButton()
                        }
                    }
                    
                    override fun onFailure(errorCode: Int) {
                        println("[TapCal] Screenshot failed with error code: $errorCode")
                        showButton()
                    }
                }
            )
        } catch (e: Exception) {
            println("[TapCal] Exception calling takeScreenshot: ${e.message}")
            e.printStackTrace()
            showButton()
        }
    }
    
    @SuppressLint("ClickableViewAccessibility")
    private fun showScreenshotOverlay(bitmap: Bitmap) {
        println("[TapCal] Showing screenshot overlay - tap to select region")
        
        handler.post {
            try {
                // Get screen dimensions via WindowManager (works in Service context)
                val wm = getSystemService(WINDOW_SERVICE) as WindowManager
                val metrics = DisplayMetrics()
                @Suppress("DEPRECATION")
                wm.defaultDisplay.getRealMetrics(metrics)
                
                // Create container
                val container = FrameLayout(this)
                container.setBackgroundColor(Color.BLACK)
                
                // Add screenshot as background
                val imageView = ImageView(this).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                    )
                    setImageBitmap(bitmap)
                    scaleType = ImageView.ScaleType.FIT_XY
                }
                container.addView(imageView)
                
                // Add instruction text at top
                val instructionText = TextView(this).apply {
                    text = "👆 Tap on the event to analyze"
                    setTextColor(Color.WHITE)
                    textSize = 18f
                    setPadding(32, 80, 32, 32)
                    setBackgroundColor(0xAA000000.toInt())
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        gravity = Gravity.TOP
                    }
                }
                container.addView(instructionText)
                
                // Add cancel button at bottom
                val cancelText = TextView(this).apply {
                    text = "✕ Cancel"
                    setTextColor(Color.WHITE)
                    textSize = 16f
                    setPadding(48, 32, 48, 80)
                    setBackgroundColor(0xAA000000.toInt())
                    gravity = Gravity.CENTER
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        gravity = Gravity.BOTTOM
                    }
                    setOnClickListener {
                        dismissScreenshotOverlay()
                        showButton()
                    }
                }
                container.addView(cancelText)
                
                // Handle tap on screenshot
                imageView.setOnTouchListener { _, event ->
                    if (event.action == MotionEvent.ACTION_UP) {
                        val tapX = event.x
                        val tapY = event.y
                        
                        // Convert tap coordinates to bitmap coordinates
                        val scaleX = bitmap.width.toFloat() / imageView.width
                        val scaleY = bitmap.height.toFloat() / imageView.height
                        val bitmapX = (tapX * scaleX).toInt()
                        val bitmapY = (tapY * scaleY).toInt()
                        
                        println("[TapCal] Tap at screen: ($tapX, $tapY)")
                        println("[TapCal] Tap at bitmap: ($bitmapX, $bitmapY)")
                        
                        // Crop and process
                        cropAndProcessRegion(bitmap, bitmapX, bitmapY)
                    }
                    true
                }
                
                screenshotOverlay = container
                
                val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
                }
                
                overlayParams = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    layoutFlag,
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    PixelFormat.TRANSLUCENT
                )
                
                windowManager?.addView(screenshotOverlay, overlayParams)
                println("[TapCal] Screenshot overlay displayed")
                
            } catch (e: Exception) {
                println("[TapCal] Error showing overlay: ${e.message}")
                e.printStackTrace()
                showButton()
            }
        }
    }
    
    private fun dismissScreenshotOverlay() {
        handler.post {
            try {
                screenshotOverlay?.let {
                    windowManager?.removeView(it)
                }
            } catch (e: Exception) {
                println("[TapCal] Error removing overlay: ${e.message}")
            }
            screenshotOverlay = null
            isAnalyzing = false
        }
    }
    
    private fun cropAndProcessRegion(bitmap: Bitmap, centerX: Int, centerY: Int) {
        println("[TapCal] Cropping horizontal strip around Y=$centerY")
        
        try {
            // Full width, crop only height
            val left = 0
            val right = bitmap.width
            
            // Calculate vertical crop bounds
            val halfHeight = CROP_HEIGHT / 2
            var top = centerY - halfHeight
            var bottom = centerY + halfHeight
            
            // Clamp to bitmap bounds (shift if needed)
            if (top < 0) {
                bottom -= top
                top = 0
            }
            if (bottom > bitmap.height) {
                top -= (bottom - bitmap.height)
                bottom = bitmap.height
            }
            
            // Final clamp
            top = top.coerceAtLeast(0)
            bottom = bottom.coerceAtMost(bitmap.height)
            
            val cropWidth = right - left
            val cropHeight = bottom - top
            
            println("[TapCal] Crop bounds: full width=$cropWidth, top=$top, height=$cropHeight")
            
            // Crop the bitmap (full width, cropped height)
            val croppedBitmap = Bitmap.createBitmap(bitmap, left, top, cropWidth, cropHeight)
            
            // Dismiss overlay
            dismissScreenshotOverlay()
            
            // Save cropped image and send to app
            val cacheDir = applicationContext.cacheDir
            val file = java.io.File(cacheDir, "cropped_screenshot.jpg")
            java.io.FileOutputStream(file).use { fos ->
                croppedBitmap.compress(Bitmap.CompressFormat.JPEG, 85, fos)
            }
            
            println("[TapCal] Cropped image saved: ${file.length() / 1024} KB")
            
            // Clean up
            croppedBitmap.recycle()
            capturedBitmap?.recycle()
            capturedBitmap = null
            
            // Launch app with cropped image
            launchAppWithScreenshotFile(file.absolutePath)
            
        } catch (e: Exception) {
            println("[TapCal] Error cropping: ${e.message}")
            e.printStackTrace()
            dismissScreenshotOverlay()
            showButton()
        }
    }
    
    private fun launchAppWithScreenshotFile(filePath: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("action", "process_screenshot_file")
            putExtra("screenshot_path", filePath)
        }
        startActivity(intent)
    }
    
    fun hideButton() {
        handler.post {
            floatingButton?.visibility = View.GONE
            println("[TapCal] Button hidden")
        }
    }
    
    fun showButton() {
        handler.post {
            floatingButton?.visibility = View.VISIBLE
            isAnalyzing = false
            println("[TapCal] Button visible again")
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Not needed for floating button approach
    }

    override fun onInterrupt() {
        println("[TapCal] Service interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        floatingButton?.let {
            try {
                windowManager?.removeView(it)
            } catch (e: Exception) { }
        }
        screenshotOverlay?.let {
            try {
                windowManager?.removeView(it)
            } catch (e: Exception) { }
        }
        capturedBitmap?.recycle()
        capturedBitmap = null
        floatingButton = null
        screenshotOverlay = null
        instance = null
        isRunning = false
        isAnalyzing = false
        releaseMediaProjection()
        println("[TapCal] Service DESTROYED")
    }

    private fun onTripleTapDetected() {
        println("[TapCal] Triple-tap detected!")
        
        // Notify Flutter and bring app to front
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("action", "triple_tap")
        }
        startActivity(intent)
    }

    fun requestScreenCapture(resultCode: Int, data: Intent) {
        val projectionManager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = projectionManager.getMediaProjection(resultCode, data)
        
        if (mediaProjection != null) {
            captureScreen()
        }
    }

    private fun captureScreen() {
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
        
        // Capture after a short delay to ensure display is ready
        handler.postDelayed({
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
                croppedBitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
                val base64Image = Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
                croppedBitmap.recycle()
                
                // Send to Flutter
                MainActivity.instance?.onScreenCaptured(base64Image)
                
                releaseMediaProjection()
            }
        }, 100)
    }

    private fun releaseMediaProjection() {
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        mediaProjection?.stop()
        mediaProjection = null
    }
}

