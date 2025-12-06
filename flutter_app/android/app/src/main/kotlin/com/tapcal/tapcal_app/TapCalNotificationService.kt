package com.tapcal.tapcal_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Foreground Service that maintains a persistent notification in the shade.
 * When tapped, it triggers screenshot capture via the Accessibility Service.
 */
class TapCalNotificationService : Service() {
    
    companion object {
        const val CHANNEL_ID = "tapcal_capture"
        const val RESULT_CHANNEL_ID = "tapcal_results"
        const val NOTIFICATION_ID = 1001
        const val RESULT_NOTIFICATION_ID = 1002
        const val ACTION_CAPTURE = "com.tapcal.ACTION_CAPTURE"
        
        var instance: TapCalNotificationService? = null
            private set
        
        var isRunning = false
            private set
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        isRunning = true
        println("[SnapCal] NotificationService created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        println("[SnapCal] NotificationService onStartCommand: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_CAPTURE -> {
                // User tapped the notification - trigger capture
                triggerCapture()
            }
            else -> {
                // Start foreground with persistent notification
                startForeground(NOTIFICATION_ID, createReadyNotification())
            }
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        super.onDestroy()
        instance = null
        isRunning = false
        println("[SnapCal] NotificationService destroyed")
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java)
            
            // Main capture channel (low priority, persistent)
            val captureChannel = NotificationChannel(
                CHANNEL_ID,
                "SnapCal Capture",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Tap to capture screen for calendar events"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(captureChannel)
            
            // Results channel (default priority, dismissable, with sound)
            val resultsChannel = NotificationChannel(
                RESULT_CHANNEL_ID,
                "SnapCal Results",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Shows results after scanning for events"
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(resultsChannel)
        }
    }
    
    private fun createReadyNotification(): Notification {
        // Intent when notification is tapped
        val captureIntent = Intent(this, TapCalNotificationService::class.java).apply {
            action = ACTION_CAPTURE
        }
        val pendingIntent = PendingIntent.getService(
            this,
            0,
            captureIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SnapCal Ready")
            .setContentText("Tap to snap & find events")
            .setSmallIcon(android.R.drawable.ic_menu_today)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setAutoCancel(false)
            .build()
    }
    
    private fun triggerCapture() {
        println("[SnapCal] Notification tapped - launching capture activity")
        
        // Launch a transparent activity to close the notification shade
        // This is the only reliable way on Android 12+
        val intent = Intent(this, CaptureActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION
        }
        startActivity(intent)
    }
    
    fun updateNotification(title: String, text: String) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_today)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
    
    fun showResultNotification(eventCount: Int) {
        // First, reset the main notification back to "Ready" state
        resetToReady()
        
        // Intent to open the app directly to History tab when result notification is tapped
        val openAppIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("open_tab", "history")
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            1,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val (title, text, icon) = if (eventCount > 0) {
            Triple(
                "$eventCount event${if (eventCount > 1) "s" else ""} found!",
                "Tap to view and add to calendar",
                android.R.drawable.ic_menu_my_calendar
            )
        } else {
            Triple(
                "No events found",
                "Try again with a screen showing event details",
                android.R.drawable.ic_menu_info_details
            )
        }
        
        // Show SEPARATE dismissable notification for results
        val resultNotification = NotificationCompat.Builder(this, RESULT_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(icon)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)  // Dismiss when tapped
            .setContentIntent(pendingIntent)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .build()
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(RESULT_NOTIFICATION_ID, resultNotification)
        
        println("[SnapCal] Result notification shown: $title")
    }
    
    fun resetToReady() {
        val notification = createReadyNotification()
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}

