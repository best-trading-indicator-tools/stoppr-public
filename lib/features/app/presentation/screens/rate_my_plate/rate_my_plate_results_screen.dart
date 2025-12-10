import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import '../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../core/config/env_config.dart';
import '../../../../../core/navigation/page_transitions.dart';
import '../../../../../core/api_rate_limit/api_rate_limit_service.dart';
import '../../../../../core/services/in_app_review_service.dart';
import 'rate_my_plate_scan_screen.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';

class PlateRating {
  final double score; // 0-10 score
  final String title; // Main feedback title
  final String description; // Detailed feedback
  final List<String> strengths; // List of strengths of the plate
  final List<String> improvements; // List of improvement suggestions
  final Map<String, double> nutritionalEstimates; // Estimated nutritional values
  final String carbImpact; // Description of carb impact
  final String sugarContent; // Description of sugar content
  final String proteinContent; // Description of protein content
  final double totalWeight; // Total weight of food in grams

  PlateRating({
    required this.score,
    required this.title,
    required this.description,
    required this.strengths,
    required this.improvements,
    required this.nutritionalEstimates,
    required this.carbImpact,
    required this.sugarContent,
    required this.proteinContent,
    this.totalWeight = 0, // Default to 0 if not provided
  });
}

class RateMyPlateResultsScreen extends StatefulWidget {
  final File imageFile;
  
  const RateMyPlateResultsScreen({
    Key? key,
    required this.imageFile,
  }) : super(key: key);

  @override
  State<RateMyPlateResultsScreen> createState() => _RateMyPlateResultsScreenState();
}

