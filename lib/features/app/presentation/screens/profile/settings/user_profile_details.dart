import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../../core/repositories/user_repository.dart';
import '../../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../../features/onboarding/presentation/screens/onboarding_page.dart';
import '../../../../../../features/onboarding/presentation/screens/welcome_video_screen.dart';
import '../../../../../../features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../../../../core/notifications/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../../core/auth/cubit/auth_cubit.dart';
import '../../../../../../core/auth/models/app_user.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../../core/localization/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../../../../../core/analytics/superwall_utils.dart';
import 'package:stoppr/core/quick_actions/quick_actions_service.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:stoppr/core/accountability/accountability_widget_service.dart';

// String extension for capitalization
extension StringExtension on String {
  String capitalizeFirst() {
    if (this.isEmpty) return this;
    return '${this[0].toUpperCase()}${this.substring(1)}';
  }
}

// Enum for account deletion reasons
enum DeletionReason {
  didntFindUseful,
  tooExpensive,
  difficultToUse,
  foundBetterApp,
  privacyConcerns,
  technicalIssues,
  other
}

class UserProfileDetailsScreen extends StatefulWidget {
  const UserProfileDetailsScreen({super.key});

  @override
  State<UserProfileDetailsScreen> createState() => _UserProfileDetailsScreenState();
}

class _UserProfileDetailsScreenState extends State<UserProfileDetailsScreen> {
  final UserRepository _userRepository = UserRepository();
  final OnboardingProgressService _progressService = OnboardingProgressService();
  final TextEditingController _deletionReasonController = TextEditingController();
  
  String _firstName = '';
  String _age = '';
  String _gender = '';
  String _email = '';
  
  bool _isLoading = true;
  bool _isTestFlightEnv = false;
  DeletionReason? _selectedDeletionReason;
  bool _showInfoBulle = false;
  
