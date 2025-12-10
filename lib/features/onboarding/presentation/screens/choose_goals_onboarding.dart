import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/features/onboarding/presentation/screens/rewiring_benefits_2_chart.dart';
import 'package:stoppr/features/onboarding/presentation/screens/stoppr_science_backed_plan.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stoppr/features/onboarding/presentation/screens/referral_code_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/features/onboarding/data/repositories/questionnaire_repository.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class SlideRightRoute extends PageRouteBuilder {
  final Widget page;
  SlideRightRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(-1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}

class Goal {
  final String titleKey;
  final String englishTitle;
  final IconData icon;
  final Color backgroundColor;
  final Color accentColor;
  bool isSelected;

  Goal({
    required this.titleKey,
    required this.englishTitle,
    required this.icon,
    required this.backgroundColor,
    required this.accentColor,
    this.isSelected = false,
  });
}

class ChooseGoalsOnboardingScreen extends StatefulWidget {
  const ChooseGoalsOnboardingScreen({super.key});

  @override
  State<ChooseGoalsOnboardingScreen> createState() => _ChooseGoalsOnboardingScreenState();
}

class _ChooseGoalsOnboardingScreenState extends State<ChooseGoalsOnboardingScreen> {
  final List<Goal> goals = [
    Goal(
      titleKey: 'goal_strongerRelationships',
      englishTitle: 'Stronger relationships',
      icon: Icons.favorite,
      backgroundColor: const Color(0xFFFFF9FB), // Very light pink, almost white
      accentColor: const Color(0xFFed3272), // Brand pink
    ),
    Goal(
      titleKey: 'goal_improvedSelfConfidence',
      englishTitle: 'Improved self-confidence',
      icon: Icons.person,
      backgroundColor: const Color(0xFFF8FBFF), // Very light blue, almost white
      accentColor: const Color(0xFF2196F3), // Brighter blue
    ),
    Goal(
      titleKey: 'goal_improvedMoodHappiness',
      englishTitle: 'Improved mood and happiness',
      icon: Icons.sentiment_satisfied_alt,
      backgroundColor: const Color(0xFFFFFDF7), // Very light yellow, almost white
      accentColor: const Color(0xFFFFC107), // Bright yellow
    ),
    Goal(
      titleKey: 'goal_moreEnergyMotivation',
      englishTitle: 'More energy and motivation',
      icon: Icons.bolt,
      backgroundColor: const Color(0xFFFFFCF7), // Very light orange, almost white
      accentColor: const Color(0xFFfd5d32), // Brand orange
    ),
    Goal(
      titleKey: 'goal_improvedLibidoSexLife',
      englishTitle: 'Improved libido and sex life',
      icon: Icons.favorite_border,
      backgroundColor: const Color(0xFFFFF9F9), // Very light red, almost white
      accentColor: const Color(0xFFF44336), // Brighter red
    ),
    Goal(
      titleKey: 'goal_improvedSelfControl',
      englishTitle: 'Improved self-control',
      icon: Icons.pan_tool_outlined,
      backgroundColor: const Color(0xFFF7FEFF), // Very light teal, almost white
      accentColor: const Color(0xFF00BCD4), // Brighter teal
    ),
    Goal(
      titleKey: 'goal_improvedFocusClarity',
      englishTitle: 'Improved focus and clarity',
      icon: Icons.psychology,
      backgroundColor: const Color(0xFFFDF9FF), // Very light purple, almost white
      accentColor: const Color(0xFF9C27B0), // Brighter purple
    ),
    Goal(
      titleKey: 'goal_pureHealthyThoughts',
      englishTitle: 'Pure and healthy thoughts',
      icon: Icons.spa,
      backgroundColor: const Color(0xFFF9FFF9), // Very light green, almost white
      accentColor: const Color(0xFF4CAF50), // Brighter green
    ),
  ];
  
  final QuestionnaireRepository _questionnaireRepository = QuestionnaireRepository();
  final OnboardingProgressService _progressService = OnboardingProgressService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    // Force dark status bar icons for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    
    // Save current screen state
    _saveCurrentScreen();

