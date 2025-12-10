// Summary: Wire Meta (Facebook) SDK delegate methods for AEM by forwarding
// app lifecycle, URL, and universal link events to FBSDK's ApplicationDelegate.
// Keeps existing custom stoppr:// handling intact.
import Flutter
import UIKit
import FBSDKCoreKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize Meta (Facebook) SDK for AEM/deeplink handling
    ApplicationDelegate.shared.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let environmentChannel = FlutterMethodChannel(name: "com.stoppr.app/environment", binaryMessenger: controller.binaryMessenger)
    
    environmentChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "isTestFlight" {
        #if DEBUG
          result(false)
        #else
          let receiptURL = Bundle.main.appStoreReceiptURL
          let isTestFlight = receiptURL?.path.contains("sandboxReceipt") ?? false
          result(isTestFlight)
        #endif
      } else if call.method == "getAppVersion" {
        if let infoDict = Bundle.main.infoDictionary,
           let version = infoDict["CFBundleShortVersionString"] as? String,
           let build = infoDict["CFBundleVersion"] as? String {
             result(["version": version, "build": build])
        } else {
            result(FlutterError(code: "UNAVAILABLE", message: "Version info unavailable", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    // Handle custom scheme deep links from iOS widgets before Flutter starts
    if url.scheme?.lowercased() == "stoppr" {
      // Prefer host; fallback to trimmed path component to be robust across URL formats
      var target = url.host?.lowercased() ?? ""
      if target.isEmpty {
        let trimmedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        if !trimmedPath.isEmpty { target = trimmedPath }
      }
      if target == "home" || target == "panic" || target == "meditation" || target == "pledge" {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "pending_home_navigation")
        defaults.set(target, forKey: "pending_widget_deeplink")
        // Force keeping the welcome video; Flutter will route correctly after
        defaults.set(true, forKey: "force_keep_welcome_video")
        defaults.synchronize()
        return true
      }
    }
    // Forward to Meta SDK for AEM/deeplinks
    if ApplicationDelegate.shared.application(app, open: url, options: options) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  // Support Universal Links for Meta AEM on iOS 13+
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if ApplicationDelegate.shared.application(
      application,
      continue: userActivity
    ) {
      return true
    }
    return super.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )
  }
}