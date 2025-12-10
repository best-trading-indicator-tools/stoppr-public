import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../../../core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/config/env_config.dart';
import '../../../../../core/navigation/page_transitions.dart';
import '../../../../../core/api_rate_limit/api_rate_limit_service.dart';
import '../../../../../core/models/food_alternative.dart';
import '../../../../../core/services/in_app_review_service.dart';
import 'widgets/alternative_slides/slides.dart';
import 'food_scan_screen.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import '../../../../../core/subscription/subscription_service.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart'; // Add Superwall import
import 'package:stoppr/core/utils/text_sanitizer.dart';

class FoodAlternativesScreen extends StatefulWidget {
  final File imageFile;
  
  const FoodAlternativesScreen({
    Key? key,
    required this.imageFile,
  }) : super(key: key);

  @override
  State<FoodAlternativesScreen> createState() => _FoodAlternativesScreenState();
}

class _FoodAlternativesScreenState extends State<FoodAlternativesScreen> {
  bool _isLoading = true;
  String _detectedFoodName = '';
  String _detectedFoodDescription = '';
  String _detectedFoodHealthConcerns = '';
  List<FoodAlternative> _alternatives = [];
  String _errorMessage = '';
  bool _rateLimitExceeded = false;
  final InAppReviewService _reviewService = InAppReviewService();
  int _reviewTriggerSlideIndex = -1;
  bool _reviewRequestedForTriggerSlide = false;
  
  // Page controller for the slides
  late final PageController _pageController;
  int _currentPage = 0;
  
  // Loading messages
  late List<String> _loadingMessages;
  late String _currentLoadingMessage;
  Timer? _messageTimer;
  bool _dependenciesInitialized = false;
  
  // Retry logic for API failures
  int _retryAttempts = 0;
  static const int _maxRetryAttempts = 3;

