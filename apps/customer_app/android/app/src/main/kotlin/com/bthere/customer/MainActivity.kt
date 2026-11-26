package com.bthere.customer

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var activeChannel: MethodChannel? = null
    private var pendingNotification: Map<String, Any?>? = null
    private var pendingOpen: Map<String, Any?>? = null
    private val notificationId = 31001
    private val permissionRequest = 7401
    private val channelId = "booking_request_status"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        captureOpen(intent)
        activeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.bthere.customer/active-request")
        activeChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialOpen" -> { result.success(pendingOpen); pendingOpen = null }
                "show" -> {
                    @Suppress("UNCHECKED_CAST")
                    val data = call.arguments as? Map<String, Any?>
                    if (data == null || (data["requestId"] as? Number)?.toInt()?.let { it > 0 } != true) {
                        result.error("INVALID_REQUEST", "Request reference required", null)
                    } else {
                        pendingNotification = data
                        showStatus(data)
                        result.success(null)
                    }
                }
                "clear" -> {
                    pendingNotification = null
                    getSystemService(NotificationManager::class.java).cancel(notificationId)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun captureOpen(source: Intent?) {
        if (source?.action != "com.bthere.customer.OPEN_ACTIVE_REQUEST") return
        val requestId = source.getIntExtra("requestId", 0)
        val owner = source.getIntExtra("owner", 0)
        val scope = source.getStringExtra("scope")
        if (requestId > 0 && owner > 0 && scope != null) {
            pendingOpen = mapOf("requestId" to requestId, "owner" to owner, "scope" to scope)
        }
        source.action = Intent.ACTION_MAIN
        source.removeExtra("requestId"); source.removeExtra("owner"); source.removeExtra("scope")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureOpen(intent)
        pendingOpen?.let { data ->
            if (activeChannel != null) {
                pendingOpen = null
                activeChannel!!.invokeMethod("open", data)
            }
        }
    }

    private fun showStatus(data: Map<String, Any?>) {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            val preferences = getSharedPreferences("booking_notification_preferences", MODE_PRIVATE)
            if (!preferences.getBoolean("asked", false) && !isFinishing) {
                preferences.edit().putBoolean("asked", true).apply()
                requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), permissionRequest)
            }
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(channelId, "Active booking requests", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Return to a provider search or confirm payment for an accepted request"
            })
        }
        val requestId = (data["requestId"] as Number).toInt()
        val open = Intent(this, MainActivity::class.java).apply {
            action = "com.bthere.customer.OPEN_ACTIVE_REQUEST"
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("requestId", requestId)
            putExtra("owner", (data["owner"] as? Number)?.toInt() ?: 0)
            putExtra("scope", data["scope"] as? String)
        }
        val content = PendingIntent.getActivity(this, notificationId, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channelId) else Notification.Builder(this)
        builder.setSmallIcon(R.drawable.ic_booking_status)
            .setContentTitle(data["title"] as? String ?: "Your booking request")
            .setContentText(data["body"] as? String ?: "Tap to check the latest status")
            .setContentIntent(content).setOngoing(true).setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setCategory(Notification.CATEGORY_STATUS)
            .setShowWhen(false)
        val remaining = (data["remainingMs"] as? Number)?.toLong()
        if (Build.VERSION.SDK_INT >= 26 && remaining != null && remaining > 0) builder.setTimeoutAfter(remaining)
        manager.notify(notificationId, builder.build())
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequest && grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            pendingNotification?.let { showStatus(it) }
        }
    }
}
