import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import 'home_screen.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../features/app/presentation/screens/main_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:stoppr/core/pledges/pledge_service.dart';
import 'package:stoppr/core/services/defensive_asset_image_provider.dart';
import 'package:stoppr/core/streak/streak_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';


class PledgeScreen extends StatefulWidget {
  const PledgeScreen({super.key});

  @override
  State<PledgeScreen> createState() => _PledgeScreenState();
}

class _PledgeScreenState extends State<PledgeScreen> {
  bool _showSuccess = false;
  bool _showConfirmation = false;
  
  static const String _pledgeTimestampKey = 'pledge_timestamp';
  static const String _pledgeCountKey = 'pledge_count';
  
  // Initialize the NotificationService
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    
    // Track page view
    MixpanelService.trackPageView('Pledge Screen', 
      additionalProps: {'Source': 'Home Screen'});
    
    // Set status bar icons to dark mode for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for white background
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
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for white background
        statusBarBrightness: Brightness.light, // For iOS
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                TopToBottomPageRoute(
                  child: const MainScaffold(initialIndex: 0),
                  settings: const RouteSettings(name: '/home'),
                ),
              );
            },
          ),
          title: Center(
            child: Text(
              l10n.translate('pledgeScreen_title'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1A1A1A), // Dark text for white background
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          centerTitle: true,
          actions: [
            // Help & Info icon
            IconButton(
              icon: const Icon(
                Icons.help_outline,
                color: Color(0xFF1A1A1A),
                size: 28,
              ),
              onPressed: _openMedicalInfo,
              tooltip: l10n.translate('pledgeScreen_tooltip_help'),
            ),
          ],
        ),
        body: _showSuccess 
            ? _buildSuccessScreen() 
            : _showConfirmation
                ? _buildConfirmationScreen()
                : _buildPledgeScreen(),
      ),
    );
  }
  
  // Initial pledge screen
  Widget _buildPledgeScreen() {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Hand icon
                  Image(
                    image: DefensiveAssetImageProvider('assets/images/onboarding/raising_hand.png'),
                    width: 70,
                    height: 70,
                    color: const Color(0xFF1A1A1A), // Dark color for white background
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.error, size: 70, color: Color(0xFF1A1A1A)),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Title
                  Text(
                    l10n.translate('pledgeScreen_mainTitle'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A), // Dark text on white background
                      fontSize: 28,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.translate('pledgeScreen_mainDescription'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF666666), // Gray text for description
                        fontSize: 16,
                        fontFamily: 'ElzaRound',
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Benefits container
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFfae6ec).withOpacity(0.3), // Light pink accent from brand guide
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFed3272).withOpacity(0.2), // Brand pink border
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildPledgeBenefit(
                          icon: Icons.check_circle_outline,
                          text: l10n.translate('pledgeScreen_benefit1_title'),
                          description: l10n.translate('pledgeScreen_benefit1_description'),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        _buildPledgeBenefit(
                          icon: Icons.star_outline,
                          text: l10n.translate('pledgeScreen_benefit2_title'),
                          description: l10n.translate('pledgeScreen_benefit2_description'),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        _buildPledgeBenefit(
                          icon: Icons.emoji_events_outlined,
                          text: l10n.translate('pledgeScreen_benefit3_title'),
                          description: l10n.translate('pledgeScreen_benefit3_description'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom button
          Padding(
            padding: const EdgeInsets.all(24),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showConfirmation = true;
                });
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFed3272), // Strong pink/magenta
                      Color(0xFFfd5d32), // Vivid orange
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  l10n.translate('pledgeScreen_button_pledgeNow'),
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    color: Colors.white, // White text on gradient
                    fontSize: 19, // Brand standard
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Confirmation dialog
  Widget _buildConfirmationScreen() {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        // Background screen
        _buildPledgeScreen(),
        
        // Confirmation dialog
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFed3272).withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.translate('pledgeScreen_confirmDialog_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A), // Dark text for white background
                    fontSize: 18,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  l10n.translate('pledgeScreen_mainDescription'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF666666), // Gray text for description
                    fontSize: 14,
                    fontFamily: 'ElzaRound',
                  ),
                ),
                
                const SizedBox(height: 30),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cancel button
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _showConfirmation = false;
                          });
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: const Color(0xFF666666),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFFE0E0E0)),
                          ),
                        ),
                        child: Text(
                          l10n.translate('common_cancel'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Confirm button
                    Expanded(
                      child: GestureDetector(
                        onTap: _confirmPledge,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFed3272), // Strong pink/magenta
                                Color(0xFFfd5d32), // Vivid orange
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            l10n.translate('homeScreen_pledge'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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
        ),
      ],
    );
  }
  
  // Success screen
  Widget _buildSuccessScreen() {
    final l10n = AppLocalizations.of(context)!;
          return Container(
        decoration: const BoxDecoration(
          color: Colors.white, // Clean white background
        ),
        child: Stack(
          children: [
            // Lottie animation overlay
            Positioned.fill(
              child: Lottie.asset(
                'assets/images/lotties/fireworksRed.json',
                fit: BoxFit.cover,
                repeat: true,
              ),
            ),
            // Content overlay
            Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Checkmark icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
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
                  Icons.check,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Success text
              Text(
                l10n.translate('pledgeScreen_success_title'),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text for white background
                  fontSize: 28,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  l10n.translate('pledgeScreen_mainDescription'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF666666), // Gray text for description
                    fontSize: 16,
                    fontFamily: 'ElzaRound',
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Finish button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pushReplacement(
                    TopToBottomPageRoute(
                      child: const MainScaffold(initialIndex: 0),
                      settings: const RouteSettings(name: '/home'),
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFed3272), // Strong pink/magenta
                          Color(0xFFfd5d32), // Vivid orange
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.translate('dailyCheckIn_finish'),
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        color: Colors.white, // White text on gradient
                        fontSize: 19, // Brand standard
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
            ),
          ],
        ),
      );
  }
  
  Widget _buildPledgeBenefit({
    required IconData icon,
    required String text,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: const Color(0xFFed3272), // Brand pink for icons
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text for white background
                  fontSize: 16,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF666666), // Gray text for descriptions
                  fontSize: 14,
                  fontFamily: 'ElzaRound',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Handle pledge confirmation
  Future<void> _confirmPledge() async {
    final l10n = AppLocalizations.of(context)!;
    // Check if notification permissions are granted based on platform
    bool permissionsGranted = false;
    
    // Use the new coordinated notification permission request
    permissionsGranted = await _notificationService.requestAllNotificationPermissions();
    
    if (!permissionsGranted) {
      // If permissions weren't granted, show a dialog explaining why notifications are needed
      if (!mounted) return;
      
      bool shouldContinue = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.translate('pledgeScreen_notificationDialog_title')),
          content: Text(
            l10n.translate('pledgeScreen_notificationDialog_content'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.translate('common_cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.translate('pledgeScreen_notificationDialog_button_continueAnyway')),
            ),
          ],
        ),
      ) ?? false;
      
      if (!shouldContinue) {
        setState(() {
          _showConfirmation = false;
        });
        return;
      }
    }
    
    // Get current time and calculate completion time
    final now = DateTime.now();
    final completionTime = now.add(const Duration(hours: 24));
    
    // Use PledgeService to start the pledge (handles local + Firebase + Mixpanel)
    try {
      await PledgeService().startPledge(now, completionTime);
      debugPrint('✅ Pledge started via PledgeService.');
    } catch (e) {
      debugPrint('❌ Error starting pledge via PledgeService: $e');
      // Handle error appropriately - maybe show a message to the user?
      // For now, just log and potentially prevent success screen
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(l10n.translate('pledgeScreen_snackbar_error_couldNotStartPledge'))),
         );
         setState(() {
           _showConfirmation = false; // Go back to initial screen
         });
      }
      return; // Stop execution if pledge couldn't be started
    }
    
    // Schedule a notification for when the pledge is complete
    // (Keep this here as it's UI/Notification related)
    await _notificationService.schedulePledgeCheckNotification(
      checkTime: completionTime,
      title: l10n.translate('pledgeScreen_pledgeCompleteNotification_title'),
      body: l10n.translate('pledgeScreen_pledgeCompleteNotification_body'),
    );
    
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Pledge Confirm', screenName: 'Pledge Screen', additionalProps: {
      'notification_permissions_granted': permissionsGranted,
      'pledge_start_time': now.toIso8601String(),
      'pledge_end_time': completionTime.toIso8601String(),
    });
    
    // Increment local pledge count (This seems like a local UI stat, keep it if needed, otherwise rely on Firestore)
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_pledgeCountKey) ?? 0;
    await prefs.setInt(_pledgeCountKey, currentCount + 1);
    debugPrint('ℹ️ Incremented local pledge count to ${currentCount + 1}');

    // Show success screen
    if (mounted) {
      setState(() {
        _showConfirmation = false;
        _showSuccess = true;
      });
    }
  }

  // Method to open medical information URL
  Future<void> _openMedicalInfo() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Help & Info', screenName: 'Pledge Screen');
    
    final Uri url = Uri.parse('https://elevenlife.notion.site/Stoppr-1c3456d8905e80029856d5373ee08dfb?pvs=4');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.inAppWebView,
        );
      } else {
        debugPrint('Could not launch help & info URL');
      }
    } catch (e) {
      debugPrint('Error launching help & info URL: $e');
    }
  }
} 