import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import 'dart:io';
import 'package:stoppr/features/app/presentation/screens/home_screen.dart';
import 'package:stoppr/core/notifications/notification_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart';

class CongratulationsPaymentScreen extends StatefulWidget {
  const CongratulationsPaymentScreen({super.key});

  @override
  State<CongratulationsPaymentScreen> createState() => _CongratulationsPaymentScreenState();
}

class _CongratulationsPaymentScreenState extends State<CongratulationsPaymentScreen> with WidgetsBindingObserver {
  late Timer _redirectTimer;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Apply system UI settings immediately
    _setSystemUIOverlayStyle();
    
    // Use post-frame callback to ensure UI settings are applied after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setSystemUIOverlayStyle();
    });
    
    // Hide the bottom system navigation bar completely on Android
    if (Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: [SystemUiOverlay.top],
      );
    }
    
    // Update notifications for subscribers
    _updateNotifications();
    
    // Set up timer to redirect to home screen after 4 seconds
    _redirectTimer = Timer(const Duration(seconds: 4), () {
      _navigateToHomeScreen();
    });
  }
  
  void _setSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // For Android (white icons)
      statusBarBrightness: Brightness.dark, // For iOS (white icons)
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Reapply UI settings when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _setSystemUIOverlayStyle();
    }
  }
  
  // Update notifications for newly subscribed users
  Future<void> _updateNotifications() async {
    try {
      await _notificationService.updateNotificationsBasedOnSubscription(
        isSubscribed: true,
        hour: 9,
        minute: 0,
      );
      debugPrint('🔔 Updated notifications for newly subscribed user');
    } catch (e) {
      debugPrint('🔔 Error updating notifications: $e');
    }
  }
  
  void _navigateToHomeScreen() {
    if (mounted) {
      // Replace the entire navigation stack with MainScaffold
      // This ensures no previous screens remain in the stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const MainScaffold(initialIndex: 0),
          settings: const RouteSettings(name: '/home'),
          fullscreenDialog: true, // Use fullscreen dialog for cleaner transition
        ),
        (route) => false, // Remove ALL previous routes
      );
    }
  }

  @override
  void dispose() {
    _redirectTimer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    // Force apply system UI settings on every build
    _setSystemUIOverlayStyle();
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // For Android (white icons)
        statusBarBrightness: Brightness.dark, // For iOS (white icons)
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: WillPopScope(
        // Prevent back button from working
        onWillPop: () async => false,
        child: Scaffold(
          backgroundColor: const Color(0xFFFF7A8A), // Salmon/pink fallback color
          extendBody: true,
          extendBodyBehindAppBar: true,
          // Set AppBar with transparent background to force status bar styling
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(0), // Zero height app bar
            child: AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light, // White icons for Android
                statusBarBrightness: Brightness.dark, // White icons for iOS
              ),
            ),
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Static background image instead of video
              Image.asset(
                'assets/images/onboarding/sun-image-background.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                alignment: const Alignment(0.0, 0.5), // More extreme value to move the sun up
              ),
              
              // Optional gradient overlay to ensure text visibility
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.2),
                    ],
                    stops: const [0.7, 1.0],
                  ),
                ),
              ),
              
              // Stars overlay with opacity
              Positioned.fill(
                child: Opacity(
                  opacity: 0.7,
                  child: Lottie.asset(
                    'assets/images/lotties/WhiteStars.json',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              
              // Content
              SafeArea(
                bottom: false, // Don't respect safe area at the bottom to avoid the home indicator area
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top congratulations content - moved higher
                    Padding(
                      padding: const EdgeInsets.only(top: 30.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.translate('congratsPayment_congratulations'),
                            style: TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 50),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: 'ElzaRound',
                                fontSize: 36,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                height: 0.9,
                              ),
                              children: [
                                TextSpan(text: AppLocalizations.of(context)!.translate('congratsPayment_youAreNowA') + '\n'),
                                TextSpan(
                                  text: 'Stoppr',
                                  style: TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 80,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -4.8, // -6% of 80px
                                    height: 1.0, // 100% line height
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Expanded spacer to push content to top and bottom
                    const Spacer(),
                    
                    // Bottom container with message and button - no purple band
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 30, left: 20, right: 20, bottom: 40),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: 'ElzaRound',
                                fontSize: 18,
                                color: Color(0xFF181830),
                                height: 1.81,
                                letterSpacing: 0.32, // 2% of 16px
                              ),
                              children: [
                                TextSpan(
                                  text: AppLocalizations.of(context)!.translate('congratsPayment_rememberThisDay') + ' ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                TextSpan(
                                  text: AppLocalizations.of(context)!.translate('congratsPayment_asTheDay') + ' ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextSpan(
                                  text: AppLocalizations.of(context)!.translate('congratsPayment_changeYourLifeForGood'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 25),
                          SizedBox(
                            width: screenSize.width * 0.8,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _navigateToHomeScreen,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF231132),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.translate('congratsPayment_letsDoThis'),
                                style: const TextStyle(
                                  fontFamily: 'ElzaRound',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 