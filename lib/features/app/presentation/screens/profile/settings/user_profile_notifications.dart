import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/notifications/notification_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'meal_notifications_screen.dart';

class UserProfileNotificationsScreen extends StatefulWidget {
  const UserProfileNotificationsScreen({super.key});

  @override
  State<UserProfileNotificationsScreen> createState() => _UserProfileNotificationsScreenState();
}

class _UserProfileNotificationsScreenState extends State<UserProfileNotificationsScreen> with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();
  bool _isNotificationsEnabled = true;
  bool _isCheckupRemindersEnabled = true;
  bool _isStreakGoalsEnabled = true;
  bool _isMorningMotivationEnabled = true;
  bool _isAppUpdateEnabled = true;
  bool _isChatNotificationsEnabled = false;
  bool _isTimeSensitiveEnabled = true;
  bool _isMealCalorieTrackingEnabled = true;
  bool _areSystemNotificationsEnabled = true;
  
  // Configurable times
  TimeOfDay? _motivationTime; // morning motivation
  TimeOfDay? _pledgeTime; // checkup/pledge
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Track page view
    MixpanelService.trackPageView('User Profile Notifications Screen');
    
    _loadNotificationSettings();
    _checkSystemNotifications();
    
    // Force status bar icons to dark mode for white background
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
  
  Future<void> _checkSystemNotifications() async {
    final systemNotificationsEnabled = await _notificationService.areSystemNotificationsEnabled();
    
    if (mounted) {
      setState(() {
        _areSystemNotificationsEnabled = systemNotificationsEnabled;
      });
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Restore default status bar for light theme
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSystemNotifications();
      // If user turned notifications on in Settings and our toggle is on,
      // ensure schedules are updated.
      if (_isNotificationsEnabled && _areSystemNotificationsEnabled) {
        _notificationService.updateAllNotifications();
      }
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _showOpenSettingsDialog() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('notifications_enable_all'),
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 20,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.translate('notifications_system_disabled_warning'),
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 16,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(
                          l10n.translate('common_cancel'),
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await openAppSettings();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                        child: Ink(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(
                              l10n.translate('permissions_openSettings'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
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

  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final systemNotificationsEnabled = await _notificationService.areSystemNotificationsEnabled();
      
      // Load main notification toggle state
      final savedNotificationsEnabled = prefs.getBool(NotificationService.notificationsEnabledKey) ?? true;
      
      // If system notifications are disabled, disable in-app notifications too
      final isNotificationsEnabled = systemNotificationsEnabled && savedNotificationsEnabled;
      
      // Load individual notification type states
      final isCheckupRemindersEnabled = prefs.getBool(NotificationService.checkupRemindersEnabledKey) ?? true;
      final isStreakGoalsEnabled = prefs.getBool(NotificationService.streakGoalsEnabledKey) ?? true;
      final isMorningMotivationEnabled = prefs.getBool(NotificationService.morningMotivationEnabledKey) ?? true;
      final isAppUpdateEnabled = prefs.getBool(NotificationService.appUpdateEnabledKey) ?? true;
      final isChatNotificationsEnabled = prefs.getBool(NotificationService.chatNotificationsEnabledKey) ?? false;
      final isMealCalorieTrackingEnabled = prefs.getBool(NotificationService.mealCalorieTrackingEnabledKey) ?? true;
      
      // Load configurable times
      final motivationTime = await _notificationService.getMotivationReminderTime();
      final pledgeTime = await _notificationService.getPledgeReminderTime();
      
      if (mounted) {
        setState(() {
          _isNotificationsEnabled = isNotificationsEnabled;
          _isCheckupRemindersEnabled = isCheckupRemindersEnabled;
          _isStreakGoalsEnabled = isStreakGoalsEnabled;
          _isMorningMotivationEnabled = isMorningMotivationEnabled;
          _isAppUpdateEnabled = isAppUpdateEnabled;
          _isChatNotificationsEnabled = isChatNotificationsEnabled;
          _isMealCalorieTrackingEnabled = isMealCalorieTrackingEnabled;
          _areSystemNotificationsEnabled = systemNotificationsEnabled;
          _motivationTime = motivationTime;
          _pledgeTime = pledgeTime;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    }
  }

  /// Register FCM token to Firestore after permissions are granted
  Future<void> _registerFCMToken() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get FCM token (should work now that permissions are granted)
      final fcmToken = await FirebaseMessaging.instance.getToken();
      
      if (fcmToken != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
          'fcmToken': fcmToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('✅ FCM token saved to Firestore from settings: ${fcmToken.substring(0, 20)}...');
      } else {
        debugPrint('⚠️  FCM token is still null after requesting permissions');
      }
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    try {
      // Track toggle event
      MixpanelService.trackEvent(
        'Toggle Notifications', 
        properties: {'enabled': value}
      );
      
      if (value) {
        // If user is enabling notifications, request all permissions first
        final permissionsGranted = await _notificationService.requestAllNotificationPermissions(context: 'settings');
        
        // Check if system permissions are granted after the request
        final systemEnabled = await _notificationService.areSystemNotificationsEnabled();
        
        if (mounted) {
          setState(() {
            _areSystemNotificationsEnabled = systemEnabled;
          });
        }
        
        // Only proceed if system permissions are granted
        if (systemEnabled) {
          // Register FCM token for accountability push notifications
          await _registerFCMToken();
          
          // Save to preferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(NotificationService.notificationsEnabledKey, value);
          
          if (mounted) {
            setState(() {
              _isNotificationsEnabled = value;
            });
          }
          
          // Update all notifications
          await _notificationService.updateAllNotifications();
        } else {
          // If permissions were denied, keep toggle disabled
          await _showOpenSettingsDialog();
          if (mounted) {
            setState(() {
              _isNotificationsEnabled = false;
            });
          }
        }
      } else {
        // User is disabling notifications
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(NotificationService.notificationsEnabledKey, value);
        
        if (mounted) {
          setState(() {
            _isNotificationsEnabled = value;
          });
        }
        
        // Cancel all scheduled notifications
        await _notificationService.cancelAllNotifications();
      }
    } catch (e) {
      debugPrint('Error toggling notifications: $e');
    }
  }
  
  Future<void> _selectConfigurableTime(NotificationType type) async {
    try {
      TimeOfDay? current;
      switch (type) {
        case NotificationType.morningMotivation:
          current = _motivationTime;
          break;
        case NotificationType.checkupReminders:
          current = _pledgeTime;
          break;
        default:
          return;
      }
      final TimeOfDay? newTime = await showTimePicker(
        context: context,
        initialTime: current ?? const TimeOfDay(hour: 8, minute: 42),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              dialogBackgroundColor: Colors.white,
              timePickerTheme: Theme.of(context).timePickerTheme.copyWith(
                backgroundColor: Colors.white,
                dialHandColor: const Color(0xFFed3272),
                hourMinuteColor: MaterialStateColor.resolveWith((states) {
                  return states.contains(MaterialState.selected)
                      ? const Color(0xFFfae6ec)
                      : const Color(0xFFF2F2F7);
                }),
                hourMinuteTextColor: MaterialStateColor.resolveWith((states) {
                  return const Color(0xFF1A1A1A);
                }),
                dayPeriodColor: MaterialStateColor.resolveWith((states) {
                  return states.contains(MaterialState.selected)
                      ? const Color(0xFFfae6ec)
                      : const Color(0xFFF2F2F7);
                }),
                dayPeriodTextColor: MaterialStateColor.resolveWith((states) {
                  return const Color(0xFF1A1A1A);
                }),
              ),
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFFed3272),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: const Color(0xFF1A1A1A),
              ),
            ),
            child: child!,
          );
        },
      );
      if (newTime == null) return;
      if (!mounted) return;
      setState(() {
        if (type == NotificationType.morningMotivation) {
          _motivationTime = newTime;
        } else if (type == NotificationType.checkupReminders) {
          _pledgeTime = newTime;
        }
      });
      if (type == NotificationType.morningMotivation) {
        await _notificationService.setMotivationReminderTime(newTime);
        MixpanelService.trackEvent('Set Motivation Notification Time', properties: {
          'hour': newTime.hour,
          'minute': newTime.minute,
        });
      } else {
        await _notificationService.setPledgeReminderTime(newTime);
        MixpanelService.trackEvent('Set Pledge Notification Time', properties: {
          'hour': newTime.hour,
          'minute': newTime.minute,
        });
      }
    } catch (e) {
      debugPrint('Error selecting configurable time: $e');
    }
  }

  Future<void> _toggleNotificationType(NotificationType type, bool value) async {
    try {
      String typeName;
      
      // Determine which type we're toggling
      switch (type) {
        case NotificationType.checkupReminders:
          typeName = 'Checkup Reminders';
          setState(() => _isCheckupRemindersEnabled = value);
          break;
        case NotificationType.streakGoals:
          typeName = 'Streak Goals';
          setState(() => _isStreakGoalsEnabled = value);
          break;
        case NotificationType.morningMotivation:
          typeName = 'Morning Motivation';
          setState(() => _isMorningMotivationEnabled = value);
          break;
        case NotificationType.appUpdate:
          typeName = 'App Updates';
          setState(() => _isAppUpdateEnabled = value);
          break;
        case NotificationType.chatNotifications:
          typeName = 'Chat Notifications';
          setState(() => _isChatNotificationsEnabled = value);
          break;
        case NotificationType.marketingOffers:
          typeName = 'Marketing Offers';
          // Note: Marketing offers don't have a UI toggle in settings
          break;
        case NotificationType.trialOffer:
          typeName = 'Trial Offers';
          // Note: Trial offers don't have a UI toggle in settings
          break;
        case NotificationType.timeSensitive:
          typeName = 'Time-Sensitive Reminders';
          setState(() => _isTimeSensitiveEnabled = value);
          break;
        case NotificationType.mealCalorieTracking:
          typeName = 'Meal Calorie Tracking';
          setState(() => _isMealCalorieTrackingEnabled = value);
          break;
        case NotificationType.breakfastReminder:
          typeName = 'Breakfast Reminder';
          // Note: Breakfast reminders are handled in the meal notifications page
          break;
        case NotificationType.lunchReminder:
          typeName = 'Lunch Reminder';
          // Note: Lunch reminders are handled in the meal notifications page
          break;
        case NotificationType.dinnerReminder:
          typeName = 'Dinner Reminder';
          // Note: Dinner reminders are handled in the meal notifications page
          break;
        case NotificationType.relapseChallengeDaily:
          typeName = 'Relapse Challenge Daily';
          // No direct toggle in UI; controlled by flow
          break;
      }
      
      // Track toggle event
      MixpanelService.trackEvent(
        'Toggle Notification Type', 
        properties: {'type': typeName, 'enabled': value}
      );
      
      // Update notification service
      await _notificationService.setNotificationTypeEnabled(type, value);
      
    } catch (e) {
      debugPrint('Error toggling notification type: $e');
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
        backgroundColor: const Color(0xFFFBFBFB), // Neutral white background
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            AppLocalizations.of(context)!.translate('notifications_title'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 28,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: false,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main toggle for all notifications in a card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.translate('notifications_enable_all'),
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 18,
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Switch(
                        value: _isNotificationsEnabled,
                        onChanged: _toggleNotifications,
                        activeColor: const Color(0xFFed3272),
                        activeTrackColor: const Color(0xFFed3272).withOpacity(0.3),
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.grey.withOpacity(0.3),
                      ),
                    ],
                  ),
                ),
                
                // System notification permission warning
                if (_isNotificationsEnabled && !_areSystemNotificationsEnabled)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(context)!.translate('notifications_system_disabled_warning'),
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 14,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () async {
                            await openAppSettings();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            backgroundColor: Colors.transparent,
                          ),
                          child: Ink(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                              ),
                              borderRadius: BorderRadius.all(Radius.circular(20)),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text(
                                AppLocalizations.of(context)!.translate('permissions_openSettings'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
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
                
                const SizedBox(height: 30),
                
                // Meal Notifications Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.translate('notifications_meal_reminders_title'),
                                  style: TextStyle(
                                    color: _isNotificationsEnabled ? const Color(0xFF1A1A1A) : const Color(0xFF666666),
                                    fontSize: 18,
                                    fontFamily: 'ElzaRound',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLocalizations.of(context)!.translate('notifications_meal_reminders_description'),
                                  style: TextStyle(
                                    color: _isNotificationsEnabled ? const Color(0xFF666666) : const Color(0xFF999999),
                                    fontSize: 14,
                                    fontFamily: 'ElzaRound',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: _isNotificationsEnabled 
                                  ? const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                                    )
                                  : null,
                              color: _isNotificationsEnabled ? null : const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(25),
                                onTap: _isNotificationsEnabled ? () {
                                  // Navigate to meal notifications page
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const MealNotificationsScreen(),
                                    ),
                                  );
                                } : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)!.translate('configure'),
                                        style: TextStyle(
                                          color: _isNotificationsEnabled ? Colors.white : const Color(0xFF999999),
                                          fontSize: 14,
                                          fontFamily: 'ElzaRound',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 12,
                                        color: _isNotificationsEnabled ? Colors.white : const Color(0xFF999999),
                                      ),
                                    ],
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
                
                const SizedBox(height: 20),
                
                // Other Notifications Section
                Text(
                  AppLocalizations.of(context)!.translate('notifications_other_title'),
                  style: TextStyle(
                    color: _isNotificationsEnabled ? const Color(0xFF1A1A1A) : const Color(0xFF666666),
                    fontSize: 20,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Notification types in individual cards
                _buildNotificationCard(
                  title: AppLocalizations.of(context)!.translate('notifications_checkup_reminders_title'),
                  description: AppLocalizations.of(context)!.translate('notifications_checkup_reminders_description'),
                  isEnabled: _isCheckupRemindersEnabled,
                  onToggle: _isNotificationsEnabled 
                      ? (value) => _toggleNotificationType(NotificationType.checkupReminders, value)
                      : null,
                ),
                if (_isNotificationsEnabled && _isCheckupRemindersEnabled)
                  const SizedBox(height: 8),
                if (_isNotificationsEnabled && _isCheckupRemindersEnabled)
                  _buildTimeRow(
                    label: AppLocalizations.of(context)!.translate('meal_notification_time'),
                    time: _pledgeTime,
                    onTap: () => _selectConfigurableTime(NotificationType.checkupReminders),
                  ),
                
                
                const SizedBox(height: 12),
                _buildNotificationCard(
                  title: AppLocalizations.of(context)!.translate('notifications_streak_goals_title'),
                  description: AppLocalizations.of(context)!.translate('notifications_streak_goals_description'),
                  isEnabled: _isStreakGoalsEnabled,
                  onToggle: _isNotificationsEnabled 
                      ? (value) => _toggleNotificationType(NotificationType.streakGoals, value)
                      : null,
                ),
                
                const SizedBox(height: 12),
                _buildNotificationCard(
                  title: AppLocalizations.of(context)!.translate('notifications_morning_motivation_title'),
                  description: AppLocalizations.of(context)!.translate('notifications_morning_motivation_description'),
                  isEnabled: _isMorningMotivationEnabled,
                  onToggle: _isNotificationsEnabled 
                      ? (value) => _toggleNotificationType(NotificationType.morningMotivation, value)
                      : null,
                ),
                if (_isNotificationsEnabled && _isMorningMotivationEnabled)
                  const SizedBox(height: 8),
                if (_isNotificationsEnabled && _isMorningMotivationEnabled)
                  _buildTimeRow(
                    label: AppLocalizations.of(context)!.translate('meal_notification_time'),
                    time: _motivationTime,
                    onTap: () => _selectConfigurableTime(NotificationType.morningMotivation),
                  ),
                
                const SizedBox(height: 12),
                _buildNotificationCard(
                  title: AppLocalizations.of(context)!.translate('notifications_app_updates_title'),
                  description: AppLocalizations.of(context)!.translate('notifications_app_updates_description'),
                  isEnabled: _isAppUpdateEnabled,
                  onToggle: _isNotificationsEnabled 
                      ? (value) => _toggleNotificationType(NotificationType.appUpdate, value)
                      : null,
                ),
                
                const SizedBox(height: 12),
                _buildNotificationCard(
                  title: AppLocalizations.of(context)!.translate('notifications_meal_calorie_tracking_title'),
                  description: AppLocalizations.of(context)!.translate('notifications_meal_calorie_tracking_description'),
                  isEnabled: _isMealCalorieTrackingEnabled,
                  onToggle: _isNotificationsEnabled 
                      ? (value) => _toggleNotificationType(NotificationType.mealCalorieTracking, value)
                      : null,
                ),
                
                const SizedBox(height: 12),
                _buildNotificationCard(
                  title: AppLocalizations.of(context)!.translate('notifications_chat_title'),
                  description: AppLocalizations.of(context)!.translate('notifications_chat_description'),
                  isEnabled: _isChatNotificationsEnabled,
                  onToggle: _isNotificationsEnabled 
                      ? (value) => _toggleNotificationType(NotificationType.chatNotifications, value)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Helper method to build notification toggle cards
  Widget _buildNotificationCard({
    required String title,
    required String description,
    required bool isEnabled,
    required void Function(bool)? onToggle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _isNotificationsEnabled ? const Color(0xFF1A1A1A) : const Color(0xFF666666),
                    fontSize: 16,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: _isNotificationsEnabled ? const Color(0xFF666666) : const Color(0xFF999999),
                    fontSize: 14,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch(
            value: isEnabled,
            onChanged: onToggle,
            activeColor: const Color(0xFFed3272),
            activeTrackColor: const Color(0xFFed3272).withOpacity(0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.grey.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Color(0xFF666666), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 15,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      time != null ? time.format(context) : '--:--',
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 17,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: Color(0xFF666666), size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 