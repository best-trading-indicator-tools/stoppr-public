import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class InsightsScreen extends StatefulWidget {
  final Map<int, String> userAnswers;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  
  const InsightsScreen({
    super.key,
    required this.userAnswers,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with SingleTickerProviderStateMixin {
  // Health impact metrics based on user consumption data
  String _weightLossKg = '1-2';
  int _caloriesPerMonth = 0; // Monthly calories (approx. 4 weeks)
  String _treatSize = 'medium'; // Key: 'small', 'medium', 'large' - use getLocalizedTreatSize() for display
  double _caloriesPerTreatValue = 250.0;
  
  final OnboardingProgressService _progressService = OnboardingProgressService();
  
  // Helper to get localized treat size display value
  String _getLocalizedTreatSize(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (_treatSize) {
      case 'small':
        return localizations.translate('consumption_small');
      case 'large':
        return localizations.translate('consumption_large');
      case 'medium':
      default:
        return localizations.translate('consumption_medium');
    }
  }
  
  @override
  void initState() {
    super.initState();
    _calculateInsights();
    _saveCurrentScreen();

    // Force status bar icons to dark mode for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
    ));

    // Track page view with Mixpanel
    MixpanelService.trackPageView('Onboarding Insights Screen');

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();

    _fade1 = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );
    _fade2 = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
    );
    _fade3 = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOutCubic),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    // Restore status bar for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    super.dispose();
  }
  
  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.insightsScreen);
  }
  
  // Animations
  late final AnimationController _animationController;
  late final Animation<double> _fade1;
  late final Animation<double> _fade2;
  late final Animation<double> _fade3;

  // Calculate health impact insights based on consumption data (monthly)
  void _calculateInsights() {
    // Get consumption data from previous screen
    int treatPerWeek = 0;
    double caloriesPerTreat = 0;
    
    // Extract values from userAnswers (stored in keys 100+)
    if (widget.userAnswers.containsKey(100)) {
      treatPerWeek = int.tryParse(widget.userAnswers[100] ?? "0") ?? 0;
    }
    
    String treatSize = widget.userAnswers[101] ?? "medium";
    _treatSize = treatSize;
    
    // Get calories based on treat size
    switch (treatSize) {
      case 'small':
        caloriesPerTreat = 150.0;
        break;
      case 'medium':
        caloriesPerTreat = 250.0;
        break;
      case 'large':
        caloriesPerTreat = 425.0;
        break;
      default:
        caloriesPerTreat = 250.0;
    }
    _caloriesPerTreatValue = caloriesPerTreat;
    
    // Calculate calories for roughly a month (4 weeks)
    const int weeksInMonth = 4;
    double monthlyCalories = treatPerWeek * caloriesPerTreat * weeksInMonth;
    _caloriesPerMonth = monthlyCalories.round();
    
    // Weight loss: 1-2kg per week on average
    // This is a consistent, believable metric for users
    _weightLossKg = '1-2';
    
    // Sleep quality improvement - 3X better sleep quality
    // Studies show reducing sugar significantly improves sleep through fewer blood sugar crashes
    // Note: '3X' is a universal symbol, no localization needed
    
    // Skin improvement - visible results in 2 weeks
    // Research shows reducing sugar improves skin clarity and reduces breakouts quickly
    // Will be localized in build method
  }
  
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for white background
        statusBarBrightness: Brightness.light, // For iOS
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white, // Clean white background matching app branding
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                // Detect if we're on a smaller screen (like iPhone XS)
                final isSmallScreen = MediaQuery.of(context).size.height < 750;
                final topSpacing = isSmallScreen ? 20.0 : 24.0;
                final titleSpacing = isSmallScreen ? 18.0 : 22.0;
                final subtitleSpacing = isSmallScreen ? 28.0 : 32.0;
                final metricSpacing = isSmallScreen ? 32.0 : 40.0;
                final disclaimerSpacing = isSmallScreen ? 40.0 : 60.0;
                final bottomSpacing = isSmallScreen ? 30.0 : 38.0;

                return SingleChildScrollView(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24.0, topSpacing, 24.0, 50.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Progress bar and back button row
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // Navigate back to ConsumptionSummaryScreen
                                  Navigator.of(context).pop();
                                },
                                child: const Icon(
                                  Icons.arrow_back_ios,
                                  color: Color(0xFF1A1A1A), // Dark icon for white background
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: 0.4, // About 40% progress in onboarding
                                    minHeight: 8,
                                    backgroundColor: const Color(0xFFE0E0E0), // Light gray for white background
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFed3272)), // Brand pink
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: topSpacing),
                          // Headline
                          Text(
                            AppLocalizations.of(context)!.translate('insights_title'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A), // Dark text for white background
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: titleSpacing),
                          // Subtitle
                          Text(
                            AppLocalizations.of(context)!.translate('insights_subtitle'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF666666), // Dark gray for white background
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: subtitleSpacing),
                          // Weight Loss
                          FadeTransition(
                            opacity: _fade1,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.06),
                                end: Offset.zero,
                              ).animate(_fade1),
                              child: _buildMetricDisplay(
                                value: '$_weightLossKg kg',
                                label: AppLocalizations.of(context)!
                                    .translate('insights_weightLoss'),
                                hint: AppLocalizations.of(context)!
                                    .translate('insights_cmp_weightLoss'),
                                textColor: const Color(0xFF1A1A1A), // Dark text for white background
                              ),
                            ),
                          ),
                          SizedBox(height: metricSpacing),
                          // Sleep Quality Improvement
                          FadeTransition(
                            opacity: _fade2,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.06),
                                end: Offset.zero,
                              ).animate(_fade2),
                              child: _buildMetricDisplay(
                                value: AppLocalizations.of(context)!
                                    .translate('insights_sleepValue'),
                                label: AppLocalizations.of(context)!
                                    .translate('insights_sleepQualityImprovement'),
                                hint: AppLocalizations.of(context)!
                                    .translate('insights_cmp_sleep'),
                                textColor: const Color(0xFF1A1A1A), // Dark text for white background
                              ),
                            ),
                          ),
                          SizedBox(height: metricSpacing),
                          // Skin Improvement
                          FadeTransition(
                            opacity: _fade3,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.06),
                                end: Offset.zero,
                              ).animate(_fade3),
                              child: _buildMetricDisplay(
                                value: AppLocalizations.of(context)!
                                    .translate('insights_skinValue'),
                                label: AppLocalizations.of(context)!
                                    .translate('insights_skinImprovement'),
                                hint: AppLocalizations.of(context)!
                                    .translate('insights_cmp_skin'),
                                textColor: const Color(0xFF1A1A1A), // Dark text for white background
                              ),
                            ),
                          ),
                          SizedBox(height: bottomSpacing),
                          // Next Button
                          Container(
                            width: double.infinity,
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
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                // Track the button tap
                                MixpanelService.trackEvent('Onboarding Progress Card Creation Screen: Button Tap');
                                
                                // Continue to next question in questionnaire flow
                                debugPrint('Next button pressed on InsightsScreen - Continuing to next question');
                                // Store callback before popping
                                final nextCallback = widget.onNext;
                                // Pop the Insights Screen first
                                Navigator.of(context).pop();
                                // Call onNext after pop completes in the next frame
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  nextCallback();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 12.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                minimumSize: const Size(double.infinity, 56),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.translate('common_next'),
                                style: const TextStyle(
                                  fontFamily: 'ElzaRound',
                                  fontSize: 19, // Increased from 16 to 19
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper to build metric displays with consistent styling
  Widget _buildMetricDisplay({
    required String value,
    required String label,
    required Color textColor,
    String? hint,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'ElzaRound',
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'ElzaRound',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A), // Dark text for white background
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontSize: 14,
              color: Color(0xFF666666), // Gray text for white background
            ),
          ),
        ],
      ],
    );
  }
} 