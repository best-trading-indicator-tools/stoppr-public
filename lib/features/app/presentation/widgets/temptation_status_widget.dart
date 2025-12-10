import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/home_how_do_you_feel_screen.dart';
import '../screens/main_scaffold.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import '../../../../core/localization/app_localizations.dart';
import 'package:stoppr/app/theme/colors.dart';

class TemptationStatusWidget extends StatefulWidget {
  const TemptationStatusWidget({super.key});

  @override
  State<TemptationStatusWidget> createState() => _TemptationStatusWidgetState();
}

class _TemptationStatusWidgetState extends State<TemptationStatusWidget> {
  bool _isTempted = false;
  String? _currentMoodEmoji;
  
  @override
  void initState() {
    super.initState();
    _loadTemptationStatus();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTemptationStatus();
  }

  Future<void> _loadTemptationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if it's a new day only once per app startup, not on every load
    final String today = DateTime.now().toIso8601String().split('T')[0];
    final String? lastCheckDate = prefs.getString('last_temptation_check_date');
    
    if (lastCheckDate != null && lastCheckDate != today) {
      // It's a new day, reset temptation status to false
      await prefs.setBool('is_tempted', false);
      print('New day detected, reset temptation status to false');
    }
    
    // Always update the last check date
    await prefs.setString('last_temptation_check_date', today);
    
    final isTempted = prefs.getBool('is_tempted') ?? false;
    final moodEmoji = prefs.getString('current_mood_emoji');
    
    if (mounted) {
      setState(() {
        _isTempted = isTempted;
        _currentMoodEmoji = moodEmoji;
      });
    }
    
    // Print for debugging
    //print('Loaded temptation status: $_isTempted');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () {
        // Track block tap with Mixpanel
        MixpanelService.trackButtonTap('Temptation Status Block', screenName: 'Home Screen');
        Navigator.of(context).push(
          BottomToTopPageRoute(
            child: const HomeHowDoYouFeelScreen(),
            settings: const RouteSettings(name: '/how_do_you_feel'),
          ),
        ).then((_) => _loadTemptationStatus());
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.only(left: 5, right: 20, top: 20),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                Text(
                  l10n.translate('home_temptationStatus_label'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF666666), // Gray text for white background
                    fontSize: 11,
                    fontFamily: 'ElzaRound',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  _isTempted ? l10n.translate('common_true') : l10n.translate('common_false'),
                  style: TextStyle(
                    color: _isTempted ? Colors.redAccent : Colors.greenAccent, // Keep status colors for meaning
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'ElzaRound Variable',
                  ),
                ),
              ],
            ),
          ),
          
          // Emoji positioned on the top border
          Positioned(
            top: -5,
            left: -10,
            right: 0,
            child: Center(
              child: Text(
                _currentMoodEmoji ?? '😊',
                style: const TextStyle(fontSize: 34),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 