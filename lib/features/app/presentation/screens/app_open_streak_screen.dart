import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/streak/app_open_streak_service.dart';
import '../../../../core/analytics/mixpanel_service.dart';

class AppOpenStreakScreen extends StatefulWidget {
  const AppOpenStreakScreen({super.key});

  @override
  State<AppOpenStreakScreen> createState() => _AppOpenStreakScreenState();
}

class _AppOpenStreakScreenState extends State<AppOpenStreakScreen> {
  final AppOpenStreakService _appOpenStreakService = AppOpenStreakService();
  int _streakDays = 0;

  @override
  void initState() {
    super.initState();
    
    // Set status bar to dark icons for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for white background
      statusBarBrightness: Brightness.light, // For iOS
    ));
    
    _loadStreakData();
    
    
    // Track screen view
    MixpanelService.trackEvent('App Open Streak Screen View');
  }

  Future<void> _loadStreakData() async {
    final streakData = _appOpenStreakService.currentStreak;
    if (mounted) {
      setState(() {
        _streakDays = streakData.consecutiveDays;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque, // Detect taps anywhere
        onTap: () {
          MixpanelService.trackButtonTap('Background Tap Close', screenName: 'App Open Streak Screen');
          Navigator.of(context).pop();
        },
        child: SafeArea(
        child: Column(
          children: [
            // Top bar with close button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      MixpanelService.trackButtonTap('Close', screenName: 'App Open Streak Screen');
                      Navigator.of(context).pop();
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.close,
                        color: Color(0xFF1A1A1A), // Dark icon for white background
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Main content
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Large flame icon
                  SvgPicture.asset(
                    'assets/images/home/flame.svg',
                    width: 160,
                    height: 160,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Streak count and title
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFed3272), // Brand pink
                        Color(0xFFfd5d32), // Brand orange
                      ],
                    ).createShader(bounds),
                    child: Text(
                      l10n.translate('appOpenStreak_title').replaceAll('{days}', '$_streakDays'),
                      style: const TextStyle(
                        color: Colors.white, // Required for shader mask
                        fontSize: 36,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      l10n.translate('appOpenStreak_intro'),
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A), // Dark text for white background
                        fontSize: 16,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Additional motivational content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        Text(
                          _streakDays == 0 
                            ? l10n.translate('homeScreen_appOpenStreakFirstDay')
                            : _streakDays == 1
                              ? l10n.translate('homeScreen_appOpenStreakDescriptionSingular')
                              : l10n.translate('homeScreen_appOpenStreakDescription').replaceAll('{days}', '$_streakDays'),
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A), // Dark text for white background
                            fontSize: 16,
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.translate('homeScreen_appOpenStreakMotivation'),
                          style: const TextStyle(
                            color: Color(0xFF666666), // Gray secondary text
                            fontSize: 14,
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
        ),
      ),
    );
  }
} 