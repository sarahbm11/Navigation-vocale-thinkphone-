package ca.thinkphone.navigation_vocale

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

class BackgroundSpeechService : Service() {

    companion object {
        private const val CHANNEL_ID = "nav_vocale_foreground"
        private const val CHANNEL_NAME = "Navigation Vocale"
        private const val NOTIFICATION_ID = 5210
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        try {
            // Sur Android 10+ on déclare explicitement le type "microphone".
            // ServiceCompat gère les différences d'API. Si la permission
            // FOREGROUND_SERVICE_MICROPHONE manque, on tombe en mode dégradé
            // (notification simple) plutôt que de faire planter l'app.
            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            } else {
                0
            }
            ServiceCompat.startForeground(this, NOTIFICATION_ID, buildNotification(), type)
        } catch (e: Exception) {
            Log.e("NavVocale", "startForeground (micro) a échoué : ${e.message}")
            try {
                ServiceCompat.startForeground(this, NOTIFICATION_ID, buildNotification(), 0)
            } catch (e2: Exception) {
                Log.e("NavVocale", "startForeground (fallback) a échoué : ${e2.message}")
                stopSelf()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Navigation Vocale")
            .setContentText("Écoute vocale en arrière-plan")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Service de navigation vocale en écoute continue"
            }
            manager.createNotificationChannel(channel)
        }
    }
}
