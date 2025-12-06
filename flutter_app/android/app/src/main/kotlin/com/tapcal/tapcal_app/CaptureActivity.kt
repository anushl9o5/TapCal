package com.tapcal.tapcal_app

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper

/**
 * Minimal activity that just triggers the capture sequence.
 * The AccessibilityService handles closing the notification shade
 * using GLOBAL_ACTION_BACK gestures.
 */
class CaptureActivity : Activity() {
    
    companion object {
        private var isCapturing = false
        private val handler = Handler(Looper.getMainLooper())
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Prevent duplicate captures
        if (isCapturing) {
            println("[SnapCal] CaptureActivity: Already capturing, finishing...")
            finish()
            return
        }
        
        isCapturing = true
        println("[SnapCal] CaptureActivity: Starting capture sequence")
        
        // Update notification to show analyzing state
        TapCalNotificationService.instance?.updateNotification(
            "Looking for events...",
            "Analyzing screen content"
        )
        
        // Immediately finish this activity
        finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
        
        // Trigger accessibility service to close shade and capture
        // Small delay to let this activity fully close first
        handler.postDelayed({
            val accessibilityService = TapCalAccessibilityService.instance
            if (accessibilityService != null) {
                accessibilityService.captureFromNotification()
            } else {
                println("[SnapCal] Accessibility service not available!")
                TapCalNotificationService.instance?.apply {
                    updateNotification("Service not ready", "Enable accessibility first")
                    handler.postDelayed({ resetToReady() }, 3000)
                }
                isCapturing = false
            }
            
            // Reset capture flag after capture completes
            handler.postDelayed({
                isCapturing = false
            }, 5000)
            
        }, 100)
    }
}

