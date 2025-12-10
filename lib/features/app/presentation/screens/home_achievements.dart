import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/streak/achievements_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import 'home_screen.dart';
import 'main_scaffold.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../../../core/localization/app_localizations.dart';

class HomeAchievementsScreen extends StatefulWidget {
  const HomeAchievementsScreen({super.key});

  @override
  State<HomeAchievementsScreen> createState() => _HomeAchievementsScreenState();
}

class _HomeAchievementsScreenState extends State<HomeAchievementsScreen> {
  final AchievementsService _achievementsService = AchievementsService();
  String _userName = '';
  List<Achievement> _achievements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Track page view
    MixpanelService.trackPageView('Achievements Screen',
      additionalProps: {'Source': 'Navigation'});
    
    // Force status bar icons to dark mode for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ));
    
    _loadData();
  }

  Future<void> _loadData() async {
    // Initialize achievements service
    await _achievementsService.initialize();
    
    // Get achievements
    final achievements = _achievementsService.achievements;
    
    // Get user name with priority order:
    // 1. Firebase display name
    // 2. SharedPreferences user_first_name
    String name = '';
    
    // Try Firebase first
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      name = user.displayName!.split(' ')[0];
    }
    
    // If no name from Firebase, try SharedPreferences
    if (name.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      name = prefs.getString('user_first_name') ?? ''; // Default to empty as in screenshot
    }
    
    if (mounted) {
      setState(() {
        _userName = name;
        _achievements = achievements;
        _isLoading = false;
      });
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
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFed3272)))
              : CustomScrollView(
                  slivers: [
                    // Header section
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Back button and title row
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Title centered
                                Center(
                                  child: Text(
                                    AppLocalizations.of(context)!.translate('achievementsScreen_title'),
                                    style: const TextStyle(
                                      color: Color(0xFF1A1A1A),
                                      fontSize: 20,
                                      fontFamily: 'ElzaRound',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                
                                // Back button aligned left
                                Positioned(
                                  left: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).pushReplacement(
                                        TopToBottomPageRoute(
                                          child: const MainScaffold(initialIndex: 0),
                                          settings: const RouteSettings(name: '/home'),
                                        ),
                                      );
                                    },
                                    child: const Icon(
                                      Icons.arrow_back_ios,
                                      color: Color(0xFF1A1A1A),
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Your Showcase row with stars_wings image
                          Padding(
                            padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Your Showcase text
                                Text(
                                  l10n.translate('achievementsScreen_yourShowcase'),
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontSize: 24,
                                    fontFamily: 'ElzaRound',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                
                                // Stars wings image - only on iOS
                                Image.asset(
                                  'assets/images/onboarding/stars_wings.png',
                                  height: 30,
                                ),
                              ],
                            ),
                          ),
                          
                          // Added extra space
                          const SizedBox(height: 30),
                          
                          // User name
                          if (_userName.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 20, bottom: 20),
                              child: Text(
                                _userName,
                                style: const TextStyle(
                                  color: Color(0xFF666666),
                                  fontSize: 18,
                                  fontFamily: 'ElzaRound',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Achievement grid
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.80,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 18,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final achievement = _achievements[index];
                            return _buildAchievementCard(achievement);
                          },
                          childCount: _achievements.length,
                        ),
                      ),
                    ),
                    
                    // Bottom padding
                    const SliverPadding(
                      padding: EdgeInsets.only(bottom: 16),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    final bool isLocked = !achievement.isUnlocked;
    final double progress = achievement.currentProgress / achievement.daysRequired;
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFB), // Neutral white background
        borderRadius: BorderRadius.circular(20),
        border: isLocked 
            ? Border.all(
                color: const Color(0xFFE0E0E0),
                width: 2,
              )
            : GradientBoxBorder(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFed3272).withOpacity(0.4), // Brand pink - reduced opacity
                    const Color(0xFFfd5d32).withOpacity(0.4), // Brand orange - reduced opacity
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                width: 2,
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Stone image or lock icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent, // Always transparent now
                boxShadow: isLocked
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.1),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Center(
                child: isLocked
                  ? const Icon(
                      Icons.lock,
                      color: Color(0xFF666666),
                      size: 25,
                    )
                  : SizedBox(
                      width: 45,
                      height: 45,
                      child: _buildAchievementLottie(achievement),
                    ),
              ),
            ),
            const SizedBox(height: 10),
            
            // Achievement name
            Text(
              l10n.translate('achievement_${achievement.id}_name'),
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 18,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            
            // Achievement description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                l10n.translate('achievement_${achievement.id}_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 12,
                  fontFamily: 'ElzaRound',
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Stack(
                children: [
                  // Background
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  // Progress
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFed3272), // Brand pink
                            Color(0xFFfd5d32), // Brand orange
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            
            // Progress text
            Text(
              '${achievement.currentProgress}/${achievement.daysRequired}${l10n.translate('achievementsScreen_progress_days')}',
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 12,
                fontFamily: 'ElzaRound',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementLottie(Achievement achievement) {
    try {
      return Lottie.asset(
        achievement.imageAsset,
        width: 45,
        height: 45,
        fit: BoxFit.contain,
        animate: true,
        repeat: true,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading achievement Lottie: $error');
          return _buildFallbackAchievementIcon();
        },
      );
    } catch (e) {
      debugPrint('Error creating achievement Lottie widget: $e');
      return _buildFallbackAchievementIcon();
    }
  }

  Widget _buildFallbackAchievementIcon() {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Color(0xFFed3272), // Brand pink
            Color(0xFFfd5d32), // Brand orange
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: const Icon(
        Icons.stars,
        color: Colors.white,
        size: 25,
      ),
    );
  }
}

// A proper implementation of a gradient border for boxes that extends BoxBorder
class GradientBoxBorder extends BoxBorder {
  final Gradient gradient;
  final double width;

  const GradientBoxBorder({
    required this.gradient,
    required this.width,
  });

  @override
  BorderSide get top => BorderSide(width: width, color: Colors.transparent);
  
  @override
  BorderSide get bottom => BorderSide(width: width, color: Colors.transparent);
  
  @override
  BorderSide get left => BorderSide(width: width, color: Colors.transparent);
  
  @override
  BorderSide get right => BorderSide(width: width, color: Colors.transparent);
  
  @override
  bool get isUniform => true;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final Paint paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    final RRect rrect = borderRadius?.toRRect(rect) ?? RRect.fromRectAndRadius(rect, Radius.circular(0));
    canvas.drawRRect(rrect, paint);
  }
  
  @override
  ShapeBorder scale(double t) {
    return GradientBoxBorder(
      gradient: gradient,
      width: width * t,
    );
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);
} 