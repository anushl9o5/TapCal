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
        
        // Auto-return to TapCal app after enabling accessibility
        bringAppToForeground()
    }
    
    private fun bringAppToForeground() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            }
            startActivity(intent)
            println("[TapCal] Returning to TapCal app...")
        } catch (e: Exception) {
            println("[TapCal] Could not bring app to foreground: ${e.message}")
        }
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun createFloatingButton() {
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        // Create button container with pulse glow effect
        val container = FrameLayout(this)
        
        // Outer glow ring for pulse effect
        val glowRing = View(this).apply {
            val glowSize = 130
            layoutParams = FrameLayout.LayoutParams(glowSize, glowSize).apply {
                gravity = Gravity.CENTER
            }
            val glowShape = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0x006366F1.toInt()) // Transparent center
                setStroke(4, 0x406366F1.toInt()) // Subtle glow border
            }
            background = glowShape
            alpha = 0f
        }
        container.addView(glowRing)
        
        // Create the circular button with transparency
        val button = ImageView(this).apply {
            val size = 110
            layoutParams = FrameLayout.LayoutParams(size, size).apply {
                gravity = Gravity.CENTER
            }
            
            // Semi-transparent circular background (70% opacity)
            val shape = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(0xB36366F1.toInt()) // Indigo with 70% opacity
                setStroke(2, 0x99FFFFFF.toInt()) // White border with 60% opacity
            }
            background = shape
            
            // Camera/capture icon
            setImageResource(android.R.drawable.ic_menu_camera)
            setColorFilter(0xFFFFFFFF.toInt())
            scaleType = ImageView.ScaleType.CENTER
            setPadding(28, 28, 28, 28)
        }
        container.addView(button)
        
        // Start subtle pulse animation on the glow ring
        startButtonPulseAnimation(glowRing)
        
        floatingButton = container
        
        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }
        
        buttonParams = WindowManager.LayoutParams(
            130,
            130,
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
            println("[TapCal] Floating button created with pulse animation")
        } catch (e: Exception) {
            println("[TapCal] Failed to create button: ${e.message}")
        }
    }
    
    private fun startButtonPulseAnimation(glowRing: View) {
        // Create a subtle pulse animation that loops
        val pulseIn = glowRing.animate()
            .alpha(0.6f)
            .scaleX(1.15f)
            .scaleY(1.15f)
            .setDuration(1200)
            
        val runPulse = object : Runnable {
            var expanding = true
            override fun run() {
                if (floatingButton?.visibility != View.VISIBLE) {
                    glowRing.alpha = 0f
                    return
                }
                
                if (expanding) {
                    glowRing.animate()
                        .alpha(0.5f)
                        .scaleX(1.2f)
                        .scaleY(1.2f)
                        .setDuration(1000)
                        .withEndAction { 
                            expanding = false
                            handler.post(this)
                        }
                        .start()
                } else {
                    glowRing.animate()
                        .alpha(0f)
                        .scaleX(1.0f)
                        .scaleY(1.0f)
                        .setDuration(1000)
                        .withEndAction { 
                            expanding = true
                            handler.postDelayed(this, 500) // Pause between pulses
                        }
                        .start()
                }
            }
        }
        
        handler.postDelayed(runPulse, 500)
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
                                    
                                    // Process full screenshot directly (no tap selection needed)
                                    capturedBitmap = softwareBitmap
                                    showQuickCaptureAnimation()
                                    processFullScreenshot(softwareBitmap)
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
                
                // Create main container
                val container = FrameLayout(this)
                
                // Add screenshot as background with slight dim
                val imageView = ImageView(this).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                    )
                    setImageBitmap(bitmap)
                    scaleType = ImageView.ScaleType.FIT_XY
                    // Slight dim to show it's a capture
                    alpha = 0.95f
                }
                container.addView(imageView)
                
                // Semi-transparent overlay gradient at top
                val topGradient = View(this).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        300
                    ).apply {
                        gravity = Gravity.TOP
                    }
                    val gradient = GradientDrawable(
                        GradientDrawable.Orientation.TOP_BOTTOM,
                        intArrayOf(0xDD1E293B.toInt(), 0x001E293B.toInt())
                    )
                    background = gradient
                }
                container.addView(topGradient)
                
                // Semi-transparent overlay gradient at bottom
                val bottomGradient = View(this).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        350
                    ).apply {
                        gravity = Gravity.BOTTOM
                    }
                    val gradient = GradientDrawable(
                        GradientDrawable.Orientation.BOTTOM_TOP,
                        intArrayOf(0xEE1E293B.toInt(), 0x001E293B.toInt())
                    )
                    background = gradient
                }
                container.addView(bottomGradient)
                
                // Header container with icon and text
                val headerContainer = FrameLayout(this).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        gravity = Gravity.TOP
                        topMargin = 60
                        leftMargin = 24
                        rightMargin = 24
                    }
                }
                
                // Instruction pill/badge
                val instructionBadge = TextView(this).apply {
                    text = "  👆  Tap on event info to analyze  "
                    setTextColor(Color.WHITE)
                    textSize = 15f
                    setPadding(48, 24, 48, 24)
                    
                    val pillBackground = GradientDrawable().apply {
                        shape = GradientDrawable.RECTANGLE
                        cornerRadius = 50f
                        setColor(0xCC6366F1.toInt()) // Indigo with transparency
                    }
                    background = pillBackground
                    
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        gravity = Gravity.CENTER_HORIZONTAL
                    }
                }
                headerContainer.addView(instructionBadge)
                container.addView(headerContainer)
                
                // Bottom action area
                val bottomContainer = FrameLayout(this).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        gravity = Gravity.BOTTOM
                        bottomMargin = 50
                        leftMargin = 24
                        rightMargin = 24
                    }
                }
                
                // Cancel button with modern styling
                val cancelButton = TextView(this).apply {
                    text = "Cancel"
                    setTextColor(Color.WHITE)
                    textSize = 16f
                    setPadding(64, 18, 64, 18)
                    
                    val buttonBackground = GradientDrawable().apply {
                        shape = GradientDrawable.RECTANGLE
                        cornerRadius = 30f
                        setColor(0x40FFFFFF.toInt()) // White with low opacity
                        setStroke(2, 0x60FFFFFF.toInt())
                    }
                    background = buttonBackground
                    
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        gravity = Gravity.CENTER_HORIZONTAL
                    }
                    
                    setOnClickListener {
                        dismissScreenshotOverlay()
                        showButton()
                    }
                }
                bottomContainer.addView(cancelButton)
                container.addView(bottomContainer)
                
                // Floating help text
                val helpText = TextView(this).apply {
                    text = "The area around your tap will be analyzed"
                    setTextColor(0xAAFFFFFF.toInt())
                    textSize = 12f
                    gravity = Gravity.CENTER
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        gravity = Gravity.BOTTOM
                        bottomMargin = 120
                    }
                }
                container.addView(helpText)
                
                // Visual tap feedback indicator
                var tapIndicator: View? = null
                
                // Handle tap on screenshot with visual feedback
                imageView.setOnTouchListener { view, event ->
                    when (event.action) {
                        MotionEvent.ACTION_DOWN -> {
                            // Show tap indicator at touch position
                            tapIndicator = View(this).apply {
                                val indicatorSize = 120
                                layoutParams = FrameLayout.LayoutParams(indicatorSize, indicatorSize).apply {
                                    leftMargin = (event.x - indicatorSize / 2).toInt()
                                    topMargin = (event.y - indicatorSize / 2).toInt()
                                }
                                
                                val ripple = GradientDrawable().apply {
                                    shape = GradientDrawable.OVAL
                                    setColor(0x406366F1.toInt())
                                    setStroke(4, 0x806366F1.toInt())
                                }
                                background = ripple
                                alpha = 0f
                                
                                // Animate in
                                animate()
                                    .alpha(1f)
                                    .scaleX(1.3f)
                                    .scaleY(1.3f)
                                    .setDuration(150)
                                    .start()
                            }
                            container.addView(tapIndicator)
                            true
                        }
                        MotionEvent.ACTION_UP -> {
                            val tapX = event.x
                            val tapY = event.y
                            
                            // Animate tap indicator out and show processing
                            tapIndicator?.animate()
                                ?.alpha(0.8f)
                                ?.scaleX(2f)
                                ?.scaleY(2f)
                                ?.setDuration(200)
                                ?.withEndAction {
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
                                ?.start()
                            true
                        }
                        MotionEvent.ACTION_CANCEL -> {
                            // Remove indicator on cancel
                            tapIndicator?.let { container.removeView(it) }
                            true
                        }
                        else -> true
                    }
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
        }
    }
    
    /**
     * Show a brief "captured" animation - just a quick flash
     */
    private fun showQuickCaptureAnimation() {
        handler.post {
            try {
                val wm = getSystemService(WINDOW_SERVICE) as WindowManager
                
                // Simple flash overlay
                val flashView = View(this).apply {
                    setBackgroundColor(0x40FFFFFF.toInt())
                    alpha = 0f
                }
                
                val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
                }
                
                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    layoutFlag,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
                    PixelFormat.TRANSLUCENT
                )
                
                wm.addView(flashView, params)
                
                // Quick flash animation
                flashView.animate()
                    .alpha(1f)
                    .setDuration(100)
                    .withEndAction {
                        flashView.animate()
                            .alpha(0f)
                            .setDuration(150)
                            .withEndAction {
                                try { wm.removeView(flashView) } catch (_: Exception) {}
                            }
                            .start()
                    }
                    .start()
                    
                println("[TapCal] 📸 Capture flash shown")
            } catch (e: Exception) {
                println("[TapCal] Flash animation error: ${e.message}")
            }
        }
    }
    
    /**
     * Process the full screenshot without cropping - analyze for multiple events
     */
    private fun processFullScreenshot(bitmap: Bitmap) {
        println("[TapCal] Processing full screenshot for multiple events")
        
        try {
            // Scale down for faster processing
            val maxWidth = 1080
            val scaledBitmap = if (bitmap.width > maxWidth) {
                val scale = maxWidth.toFloat() / bitmap.width
                val scaledHeight = (bitmap.height * scale).toInt()
                Bitmap.createScaledBitmap(bitmap, maxWidth, scaledHeight, true)
            } else {
                bitmap
            }
            
            // Save to file
            val cacheDir = applicationContext.cacheDir
            val file = java.io.File(cacheDir, "screenshot_${System.currentTimeMillis()}.jpg")
            java.io.FileOutputStream(file).use { fos ->
                scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 80, fos)
            }
            
            println("[TapCal] Full screenshot saved: ${file.length() / 1024} KB")
            
            // Clean up bitmaps
            if (scaledBitmap !== bitmap) {
                scaledBitmap.recycle()
            }
            capturedBitmap?.recycle()
            capturedBitmap = null
            
            // Launch app with full screenshot
            launchAppWithScreenshotFile(file.absolutePath)
            
        } catch (e: Exception) {
            println("[TapCal] Error processing screenshot: ${e.message}")
            e.printStackTrace()
            showButton()
        }
    }
    
    // Legacy function - kept for compatibility but no longer used
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
    
    // ============================================
    // EVENT OVERLAY - Shows swipeable cards at bottom
    // ============================================
    
    private var eventsOverlay: View? = null
    private var currentEventIndex = 0
    private var detectedEvents: List<Map<String, String>> = emptyList()
    
    /**
     * Show events as swipeable cards at the bottom of the screen (overlay mode)
     */
    @SuppressLint("ClickableViewAccessibility")
    fun showEventsOverlay(events: List<Map<String, String>>) {
        if (events.isEmpty()) {
            showButton()
            return
        }
        
        detectedEvents = events
        currentEventIndex = 0
        
        handler.post {
            try {
                dismissEventsOverlay()
                
                val wm = getSystemService(WINDOW_SERVICE) as WindowManager
                val metrics = DisplayMetrics()
                @Suppress("DEPRECATION")
                wm.defaultDisplay.getRealMetrics(metrics)
                
                // Main container
                val container = FrameLayout(this)
                
                // Semi-transparent backdrop (tappable to dismiss)
                val backdrop = View(this).apply {
                    setBackgroundColor(0x60000000.toInt())
                    setOnClickListener {
                        dismissEventsOverlay()
                        showButton()
                    }
                }
                container.addView(backdrop, FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                ))
                
                // Bottom card container
                val cardContainer = FrameLayout(this).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        gravity = Gravity.BOTTOM
                    }
                }
                
                // Card background
                val cardBg = GradientDrawable().apply {
                    shape = GradientDrawable.RECTANGLE
                    cornerRadii = floatArrayOf(32f, 32f, 32f, 32f, 0f, 0f, 0f, 0f)
                    setColor(0xFFFFFFFF.toInt())
                }
                cardContainer.background = cardBg
                cardContainer.elevation = 24f
                
                // Card content layout
                val cardContent = android.widget.LinearLayout(this).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    setPadding(48, 32, 48, 60)
                }
                
                // Header row with count
                val headerRow = FrameLayout(this)
                
                val titleText = TextView(this).apply {
                    text = "📅 ${events.size} Event${if (events.size > 1) "s" else ""} Found"
                    setTextColor(0xFF1E293B.toInt())
                    textSize = 18f
                    setTypeface(null, android.graphics.Typeface.BOLD)
                }
                headerRow.addView(titleText, FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT
                ).apply { gravity = Gravity.START or Gravity.CENTER_VERTICAL })
                
                val closeBtn = TextView(this).apply {
                    text = "✕"
                    setTextColor(0xFF94A3B8.toInt())
                    textSize = 20f
                    setPadding(16, 8, 8, 8)
                    setOnClickListener {
                        dismissEventsOverlay()
                        showButton()
                    }
                }
                headerRow.addView(closeBtn, FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT
                ).apply { gravity = Gravity.END or Gravity.CENTER_VERTICAL })
                
                cardContent.addView(headerRow, android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                ))
                
                // Spacer
                cardContent.addView(View(this), android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT, 24
                ))
                
                // Event card holder (will show current event)
                val eventHolder = FrameLayout(this)
                eventHolder.id = View.generateViewId()
                cardContent.addView(eventHolder, android.widget.LinearLayout.LayoutParams(
                    android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                    android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                ))
                
                // Build the event card view
                fun buildEventCard(event: Map<String, String>, index: Int): View {
                    val eventCard = android.widget.LinearLayout(this).apply {
                        orientation = android.widget.LinearLayout.VERTICAL
                        setPadding(32, 24, 32, 24)
                        
                        val cardShape = GradientDrawable().apply {
                            shape = GradientDrawable.RECTANGLE
                            cornerRadius = 20f
                            setColor(0xFFF8FAFC.toInt())
                        }
                        background = cardShape
                    }
                    
                    // Event title
                    val eventTitle = TextView(this).apply {
                        text = event["title"] ?: "Event"
                        setTextColor(0xFF1E293B.toInt())
                        textSize = 17f
                        setTypeface(null, android.graphics.Typeface.BOLD)
                        maxLines = 2
                    }
                    eventCard.addView(eventTitle)
                    
                    // Date & Time row
                    val dateTimeRow = android.widget.LinearLayout(this).apply {
                        orientation = android.widget.LinearLayout.HORIZONTAL
                        setPadding(0, 16, 0, 0)
                    }
                    
                    val dateText = TextView(this).apply {
                        text = "📅 ${event["date"] ?: ""}"
                        setTextColor(0xFF64748B.toInt())
                        textSize = 14f
                    }
                    dateTimeRow.addView(dateText)
                    
                    val spacer = View(this)
                    dateTimeRow.addView(spacer, android.widget.LinearLayout.LayoutParams(24, 0))
                    
                    val timeText = TextView(this).apply {
                        text = "🕐 ${event["time"] ?: ""}"
                        setTextColor(0xFF64748B.toInt())
                        textSize = 14f
                    }
                    dateTimeRow.addView(timeText)
                    
                    eventCard.addView(dateTimeRow)
                    
                    // Location if present
                    val location = event["location"]
                    if (!location.isNullOrEmpty()) {
                        val locText = TextView(this).apply {
                            text = "📍 $location"
                            setTextColor(0xFF64748B.toInt())
                            textSize = 14f
                            setPadding(0, 8, 0, 0)
                        }
                        eventCard.addView(locText)
                    }
                    
                    // Add to Calendar button
                    val addButton = TextView(this).apply {
                        text = "➕  Add to Calendar"
                        setTextColor(0xFFFFFFFF.toInt())
                        textSize = 15f
                        gravity = Gravity.CENTER
                        setPadding(0, 28, 0, 28)
                        
                        val btnShape = GradientDrawable().apply {
                            shape = GradientDrawable.RECTANGLE
                            cornerRadius = 14f
                            setColor(0xFF10B981.toInt())
                        }
                        background = btnShape
                        
                        setOnClickListener {
                            addEventToCalendar(event)
                            // Move to next event or close
                            if (index < events.size - 1) {
                                currentEventIndex++
                                eventHolder.removeAllViews()
                                eventHolder.addView(buildEventCard(events[currentEventIndex], currentEventIndex))
                                titleText.text = "📅 ${events.size - currentEventIndex} Event${if (events.size - currentEventIndex > 1) "s" else ""} Remaining"
                            } else {
                                dismissEventsOverlay()
                                showButton()
                            }
                        }
                    }
                    
                    val btnParams = android.widget.LinearLayout.LayoutParams(
                        android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                        android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply { topMargin = 24 }
                    eventCard.addView(addButton, btnParams)
                    
                    // Skip button
                    if (events.size > 1) {
                        val skipBtn = TextView(this).apply {
                            text = if (index < events.size - 1) "Skip →" else "Done"
                            setTextColor(0xFF6366F1.toInt())
                            textSize = 14f
                            gravity = Gravity.CENTER
                            setPadding(0, 16, 0, 0)
                            
                            setOnClickListener {
                                if (index < events.size - 1) {
                                    currentEventIndex++
                                    eventHolder.removeAllViews()
                                    eventHolder.addView(buildEventCard(events[currentEventIndex], currentEventIndex))
                                    titleText.text = "📅 ${events.size - currentEventIndex} Event${if (events.size - currentEventIndex > 1) "s" else ""} Remaining"
                                } else {
                                    dismissEventsOverlay()
                                    showButton()
                                }
                            }
                        }
                        eventCard.addView(skipBtn)
                    }
                    
                    return eventCard
                }
                
                // Show first event
                eventHolder.addView(buildEventCard(events[0], 0))
                
                // Page indicator if multiple events
                if (events.size > 1) {
                    val indicatorRow = android.widget.LinearLayout(this).apply {
                        orientation = android.widget.LinearLayout.HORIZONTAL
                        gravity = Gravity.CENTER
                        setPadding(0, 16, 0, 0)
                    }
                    
                    val indicator = TextView(this).apply {
                        text = "1 of ${events.size}"
                        setTextColor(0xFF94A3B8.toInt())
                        textSize = 12f
                    }
                    indicatorRow.addView(indicator)
                    
                    cardContent.addView(indicatorRow)
                }
                
                cardContainer.addView(cardContent)
                container.addView(cardContainer)
                
                eventsOverlay = container
                
                val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
                }
                
                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    layoutFlag,
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                    PixelFormat.TRANSLUCENT
                )
                
                wm.addView(eventsOverlay, params)
                println("[TapCal] Events overlay displayed with ${events.size} events")
                
            } catch (e: Exception) {
                println("[TapCal] Error showing events overlay: ${e.message}")
                e.printStackTrace()
                showButton()
            }
        }
    }
    
    private fun addEventToCalendar(event: Map<String, String>) {
        try {
            val calendar = java.util.Calendar.getInstance()
            
            // Parse date
            val date = event["date"] ?: ""
            try {
                val dateParts = date.split("-")
                if (dateParts.size >= 3) {
                    calendar.set(java.util.Calendar.YEAR, dateParts[0].toInt())
                    calendar.set(java.util.Calendar.MONTH, dateParts[1].toInt() - 1)
                    calendar.set(java.util.Calendar.DAY_OF_MONTH, dateParts[2].toInt())
                }
            } catch (e: Exception) {
                println("[TapCal] Could not parse date: $date")
            }
            
            // Parse time
            val time = event["time"] ?: "12:00"
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
                    
                    calendar.set(java.util.Calendar.HOUR_OF_DAY, hour)
                    calendar.set(java.util.Calendar.MINUTE, minute)
                }
            } catch (e: Exception) {
                calendar.set(java.util.Calendar.HOUR_OF_DAY, 12)
                calendar.set(java.util.Calendar.MINUTE, 0)
            }
            
            calendar.set(java.util.Calendar.SECOND, 0)
            
            val startMillis = calendar.timeInMillis
            val endMillis = startMillis + 60 * 60 * 1000 // 1 hour
            
            val intent = Intent(Intent.ACTION_INSERT).apply {
                data = android.provider.CalendarContract.Events.CONTENT_URI
                putExtra(android.provider.CalendarContract.Events.TITLE, event["title"] ?: "Event")
                putExtra(android.provider.CalendarContract.EXTRA_EVENT_BEGIN_TIME, startMillis)
                putExtra(android.provider.CalendarContract.EXTRA_EVENT_END_TIME, endMillis)
                putExtra(android.provider.CalendarContract.Events.ALL_DAY, false)
                
                event["location"]?.let { loc ->
                    if (loc.isNotEmpty()) {
                        putExtra(android.provider.CalendarContract.Events.EVENT_LOCATION, loc)
                    }
                }
                event["description"]?.let { desc ->
                    if (desc.isNotEmpty()) {
                        putExtra(android.provider.CalendarContract.Events.DESCRIPTION, desc)
                    }
                }
                
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            
            startActivity(intent)
            println("[TapCal] Calendar opened for: ${event["title"]}")
            
        } catch (e: Exception) {
            println("[TapCal] Error opening calendar: ${e.message}")
        }
    }
    
    private fun dismissEventsOverlay() {
        try {
            eventsOverlay?.let {
                windowManager?.removeView(it)
            }
        } catch (e: Exception) { }
        eventsOverlay = null
        detectedEvents = emptyList()
        currentEventIndex = 0
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

