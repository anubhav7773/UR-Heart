package com.urheart.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "flutter_windowmanager"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return

            val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_COMMUNICATION_INSTANT)
                .build()

            // 1. Dialogue Channel (Heads-Up, Vibration, LED Lights, Max Importance)
            val dialogueChannelId = "ur_heart_sacred_dialogue"
            val dialogueChannelName = "UR-Heart Sacred Dialogues"
            val dialogueChannelDesc = "Real-time alerts for mindful messages, mutual sparks, direct letters, and streaks."
            val dialogueImportance = NotificationManager.IMPORTANCE_HIGH
            val dialogueChannel = NotificationChannel(dialogueChannelId, dialogueChannelName, dialogueImportance).apply {
                description = dialogueChannelDesc
                enableLights(true)
                lightColor = Color.parseColor("#D4AF37") // Sacred Gold
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 200, 250)
                setSound(defaultSoundUri, audioAttributes)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(dialogueChannel)

            // 2. Presence & Streaks Channel
            val presenceChannelId = "ur_heart_presence_channel"
            val presenceChannelName = "Sanctuary Presence & Streaks"
            val presenceChannelDesc = "Mindful reminders for daily reflections, streaks, and sovereign sanctuary milestones."
            val presenceImportance = NotificationManager.IMPORTANCE_HIGH
            val presenceChannel = NotificationChannel(presenceChannelId, presenceChannelName, presenceImportance).apply {
                description = presenceChannelDesc
                enableLights(true)
                lightColor = Color.parseColor("#1B4332") // Sacred Pine
                enableVibration(true)
                setSound(defaultSoundUri, audioAttributes)
                setShowBadge(true)
            }
            notificationManager.createNotificationChannel(presenceChannel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "addFlags" -> {
                    val flags = call.argument<Int>("flags") ?: WindowManager.LayoutParams.FLAG_SECURE
                    window.addFlags(flags)
                    result.success(true)
                }
                "clearFlags" -> {
                    val flags = call.argument<Int>("flags") ?: WindowManager.LayoutParams.FLAG_SECURE
                    window.clearFlags(flags)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
