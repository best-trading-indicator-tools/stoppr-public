package com.stoppr.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.ApplicationInfo
import android.os.Bundle

class MainActivity : FlutterActivity() {
    private val ENVIRONMENT_CHANNEL = "com.stoppr.app/environment"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ENVIRONMENT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTestFlight" -> {
                    // This is for compatibility with iOS code
                    result.success(false)
                }
                "isGooglePlayInternal" -> {
                    // Check if app is running in internal testing track
                    val isDebuggable = 0 != applicationContext.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE
                    val installer = context.packageManager.getInstallerPackageName(context.packageName)
                    val isFromPlayStore = installer != null && installer.contains("com.android.vending")
                    
                    // If from Play Store but debuggable, it's likely in internal testing
                    result.success(isFromPlayStore && isDebuggable)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
} 