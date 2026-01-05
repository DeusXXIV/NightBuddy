package com.nightbuddy.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        val state = loadState(context)
        if (state?.startOnBootReminder == true) {
            showReminder(context)
        }
    }

    private fun loadState(context: Context): StoredState? {
        return try {
            val prefs =
                context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.nightbuddy_app_state", null) ?: return null
            val json = JSONObject(raw)
            StoredState.fromJson(json)
        } catch (_: Exception) {
            null
        }
    }

    private fun showReminder(context: Context) {
        val channelId = "nightbuddy_boot_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "NightBuddy Reminder",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_menu_day)
            .setContentTitle("NightBuddy overlay")
            .setContentText("Tap to re-enable your filter after reboot.")
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        NotificationManagerCompat.from(context).notify(2001, builder.build())
    }

    private data class StoredState(
        val overlayEnabled: Boolean,
        val scheduleMode: String,
        val startOnBootReminder: Boolean,
        val snoozeUntilMillis: Long?,
        val temperature: Double,
        val opacity: Double,
        val brightness: Double,
        val weekdayStart: Int?,
        val weekdayEnd: Int?,
        val weekendStart: Int?,
        val weekendEnd: Int?,
        val weekendDifferent: Boolean,
        val windDownMinutes: Int,
        val fadeOutMinutes: Int,
        val targetPresetId: String?
    ) {
        fun scheduleStart(isWeekend: Boolean): Int? {
            return if (weekendDifferent && isWeekend) weekendStart ?: weekdayStart else weekdayStart
        }

        fun scheduleEnd(isWeekend: Boolean): Int? {
            return if (weekendDifferent && isWeekend) weekendEnd ?: weekdayEnd else weekdayEnd
        }

        companion object {
            fun fromJson(json: JSONObject): StoredState? {
                val overlayEnabled = json.optBoolean("overlayEnabled", false)
                val startOnBootReminder = json.optBoolean("startOnBootReminder", false)
                val snoozeUntil = json.optString("snoozeUntil", null)
                val snoozeMillis = try {
                    if (snoozeUntil.isNullOrEmpty()) null else java.time.Instant.parse(snoozeUntil)
                        .toEpochMilli()
                } catch (_: Exception) {
                    null
                }
                val schedule = json.optJSONObject("schedule") ?: return null
                val scheduleMode = schedule.optString("mode", "off")
                val weekendDifferent = schedule.optBoolean("weekendDifferent", false)
                val windDownMinutes = schedule.optInt("windDownMinutes", 0)
                val fadeOutMinutes = schedule.optInt("fadeOutMinutes", 0)
                val rawTargetPresetId = schedule.optString("targetPresetId", null)
                val targetPresetId =
                    if (rawTargetPresetId.isNullOrEmpty()) null else rawTargetPresetId
                fun decodeTime(key: String): Int? {
                    val obj = schedule.optJSONObject(key) ?: return null
                    val hour = obj.optInt("hour", -1)
                    val minute = obj.optInt("minute", -1)
                    return if (hour in 0..23 && minute in 0..59) hour * 60 + minute else null
                }
                val weekdayStart = decodeTime("startTime")
                val weekdayEnd = decodeTime("endTime")
                val weekendStart = decodeTime("weekendStartTime")
                val weekendEnd = decodeTime("weekendEndTime")

                val presets = json.optJSONArray("presets") ?: JSONArray()
                val activeId = json.optString("activePresetId", "")
                val preset = findPreset(presets, targetPresetId ?: activeId)

                return StoredState(
                    overlayEnabled = overlayEnabled,
                    scheduleMode = scheduleMode,
                    startOnBootReminder = startOnBootReminder,
                    snoozeUntilMillis = snoozeMillis,
                    temperature = preset?.optDouble("temperature", 50.0) ?: 50.0,
                    opacity = preset?.optDouble("opacity", 50.0) ?: 50.0,
                    brightness = preset?.optDouble("brightness", 100.0) ?: 100.0,
                    weekdayStart = weekdayStart,
                    weekdayEnd = weekdayEnd,
                    weekendStart = weekendStart,
                    weekendEnd = weekendEnd,
                    weekendDifferent = weekendDifferent,
                    windDownMinutes = windDownMinutes,
                    fadeOutMinutes = fadeOutMinutes,
                    targetPresetId = targetPresetId
                )
            }

            private fun findPreset(array: JSONArray, activeId: String): JSONObject? {
                var fallback: JSONObject? = null
                for (i in 0 until array.length()) {
                    val obj = array.optJSONObject(i) ?: continue
                    if (fallback == null) fallback = obj
                    if (obj.optString("id") == activeId) return obj
                }
                return fallback
            }
        }
    }

    private data class FilterPayload(
        val temperature: Double,
        val opacity: Double,
        val brightness: Double
    )

}