class _RateMyPlateResultsScreenState extends State<RateMyPlateResultsScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _errorMessage = '';
  bool _rateLimitExceeded = false;
  PlateRating? _plateRating;
  late AnimationController _scoreAnimationController;
  final InAppReviewService _reviewService = InAppReviewService();
  late ScrollController _scrollController;
  final double _reviewPromptScrollThreshold = 300.0;
  bool _hasTriggeredReviewOnScroll = false;
  
  // Loading messages
  late List<String> _loadingMessages = [];
  late String _currentLoadingMessage = '';
  Timer? _messageTimer;
  bool _dependenciesInitialized = false; // Flag to run didChangeDependencies once

  @override
  void initState() {
    super.initState();
    // DO NOT initialize l10n-dependent things here
    
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Init score animation controller
    _scoreAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Force status bar icons to dark mode for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for white bg
      statusBarBrightness: Brightness.light, // For iOS
    ));
    
    // Track page view
    MixpanelService.trackPageView('Rate My Plate Results Screen');
    
    // Analyze the image (will be called after dependencies are initialized)
    // _analyzeImage(); // Moved to didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dependenciesInitialized) {
      final l10n = AppLocalizations.of(context)!;
      // Initialize with a random message
      _loadingMessages = [
        l10n.translate('rateMyPlateResults_loading_analyzingComposition'),
        l10n.translate('rateMyPlateResults_loading_calculatingScore'),
        l10n.translate('rateMyPlateResults_loading_evaluatingCarbs'),
        l10n.translate('rateMyPlateResults_loading_measuringAppeal'),
        l10n.translate('rateMyPlateResults_loading_examiningProtein'),
        l10n.translate('rateMyPlateResults_loading_detectingSugar'),
        l10n.translate('rateMyPlateResults_loading_checkingColors'),
        l10n.translate('rateMyPlateResults_loading_assessingPortions'),
        l10n.translate('rateMyPlateResults_loading_evaluatingDensity'),
        l10n.translate('rateMyPlateResults_loading_generatingTips'),
      ];
      if (_loadingMessages.isNotEmpty) {
        _currentLoadingMessage = _loadingMessages[Random().nextInt(_loadingMessages.length)];
      } else {
        _currentLoadingMessage = 'Loading...'; // Fallback if list is somehow still empty
      }

      // Start rotating messages every 3 seconds
      _messageTimer?.cancel(); // Cancel any existing timer
      _messageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted && _isLoading && _loadingMessages.isNotEmpty) {
          setState(() {
            _currentLoadingMessage = _loadingMessages[Random().nextInt(_loadingMessages.length)];
          });
        }
      });
      
      // Analyze the image now that context is available for localizations
      _analyzeImage();
      _dependenciesInitialized = true;
    }
  }
  
  @override
  void dispose() {
    _messageTimer?.cancel();
    _scoreAnimationController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_isLoading &&
        _plateRating != null &&
        !_hasTriggeredReviewOnScroll && 
        _scrollController.offset > _reviewPromptScrollThreshold) {
      debugPrint('RateMyPlateResultsScreen: Scrolled past threshold, requesting review.');
      _reviewService.requestReviewIfAppropriate(screenName: 'RateMyPlateResultsScreen');
      setState(() {
        _hasTriggeredReviewOnScroll = true;
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (!mounted) return; // Guard at the beginning

    try {
      // Check if we can make the request
      final bool canRequest = await ApiRateLimitService.canMakeRequest();
      if (!mounted) return; // Guard after await

      if (!canRequest) {
        final remainingRequests = await ApiRateLimitService.getRemainingRequests();
        if (!mounted) return; // Guard after await
        final currentCount = await ApiRateLimitService.getCurrentCount();
        if (!mounted) return; // Guard after await
        final dailyLimit = currentCount + remainingRequests; // Correctly derive the daily limit
        if (mounted) { // This existing check is fine
          setState(() {
            _rateLimitExceeded = true;
            _errorMessage = AppLocalizations.of(context)!
                .translate('rateMyPlateResults_error_rateLimitExceeded')
                .replaceFirst('{currentCount}', currentCount.toString())
                .replaceFirst('{dailyLimit}', dailyLimit.toString());
            _isLoading = false;
          });
        }
        return;
      }
      
      // Read the image file and convert to base64
      final List<int> imageBytes = await widget.imageFile.readAsBytes();
      if (!mounted) return; // Guard after await
      final String base64Image = base64Encode(imageBytes);
      
      // Set up the OpenAI API request
      final apiKey = EnvConfig.openaiApiKey ?? '';
      if (apiKey.isEmpty) {
        if (!mounted) return; // Guard before using context for AppLocalizations
        throw Exception(AppLocalizations.of(context)!.translate('rateMyPlateResults_error_apiKeyNotConfigured'));
      }
      
      debugPrint('Sending image to OpenAI for plate rating analysis...');
      if (!mounted) return; // Guard before using context for AppLocalizations
      final langCode = AppLocalizations.of(context)!.locale.languageCode;
      
      // Make the API request to OpenAI
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': "You are a knowledgeable nutrition expert specializing in low-carb diets and sugar reduction. "
                  "Analyze this image of a meal plate, and provide a detailed rating and feedback. "
                  "Focus especially on how good the plate is for someone trying to QUIT SUGAR and reduce carbs. "
                  "IMPORTANT: Rate higher for plates with more protein, healthy fats, vegetables, and fewer carbs/sugars. "
                  "The perfect score (10/10) would be for a plate with plenty of protein, healthy fats, fiber, and almost no carbs or sugars. "
                  "A poor score (1-3/10) would be for a plate dominated by high-carb or sugary foods. "
                  "For example: A plate with steak and vegetables would score very high (8-10), "
                  "while a plate with pasta, bread, dessert, or sugary items would score very low (1-3). "
                  "A plate with a mix of protein and some carbs (like a small portion of rice with chicken) would score mid-range (4-7). "
                  "IMPORTANT: Respond ENTIRELY in the following language: $langCode. "
                  "Structure your analysis as follows: "
                  "1. Overall score (0-10, with higher being better for low-carb/low-sugar) "
                  "2. Title that summarizes the rating (like 'Excellent Low-Carb Plate!' or 'Too Many Simple Carbs') "
                  "3. Brief description explaining the overall rating "
                  "4. List of strengths (what's good about this plate for someone quitting sugar) "
                  "5. List of improvements (what could be changed to make it better for quitting sugar) "
                  "6. Estimated nutritional values (rough estimates for protein, carbs, fat, total calories) "
                  "7. Description of the carb impact on blood sugar "
                  "8. Description of any sugar content "
                  "9. Description of protein content "
                  "10. Estimated total weight of food in grams "
                  "Format the response in JSON with these fields: "
                  "{\"score\": 0.0, \"title\": \"...\", \"description\": \"...\", "
                  "\"strengths\": [\"str1\", \"str2\", ...], \"improvements\": [\"imp1\", \"imp2\", ...], "
                  "\"nutritional_estimates\": {\"protein\": 0, \"carbs\": 0, \"fat\": 0, \"calories\": 0}, "
                  "\"carb_impact\": \"...\", \"sugar_content\": \"...\", \"protein_content\": \"...\", \"total_weight\": 300}"
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
          'max_tokens': 800,
        }),
      );
      if (!mounted) return; // Guard after await
      
      // Increment the request counter
      if (response.statusCode == 200) {
        await ApiRateLimitService.incrementRequestCount();
        if (!mounted) return; // Guard after await
      } else {
        if (!mounted) return; // Guard before using context for AppLocalizations
        throw Exception(
          AppLocalizations.of(context)!
              .translate('rateMyPlateResults_error_failedToAnalyze')
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
      
      final responseBody = jsonDecode(utf8.decode(response.bodyBytes)); // Explicitly decode as UTF-8
      final jsonResponseString = responseBody['choices'][0]['message']['content'];
      debugPrint('Received response from OpenAI: $jsonResponseString');
      
      // Parse the JSON response
      try {
        // Remove markdown code block indicators if present
        String cleanJsonString = jsonResponseString;
        if (cleanJsonString.startsWith('```')) {
          cleanJsonString = cleanJsonString
              .replaceAll(RegExp(r'^```json\s*'), '')
              .replaceAll(RegExp(r'\s*```$'), '')
              .trim();
        }
        
        final jsonResponse = jsonDecode(cleanJsonString);
        
        if (mounted) { // This existing check is fine
          setState(() {
            _plateRating = PlateRating(
              score: (jsonResponse["score"] as num).toDouble(),
              title: TextSanitizer.sanitizeForDisplay(jsonResponse["title"] ?? AppLocalizations.of(context)!.translate('rateMyPlateResults_defaultTitle')),
              description: TextSanitizer.sanitizeForDisplay(jsonResponse["description"] ?? ""),
              strengths: List<String>.from(jsonResponse["strengths"] ?? [])
                  .map((s) => TextSanitizer.sanitizeForDisplay(s))
                  .toList(),
              improvements: List<String>.from(jsonResponse["improvements"] ?? [])
                  .map((s) => TextSanitizer.sanitizeForDisplay(s))
                  .toList(),
              nutritionalEstimates: {
                "protein": (jsonResponse["nutritional_estimates"]["protein"] as num).toDouble(),
                "carbs": (jsonResponse["nutritional_estimates"]["carbs"] as num).toDouble(),
                "fat": (jsonResponse["nutritional_estimates"]["fat"] as num).toDouble(),
                "calories": (jsonResponse["nutritional_estimates"]["calories"] as num).toDouble(),
              },
              carbImpact: TextSanitizer.sanitizeForDisplay(jsonResponse["carb_impact"] ?? ""),
              sugarContent: TextSanitizer.sanitizeForDisplay(jsonResponse["sugar_content"] ?? ""),
              proteinContent: TextSanitizer.sanitizeForDisplay(jsonResponse["protein_content"] ?? ""),
              totalWeight: jsonResponse["total_weight"] != null 
                  ? (jsonResponse["total_weight"] as num).toDouble() 
                  : 350.0, // Default value if not provided
            );
            
            _isLoading = false;
          });
          
          // Start score animation
          _scoreAnimationController.forward();
        }
        
      } catch (jsonError) {
        debugPrint('Error parsing JSON response: $jsonError');
        if (mounted) { // This existing check is fine
          setState(() {
            _errorMessage = AppLocalizations.of(context)!.translate('rateMyPlateResults_error_parsingResponse');
            _isLoading = false;
          });
        }
      }
      
    } catch (e) {
      debugPrint('Error analyzing image: $e');
      if (mounted) { // This existing check is fine
        setState(() {
          _errorMessage = AppLocalizations.of(context)!.translate('rateMyPlateResults_error_generic');
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to get color based on score
  Color _getScoreColor(double score) {
    if (score >= 8) return const Color(0xFF4CAF50); // Green for great
    if (score >= 6) return const Color(0xFF8BC34A); // Light green for good
    if (score >= 4) return const Color(0xFFFFEB3B); // Yellow for okay
    if (score >= 2) return const Color(0xFFFF9800); // Orange for not great
    return const Color(0xFFFF5252); // Red for poor
  }
  
  // Method to show health information dialog
  void _openMedicalInfo() async {
    // Track button tap with Mixpanel
    MixpanelService.trackButtonTap('Help & Info', screenName: 'Rate My Plate Results Screen');
    
    final Uri url = Uri.parse('https://elevenlife.notion.site/Stoppr-1c3456d8905e80029856d5373ee08dfb?pvs=4');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.inAppWebView,
        );
      } else {
        debugPrint('Could not launch health info URL');
      }
    } catch (e) {
      debugPrint('Error launching health info URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FA), // Soft pink-tinted white
      extendBodyBehindAppBar: false, // Don't extend behind app bar
      appBar: AppBar(
        backgroundColor: Colors.white, // White background for readability
        elevation: 0.5, // Slight shadow for definition
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)), // Dark icons
        title: Text(
          AppLocalizations.of(context)!.translate('rateMyPlateResults_appBarTitle'),
          style: const TextStyle(
            color: Color(0xFF1A1A1A), // Dark text
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w600,
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacement(
              TopToBottomPageRoute(
                child: const RateMyPlateScanScreen(),
                settings: const RouteSettings(name: '/rate_my_plate_scan'),
              ),
            );
          },
        ),
        actions: [
          // Help & Info icon - only show when not loading
          if (!_isLoading)
            IconButton(
              icon: const Icon(
                Icons.help_outline,
                color: Color(0xFF1A1A1A), // Dark icon
                size: 28,
              ),
              onPressed: _openMedicalInfo,
              tooltip: AppLocalizations.of(context)!.translate('rateMyPlateResults_tooltip_helpAndInfo'),
            ),
          if (!_isLoading && _plateRating != null)
            IconButton(
              icon: const Icon(
                Icons.share,
                color: Color(0xFF1A1A1A), // Dark icon
                size: 24,
              ),
              onPressed: _shareRating,
              tooltip: AppLocalizations.of(context)!.translate('rateMyPlateResults_tooltip_shareRating'),
            ),
        ],
      ),
      body: _isLoading 
          ? _buildLoadingUI()
          : _errorMessage.isNotEmpty
              ? _buildErrorUI()
              : _buildResultsUI(),
    );
  }

  // Widget for loading state
  Widget _buildLoadingUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center, // Explicitly center children horizontally
        children: [
          SizedBox(
            height: 200,
            width: 200,
            child: Lottie.asset(
              'assets/images/lotties/Cooking.json',
              repeat: true,
              animate: true,
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              _currentLoadingMessage,
              key: ValueKey<String>(_currentLoadingMessage),
              style: const TextStyle(
                color: Color(0xFF1A1A1A), // Dark text
                fontFamily: 'ElzaRound',
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.translate('rateMyPlateResults_loading_eta'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF666666), // Gray text
              fontFamily: 'ElzaRound',
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Widget for error state
  Widget _buildErrorUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _rateLimitExceeded ? Icons.timer_off_outlined : Icons.error_outline,
              color: Color(_rateLimitExceeded ? 0xFFFF9800 : 0xFFed3272), // Use brand pink
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1A1A1A), // Dark text
                fontFamily: 'ElzaRound',
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _rateLimitExceeded ? const Color(0xFFFF9800) : const Color(0xFFed3272), // Use brand pink
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 4,
              ),
              child: Text(
                _rateLimitExceeded ? AppLocalizations.of(context)!.translate('rateMyPlateResults_button_ok') : AppLocalizations.of(context)!.translate('rateMyPlateResults_button_tryAgain'),
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
    );
  }

  // Widget for results state
  Widget _buildResultsUI() {
    final rating = _plateRating!;
    final scoreColor = _getScoreColor(rating.score);
    final l10n = AppLocalizations.of(context)!;
    
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image of the plate with overlay
          SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image with gradient overlay
                ShaderMask(
                  shaderCallback: (rect) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.9),
                      ],
                      stops: const [0.3, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.srcATop,
                  child: Image.file(
                    widget.imageFile,
                    fit: BoxFit.cover,
                  ),
                ),
                
                // Text overlay at bottom
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      TextSanitizer.sanitizeForDisplay(rating.title),
                      style: const TextStyle(
                        color: Colors.white, // Keep white for overlay on image
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w700,
                        fontSize: 24,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 3.0,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Total Weight Badge
                Positioned(
                  top: 150,
                  right: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.scale, 
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${(rating.totalWeight ?? 0).round()}g",
                          style: const TextStyle(
                            color: Colors.white, // Keep white for overlay on image
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Main score indicator (circular)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: AnimatedBuilder(
                animation: _scoreAnimationController,
                builder: (context, child) {
                  final double displayScore = rating.score * _scoreAnimationController.value;
                  return Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 130,
                            height: 130,
                            child: CircularProgressIndicator(
                              value: _scoreAnimationController.value,
                              strokeWidth: 14,
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                displayScore.toStringAsFixed(1),
                                style: TextStyle(
                                  color: scoreColor,
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'ElzaRound',
                                ),
                              ),
                              Text(
                                l10n.translate('rateMyPlateResults_scoreOutOfTen'),
                                style: const TextStyle(
                                  color: Color(0xFF666666), // Gray text
                                  fontSize: 16,
                                  fontFamily: 'ElzaRound',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _getScoreLabel(rating.score, l10n),
                        style: TextStyle(
                          color: scoreColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'ElzaRound',
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          
          // Description
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, // White card background
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                TextSanitizer.sanitizeForDisplay(rating.description),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text
                  fontFamily: 'ElzaRound',
                  fontSize: 17,
                  height: 1.5,
                ),
              ),
            ),
          ),
          
          // Nutritional Estimates Section with Circular Design
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
            child: _buildCircularNutritionalEstimates(rating.nutritionalEstimates),
          ),
          
          // Strengths and Improvements Sections - only show if they have content
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rating.strengths.isNotEmpty) ...[
                  _buildListSection(
                    l10n.translate('rateMyPlateResults_sectionTitle_strengths'),
                    rating.strengths.map((e) => TextSanitizer.sanitizeForDisplay(e)).toList(),
                    const Color(0xFF4CAF50), // Green for strengths
                    Icons.check_circle_outline,
                  ),
                  const SizedBox(height: 24),
                ],
                if (rating.improvements.isNotEmpty)
                  _buildListSection(
                    l10n.translate('rateMyPlateResults_sectionTitle_improvements'),
                    rating.improvements.map((e) => TextSanitizer.sanitizeForDisplay(e)).toList(),
                    const Color(0xFFFF9800), // Amber for improvements
                    Icons.lightbulb_outline,
                  ),
              ],
            ),
          ),
          
          // Detailed Analysis Section
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfae6ec), // Light pink accent
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.translate('rateMyPlateResults_sectionTitle_detailedAnalysis'),
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A), // Dark text
                      fontFamily: 'ElzaRound',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Carb Impact Section
                _buildDetailSection(
                  l10n.translate('rateMyPlateResults_sectionTitle_carbImpact'),
                  TextSanitizer.sanitizeForDisplay(rating.carbImpact),
                  const Color(0xFFfd5d32), // Brand orange for carbs
                  Icons.grain,
                ),
                const SizedBox(height: 24),
                
                // Sugar Content Section
                _buildDetailSection(
                  l10n.translate('rateMyPlateResults_sectionTitle_sugarContent'),
                  TextSanitizer.sanitizeForDisplay(rating.sugarContent),
                  const Color(0xFFFF5252), // Red for sugar (keep red as it's appropriate)
                  Icons.cake,
                ),
                const SizedBox(height: 24),
                
                // Protein Content Section
                _buildDetailSection(
                  l10n.translate('rateMyPlateResults_sectionTitle_proteinContent'),
                  TextSanitizer.sanitizeForDisplay(rating.proteinContent),
                  const Color(0xFFed3272), // Brand pink for protein
                  Icons.fitness_center,
                ),
              ],
            ),
          ),
          
          // Share button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Center(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFed3272), // Brand pink
                      Color(0xFFfd5d32), // Brand orange
                    ],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                ),
                child: ElevatedButton.icon(
                  onPressed: _shareRating,
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: Text(
                    l10n.translate('rateMyPlateResults_button_shareYourRating'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'ElzaRound',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom spacing
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  // Helper method to build circular nutritional estimates
  Widget _buildCircularNutritionalEstimates(Map<String, double> estimates) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white, // White card background
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_outlined,
                color: const Color(0xFF666666), // Gray icon
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.translate('rateMyPlateResults_sectionTitle_nutritionalEstimates'),
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A), // Dark text
                    fontFamily: 'ElzaRound',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Grid layout for nutrition with radial progress indicators
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildNutrientBox(
                    l10n.translate('rateMyPlateResults_nutrientLabel_protein'), 
                    "${estimates['protein']?.round() ?? 0}g", 
                    const Color(0xFFed3272), // Brand pink for protein
                    Icons.fitness_center,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _buildNutrientBox(
                    l10n.translate('rateMyPlateResults_nutrientLabel_carbs'), 
                    "${estimates['carbs']?.round() ?? 0}g", 
                    const Color(0xFFfd5d32), // Brand orange for carbs
                    Icons.grain,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildNutrientBox(
                    l10n.translate('rateMyPlateResults_nutrientLabel_fat'), 
                    "${estimates['fat']?.round() ?? 0}g", 
                    const Color(0xFF00ACC1), // Teal for fat (distinct and good contrast)
                    Icons.opacity,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _buildNutrientBox(
                    l10n.translate('rateMyPlateResults_nutrientLabel_calories'), 
                    "${estimates['calories']?.round() ?? 0}", 
                    const Color(0xFF673AB7), // Deep purple for calories (good contrast)
                    Icons.local_fire_department,
                  ),
                ),
              ),
            ],
          ),
          
          // Helper text
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  color: const Color(0xFF666666), // Gray icon
                  size: 12,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l10n.translate('rateMyPlateResults_nutritionalEstimates_helperText'),
                    style: const TextStyle(
                      color: Color(0xFF666666), // Gray text
                      fontFamily: 'ElzaRound',
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Updated nutrient box with better contrast and readability
  // BRAND GUIDE COMPLIANCE: Always ensure proper contrast ratios
  // - Never use light colors on white backgrounds
  // - Never use dark colors on dark backgrounds  
  // - Use full color opacity for text/icons to ensure visibility
  Widget _buildNutrientBox(String label, String value, Color color, IconData icon) {
    return Container(
      height: 95,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08), // Very light background tint
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Value with icon
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontFamily: 'ElzaRound',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            
            // Label with better contrast
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color, // Full color opacity for better contrast
                fontFamily: 'ElzaRound',
                fontSize: 14, // Bigger text as requested
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to build a list section (strengths or improvements)
  Widget _buildListSection(String title, List<String> items, Color color, IconData icon) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, // White card background
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontFamily: 'ElzaRound',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    title == "Strengths" ? Icons.add_circle : Icons.arrow_right,
                    color: color.withOpacity(0.8),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A), // Dark text
                      fontFamily: 'ElzaRound',
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
  
  // Helper method to build a detailed analysis section
  Widget _buildDetailSection(String title, String content, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white, // White card background
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontFamily: 'ElzaRound',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: const TextStyle(
              color: Color(0xFF1A1A1A), // Dark text
              fontFamily: 'ElzaRound',
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to get a label based on score
  String _getScoreLabel(double score, AppLocalizations l10n) {
    if (score >= 9) return l10n.translate('rateMyPlateResults_scoreLabel_excellent');
    if (score >= 8) return l10n.translate('rateMyPlateResults_scoreLabel_great');
    if (score >= 7) return l10n.translate('rateMyPlateResults_scoreLabel_veryGood');
    if (score >= 6) return l10n.translate('rateMyPlateResults_scoreLabel_good');
    if (score >= 5) return l10n.translate('rateMyPlateResults_scoreLabel_average');
    if (score >= 4) return l10n.translate('rateMyPlateResults_scoreLabel_needsWork');
    if (score >= 3) return l10n.translate('rateMyPlateResults_scoreLabel_notGreat');
    if (score >= 2) return l10n.translate('rateMyPlateResults_scoreLabel_poor');
    return l10n.translate('rateMyPlateResults_scoreLabel_needsImprovement');
  }
  
  // Method to share the rating
  Future<void> _shareRating() async {
    if (!mounted) return; // Guard at the beginning
    if (_plateRating == null) return;
    if (!mounted) return; // Guard before using context for AppLocalizations
    final l10n = AppLocalizations.of(context)!;

    // Create a temporary file for the image
    final tempDir = await getTemporaryDirectory();
    if (!mounted) return; // Guard after await
    final tempPath = path.join(tempDir.path, 'plate_rating_share.jpg');
    await widget.imageFile.copy(tempPath);
    if (!mounted) return; // Guard after await

    final String scoreText = _plateRating!.score.toStringAsFixed(1);
    final String shareText = l10n.translate('rateMyPlateResults_shareMessage')
                              .replaceFirst('{score}', scoreText)
                              .replaceFirst('{title}', TextSanitizer.sanitizeForDisplay(_plateRating!.title));

    try {
      await Share.shareXFiles(
        [XFile(tempPath)],
        text: shareText,
        subject: l10n.translate('rateMyPlateResults_appBarTitle'), // Optional: subject for email
      );
    } catch (e) {
      debugPrint('Error sharing rating: $e');
      if (mounted) { // This existing check is fine
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('rateMyPlateResults_shareError'))),
        );
      }
    }
  }
} 