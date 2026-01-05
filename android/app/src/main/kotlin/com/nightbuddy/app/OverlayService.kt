package com.nightbuddy.app

import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.net.Uri
import android.view.Gravity
import android.view.OrientationEventListener
import android.view.View
import android.view.WindowManager
import android.os.Process
import android.hardware.display.DisplayManager
import android.util.DisplayMetrics
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.graphics.ColorUtils
import com.nightbuddy.app.BuildConfig

class OverlayService : Service() {
    companion object {
        const val CHANNEL_ID = "nightbuddy_overlay_channel"
        const val NOTIF_ID = 1001
        @Volatile
        var lastKnownEnabled: Boolean? = null

        private val actionPrefix: String
            get() = "${BuildConfig.APPLICATION_ID}."
        val ACTION_START: String
            get() = "${actionPrefix}ACTION_START"
        val ACTION_TOGGLE_FLASHLIGHT: String
            get() = "${actionPrefix}ACTION_TOGGLE_FLASHLIGHT"
        val ACTION_TOGGLE_FILTER: String
            get() = "${actionPrefix}ACTION_TOGGLE_FILTER"
        val ACTION_OVERLAY_STATUS: String
            get() = "${actionPrefix}ACTION_OVERLAY_STATUS"

        const val EXTRA_TEMPERATURE = "temperature"
        const val EXTRA_OPACITY = "opacity"
        const val EXTRA_BRIGHTNESS = "brightness"
        const val EXTRA_ENABLE = "enable"
        const val EXTRA_OVERLAY_ENABLED = "overlayEnabled"
    }

    private var isFilterEnabled = false
    private var payload: Map<String, Double> = emptyMap()
    private lateinit var overlayController: OverlayController

