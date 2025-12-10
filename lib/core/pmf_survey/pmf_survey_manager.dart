import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../analytics/mixpanel_service.dart';
import '../localization/app_localizations.dart';

/// PMF Survey Manager - Handles the display and tracking of Product-Market Fit surveys
/// 
/// This manager:
/// - Determines when to show the PMF survey based on app usage and time
/// - Prevents survey interruption during key moments (check-ins, pledges, etc.)
/// - Integrates with Google Forms for data collection
/// - Tracks Firebase user IDs for response attribution
class PMFSurveyManager {
  // Constants for PMF survey display rules
  static const String _pmfLastPromptKey = 'pmf_survey_last_prompt_date';
  static const String _pmfCompletedKey = 'pmf_survey_completed';
  static const String _pmfInstallDateKey = 'pmf_survey_install_date';
  static const String _pmfAppOpenCountKey = 'pmf_survey_app_open_count';
  static const String _pmfLastDismissedKey = 'pmf_survey_last_dismissed_date';
  static const int _pmfDismissWaitDays = 14; // Wait 14 days after dismissing
  
  // Timing parameters
  static const int _minDaysSinceInstall = 5; // At least 5 days of app usage
  static const int _minAppOpens = 8; // At least 8 app opens
  static const int _minDaysBetweenPrompts = 30; // Don't show more than once per month
  
  // Survey configuration
  static const String _googleFormId = '1FAIpQLScaDizWV8-SETerzBskbcckpN797v6_-jb4yWJvRv1QMC51hg';
  
  // Tracking
  DateTime? _lastCheckTime;
  bool _isCheckInProgress = false;
  
  // Singleton instance
  static final PMFSurveyManager _instance = PMFSurveyManager._internal();
  
  // Factory constructor
  factory PMFSurveyManager() {
    return _instance;
  }
  
  // Private constructor
  PMFSurveyManager._internal();
  
  /// Track app open to count towards survey display criteria
  Future<void> trackAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Record install date if first time
    if (!prefs.containsKey(_pmfInstallDateKey)) {
      await prefs.setInt(_pmfInstallDateKey, DateTime.now().millisecondsSinceEpoch);
      
      // Track first install with Mixpanel
      //MixpanelService.trackEvent('PMF Survey First Install');
    }
    
    // Increment app open count
    final currentCount = prefs.getInt(_pmfAppOpenCountKey) ?? 0;
    await prefs.setInt(_pmfAppOpenCountKey, currentCount + 1);
    
