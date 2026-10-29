package com.bthere.provider

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build

class MainActivity : FlutterActivity() {
    private var bookingRingtone: Ringtone? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notifications = getSystemService(NotificationManager::class.java)
            notifications.createNotificationChannel(NotificationChannel(
                "booking_calls", "Incoming booking requests", NotificationManager.IMPORTANCE_HIGH))
            notifications.createNotificationChannel(NotificationChannel(
                "booking_updates", "Booking updates", NotificationManager.IMPORTANCE_DEFAULT))
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.bthere.provider/booking-alert").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    bookingRingtone?.stop()
                    bookingRingtone = RingtoneManager.getRingtone(this,
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE))
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        bookingRingtone?.isLooping = true
                    }
                    bookingRingtone?.play()
                    result.success(null)
                }
                "stop" -> { bookingRingtone?.stop(); result.success(null) }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.bthere.provider/maps-configuration").setMethodCallHandler { call, result ->
            if (call.method != "isConfigured") {
                result.notImplemented()
            } else {
                val key = packageManager.getApplicationInfo(packageName,
                    PackageManager.GET_META_DATA).metaData
                    ?.getString("com.google.android.geo.API_KEY").orEmpty().trim()
                // Only availability crosses the channel, never the key itself.
                result.success(Regex("^AIza[A-Za-z0-9_-]{35}$").matches(key))
            }
        }
    }
    override fun onStop() {
        bookingRingtone?.stop()
        super.onStop()
    }
    override fun onDestroy() {
        bookingRingtone?.stop()
        bookingRingtone = null
        super.onDestroy()
    }
}
