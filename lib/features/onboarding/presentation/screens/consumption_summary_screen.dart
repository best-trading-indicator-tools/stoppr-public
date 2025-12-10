import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/features/onboarding/presentation/screens/questionnaire_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/insights_screen.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/navigation/page_transitions.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class ConsumptionSummaryScreen extends StatefulWidget {
  final Map<int, String> userAnswers;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  
  const ConsumptionSummaryScreen({
    super.key,
    required this.userAnswers,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  State<ConsumptionSummaryScreen> createState() => _ConsumptionSummaryScreenState();
}

class _ConsumptionSummaryScreenState extends State<ConsumptionSummaryScreen> {
  // Default values for the sliders
  int _sugaryTreatsPerWeek = 36;
  
  // Pattern-first selection for frequency
  String _consumptionPattern = 'daily'; // daily | fewDays
  
  // Categories for treat size with fixed calorie values
  final Map<String, double> _treatSizeCalories = {
    'small': 150.0,   // Small treat (cookie)
    'medium': 250.0,  // Medium treat (ice cream)
    'large': 425.0,   // Large treat (cake)
  };
  
  // Selected treat size (default to medium)
  String _selectedTreatSize = 'medium';
  
  // Current calories per treat based on selection
  double get _caloriesPerTreat => _treatSizeCalories[_selectedTreatSize]!;
  
  // Calculated totals
  double _caloriesPerWeek = 9000.0;
  double _caloriesPerQuarter = 0.0; // New: calories per quarter (13 weeks)
  double _caloriesPerYear = 108000.0;
  
  final OnboardingProgressService _progressService = OnboardingProgressService();
  
  @override
  void initState() {
    super.initState();
    _calculateInitialValues();
    _saveCurrentScreen();
    
    // Force status bar icons to dark mode for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
    ));

    // Save initial values to userAnswers map
    _saveToUserAnswers();

    // Track page view with Mixpanel
    MixpanelService.trackPageView('Consumption Summary Screen');
    
    // Track as question 5 answered immediately when screen loads
    // This ensures it's tracked even if user doesn't complete the screen
    String baseLevel = _getConsumptionLevel().split(' (')[0];
    MixpanelService.trackEvent(
      'Onboarding Consumtion Summary Question Answered',
      properties: {
        'question_id': 5,
        'question_text': 'Do you think your sugar consumption is:',
        'answer': baseLevel.substring(0, 1).toUpperCase() + baseLevel.substring(1), // Capitalize first letter
      }
    );
  }
  
  @override
  void dispose() {
    // Restore default status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    super.dispose();
  }
  
  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.consumptionSummaryScreen);
  }
  
  // Save the current values to the userAnswers map
  void _saveToUserAnswers() {
    // Use high integer keys for consumption summary data to avoid conflicts with question numbers
    // Questions are 0-based indexed, so we'll use 100+ to store our custom data
    widget.userAnswers[100] = _sugaryTreatsPerWeek.toString();
    widget.userAnswers[101] = _selectedTreatSize;
    widget.userAnswers[102] = _caloriesPerTreat.toString();
    widget.userAnswers[103] = _caloriesPerQuarter.toString(); // Add quarterly calories to userAnswers
    widget.userAnswers[105] = _consumptionPattern;
    
    // Save formatted consumption level with count to our internal tracking
    widget.userAnswers[104] = _getConsumptionLevel();
    
    // Save JUST the level without count to q5 for the questionnaire display
    // This becomes the 5th question answer (index 4)
    String baseLevel = _getConsumptionLevel().split(' (')[0];
    // Make first letter uppercase for better display
    baseLevel = baseLevel[0].toUpperCase() + baseLevel.substring(1);
    widget.userAnswers[4] = baseLevel;
  }
  
  // Determine consumption level based on number of treats per week
  String _getConsumptionLevel() {
    // Categorize consumption level
    String level;
    if (_sugaryTreatsPerWeek <= 10) {
      level = 'Low';
    } else if (_sugaryTreatsPerWeek <= 30) {
      level = 'Moderate';
    } else {
      level = 'High';
    }
    
    // Return formatted string with level and count
    return '$level (${_sugaryTreatsPerWeek})';
  }
  
  // Calculate initial values based on the answers to previous questions
  void _calculateInitialValues() {
    // Initialize from previously selected pattern if available
    if (widget.userAnswers.containsKey(105)) {
      _consumptionPattern = widget.userAnswers[105] ?? 'daily';
    }

    // Map pattern to an estimated weekly count
    switch (_consumptionPattern) {
      case 'daily':
        _sugaryTreatsPerWeek = 35; // ~5 per day
        break;
      case 'fewDays':
        _sugaryTreatsPerWeek = 15; // ~3-4 times a week
        break;
      default:
        _sugaryTreatsPerWeek = 10;
    }
    
    // Update calorie calculations
    _updateCalories();
  }
  
  // Calculate the weekly and yearly calories based on treats per week and current treat size
  void _updateCalories() {
    // Weekly calories: treats per week * calories per treat
    _caloriesPerWeek = _sugaryTreatsPerWeek * _caloriesPerTreat;
    
    // Quarterly calories: weekly calories * 13 weeks
    _caloriesPerQuarter = _caloriesPerWeek * 13;
    
    // Yearly calories: weekly calories * weeks in a year
    _caloriesPerYear = _caloriesPerWeek * 52;
    
    // Make sure the UI updates with setState
    setState(() {});
    
    // Update userAnswers with new values
    _saveToUserAnswers();
    
    // Save to SharedPreferences separately
    _saveConsumptionDataToPrefs();
  }
  
  // Save consumption data to SharedPreferences for easy access
  Future<void> _saveConsumptionDataToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sugar_treats_per_week', _sugaryTreatsPerWeek);
    await prefs.setString('consumption_pattern', _consumptionPattern);
    
    // Save both individual level and the formatted level with count
    final String consumptionLevel = _getConsumptionLevel();
    final String baseLevel = consumptionLevel.split(' (')[0]; // Extract just 'low', 'moderate', or 'high'
    
    await prefs.setString('consumption_level', consumptionLevel); // Full formatted string
    await prefs.setString('consumption_base_level', baseLevel); // Just the level name
    
    await prefs.setString('treat_size', _selectedTreatSize);
    await prefs.setDouble('calories_per_treat', _caloriesPerTreat);
    await prefs.setDouble('calories_per_week', _caloriesPerWeek);
    await prefs.setDouble('calories_per_quarter', _caloriesPerQuarter);
    await prefs.setDouble('calories_per_year', _caloriesPerYear);
  }

  // Build a treat size option
  Widget _buildTreatSizeOption(String size, String emoji, String label) {
    final bool isSelected = _selectedTreatSize == size;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTreatSize = size;
          _updateCalories();
        });
      },
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          gradient: isSelected 
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFed3272), // Strong pink/magenta
                    Color(0xFFfd5d32), // Vivid orange
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.transparent // No border for gradient
                : const Color(0xFFE0E0E0), // Light gray for unselected
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'ElzaRound',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF1A1A1A), // White on gradient, dark on white
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_treatSizeCalories[size]!.toInt()} cal',
              style: TextStyle(
                fontFamily: 'ElzaRound',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isSelected ? Colors.white.withOpacity(0.8) : const Color(0xFF666666), // White on gradient, gray on white
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Small widget: radio group for pattern selection
  Widget _patternTile({
    required String value,
    required String labelKey,
  }) {
    final bool isSelected = _consumptionPattern == value;
    return InkWell(
      onTap: () => setState(() {
        _consumptionPattern = value;
        switch (value) {
          case 'daily':
            _sugaryTreatsPerWeek = 35;
            break;
          case 'fewDays':
            _sugaryTreatsPerWeek = 15;
            break;
        }
        _updateCalories();
      }),
      child: Row(
        children: [
          Radio<String>(
            value: value,
            groupValue: _consumptionPattern,
            activeColor: const Color(0xFFed3272), // Brand pink
            onChanged: (val) => setState(() {
              _consumptionPattern = val!;
              switch (val) {
                case 'daily':
                  _sugaryTreatsPerWeek = 35;
                  break;
                case 'fewDays':
                  _sugaryTreatsPerWeek = 15;
                  break;
              }
              _updateCalories();
            }),
          ),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.translate(labelKey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                fontSize: 16,
                color: Color(0xFF1A1A1A), // Dark text for white background
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
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
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            color: Colors.white, // Clean white background matching app branding
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0).copyWith(top: 10, bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.translate('consumption_title'),
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A), // Dark text for white background
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Pattern-first question
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!
                              .translate('consumption_patternQuestion'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF666666), // Dark gray for white background
                          ),
                        ),
                        const SizedBox(height: 8),
                        _patternTile(value: 'daily', labelKey: 'consumption_pattern_daily'),
                        _patternTile(value: 'fewDays', labelKey: 'consumption_pattern_fewDays'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.translate('consumption_averageTreatSize'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF666666), // Dark gray for white background
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildTreatSizeOption('small', '🍪', AppLocalizations.of(context)!.translate('consumption_small')),
                            _buildTreatSizeOption('medium', '🍦', AppLocalizations.of(context)!.translate('consumption_medium')),
                            _buildTreatSizeOption('large', '🍰', AppLocalizations.of(context)!.translate('consumption_large')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: Text(
                                AppLocalizations.of(context)!.translate('consumption_whyDoWeAskTitle'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontFamily: 'ElzaRound',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              content: Text(
                                AppLocalizations.of(context)!.translate('consumption_whyDoWeAskContent'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF666666),
                                  fontFamily: 'ElzaRound',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              actions: [
                                Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xFFed3272), // Strong pink/magenta
                                          Color(0xFFfd5d32), // Vivid orange
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 40,
                                          vertical: 10,
                                        ),
                                      ),
                                      child: Text(
                                        AppLocalizations.of(context)!.translate('consumption_gotIt'),
                                        style: const TextStyle(
                                          fontFamily: 'ElzaRound',
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 5.0),
                          child:                           Text(
                            AppLocalizations.of(context)!.translate('consumption_whyDoWeAsk'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 13,
                              fontWeight: FontWeight.w600, // Slightly bolder instead of underline
                              color: Color(0xFFed3272), // Brand pink like other links
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Removed Skip test link per request
                    const SizedBox(height: 80),
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
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          _saveToUserAnswers();
                          await _saveConsumptionDataToPrefs();
                          MixpanelService.trackEvent(
                            'Onboarding Question Consumption Summary Data Set',
                            properties: {
                              'sugary_treats_per_week': _sugaryTreatsPerWeek,
                              'consumption_level': _getConsumptionLevel().split(' (')[0],
                              'formatted_consumption_level': _getConsumptionLevel(),
                              'treat_size': _selectedTreatSize,
                              'calories_per_week': _caloriesPerWeek,
                              'calories_per_quarter': _caloriesPerQuarter,
                              'calories_per_year': _caloriesPerYear,
                            }
                          );
                          Navigator.of(context).push(
                            FadePageRoute(
                              child: InsightsScreen(
                                userAnswers: widget.userAnswers,
                                onNext: () {
                                  widget.onNext();
                                },
                                onPrevious: () => Navigator.pop(context),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          minimumSize: const Size(double.infinity, 44),
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
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 