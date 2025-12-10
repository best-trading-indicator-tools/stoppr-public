import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:async';
import '../../data/models/nutrition_data.dart';
import '../../data/models/food_log.dart';
import '../../data/repositories/nutrition_repository.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/services/local_food_image_service.dart';
import '../../../../core/utils/text_sanitizer.dart';
import 'package:stoppr/core/config/env_config.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:stoppr/permissions/permission_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stoppr/core/api_rate_limit/api_rate_limit_service.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/notifications/notification_service.dart';


class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key, required this.targetDate});

  // Date the log should be attributed to (e.g., yesterday from dashboard)
  final DateTime targetDate;

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isProcessing = false;
  bool _isScanning = false;
  bool _showTapProcessing = false; // 1-second popup feedback after tap
  bool _isPermissionGranted = false;
  bool _isCheckingPermission = true;
  File? _imageFile;
  String? _errorMessage;
  late List<CameraDescription> _cameras;
  final _nutritionRepository = NutritionRepository();
  final _imageService = LocalFoodImageService();
  final _permissionService = PermissionService();
  final _imagePicker = ImagePicker();
  
  // Animation controllers
  late AnimationController _scanAnimationController;
  late AnimationController _progressAnimationController;
  
  // Progress tracking
  double _analysisProgress = 0.0;
  final StreamController<double> _progressController = StreamController<double>.broadcast();
  
  // Zoom controls
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoomLevel = 1.0;
  double _baseScale = 1.0;
  static const String _healthNotionUrl =
      'https://elevenlife.notion.site/Stoppr-App-Health-Information-and-Scientific-References-1c3456d8905e80029856d5373ee08dfb?pvs=4';

  @override
  void initState() {
    super.initState();
    
    debugPrint('📷 FOOD SCANNER INIT:');
    debugPrint('   Received targetDate: ${widget.targetDate.toIso8601String().substring(0, 10)}');
    debugPrint('   Current date: ${DateTime.now().toIso8601String().substring(0, 10)}');
    debugPrint('   Days difference: ${DateTime.now().difference(widget.targetDate).inDays}');
    
    _checkAndRequestPermissionOnInit();
    
    // Debug mode: Auto-scan cinnamon bun image
    if (kDebugMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _useDebugCinnamonBunImage();
          }
        });
      });
    }
    
    // Force status bar to white
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    
    // Initialize scanner animation
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    
    // Initialize progress animation
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // Estimated processing time
    );

    // Track page view
    MixpanelService.trackPageView('Food Scanner Screen');
  }

  // Compose a timestamp using the widget's target date with current time-of-day
  DateTime _composeLogDate() {
    final now = DateTime.now();
    final d = widget.targetDate;
    return DateTime(d.year, d.month, d.day, now.hour, now.minute, now.second, now.millisecond, now.microsecond);
  }

  // Check and request permission when the screen initializes
  Future<void> _checkAndRequestPermissionOnInit() async {
    bool granted = await _permissionService.isCameraGranted();
    
    if (!granted) {
      // Track when the permission dialog is about to be shown
      MixpanelService.trackEvent('Food Scanner Camera Permission Launched');
      MixpanelService.setUserProfileProperty('Food Scanner Camera Permission Status', 'Not Granted');
      // Request permission if not already granted
      granted = await _permissionService.requestCameraPermission();
    }

    if (mounted) {
      setState(() {
        _isPermissionGranted = granted;
        _isCheckingPermission = false; // Finished checking/requesting
      });
      if (granted) {
        // Track when permission is accepted
        MixpanelService.trackEvent('Food Scanner Camera Permission Accepted');
        MixpanelService.setUserProfileProperty('Food Scanner Camera Permission Status', 'Accepted');
        await _initializeCamera();
      } else {
        MixpanelService.setUserProfileProperty('Food Scanner Camera Permission Status', 'Denied');
        _showPermissionDeniedMessage(AppLocalizations.of(context)!.translate('calorieTracker_cameraPermissionName'));
        // Optionally navigate away or show a persistent error message
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return; // Add guard at the beginning

    // Ensure permission is granted before initializing
    if (!_isPermissionGranted) return; 
    
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = AppLocalizations.of(context)!.translate('calorieTracker_noCamerasAvailable');
          });
        }
        return;
      }

      _controller = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        // Get available zoom levels after camera is initialized
        await _getAvailableZoomLevels();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '${AppLocalizations.of(context)!.translate('calorieTracker_failedToInitializeCamera')}: $e';
        });
      }
    }
  }

  Future<void> _captureAndAnalyze() async {
    // Strong guard to prevent duplicate scans from rapid taps
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing || _isScanning) {
      return;
    }

    // Lock immediately to avoid near-simultaneous taps during state update
    _isProcessing = true;
    setState(() {
      _errorMessage = null;
      _showTapProcessing = true; // show immediate popup
    });
    // Auto-hide the tap popup after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _showTapProcessing = false;
      });
    });

    try {
      // Track scan attempt
      MixpanelService.trackButtonTap('Capture Food Image', 
        additionalProps: {
          'source': 'food_scanner',
        });

      final image = await _controller!.takePicture();
      
      // Read and compress image
      final Uint8List photoBytes = await image.readAsBytes();
      debugPrint('Original image size: ${photoBytes.lengthInBytes} bytes');
      
      final Stopwatch localProcessingStopwatch = Stopwatch()..start();
      
      // Decode image using the image package
      img.Image? originalImage = img.decodeImage(photoBytes);
      
      if (originalImage == null) {
        debugPrint('Error decoding captured image');
        if (mounted) {
          setState(() {
            _errorMessage = AppLocalizations.of(context)!.translate('calorieTracker_failedToProcessImage');
                  _isProcessing = false;
          });
        }
        return;
      }
      
      // Create high quality version for thumbnail (less compressed)
      final Uint8List highQualityBytes = Uint8List.fromList(img.encodeJpg(originalImage, quality: 95));
      
      // Resize the image for API processing
      img.Image resizedImage = img.copyResize(originalImage, width: 512);
      
      // Encode the resized image to JPEG with quality 85 for API
      final List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 85);
      
      localProcessingStopwatch.stop();
      debugPrint('Local processing time: ${localProcessingStopwatch.elapsedMilliseconds}ms');
      debugPrint('High quality image size: ${highQualityBytes.length} bytes');
      debugPrint('Compressed image size: ${compressedBytes.length} bytes');
      
      // Create temporary files
      final Directory dir = await getTemporaryDirectory();
      final String filePath = path.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg');
      final String highQualityPath = path.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}_hq.jpg');
      
      final File newImage = File(filePath);
      final File highQualityImage = File(highQualityPath);
      
      await newImage.writeAsBytes(compressedBytes);
      await highQualityImage.writeAsBytes(highQualityBytes);
      
      // Skip the scanning overlay - go directly to dashboard
      // setState(() {
      //   _imageFile = newImage;
      //   _isScanning = true;
      // });
      // 
      // // Start scanner animation
      // _scanAnimationController.repeat();
      // _progressAnimationController.forward();
      // 
      // // Start progress updates
      // _startProgressSimulation();
      
      if (mounted) {
        // Generate the final FoodLog ID upfront
        final foodLogId = FirebaseFirestore.instance
            .collection('users')
            .doc() // This generates a unique ID
            .id;
        
        // Use high quality image for thumbnail saving
        _imageFile = highQualityImage;
        
        // Save high quality image thumbnail immediately with final ID
        await _imageService.saveFoodImage(foodLogId, highQualityBytes);
        debugPrint('📷 High quality thumbnail saved with final ID: $foodLogId');

        // Create food log immediately with processing state
        final processingFoodLog = FoodLog(
          userId: '', // Will be set by repository
          foodName: AppLocalizations.of(context)!.translate('calorieTracker_analyzingFood'), 
          mealType: MealType.lunch,
          nutritionData: NutritionData(
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            sugar: 0,
            fiber: 0,
            sodium: 0,
            micronutrients: {},
            servingInfo: ServingInfo(
              amount: 0,
              unit: 'g',
              weight: 0,
              weightUnit: 'g',
            ),
          ),
          loggedAt: _composeLogDate(),
          imageUrl: foodLogId, // Store the food log ID for Firebase Storage reference
        );
        
        // Add processing food log immediately with pre-generated ID
        debugPrint('=== CREATING PROCESSING FOOD LOG (CAPTURE) ===');
        debugPrint('Food name: ${processingFoodLog.foodName}');
        debugPrint('Calories: ${processingFoodLog.nutritionData.calories}');
        debugPrint('Food log ID (pre-generated): $foodLogId');
        await _nutritionRepository.addFoodLogWithId(processingFoodLog.copyWith(id: foodLogId));
        debugPrint('Created food log with ID: $foodLogId');
        
        // No need to update tracking - we used the final ID from the start
        final foodLogWithId = processingFoodLog.copyWith(id: foodLogId);
        
        // Small delay to ensure the analyzing state is visible
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Navigate back to dashboard
        if (mounted) {
          Navigator.pop(context);
        }
        
        // Continue processing in background
        debugPrint('=== STARTING BACKGROUND PROCESSING ===');
        debugPrint('Image path: ${newImage.path}');
        debugPrint('Food log ID: ${foodLogWithId.id}');
        _processImageInBackground(newImage.path, foodLogWithId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '${AppLocalizations.of(context)!.translate('calorieTracker_failedToAnalyzeFood')}: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isScanning = false;
        });
        _scanAnimationController.stop();
        _progressAnimationController.stop();
      }
    }
  }
  
  void _startProgressSimulation() {
    // Simulate progress updates
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!_isScanning || _analysisProgress >= 1.0) {
        timer.cancel();
        return;
      }
      
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          _analysisProgress = (_progressAnimationController.value * 100).clamp(0, 100) / 100;
        });
      }
      
      _progressController.add(_analysisProgress);
    });
  }

  Future<void> _processImageInBackground(String imagePath, FoodLog processingFoodLog) async {
    try {
      debugPrint('Starting background processing for image: $imagePath');
      
      // Process the image
      final nutritionData = await _analyzeFood(imagePath);
      
      if (nutritionData != null) {
        debugPrint('Analysis completed successfully: ${nutritionData.foodName}, ${nutritionData.calories} calories');
        
        // Update the food log with actual data (keeping existing image path)
        final completedFoodLog = FoodLog(
          id: processingFoodLog.id,
          userId: processingFoodLog.userId,
          foodName: nutritionData.foodName ?? 'Unknown Food',
          mealType: MealType.lunch,
          nutritionData: nutritionData,
          loggedAt: processingFoodLog.loggedAt,
          imageUrl: processingFoodLog.imageUrl, // Keep existing image path
        );
        
        debugPrint('=== UPDATING FOOD LOG WITH ANALYSIS RESULTS ===');
        debugPrint('Updating food log ID: ${completedFoodLog.id}');
        debugPrint('New food name: ${completedFoodLog.foodName}');
        debugPrint('New calories: ${completedFoodLog.nutritionData.calories}');
        debugPrint('New protein: ${completedFoodLog.nutritionData.protein}g');
        debugPrint('New carbs: ${completedFoodLog.nutritionData.carbs}g');
        debugPrint('New fat: ${completedFoodLog.nutritionData.fat}g');
        debugPrint('Image path: ${completedFoodLog.imageUrl}');
        
        debugPrint('🔄 Calling repository.updateFoodLog()...');
        await _nutritionRepository.updateFoodLog(completedFoodLog);
        debugPrint('✅ REPOSITORY UPDATE COMPLETE - DAILY SUMMARY SHOULD BE UPDATED');
        
        // Send food scan complete notification
        debugPrint('📱 Sending food scan complete notification...');
        try {
          final NotificationService notificationService = NotificationService();
          await notificationService.sendFoodScanCompleteNotification(
            foodName: completedFoodLog.foodName,
            calories: completedFoodLog.nutritionData.calories,
          );
          debugPrint('✅ Food scan complete notification sent successfully');
        } catch (e) {
          debugPrint('❌ Error sending food scan complete notification: $e');
          // Don't rethrow - notification failure shouldn't affect food scanning
        }
      } else {
        debugPrint('Analysis returned null data - updating with error state');
        // Update with error state
        final errorFoodLog = processingFoodLog.copyWith(
          foodName: AppLocalizations.of(context)!.translate('calorieTracker_analysisFailed'),
          nutritionData: processingFoodLog.nutritionData.copyWith(calories: -1.0), // Use -1.0 to indicate error
        );
        await _nutritionRepository.updateFoodLog(errorFoodLog);
      }
    } catch (e, stackTrace) {
      // Suppress noisy stack traces for expected non-consumable cases
      final String message = e.toString();
      final bool isExpectedNonConsumable =
          message.contains('Non-consumable item detected');
      if (isExpectedNonConsumable) {
        debugPrint('Background processing error: $e');
      } else {
        debugPrint('Background processing error: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      
      // Update food log with error state
      try {
        // Provide user-friendly error messages
        String errorMessage = 'Analysis failed';
        if (mounted) {
          // Only use context if widget is still mounted
          if (e is TimeoutException) {
            errorMessage = AppLocalizations.of(context)!.translate('calorieTracker_analysisTimeout');
          } else if (e.toString().contains('Rate limit exceeded')) {
            errorMessage = AppLocalizations.of(context)!.translate('calorieTracker_rateLimitExceeded');
          } else if (e.toString().contains('Non-consumable item detected')) {
            errorMessage = AppLocalizations.of(context)!.translate('calorieTracker_nonFoodDetected');
          } else {
            errorMessage = AppLocalizations.of(context)!.translate('calorieTracker_analysisFailed');
          }
        }
        
        final errorFoodLog = processingFoodLog.copyWith(
          foodName: errorMessage,
          nutritionData: processingFoodLog.nutritionData.copyWith(calories: -1.0), // Use -1.0 to indicate error
        );
        await _nutritionRepository.updateFoodLog(errorFoodLog);
        debugPrint('Updated food log with error state');
      } catch (updateError) {
        debugPrint('Failed to update food log with error state: $updateError');
      }
    }
  }

  Future<NutritionData?> _analyzeFood(String imagePath) async {
    try {
      debugPrint('Starting food analysis for image: $imagePath');
      
      // Global API rate limit check
      final canRequest = await ApiRateLimitService.canMakeRequest();
      if (!canRequest) {
        throw Exception('Rate limit exceeded');
      }

      // Check if API key is available
      final apiKey = EnvConfig.groqApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('Groq API key not configured');
      }
      debugPrint('API key is configured (length: ${apiKey.length})');
      
      // Read the already compressed image
      final imageBytes = await File(imagePath).readAsBytes();
      debugPrint('Image loaded: ${imageBytes.length} bytes');
      final base64Image = base64Encode(imageBytes);
      debugPrint('Image encoded to base64: ${base64Image.length} characters');

      // Increment global API request count before making network call
      final incremented = await ApiRateLimitService.incrementRequestCount();
      if (!incremented) {
        throw Exception('Rate limit exceeded');
      }

      // Current UI language for localization of returned foodName
      final String langCode = AppLocalizations.of(context)!.locale.languageCode;

      // Call Groq Vision API with timeout
      debugPrint('Making API call to Groq...');
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
              'role': 'system',
              'content': '''You are a nutrition expert AI that analyzes food and drink images.
Your task is to: (1) identify if this contains food or drinks, (2) if yes, provide nutrition normalized to 1 gram/ml, and (3) estimate the visible portion size.

ALWAYS return ONLY a valid JSON object with exactly this structure (no prose):

For FOOD/DRINK items (even if other non-edible items are visible):
{
  "isFood": true,
  "foodName": "Brief description",
  "per1g": { "calories": 2.5, "protein": 0.2, "carbs": 0.3, "fat": 0.1, "sugar": 0.08, "fiber": 0.05, "sodium": 3 },
  "estimatedPortionGrams": 180,
  "micronutrients": { "vitaminA": {"value": 0.001, "unit": "mcg"}, "vitaminC": {"value": 0.15, "unit": "mg"}, "calcium": {"value": 2, "unit": "mg"}, "iron": {"value": 0.08, "unit": "mg"} }
}

For NON-FOOD/DRINK items (only if NO consumable items are visible):
{
  "isFood": false,
  "reason": "Brief explanation of what this is instead of food/drink"
}

Rules:
- per1g values must be numeric and represent amounts within 1g (solids) or 1ml (liquids).
- estimatedPortionGrams represents grams for solids, ml for liquids (1ml ≈ 1g for water-based drinks).
- For drinks: estimate volume based on container size (e.g., coffee cup ~240ml, glass ~300ml, bottle ~500ml).
- micronutrients values should also be per 1g/ml - use realistic values (e.g., 0.001-10 for most nutrients).
- Use appropriate units: mg for minerals, mcg for vitamins (except vitamin C in mg).
- Localization requirement: The "foodName" string MUST be written in the following language (do not translate numbers/units): ${langCode}.
- Do not include any text outside the JSON.'''
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Analyze this food image and provide nutritional information.',
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                  },
                },
              ],
            },
          ],
          'max_tokens': 500,
          'temperature': 0.3,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Groq API request timed out after 10 seconds', const Duration(seconds: 10));
        },
      );

      debugPrint('API response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        debugPrint('Parsing API response...');
        final data = jsonDecode(
          utf8.decode(
            response.bodyBytes,
            allowMalformed: true,
          ),
        );
        final content = data['choices'][0]['message']['content'];
        debugPrint('API response content: $content');
        
        // Clean the response content - remove markdown code blocks if present
        String cleanContent = content.trim();
        if (cleanContent.startsWith('```json')) {
          cleanContent = cleanContent.substring(7); // Remove ```json
        }
        if (cleanContent.startsWith('```')) {
          cleanContent = cleanContent.substring(3); // Remove ```
        }
        if (cleanContent.endsWith('```')) {
          cleanContent = cleanContent.substring(0, cleanContent.length - 3); // Remove trailing ```
        }
        cleanContent = cleanContent.trim();
        
        // Check if Groq responded with plain text (fallback for old behavior)
        if (!cleanContent.startsWith('{') || !cleanContent.endsWith('}')) {
          debugPrint('Groq detected non-consumable item, response: $cleanContent');
          throw Exception('Non-consumable item detected: $cleanContent');
        }
        
        // Parse the JSON response
        final nutritionJson = jsonDecode(cleanContent);
        debugPrint('Parsed nutrition JSON: $nutritionJson');
        
        // Check if OpenAI detected non-consumable item (not food or drink)
        final isFood = nutritionJson['isFood'] ?? true; // Default to true for backward compatibility
        if (!isFood) {
          final reason = nutritionJson['reason'] ?? 'Non-consumable item detected';
          debugPrint('Groq detected non-consumable item: $reason');
          throw Exception('Non-consumable item detected: $reason');
        }
        
        // Build NutritionData: scale per-gram baseline by estimated portion grams
        final per1g = nutritionJson['per1g'] ?? {};
        final double grams = _asDouble(nutritionJson['estimatedPortionGrams'] ?? 0).clamp(30.0, 1000.0);
        final double portion = grams > 0 ? grams : 100.0; // fallback

        NutritionData base = NutritionData(
          foodName: TextSanitizer.sanitizeForDisplay(nutritionJson['foodName'] ?? 'Unknown Food'),
          calories: _asDouble(per1g['calories'] ?? 0),
          protein: _asDouble(per1g['protein'] ?? 0),
          carbs: _asDouble(per1g['carbs'] ?? 0),
          fat: _asDouble(per1g['fat'] ?? 0),
          sugar: _asDouble(per1g['sugar'] ?? 0),
          fiber: _asDouble(per1g['fiber'] ?? 0),
          sodium: _asDouble(per1g['sodium'] ?? 0),
          micronutrients: _parseMicronutrients(nutritionJson['micronutrients'] ?? {}),
          servingInfo: const ServingInfo(
            amount: 1,
            unit: 'g',
            weight: 1,
            weightUnit: 'g',
          ),
        );

        double scale(double v) => v * portion;

        return base.copyWith(
          calories: scale(base.calories),
          protein: scale(base.protein),
          carbs: scale(base.carbs),
          fat: scale(base.fat),
          sugar: scale(base.sugar),
          fiber: scale(base.fiber),
          sodium: scale(base.sodium),
          micronutrients: base.micronutrients.map((k, v) => MapEntry(k, v.copyWith(value: scale(v.value)))),
          servingInfo: ServingInfo(
            amount: 1, // Always 1 serving (the weight field contains the portion size)
            unit: 'serving',
            weight: portion,
            weightUnit: 'g',
          ),
        );
      } else {
        final errorBody = utf8.decode(
          response.bodyBytes,
          allowMalformed: true,
        );
        debugPrint('API error response body: $errorBody');
        throw Exception('API request failed: ${response.statusCode} - $errorBody');
      }
    } catch (e, stackTrace) {
      debugPrint('Error analyzing food: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Map<String, Micronutrient> _parseMicronutrients(Map<String, dynamic> json) {
    final result = <String, Micronutrient>{};
    json.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        // Sanity clamp micronutrient numeric values to avoid model outliers
        double v = _asDouble(value['value'] ?? 0);
        if (v.isNaN || v.isInfinite) v = 0.0;
        // Extremely high values are unrealistic; hard-cap to keep UI sane
        v = v.clamp(0.0, 1000000.0);
        result[key] = Micronutrient(
          value: v,
          unit: TextSanitizer.sanitizeForDisplay(value['unit'] ?? ''),
        );
      }
    });
    return result;
  }

  // Safely convert dynamic JSON numeric values (int/double/String) to double
  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) {
      final parsed = double.tryParse(v.trim());
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  // Helper function to show a snackbar when permission is denied
  void _showPermissionDeniedMessage(String permissionName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.translate('calorieTracker_cameraPermissionDenied')),
        backgroundColor: Colors.red,
      ),
    );
  }


  @override
  void dispose() {
    _scanAnimationController.dispose();
    _progressAnimationController.dispose();
    _progressController.close();
    _controller?.dispose();
    super.dispose();
  }
  
  // Get min/max zoom levels supported by the camera
  Future<void> _getAvailableZoomLevels() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      _minAvailableZoom = await _controller!.getMinZoomLevel();
      _maxAvailableZoom = await _controller!.getMaxZoomLevel();
      
      // Some devices return unreasonable values, so cap them at sane limits
      _maxAvailableZoom = _maxAvailableZoom.clamp(1.0, 10.0);
      
      // Set current zoom to min initially
      _currentZoomLevel = _minAvailableZoom;
      
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error getting zoom levels: $e');
      // Use default values if we can't get device-specific ones
      _minAvailableZoom = 1.0;
      _maxAvailableZoom = 3.0;
      _currentZoomLevel = 1.0;
    }
  }

  // Set zoom level with bounds checking
  Future<void> _setZoomLevel(double value) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    // Ensure the value is within available zoom range
    value = value.clamp(_minAvailableZoom, _maxAvailableZoom);

    try {
      await _controller!.setZoomLevel(value);
      setState(() {
        _currentZoomLevel = value;
      });
    } catch (e) {
      debugPrint('Error setting zoom level: $e');
    }
  }

  // Debug mode: Automatically scan cinnamon bun image
  Future<void> _useDebugCinnamonBunImage() async {
    debugPrint('🐛 DEBUG MODE: Auto-scanning cinnamon bun image...');
    await _useTestFoodImage();
  }

  // Method to use test food image for testing
  Future<void> _useTestFoodImage() async {
    
    try {
      debugPrint('=== USING TEST FOOD IMAGE (PINK ICON CLICKED) ===');
      setState(() {
        _isProcessing = true;
      });

      // Track test scan
      MixpanelService.trackButtonTap('Test Food Image Scan');
      
      // Load asset for testing
      final ByteData data = await rootBundle.load('assets/images/cinnamonbun.jpg');
      final Uint8List assetBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      debugPrint('✅ Test asset loaded: ${assetBytes.length} bytes');
      
      // Create a temporary file from the asset
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = path.join(tempDir.path, 'test_food_compressed.jpg');
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(assetBytes);
      
      // Skip the scanning overlay for test images too - go directly to dashboard
      // setState(() {
      //   _imageFile = tempFile;
      //   _isScanning = true;
      // });
      // 
      // // Start scanner animation
      // _scanAnimationController.repeat();
      // _progressAnimationController.forward();
      // 
      // // Start progress updates
      // _startProgressSimulation();
      
      if (mounted) {
        // Generate the final FoodLog ID upfront for test image
        final foodLogId = FirebaseFirestore.instance
            .collection('users')
            .doc() // This generates a unique ID
            .id;
        
        // Save asset locally in debug mode so it can be displayed (no Firebase upload)
        await _imageService.saveFoodImageLocalOnly(foodLogId, assetBytes);
        debugPrint('📷 Debug mode: saved cinnamon bun asset locally with ID: $foodLogId');

        // Create food log immediately with processing state
        final processingFoodLog = FoodLog(
          userId: '', // Will be set by repository
          foodName: AppLocalizations.of(context)!.translate('calorieTracker_analyzingFood'), 
          mealType: MealType.lunch,
          nutritionData: NutritionData(
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            sugar: 0,
            fiber: 0,
            sodium: 0,
            micronutrients: {},
            servingInfo: ServingInfo(
              amount: 0,
              unit: 'g',
              weight: 0,
              weightUnit: 'g',
            ),
          ),
          loggedAt: _composeLogDate(),
          imageUrl: foodLogId, // Store the food log ID for Firebase Storage reference
        );
        
        // Add processing food log immediately with pre-generated ID
        await _nutritionRepository.addFoodLogWithId(processingFoodLog.copyWith(id: foodLogId));
        final foodLogWithId = processingFoodLog.copyWith(id: foodLogId);
        
        // No need to update tracking - we used the final ID from the start
        
              // Small delay to ensure the analyzing state is visible
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Navigate back to dashboard
      if (mounted) {
        Navigator.pop(context);
      }
      
      // Continue processing in background
      debugPrint('=== STARTING BACKGROUND PROCESSING (TEST IMAGE) ===');
        debugPrint('Test image path: ${tempFile.path}');
        debugPrint('Food log ID: ${foodLogWithId.id}');
        _processImageInBackground(tempFile.path, foodLogWithId);
      }
    } catch (e) {
      debugPrint('Error using test food image: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '${AppLocalizations.of(context)!.translate('calorieTracker_failedToAnalyzeTestImage')}: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isScanning = false;
        });
        _scanAnimationController.stop();
        _progressAnimationController.stop();
      }
    }
  }

  // Method to test non-food image (chair) to see OpenAI behavior
  Future<void> _useTestChairImage() async {
    
    try {
      debugPrint('=== USING TEST CHAIR IMAGE (NON-FOOD DEBUG) ===');
      setState(() {
        _isProcessing = true;
      });

      // Track test scan
      MixpanelService.trackButtonTap('Test Chair Image Scan (Non-Food)');
      
      // Load chair asset for testing non-food behavior
      final ByteData data = await rootBundle.load('assets/images/chair.jpeg');
      final Uint8List assetBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      debugPrint('✅ Test chair asset loaded: ${assetBytes.length} bytes');
      
      // Create a temporary file from the asset
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = path.join(tempDir.path, 'test_chair_compressed.jpg');
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(assetBytes);
      
      // Skip the scanning overlay for test chair images too - go directly to dashboard
      // setState(() {
      //   _imageFile = tempFile;
      //   _isScanning = true;
      // });
      // 
      // // Start scanner animation
      // _scanAnimationController.repeat();
      // _progressAnimationController.forward();
      // 
      // // Start progress updates
      // _startProgressSimulation();
      
      if (mounted) {
        // Generate the final FoodLog ID upfront for test chair image
        final foodLogId = FirebaseFirestore.instance
            .collection('users')
            .doc() // This generates a unique ID
            .id;
        
        // Save image thumbnail immediately with final ID
        await _imageService.saveFoodImage(foodLogId, assetBytes);
        debugPrint('📷 Test chair image thumbnail saved with final ID: $foodLogId');

        // Create food log immediately with processing state
        final processingFoodLog = FoodLog(
          userId: '', // Will be set by repository
          foodName: 'Analyzing chair (debug test)...', 
          mealType: MealType.lunch,
          nutritionData: NutritionData(
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            sugar: 0,
            fiber: 0,
            sodium: 0,
            micronutrients: {},
            servingInfo: ServingInfo(
              amount: 0,
              unit: 'g',
              weight: 0,
              weightUnit: 'g',
            ),
          ),
          loggedAt: _composeLogDate(),
          imageUrl: foodLogId, // Store the food log ID for Firebase Storage reference
        );
        
        // Add processing food log immediately with pre-generated ID
        await _nutritionRepository.addFoodLogWithId(processingFoodLog.copyWith(id: foodLogId));
        final foodLogWithId = processingFoodLog.copyWith(id: foodLogId);
        
        // No need to update tracking - we used the final ID from the start
        
        // Small delay to ensure the analyzing state is visible
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Navigate back to dashboard
        if (mounted) {
          Navigator.pop(context);
        }
        
        // Continue processing in background
        debugPrint('=== STARTING BACKGROUND PROCESSING (TEST CHAIR IMAGE) ===');
        debugPrint('Test chair image path: ${tempFile.path}');
        debugPrint('Food log ID: ${foodLogWithId.id}');
        _processImageInBackground(tempFile.path, foodLogWithId);
      }
    } catch (e) {
      debugPrint('Error using test chair image: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to analyze test chair image: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isScanning = false;
        });
        _scanAnimationController.stop();
        _progressAnimationController.stop();
      }
    }
  }
  
  // Pick image from gallery
  Future<void> _pickImageFromGallery() async {
    try {
      // Track gallery button tap
      MixpanelService.trackButtonTap('Pick Food Image from Gallery');
      
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      
      if (pickedFile == null) {
        return; // User cancelled
      }
      
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });
      
      // Convert XFile to File
      final File imageFile = File(pickedFile.path);
      
      // Read and process the image
      final Uint8List photoBytes = await imageFile.readAsBytes();
      debugPrint('Gallery image size: ${photoBytes.lengthInBytes} bytes');
      
      // Process similar to camera capture
      setState(() {
        _imageFile = imageFile;
        _isScanning = true;
      });
      
      // Start scanner animation
      _scanAnimationController.repeat();
      _progressAnimationController.forward();
      
      // Start progress updates
      _startProgressSimulation();
      
      if (mounted) {
        // Generate the final FoodLog ID upfront for gallery image
        final foodLogId = FirebaseFirestore.instance
            .collection('users')
            .doc() // This generates a unique ID
            .id;
        
        // Save image thumbnail immediately with final ID
        await _imageService.saveFoodImage(foodLogId, photoBytes);
        debugPrint('📷 Gallery image thumbnail saved with final ID: $foodLogId');

        // Create food log immediately with processing state
        final processingFoodLog = FoodLog(
          userId: '', // Will be set by repository
          foodName: AppLocalizations.of(context)!.translate('calorieTracker_analyzingFood'), 
          mealType: MealType.lunch,
          nutritionData: NutritionData(
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            sugar: 0,
            fiber: 0,
            sodium: 0,
            micronutrients: {},
            servingInfo: ServingInfo(
              amount: 0,
              unit: 'g',
              weight: 0,
              weightUnit: 'g',
            ),
          ),
          loggedAt: _composeLogDate(),
          imageUrl: foodLogId, // Store the food log ID for Firebase Storage reference
        );
        
        // Add processing food log immediately with pre-generated ID
        debugPrint('=== CREATING PROCESSING FOOD LOG (GALLERY) ===');
        debugPrint('Food name: ${processingFoodLog.foodName}');
        debugPrint('Calories: ${processingFoodLog.nutritionData.calories}');
        debugPrint('Food log ID (pre-generated): $foodLogId');
        await _nutritionRepository.addFoodLogWithId(processingFoodLog.copyWith(id: foodLogId));
        debugPrint('Created food log with ID: $foodLogId');
        final foodLogWithId = processingFoodLog.copyWith(id: foodLogId);
        
        // No need to update tracking - we used the final ID from the start
        
              // Small delay to ensure the analyzing state is visible
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Navigate back to dashboard
      if (mounted) {
        Navigator.pop(context);
      }
      
      // Continue processing in background
      debugPrint('=== STARTING BACKGROUND PROCESSING (GALLERY) ===');
        debugPrint('Image path: ${imageFile.path}');
        debugPrint('Food log ID: ${foodLogWithId.id}');
        _processImageInBackground(imageFile.path, foodLogWithId);
      }
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '${AppLocalizations.of(context)!.translate('calorieTracker_failedToAnalyzeFood')}: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isScanning = false;
        });
        _scanAnimationController.stop();
        _progressAnimationController.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          l10n.translate('calorieTracker_scanFood'),
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Help button in the app bar
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: _openHealthInfo,
          ),
        ],
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Stack(
        children: [
          // Full black background
          Positioned.fill(
            child: Container(color: Colors.black),
          ),
          
          // Conditional UI based on permission, initialization, and scanning state
          if (_isScanning && _imageFile != null)
             _buildScanningOverlay() // Show scanning overlay first if scanning
          else if (_isPermissionGranted && _controller != null && _controller!.value.isInitialized)
            _buildCameraPreview() // Show camera if permission granted and initialized
          else if (_errorMessage != null)
            Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            )
          else // Otherwise, show loading/error state
            _buildLoadingIndicator(),
          
          // One-second tap feedback popup (orange circle)
          if (_showTapProcessing) _buildTapFeedbackPopup(),
            
        ],
      ),

    );
  }
  
  Widget _buildCameraPreview() {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Wrap camera preview with gesture detector for zoom
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (ScaleStartDetails details) {
                _baseScale = _currentZoomLevel;
              },
              onScaleUpdate: (ScaleUpdateDetails details) {
                // Only zoom if scale is changing (to avoid conflict with other gestures)
                if (details.scale != 1.0) {
                  // Calculate new zoom level
                  double newZoomLevel = (_baseScale * details.scale).clamp(
                    _minAvailableZoom,
                    _maxAvailableZoom,
                  );
                  
                  // Only update if it's significantly different
                  if ((newZoomLevel - _currentZoomLevel).abs() > 0.05) {
                    _setZoomLevel(newZoomLevel);
                  }
                }
              },
              child: CameraPreview(_controller!),
            ),
            
            // Camera overlay guides
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(32),
                child: Stack(
                  children: [
                    // Top left corner
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.white, width: 3),
                            left: BorderSide(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                    
                    // Top right corner
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.white, width: 3),
                            right: BorderSide(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                    
                    // Bottom left corner
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white, width: 3),
                            left: BorderSide(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                    
                    // Bottom right corner
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white, width: 3),
                            right: BorderSide(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                    ),
                    
                    // Text guides in the center
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.translate('calorieTracker_centerFoodInFrame'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 3.0,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.translate('calorieTracker_takeClearPhoto'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w400,
                              shadows: const [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 3.0,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Add zoom level indicator
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentZoomLevel.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            
            // Add zoom buttons for manual control
            Positioned(
              right: 16,
              bottom: 100, // Position above the capture button
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zoom in button
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        double newZoom = (_currentZoomLevel + 0.5).clamp(
                          _minAvailableZoom,
                          _maxAvailableZoom,
                        );
                        _setZoomLevel(newZoom);
                      },
                    ),
                  ),
                  
                  // Zoom out button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.remove, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        double newZoom = (_currentZoomLevel - 0.5).clamp(
                          _minAvailableZoom,
                          _maxAvailableZoom,
                        );
                        _setZoomLevel(newZoom);
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Add label to indicate pinch to zoom
            Positioned(
              bottom: 150,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pinch_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!.translate('foodScan_guide_pinchToZoom'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontFamily: 'ElzaRound',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom buttons (camera capture and gallery)
            if (!_isScanning && !_isProcessing)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Gallery button with label
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.photo_library, color: Colors.white, size: 28),
                            onPressed: _pickImageFromGallery,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.translate('calorieTracker_addPhoto'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 40),
                    // Capture button with label
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _captureAndAnalyze,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFFed3272), // Brand pink
                                  Color(0xFFfd5d32), // Brand orange
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.translate('calorieTracker_capture'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  


  // Rounded translucent control button used for X and ?

  Future<void> _openHealthInfo() async {
    try {
      final Uri url = Uri.parse(_healthNotionUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.inAppWebView);
      }
    } catch (_) {}
  }
  
  Widget _buildScanningOverlay() {
    return Stack(
      children: [
        // Display captured image
        Container(
          color: Colors.black,
          child: Center(
            child: _imageFile != null
                ? Image.file(
                    _imageFile!,
                    fit: BoxFit.contain,
                  )
                : Container(),
          ),
        ),
        
        // Semi-transparent overlay
        Container(
          color: Colors.black.withOpacity(0.7),
        ),
        
        // Progress card - Cal AI style
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  AppLocalizations.of(context)!.translate('calorieTracker_analyzingFood'),
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Circular progress with percentage
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: _analysisProgress,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange.shade400,
                        ),
                      ),
                    ),
                    Text(
                      '${(_analysisProgress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 28,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Progress bar
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 300),
                    widthFactor: _analysisProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.orange.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Helper text
                Text(
                  AppLocalizations.of(context)!.translate('calorieTracker_notifyWhenDone'),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontFamily: 'ElzaRound',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // One-second tap feedback popup (white card + orange circular progress)
  Widget _buildTapFeedbackPopup() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          color: Colors.black.withOpacity(0.6),
          child: Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade400),
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.translate('calorieTracker_analyzingFood'),
                    style: const TextStyle(
                      color: Colors.black,
                      fontFamily: 'ElzaRound',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget for Loading Indicator (now handles initial check and init states)
  Widget _buildLoadingIndicator() {
    String message = _isCheckingPermission 
        ? AppLocalizations.of(context)!.translate('calorieTracker_checkingPermissions') 
        : AppLocalizations.of(context)!.translate('calorieTracker_initializingCamera');
    if (!_isPermissionGranted && !_isCheckingPermission) {
       message = AppLocalizations.of(context)!.translate('calorieTracker_cameraPermissionDenied');
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isPermissionGranted || _isCheckingPermission) // Show spinner only if checking or granted but initializing
             const CircularProgressIndicator(color: Colors.white),
          if (!_isPermissionGranted && !_isCheckingPermission) // Show error icon if denied
             const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0), // Add padding for longer messages
            child: Text(
              message,
              textAlign: TextAlign.center, // Center align text
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontFamily: 'ElzaRound',
                fontSize: 16, // Slightly larger text
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Food confirmation screen
class FoodConfirmationScreen extends StatefulWidget {
  final NutritionData nutritionData;
  final String imagePath;
  final String? tempId;
  final String? initialImagePath;

  const FoodConfirmationScreen({
    super.key,
    required this.nutritionData,
    required this.imagePath,
    this.tempId,
    this.initialImagePath,
  });

  @override
  State<FoodConfirmationScreen> createState() => _FoodConfirmationScreenState();
}

class _FoodConfirmationScreenState extends State<FoodConfirmationScreen> {
  final _nameController = TextEditingController();
  MealType _selectedMealType = MealType.lunch;
  bool _isSaving = false;
  final _nutritionRepository = NutritionRepository();

  // Local helper for legacy confirmation flow
  DateTime _composeLogDate() {
    // If this flow is used, we don't have a selected date context; default to now
    final now = DateTime.now();
    return now;
  }

  @override
  void initState() {
    super.initState();
    // Track page view
    MixpanelService.trackPageView('Food Confirmation Screen');
  }

  Future<void> _saveFoodLog() async {
    if (_nameController.text.isEmpty || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Generate final ID if not provided
      final foodLogId = widget.tempId ?? FirebaseFirestore.instance
          .collection('users')
          .doc()
          .id;
          
      // Create food log with the ID
      final foodLog = FoodLog(
        id: foodLogId, 
        userId: '', // Will be set by repository
        foodName: _nameController.text,
        mealType: _selectedMealType,
        nutritionData: widget.nutritionData,
        loggedAt: _composeLogDate(),
        imageUrl: foodLogId, // Store the food log ID for Firebase Storage reference
      );

      // Save to Firestore with the specified ID
      await _nutritionRepository.addFoodLogWithId(foodLog);

      // Track success
      MixpanelService.trackButtonTap('Save Food Log', 
        additionalProps: {
          'meal_type': _selectedMealType.name,
          'calories': widget.nutritionData.calories,
        });

      if (mounted) {
        // Navigate back to dashboard
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.translate('error_generic').replaceAll('{error}', e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            l10n.translate('calorieTracker_confirmFood'),
            style: const TextStyle(
              color: Colors.black,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _saveFoodLog,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      l10n.translate('common_save'),
                      style: const TextStyle(
                        color: Colors.black,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Food image
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: widget.imagePath.startsWith('assets/')
                        ? AssetImage(widget.imagePath) as ImageProvider
                        : FileImage(File(widget.imagePath)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Food name input
              TextField(
                controller: _nameController,
                style: const TextStyle(
                  color: Colors.black,
                  fontFamily: 'ElzaRound',
                ),
                decoration: InputDecoration(
                  labelText: l10n.translate('calorieTracker_foodName'),
                  labelStyle: TextStyle(
                    color: Colors.black.withOpacity(0.6),
                    fontFamily: 'ElzaRound',
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.black.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Meal type selector
              Text(
                l10n.translate('calorieTracker_mealType'),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                children: MealType.values.map((type) {
                  final isSelected = type == _selectedMealType;
                  return ChoiceChip(
                    label: Text(_getMealTypeLabel(type, l10n)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedMealType = type;
                      });
                    },
                    selectedColor: Colors.black,
                    backgroundColor: Colors.grey.shade200,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black,
                      fontFamily: 'ElzaRound',
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // Nutrition info
              _buildNutritionSummary(),
            ],
          ),
        ),
      );
  }

  Widget _buildNutritionSummary() {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('calorieTracker_nutritionInfo'),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildNutritionRow(
            l10n.translate('calorieTracker_calories'),
            '${widget.nutritionData.calories.toInt()}',
            const Color(0xFFFF6B35), // Orange
          ),
          _buildNutritionRow(
            l10n.translate('calorieTracker_protein'),
            '${widget.nutritionData.protein.toInt()}g',
            const Color(0xFFE57373), // Light red  
          ),
          _buildNutritionRow(
            l10n.translate('calorieTracker_carbs'),
            '${widget.nutritionData.carbs.toInt()}g',
            const Color(0xFFFFD54F), // Light yellow/gold
          ),
          _buildNutritionRow(
            l10n.translate('calorieTracker_fat'),
            '${widget.nutritionData.fat.toInt()}g',
            const Color(0xFF64B5F6), // Light blue
          ),
          _buildNutritionRow(
            l10n.translate('calorieTracker_sugar'),
            '${widget.nutritionData.sugar.toInt()}g',
            const Color(0xFFE91E63),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.8),
                  fontSize: 14,
                  fontFamily: 'ElzaRound',
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getMealTypeLabel(MealType type, AppLocalizations l10n) {
    switch (type) {
      case MealType.breakfast:
        return l10n.translate('calorieTracker_breakfast');
      case MealType.lunch:
        return l10n.translate('calorieTracker_lunch');
      case MealType.dinner:
        return l10n.translate('calorieTracker_dinner');
      case MealType.snack:
        return l10n.translate('calorieTracker_snack');
    }
  }
}
