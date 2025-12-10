import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../screens/home_rewire_brain.dart';
import '../../../../core/streak/streak_service.dart';
import 'dart:async';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import '../screens/main_scaffold.dart';
import '../../../../core/localization/app_localizations.dart';
import 'package:stoppr/app/theme/colors.dart';

class GoalDateWidget extends StatefulWidget {
  const GoalDateWidget({super.key});

  @override
  State<GoalDateWidget> createState() => _GoalDateWidgetState();
}

class _GoalDateWidgetState extends State<GoalDateWidget> {
  DateTime? _goalDate;
  bool _isTempted = false;
  final StreakService _streakService = StreakService();
  StreamSubscription? _streakSubscription;
  
  @override
  void initState() {
    super.initState();
    _loadGoalDate();
    
    // Listen to streak updates to recalculate goal date
    _streakSubscription = _streakService.streakStream.listen((_) {
      if (mounted) {
        _calculateGoalDate();
      }
    });
  }
  
  @override
  void dispose() {
    // Cancel the stream subscription to prevent memory leaks
    _streakSubscription?.cancel();
    super.dispose();
  }
  
  Future<void> _loadGoalDate() async {
    await _calculateGoalDate();
    
    // Load temptation state (could be from a different key)
    final prefs = await SharedPreferences.getInstance();
    final isTempted = prefs.getBool('is_tempted') ?? false;
    if (mounted) {
      setState(() {
        _isTempted = isTempted;
      });
    }
  }
  
  Future<void> _calculateGoalDate() async {
    final streakData = _streakService.currentStreak;
    
    if (streakData.startTime != null) {
      // Calculate goal date as 90 days from streak start
      final calculatedGoalDate = streakData.startTime!.add(const Duration(days: 90));
      
      // Update the stored target quit timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('target_quit_timestamp', calculatedGoalDate.millisecondsSinceEpoch);
      
      if (mounted) {
        setState(() {
          _goalDate = calculatedGoalDate;
        });
      }
    } else {
      // Fallback to reading from shared preferences if streak start time is somehow not available
      final prefs = await SharedPreferences.getInstance();
      final targetQuitTimestamp = prefs.getInt('target_quit_timestamp');
      
      if (targetQuitTimestamp != null && mounted) {
        setState(() {
          _goalDate = DateTime.fromMillisecondsSinceEpoch(targetQuitTimestamp);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Format the date using current locale if available
    String formattedDate = _goalDate != null 
        ? DateFormat('MMM d, yyyy', l10n.locale.languageCode).format(_goalDate!)
        : DateFormat('MMM d, yyyy', l10n.locale.languageCode).format(DateTime.now());
        
    return GestureDetector(
      onTap: () {
        // Track block tap with Mixpanel
        MixpanelService.trackButtonTap('Goal Date Block', screenName: 'Home Screen');
        Navigator.of(context).pushReplacement(
          BottomToTopPageRoute(
            child: const HomeRewireBrainScreen(),
            settings: const RouteSettings(name: '/home_rewire_brain'),
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main container
          Container(
            margin: const EdgeInsets.only(left: 20, right: 5, top: 20),
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
            constraints: const BoxConstraints(minHeight: 118),
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8), // Space for the checkmark
                Text(
                  l10n.translate('home_goalDate_onTrackToQuit'),
                  style: const TextStyle(
                    color: Color(0xFF666666), // Gray text for white background
                    fontSize: 11,
                    fontFamily: 'ElzaRound',
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formattedDate,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A), // Dark text for white background
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'ElzaRound Variable',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          
          // Checkmark positioned on the top border
          Positioned(
            top: 2, // Position halfway on the border
            left: 11,
            right: 0,
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFed3272), // Brand pink background
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE0E0E0), // Light gray border
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/onboarding/checkmark_white.png',
                    width: 80,
                    height: 80,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 