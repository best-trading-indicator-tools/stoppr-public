import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/installation/installation_tracker_service.dart';
import 'package:stoppr/core/chat/crisp_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:stoppr/features/onboarding/presentation/screens/congratulations/congratulations_screen_1.dart';
import 'package:stoppr/core/subscription/post_purchase_handler.dart';

class RedownloadFeedbackScreen extends StatefulWidget {
  final VoidCallback onComplete;
  
  const RedownloadFeedbackScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<RedownloadFeedbackScreen> createState() =>
      _RedownloadFeedbackScreenState();
}

class _RedownloadFeedbackScreenState extends State<RedownloadFeedbackScreen> {
  String? _selectedReason;
  bool _isSubmitting = false;
  bool _hasSubmitted = false;
  bool _is80OffPaywallRegistered = false;

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlayStyle();
    
    // Track page view
    MixpanelService.trackEvent(
      'Redownload Feedback Screen: Page Viewed',
      properties: {
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _setSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    if (Platform.isAndroid) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
      );
    }
  }

  Future<void> _submitFeedback(String reason) async {
    if (_hasSubmitted) return; // Prevent double submission
    
    setState(() {
      _isSubmitting = true;
      _hasSubmitted = true;
    });

    try {
      // Track in Mixpanel
      MixpanelService.trackEvent(
        'Redownload Feedback Screen: Option Selected',
        properties: {
          'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Record ALL feedback selections in Firestore and Mixpanel
      await _recordFeedback(reason);
      
      // Handle each option's specific action
      switch (reason) {
        case 'redownload_feedback_option_performance':
          // Open email with prefilled question
          await _openPerformanceEmail();
          break;
          
        case 'redownload_feedback_option_suggestion':
          // Open Crisp chat
          await _openCrispChat();
          break;
          
        case 'redownload_feedback_option_price':
          // Launch 80% off paywall
          await _launch80OffPaywall();
          return; // Don't clear feedback flag or navigate yet
          
        case 'redownload_feedback_option_motivation':
          // Already recorded above, no additional action
          break;
          
        case 'redownload_feedback_option_notifications':
          // Show popup after recording
          if (mounted) {
            await _showNotificationsPopup();
          }
          break;
          
        default:
          // Already recorded above
          break;
      }

      // Clear the feedback form flag
      await InstallationTrackerService().clearFeedbackFormFlag();

      // Brief delay to show selection, then navigate
      await Future.delayed(const Duration(milliseconds: 400));

      // Complete
      if (mounted) {
        widget.onComplete();
      }
    } catch (e) {
      debugPrint('Error submitting feedback: $e');
      
      // Even on error, proceed to avoid blocking the user
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        widget.onComplete();
      }
    }
  }

  Future<void> _recordFeedback(String reason) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Save to Firestore
        await FirebaseFirestore.instance
            .collection('redownload_feedback')
            .add({
          'userId': user.uid,
          'reason': reason,
          'timestamp': FieldValue.serverTimestamp(),
          'platform': Platform.operatingSystem,
        });

        // Also add to user document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'redownload_feedback': {
            'reason': reason,
            'timestamp': FieldValue.serverTimestamp(),
          }
        });
      }

      // Track in Mixpanel
      MixpanelService.trackEvent(
        'Redownload Feedback Screen: Option Recorded',
        properties: {
          'reason': reason,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Error recording feedback: $e');
    }
  }

  Future<void> _openPerformanceEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userEmail = user?.email ?? '';
      
      final subject = Uri.encodeComponent('App Performance Issue');
      final body = Uri.encodeComponent(
        "What's the issue? (Speed, crashes, reliability, etc)\n\n"
        "Please describe the performance issue you're experiencing:\n\n\n\n"
        "---\n"
        "User: $userEmail\n"
        "Platform: ${Platform.operatingSystem}\n"
        "Timestamp: ${DateTime.now().toIso8601String()}"
      );
      
      final emailUri = Uri.parse('mailto:support@stoppr.app?subject=$subject&body=$body');
      
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        MixpanelService.trackEvent('Redownload Feedback: Email Opened');
      } else {
        throw 'Could not launch email';
      }
    } catch (e) {
      debugPrint('Error opening email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open email app: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openCrispChat() async {
    try {
      final crispService = CrispService();
      
      // Set user information if available
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email != null) {
        // Try to get display name from Firebase Auth
        String firstName = 'You';
        if (currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
          final nameParts = currentUser.displayName!.split(' ');
          if (nameParts.isNotEmpty) {
            firstName = nameParts[0];
          }
        }
        
        crispService.setUserInformation(
          email: currentUser.email!,
          firstName: firstName,
        );
      }
      
      // Open Crisp chat
      if (mounted) {
        crispService.openChat(context);
        MixpanelService.trackEvent('Redownload Feedback: Crisp Opened');
      }
    } catch (e) {
      debugPrint('Error opening Crisp chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open support chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launch80OffPaywall() async {
    if (_is80OffPaywallRegistered) {
      debugPrint('80% off paywall already registered, skipping');
      return;
    }

    try {
      _is80OffPaywallRegistered = true;
      
      // Create paywall handler
      PaywallPresentationHandler handler = PaywallPresentationHandler();
      
      handler.onPresent((paywallInfo) async {
        String? name = await paywallInfo.name;
        debugPrint("80% Off Paywall presented: ${name ?? 'Unknown'}");
      });

      handler.onDismiss((paywallInfo, paywallResult) async {
        String? name = await paywallInfo.name;
        debugPrint("80% Off Paywall dismissed: ${name ?? 'Unknown'}");
        _is80OffPaywallRegistered = false;
      });

      handler.onError((error) {
        debugPrint('80% Off Paywall error: $error');
        _is80OffPaywallRegistered = false;
      });

      handler.onSkip((skipReason) async {
        String reasonString = skipReason.toString();
        debugPrint("80% Off Paywall skipped: $reasonString");
        _is80OffPaywallRegistered = false;
      });

      // Register the placement
      await Superwall.shared.registerPlacement(
        "INSERT_YOUR_REDOWNLOAD_80_OFF_PLACEMENT_ID_HERE",
        handler: handler,
        feature: () async {
          final defaultProductId = Platform.isIOS 
              ? 'com.stoppr.app.annual80OFF' 
              : 'com.stoppr.sugar.app.annual80off:annual80off';
          
          await InstallationTrackerService().clearFeedbackFormFlag();
          await PostPurchaseHandler.handlePostPurchase(
            context,
            defaultProductId: defaultProductId,
          );
        },
      );
      
      debugPrint('Registered redownload_80_off placement');
    } catch (e) {
      debugPrint('Error launching 80% off paywall: $e');
      _is80OffPaywallRegistered = false;
      
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _hasSubmitted = false;
        });
      }
    }
  }

  Future<void> _showNotificationsPopup() async {
    final l10n = AppLocalizations.of(context)!;
    
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title with emoji
                Text(
                  l10n.translate('redownload_notifications_popup_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Message
                Text(
                  l10n.translate('redownload_notifications_popup_message'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Branded gradient button
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFed3272), // Brand pink
                        Color(0xFFfd5d32), // Brand orange
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      MixpanelService.trackEvent('Redownload Feedback: Notifications Popup Dismissed');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: Text(
                      l10n.translate('chatbot_voiceOnly_dismissButton'),
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Title
              Text(
                l10n.translate('redownload_feedback_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  height: 1.3,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Subtitle
              Text(
                l10n.translate('redownload_feedback_subtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF666666),
                  height: 1.4,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Options
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildOption(
                        'redownload_feedback_option_price',
                        l10n,
                      ),
                      const SizedBox(height: 16),
                      _buildOption(
                        'redownload_feedback_option_performance',
                        l10n,
                      ),
                      const SizedBox(height: 16),
                      _buildOption(
                        'redownload_feedback_option_suggestion',
                        l10n,
                      ),
                      const SizedBox(height: 16),
                      _buildOption(
                        'redownload_feedback_option_motivation',
                        l10n,
                      ),
                      const SizedBox(height: 16),
                      _buildOption(
                        'redownload_feedback_option_notifications',
                        l10n,
                      ),
                      const SizedBox(height: 40), // Bottom padding
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(String translationKey, AppLocalizations l10n) {
    final isSelected = _selectedReason == translationKey;
    final isDisabled = _isSubmitting;
    
    return GestureDetector(
      onTap: isDisabled ? null : () {
        // Set selected state immediately for visual feedback
        setState(() {
          _selectedReason = translationKey;
        });
        
        // Submit immediately
        _submitFeedback(translationKey);
      },
      child: Opacity(
        opacity: isDisabled && !isSelected ? 0.5 : 1.0,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFed3272)
                  : const Color(0xFFE0E0E0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFed3272).withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Radio circle
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFed3272)
                        : const Color(0xFFBDBDBD),
                    width: 2,
                  ),
                  color: isSelected
                      ? const Color(0xFFed3272)
                      : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
              
              const SizedBox(width: 16),
              
              // Text
              Expanded(
                child: Text(
                  l10n.translate(translationKey),
                  style: TextStyle(
                    fontFamily: 'ElzaRound',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF1A1A1A)
                        : const Color(0xFF666666),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

