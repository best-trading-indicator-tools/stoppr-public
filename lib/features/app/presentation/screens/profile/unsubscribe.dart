import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import '../main_scaffold.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../features/onboarding/presentation/screens/onboarding_page.dart';
import '../../../../../features/onboarding/data/services/onboarding_progress_service.dart';
import '../../../../../core/localization/app_localizations.dart';

// String extension for capitalization
extension StringExtension on String {
  String capitalizeFirst() {
    if (this.isEmpty) return this;
    return '${this[0].toUpperCase()}${this.substring(1)}';
  }
}

// Enum for unsubscribe reasons
enum UnsubscribeReason {
  didntFindUseful,
  tooExpensive,
  difficultToUse,
  foundBetterApp,
  privacyConcerns,
  technicalIssues,
  other
}

class UnsubscribeScreen extends StatefulWidget {
  const UnsubscribeScreen({super.key});

  @override
  State<UnsubscribeScreen> createState() => _UnsubscribeScreenState();
}

class _UnsubscribeScreenState extends State<UnsubscribeScreen> {
  final TextEditingController _reasonController = TextEditingController();
  final OnboardingProgressService _progressService = OnboardingProgressService();
  
  bool _canSubmit = false;
  bool _isSubmitting = false;
  UnsubscribeReason? _selectedReason;
  
  @override
  void initState() {
    super.initState();
    
    // Track page view with Mixpanel
    MixpanelService.trackPageView('Unsubscribe Screen');
    
    // Add listener to track text changes
    _reasonController.addListener(_checkReasonLength);
    
    // Force status bar icons to white mode with explicit settings
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark, // iOS uses opposite naming
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    
    // Make app fullscreen and immersive
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
  }
  
  @override
  void dispose() {
    _reasonController.removeListener(_checkReasonLength);
    _reasonController.dispose();
    
    // Restore default status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    
    super.dispose();
  }
  
  void _checkReasonLength() {
    setState(() {
      // Enable submit button when text is at least 15 characters (for "Other" option)
      if (_selectedReason == UnsubscribeReason.other) {
        _canSubmit = _reasonController.text.trim().length >= 15;
      }
    });
  }
  
  Widget _buildRadioOption(UnsubscribeReason reason, String text) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedReason = reason;
          // If not "Other", then we can submit immediately
          _canSubmit = (reason != UnsubscribeReason.other) || 
                       (_reasonController.text.trim().length >= 15);
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Radio<UnsubscribeReason>(
              value: reason,
              groupValue: _selectedReason,
              onChanged: (UnsubscribeReason? value) {
                setState(() {
                  _selectedReason = value;
                  // If not "Other", then we can submit immediately
                  _canSubmit = (value != UnsubscribeReason.other) || 
                              (_reasonController.text.trim().length >= 15);
                });
              },
              fillColor: MaterialStateProperty.all(Colors.white),
            ),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'ElzaRound',
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getUnsubscribeFeedbackText() {
    if (_selectedReason == UnsubscribeReason.other) {
      return _reasonController.text.trim().isNotEmpty 
          ? _reasonController.text.trim() 
          : 'Other (no details provided)';
    } else {
      // Convert enum to readable string
      final String reasonText = _selectedReason.toString().split('.').last;
      // Convert camelCase to sentence case with spaces
      return reasonText.replaceAllMapped(
        RegExp(r'([A-Z])'), 
        (match) => ' ${match.group(0)!.toLowerCase()}'
      ).capitalizeFirst();
    }
  }
  
