import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/streak/streak_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import 'main_scaffold.dart';
import 'home_rewire_brain.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/accountability/accountability_widget_service.dart';

class HomeEditStreakScreen extends StatefulWidget {
  const HomeEditStreakScreen({super.key});

  @override
  State<HomeEditStreakScreen> createState() => _HomeEditStreakScreenState();
}

class _HomeEditStreakScreenState extends State<HomeEditStreakScreen> {
  final StreakService _streakService = StreakService();
  DateTime _selectedDate = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    // Track page view
    MixpanelService.trackPageView('Edit Streak Screen');
    _loadCurrentDate();
  }
  
  Future<void> _loadCurrentDate() async {
    // Get current streak start date
    final streakData = _streakService.currentStreak;
    if (streakData.startTime != null) {
      setState(() {
        _selectedDate = streakData.startTime!;
        _currentMonth = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          1
        );
      });
    }
  }
  
  void _updateStreakDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Use the new method to set custom streak start date
    await _streakService.setCustomStreakStartDate(date);
    
    // Calculate and update target quit date (90 days from streak start)
    final targetQuitDate = date.add(const Duration(days: 90));
    await prefs.setInt('target_quit_timestamp', targetQuitDate.millisecondsSinceEpoch);
    
    // Force sync both widgets to ensure they update immediately
    try {
      // Update streak widget
      await _streakService.syncWidgetData();
      // Update accountability widget with new streak
      await AccountabilityWidgetService.instance.updateWidget();
    } catch (e) {
      debugPrint('Error updating widgets after streak change: $e');
    }
    
    // Navigate back to home screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        FadePageRoute(
          child: const MainScaffold(initialIndex: 0),
          settings: const RouteSettings(name: '/home'),
        ),
      );
    }
  }
  
  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month - 1,
        1,
      );
    });
  }
  
  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + 1,
        1,
      );
    });
  }
  
  List<Widget> _buildCalendarDays() {
    List<Widget> dayWidgets = [];
    
    // Get the first day of the current month
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    
    // Get the last day of the current month
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    
    // Get the weekday of the first day (0 = Monday, 6 = Sunday)
    int firstWeekday = firstDayOfMonth.weekday - 1;
    if (firstWeekday == -1) firstWeekday = 6; // Sunday adjustment
    
    // Fill empty cells before the first day
    for (int i = 0; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox.shrink());
    }
    
    // Add day cells
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final currentDate = DateTime(_currentMonth.year, _currentMonth.month, day);
      final isSelected = currentDate.year == _selectedDate.year &&
                         currentDate.month == _selectedDate.month &&
                         currentDate.day == _selectedDate.day;
      
      final now = DateTime.now();
      final isAfterToday = currentDate.isAfter(now) || 
                          (currentDate.year == now.year && 
                           currentDate.month == now.month && 
                           currentDate.day == now.day);
      
      dayWidgets.add(
        GestureDetector(
          onTap: isAfterToday ? null : () {
            setState(() {
              _selectedDate = currentDate;
            });
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              gradient: isSelected 
                ? const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFed3272), // Brand pink
                      Color(0xFFfd5d32), // Brand orange
                    ],
                  )
                : null,
              color: isSelected ? null : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  fontSize: 16,
                  fontFamily: 'ElzaRound',
                  color: isSelected 
                    ? Colors.white 
                    : (isAfterToday ? const Color(0xFF666666) : const Color(0xFF1A1A1A)), // Dark text for white background
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }
    
    return dayWidgets;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 70,
        leading: GestureDetector(
          onTap: () {
            Navigator.of(context).pushReplacement(
              FadePageRoute(
               child: const MainScaffold(initialIndex: 0),
                settings: const RouteSettings(name: '/home'),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.translate('common_cancel'),
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFFed3272), // Brand pink
                  fontSize: 16,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            l10n.translate('editStreakScreen_title'),
            maxLines: 1,
            overflow: TextOverflow.visible,
            style: const TextStyle(
              color: Color(0xFF1A1A1A), // Dark text for white background
              fontSize: 18,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              _updateStreakDate(_selectedDate);
            },
            child: Text(
              l10n.translate('common_save'),
              style: const TextStyle(
                color: Color(0xFFed3272), // Brand pink
                fontSize: 16,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // Dark icons for white background
          statusBarBrightness: Brightness.light, // For iOS
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Color(0xFFed3272)), // Brand pink
                onPressed: _previousMonth,
              ),
              Text(
                DateFormat('MMMM yyyy').format(_currentMonth),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text for white background
                  fontSize: 20,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Color(0xFFed3272)), // Brand pink
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              l10n.translate('common_day_monday_short').toUpperCase(), 
              l10n.translate('common_day_tuesday_short').toUpperCase(), 
              l10n.translate('common_day_wednesday_short').toUpperCase(), 
              l10n.translate('common_day_thursday_short').toUpperCase(), 
              l10n.translate('common_day_friday_short').toUpperCase(), 
              l10n.translate('common_day_saturday_short').toUpperCase(), 
              l10n.translate('common_day_sunday_short').toUpperCase()
            ].map((day) => SizedBox(
              width: 40,
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(
                    color: Color(0xFF666666), // Gray secondary text
                    fontSize: 14,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 10),
          // Calendar grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: _buildCalendarDays(),
            ),
          ),
        ],
      ),
    );
  }

  // Method to open medical information URL
  Future<void> _openMedicalInfo() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Help & Info', screenName: 'Edit Streak Screen');
    
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