    // Log only on significant milestones to avoid excessive logging
    if (currentCount == 0 || currentCount == 5 || currentCount == 10 || 
        currentCount == 25 || currentCount == 50 || currentCount == 100) {
      MixpanelService.trackEvent('PMF Survey App Open Count', properties: {
        'count': currentCount + 1
      });
    }
  }
  
  /// Check if we should show the PMF survey now
  /// 
  /// [isCheckInActive] - Pass true if daily check-in is active
  /// [isPledgeActive] - Pass true if pledge feature is active
  /// 
  /// Returns true if survey should be shown
  Future<bool> shouldShowSurvey({
    bool isCheckInActive = false,
    bool isPledgeActive = false,
    bool isRelapsing = false, 
    bool isOnboarding = false
  }) async {
    // Prevent multiple simultaneous checks
    if (_isCheckInProgress) {
      return false;
    }
    
    // Don't check more than once per minute
    if (_lastCheckTime != null && 
        DateTime.now().difference(_lastCheckTime!).inMinutes < 1) {
      return false;
    }
    
    _isCheckInProgress = true;
    _lastCheckTime = DateTime.now();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check important conditions first - don't interrupt these flows
      if (isCheckInActive || isPledgeActive || isRelapsing || isOnboarding) {
        _isCheckInProgress = false;
        return false;
      }
      
      // If user already completed the survey, don't show again
      if (prefs.getBool(_pmfCompletedKey) == true) {
        _isCheckInProgress = false;
        return false;
      }
      
      // Check when we last showed the survey
      final lastPromptMillis = prefs.getInt(_pmfLastPromptKey) ?? 0;
      final lastPromptDate = DateTime.fromMillisecondsSinceEpoch(lastPromptMillis);
      final now = DateTime.now();
      
      // Only show if it's been at least _minDaysBetweenPrompts days
      if (now.difference(lastPromptDate).inDays < _minDaysBetweenPrompts) {
        _isCheckInProgress = false;
        return false;
      }
      
      // Check if user recently dismissed the survey
      final lastDismissedMillis = prefs.getInt(_pmfLastDismissedKey) ?? 0;
      if (lastDismissedMillis > 0) {
        final lastDismissedDate = DateTime.fromMillisecondsSinceEpoch(lastDismissedMillis);
        if (now.difference(lastDismissedDate).inDays < _pmfDismissWaitDays) {
          _isCheckInProgress = false;
          return false;
        }
      }
      
      // Check days since install
      final installDateMillis = prefs.getInt(_pmfInstallDateKey) ?? now.millisecondsSinceEpoch;
      final installDate = DateTime.fromMillisecondsSinceEpoch(installDateMillis);
      if (now.difference(installDate).inDays < _minDaysSinceInstall) {
        _isCheckInProgress = false;
        return false;
      }
      
      // Check app open count
      final appOpenCount = prefs.getInt(_pmfAppOpenCountKey) ?? 0;
      if (appOpenCount < _minAppOpens) {
        _isCheckInProgress = false;
        return false;
      }
      
      // If we get here, we should show the survey
      _isCheckInProgress = false;
      return true;
    } catch (e) {
      debugPrint('Error checking PMF survey criteria: $e');
      _isCheckInProgress = false;
      return false;
    }
  }
  
  /// Show the PMF survey dialog
  Future<void> showSurveyPrompt(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Mark that we've shown the survey
    await prefs.setInt(_pmfLastPromptKey, DateTime.now().millisecondsSinceEpoch);
    
    // Track survey shown with Mixpanel
    MixpanelService.trackEvent('PMF Survey Shown');
    
    // Show branded popup per style_brand.md
    // - White background, rounded corners, shadow
    // - Dark text (#1A1A1A) and gray secondary where applicable
    // - CTA button uses pink→orange gradient; secondary link uses brand pink
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('pmfSurvey_title'),
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontFamily: 'ElzaRound',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.translate('pmfSurvey_message'),
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontFamily: 'ElzaRound',
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    // Secondary action: brand pink text button
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          MixpanelService.trackEvent('PMF Survey Dismissed');
                          prefs.setInt(
                            _pmfLastDismissedKey,
                            DateTime.now().millisecondsSinceEpoch,
                          );
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFed3272),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          l10n.translate('pmfSurvey_notNow'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Primary CTA: gradient button
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          MixpanelService.trackEvent('PMF Survey Accepted');
                          Navigator.of(context).pop();
                          _openPMFSurvey();
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Ink(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFed3272),
                                Color(0xFFfd5d32),
                              ],
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              l10n.translate('pmfSurvey_giveFeedback'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'ElzaRound',
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// Open the PMF survey in the browser with user ID
  Future<void> _openPMFSurvey() async {
    try {
      final surveyUrl = getSurveyUrl();
      
      // Track survey opened
      MixpanelService.trackEvent('PMF Survey Opened');
      
      // Mark as completed (optimistically - can't detect actual completion)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pmfCompletedKey, true);
      
      // Open URL in external browser
      final Uri uri = Uri.parse(surveyUrl);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error opening PMF survey: $e');
      
      // Track error
      MixpanelService.trackEvent('PMF Survey Error', properties: {
        'error': e.toString()
      });
    }
  }
  
  /// Get the survey URL with the user's Firebase ID
  String getSurveyUrl() {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'anonymous';
    return 'https://docs.google.com/forms/d/e/$_googleFormId/viewform?userId=$userId';
  }
  
  /// Mark the survey as seen but not completed
  Future<void> markSurveyPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pmfLastPromptKey, DateTime.now().millisecondsSinceEpoch);
  }
  
  /// Manual override - show the survey regardless of conditions
  Future<void> forceSurveyDisplay(BuildContext context) async {
    MixpanelService.trackEvent('PMFSurvey Force Displayed');
    await showSurveyPrompt(context);
  }
  
  /// Reset survey status (for testing)
  Future<void> resetSurveyStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pmfCompletedKey);
    await prefs.remove(_pmfLastPromptKey);
    await prefs.remove(_pmfLastDismissedKey);
    
    // Keep install date and app open count
    
    MixpanelService.trackEvent('PMFSurvey Status Reset');
  }
} 