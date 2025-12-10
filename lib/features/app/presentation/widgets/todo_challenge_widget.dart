import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/notifications/notification_service.dart';
import '../screens/main_scaffold.dart';
import 'package:stoppr/features/app/presentation/screens/tree_of_life_screen.dart';
import '../screens/profile/settings/user_profile_notifications.dart';
import '../../../../core/navigation/page_transitions.dart';
import '../../../nutrition/presentation/screens/calorie_tracker_dashboard.dart';
import 'package:stoppr/app/theme/colors.dart';
import 'package:stoppr/features/accountability/presentation/screens/accountability_partner_screen.dart';

class TodoChallengeWidget extends StatefulWidget {
  const TodoChallengeWidget({super.key});

  @override
  State<TodoChallengeWidget> createState() => _TodoChallengeWidgetState();
}

class _TodoChallengeWidgetState extends State<TodoChallengeWidget> {
  bool _showWidget = false;
  List<bool> _completedItems = [false, false, false, false, false, false, false];
  
  @override
  void initState() {
    super.initState();
    _checkShouldShowWidget();
  }
  
  Future<void> _checkShouldShowWidget() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTodo = prefs.getBool('has_seen_todo_challenge') ?? false;
    final completedList = prefs.getStringList('todo_completed_items') ?? [];
    
