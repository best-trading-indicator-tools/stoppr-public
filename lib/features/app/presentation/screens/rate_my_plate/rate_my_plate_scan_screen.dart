import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http; // For Groq API calls
import 'dart:convert'; // For JSON encoding/decoding
import 'package:stoppr/core/config/env_config.dart';
import '../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../core/localization/app_localizations.dart'; // Import AppLocalizations
import '../../../../../core/navigation/page_transitions.dart';
import 'rate_my_plate_results_screen.dart';
import '../../../../../main.dart'; // Import to access global cameras list
import 'package:stoppr/permissions/permission_service.dart';
import '../../../../../core/usage/feature_quota_service.dart'; // Add quota service
import 'package:superwallkit_flutter/superwallkit_flutter.dart'; // Add Superwall import
import 'package:stoppr/core/api_rate_limit/api_rate_limit_service.dart'; // For API rate limiting

class RateMyPlateScanScreen extends StatefulWidget {
  const RateMyPlateScanScreen({Key? key}) : super(key: key);

  @override
  State<RateMyPlateScanScreen> createState() => _RateMyPlateScanScreenState();
}

class _RateMyPlateScanScreenState extends State<RateMyPlateScanScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isPermissionGranted = false; // Track permission status
  bool _isCheckingPermission = true; // Track initial permission check/request
  bool _isAnalyzing = false;
  bool _isTakingPicture = false;
  File? _imageFile;
  final PermissionService _permissionService = PermissionService();
  
  // Feature quota service
  final _quotaService = FeatureQuotaService();
  bool _hasRecordedUsage = false; // Prevent multiple quota recordings
  
  // Add zoom-related variables
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoomLevel = 1.0;
  double _baseScale = 1.0;
  
  // Animation controller for scanner effect
  late AnimationController _analyzeAnimationController;
  late Animation<double> _analyzeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Reset any previous scan state
    _resetScanState();
    
    // Force status bar icons to dark mode for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for white bg
      statusBarBrightness: Brightness.light, // For iOS
    ));
    
    // Initialize scanner animation
    _analyzeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _analyzeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _analyzeAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Track page view with Mixpanel
    MixpanelService.trackPageView('Rate My Plate Scan Screen');
  }

  // Reset all scan-related state variables and request permission
  void _resetScanState() {
    _isCameraInitialized = false;
    _isPermissionGranted = false;
    _isCheckingPermission = true; // Start in checking state
    _isAnalyzing = false;
    _isTakingPicture = false;
    _imageFile = null;
    _hasRecordedUsage = false; // Reset usage flag for new scan
    
    // Check and request permission on load
    _checkAndRequestPermissionOnInit();
  }

  // Check and request permission when the screen initializes
  Future<void> _checkAndRequestPermissionOnInit() async {
    bool granted = await _permissionService.isCameraGranted();
    
    if (!granted) {
      // Track when the permission dialog is about to be shown
      MixpanelService.trackEvent('Rate My Plate Camera Permission Launched');
      MixpanelService.setUserProfileProperty('Rate My Plate Camera Permission Status', 'Not Granted');
      // Request permission if not already granted
      granted = await _permissionService.requestCameraPermission();
    }

    if (!mounted) return; // Guard before setState and further async calls

    setState(() {
      _isPermissionGranted = granted;
      _isCheckingPermission = false; // Finished checking/requesting
    });
    if (granted) {
      MixpanelService.trackEvent('Rate My Plate Camera Permission Accepted');
      MixpanelService.setUserProfileProperty('Rate My Plate Camera Permission Status', 'Accepted');
      await _initializeCamera();
    } else {
      MixpanelService.setUserProfileProperty('Rate My Plate Camera Permission Status', 'Denied');
      // Ensure context is available for AppLocalizations
      if (!mounted) return;
      _showPermissionDeniedMessage(AppLocalizations.of(context)!.translate('rateMyPlateScan_cameraPermissionName'));
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return; // Guard at the beginning

    // Ensure permission is granted before initializing
    if (!_isPermissionGranted) return; 
    
    try {
      if (cameras.isEmpty) {
        if (!mounted) return; // Guard before using context
        debugPrint(AppLocalizations.of(context)!.translate('rateMyPlateScan_debugNoCamerasAvailable'));
        _showErrorDialog(AppLocalizations.of(context)!.translate('rateMyPlateScan_noCamerasAvailableDevice'));
        if (mounted) setState(() => _isCameraInitialized = false);
        return;
      }
      
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      
      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      
      await _controller!.initialize();
      if (!mounted) return; // Guard after await
      
      // Reduce preview tremble by locking auto adjustments after init
      try {
        await _controller!.setFocusMode(FocusMode.locked);
        await _controller!.setExposureMode(ExposureMode.locked);
      } catch (_) {
        // Silently ignore if not supported
      }
      
      // Get available zoom levels after camera is initialized
      await _getAvailableZoomLevels();
      if (!mounted) return; // Guard after await
      
      setState(() { // setState is implicitly guarded by the checks above
        _isCameraInitialized = true;
      });
    } catch (e) {
      if (!mounted) return; // Guard in catch block
      debugPrint(AppLocalizations.of(context)!.translate('rateMyPlateScan_debugErrorInitializingCamera').replaceFirst('{e}', e.toString()));
      _showErrorDialog(AppLocalizations.of(context)!.translate('rateMyPlateScan_errorInitializingCamera'));
       if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  // Get min/max zoom levels supported by the camera
  Future<void> _getAvailableZoomLevels() async {
    if (!mounted) return; // Guard at the beginning
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      _minAvailableZoom = await _controller!.getMinZoomLevel();
      if (!mounted) return; // Guard after await
      _maxAvailableZoom = await _controller!.getMaxZoomLevel();
      if (!mounted) return; // Guard after await
      
      // Some devices return unreasonable values, so cap them at sane limits
      _maxAvailableZoom = _maxAvailableZoom.clamp(1.0, 10.0);
      
      // Set current zoom to min initially
      _currentZoomLevel = _minAvailableZoom;
      
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return; // Guard in catch block
      debugPrint(AppLocalizations.of(context)!.translate('rateMyPlateScan_debugErrorGettingZoomLevels').replaceFirst('{e}', e.toString()));
      // Use default values if we can't get device-specific ones
      _minAvailableZoom = 1.0;
      _maxAvailableZoom = 3.0;
      _currentZoomLevel = 1.0;
    }
  }

  // Set zoom level with bounds checking
  Future<void> _setZoomLevel(double value) async {
    if (!mounted) return; // Guard at the beginning
    if (_controller == null || !_controller!.value.isInitialized) return;

    // Ensure the value is within available zoom range
    value = value.clamp(_minAvailableZoom, _maxAvailableZoom);

    try {
      await _controller!.setZoomLevel(value);
      if (!mounted) return; // Guard after await
      setState(() {
        _currentZoomLevel = value;
      });
    } catch (e) {
      if (!mounted) return; // Guard in catch block
      debugPrint(AppLocalizations.of(context)!.translate('rateMyPlateScan_debugErrorSettingZoomLevel').replaceFirst('{e}', e.toString()));
    }
  }

  Future<void> _takeAndAnalyzePicture() async {
    if (!mounted) return; // Guard at the beginning
    if (_controller == null || !_controller!.value.isInitialized || _isTakingPicture) {
      return;
    }
    
    // FEATURE FLAG: Temporarily disable quota system for A/B test
    const bool QUOTA_SYSTEM_ENABLED = false; // Set to true to re-enable quota system
    
    // Check quota before processing scan (DISABLED for A/B test)
    if (QUOTA_SYSTEM_ENABLED) {
      final canUse = await _quotaService.canUseRateMyPlate();
      if (!canUse) {
        MixpanelService.trackButtonTap('Rate My Plate Quota Exceeded Paywall Shown');
        _showPaywall();
        return;
      }
    }
    
    try {
      setState(() {
        _isTakingPicture = true;
      });
      
      // Take picture
      final XFile photo = await _controller!.takePicture();
      if (!mounted) return; // Guard after await
      
      // Create a more permanent file
      final Directory dir = await getTemporaryDirectory();
      if (!mounted) return; // Guard after await (though getTemporaryDirectory is sync, good practice with path)
      final String filePath = path.join(dir.path, 'plate_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      // Save the file to the new location
      final File newImage = File(filePath);
      await File(photo.path).copy(filePath);
      if (!mounted) return; // Guard after await
      
      setState(() {
        _imageFile = newImage;
        _isAnalyzing = true;
      });
      
      // Start animation
      _analyzeAnimationController.forward();
      
      // Analyze the image with OpenAI Vision API
      try {
        final isFood = await _analyzeFood(newImage.path);
        if (!mounted) return; // Guard after await
        
        if (!isFood) {
          // Non-food item detected - show branded error dialog
          debugPrint('Non-food item detected in plate, showing error dialog');
          setState(() {
            _isAnalyzing = false;
            _isTakingPicture = false;
          });
          _analyzeAnimationController.stop();
          _showNonFoodDialog();
          return;
        }
        
        // Food detected - record usage and proceed to results screen
        debugPrint('Food detected in plate, proceeding to results screen');
        
        // Record rate my plate usage ONLY after successful completion (and only once) (DISABLED for A/B test)
        if (QUOTA_SYSTEM_ENABLED && !_hasRecordedUsage) {
          await _quotaService.recordRateMyPlateUse();
          _hasRecordedUsage = true;
        }
        
        // Navigate to results screen
        Navigator.of(context).pushReplacement(
          FadePageRoute(
            child: RateMyPlateResultsScreen(imageFile: _imageFile!),
            settings: const RouteSettings(name: '/rate_my_plate_results'),
          ),
        );
      } catch (e) {
        // API error - show generic error but allow continuation
        debugPrint('Error during plate food analysis: $e');
        if (!mounted) return; // Guard after await
        
        // For API errors, we'll be permissive and allow the user to continue
        // This prevents blocking users when the API is down
        
        // Record rate my plate usage even on API error (DISABLED for A/B test)
        if (QUOTA_SYSTEM_ENABLED && !_hasRecordedUsage) {
          await _quotaService.recordRateMyPlateUse();
          _hasRecordedUsage = true;
        }
        
        Navigator.of(context).pushReplacement(
          FadePageRoute(
            child: RateMyPlateResultsScreen(imageFile: _imageFile!),
            settings: const RouteSettings(name: '/rate_my_plate_results'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return; // Guard in catch block
      debugPrint(AppLocalizations.of(context)!.translate('rateMyPlateScan_debugErrorTakingPicture').replaceFirst('{e}', e.toString()));
      setState(() {
        _isTakingPicture = false;
        _isAnalyzing = false;
      });
      _showErrorDialog(AppLocalizations.of(context)!.translate('rateMyPlateScan_errorTakingPicture'));
    }
  }
  
  // Debug method to use a test image for simulators
  Future<void> _useTestPlateImage() async {
    if (!mounted) return; // Guard at the beginning
    
    // FEATURE FLAG: Temporarily disable quota system for A/B test
    const bool QUOTA_SYSTEM_ENABLED = false; // Set to true to re-enable quota system
    
    // Check quota before processing test scan (DISABLED for A/B test)
    if (QUOTA_SYSTEM_ENABLED) {
      final canUse = await _quotaService.canUseRateMyPlate();
      if (!canUse) {
        MixpanelService.trackButtonTap('Rate My Plate Test Image Quota Exceeded Paywall Shown');
        _showPaywall();
        return;
      }
    }
    
    try {
      setState(() {
        _isAnalyzing = true;
      });
      
      // Create a temporary file from the asset
      final ByteData data = await rootBundle.load('assets/images/food_scan_samples/pizza-bijou.jpg');
      if (!mounted) return; // Guard after await
      final Directory tempDir = await getTemporaryDirectory();
      if (!mounted) return; // Guard after await (sync but good practice)
      final String tempPath = path.join(tempDir.path, 'test_plate.jpg');
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      if (!mounted) return; // Guard after await
      
      setState(() {
        _imageFile = tempFile;
      });
      
      // Start animation
      _analyzeAnimationController.forward();
      
      // Analyze the test image with OpenAI Vision API
      try {
        final isFood = await _analyzeFood(tempFile.path);
        if (!mounted) return; // Guard after await
        
        if (!isFood) {
          // Non-food item detected - show branded error dialog
          debugPrint('Non-food item detected in test plate image, showing error dialog');
          setState(() {
            _isAnalyzing = false;
          });
          _analyzeAnimationController.stop();
          _showNonFoodDialog();
          return;
        }
        
        // Food detected - record usage and proceed to results screen
        debugPrint('Food detected in test plate image, proceeding to results screen');
        
        // Record rate my plate usage ONLY after successful completion (and only once) (DISABLED for A/B test)
        if (QUOTA_SYSTEM_ENABLED && !_hasRecordedUsage) {
          await _quotaService.recordRateMyPlateUse();
          _hasRecordedUsage = true;
        }
        
        // Navigate to results screen
        Navigator.of(context).pushReplacement(
          FadePageRoute(
            child: RateMyPlateResultsScreen(imageFile: _imageFile!),
            settings: const RouteSettings(name: '/rate_my_plate_results'),
          ),
        );
      } catch (e) {
        // API error - allow continuation for test image
        debugPrint('Error during test plate food analysis: $e');
        if (!mounted) return; // Guard after await
        
        // For test image API errors, we'll be permissive and allow continuation
        
        // Record rate my plate usage even on API error (DISABLED for A/B test)
        if (QUOTA_SYSTEM_ENABLED && !_hasRecordedUsage) {
          await _quotaService.recordRateMyPlateUse();
          _hasRecordedUsage = true;
        }
        
        Navigator.of(context).pushReplacement(
          FadePageRoute(
            child: RateMyPlateResultsScreen(imageFile: _imageFile!),
            settings: const RouteSettings(name: '/rate_my_plate_results'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return; // Guard in catch block
      debugPrint(AppLocalizations.of(context)!.translate('rateMyPlateScan_debugErrorUsingTestPlateImage').replaceFirst('{e}', e.toString()));
      setState(() {
        _isAnalyzing = false;
      });
      _showErrorDialog(AppLocalizations.of(context)!.translate('rateMyPlateScan_errorLoadingTestImage').replaceFirst('{e}', e.toString()));
    }
  }

  // OpenAI Vision API analysis method to detect food items for plate rating
  Future<bool> _analyzeFood(String imagePath) async {
    try {
      debugPrint('Starting food analysis for plate rating: $imagePath');
      
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
      
      // Read the image
      final imageBytes = await File(imagePath).readAsBytes();
      debugPrint('Image loaded: ${imageBytes.length} bytes');
      final base64Image = base64Encode(imageBytes);
      debugPrint('Image encoded to base64: ${base64Image.length} characters');

      // Increment global API request count before making network call
      final incremented = await ApiRateLimitService.incrementRequestCount();
      if (!incremented) {
        throw Exception('Rate limit exceeded');
      }

      // Call Groq Vision API with timeout
      debugPrint('Making API call to Groq for plate rating...');
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
              'content': '''You are a nutrition expert AI that analyzes meal plate images for nutritional evaluation.
Your task is to identify if this image contains a meal or plate with food/drink items that can be nutritionally evaluated.

ALWAYS return ONLY a valid JSON object with exactly this structure (no prose):

For images that contain at least ONE food item OR drink item that can be nutritionally evaluated (even if other objects are visible):
{
  "isFood": true,
  "reason": "Brief description of the meal/food/drink items identified"
}

For images that contain NO consumable food or drink items suitable for nutritional evaluation:
{
  "isFood": false,
  "reason": "Brief explanation of what this is instead of consumable items"
}

Rules:
- Look for plates, bowls, meals, snacks, beverages, or any consumable items
- If you find at least one food item OR at least one drink item, return isFood: true
- Images with both food AND drinks should return isFood: true
- Only return isFood: false if NO consumable items are present for evaluation
- Focus on items that can actually be consumed (eaten or drunk) and nutritionally assessed
- Do not include any text outside the JSON.'''
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Analyze this plate/meal image and determine if it contains at least one food item or at least one drink item that can be nutritionally evaluated.',
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
          'max_tokens': 300,
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
        
        // Check if OpenAI responded with plain text (fallback for old behavior)
        if (!cleanContent.startsWith('{') || !cleanContent.endsWith('}')) {
          debugPrint('OpenAI detected non-food item, response: $cleanContent');
          return false;
        }
        
        // Parse the JSON response
        final analysisJson = jsonDecode(cleanContent);
        debugPrint('Parsed analysis JSON: $analysisJson');
        
        // Check if OpenAI detected food/drink items suitable for plate rating
        final isFood = analysisJson['isFood'] ?? false;
        final reason = analysisJson['reason'] ?? 'Unknown reason';
        
        debugPrint('OpenAI plate analysis result: isFood=$isFood, reason=$reason');
        return isFood;
      } else {
        final errorBody = utf8.decode(
          response.bodyBytes,
          allowMalformed: true,
        );
        debugPrint('API error response body: $errorBody');
        throw Exception('API request failed: ${response.statusCode} - $errorBody');
      }
    } catch (e, stackTrace) {
      debugPrint('Error analyzing plate food: $e');
      debugPrint('Stack trace: $stackTrace');
      throw e;
    }
  }

  // Show branded error dialog for non-food detection in plate rating
  void _showNonFoodDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Non-food plate icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFFed3272).withOpacity(0.1), // Brand pink
                      const Color(0xFFfd5d32).withOpacity(0.1), // Brand orange
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.no_meals,
                  color: Color(0xFFed3272), // Brand pink
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                AppLocalizations.of(context)!.translate('calorieTracker_nonFoodDetected'),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                AppLocalizations.of(context)!.translate('calorieTracker_nonFoodDetected'),
                style: const TextStyle(
                  color: Color(0xFF666666), // Gray text
                  fontFamily: 'ElzaRound',
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Try Again Button with gradient
              SizedBox(
                width: double.infinity,
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
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Try Again',
                      style: const TextStyle(
                        color: Colors.white, // White text on gradient
                        fontFamily: 'ElzaRound',
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showErrorDialog(String message) {
    if (!mounted) return; // Guard at the beginning
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Color(0xFFFF5252),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                AppLocalizations.of(context)!.translate('rateMyPlateScan_dialogTitleError'),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // Message
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontFamily: 'ElzaRound',
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // OK Button with gradient
              SizedBox(
                width: double.infinity,
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
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.translate('rateMyPlateScan_dialogButtonOK'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'ElzaRound',
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // DEBUG ONLY: Reset all quotas for testing
  Future<void> _debugResetQuotas() async {
    if (!kDebugMode) return;
    
    try {
      await _quotaService.debugResetAllQuotas();
      
      // Show confirmation snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎉 DEBUG: All quotas reset! You can test features again.',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'ElzaRound',
              ),
            ),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error resetting quotas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Failed to reset quotas: $e',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'ElzaRound',
              ),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Method to show paywall when quota exceeded
  Future<void> _showPaywall() async {
    try {
      // Create a handler for paywall presentation
      PaywallPresentationHandler handler = PaywallPresentationHandler();
      
      handler.onPresent((paywallInfo) async {
        String? name = await paywallInfo.name;
        debugPrint("Rate My Plate Paywall presented: ${name ?? 'Unknown'}");
        MixpanelService.trackEvent('Rate My Plate Quota Paywall Presented', 
          properties: {'paywall_name': name ?? 'Unknown'}
        );
      });

      handler.onDismiss((paywallInfo, paywallResult) async {
        String? name = await paywallInfo.name;
        debugPrint("Rate My Plate Paywall dismissed: ${name ?? 'Unknown'}, Result: $paywallResult");
        MixpanelService.trackEvent('Rate My Plate Quota Paywall Dismissed', 
          properties: {
            'paywall_name': name ?? 'Unknown',
            'result': paywallResult?.toString() ?? 'null'
          }
        );
      });

      handler.onError((error) {
        debugPrint("Rate My Plate Paywall error: $error");
        MixpanelService.trackEvent('Rate My Plate Quota Paywall Error', 
          properties: {'error': error.toString()}
        );
      });

      handler.onSkip((skipReason) async {
        String reasonString = skipReason.toString();
        debugPrint("Rate My Plate Paywall skipped: $reasonString");
        MixpanelService.trackEvent('Rate My Plate Quota Paywall Skipped', 
          properties: {'reason': reasonString}
        );
      });

      // Register the placement with handlers
      await Superwall.shared.registerPlacement(
        'INSERT_YOUR_STANDARD_PAYWALL_PLACEMENT_ID_HERE',
        handler: handler,
        feature: () async {
          // Reset quotas on successful purchase
          await _quotaService.resetAllQuotas();
          debugPrint('Rate My Plate: Quotas reset after successful purchase');
        },
      );
    } catch (e) {
      debugPrint('Error showing Rate My Plate paywall: $e');
    }
  }

  // Helper function to show a snackbar when permission is denied
  void _showPermissionDeniedMessage(String permissionName) {
    if (!mounted) return; // This was already here, good.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.translate('rateMyPlateScan_permissionDeniedSnackbar').replaceFirst('{permissionName}', permissionName)),
        backgroundColor: Colors.red,
      ),
    );
    setState(() {
      _isCameraInitialized = false; // Reflect denial in UI
    });
  }

  @override
  void dispose() {
    _analyzeAnimationController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FA), // Soft pink-tinted white
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF8FA),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)), // Dark icons
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            AppLocalizations.of(context)!.translate('rateMyPlateScan_appBarTitle'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A), // Dark text
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ),
        actions: [
          // Conditionally show the debug button for iOS debug builds
                      if (kDebugMode && Platform.isIOS)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: IconButton(
                icon: const Icon(
                  Icons.bug_report,
                  color: Color(0xFFed3272), // Brand pink
                  size: 28, 
                ),
                tooltip: AppLocalizations.of(context)!.translate('rateMyPlateScan_tooltipUseTestImage'),
                onPressed: _useTestPlateImage,
              ),
            ),
          // Debug quota reset button
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: Color(0xFF4CAF50), // Green color for reset
                  size: 24,
                ),
                tooltip: 'DEBUG: Reset All Quotas',
                onPressed: _debugResetQuotas,
              ),
            ),
        ],
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Stack(
        children: [
          // Camera background (keep black for camera functionality)
          if (_isPermissionGranted && _isCameraInitialized)
            Positioned.fill(
              child: Container(color: Colors.black),
            )
          else
            // Branded background for loading/error states
            Positioned.fill(
              child: Container(color: const Color(0xFFFDF8FA)),
            ),
          
          // Conditional UI based on permission, initialization, and analyzing state
          if (_isAnalyzing && _imageFile != null)
             _buildAnalyzingOverlay() // Show analyzing overlay first if analyzing
          else if (_isPermissionGranted && _isCameraInitialized)
            _buildCameraPreview() // Show camera if permission granted and initialized
          else // Otherwise, show loading/error state
            _buildLoadingIndicator(), 
        ],
      ),
      floatingActionButton: _isPermissionGranted && _isCameraInitialized && !_isAnalyzing
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFed3272), // Brand pink
                    Color(0xFFfd5d32), // Brand orange
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: FloatingActionButton(
                heroTag: null,
                onPressed: _takeAndAnalyzePicture,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Icon(Icons.camera_alt, color: Colors.white),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // Widget for Camera Preview
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
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: RepaintBoundary(
                    child: CameraPreview(_controller!),
                  ),
                ),
              ),
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
                            AppLocalizations.of(context)!.translate('rateMyPlateScan_guideFrameYourPlate'),
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
                            AppLocalizations.of(context)!.translate('rateMyPlateScan_guideTakePhotoHint'),
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
                        AppLocalizations.of(context)!.translate('rateMyPlateScan_guidePinchToZoom'),
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
          ],
        ),
      ),
    );
  }

  // Widget for Analyzing Overlay
  Widget _buildAnalyzingOverlay() {
    return Stack(
      children: [
        // Display captured image with corrected display
        Container(
          color: Colors.black,
          child: Center(
            child: Image.file(
              _imageFile!,
              fit: BoxFit.contain,
            ),
          ),
        ),
        
        // Scan frame corners (matching the camera overlay)
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
              ],
            ),
          ),
        ),
        
        // Animated scanner line
        AnimatedBuilder(
          animation: _analyzeAnimation,
          builder: (context, child) {
            // Scanner moves up and down
            final double position = _analyzeAnimation.value <= 0.5 
                ? _analyzeAnimation.value * 2 // 0 to 1 during first half
                : (1 - (_analyzeAnimation.value - 0.5) * 2); // 1 to 0 during second half
            
            return Positioned(
              top: MediaQuery.of(context).size.height * position,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Gradient shadow above the line
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          const Color(0xFFed3272).withOpacity(0.2), // Brand pink
                        ],
                      ),
                    ),
                  ),
                  // Main scanner line
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFed3272), // Brand pink
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFed3272).withOpacity(0.7), // Brand pink
                          blurRadius: 8.0,
                          spreadRadius: 2.0,
                        ),
                      ],
                    ),
                  ),
                  // Gradient shadow below the line
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFed3272).withOpacity(0.2), // Brand pink
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        
        // Analyzing text overlay
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  AppLocalizations.of(context)!.translate('rateMyPlateScan_analyzingOverlayText'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 120,
                child: LottieBuilder.asset(
                  'assets/images/lotties/loading.json',
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget for Loading Indicator (now handles initial check and init states)
  Widget _buildLoadingIndicator() {
    String message = _isCheckingPermission 
        ? AppLocalizations.of(context)!.translate('rateMyPlateScan_loadingCheckingPermissions') 
        : AppLocalizations.of(context)!.translate('rateMyPlateScan_loadingInitializingCamera');
    if (!_isPermissionGranted && !_isCheckingPermission) {
       message = AppLocalizations.of(context)!.translate('rateMyPlateScan_loadingPermissionDenied');
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isPermissionGranted || _isCheckingPermission) // Show spinner only if checking or granted but initializing
             const CircularProgressIndicator(color: Color(0xFFed3272)), // Brand pink
          if (!_isPermissionGranted && !_isCheckingPermission) // Show error icon if denied
             const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0), // Add padding for longer messages
            child: Text(
              message,
              textAlign: TextAlign.center, // Center align text
              style: const TextStyle(
                color: Color(0xFF666666), // Gray text
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