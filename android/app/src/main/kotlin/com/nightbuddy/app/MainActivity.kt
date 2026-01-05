package com.nightbuddy.app

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val channelName = "nightbuddy/overlay"
    private val eventChannelName = "nightbuddy/overlay_events"
    private val flashPermissionRequest = 9001
    private var pendingFlashPermissionResult: MethodChannel.Result? = null
    private var overlayStatusSink: EventChannel.EventSink? = null
    private var overlayReceiverRegistered = false
    private var toggleReceiverRegistered = false
    private var overlayChannel: MethodChannel? = null
    private val overlayStatusReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != OverlayService.ACTION_OVERLAY_STATUS) return
            val enabled = intent.getBooleanExtra(
                OverlayService.EXTRA_OVERLAY_ENABLED,
                false
            )
            overlayStatusSink?.success(enabled)
        }
    }
    private val toggleFilterReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != OverlayService.ACTION_TOGGLE_FILTER) return
            overlayChannel?.invokeMethod("toggleFilter", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        overlayChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        overlayChannel?.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "startOverlay" -> {
                        OverlayServiceStarter.start(
                            this,
                            args = call.arguments as? Map<*, *>,
                            enable = true
                        )
                        result.success(null)
                    }
                    "stopOverlay" -> {
                        OverlayServiceStarter.start(
                            this,
                            args = call.arguments as? Map<*, *>,
                            enable = false
                        )
                        result.success(null)
                    }
                    "hasPermission" -> {
                        result.success(OverlayServiceStarter.canDrawOverlays(this))
                    }
                    "requestPermission" -> {
                        val ok = OverlayServiceStarter.requestPermission(this)
                        result.success(ok)
                    }
                    "getOverlayStatus" -> {
                        result.success(OverlayService.lastKnownEnabled)
                    }
                    "hasFlashlight" -> {
                        result.success(FlashlightController.hasFlash(this))
                    }
                    "getFlashlightStatus" -> {
                        result.success(FlashlightController.isOn())
                    }
                    "hasFlashlightPermission" -> {
                        result.success(hasFlashlightPermission())
                    }
                    "requestFlashlightPermission" -> {
                        if (hasFlashlightPermission()) {
                            result.success(true)
                        } else {
                            pendingFlashPermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.CAMERA),
                                flashPermissionRequest
                            )
                        }
                    }
                    "setFlashlight" -> {
                        val enabled =
                            (call.argument<Boolean>("enabled") as Boolean?) ?: false
                        if (!FlashlightController.hasFlash(this) || !hasFlashlightPermission()) {
                            result.success(false)
                        } else {
                            val ok = FlashlightController.setTorch(this, enabled)
                            result.success(ok)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    overlayStatusSink = events
                    OverlayService.lastKnownEnabled?.let { enabled ->
                        events?.success(enabled)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    overlayStatusSink = null
                }
            })
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        registerOverlayReceiver()
        registerToggleReceiver()
    }

    override fun onDestroy() {
        if (overlayReceiverRegistered) {
            unregisterReceiver(overlayStatusReceiver)
            overlayReceiverRegistered = false
        }
        if (toggleReceiverRegistered) {
            unregisterReceiver(toggleFilterReceiver)
            toggleReceiverRegistered = false
        }
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == flashPermissionRequest) {
            val granted =
                grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingFlashPermissionResult?.success(granted)
            pendingFlashPermissionResult = null
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    private fun hasFlashlightPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun registerOverlayReceiver() {
        if (overlayReceiverRegistered) return
        val filter = IntentFilter(OverlayService.ACTION_OVERLAY_STATUS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(overlayStatusReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(overlayStatusReceiver, filter)
        }
        overlayReceiverRegistered = true
    }

    private fun registerToggleReceiver() {
        if (toggleReceiverRegistered) return
        val filter = IntentFilter(OverlayService.ACTION_TOGGLE_FILTER)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(toggleFilterReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(toggleFilterReceiver, filter)
        }
        toggleReceiverRegistered = true
    }
}
