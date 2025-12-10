import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:stoppr/app/theme/colors.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';

class CancelSubscriptionScreen extends StatefulWidget {
  const CancelSubscriptionScreen({super.key});

  @override
  State<CancelSubscriptionScreen> createState() => _CancelSubscriptionScreenState();
}

class _CancelSubscriptionScreenState extends State<CancelSubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    
    // Track page view
    MixpanelService.trackPageView('Cancel Subscription Screen');
    
    // Force status bar icons to dark mode for light background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for light background
      statusBarBrightness: Brightness.light, // For iOS
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    
    // Make app fullscreen and immersive
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
  }
  
  @override
  void dispose() {
    // Restore default status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isIOS = Platform.isIOS;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for light background
        statusBarBrightness: Brightness.light, // For iOS
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
      backgroundColor: const Color(0xFFFDF8FA), // Soft pink-tinted white background for eye comfort
      body: Stack(
        children: [
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Fixed header with back button and title
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Color(0xFF1A1A1A), // Dark color for light background
                          size: 24,
                        ),
                        onPressed: () {
                          MixpanelService.trackButtonTap('Back Button', screenName: 'Cancel Subscription Screen');
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n?.translate('cancelSubscription_title') ?? 'Cancel membership',
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A), // Dark text for light background
                          fontSize: 24,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Fixed yellow heart bubble and "We'll miss you"
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Pink heart bubble with brand gradient
                      Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFed3272), // Strong pink/magenta
                              Color(0xFFfd5d32), // Vivid orange
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // "We'll miss you" title
                      Text(
                        l10n?.translate('cancelSubscription_wellMissYou') ?? "We'll miss you",
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A), // Dark text for light background
                          fontSize: 28,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      
                      // Subtitle
                      Text(
                        l10n?.translate('cancelSubscription_subtitle') ?? 
                        "You can always renew your membership to access our sugar-free challenges, personalized coaching, and community support.",
                        style: const TextStyle(
                          color: Color(0xFF666666), // Gray secondary text
                          fontSize: 16,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Scrollable instructions content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white, // White card background on soft pink background
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE0E0E0), // Light gray border
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Instructions title
                          Text(
                            isIOS 
                              ? (l10n?.translate('cancelSubscription_howToCancel_ios') ?? 'How to cancel if you purchased your subscription via App Store:')
                              : (l10n?.translate('cancelSubscription_howToCancel_android') ?? 'How to cancel if you purchased your subscription via Google Play:'),
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A), // Dark text on white card
                              fontSize: 18,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Steps
                          ...List.generate(5, (index) {
                            final stepNumber = index + 1;
                            String stepText;
                            
                            if (isIOS) {
                              switch (stepNumber) {
                                case 1:
                                  stepText = l10n?.translate('cancelSubscription_step1_ios') ?? 'Open the Settings app';
                                  break;
                                case 2:
                                  stepText = l10n?.translate('cancelSubscription_step2_ios') ?? 'Tap on your name';
                                  break;
                                case 3:
                                  stepText = l10n?.translate('cancelSubscription_step3_ios') ?? 'Tap "Subscriptions"';
                                  break;
                                case 4:
                                  stepText = l10n?.translate('cancelSubscription_step4_ios') ?? 'Select the STOPPR subscription';
                                  break;
                                case 5:
                                  stepText = l10n?.translate('cancelSubscription_step5_ios') ?? 'Tap "Cancel Subscription" to disable it from auto-renewing at the end of the current billing cycle';
                                  break;
                                default:
                                  stepText = '';
                              }
                            } else {
                              switch (stepNumber) {
                                case 1:
                                  stepText = l10n?.translate('cancelSubscription_step1_android') ?? 'Open the Google Play Store app';
                                  break;
                                case 2:
                                  stepText = l10n?.translate('cancelSubscription_step2_android') ?? 'Tap the profile icon in the top right';
                                  break;
                                case 3:
                                  stepText = l10n?.translate('cancelSubscription_step3_android') ?? 'Tap "Payments & subscriptions"';
                                  break;
                                case 4:
                                  stepText = l10n?.translate('cancelSubscription_step4_android') ?? 'Tap "Subscriptions"';
                                  break;
                                case 5:
                                  stepText = l10n?.translate('cancelSubscription_step5_android') ?? 'Find STOPPR and tap "Cancel subscription"';
                                  break;
                                default:
                                  stepText = '';
                              }
                            }
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xFFed3272), // Strong pink/magenta
                                          Color(0xFFfd5d32), // Vivid orange
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Center(
                                      child: Text(
                                        stepNumber.toString(),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontFamily: 'ElzaRound',
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n?.translate('cancelSubscription_stepNumber_$stepNumber') ?? 'Step $stepNumber',
                                          style: const TextStyle(
                                            color: Color(0xFFed3272), // Brand pink for accent text
                                            fontSize: 14,
                                            fontFamily: 'ElzaRound',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          stepText,
                                          style: const TextStyle(
                                            color: Color(0xFF1A1A1A), // Dark text on white card
                                            fontSize: 14,
                                            fontFamily: 'ElzaRound',
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          
                          // Add some bottom padding to ensure content doesn't get cut off
                          const SizedBox(height: 20),
                        ],
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
  );
  }
} 