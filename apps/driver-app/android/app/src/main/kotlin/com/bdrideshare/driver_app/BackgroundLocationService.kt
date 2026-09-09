package com.bdrideshare.driver_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import io.flutter.plugin.common.EventChannel

/**
 * Native driver GPS. Flutter plugins are OS-killed in the background.
 * Pings only when displacement >= 10m (PRD PL-06).
 */
class BackgroundLocationService : Service(), LocationListener {
    private var last: Location? = null
    private var minDisplacement = 10f

    override fun onCreate() {
        super.onCreate()
        val channelId = "gps"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(
                NotificationChannel(channelId, "BD Ride Share GPS", NotificationManager.IMPORTANCE_LOW)
            )
            val notification: Notification = Notification.Builder(this, channelId)
                .setContentTitle("BD Ride Share")
                .setContentText("Sharing location while online")
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .build()
            startForeground(1, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val interval = intent?.getIntExtra("intervalMs", 3000)?.toLong() ?: 3000L
        minDisplacement = (intent?.getIntExtra("displacementM", 10) ?: 10).toFloat()
        val lm = getSystemService(LOCATION_SERVICE) as LocationManager
        try {
            lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, interval, minDisplacement, this)
        } catch (_: SecurityException) {
        }
        return START_STICKY
    }

    override fun onLocationChanged(location: Location) {
        val prev = last
        if (prev != null && location.distanceTo(prev) < minDisplacement) return
        last = location
        sink?.success(
            mapOf(
                "lat" to location.latitude,
                "lng" to location.longitude,
                "accuracy" to location.accuracy,
                "speed" to location.speed,
            )
        )
    }

    @Deprecated("Deprecated in Java")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        val lm = getSystemService(LOCATION_SERVICE) as LocationManager
        lm.removeUpdates(this)
        super.onDestroy()
    }

    companion object {
        var sink: EventChannel.EventSink? = null
        val streamHandler = object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
            }
            override fun onCancel(arguments: Any?) {
                sink = null
            }
        }
    }
}