    // Only show if user hasn't seen it before or has uncompleted items
    if (!hasSeenTodo || completedList.length < 7) {
      // Load completed items
      setState(() {
        _showWidget = true;
        for (int i = 0; i < 7; i++) {
          _completedItems[i] = completedList.contains(i.toString());
        }
      });
      
      // Mark as seen
      await prefs.setBool('has_seen_todo_challenge', true);
    }
  }
  
  Future<void> _markItemCompleted(int index) async {
    if (index < 0 || index >= _completedItems.length) return;
    
    setState(() {
      _completedItems[index] = true;
    });
    
    // Save to preferences with error handling
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = <String>[];
      for (int i = 0; i < _completedItems.length; i++) {
        if (_completedItems[i]) {
          completed.add(i.toString());
        }
      }
      await prefs.setStringList('todo_completed_items', completed);
    } catch (e) {
      debugPrint('Error saving todo completion state: $e');
      // Continue execution even if save fails - user experience shouldn't be interrupted
    }
    
    // Hide widget if all items are completed
    if (_completedItems.every((item) => item)) {
      setState(() {
        _showWidget = false;
      });
    }
    
    // Track completion
    final l10n = AppLocalizations.of(context)!;
    final itemNames = [
      l10n.translate('todoChallenge_enableNotifications'),
      l10n.translate('todoChallenge_scanFirstMeal'),
      l10n.translate('todoChallenge_findAccountabilityPartner'),
      l10n.translate('todoChallenge_joinCommunity'),
      l10n.translate('todoChallenge_helpAndLearn'),
      l10n.translate('todoChallenge_addHomeWidget'),
      l10n.translate('todoChallenge_plantYourTree'),
    ];
    MixpanelService.trackEvent('Todo Challenge: Item Completed', properties: {
      'item_name': itemNames[index],
      'item_index': index,
    });
  }
  
  Future<void> _onEnableNotificationsTap() async {
    MixpanelService.trackButtonTap('Todo Enable Notifications', screenName: 'Home Screen');
    
    // Navigate to notifications settings screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const UserProfileNotificationsScreen(),
      ),
    );
  }
  
  Future<void> _onScanFirstMealTap() async {
    MixpanelService.trackButtonTap('Todo Scan First Meal', screenName: 'Home Screen');
    
    // Navigate to calorie tracker dashboard
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CalorieTrackerDashboard(),
        settings: const RouteSettings(name: '/calorie_tracker_dashboard_from_todo'),
      ),
    );
  }
  
  Future<void> _onFindAccountabilityPartnerTap() async {
    MixpanelService.trackButtonTap('Todo Find Accountability Partner', screenName: 'Home Screen');
    
    // Navigate to accountability partner screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AccountabilityPartnerScreen(),
        settings: const RouteSettings(name: '/accountability_partner_from_todo'),
      ),
    );
  }
  
  Future<void> _onJoinCommunityTap() async {
    MixpanelService.trackButtonTap('Todo Join Community', screenName: 'Home Screen');
    
    final Uri url = Uri.parse('https://t.me/+SKqx1P0D3iljZGRh');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not open Telegram group: $e');
    }
  }
  
  void _onHelpAndLearnTap() {
    MixpanelService.trackButtonTap('Todo Help & Learn', screenName: 'Home Screen');
    
    Navigator.of(context).pushReplacement(
      FadePageRoute(
        child: const MainScaffold(initialIndex: 3),
        settings: const RouteSettings(name: '/home'),
      ),
    );
  }
  
  void _onAddHomeWidgetTap() {
    MixpanelService.trackButtonTap('Todo Add Home Widget', screenName: 'Home Screen');
    _showAddWidgetInstructions();
  }

  void _onPlantYourTreeTap() {
    MixpanelService.trackButtonTap('Todo Plant Your Tree', screenName: 'Home Screen');
    Navigator.of(context).push(
      BottomToTopPageRoute(
        child: const TreeOfLifeScreen(),
        settings: const RouteSettings(name: '/tree_of_life_from_todo'),
      ),
    );
  }
  
  void _showAddWidgetInstructions() {
    final l10n = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // White background for dialog
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            l10n.translate('homeScreen_addWidgetTitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1A1A1A), // Dark text for white dialog
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('homeScreen_addWidgetInstructions_intro'),
                                      style: const TextStyle(
                      color: Color(0xFF1A1A1A), // Dark text for white dialog
                      fontFamily: 'ElzaRound',
                      fontSize: 16,
                      height: 1.4,
                    ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.translate('homeScreen_addWidgetInstructions_note'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'ElzaRound',
                    fontSize: 14,
                    height: 1.3,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Show platform-specific instructions
                if (Platform.isIOS) ...[
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_step1'),
                    style: const TextStyle(
                      color: const Color(0xFF1A1A1A), // Dark text for white dialog
                      fontFamily: 'ElzaRound',
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_step2'),
                    style: const TextStyle(
                      color: const Color(0xFF1A1A1A), // Dark text for white dialog
                      fontFamily: 'ElzaRound',
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_step3'),
                    style: const TextStyle(
                      color: const Color(0xFF1A1A1A), // Dark text for white dialog
                      fontFamily: 'ElzaRound',
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_step4'),
                    style: const TextStyle(
                      color: const Color(0xFF1A1A1A), // Dark text for white dialog
                      fontFamily: 'ElzaRound',
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_step5'),
                    style: const TextStyle(
                      color: const Color(0xFF1A1A1A), // Dark text for white dialog
                      fontFamily: 'ElzaRound',
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_step6'),
                    style: const TextStyle(
                      color: const Color(0xFF1A1A1A), // Dark text for white dialog
                      fontFamily: 'ElzaRound',
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                ] else ...[
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_android_step1'),
                    style: const TextStyle(
                      color: const Color(0xFF1A1A1A), // Dark text for white dialog
                      fontFamily: 'ElzaRound',
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_android_step2'),
                    style: const TextStyle(
                      color: const Color(0xFF1A1A1A), // Dark text for white dialog
                      fontFamily: 'ElzaRound',
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_android_step3'),
                    style: const TextStyle(
                      color: const Color(0xFF1A1A1A), // Dark text for white dialog
                      fontFamily: 'ElzaRound',
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_android_step4'),
                    style: const TextStyle(
                      color: const Color(0xFF1A1A1A), // Dark text for white dialog
                      fontFamily: 'ElzaRound',
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('homeScreen_addWidgetInstructions_android_step5_resize'),
                    style: const TextStyle(
                      color: const Color(0xFF1A1A1A), // Dark text for white dialog
                      fontFamily: 'ElzaRound',
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5), // Light gray background for info box
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF666666), // Gray icon for light background
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            l10n.translate('homeScreen_addWidgetInstructions_android_tip_largeText'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'ElzaRound',
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                l10n.translate('common_close'),
                style: const TextStyle(
                  color: Color(0xFFed3272), // Brand pink for close button
                  fontFamily: 'ElzaRound',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_showWidget) return const SizedBox.shrink();
    
    final l10n = AppLocalizations.of(context)!;
    
    // Filter out completed items
    final visibleItems = <Widget>[];
    
    if (!_completedItems[0]) {
      visibleItems.add(_buildTodoItem(
        icon: Icons.notifications_outlined,
        title: l10n.translate('todoChallenge_enableNotifications'),
        subtitle: l10n.translate('todoChallenge_enableNotifications_subtitle'),
        onCircleTap: () => _markItemCompleted(0),
        onTextTap: _onEnableNotificationsTap,
      ));
    }
    
    if (!_completedItems[1]) {
      visibleItems.add(_buildTodoItem(
        icon: Icons.camera_alt_outlined,
        title: l10n.translate('todoChallenge_scanFirstMeal'),
        subtitle: l10n.translate('todoChallenge_scanFirstMeal_subtitle'),
        onCircleTap: () => _markItemCompleted(1),
        onTextTap: _onScanFirstMealTap,
      ));
    }
    
    if (!_completedItems[2]) {
      visibleItems.add(_buildTodoItem(
        icon: Icons.people_outline,
        title: l10n.translate('todoChallenge_findAccountabilityPartner'),
        subtitle: l10n.translate('todoChallenge_findAccountabilityPartner_subtitle'),
        onCircleTap: () => _markItemCompleted(2),
        onTextTap: _onFindAccountabilityPartnerTap,
      ));
    }
    
    if (!_completedItems[3]) {
      visibleItems.add(_buildTodoItem(
        icon: Icons.forum_outlined,
        title: l10n.translate('todoChallenge_joinCommunity'),
        subtitle: l10n.translate('todoChallenge_joinCommunity_subtitle'),
        onCircleTap: () => _markItemCompleted(3),
        onTextTap: _onJoinCommunityTap,
      ));
    }
    
    if (!_completedItems[4]) {
      visibleItems.add(_buildTodoItem(
        icon: Icons.help_outline,
        title: l10n.translate('todoChallenge_helpAndLearn'),
        subtitle: l10n.translate('todoChallenge_helpAndLearn_subtitle'),
        onCircleTap: () => _markItemCompleted(4),
        onTextTap: _onHelpAndLearnTap,
      ));
    }
    
    if (!_completedItems[5]) {
      visibleItems.add(_buildTodoItem(
        icon: Icons.widgets_outlined,
        title: l10n.translate('todoChallenge_addHomeWidget'),
        subtitle: l10n.translate('todoChallenge_addHomeWidget_subtitle'),
        onCircleTap: () => _markItemCompleted(5),
        onTextTap: _onAddHomeWidgetTap,
      ));
    }

    if (!_completedItems[6]) {
      visibleItems.add(_buildTodoItem(
        icon: Icons.eco_outlined,
        title: l10n.translate('todoChallenge_plantYourTree'),
        subtitle: l10n.translate('todoChallenge_plantYourTree_subtitle'),
        onCircleTap: () => _markItemCompleted(6),
        onTextTap: _onPlantYourTreeTap,
      ));
    }
    
    if (visibleItems.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE0E0E0), // Light gray border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFed3272).withOpacity(0.1), // Light brand pink background
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.checklist,
                  color: Color(0xFFed3272), // Brand pink icon
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.translate('todoChallenge_title'),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text for white background
                  fontSize: 18,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Build items with separators
          for (int i = 0; i < visibleItems.length; i++) ...[
            visibleItems[i],
            if (i < visibleItems.length - 1) ...[
              const SizedBox(height: 16),
              Container(
                height: 1,
                color: const Color(0xFFE0E0E0), // Light gray divider
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ],
      ),
    );
  }
  
  Widget _buildTodoItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onCircleTap,
    required VoidCallback onTextTap,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF666666), // Gray icon for white background
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onTextTap,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A), // Dark text for white background
                    fontSize: 16,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF666666), // Gray subtitle for white background
                    fontSize: 14,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onCircleTap,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF666666), // Gray border for white background
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
} 