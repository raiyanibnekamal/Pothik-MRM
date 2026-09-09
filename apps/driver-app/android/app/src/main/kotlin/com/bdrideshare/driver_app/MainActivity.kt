package com.bdrideshare.driver_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methods = "com.bdrideshare/gps"
    private val events = "com.bdrideshare/gps_events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methods)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "warmUp" -> result.success(null)
                    "start" -> {
                        val interval = call.argument<Int>("intervalMs") ?: 3000
                        val displacement = call.argument<Int>("displacementM") ?: 10
                        val intent = Intent(this, BackgroundLocationService::class.java).apply {
                            putExtra("intervalMs", interval)
                            putExtra("displacementM", displacement)
                        }
                        startForegroundService(intent)
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, BackgroundLocationService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, events)
            .setStreamHandler(BackgroundLocationService.streamHandler)
    }
}