  @override
  void initState() {
    super.initState();
    // DO NOT initialize l10n-dependent things here
    
    // Initialize page controller
    _pageController = PageController(initialPage: 0);
    
    // Force status bar icons to dark mode for light background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for light background
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
    ));
    
    // Track page view with Mixpanel
    MixpanelService.trackPageView('Food Alternatives Screen');
    
    // DO NOT call _analyzeImageAndGetAlternatives() here - it needs context
    // It will be called in didChangeDependencies() instead
  }
  
  @override
  void dispose() {
    _messageTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  double _asDoubleFlexible(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) {
      final parsed = double.tryParse(v.trim());
      return parsed ?? 0;
    }
    return 0;
  }

  int _asIntFlexible(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final parsed = num.tryParse(v.trim());
      return parsed?.toInt() ?? 0;
    }
    return 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dependenciesInitialized) {
      final l10n = AppLocalizations.of(context)!;
      // Initialize with a random message
      _loadingMessages = [
        l10n.translate('foodAlternatives_loading_message1'),
        l10n.translate('foodAlternatives_loading_message2'),
        l10n.translate('foodAlternatives_loading_message3'),
        l10n.translate('foodAlternatives_loading_message4'),
        l10n.translate('foodAlternatives_loading_message5'),
        l10n.translate('foodAlternatives_loading_message6'),
        l10n.translate('foodAlternatives_loading_message7'),
        l10n.translate('foodAlternatives_loading_message8'),
        l10n.translate('foodAlternatives_loading_message9'),
        l10n.translate('foodAlternatives_loading_message10'),
      ];
      if (_loadingMessages.isNotEmpty) {
        _currentLoadingMessage = _loadingMessages[Random().nextInt(_loadingMessages.length)];
      } else {
        _currentLoadingMessage = l10n.translate('foodAlternatives_loading_fallback'); // Fallback if list is somehow still empty
      }

      // Start rotating messages every 3 seconds
      _messageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted && _isLoading) {
          setState(() {
            _currentLoadingMessage = _loadingMessages[Random().nextInt(_loadingMessages.length)];
          });
        }
      });

      // Mark dependencies as initialized to prevent re-running
      _dependenciesInitialized = true;

      // Analyze the image and get alternatives
      _analyzeImageAndGetAlternatives();
    }
  }

  Future<void> _analyzeImageAndGetAlternatives() async {
    try {
      // Check rate limit before making the API call
      final bool canRequest = await ApiRateLimitService.canMakeRequest();
      if (!canRequest) {
        if (!mounted) return;
        final remainingRequests = await ApiRateLimitService.getRemainingRequests();
        final currentCount = await ApiRateLimitService.getCurrentCount();
        final dailyLimit = currentCount + remainingRequests; // Correctly derive the daily limit
        final l10n = AppLocalizations.of(context)!;
        if (!mounted) return;
        setState(() {
          _rateLimitExceeded = true;
          _errorMessage = l10n
              .translate('foodAlternatives_error_rateLimitExceeded')
              .replaceFirst('{currentCount}', currentCount.toString())
              .replaceFirst('{dailyLimit}', dailyLimit.toString());
          _isLoading = false;
        });
        return;
      }
      
      // Call the OpenAI API with the image
      
      // 1. Read the file as bytes and convert to base64
      final List<int> imageBytes = await widget.imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);
      
      // 2. Set up the Groq API request
      final apiKey = EnvConfig.groqApiKey ?? '';
      if (apiKey.isEmpty) {
        if (!mounted) return;
        throw Exception(AppLocalizations.of(context)!.translate('foodAlternatives_error_apiKeyNotConfigured'));
      }
      
      // 3. Make the API request
      debugPrint('Sending image to Groq for analysis...');
      
      // Get the current time to provide context for meal recommendations
      final now = DateTime.now();
      final currentHour = now.hour;
      
      // Determine the meal time based on the current hour
      String mealTime = "snack";
      if (currentHour >= 5 && currentHour < 10) {
        mealTime = "breakfast";
      } else if (currentHour >= 10 && currentHour < 14) {
        mealTime = "lunch";
      } else if (currentHour >= 17 && currentHour < 22) {
        mealTime = "dinner";
      }
      
      // Get current app language
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final String languageCode = l10n.locale.languageCode;
      final String languageName = l10n.translate('language_name_for_api'); // e.g., 'English', 'Spanish'

      final Stopwatch apiCallStopwatch = Stopwatch()..start(); // Start timing API call
      
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'meta-llama/llama-4-maverick-17b-128e-instruct',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': "Please provide your response in the following language: $languageName ($languageCode). All parts of your JSON response, including names, descriptions, benefits, recipes, health concerns, impact explanations, and any other textual content, must be in $languageName ($languageCode). \n\n"
                  "Analyze this image of food. Identify what it is and explain in detail why it might be unhealthy or cause problems (focus on sugar, processed ingredients, etc.). Then suggest ONE healthier alternative that's a direct substitute. "
                  "IMPORTANT: The alternative should be a healthier version of the same dish, replacing unhealthy ingredients with healthier ones. "
                  "CURRENT TIME CONTEXT: It is currently $mealTime time (${now.hour}:${now.minute.toString().padLeft(2, '0')}). "
                  "PRIORITIZE suggesting alternatives that are APPROPRIATE FOR $mealTime, VERY EASY TO BUY (common ingredients available in most stores), and EXTREMELY QUICK & EASY TO PREPARE (UNDER 10 MINUTES TOTAL PREP/COOK TIME with minimal steps). People are lazy and won't cook complex recipes, so keep it extremely simple. Ideally suggest options that require almost no preparation at all. "
                  "For example: if it's pizza at dinner time, suggest a pizza with cauliflower crust instead of bread and healthier toppings. "
                  "If it's a breakfast cereal in the morning, suggest a protein-rich breakfast alternative like eggs with vegetables. "
                  "SINGLE-INGREDIENT EDGE CASE: If the image shows a simple single-ingredient food (like chocolate, cookies, white bread, candy, pastries, etc.), consider that the person might be craving it due to a nutrient deficiency. In this case: "
                  "1. Identify the potential nutrient deficiency (e.g., chocolate cravings = magnesium deficiency, bread/carb cravings = chromium or B vitamin deficiency, ...) "
                  "2. Recommend a whole food alternative rich in the missing nutrient (e.g., for chocolate craving, suggest almonds, pumpkin seeds, or spinach for magnesium; for bread cravings, suggest sweet potatoes or eggs for chromium/B vitamins, etc.) "
                  "3. Explain how addressing the underlying deficiency may reduce cravings for the unhealthy food "
                  "DO NOT suggest cereals, grains, or any foods that could trigger an insulin spike. "
                  "Focus on protein-rich options with fresh vegetables, fruits, and water or zero-calorie drinks. "
                  "Provide detailed and scientifically-backed benefits of the alternative, explaining exactly why it's better for health, metabolism, weight management, and mental clarity. "
                  "Also include a basic recipe with preparation steps, nutritional comparison data for key nutrients, a health improvement score (0-100), and a preparation difficulty rating (1-5 with 5 being most difficult)."
                  "IMPORTANT: Include information about the blood sugar impact of both the original food and the healthier alternative. "
                  "Explain how each food affects insulin levels, glucose response, and overall glycemic impact. "
                  "For the blood sugar impact scores, use a 0-100 scale where HIGHER SCORES MEAN WORSE IMPACT (more blood sugar elevation). "
                  "The original unhealthy food should typically have a high score (75-95) and the healthier alternative should have a lower score (20-40). "
                  "INCLUDE GLYCEMIC INDEX: Provide the specific glycemic index (GI) range for both foods. Low GI: 0-55, Medium GI: 56-69, High GI: 70+. "
                  "MEAL TIMING: Explain how consuming this food at different times of day (breakfast, lunch, dinner, or as a snack) affects blood sugar differently. "
                  "COST COMPARISON: Include a cost comparison between the original and alternative options (use \$ for low cost, \$\$ for medium, \$\$\$ for high). "
                  "INCLUDE CITATIONS: For each health claim, nutritional information, or medical statement, provide at least 3-5 scientific sources or citations. Include title, authors, publication, year, and URL if available. Ensure these are reputable medical or nutritional sources."
                  "Format your response as JSON with these fields: "
                  "{\"detected_food\": {\"name\": \"...\", \"description\": \"...\", \"health_concerns\": \"...\"}, "
                  "\"alternatives\": [{\"name\": \"...\", \"description\": \"...\", \"benefits\": \"...\", \"detailed_benefits\": \"...\", \"image_query\": \"...\", "
                  "\"ingredients\": [{\"name\": \"cauliflower\", \"quantity\": \"1\", \"unit\": \"cup\", \"note\": \"chopped\", \"emoji\": \"🥦\"}], "
                  "\"recipe\": \"Short notes/tips if needed\", \"preparation_steps\": [\"Step 1: ...\", \"Step 2: ...\"], "
                  "\"nutritional_comparison\": {\"calories\": {\"original\": {\"value\": 0, \"unit\": \"kcal\"}, \"alternative\": {\"value\": 0, \"unit\": \"kcal\"}}, "
                  "\"carbs\": {\"original\": {\"value\": 0, \"unit\": \"g\"}, \"alternative\": {\"value\": 0, \"unit\": \"g\"}}, "
                  "\"protein\": {\"original\": {\"value\": 0, \"unit\": \"g\"}, \"alternative\": {\"value\": 0, \"unit\": \"g\"}}, "
                  "\"fat\": {\"original\": {\"value\": 0, \"unit\": \"g\"}, \"alternative\": {\"value\": 0, \"unit\": \"g\"}}, "
                  "\"sugar\": {\"original\": {\"value\": 0, \"unit\": \"g\"}, \"alternative\": {\"value\": 0, \"unit\": \"g\"}}, "
                  "\"fiber\": {\"original\": {\"value\": 0, \"unit\": \"g\"}, \"alternative\": {\"value\": 0, \"unit\": \"g\"}}}, "
                  "\"glycemic_index\": {\"original\": {\"value\": 0, \"category\": \"Low/Medium/High\"}, \"alternative\": {\"value\": 0, \"category\": \"Low/Medium/High\"}}, "
                  "\"meal_timing\": {\"breakfast\": \"...\", \"lunch\": \"...\", \"dinner\": \"...\", \"snack\": \"...\"}, "
                  "\"cost_comparison\": {\"original\": \"\$\", \"alternative\": \"\$\$\", \"description\": \"Explanation of cost difference\"}, "
                  "\"blood_sugar_impact\": {\"original_impact\": \"Detailed explanation of how the original food impacts blood sugar\", "
                  "\"alternative_impact\": \"Detailed explanation of how the alternative food impacts blood sugar\", "
                  "\"original_score\": 75-95, \"alternative_score\": 20-40}, "
                  "\"sources\": [{\"title\": \"Title of source\", \"authors\": \"Author names\", \"publication\": \"Journal/Publication name\", \"year\": \"Publication year\", \"url\": \"URL if available\", \"description\": \"Brief description of what this source supports\"}], "
                  "\"health_score\": 0, \"preparation_difficulty\": 0, "
                  "\"bloat_index\": {\"score\": 78, \"description\": \"This food causes significant bloating\", \"skin_effects\": {\"puffiness\": \"Makes face appear puffy and swollen\", \"redness\": \"Increases facial redness and inflammation\", \"texture\": \"Makes skin appear rough and uneven\"}}}}]}\""
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image'
                  }
                }
              ]
            }
          ],
          'max_tokens': 1800,
        }),
      );
      
      apiCallStopwatch.stop(); // Stop timing API call
      debugPrint('Groq API call duration: ${apiCallStopwatch.elapsedMilliseconds}ms'); // Log API call duration
      
      // Increment the request counter after a successful response (status 200)
      if (response.statusCode == 200) {
        await ApiRateLimitService.incrementRequestCount();
        if (!mounted) return;
        _isLoading = false;
        _retryAttempts = 0; // Reset retry counter on success
      } else {
        // Handle API errors without incrementing the count
        if (!mounted) return;
        throw Exception(
          AppLocalizations.of(context)!
              .translate('foodAlternatives_error_failedToAnalyze')
              .replaceFirst(
                '{responseBody}',
                TextSanitizer.sanitizeForDisplay(
                  utf8.decode(
                    response.bodyBytes,
                    allowMalformed: true,
                  ),
                ),
              ),
        );
      }
      
      // Decode the response body using UTF-8
      final decodedBody = utf8.decode(response.bodyBytes);
      final responseBody = jsonDecode(decodedBody);
      final jsonResponseString = responseBody['choices'][0]['message']['content'];
      debugPrint('Received response from Groq: $jsonResponseString');
      
      // Try to parse the JSON response
      try {
        // Fix JSON parsing by removing markdown code block indicators if present
        String cleanJsonString = jsonResponseString;
        if (cleanJsonString.startsWith('```')) {
          // Remove markdown code block formatting
          cleanJsonString = cleanJsonString
              .replaceAll(RegExp(r'^```json\s*'), '')
              .replaceAll(RegExp(r'\s*```$'), '')
              .trim();
        }
        
        final jsonResponse = jsonDecode(cleanJsonString);
        
        // Process the response
        if (!mounted) return;
        setState(() {
          _detectedFoodName = TextSanitizer.sanitizeForDisplay(jsonResponse["detected_food"]["name"] ?? "Unknown Food");
          _detectedFoodDescription = TextSanitizer.sanitizeForDisplay(jsonResponse["detected_food"]["description"] ?? "");
          _detectedFoodHealthConcerns = TextSanitizer.sanitizeForDisplay(jsonResponse["detected_food"]["health_concerns"] ?? "");
          
          _alternatives = (jsonResponse["alternatives"] as List).map((alternative) {
            // Parse nutritional comparison data if available
            Map<String, Map<String, NutritionalData>>? nutritionalComparison;
            
            if (alternative["nutritional_comparison"] != null) {
              nutritionalComparison = {};
              final comparisonData = alternative["nutritional_comparison"] as Map<String, dynamic>;
              
              comparisonData.forEach((nutrient, values) {
                final originalData = values["original"];
                final alternativeData = values["alternative"];
                
                nutritionalComparison![nutrient] = {
                  "original": NutritionalData(
                    value: _asDoubleFlexible(originalData["value"]),
                    unit: originalData["unit"] ?? "",
                  ),
                  "alternative": NutritionalData(
                    value: _asDoubleFlexible(alternativeData["value"]),
                    unit: alternativeData["unit"] ?? "",
                  ),
                };
              });
            }
            
            // Parse preparation steps if available
            List<String>? preparationSteps;
            if (alternative["preparation_steps"] != null) {
              preparationSteps = (alternative["preparation_steps"] as List)
                  .map((step) {
                    // Sanitize each preparation step
                    String fixedStep = TextSanitizer.sanitizeForDisplay(step.toString());
                    return fixedStep;
                  })
                  .toList();
            }
            
            return FoodAlternative(
              name: TextSanitizer.sanitizeForDisplay(alternative["name"] ?? "Healthier Alternative"),
              description: TextSanitizer.sanitizeForDisplay(alternative["description"] ?? ""),
              benefits: TextSanitizer.sanitizeForDisplay(alternative["benefits"] ?? ""),
              detailedBenefits: alternative["detailed_benefits"] != null ? TextSanitizer.sanitizeForDisplay(alternative["detailed_benefits"]) : null,
              nutritionalComparison: nutritionalComparison,
              preparationDifficulty: alternative["preparation_difficulty"] as int? ?? 3,
              healthScore: alternative["health_score"] as int? ?? 75,
              recipe: alternative["recipe"] != null ? TextSanitizer.sanitizeForDisplay(alternative["recipe"]) : null,
              ingredients: alternative["ingredients"] != null ? (alternative["ingredients"] as List).map((ing) => Ingredient(
                name: TextSanitizer.sanitizeForDisplay(ing["name"]?.toString() ?? ""),
                quantity: ing["quantity"]?.toString(),
                unit: ing["unit"]?.toString(),
                note: ing["note"] != null ? TextSanitizer.sanitizeForDisplay(ing["note"]) : null,
                emoji: ing["emoji"]?.toString(),
              )).toList() : null,
              preparationSteps: preparationSteps,
              bloodSugarImpact: alternative["blood_sugar_impact"] != null ? BloodSugarImpact(
                originalImpact: TextSanitizer.sanitizeForDisplay(alternative["blood_sugar_impact"]["original_impact"] ?? "High impact on blood sugar"),
                alternativeImpact: TextSanitizer.sanitizeForDisplay(alternative["blood_sugar_impact"]["alternative_impact"] ?? "Lower impact on blood sugar"),
                originalScore: alternative["blood_sugar_impact"]["original_score"] as int? ?? 80,
                alternativeScore: alternative["blood_sugar_impact"]["alternative_score"] as int? ?? 30,
              ) : null,
              glycemicIndex: alternative["glycemic_index"] != null ? GlycemicIndex(
                originalValue: _asIntFlexible(alternative["glycemic_index"]["original"]["value"]),
                originalCategory: TextSanitizer.sanitizeForDisplay(alternative["glycemic_index"]["original"]["category"] ?? ""),
                alternativeValue: _asIntFlexible(alternative["glycemic_index"]["alternative"]["value"]),
                alternativeCategory: TextSanitizer.sanitizeForDisplay(alternative["glycemic_index"]["alternative"]["category"] ?? ""),
              ) : null,
              mealTiming: alternative["meal_timing"] != null ? MealTiming(
                breakfast: TextSanitizer.sanitizeForDisplay(alternative["meal_timing"]["breakfast"] ?? ""),
                lunch: TextSanitizer.sanitizeForDisplay(alternative["meal_timing"]["lunch"] ?? ""),
                dinner: TextSanitizer.sanitizeForDisplay(alternative["meal_timing"]["dinner"] ?? ""),
                snack: TextSanitizer.sanitizeForDisplay(alternative["meal_timing"]["snack"] ?? ""),
              ) : null,
              costComparison: alternative["cost_comparison"] != null ? CostComparison(
                original: TextSanitizer.sanitizeForDisplay(alternative["cost_comparison"]["original"] ?? ""),
                alternative: TextSanitizer.sanitizeForDisplay(alternative["cost_comparison"]["alternative"] ?? ""),
                description: TextSanitizer.sanitizeForDisplay(alternative["cost_comparison"]["description"] ?? ""),
              ) : null,
              sources: alternative["sources"] != null ? (alternative["sources"] as List).map((source) => Source(
                title: TextSanitizer.sanitizeForDisplay(source["title"] ?? "Unknown Source"),
                authors: source["authors"] != null ? TextSanitizer.sanitizeForDisplay(source["authors"]) : null,
                publication: source["publication"] != null ? TextSanitizer.sanitizeForDisplay(source["publication"]) : null,
                year: source["year"] != null ? TextSanitizer.sanitizeForDisplay(source["year"].toString()) : null,
                url: source["url"] as String?, // URLs don't need sanitization
                description: source["description"] != null ? TextSanitizer.sanitizeForDisplay(source["description"]) : null,
              )).toList() : null,
              bloatInfo: alternative["bloat_index"] != null ? BloatInfo(
                score: alternative["bloat_index"]["score"] ?? 0,
                description: TextSanitizer.sanitizeForDisplay(alternative["bloat_index"]["description"] ?? ""),
                skinEffects: alternative["bloat_index"]["skin_effects"] != null ? 
                  (alternative["bloat_index"]["skin_effects"] as Map).map((key, value) => 
                    MapEntry(key.toString(), TextSanitizer.sanitizeForDisplay(value.toString()))
                  ) : null,
              ) : null,
            );
          }).toList();
          
          _isLoading = false;
        });
      } catch (jsonError) {
        debugPrint('Error parsing JSON response: $jsonError');
        if (_retryAttempts < _maxRetryAttempts) {
          _retryAttempts++;
          debugPrint('Retrying Groq call due to JSON error (attempt $_retryAttempts/$_maxRetryAttempts)');
          if (!mounted) return;
          await _analyzeImageAndGetAlternatives();
          return;
        }
        if (!mounted) return;
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.translate('foodAlternatives_error_parsingResponse');
          _isLoading = false;
        });
      }
      
    } catch (e) {
      debugPrint('Error analyzing image: $e');
      if (_retryAttempts < _maxRetryAttempts) {
        _retryAttempts++;
        debugPrint('Retrying Groq call (attempt $_retryAttempts/$_maxRetryAttempts)');
        if (!mounted) return;
        await _analyzeImageAndGetAlternatives();
        return;
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context)!.translate('foodAlternatives_error_generic');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FA), // New branding: soft pink-tinted white
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)), // Dark icons for light background
        title: const SizedBox.shrink(),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // Dark icons for light background
          statusBarBrightness: Brightness.light, // For iOS
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Replace the current screen with a new instance of FoodScanScreen
            // This ensures the scan state is reset
            Navigator.of(context).pushReplacement(
              TopToBottomPageRoute(
                child: const FoodScanScreen(),
                settings: const RouteSettings(name: '/food_scan'),
              ),
            );
          },
        ),
        actions: [
          // Help & Info icon
          IconButton(
            icon: const Icon(
              Icons.help_outline,
              color: Color(0xFF1A1A1A), // Dark icon for light background
              size: 28,
            ),
            onPressed: _openMedicalInfo,
            tooltip: AppLocalizations.of(context)!.translate('foodAlternatives_tooltip_helpAndInfo'),
          ),
        ],
      ),
      body: _isLoading 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Lottie animation or improved spinner
                  SizedBox(
                    height: 300,
                    width: 300,
                    child: Lottie.asset(
                      'assets/images/lotties/Cooking.json',
                      repeat: true,
                      animate: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Animated loading text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        _currentLoadingMessage,
                        key: ValueKey<String>(_currentLoadingMessage),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A), // Primary dark text for light background
                          fontFamily: 'ElzaRound',
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .shimmer(
                        duration: 1.8.seconds,
                        color: Colors.white.withOpacity(0.7),
                        angle: 0,
                        size: 3,
                        curve: Curves.easeInOut,
                      )
                      .scale(
                        duration: 1.5.seconds,
                        begin: const Offset(1, 1),
                        end: const Offset(1.05, 1.05),
                        curve: Curves.easeInOut,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      AppLocalizations.of(context)!.translate('foodAlternatives_loading_eta'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF666666), // Secondary gray text for light background
                        fontFamily: 'ElzaRound',
                        fontSize: 16,
                      ),
                    )
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .shimmer(
                      duration: 1.8.seconds,
                      color: Colors.white.withOpacity(0.5),
                      angle: 0,
                      curve: Curves.easeInOut,
                      size: 3,
                    )
                    .scale(
                      duration: 1.5.seconds,
                      begin: const Offset(1, 1),
                      end: const Offset(1.03, 1.03),
                      curve: Curves.easeInOut,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _rateLimitExceeded ? Icons.timer_off_outlined : Icons.error_outline,
                          color: Color(_rateLimitExceeded ? 0xFFFF9800 : 0xFFed3272), // Orange for rate limit, brand pink for errors
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A), // Dark text for white background
                            fontFamily: 'ElzaRound',
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(_rateLimitExceeded ? 0xFFFF9800 : 0xFFed3272), // Brand pink for errors
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 4,
                          ),
                          child: Text(
                            _rateLimitExceeded ? AppLocalizations.of(context)!.translate('foodAlternatives_button_ok') : AppLocalizations.of(context)!.translate('foodAlternatives_button_tryAgain'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'ElzaRound',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  top: true,
                  bottom: false,
                  child: _buildResultsContent(),
                ),
    );
  }
  
  Widget _buildResultsContent() {
    if (_alternatives.isEmpty) {
      return const Center(
        child: Text(
          'No alternatives found',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'ElzaRound',
            fontSize: 18,
          ),
        ),
      );
    }
  
    final alternative = _alternatives[0];
    final slideWidgets = _buildSlideWidgets(alternative);

    // Find the index of GlycemicIndexSlide (target for review)
    _reviewTriggerSlideIndex = slideWidgets.indexWhere((widget) => widget is SizedBox && widget.child is GlycemicIndexSlide);
    if (_reviewTriggerSlideIndex == -1) {
       // Fallback: try finding GlycemicIndexSlide directly (if not wrapped in SizedBox)
      _reviewTriggerSlideIndex = slideWidgets.indexWhere((widget) => widget is GlycemicIndexSlide);
    }
    debugPrint('Review trigger slide (GlycemicIndexSlide) index: $_reviewTriggerSlideIndex');

    // Main content Column: Title + Expanded Stack (PageView + Indicator)
    return Column(
      children: [
        // Title for the current slide
        Padding(
          padding: const EdgeInsets.only(top: 16.0, left: 24, right: 24, bottom: 8),
          child: Text(
            _getSlideTitle(_currentPage, AppLocalizations.of(context)!),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _getSlideThemeColor(_currentPage),
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ).animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          ).shimmer(
            duration: 3.seconds,
            color: _getSlideThemeColor(_currentPage, true).withOpacity(0.5),
          ),
        ),
              
        // Expanded Stack containing PageView and Indicator
        Expanded(
          child: Stack(
            children: [
              // PageView fills the available space - Fix: Wrap in a SizedBox with constraints
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: double.infinity,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: slideWidgets.length,
                                     onPageChanged: (index) async {
                     // FEATURE FLAG: Temporarily disable quota system for A/B test
                     const bool QUOTA_SYSTEM_ENABLED = false; // Set to true to re-enable quota system
                     
                     // Add 50% gate - block slides 6+ (MealTiming, Benefits, ScientificSources, Recipe) (DISABLED for A/B test)
                     if (QUOTA_SYSTEM_ENABLED) {
                       final subscriptionService = SubscriptionService();
                       final isPaidSubscriber = await subscriptionService.isPaidSubscriber(null);
                       if (!isPaidSubscriber && index >= 6) {
                         // Block progression, show standard paywall
                         MixpanelService.trackButtonTap('Food Scan 50% Gate Paywall Shown');
                         _showStandardPaywall();
                         _pageController.previousPage(
                           duration: const Duration(milliseconds: 300), 
                           curve: Curves.easeOut
                         );
                         return;
                       }
                     }
                    
                    if (!mounted) return;
                    setState(() {
                      _currentPage = index;
                    });
                    // Check if the current slide is the target slide and review hasn't been requested yet
                    if (index == _reviewTriggerSlideIndex && _reviewTriggerSlideIndex != -1 && !_reviewRequestedForTriggerSlide) {
                      debugPrint('Review trigger slide (GlycemicIndexSlide) is now visible. Requesting review.');
                      _reviewService.requestReviewIfAppropriate(screenName: 'FoodAlternativesScreen - GlycemicIndexSlide');
                      _reviewRequestedForTriggerSlide = true; // Mark as requested
                    }
                  },
                  itemBuilder: (context, index) {
                    // Pre-build the slide with key to maintain state
                    return KeyedSubtree(
                      key: ValueKey('slide_$index'),
                      child: slideWidgets[index].animate()
                        .fadeIn(
                          duration: 400.ms, 
                          curve: Curves.easeOutCubic
                        )
                        .slideY(
                          begin: 0.05, 
                          end: 0,
                          duration: 500.ms, 
                          curve: Curves.easeOutCubic
                        ),
                    );
                  },
                ),
              ),
              // Page indicator positioned at the bottom center with better initial state handling
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  // Add a subtle background gradient that's more transparent
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF0D2032).withOpacity(0.6),
                        const Color(0xFF0D2032).withOpacity(0.9),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20), // Top padding for gradient
                      // Slide counter text with conditional opacity
                      AnimatedOpacity(
                        opacity: _currentPage == 0 ? 0.85 : 1.0, // Slightly more transparent on first slide
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getSlideThemeColor(_currentPage).withOpacity(0.9),
                                _getSlideThemeColor(_currentPage, true).withOpacity(0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _getSlideThemeColor(_currentPage).withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            "${_currentPage + 1}/${slideWidgets.length}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'ElzaRound',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ).animate(
                          onPlay: (controller) => controller.repeat(reverse: true),
                        ).scale(
                          duration: 2.seconds,
                          begin: const Offset(1, 1),
                          end: const Offset(1.05, 1.05),
                          curve: Curves.easeInOut,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Page indicator dots with conditional opacity
                      AnimatedOpacity(
                        opacity: _currentPage == 0 ? 0.7 : 1.0, // More transparent on first slide  
                        duration: const Duration(milliseconds: 300),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).padding.bottom + 20, // Respect safe area
                          ),
                          child: SmoothPageIndicator(
                            controller: _pageController,
                            count: slideWidgets.length,
                            effect: ExpandingDotsEffect(
                              dotHeight: 8,
                              dotWidth: 8,
                              activeDotColor: _getSlideThemeColor(_currentPage),
                              dotColor: const Color(0xFF556575),
                              spacing: 6,
                              expansionFactor: 2.5,
                            ),
                          ),
                        ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Get the title for each slide based on index
  String _getSlideTitle(int index, AppLocalizations l10n) {
    final alternative = _alternatives[0];
    final slideWidgets = _buildSlideWidgets(alternative);
    
    if (index >= slideWidgets.length) {
      return l10n.translate('foodAlternatives_title_foodAnalysis');
    }
    
    // Determine slide title based on the current page index
    switch (index) {
      case 0:
        return l10n.translate('foodAlternatives_title_scannedFoodAnalysis');
      case 1:
        return l10n.translate('foodAlternatives_title_healthierAlternative');
      case 2:
        return l10n.translate('foodAlternatives_title_nutritionalComparison');
      case 3:
        return l10n.translate('foodAlternatives_title_glycemicIndex');
      case 4:
        return l10n.translate('foodAlternatives_title_bloodSugarImpact');
      case 5:
        return l10n.translate('foodAlternatives_title_bloatingEffect');
      case 6:
        return l10n.translate('foodAlternatives_title_mealTiming');
      case 7:
        return l10n.translate('foodAlternatives_title_healthBenefits');
      case 8:
        return l10n.translate('foodAlternatives_title_scientificSources');
      case 9:
        return l10n.translate('foodAlternatives_title_recipePreparation');
      default:
        return l10n.translate('foodAlternatives_title_foodAnalysis');
    }
  }

  // Helper to build the list of slides
  List<Widget> _buildSlideWidgets(FoodAlternative alternative) {
    return [
      SizedBox(
        width: MediaQuery.of(context).size.width,
        height: double.infinity,
        child: DetectedFoodSlide(
          imageFile: widget.imageFile,
          detectedFoodName: _detectedFoodName,
          detectedFoodDescription: _detectedFoodDescription,
          detectedFoodHealthConcerns: _detectedFoodHealthConcerns,
        ),
      ),
      // Fix: Ensure AlternativeInfoSlide has an explicit parent size and proper wrapping
      SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: AlternativeInfoSlide(alternative: alternative),
      ),
      if (alternative.nutritionalComparison != null &&
          alternative.nutritionalComparison!.isNotEmpty)
        SizedBox(
          width: MediaQuery.of(context).size.width,
          height: double.infinity,
          child: NutritionalComparisonSlide(alternative: alternative),
        ),
      if (alternative.glycemicIndex != null)
        SizedBox(
          width: MediaQuery.of(context).size.width,
          height: double.infinity,
          child: GlycemicIndexSlide(alternative: alternative),
        ),
      if (alternative.bloodSugarImpact != null)
        SizedBox(
          width: MediaQuery.of(context).size.width,
          height: double.infinity,
          child: BloodSugarImpactSlide(alternative: alternative),
        ),
      // New Bloating Effect Slide - always included for teen audience focus
      SizedBox(
        width: MediaQuery.of(context).size.width,
        height: double.infinity,
        child: BloatingEffectSlide(
          alternative: alternative,
          originalHealthConcerns: _detectedFoodHealthConcerns,
        ),
      ),
      if (alternative.mealTiming != null)
        SizedBox(
          width: MediaQuery.of(context).size.width,
          height: double.infinity,
          child: MealTimingSlide(alternative: alternative),
        ),
      SizedBox(
        width: MediaQuery.of(context).size.width,
        height: double.infinity,
        child: BenefitsSlide(alternative: alternative),
      ),
      if (alternative.sources != null && alternative.sources!.isNotEmpty)
        SizedBox(
          width: MediaQuery.of(context).size.width,
          height: double.infinity,
          child: _wrapWithBottomPadding(ScientificSourcesSlide(alternative: alternative)),
        ),
      if (alternative.recipe != null && alternative.preparationSteps != null)
        SizedBox(
          width: MediaQuery.of(context).size.width,
          height: double.infinity,
          child: _wrapWithBottomPadding(RecipeSlide(alternative: alternative)),
        ),
    ];
  }
  
  // Helper to add extra bottom padding to slides with longer content
  Widget _wrapWithBottomPadding(Widget slide) {
    // Fix: Ensure the SingleChildScrollView has explicit constraints
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        width: MediaQuery.of(context).size.width,
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 200, // Account for appbar, title, etc.
        ),
        child: Column(
          children: [
            slide,
            // Add safe area at bottom to prevent content from being hidden by navigation dots
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // Method to show paywall when 50% gate is hit
  Future<void> _showStandardPaywall() async {
    try {
      // Create a handler for paywall presentation
      PaywallPresentationHandler handler = PaywallPresentationHandler();
      
      handler.onPresent((paywallInfo) async {
        String? name = await paywallInfo.name;
        debugPrint("Food Scan 50% Gate Paywall presented: ${name ?? 'Unknown'}");
        MixpanelService.trackEvent('Food Scan 50% Gate Paywall Presented', 
          properties: {'paywall_name': name ?? 'Unknown'}
        );
      });

      handler.onDismiss((paywallInfo, paywallResult) async {
        String? name = await paywallInfo.name;
        debugPrint("Food Scan 50% Gate Paywall dismissed: ${name ?? 'Unknown'}, result: $paywallResult");
        MixpanelService.trackEvent('Food Scan 50% Gate Paywall Dismissed', 
          properties: {
            'paywall_name': name ?? 'Unknown',
            'result': paywallResult.toString()
          }
        );
      });

      handler.onError((error) async {
        debugPrint("Food Scan 50% Gate Paywall error: $error");
        MixpanelService.trackEvent('Food Scan 50% Gate Paywall Error', 
          properties: {'error': error.toString()}
        );
      });

      // Register the paywall placement
      await Superwall.shared.registerPlacement(
        "INSERT_YOUR_STANDARD_PAYWALL_PLACEMENT_ID_HERE",
        handler: handler,
        feature: () async {
          debugPrint("Food Scan 50% Gate: User subscribed, allowing full access");
        }
      );
    } catch (e) {
      debugPrint('Error showing Food Scan 50% Gate paywall: $e');
    }
  }

  // Method to open medical information URL
  Future<void> _openMedicalInfo() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Help & Info', screenName: 'Food Alternatives Screen');
    
    final Uri url = Uri.parse('https://elevenlife.notion.site/Stoppr-1c3456d8905e80029856d5373ee08dfb?pvs=4');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.inAppWebView,
        );
      } else {
        debugPrint(AppLocalizations.of(context)!.translate('foodAlternatives_debug_couldNotLaunchUrl'));
      }
    } catch (e) {
      debugPrint(AppLocalizations.of(context)!.translate('foodAlternatives_debug_errorLaunchingUrl').replaceFirst('{error}', e.toString()));
    }
  }

  // Get a dominant color for each slide type
  Color _getSlideThemeColor(int index, [bool isSecondary = false]) {
    // Primary colors for each slide
    final List<Color> primaryColors = [
      const Color(0xFFE57373), // Scanned Food Analysis - Red
      const Color(0xFF66BB6A), // Healthier Alternative - Green
      const Color(0xFF42A5F5), // Nutritional Comparison - Blue
      const Color(0xFF55B6C2), // Glycemic Index - Teal
      const Color(0xFFFFB74D), // Blood Sugar Impact - Orange
      const Color(0xFF8D6E63), // Bloating Effect - Brown
      const Color(0xFF9575CD), // Meal Timing - Purple
      const Color(0xFF4DB6AC), // Health Benefits - Teal-Green
      const Color(0xFFFF8A65), // Scientific Sources - Deep Orange
      const Color(0xFF7986CB), // Recipe & Preparation - Indigo
    ];
    
    // Secondary colors (lighter or darker variants for gradients)
    final List<Color> secondaryColors = [
      const Color(0xFFEF9A9A), // Lighter Red
      const Color(0xFF81C784), // Lighter Green
      const Color(0xFF90CAF9), // Lighter Blue
      const Color(0xFF80DEEA), // Lighter Teal
      const Color(0xFFFFD54F), // Lighter Orange
      const Color(0xFFA1887F), // Lighter Brown
      const Color(0xFFB39DDB), // Lighter Purple
      const Color(0xFF80CBC4), // Lighter Teal-Green
      const Color(0xFFFFAB91), // Lighter Deep Orange
      const Color(0xFF9FA8DA), // Lighter Indigo
    ];
    
    // Make sure index is in range
    index = index.clamp(0, primaryColors.length - 1);
    
    // Return primary or secondary color
    return isSecondary ? secondaryColors[index] : primaryColors[index];
  }
} 