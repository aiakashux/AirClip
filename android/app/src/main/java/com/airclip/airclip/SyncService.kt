package com.airclip.airclip

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

private const val TAG             = "SyncService"
private const val CHANNEL_ID      = "airclip_sync"
private const val NOTIFICATION_ID = 1

/**
 * Foreground service that keeps LAN sync running while the app is in the background.
 *
 * Starts [SyncEngine.connect] on start and [SyncEngine.disconnect] on destroy.
 * The foreground notification tells the OS not to kill this process.
 */
class SyncService : Service() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        Log.d(TAG, "SyncService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        Prefs.init(applicationContext)
        if (!SyncRuntimePolicy.shouldRunLanService(AirClipIdentity.isPaired, Prefs.syncMode)) {
            SyncEngine.disconnect()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf(startId)
            Log.d(TAG, "SyncService start rejected — unpaired or paused")
            return START_NOT_STICKY
        }

        SyncEngine.connect()
        Log.d(TAG, "SyncService started — LAN sync active")
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        SyncEngine.disconnect()
        Log.d(TAG, "SyncService destroyed")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "AirClip Sync",
                NotificationManager.IMPORTANCE_LOW
            ).apply { description = "LAN clipboard sync is active" }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification() = NotificationCompat.Builder(this, CHANNEL_ID)
        .setContentTitle("AirClip is syncing")
        .setContentText("Clipboard sync is active on your local network")
        .setSmallIcon(android.R.drawable.ic_menu_share)
        .setOngoing(true)
        .setContentIntent(
            PendingIntent.getActivity(
                this, 0,
                Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE
            )
        )
        .build()

    companion object {
        fun start(context: Context) {
            Prefs.init(context.applicationContext)
            if (!SyncRuntimePolicy.shouldRunLanService(AirClipIdentity.isPaired, Prefs.syncMode)) {
                stop(context)
                return
            }
            val intent = Intent(context, SyncService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, SyncService::class.java))
        }
    }
}
