package com.example.nightbuddy

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "nightbuddy/overlay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
                when (call.method) {
                    "startOverlay" -> {
                        OverlayServiceStarter.start(
                            this,
                            args = call.arguments as? Map<*, *>,
                            enable = true
                        )
                        result.success(null)
                    }
                    "updateOverlay" -> {
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
                    else -> result.notImplemented()
                }
            }
    }
}
