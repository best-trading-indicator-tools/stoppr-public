import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../../core/chat/crisp_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../../core/localization/app_localizations.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';

class UserProfileSupportScreen extends StatefulWidget {
  const UserProfileSupportScreen({super.key});

  @override
  State<UserProfileSupportScreen> createState() => _UserProfileSupportScreenState();
}

class _UserProfileSupportScreenState extends State<UserProfileSupportScreen> {
  final CrispService _crispService = CrispService();
  String? _firstName;
  bool _isLoading = true;
  static final Uri _bugReportUri = Uri.parse('https://docs.google.com/forms/d/e/1FAIpQLSeEKHi7jB4axv5nyU1UnNjdD9ONolm7p_Q9-7T-5J-yMvnFcw/viewform?usp=dialog');
  
  @override
  void initState() {
    super.initState();
    
    // Track page view
    MixpanelService.trackPageView('User Profile Support Screen');
    
    _loadUserData();
    
    // Force status bar icons to dark mode with explicit settings
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
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

  Future<void> _loadUserData() async {
    try {
      // Try to get name from SharedPreferences first
      final prefs = await SharedPreferences.getInstance();
      final savedFirstName = prefs.getString('user_first_name');
      
      if (savedFirstName != null && savedFirstName.isNotEmpty) {
        if (mounted) {
          setState(() {
            _firstName = savedFirstName;
            _isLoading = false;
          });
        }
        return; // Exit if we found a name
      }
      
      // Fallback to Firebase Auth if name not in SharedPreferences
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.displayName != null) {
        final displayNameParts = currentUser.displayName!.split(' ');
        if (displayNameParts.isNotEmpty) {
          if (mounted) {
            setState(() {
              _firstName = displayNameParts[0]; // Get first name from display name
              _isLoading = false;
            });
          }
        } else {
          // No display name parts found
          if (mounted) {
            setState(() {
              _firstName = 'You';
              _isLoading = false;
            });
          }
        }
      } else {
        // No user or display name found
        if (mounted) {
          setState(() {
            _firstName = 'You';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _firstName = 'You'; // Fallback to a default name
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _openCrispChat() async {
    try {
      // Get current user email if available
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email != null) {
        _crispService.setUserInformation(
          email: currentUser.email!,
          firstName: TextSanitizer.sanitizeForDisplay(_firstName ?? 'You'),
        );
      }
      
      // Open Crisp chat
      _crispService.openChat(context);
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

  Future<void> _openBugReportForm() async {
    try {
      MixpanelService.trackEvent('Support Report Bug Form Open');
      if (!await launchUrl(
        _bugReportUri,
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
      )) {
        throw 'Could not launch form';
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
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFDF8FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Support',
            style: TextStyle(
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
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Column(
                    children: [
                      // Report a bug option
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            // Track report bug event and open form
                            MixpanelService.trackEvent('Report Bug Button Tap');
                            _openBugReportForm();
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFed3272).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.bug_report,
                              color: Color(0xFFed3272),
                              size: 24,
                            ),
                          ),
                          title: const Text(
                            'Report a bug',
                            style: TextStyle(
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
                      ),
                      
                      // Contact us option
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            // Track contact us event
                            MixpanelService.trackEvent('Contact Us Button Tap');
                            _openCrispChat();
                          },
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFfd5d32).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.contact_support,
                              color: Color(0xFFfd5d32),
                              size: 24,
                            ),
                          ),
                          title: const Text(
                            'Contact us',
                            style: TextStyle(
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
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
} 