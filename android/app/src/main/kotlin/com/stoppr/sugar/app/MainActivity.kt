package com.stoppr.sugar.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import android.graphics.Color

class MainActivity : FlutterActivity() {
    private val ENVIRONMENT_CHANNEL = "com.stoppr.sugar.app/environment"
    private val DEEP_LINK_CHANNEL = "com.stoppr.sugar.app/deep_link"
    private var deepLinkMethodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enable edge-to-edge display using WindowCompat
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // Make status bar transparent and set light content (white icons/text)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        
        val insetsController = WindowCompat.getInsetsController(window, window.decorView)
        insetsController?.isAppearanceLightStatusBars = false // false = light content (white icons/text)
        insetsController?.isAppearanceLightNavigationBars = false // false = light content
        
        // Handle deep link if coming from widget tap
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent) {
        // Check if launched from widget with stoppr://home URI
        if (Intent.ACTION_VIEW == intent.action) {
            val uri = intent.data
            if (uri != null && uri.toString().startsWith("stoppr://home")) {
                // Cache the URI until Flutter is ready to receive it
                deepLinkPendingUri = uri
                // If method channel is already set up, send right away
                deepLinkMethodChannel?.let { channel ->
                    sendUriToFlutter(channel, uri)
                    deepLinkPendingUri = null
                }
            }
        }
    }
    
    // Cache URI if Flutter isn't ready yet
    private var deepLinkPendingUri: Uri? = null
    
    private fun sendUriToFlutter(channel: MethodChannel, uri: Uri) {
        channel.invokeMethod("deepLink", uri.toString())
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up environment channel
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
        
        // Set up deep link channel
        deepLinkMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEEP_LINK_CHANNEL).apply {
            // Send any pending URI now that Flutter is ready
            deepLinkPendingUri?.let { uri ->
                sendUriToFlutter(this, uri)
                deepLinkPendingUri = null
            }
        }
    }
} 