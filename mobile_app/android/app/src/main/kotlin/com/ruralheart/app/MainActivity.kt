package com.ruralheart.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "flutter_windowmanager"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "addFlags" -> {
                    val flags = call.argument<Int>("flags") ?: WindowManager.LayoutParams.FLAG_SECURE
                    activity.window?.addFlags(flags)
                    result.success(true)
                }
                "clearFlags" -> {
                    val flags = call.argument<Int>("flags") ?: WindowManager.LayoutParams.FLAG_SECURE
                    activity.window?.clearFlags(flags)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