    // Mixpanel
    MixpanelService.trackPageView('Onboarding Choose Goals Screen');
  }
  
  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.chooseGoalsScreen);
  }
  
  Future<void> _saveGoalsAndNavigate() async {
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });
    
    // Get selected English goal titles
    final selectedGoals = goals
        .where((goal) => goal.isSelected)
        .map((goal) => goal.englishTitle)
        .toList();
    
    // Save to Firebase if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await _questionnaireRepository.saveGoals(
          userId: currentUser.uid,
          goals: selectedGoals,
        );
        
        // Track selected goals in Mixpanel
        MixpanelService.trackEvent('Onboarding Goals Selected', properties: {
          'selected_goals': selectedGoals,
          'goal_count': selectedGoals.length,
          'user_id': currentUser.uid,
        });
        
      } catch (e) {
        // Track error saving goals
        MixpanelService.trackEvent('Onboarding Goals Save Error', properties: {
          'error': e.toString(),
          'user_id': currentUser.uid,
        });
        // Continue with flow even if save fails
      }
    }
    
    setState(() {
      _isSaving = false;
    });
    
    // Navigate to next screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ReferralCodeScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Enforce dark status bar icons for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      // Clean white background matching app branding
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 25,
          automaticallyImplyLeading: false,
          title: const Text(''),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Custom Header
              Transform.translate(
                offset: const Offset(0, 0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        l10n.translate('chooseGoals_title'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          color: Color(0xFF1A1A1A), // Dark text for white background
                          fontSize: 31,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtitle
                      Text(
                        l10n.translate('chooseGoals_subtitle'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          color: Color(0xFF666666), // Dark gray for white background
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Goals list
              Expanded(
                child: Stack(
                  children: [
                    // List of goals
                    ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 15,
                        bottom: 125, // Added extra bottom padding to allow scrolling past the button
                      ),
                      itemCount: goals.length,
                      itemBuilder: (context, index) {
                        final goal = goals[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _GoalCard(
                            goal: goal,
                            onTap: () {
                              setState(() {
                                goal.isSelected = !goal.isSelected;
                              });
                            },
                          ),
                        );
                      },
                    ),
                    
                    // Continue button at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white, // Match main background
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        height: 110,
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: MediaQuery.of(context).padding.bottom,
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: GestureDetector(
                              onTap: _isSaving ? null : _saveGoalsAndNavigate,
                              child: Container(
                                width: double.infinity,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Color(0xFFed3272), // Strong pink/magenta
                                      Color(0xFFfd5d32), // Vivid orange
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      offset: const Offset(0, 2),
                                      blurRadius: 4,
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: _isSaving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        l10n.translate('chooseGoals_trackButton'),
                                        style: const TextStyle(
                                          fontFamily: 'ElzaRound',
                                          color: Colors.white, // White text on gradient
                                          fontSize: 19, // Increased from 15 to 19
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
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
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onTap;

  const _GoalCard({
    required this.goal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xFFed3272), // CTA brand pink border
            width: 2,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 15),
            // Icon circle
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
              ),
              child: _buildIcon(),
            ),
            const SizedBox(width: 15),
            // Title
            Expanded(
              child: Text(
                l10n.translate(goal.titleKey),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A), // Dark text on white background
                ),
              ),
            ),
            // Checkmark
            if (goal.isSelected)
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 15),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFed3272), // CTA brand pink fill
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white, // White check icon
                  size: 16,
                ),
              )
            else
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  border: Border.all(
                    color: const Color(0xFFed3272).withOpacity(0.5),
                    width: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper function to darken a color slightly
  Color _darkenColor(Color color, double factor) {
    final hsl = HSLColor.fromColor(color);
    final darkenedHsl = hsl.withLightness((hsl.lightness - factor).clamp(0.0, 1.0));
    return darkenedHsl.toColor();
  }

  Widget _buildIcon() {
    switch (goal.englishTitle) {
      case 'Improved self-control':
        return Padding(
          padding: const EdgeInsets.all(7),
          child: SvgPicture.asset(
            'assets/images/svg/goal_improve_self_control.svg',
            width: 16,
            height: 16,
            colorFilter: const ColorFilter.mode(
              Color(0xFF1A1A1A), // Dark icon on white background
              BlendMode.srcIn,
            ),
          ),
        );
      case 'More energy and motivation':
        return Padding(
          padding: const EdgeInsets.all(7),
          child: SvgPicture.asset(
            'assets/images/svg/goal_more_energy_motivation.svg',
            width: 10,
            height: 16,
            colorFilter: const ColorFilter.mode(
              Color(0xFF1A1A1A), // Dark icon on white background
              BlendMode.srcIn,
            ),
          ),
        );
      case 'Improved focus and clarity':
        return Padding(
          padding: const EdgeInsets.all(7),
          child: SvgPicture.asset(
            'assets/images/svg/goal_improve_focus_clarity.svg',
            width: 16,
            height: 15,
            colorFilter: const ColorFilter.mode(
              Color(0xFF1A1A1A), // Dark icon on white background
              BlendMode.srcIn,
            ),
          ),
        );
      case 'Improved libido and sex life':
        return Padding(
          padding: const EdgeInsets.all(7),
          child: SvgPicture.asset(
            'assets/images/svg/goal_improve_libido.svg',
            width: 14,
            height: 14,
            colorFilter: const ColorFilter.mode(
              Color(0xFF1A1A1A), // Dark icon on white background
              BlendMode.srcIn,
            ),
          ),
        );
      case 'Pure and healthy thoughts':
        return Padding(
          padding: const EdgeInsets.all(7),
          child: SvgPicture.asset(
            'assets/images/svg/goal_pure_healthy_thoughts.svg',
            width: 14,
            height: 17,
            colorFilter: const ColorFilter.mode(
              Color(0xFF1A1A1A), // Dark icon on white background
              BlendMode.srcIn,
            ),
          ),
        );
      case 'Improved self-confidence':
        return Icon(
          goal.icon,
          color: const Color(0xFF1A1A1A), // Dark icon on white background
          size: 18, // Bigger size for this specific icon
        );
      default:
        return Icon(
          goal.icon,
          color: const Color(0xFF1A1A1A), // Dark icon on white background
          size: 16,
        );
    }
  }
} 