package com.bthere.provider

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
}
