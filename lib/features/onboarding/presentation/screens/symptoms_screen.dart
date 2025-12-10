import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/features/onboarding/data/repositories/questionnaire_repository.dart';
import 'profile_info_screen.dart'; // Import the ProfileInfoScreen
import 'sugar_drug_screen.dart'; // Import the SugarDrugScreen
import 'package:stoppr/features/onboarding/presentation/screens/mock_recipes_video_screen.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart'; // Added import
import 'package:stoppr/core/utils/text_sanitizer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Custom route transition for slide animation
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final bool slideFromRight;
  
  SlidePageRoute({required this.page, this.slideFromRight = true})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final begin = slideFromRight ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutQuart;
            
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            
            return SlideTransition(position: offsetAnimation, child: child);
          },
        );
}

class SymptomsScreen extends StatefulWidget {
  final VoidCallback? onRebootBrain;
  
  const SymptomsScreen({
    super.key,
    this.onRebootBrain,
  });

  @override
  State<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends State<SymptomsScreen> {
  // Track selected English symptom texts
  final Set<String> _selectedSymptoms = {};
  final QuestionnaireRepository _questionnaireRepository = QuestionnaireRepository();
  bool _isSaving = false;
  final OnboardingProgressService _progressService = OnboardingProgressService();
  ScrollController? _scrollController;
  bool _showScrollIndicator = true;
  
  // Define symptom categories and their items using localization keys and English text
  // The main key for the map is the localization key for the category title.
  final Map<String, List<Map<String, String>>> _symptomsCategories = {
    'symptoms_category_mental': [
      {'key': 'symptoms_mental_unmotivated', 'en': 'Feeling unmotivated'},
      {'key': 'symptoms_mental_ambition', 'en': 'Lack of ambition to pursue goals'},
      {'key': 'symptoms_mental_concentrating', 'en': 'Difficulty concentrating'},
      {'key': 'symptoms_mental_memory', 'en': "Poor memory or 'brain fog'"},
      {'key': 'symptoms_mental_anxiety', 'en': 'General anxiety'},
    ],
    'symptoms_category_physical': [
      {'key': 'symptoms_physical_tiredness', 'en': 'Tiredness and lethargy'},
      {'key': 'symptoms_physical_libido', 'en': 'Low libido or sex drive'},
      {'key': 'symptoms_physical_energy', 'en': 'Low energy without sugar'},
    ],
    'symptoms_category_social': [
      {'key': 'symptoms_social_confidence', 'en': 'Low self-confidence'},
      {'key': 'symptoms_social_unattractive', 'en': 'Feeling unattractive or unworthy of love'},
      {'key': 'symptoms_social_sex', 'en': 'Unsuccessful or unenjoyable sex'},
      {'key': 'symptoms_social_desireToSocialize', 'en': 'Reduced desire to socialize'},
      {'key': 'symptoms_social_isolated', 'en': 'Feeling isolated from others'},
    ],
    'symptoms_category_faith': [
      {'key': 'symptoms_faith_distantGod', 'en': 'Feeling distant from god'},
    ],
  };
  
  @override
  void initState() {
    super.initState();
    
    _scrollController = ScrollController();
    _scrollController!.addListener(_onScroll);
    
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for white background
      statusBarBrightness: Brightness.light, // For iOS
    ));
    
    // Track page view
    // MixpanelService.trackPageView('Symptoms Screen'); // Old format
    MixpanelService.trackPageView('Onboarding Symptoms Screen'); // New format
    
