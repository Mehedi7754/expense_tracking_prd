package com.gw.project

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val channels = listOf(
                NotificationChannel("chat_messages_channel", "Chat Messages", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Direct and project team chat messages with preview"
                    enableVibration(true)
                },
                NotificationChannel("expenses_channel", "Expense Notifications", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Alerts for expense submissions, approvals, and rejections"
                    enableVibration(true)
                },
                NotificationChannel("attendance_channel", "Attendance Reminders", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Daily attendance check-in reminders and late alerts"
                    enableVibration(true)
                },
                NotificationChannel("general_channel", "General Notifications", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Budget warnings, salary, payroll, and other alerts"
                    enableVibration(true)
                },
                NotificationChannel("high_importance_channel", "High Importance Notifications", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "High priority alerts and push notifications"
                    enableVibration(true)
                }
            )

            channels.forEach { notificationManager.createNotificationChannel(it) }
        }
    }
}