  @override
  void initState() {
    super.initState();
    
    // Ensure AuthCubit is available before proceeding
    try {
       context.read<AuthCubit>();
       print('AuthCubit successfully read in initState.');
    } catch (e) {
       print('Error reading AuthCubit in initState: $e. Ensure it is provided higher up the tree.');
       // Optionally handle error, e.g., show error message or prevent screen load
    }
    
    // Track page view
    MixpanelService.trackPageView('Profile Settings User Profile Details Screen');
    
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
    _deletionReasonController.dispose();
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
      // Try to get user data from SharedPreferences first
      final prefs = await SharedPreferences.getInstance();
      final savedFirstName = prefs.getString('user_first_name');
      final savedAge = prefs.getString('user_age');
      final savedGender = prefs.getString('user_gender');
      final savedEmail = prefs.getString('user_email');
      
      // Get current user from Firebase
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser != null) {
        // Try to get additional data from Firestore
        final userData = await _userRepository.getUserProfile(currentUser.uid);
        
        if (userData != null) {
          if (mounted) {
            setState(() {
              // Use data from Firestore if available, otherwise fall back to SharedPreferences
              _firstName = userData['firstName'] ?? savedFirstName ?? _firstName;
              _age = userData['age'] ?? savedAge ?? _age;
              _gender = userData['gender'] ?? savedGender ?? _gender;
              _email = userData['email'] ?? savedEmail ?? (currentUser.email ?? _email);
              _isLoading = false;
            });
          }
        } else {
          // Fall back to SharedPreferences if Firestore data not available
          if (mounted) {
            setState(() {
              if (savedFirstName != null) _firstName = savedFirstName;
              if (savedAge != null) _age = savedAge;
              if (savedGender != null) _gender = savedGender;
              _email = savedEmail ?? (currentUser.email ?? _email);
              _isLoading = false;
            });
          }
        }
      } else {
        // Fall back to SharedPreferences if user not logged in
        if (mounted) {
          setState(() {
            if (savedFirstName != null) _firstName = savedFirstName;
            if (savedAge != null) _age = savedAge;
            if (savedGender != null) _gender = savedGender;
            if (savedEmail != null) _email = savedEmail;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _updateUserProfile(String field, String value) async {
    print('UI State: _updateUserProfile started for field: $field, value: $value'); // Log entry
    try {
      // Always update SharedPreferences first to ensure data persistence
      print('UI State: Updating SharedPreferences...'); // Log before prefs
      final prefs = await SharedPreferences.getInstance();
      if (field == 'firstName') {
        await prefs.setString('user_first_name', value);
        // Update accountability widget with new name
        try {
          await AccountabilityWidgetService.instance.updateWidget();
        } catch (e) {
          debugPrint('Error updating accountability widget after name change: $e');
        }
      } else if (field == 'age') {
        await prefs.setString('user_age', value);
        // Refresh quick actions immediately when age changes
        QuickActionsService().refreshQuickActions();
      } else if (field == 'gender') {
        await prefs.setString('user_gender', value);
      } else if (field == 'email') {
        await prefs.setString('user_email', value);
      }
      print('UI State: SharedPreferences update complete.'); // Log after prefs
      
      // Try to update Firestore if user is available
      try {
        final authCubit = context.read<AuthCubit>();
        final AppUser? appUser = authCubit.getCurrentUser(); // Use the Cubit's getter

        if (appUser != null) {
          // Use appUser.uid
          print('UI State: AppUser from AuthCubit is NOT null (UID: ${appUser.uid}). Proceeding to call repository.');
          
          // Get device locale
          final String deviceLocale = Platform.localeName;
          
          switch (field) {
            case 'firstName':
              print('UI State: About to call _userRepository.updateUserProfile for firstName...'); // Log before await
              // Pass appUser.uid
              await _userRepository.updateUserProfile(
                appUser.uid, 
                firstName: value,
                locale: deviceLocale,
              );
              print('UI State: Call to _userRepository.updateUserProfile for firstName completed.'); // Log after await
              break;
            case 'age':
              print('UI State: About to call _userRepository.updateUserProfile for age...'); // Log before await
              // Pass appUser.uid
              await _userRepository.updateUserProfile(
                appUser.uid, 
                age: value,
                locale: deviceLocale,
              );
              // Ensure quick actions reflect updated audience
              QuickActionsService().refreshQuickActions();
              print('UI State: Call to _userRepository.updateUserProfile for age completed.'); // Log after await
              break;
            case 'gender':
              print('UI State: About to call _userRepository.updateUserProfile for gender...'); // Log before await
              // Pass appUser.uid
              await _userRepository.updateUserProfile(
                appUser.uid, 
                gender: value,
                locale: deviceLocale,
              );
              print('UI State: Call to _userRepository.updateUserProfile for gender completed.'); // Log after await
              break;
            case 'email':
              print('UI State: About to call _userRepository.updateUserProfile for email...'); // Log before await
              // Pass appUser.uid
              await _userRepository.updateUserProfile(
                appUser.uid, 
                email: value,
                locale: deviceLocale,
              );
              print('UI State: Call to _userRepository.updateUserProfile for email completed.'); // Log after await
              break;
            default:
              print('UI State: Unknown field in _updateUserProfile: $field');
              break;
          }
          
          // Set Superwall user attributes after profile update
          await SuperwallUtils.setUserAttributes(
            firstName: field == 'firstName' ? value : _firstName,
            age: field == 'age' ? value : _age,
            gender: field == 'gender' ? value : _gender,
            email: field == 'email' ? value : _email,
          );

          // Facebook Advanced Matching: update hashed user data when profile changes
          try {
            final facebookAppEvents = FacebookAppEvents();
            await facebookAppEvents.setUserData(
              email: field == 'email' ? value : _email,
              firstName: field == 'firstName' ? value : _firstName,
              gender: field == 'gender' ? value : _gender,
            );
            debugPrint('✅ Facebook setUserData called from profile edit');
          } catch (e) {
            debugPrint('❌ Facebook setUserData error (profile edit): $e');
          }
          
        } else {
          print('UI State: AppUser from AuthCubit IS NULL. Cannot update Firestore, but SharedPreferences was updated.'); // Log user null
        }
      } catch (authError) {
        print('UI State: Error accessing AuthCubit: $authError. SharedPreferences was still updated.');
      }
    } catch (e, s) { // Catch stack trace here too
      debugPrint('❌ Error in UI State _updateUserProfile: $e'); // More specific error log
      debugPrint('❌ UI State Stacktrace: $s'); // Print stack trace
    }
    print('UI State: _updateUserProfile finished for field: $field'); // Log exit
  }
  
  Future<void> _deleteAccount() async {
    MixpanelService.trackEvent('Profile Settings Delete Account Button Tap');
    _logForTestFlight('Delete account button tapped');
    try {
      _isTestFlightEnv = await MixpanelService.isTestFlight();
      _logForTestFlight('Delete account initiated in TestFlight: $_isTestFlightEnv');
    } catch (e) {
      _logForTestFlight('Error checking TestFlight status in _deleteAccount: $e');
    }
    // _showDeletionFeedbackDialog(); // <-- commented out
    _showDeletionConfirmationDialog(context); // call confirmation dialog directly
  }
  
  Future<void> _showDeletionConfirmationDialog(BuildContext parentContext) async {
    await showDialog<bool>(
      context: parentContext,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxWidth: 350),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient background
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFed3272),
                        Color(0xFFfd5d32),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_forever_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.translate('profileScreen_deleteDialog_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    AppLocalizations.of(context)!.translate('profileScreen_deleteDialog_message'),
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 16,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFed3272),
                                Color(0xFFfd5d32),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFed3272).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.translate('profileScreen_editDialog_cancel'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'ElzaRound',
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                          ),
                          child: TextButton(
                            onPressed: () async {
                              Navigator.of(dialogContext).pop();
                              final currentUser = FirebaseAuth.instance.currentUser;
                              if (currentUser != null) {
                                debugPrint('Attempting to delete user data from Firestore for uid: ${currentUser.uid}');
                                await _userRepository.deleteUserData(currentUser.uid);
                                debugPrint('Firestore deleteUserData call completed for uid: ${currentUser.uid}');
                                if (mounted) {
                                  debugPrint('Showing info bulle: We deleted your informations from the database');
                                  setState(() => _showInfoBulle = true);
                                  Future.delayed(const Duration(seconds: 3), () {
                                    if (mounted) setState(() => _showInfoBulle = false);
                                  });
                                }
                              } else {
                                if (kDebugMode) {
                                  debugPrint('kDebugMode: currentUser is null, showing info bulle for debug testing');
                                  if (mounted) {
                                    setState(() => _showInfoBulle = true);
                                    Future.delayed(const Duration(seconds: 3), () {
                                      if (mounted) setState(() => _showInfoBulle = false);
                                    });
                                  }
                                }
                              }
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.translate('profileScreen_deleteDialog_confirm'),
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 14,
                                fontFamily: 'ElzaRound',
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            AppLocalizations.of(context)!.translate('profileScreen_title'),
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
        body: Stack(
          children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Column(
                        children: [
                          // Profile photo
                          Center(
                            child: Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.psychology_outlined,
                                      color: Color(0xFFed3272),
                                      size: 60,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          
                          // Profile fields
                          _buildProfileInfoOption(
                            title: AppLocalizations.of(context)!.translate('profileScreen_firstName'),
                            value: _firstName,
                            icon: Icons.person,
                            onTap: () async {
                              final newValue = await _showEditDialog(
                                AppLocalizations.of(context)!.translate('profileScreen_firstName'), 
                                _firstName
                              );
                              print('Profile Edit Dialog returned: "$newValue"');
                              if (newValue != null && newValue != _firstName) {
                                print('Condition met: New value "$newValue" is not null and different from old "$_firstName". Calling _updateUserProfile...');
                                await _updateUserProfile('firstName', newValue);
                                if (mounted) {
                                  setState(() {
                                    _firstName = newValue;
                                  });
                                }
                              }
                            },
                          ),
                          
                          _buildProfileInfoOption(
                            title: AppLocalizations.of(context)!.translate('profileScreen_age'),
                            value: _age,
                            icon: Icons.calendar_month,
                            onTap: () async {
                              final newValue = await _showEditDialog(
                                AppLocalizations.of(context)!.translate('profileScreen_age'), 
                                _age
                              );
                              if (newValue != null && newValue != _age) {
                                await _updateUserProfile('age', newValue);
                                if (mounted) {
                                  setState(() {
                                    _age = newValue;
                                  });
                                }
                              }
                            },
                          ),
                          
                          _buildProfileInfoOption(
                            title: AppLocalizations.of(context)!.translate('profileScreen_gender'),
                            value: _gender,
                            icon: Icons.transgender,
                            onTap: () async {
                              final newValue = await _showSelectionDialog(
                                AppLocalizations.of(context)!.translate('profileScreen_gender'),
                                [
                                  AppLocalizations.of(context)!.translate('profileScreen_genderOptions_male'),
                                  AppLocalizations.of(context)!.translate('profileScreen_genderOptions_female'),
                                  AppLocalizations.of(context)!.translate('profileScreen_genderOptions_preferNotToSay')
                                ],
                                _gender,
                              );
                              if (newValue != null && newValue != _gender) {
                                await _updateUserProfile('gender', newValue);
                                if (mounted) {
                                  setState(() {
                                    _gender = newValue;
                                  });
                                }
                              }
                            },
                          ),
                          
                          _buildProfileInfoOption(
                            title: AppLocalizations.of(context)!.translate('profileScreen_email'),
                            value: _email,
                            icon: Icons.email,
                            onTap: () async {
                              final newValue = await _showEditDialog(
                                AppLocalizations.of(context)!.translate('profileScreen_email'), 
                                _email, 
                                hintText: AppLocalizations.of(context)!.translate('profileScreen_editDialog_emailHint')
                              );
                              if (newValue != null && newValue != _email) {
                                await _updateUserProfile('email', newValue);
                                if (mounted) {
                                  setState(() {
                                    _email = newValue;
                                  });
                                }
                              }
                            },
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Cancel subscription button
                          Container(
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
                              onTap: () async {
                                MixpanelService.trackButtonTap('Cancel Subscription', screenName: 'User Profile Details Screen');
                                await RevenueCatUI.presentCustomerCenter();
                              },
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                              title: Text(
                                AppLocalizations.of(context)!.translate('profileScreen_customerCenter'),
                                style: const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 17,
                                  fontFamily: 'ElzaRound',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF666666),
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Log out button
                          Container(
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
                              onTap: () async {
                                _showLogoutConfirmation();
                              },
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                              title: Text(
                                AppLocalizations.of(context)!.translate('profileScreen_logOut'),
                                style: const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 17,
                                  fontFamily: 'ElzaRound',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF666666),
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Delete profile button
                          Container(
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
                              onTap: _deleteAccount,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                              title: Text(
                                AppLocalizations.of(context)!.translate('profileScreen_deleteProfile'),
                                style: const TextStyle(
                                  color: Color(0xFFFF3B30),
                                  fontSize: 17,
                                  fontFamily: 'ElzaRound',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF666666),
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            if (_showInfoBulle)
              Positioned(
                top: 60,
                left: MediaQuery.of(context).size.width * 0.05,
                child: Material(
                  color: Colors.transparent,
                  child: AnimatedOpacity(
                    opacity: _showInfoBulle ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '✅ ' + (l10n?.translate('profile_info_bulle_deleted') ?? 'We deleted your informations from the database'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileInfoOption({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () {
                MixpanelService.trackEvent('Profile Settings Edit $title Button Tap');
                onTap();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value.isEmpty ? 'Tap to add $title' : value,
                        style: TextStyle(
                          color: value.isEmpty ? const Color(0xFF666666) : const Color(0xFF1A1A1A),
                          fontSize: 17,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF666666),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<String?> _showEditDialog(String field, String currentValue, {String? hintText}) async {
    final TextEditingController controller = TextEditingController(text: currentValue);
    
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxWidth: 350),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient background
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFed3272),
                        Color(0xFFfd5d32),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.translate('profileScreen_editDialog_title').replaceFirst('{field}', field),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 18,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: hintText ?? AppLocalizations.of(context)!.translate('profileScreen_editDialog_hint').replaceFirst('{field}', field.toLowerCase()),
                      hintStyle: const TextStyle(
                        color: Color(0xFF999999),
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w400,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFDF8FA),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFed3272),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF8FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                          ),
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.translate('profileScreen_editDialog_cancel'),
                              style: const TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 16,
                                fontFamily: 'ElzaRound',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFed3272),
                                Color(0xFFfd5d32),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFed3272).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(controller.text),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.translate('profileScreen_editDialog_save'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
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
              ],
            ),
          ),
        );
      },
    );
  }
  
  Future<String?> _showSelectionDialog(
    String field,
    List<String> options,
    String currentValue,
  ) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxWidth: 350),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient background
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFed3272),
                        Color(0xFFfd5d32),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.list_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.translate('profileScreen_selectDialog_title').replaceFirst('{field}', field),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Options
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options[index];
                      final isSelected = option == currentValue;
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFfae6ec)
                              : const Color(0xFFFDF8FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFed3272)
                                : const Color(0xFFE0E0E0),
                            width: 1.5,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          title: Text(
                            option,
                            style: TextStyle(
                              color: isSelected ? const Color(0xFFed3272) : const Color(0xFF1A1A1A),
                              fontSize: 16,
                              fontFamily: 'ElzaRound',
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          trailing: isSelected
                              ? Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(option),
                        ),
                      );
                    },
                  ),
                ),
                // Cancel button
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.translate('profileScreen_editDialog_cancel'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w500,
                        ),
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
  
  // Show log out confirmation dialog
  Future<void> _showLogoutConfirmation() async {
    debugPrint('Showing logout confirmation dialog');
    
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxWidth: 350),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient background
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFed3272),
                        Color(0xFFfd5d32),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.translate('profileScreen_logoutDialog_title'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    AppLocalizations.of(context)!.translate('profileScreen_logoutDialog_message'),
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 16,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFed3272),
                                Color(0xFFfd5d32),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFed3272).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextButton(
                            onPressed: () {
                              debugPrint('Cancel button tapped');
                              Navigator.of(dialogContext).pop();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.translate('profileScreen_editDialog_cancel'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'ElzaRound',
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                          ),
                          child: TextButton(
                            onPressed: () async {
                              debugPrint('Log out button in dialog tapped');
                              Navigator.of(dialogContext).pop();
                              _performLogout();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 24,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.translate('profileScreen_logOut'),
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 16,
                                fontFamily: 'ElzaRound',
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
      },
    );
  }
  
  Future<void> _performLogout() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Clear SharedPreferences first and foremost
      final prefs = await SharedPreferences.getInstance();
      
      // Save important settings before clearing
      final notificationsEnabled = prefs.getBool('notifications_enabled_key');
      final themeMode = prefs.getString('theme_mode');
      final appTrackingEnabled = prefs.getBool('app_tracking_enabled');
      
      // SOFT LOGOUT: Save critical IDs before clearing
      final originalAppUserId = prefs.getString('original_app_user_id');
      final firestoreUserId = prefs.getString('firestore_user_id');
      debugPrint('🔑 Preserving IDs for soft logout - originalAppUserId: $originalAppUserId, firestoreUserId: $firestoreUserId');
      
      // Clear all preferences
      await prefs.clear();
      
      // Restore important settings after clearing
      if (notificationsEnabled != null) {
        await prefs.setBool('notifications_enabled_key', notificationsEnabled);
      }
      
      if (themeMode != null) {
        await prefs.setString('theme_mode', themeMode);
      }
      
      if (appTrackingEnabled != null) {
        await prefs.setBool('app_tracking_enabled', appTrackingEnabled);
      }
      
      // SOFT LOGOUT: Restore critical IDs after clearing
      if (originalAppUserId != null) {
        await prefs.setString('original_app_user_id', originalAppUserId);
        debugPrint('✅ Restored originalAppUserId: $originalAppUserId');
      }
      
      if (firestoreUserId != null) {
        await prefs.setString('firestore_user_id', firestoreUserId);
        debugPrint('✅ Restored firestoreUserId: $firestoreUserId');
      }
      
      debugPrint('Cleared all user preferences while preserving app settings and critical IDs');
      
      final FirebaseAuth auth = FirebaseAuth.instance;
      final User? user = auth.currentUser;
      
      if (user != null) {
        // Check provider ID to determine sign-in method
        final List<UserInfo> providerData = user.providerData;
        String authProvider = "unknown";
        
        if (providerData.isNotEmpty) {
          final providerId = providerData[0].providerId;
          debugPrint('Signing out user with provider: $providerId');
          
          if (providerId.contains('google')) {
            authProvider = "Google";
          } else if (providerId.contains('apple')) {
            authProvider = "Apple";
          } else if (providerId.contains('password')) {
            authProvider = "Email";
          }
        }
        
        debugPrint('Signing out $authProvider user');
      }
      
      // Clear all onboarding progress
      await _progressService.clearOnboardingProgress();
      debugPrint('Cleared onboarding progress during logout');
      
      // Sign out from Firebase
      await auth.signOut();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Track logout navigation start
        MixpanelService.trackEvent('Profile Settings Logout Confirmed', properties: {
          'timestamp': DateTime.now().toIso8601String(),
        });
        
        // Navigate directly to WelcomeVideoScreen which will then go to OnboardingPage
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute( // Use MaterialPageRoute here too for consistency
            builder: (context) => WelcomeVideoScreen(
              nextScreen: const OnboardingPage(),
            ),
          ),
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.translate('errorMessage_signOut').replaceFirst('{error}', e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Helper function for logging that will be visible in TestFlight
  void _logForTestFlight(String message, {Map<String, dynamic>? extraData}) {
    // Always do regular debug logging for development
    debugPrint(message);
    
    // Create basic log data
    final logData = {
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
      'screen': 'UserProfileDetails',
      'action': 'AccountDeletion',
      ...?extraData,
    };
    
    // Log to Mixpanel - these logs will be visible in TestFlight
    MixpanelService.trackEvent('Profile Settings TestFlight Debug', properties: logData);
  }
} 