    override fun onCreate() {
        super.onCreate()
        overlayController = OverlayController(applicationContext)
        ensureChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                payload = parsePayload(intent)
                val enable = intent.getBooleanExtra(EXTRA_ENABLE, true)
                if (enable) enableOverlay() else disableOverlay()
            }
            ACTION_TOGGLE_FLASHLIGHT -> {
                toggleFlashlight()
            }
        }
        startForegroundWithType()
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        overlayController.hide()
        lastKnownEnabled = false
        NotificationManagerCompat.from(this).cancel(NOTIF_ID)
        FlashlightController.setTorch(this, false)
        broadcastOverlayStatus(false)
    }

    private fun parsePayload(
        intent: Intent?,
        fallback: Map<String, Double> = emptyMap()
    ): Map<String, Double> {
        val temperature = intent?.getDoubleExtra(EXTRA_TEMPERATURE, fallback[EXTRA_TEMPERATURE] ?: 50.0)
        val opacity = intent?.getDoubleExtra(EXTRA_OPACITY, fallback[EXTRA_OPACITY] ?: 50.0)
        val brightness = intent?.getDoubleExtra(EXTRA_BRIGHTNESS, fallback[EXTRA_BRIGHTNESS] ?: 100.0)
        return mapOf(
            EXTRA_TEMPERATURE to (temperature ?: 50.0),
            EXTRA_OPACITY to (opacity ?: 50.0),
            EXTRA_BRIGHTNESS to (brightness ?: 100.0)
        )
    }

    private fun enableOverlay() {
        if (isFilterEnabled) {
            overlayController.update(payload)
            updateNotification()
            broadcastOverlayStatus(true)
            return
        }
        if (!overlayController.show(payload)) {
            disableOverlay()
            return
        }
        isFilterEnabled = true
        lastKnownEnabled = true
        updateNotification()
        broadcastOverlayStatus(true)
    }

    private fun disableOverlay() {
        if (!isFilterEnabled) {
            lastKnownEnabled = false
            updateNotification()
            broadcastOverlayStatus(false)
            return
        }
        isFilterEnabled = false
        lastKnownEnabled = false
        overlayController.hide()
        updateNotification()
        broadcastOverlayStatus(false)
    }

    private fun buildNotification(): Notification {
        val toggleIntent = Intent(ACTION_TOGGLE_FILTER).apply {
            setPackage(packageName)
        }
        val pendingToggle = PendingIntent.getBroadcast(
            this,
            0,
            toggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val actionText = if (isFilterEnabled) "Turn Off" else "Turn On"
        val contentIntent = PendingIntent.getActivity(
            this,
            1,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val showFlashAction = FlashlightController.hasFlash(this)
        val flashActionIntent = PendingIntent.getService(
            this,
            2,
            Intent(this, OverlayService::class.java).apply { action = ACTION_TOGGLE_FLASHLIGHT },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_day)
            .setContentTitle("NightBuddy")
            .setContentText(
                if (isFilterEnabled) "Blue light filter is ON"
                else "Blue light filter is OFF"
            )
            .setOnlyAlertOnce(true)
            .setSound(null)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(contentIntent)
            .addAction(android.R.drawable.ic_media_pause, actionText, pendingToggle)
        if (showFlashAction) {
            val flashText =
                if (FlashlightController.isOn()) "Flash Off" else "Flash On"
            builder.addAction(android.R.drawable.ic_menu_camera, flashText, flashActionIntent)
        }
        return builder.build()
    }

    private fun updateNotification() {
        NotificationManagerCompat.from(this).notify(NOTIF_ID, buildNotification())
    }

    private fun broadcastOverlayStatus(enabled: Boolean) {
        val intent = Intent(ACTION_OVERLAY_STATUS).apply {
            setPackage(packageName)
            putExtra(EXTRA_OVERLAY_ENABLED, enabled)
        }
        sendBroadcast(intent)
    }

    private fun startForegroundWithType() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIF_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIF_ID, notification)
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "NightBuddy Overlay",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
                setShowBadge(false)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun toggleFlashlight() {
        if (!FlashlightController.hasFlash(this)) return
        if (!FlashlightController.hasPermission(this)) {
            FlashlightController.setTorch(this, false)
            updateNotification()
            return
        }
        val next = !FlashlightController.isOn()
        FlashlightController.setTorch(this, next)
        updateNotification()
    }

    private class OverlayController(private val appContext: Context) {
        private companion object {
            var sharedView: View? = null
        }

        private val displayManager: DisplayManager? =
            appContext.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager
        private val orientationListener: OrientationEventListener =
            object : OrientationEventListener(appContext) {
                override fun onOrientationChanged(orientation: Int) {
                    if (orientation == ORIENTATION_UNKNOWN) return
                    refreshLayout()
                }
            }

        private val windowManager: WindowManager
            get() = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        init {
            displayManager?.registerDisplayListener(object : DisplayManager.DisplayListener {
                override fun onDisplayAdded(displayId: Int) {}
                override fun onDisplayRemoved(displayId: Int) {}
                override fun onDisplayChanged(displayId: Int) {
                    refreshLayout()
                }
            }, null)
            if (orientationListener.canDetectOrientation()) {
                orientationListener.enable()
            }
        }

        fun show(args: Map<String, Double>): Boolean {
            val view = sharedView ?: View(appContext).apply {
                systemUiVisibility =
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                        View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                        View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                        View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            }.also { created ->
                try {
                    created.setBackgroundColor(computeColor(args))
                    windowManager.addView(created, overlayLayoutParams())
                    sharedView = created
                } catch (_: Exception) {
                    return false
                }
            }
            view?.setBackgroundColor(computeColor(args))
            refreshLayout()
            return view != null
        }

        fun update(args: Map<String, Double>) {
            val view = sharedView ?: run {
                show(args)
                return
            }
            view.setBackgroundColor(computeColor(args))
            refreshLayout()
        }

        fun hide() {
            val view = sharedView ?: return
            try {
                windowManager.removeView(view)
            } catch (_: Exception) {
            }
            sharedView = null
        }

        private fun overlayType(): Int {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
        }

        private fun overlayLayoutParams(): WindowManager.LayoutParams {
            val (width, height) = screenSize()
            return WindowManager.LayoutParams(
                width,
                height,
                overlayType(),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_OVERSCAN or
                    WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_TRANSLUCENT_STATUS or
                    WindowManager.LayoutParams.FLAG_TRANSLUCENT_NAVIGATION,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    layoutInDisplayCutoutMode =
                        WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
                }
            }
        }

        private fun refreshLayout() {
            val view = sharedView ?: return
            try {
                windowManager.updateViewLayout(view, overlayLayoutParams())
            } catch (_: Exception) {
            }
        }

        private fun screenSize(): Pair<Int, Int> {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val bounds = windowManager.currentWindowMetrics.bounds
                bounds.width() to bounds.height()
            } else {
                val metrics = DisplayMetrics()
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay.getRealMetrics(metrics)
                metrics.widthPixels to metrics.heightPixels
            }
        }

        private fun computeColor(payload: Map<String, Double>): Int {
            val temperature = payload[EXTRA_TEMPERATURE] ?: 50.0
            val opacity = (payload[EXTRA_OPACITY] ?: 50.0).coerceIn(0.0, 100.0) / 100.0
            val brightness = (payload[EXTRA_BRIGHTNESS] ?: 100.0).coerceIn(0.0, 100.0) / 100.0

            val baseWarm = ColorUtils.blendARGB(
                Color.WHITE,
                Color.parseColor("#FFB347"),
                (temperature / 100.0).toFloat()
            )
            val withOpacity = ColorUtils.setAlphaComponent(baseWarm, (opacity * 255).toInt())
            val dimAlpha = ((1 - brightness) * 180).toInt().coerceAtMost(200)
            val dimLayer = ColorUtils.setAlphaComponent(Color.BLACK, dimAlpha)
            return ColorUtils.compositeColors(dimLayer, withOpacity)
        }
    }
}

object OverlayServiceStarter {
    fun start(context: Context, args: Map<*, *>?, enable: Boolean) {
        val appContext = context.applicationContext
        val intent = Intent(appContext, OverlayService::class.java).apply {
            action = OverlayService.ACTION_START
            putExtra(OverlayService.EXTRA_ENABLE, enable)
            putExtrasFromArgs(args)
        }
        start(appContext, intent)
    }

    fun canDrawOverlays(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        if (Settings.canDrawOverlays(context)) return true
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
            ?: return false
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_SYSTEM_ALERT_WINDOW,
                Process.myUid(),
                context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_SYSTEM_ALERT_WINDOW,
                Process.myUid(),
                context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun requestPermission(activity: MainActivity): Boolean {
        if (canDrawOverlays(activity)) return true
        return try {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${activity.packageName}")
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun start(appContext: Context, intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            appContext.startForegroundService(intent)
        } else {
            appContext.startService(intent)
        }
    }

    private fun Intent.putExtrasFromArgs(args: Map<*, *>?) {
        val temperature = (args?.get("temperature") as? Number)?.toDouble()
        val opacity = (args?.get("opacity") as? Number)?.toDouble()
        val brightness = (args?.get("brightness") as? Number)?.toDouble()
        if (temperature != null) putExtra(OverlayService.EXTRA_TEMPERATURE, temperature)
        if (opacity != null) putExtra(OverlayService.EXTRA_OPACITY, opacity)
        if (brightness != null) putExtra(OverlayService.EXTRA_BRIGHTNESS, brightness)
    }
}