    // Save current screen
    _saveCurrentScreen();
  }
  
  @override
  void dispose() {
    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for white background
      statusBarBrightness: Brightness.light, // For iOS
    ));
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController == null) return;
    // Hide arrows as soon as user starts scrolling
    final shouldShow = _scrollController!.offset <= 0; // Hide immediately after any scroll
    if (_showScrollIndicator != shouldShow) {
      setState(() {
        _showScrollIndicator = shouldShow;
      });
    }
  }
  
  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.symptomsScreen);
  }
  
  void _toggleSymptom(Map<String, String> symptomData) {
    final String? symptomEnglishText = symptomData['en'];
    if (symptomEnglishText == null) {
      debugPrint('Warning: symptomData missing en key: $symptomData');
      return;
    }
    setState(() {
      if (_selectedSymptoms.contains(symptomEnglishText)) {
        _selectedSymptoms.remove(symptomEnglishText);
      } else {
        _selectedSymptoms.add(symptomEnglishText);
      }
    });
  }
  
  Future<void> _handleRebootBrain() async {
    // Check if widget is still mounted
    if (!mounted) return;
    
    // Prevent multiple taps
    if (_isSaving) return;
    
    setState(() {
      _isSaving = true;
    });
    
    // Save selected English symptoms to Firebase if user is authenticated
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await _questionnaireRepository.saveSymptoms(
          userId: currentUser.uid,
          symptoms: _selectedSymptoms, // This now contains English strings
        );
        
        // Track selected English symptoms in Mixpanel
        MixpanelService.trackEvent('Onboarding Symptoms Selected', properties: {
          'selected_symptoms': _selectedSymptoms.toList(),
          'symptom_count': _selectedSymptoms.length,
          'user_id': currentUser.uid,
        });
        
      } catch (e) {
        // Track error saving symptoms
        MixpanelService.trackEvent('Onboarding Symptoms Save Error', properties: {
          'error': e.toString(),
          'user_id': currentUser.uid,
        });
        // Continue with flow even if save fails
      }
    }
    
    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
    
    // Continue with navigation
    if (widget.onRebootBrain != null) {
      widget.onRebootBrain?.call();
    } else {
      // Check if widget is still mounted before navigation
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MockRecipesVideoScreen(),
          ),
        );
      }
    }
  }

  Widget _buildScrollIndicator() {
    // Hide scroll indicator on large screens like iPad
    if (MediaQuery.of(context).size.width >= 768) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      bottom: 180, // Position above the continue button
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        opacity: _showScrollIndicator ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black,
                size: 40,
              ),
              SizedBox(height: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black,
                size: 40,
              ),
              SizedBox(height: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black,
                size: 40,
              ),
            ],
          ).animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          ).moveY(
            begin: -8,
            end: 8,
            duration: 1.5.seconds,
            curve: Curves.easeInOut,
          ).fadeIn(duration: 600.ms),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations? l10n = AppLocalizations.of(context);
    if (l10n == null) {
      // Return loading indicator if localization is not ready
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            color: Colors.white, // Clean white background matching app branding
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Custom header with back button and title
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              l10n.translate('symptoms_title'),
                              style: const TextStyle(
                                fontFamily: 'ElzaRound',
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A), // Dark text for white background
                              ),
                              maxLines: null,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 96, top: 24), 
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                  border: Border.all(color: Colors.white.withOpacity(0.2))
                                ),
                                child: Text(
                                  l10n.translate('symptoms_infoBox'),
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                child: Text(
                                  l10n.translate('symptoms_selectInstruction'),
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A), // Dark text for white background
                                  ),
                                ),
                              ),
                              ..._symptomsCategories.entries.map((categoryEntry) {
                                final String categoryKey = categoryEntry.key;
                                final List<Map<String, String>> symptomsData = categoryEntry.value;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 12),
                                      child: Text(
                                        l10n.translate(categoryKey),
                                        style: const TextStyle(
                                          fontFamily: 'ElzaRound',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF666666), // Dark gray for white background
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      child: Column(
                                        children: symptomsData.map((symptomData) => _buildSymptomItem(symptomData)).toList(),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Scroll indicator
                _buildScrollIndicator(),
                
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          offset: const Offset(0, -2),
                          blurRadius: 4,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: GestureDetector(
                      onTap: _isSaving ? null : _handleRebootBrain,
                      child: Container(
                        width: double.infinity,
                        height: 56,
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
                        child: Center(
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : Text(
                                  l10n.translate('symptoms_rebootBrainButton'),
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 19, // Increased from 16 to 19
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
        ),
      ),
    );
  }
  
  Widget _buildSymptomItem(Map<String, String> symptomData) {
    final String symptomKey = symptomData['key']!;
    final String symptomEnglishText = symptomData['en']!;
    final String translatedSymptomText = AppLocalizations.of(context)!.translate(symptomKey);
    final bool isSelected = _selectedSymptoms.contains(symptomEnglishText);
    
    final Map<String, String> boldWordMap = {
      // Keys here are the ENGLISH symptom texts, values are the English bold words
      'Feeling unmotivated': 'unmotivated',
      'Lack of ambition to pursue goals': 'ambition',
      'Difficulty concentrating': 'concentrating',
      "Poor memory or 'brain fog'": 'memory',
      'General anxiety': 'anxiety',
      'Tiredness and lethargy': 'Tiredness',
      'Low libido or sex drive': 'libido',
      'Low energy without sugar': 'energy',
      'Low self-confidence': 'self-confidence',
      'Feeling unattractive or unworthy of love': 'unattractive',
      'Unsuccessful or unenjoyable sex': 'Unsuccessful',
      'Reduced desire to socialize': 'socialize',
      'Feeling isolated from others': 'isolated',
      'Feeling distant from god': 'distant',
    };
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _toggleSymptom(symptomData),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            ),
            child: Row(
              children: [
                isSelected
                    ? const Icon(
                        Icons.check_circle,
                        color: Colors.white, // White checkmark on gradient background
                        size: 29,
                      )
                    : Container(
                        width: 29,
                        height: 29,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF999999), // Gray circle for white background
                            width: 2.0,
                          ),
                        ),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRichText(translatedSymptomText, boldWordMap[symptomEnglishText] ?? '', isSelected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRichText(String text, String boldPart, bool isSelected) {
    // Sanitize input strings to prevent UTF-16 crashes
    final safeText = TextSanitizer.sanitizeForDisplay(text);
    final safeBoldPart = TextSanitizer.sanitizeForDisplay(boldPart);
    
    // Choose text color based on selection state
    final textColor = isSelected ? Colors.white : const Color(0xFF1A1A1A);
    
    // If boldPart is empty or not found in text, return normal Text widget
    if (safeBoldPart.isEmpty || !safeText.contains(safeBoldPart)) {
      return Text(
        safeText,
        style: TextStyle(
          fontFamily: 'ElzaRound',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor, // White on gradient, dark on white background
        ),
      );
    }
    
    try {
      final int startIndex = safeText.indexOf(safeBoldPart);
      final int endIndex = startIndex + safeBoldPart.length;
      
      return RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'ElzaRound',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textColor, // White on gradient, dark on white background
          ),
          children: [
            TextSpan(
              text: TextSanitizer.safeSubstring(
                safeText,
                0,
                startIndex,
              ),
            ),
            TextSpan(
              text: TextSanitizer.safeSubstring(
                safeText,
                startIndex,
                endIndex,
              ),
              style: TextStyle(
                fontFamily: 'ElzaRound',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor, // White on gradient, dark on white background
              ),
            ),
            TextSpan(
              text: TextSanitizer.safeSubstring(
                safeText,
                endIndex,
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error building rich text: $e');
      // Fallback to simple text if string manipulation fails
      return Text(
        safeText,
        style: TextStyle(
          fontFamily: 'ElzaRound',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor, // White on gradient, dark on white background
        ),
      );
    }
  }
} 