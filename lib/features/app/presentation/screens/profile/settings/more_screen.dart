import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../../core/analytics/mixpanel_service.dart';
import 'dart:io' show Platform;
import 'package:in_app_review/in_app_review.dart';
import '../../../../../../core/localization/app_localizations.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final InAppReview _inAppReview = InAppReview.instance;

  @override
  void initState() {
    super.initState();
    
    // Track page view
    MixpanelService.trackPageView('More Screen');
    
    // Status bar for light background per brand guide
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
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
    // Restore default status bar for light background
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

  // Method to open the store listing for rating/review every time
  Future<void> _showRatingDialog() async {
    try {
      if (Platform.isIOS) {
        await _inAppReview.openStoreListing(appStoreId: '6742406521');
      } else if (Platform.isAndroid) {
        await _inAppReview.openStoreListing(appStoreId: 'com.stoppr.sugar.app');
      }
    } catch (e) {
      debugPrint('Error showing rating dialog: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.translate('errorMessage_ratingDialog').replaceFirst('{error}', e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Method to open URL
  Future<void> _launchURL(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.inAppWebView);
      } else {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.translate('errorMessage_openLink').replaceFirst('{error}', e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Method to build settings option
  Widget _buildSettingsOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: () {
          // Track more option tap
          MixpanelService.trackEvent('$title Button Tap');
          onTap();
        },
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 8.0,
        ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Color(0xFF666666),
          size: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            AppLocalizations.of(context)!.translate('moreScreen_title'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 30,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: false,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        body: ListView(
          children: [
            // Rate STOPPR
            _buildSettingsOption(
              icon: Icons.thumb_up_alt_outlined,
              iconColor: const Color(0xFF666666),
              title: AppLocalizations.of(context)!.translate('moreScreen_encourageUs'),
              onTap: _showRatingDialog,
            ),
            // Terms of use
            _buildSettingsOption(
              icon: Icons.description,
              iconColor: const Color(0xFF666666),
              title: AppLocalizations.of(context)!.translate('moreScreen_termsOfUse'),
              onTap: () => _launchURL('https://www.stoppr.app/terms-conditions'),
            ),
            // Privacy policy
            _buildSettingsOption(
              icon: Icons.privacy_tip,
              iconColor: const Color(0xFF666666),
              title: AppLocalizations.of(context)!.translate('moreScreen_privacyPolicy'),
              onTap: () => _launchURL('https://www.stoppr.app/privacy-policy'),
            ),
          ],
        ),
      ),
    );
  }
} 