  Future<void> _confirmUnsubscribe() async {
    if (_selectedReason == null) return;
    
    // For "Other" reason, ensure there's sufficient text
    if (_selectedReason == UnsubscribeReason.other && 
        _reasonController.text.trim().length < 15) return;
    
    // Track unsubscribe button tap
    MixpanelService.trackEvent('Unsubscribe Button Tap');
    
    // Store unsubscribe feedback in Firestore
    try {
      await FirebaseFirestore.instance.collection('unsubscribe_feedback').add({
        'userId': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        'reason': _getUnsubscribeFeedbackText(),
        'reasonCategory': _selectedReason?.toString().split('.').last ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'email': FirebaseAuth.instance.currentUser?.email ?? 'unknown',
      });
      debugPrint('Unsubscribe feedback stored in Firestore');
    } catch (e) {
      debugPrint('Error storing unsubscribe feedback: $e');
      // Continue with unsubscribe process even if storage fails
    }
    
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF240067),
          title: const Text(
            'Confirm Unsubscription',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Text(
            'Are you sure you want to unsubscribe? This will not immediately cancel your subscription through App Store. You need to manage your subscription through App Store settings.',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'ElzaRound',
            ),
          ),
          actions: [
            Column(
              children: [
                const Divider(
                  color: Color(0xFF2C2C2E),
                  height: 1,
                ),
                InkWell(
                  onTap: () {
                    Navigator.of(context).pop(); // Close dialog
                    _launchAppStoreSubscriptions();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Center(
                      child: Text(
                        'Proceed',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'ElzaRound',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: const Center(
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: 'ElzaRound',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _launchAppStoreSubscriptions() async {
    // iOS App Store URL for subscription management
    final Uri subscriptionUrl = Uri.parse('https://apps.apple.com/account/subscriptions');
    
    try {
      if (await canLaunchUrl(subscriptionUrl)) {
        await launchUrl(subscriptionUrl, mode: LaunchMode.externalApplication);
        
        // Return to onboarding screen after launching URL instead of MainScaffold
        if (!mounted) return;
        
        // Update the user's subscription status
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            // Update subscription status in Firestore to indicate user has unsubscribed
            await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
              'subscriptionStatus': 'free',
              'unsubscribedAt': FieldValue.serverTimestamp(),
            });
            
            // Track unsubscribe event in Mixpanel
            MixpanelService.trackEvent('User Unsubscribed', properties: {
              'userId': user.uid,
              'email': user.email ?? 'unknown',
              'timestamp': DateTime.now().toIso8601String(),
              'reasonCategory': _selectedReason?.toString().split('.').last ?? 'unknown',
            });
            
            // Clear onboarding progress since user needs to restart onboarding
            await _progressService.clearOnboardingProgress();
            debugPrint('Cleared onboarding progress due to unsubscription');
          }
        } catch (e) {
          debugPrint('Error updating subscription status: $e');
        }
        
        // Navigate to onboarding screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const OnboardingPage(),
          ),
          (route) => false, // Remove all previous routes
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.translate('errorMessage_launchAppStore')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.translate('error_generic').replaceFirst('{error}', e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFF140120),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          title: const Text(
            'Unsubscribe',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: SizedBox(
                height: MediaQuery.of(context).size.height - 140, // Account for AppBar height
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 30),
                    const Center(
                      child: Text(
                        'Why are you leaving?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    const Text(
                      'Please select a reason:',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'ElzaRound',
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Radio buttons for pre-defined reasons
                    _buildRadioOption(
                      UnsubscribeReason.didntFindUseful, 
                      'Didn\'t find it useful'
                    ),
                    _buildRadioOption(
                      UnsubscribeReason.tooExpensive, 
                      'Too expensive'
                    ),
                    _buildRadioOption(
                      UnsubscribeReason.difficultToUse, 
                      'Difficult to use'
                    ),
                    _buildRadioOption(
                      UnsubscribeReason.foundBetterApp, 
                      'Found a better app'
                    ),
                    _buildRadioOption(
                      UnsubscribeReason.privacyConcerns, 
                      'Privacy concerns'
                    ),
                    _buildRadioOption(
                      UnsubscribeReason.technicalIssues, 
                      'Technical issues'
                    ),
                    _buildRadioOption(
                      UnsubscribeReason.other, 
                      'Other'
                    ),
                    
                    // Show text field if "Other" is selected
                    if (_selectedReason == UnsubscribeReason.other)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Container(
                          height: 150,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F1030),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: _reasonController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'ElzaRound',
                            ),
                            maxLines: 6,
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)!.translate('unsubscribe_reasonHint'),
                              hintStyle: const TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                                fontFamily: 'ElzaRound',
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                          ),
                        ),
                      ),
                    
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: GestureDetector(
                        onTap: (_selectedReason != null && _canSubmit) ? _confirmUnsubscribe : null,
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: (_selectedReason != null && _canSubmit)
                                    ? [const Color(0xFF140120), const Color(0xFFFF3B30)]
                                    : [Colors.grey.shade800, Colors.grey.shade700],
                                ),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Center(
                                child: Text(
                                  'Confirm and Unsubscribe',
                                  style: TextStyle(
                                    color: (_selectedReason != null && _canSubmit) 
                                        ? Colors.white 
                                        : Colors.white70,
                                    fontSize: 18,
                                    fontFamily: 'ElzaRound',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 18,
                                      fontFamily: 'ElzaRound',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 