import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_profile_details.dart';
import '../../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../../core/chat/crisp_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'more_screen.dart';
import 'user_profile_notifications.dart';
import 'user_profile_support.dart';
import '../../../../../../core/navigation/page_transitions.dart';
import '../../../../../../core/localization/app_localizations.dart';
import 'language_selection_screen.dart';
import '../user_profile_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stoppr/features/community/presentation/screens/blocked_users_screen.dart';

class UserSettingsScreen extends StatefulWidget {
  const UserSettingsScreen({super.key});

  @override
  State<UserSettingsScreen> createState() => _UserSettingsScreenState();
}

class _UserSettingsScreenState extends State<UserSettingsScreen> {
  final CrispService _crispService = CrispService();
  String? _firstName;
  bool _isLoading = true;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    
    // Track page view
    MixpanelService.trackPageView('User Settings Screen');
    
    _loadUserData();
    _loadAppVersion();
    
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

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.version; // no +build
        });
      }
    } catch (e) {
      debugPrint('Error loading app version: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _firstName = prefs.getString('user_first_name');
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
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

  Future<void> _openCrispChat() async {
    try {
      // Get current user email if available
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email != null) {
        _crispService.setUserInformation(
          email: currentUser.email!,
          firstName: _firstName ?? 'You',
        );
      }
      
      // Open Crisp chat
      _crispService.openChat(context);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.translate('settings_crispErrorPrefix')} $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          title: Text(
            l10n.translate('settings_title'),
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
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              children: [
                // Profile option
                _buildSettingsOption(
                  icon: Icons.person,
                  iconColor: const Color(0xFFed3272),
                  title: l10n.translate('settings_profile'),
                  onTap: () {
                    Navigator.of(context).push(
                      BottomToTopPageRoute(
                        child: const UserProfileDetailsScreen(),
                        settings: const RouteSettings(name: '/profile_details'),
                      ),
                    );
                  },
                ),
                
                // Notifications option
                _buildSettingsOption(
                  icon: Icons.notifications,
                  iconColor: const Color(0xFFfd5d32),
                  title: l10n.translate('settings_notifications'),
                  onTap: () {
                    // Navigate to notifications settings
                    Navigator.of(context).push(
                      BottomToTopPageRoute(
                        child: const UserProfileNotificationsScreen(),
                        settings: const RouteSettings(name: '/notifications'),
                      ),
                    );
                  },
                ),
                
                // Support option
                _buildSettingsOption(
                  icon: Icons.help,
                  iconColor: const Color(0xFFed3272),
                  title: l10n.translate('settings_support'),
                  onTap: () {
                    // Track support tap event
                    MixpanelService.trackEvent('${l10n.translate('settings_support')} Button Tap');
                    // Navigate to support menu screen
                    Navigator.of(context).push(
                      BottomToTopPageRoute(
                        child: const UserProfileSupportScreen(),
                        settings: const RouteSettings(name: '/support'),
                      ),
                    );
                  },
                ),
                
                // Language option
                _buildSettingsOption(
                  icon: Icons.language,
                  iconColor: const Color(0xFFed3272),
                  title: l10n.translate('settings_language'),
                  onTap: () {
                    Navigator.of(context).push(
                      BottomToTopPageRoute(
                        child: const LanguageSelectionScreen(),
                        settings: const RouteSettings(name: '/language_settings'),
                      ),
                    );
                  },
                ),
                
                // Blocked Users option
                _buildSettingsOption(
                  icon: Icons.block,
                  iconColor: const Color(0xFFfd5d32),
                  title: l10n.translate('settings_blocked_users'),
                  onTap: () {
                    Navigator.of(context).push(
                      BottomToTopPageRoute(
                        child: const BlockedUsersScreen(),
                        settings: const RouteSettings(name: '/blocked_users'),
                      ),
                    );
                  },
                ),
                
                // Health option
                _buildSettingsOption(
                  icon: Icons.health_and_safety,
                  iconColor: const Color(0xFFfd5d32),
                  title: l10n.translate('profile_health_title'),
                  onTap: () {
                    Navigator.of(context).push(
                      BottomToTopPageRoute(
                        child: const HealthMenuScreen(),
                        settings: const RouteSettings(name: '/health_menu'),
                      ),
                    );
                  },
                ),
                
                // More option
                _buildSettingsOption(
                  icon: Icons.more_horiz,
                  iconColor: const Color(0xFF666666),
                  title: l10n.translate('settings_more'),
                  onTap: () {
                    // Navigate to more options
                    Navigator.of(context).push(
                      BottomToTopPageRoute(
                        child: const MoreScreen(),
                        settings: const RouteSettings(name: '/more'),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // App version (no build) displayed above brand label
                if (_appVersion.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Center(
                      child: Text(
                        l10n
                            .translate('profile_app_version')
                            .replaceAll('{version}', _appVersion),
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                          fontFamily: 'ElzaRound',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                // Brand label
                Center(
                  child: Text(
                    'STOPPR',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 14,
                      fontFamily: 'ElzaRound',
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
          // For other options, track event in the _buildSettingsOption method
          // Get l10n instance for comparison within this scope
          final l10nForComparison = AppLocalizations.of(context)!;
          if (title != l10nForComparison.translate('settings_support')) {
            MixpanelService.trackEvent('$title Button Tap');
          }
          onTap();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
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
} 