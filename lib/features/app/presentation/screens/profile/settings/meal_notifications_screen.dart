import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/notifications/notification_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class MealNotificationsScreen extends StatefulWidget {
  const MealNotificationsScreen({super.key});

  @override
  State<MealNotificationsScreen> createState() => _MealNotificationsScreenState();
}

class _MealNotificationsScreenState extends State<MealNotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  
  // Breakfast removed
  // bool _isBreakfastEnabled = true;
  bool _isLunchEnabled = true;
  bool _isDinnerEnabled = true;
  
  // TimeOfDay? _breakfastTime; // removed
  TimeOfDay? _lunchTime;
  TimeOfDay? _dinnerTime;
  
  @override
  void initState() {
    super.initState();
    
    // Track page view
    MixpanelService.trackPageView('Meal Notifications Screen');
    
    _loadMealNotificationSettings();
    
    // Status bar for light theme
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }
  
  @override
  void dispose() {
    // Restore default status bar for light theme
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    super.dispose();
  }
  
  Future<void> _loadMealNotificationSettings() async {
    try {
      // Load enabled states
      // final breakfastEnabled = await _notificationService.isNotificationTypeEnabled(NotificationType.breakfastReminder);
      final lunchEnabled = await _notificationService.isNotificationTypeEnabled(NotificationType.lunchReminder);
      final dinnerEnabled = await _notificationService.isNotificationTypeEnabled(NotificationType.dinnerReminder);
      
      // Load times
      // final breakfastTime = await _notificationService.getMealReminderTime(NotificationType.breakfastReminder);
      final lunchTime = await _notificationService.getMealReminderTime(NotificationType.lunchReminder);
      final dinnerTime = await _notificationService.getMealReminderTime(NotificationType.dinnerReminder);
      
      if (mounted) {
        setState(() {
          // _isBreakfastEnabled = breakfastEnabled;
          _isLunchEnabled = lunchEnabled;
          _isDinnerEnabled = dinnerEnabled;
          // _breakfastTime = breakfastTime;
          _lunchTime = lunchTime;
          _dinnerTime = dinnerTime;
        });
      }
    } catch (e) {
      debugPrint('Error loading meal notification settings: $e');
    }
  }
  
  Future<void> _toggleMealNotification(NotificationType type, bool enabled) async {
    try {
      // Track toggle event
      String mealName;
      switch (type) {
        case NotificationType.breakfastReminder:
          return; // removed
        case NotificationType.lunchReminder:
          mealName = 'lunch';
          if (mounted) {
            setState(() {
              _isLunchEnabled = enabled;
            });
          }
          break;
        case NotificationType.dinnerReminder:
          mealName = 'dinner';
          if (mounted) {
            setState(() {
              _isDinnerEnabled = enabled;
            });
          }
          break;
        default:
          return;
      }
      
      MixpanelService.trackEvent(
        'Toggle Meal Notification', 
        properties: {'meal_type': mealName, 'enabled': enabled}
      );
      
      // Update notification service
      await _notificationService.setNotificationTypeEnabled(type, enabled);
    } catch (e) {
      debugPrint('Error toggling meal notification: $e');
    }
  }
  
  Future<void> _selectMealTime(NotificationType type) async {
    try {
      TimeOfDay? currentTime;
      switch (type) {
        case NotificationType.breakfastReminder:
          return; // removed
        case NotificationType.lunchReminder:
          currentTime = _lunchTime;
          break;
        case NotificationType.dinnerReminder:
          currentTime = _dinnerTime;
          break;
        default:
          return;
      }
      
      final TimeOfDay? newTime = await showTimePicker(
        context: context,
        initialTime: currentTime ?? const TimeOfDay(hour: 8, minute: 0),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: Theme.of(context).copyWith(
              dialogBackgroundColor: Colors.white,
              timePickerTheme: Theme.of(context).timePickerTheme.copyWith(
                backgroundColor: Colors.white,
                dialHandColor: const Color(0xFFed3272),
                hourMinuteColor: MaterialStateColor.resolveWith((states) {
                  return states.contains(MaterialState.selected)
                      ? const Color(0xFFfae6ec) // brand light pink when selected
                      : const Color(0xFFF2F2F7); // neutral chip when idle
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
      
      if (newTime != null && mounted) {
        setState(() {
          switch (type) {
            case NotificationType.breakfastReminder:
              return; // removed
            case NotificationType.lunchReminder:
              _lunchTime = newTime;
              break;
            case NotificationType.dinnerReminder:
              _dinnerTime = newTime;
              break;
            default:
              return;
          }
        });
        
        // Save the new time
        await _notificationService.setMealReminderTime(type, newTime);
        
        // Track time selection
        String mealName;
        switch (type) {
          case NotificationType.breakfastReminder:
            return; // removed
          case NotificationType.lunchReminder:
            mealName = 'lunch';
            break;
          case NotificationType.dinnerReminder:
            mealName = 'dinner';
            break;
          default:
            return;
        }
        
        MixpanelService.trackEvent(
          'Set Meal Notification Time', 
          properties: {
            'meal_type': mealName, 
            'hour': newTime.hour,
            'minute': newTime.minute,
          }
        );
      }
    } catch (e) {
      debugPrint('Error selecting meal time: $e');
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
            AppLocalizations.of(context)!.translate('meal_notifications_title'),
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
                // Description
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
                      Text(
                        AppLocalizations.of(context)!.translate('meal_notifications_description_title'),
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 18,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.translate('meal_notifications_description_text'),
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Meal reminder cards
                // Breakfast card removed
                _buildMealReminderCard(
                  title: AppLocalizations.of(context)!.translate('meal_lunch_title'),
                  description: AppLocalizations.of(context)!.translate('meal_lunch_description'),
                  icon: Icons.lunch_dining_outlined,
                  isEnabled: _isLunchEnabled,
                  time: _lunchTime,
                  onToggle: (enabled) => _toggleMealNotification(NotificationType.lunchReminder, enabled),
                  onTimeSelect: () => _selectMealTime(NotificationType.lunchReminder),
                ),
                
                const SizedBox(height: 16),
                _buildMealReminderCard(
                  title: AppLocalizations.of(context)!.translate('meal_dinner_title'),
                  description: AppLocalizations.of(context)!.translate('meal_dinner_description'),
                  icon: Icons.dinner_dining_outlined,
                  isEnabled: _isDinnerEnabled,
                  time: _dinnerTime,
                  onToggle: (enabled) => _toggleMealNotification(NotificationType.dinnerReminder, enabled),
                  onTimeSelect: () => _selectMealTime(NotificationType.dinnerReminder),
                ),
                
                const SizedBox(height: 30),
                
                // Tips section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            AppLocalizations.of(context)!.translate('meal_notifications_tips_title'),
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 18,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)!.translate('meal_notifications_tips_text'),
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 14,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Helper method to build meal reminder cards
  Widget _buildMealReminderCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isEnabled,
    required TimeOfDay? time,
    required void Function(bool) onToggle,
    required VoidCallback onTimeSelect,
  }) {
    return Container(
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
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: isEnabled 
                      ? const LinearGradient(
                          colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                        )
                      : null,
                  color: isEnabled ? null : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? Colors.white : const Color(0xFF999999),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isEnabled ? const Color(0xFF1A1A1A) : const Color(0xFF666666),
                        fontSize: 18,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: isEnabled ? const Color(0xFF666666) : const Color(0xFF999999),
                        fontSize: 14,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w400,
                      ),
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
          
          // Time selector (only show if enabled)
          if (isEnabled) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFBFBFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE0E0E0),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTimeSelect,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Color(0xFF666666),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              AppLocalizations.of(context)!.translate('meal_notification_time'),
                              style: const TextStyle(
                                color: Color(0xFF666666),
                                fontSize: 16,
                                fontFamily: 'ElzaRound',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              time != null 
                                  ? time.format(context)
                                  : '--:--',
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 18,
                                fontFamily: 'ElzaRound',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF666666),
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
