import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img; // Added for image processing
import 'dart:typed_data'; // Added for Uint8List
import 'package:http/http.dart' as http; // For OpenAI API calls
import 'dart:convert'; // For JSON encoding/decoding
import 'package:stoppr/core/config/env_config.dart';
// import removed: dotenv no longer used here
import '../../../../../core/analytics/mixpanel_service.dart';
import '../../../../../core/navigation/page_transitions.dart';
import 'food_alternatives_screen.dart';
import '../../../../../main.dart'; // Import to access global cameras list
import 'package:stoppr/permissions/permission_service.dart';
import 'dart:io' show Platform; // Import Platform
import 'package:stoppr/core/localization/app_localizations.dart'; // Added for localization
import '../../../../../core/usage/feature_quota_service.dart'; // Add quota service
import 'package:superwallkit_flutter/superwallkit_flutter.dart'; // Add Superwall import
import 'package:stoppr/core/api_rate_limit/api_rate_limit_service.dart'; // For API rate limiting
import 'package:image_picker/image_picker.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';

class FoodScanScreen extends StatefulWidget {
  const FoodScanScreen({Key? key}) : super(key: key);

  @override
  State<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends State<FoodScanScreen> with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isPermissionGranted = false; // Track permission status
  bool _isCheckingPermission = true; // Added to track initial permission check/request
  bool _isScanning = false;
  bool _isTakingPicture = false;
  File? _imageFile;
  final PermissionService _permissionService = PermissionService();
  final ImagePicker _imagePicker = ImagePicker();
  
  // Feature quota service
  final _quotaService = FeatureQuotaService();
  
  // Add zoom-related variables
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoomLevel = 1.0;
  double _baseScale = 1.0;
  
  // Animation controller for scanner effect
  late AnimationController _scanAnimationController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    
    // Reset any previous scan state
    _resetScanState(); // This now includes permission request
    
    // Set status bar icons to dark mode for light background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for light background
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
    ));
    
    // Initialize scanner animation
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // Track page view with Mixpanel
    MixpanelService.trackPageView('Food Scan Screen');
  }

  // Reset all scan-related state variables and request permission
  void _resetScanState() {
    _isCameraInitialized = false;
    _isPermissionGranted = false;
    _isCheckingPermission = true; // Start in checking state
    _isScanning = false;
    _isTakingPicture = false;
    _imageFile = null;
    
    // Check and request permission on load
    _checkAndRequestPermissionOnInit();
  }

  // Check and request permission when the screen initializes
  Future<void> _checkAndRequestPermissionOnInit() async {
    bool granted = await _permissionService.isCameraGranted();
    
    if (!granted) {
      // Track when the permission dialog is about to be shown
      MixpanelService.trackEvent('Alternative Food Scan Camera Permission Launched');
      MixpanelService.setUserProfileProperty('Alternative Food Scan Camera Permission Status', 'Not Granted');
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
        MixpanelService.trackEvent('Alternative Food Scan Camera Permission Accepted');
        MixpanelService.setUserProfileProperty('Alternative Food Scan Camera Permission Status', 'Accepted');
        await _initializeCamera();
      } else {
        MixpanelService.setUserProfileProperty('Alternative Food Scan Camera Permission Status', 'Denied');
        _showPermissionDeniedMessage(AppLocalizations.of(context)!.translate('foodScan_permissionName_camera'));
        // Optionally navigate away or show a persistent error message
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return; // Add guard at the beginning

    // Ensure permission is granted before initializing
    if (!_isPermissionGranted) return; 
    
    try {
      if (cameras.isEmpty) {
        debugPrint(AppLocalizations.of(context)!.translate('foodScan_debug_noCamerasAvailable'));
        _showErrorDialog(AppLocalizations.of(context)!.translate('foodScan_error_noCamerasDevice'));
        if (mounted) setState(() => _isCameraInitialized = false); // Reflect error
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
      if (!mounted) return; // Add guard after await
      
      // Reduce preview tremble by locking auto adjustments after init
      try {
        await _controller!.setFocusMode(FocusMode.locked);
        await _controller!.setExposureMode(ExposureMode.locked);
      } catch (_) {
        // Silently ignore if not supported on device/platform
      }
      
      // Get available zoom levels after camera is initialized
      await _getAvailableZoomLevels();
      if (!mounted) return; // Add guard after await
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      if (!mounted) return; // Add guard in catch block before using context
      debugPrint(AppLocalizations.of(context)!.translate('foodScan_debug_errorInitializingCamera').replaceFirst('{error}', e.toString()));
      _showErrorDialog(AppLocalizations.of(context)!.translate('foodScan_error_initializingCamera'));
       if (mounted) {
        setState(() {
          _isCameraInitialized = false; // Set to false on error
        });
      }
    }
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
      debugPrint(AppLocalizations.of(context)!.translate('foodScan_debug_errorGettingZoomLevels').replaceFirst('{error}', e.toString()));
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
      debugPrint(AppLocalizations.of(context)!.translate('foodScan_debug_errorSettingZoomLevel').replaceFirst('{error}', e.toString()));
    }
  }

  Future<void> _takeAndAnalyzePicture() async {
    // Strong guard to prevent duplicate scans from rapid taps
    if (_controller == null || !_controller!.value.isInitialized || _isTakingPicture || _isScanning) {
      return;
    }
    
    // FEATURE FLAG: Temporarily disable quota system for A/B test
    const bool QUOTA_SYSTEM_ENABLED = false; // Set to true to re-enable quota system
    
    // Check quota before processing scan (DISABLED for A/B test)
    if (QUOTA_SYSTEM_ENABLED) {
      final canUse = await _quotaService.canUseFoodScan();
      if (!canUse) {
        MixpanelService.trackButtonTap('Food Scan Quota Exceeded Paywall Shown');
        _showPaywall();
        return;
      }
    }
    
    try {
      // Immediately indicate processing and hide the capture button
      setState(() {
        _isTakingPicture = true;
        _isScanning = true; // show processing overlay right away
      });
      
      // Take picture
      final XFile photo = await _controller!.takePicture();
      
      // Read image bytes from XFile
      final Uint8List photoBytes = await photo.readAsBytes();
      debugPrint(AppLocalizations.of(context)!.translate('foodScan_debug_originalImageSize').replaceFirst('{bytes}', photoBytes.lengthInBytes.toString())); // Log original size
      
      final Stopwatch localProcessingStopwatch = Stopwatch()..start(); // Start timing
      
      // Decode image using the image package
      img.Image? originalImage = img.decodeImage(photoBytes);

      if (originalImage == null) {
        debugPrint(AppLocalizations.of(context)!.translate('foodScan_debug_errorDecodingCapturedImage'));
        _showErrorDialog(AppLocalizations.of(context)!.translate('foodScan_error_processingCapturedImage'));
        if (mounted) {
          setState(() {
            _isTakingPicture = false;
            _isScanning = false;
          });
        }
        return;
      }
      
      // Resize the image (e.g., to width 512, height will be proportional)
      img.Image resizedImage = img.copyResize(originalImage, width: 512);
      
      // Encode the resized image to JPEG with desired quality (e.g., 85)
      final List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 85);
      
      localProcessingStopwatch.stop(); // Stop timing
      debugPrint(AppLocalizations.of(context)!.translate('foodScan_debug_localProcessingTime').replaceFirst('{ms}', localProcessingStopwatch.elapsedMilliseconds.toString())); // Log processing time
      debugPrint(AppLocalizations.of(context)!.translate('foodScan_debug_compressedImageSize').replaceFirst('{bytes}', compressedBytes.length.toString())); // Log compressed size
      
      // Create a more permanent file for the compressed image
      final Directory dir = await getTemporaryDirectory();
      final String filePath = path.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg');
      final File newImage = File(filePath);
      await newImage.writeAsBytes(compressedBytes); // Save compressed bytes
      
      setState(() {
        _imageFile = newImage;
        // _isScanning already true from the first tap
      });
      
      // Start scanner animation
      _scanAnimationController.forward();
      
      // Record food scan usage after successful scan (DISABLED for A/B test)
      if (QUOTA_SYSTEM_ENABLED) {
        await _quotaService.recordFoodScanUse();
      }
      
      // Analyze the image with OpenAI Vision API
      try {
        final isFood = await _analyzeFood(newImage.path);
        
        if (!isFood) {
          // Non-food item detected - show branded error dialog
          debugPrint('Non-food item detected, showing error dialog');
          setState(() {
            _isScanning = false;
            _isTakingPicture = false;
          });
          _scanAnimationController.stop();
          _showNonFoodDialog();
          return;
        }
        
        // Food detected - proceed to alternatives screen
        debugPrint('Food detected, proceeding to alternatives screen');
        
        // After analysis completes, navigate to Food Alternatives Screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            FadePageRoute(
              child: FoodAlternativesScreen(imageFile: newImage),
              settings: const RouteSettings(name: '/food_alternatives'),
            ),
          );
        }
      } catch (e) {
        // API error - show generic error but allow continuation
        debugPrint('Error during food analysis: $e');
        
        // For API errors, we'll be permissive and allow the user to continue
        // This prevents blocking users when the API is down
        if (mounted) {
          Navigator.of(context).pushReplacement(
            FadePageRoute(
              child: FoodAlternativesScreen(imageFile: newImage),
              settings: const RouteSettings(name: '/food_alternatives'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint(AppLocalizations.of(context)!.translate('foodScan_debug_errorTakingPicture').replaceFirst('{error}', e.toString()));
      setState(() {
        _isTakingPicture = false;
        _isScanning = false;
      });
      _showErrorDialog(AppLocalizations.of(context)!.translate('foodScan_error_capturingImage'));
    }
  }

  // Pick image from gallery (imports photos option)
  Future<void> _pickImageFromGallery() async {
    try {
      MixpanelService.trackButtonTap('Food Scan Pick Image from Gallery');
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      final Uint8List photoBytes = await File(picked.path).readAsBytes();
      img.Image? original = img.decodeImage(photoBytes);
      if (original == null) {
        _showErrorDialog(AppLocalizations.of(context)!
            .translate('foodScan_error_processingCapturedImage'));
        return;
      }

      final img.Image resized = img.copyResize(original, width: 512);
      final List<int> compressed = img.encodeJpg(resized, quality: 85);

      final Directory dir = await getTemporaryDirectory();
      final String filePath = path.join(
        dir.path,
        '${DateTime.now().millisecondsSinceEpoch}_gallery_compressed.jpg',
      );
      final File newImage = File(filePath);
      await newImage.writeAsBytes(compressed);

      if (!mounted) return;
      setState(() {
        _imageFile = newImage;
        _isScanning = true;
      });
      _scanAnimationController.forward();

      try {
        final isFood = await _analyzeFood(newImage.path);
        if (!isFood) {
          setState(() {
            _isScanning = false;
          });
          _scanAnimationController.stop();
          _showNonFoodDialog();
          return;
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            FadePageRoute(
              child: FoodAlternativesScreen(imageFile: newImage),
              settings: const RouteSettings(name: '/food_alternatives'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            FadePageRoute(
              child: FoodAlternativesScreen(imageFile: newImage),
              settings: const RouteSettings(name: '/food_alternatives'),
            ),
          );
        }
      }
    } catch (e) {
      _showErrorDialog(AppLocalizations.of(context)!
          .translate('foodScan_error_loadingTestImage')
          .replaceFirst('{error}', e.toString()));
    }
  }
  
  // Debug method to use the test pizza image for simulators
  Future<void> _useTestPizzaImage() async {
    // FEATURE FLAG: Temporarily disable quota system for A/B test
    const bool QUOTA_SYSTEM_ENABLED = false; // Set to true to re-enable quota system
    
    // Check quota before processing test scan (DISABLED for A/B test)
    if (QUOTA_SYSTEM_ENABLED) {
      final canUse = await _quotaService.canUseFoodScan();
      if (!canUse) {
        MixpanelService.trackButtonTap('Food Scan Test Image Quota Exceeded Paywall Shown');
        _showPaywall();
        return;
      }
    }
    
    try {
      setState(() {
        _isScanning = true;
      });
      
      // Load asset bytes
      final ByteData data = await rootBundle.load('assets/images/cinnamonbun.jpg');
      final Uint8List assetBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      debugPrint(AppLocalizations.of(context)!.translate('foodScan_debug_originalTestImageSize').replaceFirst('{bytes}', assetBytes.lengthInBytes.toString())); // Log original size

      final Stopwatch localProcessingStopwatchTest = Stopwatch()..start(); // Start timing
      
      // Decode image using the image package
      img.Image? originalImage = img.decodeImage(assetBytes);

      if (originalImage == null) {
        debugPrint(AppLocalizations.of(context)!.translate('foodScan_debug_errorDecodingTestImage'));
        _showErrorDialog(AppLocalizations.of(context)!.translate('foodScan_error_processingTestImage'));
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
        return;
      }
      
      // Resize the image
      img.Image resizedImage = img.copyResize(originalImage, width: 512);
      
      // Encode the resized image to JPEG with desired quality
      final List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 85);
      
      localProcessingStopwatchTest.stop(); // Stop timing
      debugPrint(AppLocalizations.of(context)!.translate('foodScan_debug_localTestImageProcessingTime').replaceFirst('{ms}', localProcessingStopwatchTest.elapsedMilliseconds.toString())); // Log processing time
      debugPrint(AppLocalizations.of(context)!.translate('foodScan_debug_compressedTestImageSize').replaceFirst('{bytes}', compressedBytes.length.toString())); // Log compressed size
      
      // Create a temporary file from the compressed asset
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = path.join(tempDir.path, 'test_pizza_compressed.jpg');
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(compressedBytes); // Save compressed bytes
      
      setState(() {
        _imageFile = tempFile;
      });
      
      // Start scanner animation
      _scanAnimationController.forward();
      
      // Record food scan usage after successful test scan (DISABLED for A/B test)
      if (QUOTA_SYSTEM_ENABLED) {
        await _quotaService.recordFoodScanUse();
      }
      
      // Analyze the test image with OpenAI Vision API
      try {
        final isFood = await _analyzeFood(tempFile.path);
        
        if (!isFood) {
          // Non-food item detected - show branded error dialog
          debugPrint('Non-food item detected in test image, showing error dialog');
          setState(() {
            _isScanning = false;
          });
          _scanAnimationController.stop();
          _showNonFoodDialog();
          return;
        }
        
        // Food detected - proceed to alternatives screen
        debugPrint('Food detected in test image, proceeding to alternatives screen');
        
        // After analysis completes, navigate to Food Alternatives Screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            FadePageRoute(
              child: FoodAlternativesScreen(imageFile: tempFile),
              settings: const RouteSettings(name: '/food_alternatives'),
            ),
          );
        }
      } catch (e) {
        // API error - show generic error but allow continuation for test image
        debugPrint('Error during test food analysis: $e');
        
        // For test image API errors, we'll be permissive and allow continuation
        if (mounted) {
          Navigator.of(context).pushReplacement(
            FadePageRoute(
              child: FoodAlternativesScreen(imageFile: tempFile),
              settings: const RouteSettings(name: '/food_alternatives'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint(AppLocalizations.of(context)!.translate('foodScan_debug_errorUsingTestImage').replaceFirst('{error}', e.toString()));
      setState(() {
        _isScanning = false;
      });
      _showErrorDialog(AppLocalizations.of(context)!.translate('foodScan_error_loadingTestImage').replaceFirst('{error}', e.toString()));
    }
  }

  // OpenAI Vision API analysis method to detect food items
  Future<bool> _analyzeFood(String imagePath) async {
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

      // Call Groq Llama Maverick Vision API with timeout
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
Your task is to identify if this image contains any consumable food or drink items that can be eaten or drunk.

ALWAYS return ONLY a valid JSON object with exactly this structure (no prose):

For images that contain at least ONE food item OR drink item (even if other non-edible items are also visible):
{
  "isFood": true,
  "reason": "Brief description of the food/drink items identified"
}

For images that contain NO consumable food or drink items (only non-consumable items):
{
  "isFood": false,
  "reason": "Brief explanation of what this is instead of food/drink"
}

Rules:
- Look carefully for ANY consumable items (solid food, beverages, snacks, meals, drinks, etc.)
- If you find at least one food item OR at least one drink item, respond with isFood: true
- Images with both food AND drinks should return isFood: true
- Only respond with isFood: false if NO consumable items are present at all
- Focus on items that can actually be consumed (eaten or drunk)
- Do not include any text outside the JSON.'''
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Analyze this image and determine if it contains at least one food item or at least one drink item that can be consumed.',
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
        
        // Check if Groq responded with plain text (fallback for old behavior)
        if (!cleanContent.startsWith('{') || !cleanContent.endsWith('}')) {
          debugPrint('Groq detected non-food item, response: $cleanContent');
          return false;
        }
        
        // Parse the JSON response
        final analysisJson = jsonDecode(cleanContent);
        debugPrint('Parsed analysis JSON: $analysisJson');
        
        // Check if Groq detected food/drink items
        final isFood = analysisJson['isFood'] ?? false;
        final reason = analysisJson['reason'] ?? 'Unknown reason';
        
        debugPrint('Groq analysis result: isFood=$isFood, reason=$reason');
        return isFood;
      } else {
        final errorBody = utf8.decode(
          response.bodyBytes,
          allowMalformed: true,
        );
        debugPrint('API error response body: $errorBody');
        throw Exception('API request failed: ${response.statusCode} - ${TextSanitizer.sanitizeForDisplay(errorBody)}');
      }
    } catch (e, stackTrace) {
      debugPrint('Error analyzing food: $e');
      debugPrint('Stack trace: $stackTrace');
      throw e;
    }
  }

  // Debug method to test non-food image (chair) to see OpenAI behavior
  Future<void> _useTestChairImage() async {
    if (!kDebugMode) return;
    
    // FEATURE FLAG: Temporarily disable quota system for A/B test
    const bool QUOTA_SYSTEM_ENABLED = false; // Set to true to re-enable quota system
    
    // Check quota before processing test scan (DISABLED for A/B test)
    if (QUOTA_SYSTEM_ENABLED) {
      final canUse = await _quotaService.canUseFoodScan();
      if (!canUse) {
        MixpanelService.trackButtonTap('Food Scan Test Chair Image Quota Exceeded Paywall Shown');
        _showPaywall();
        return;
      }
    }
    
    try {
      setState(() {
        _isScanning = true;
      });
      
      // Load chair asset for testing non-food behavior
      final ByteData data = await rootBundle.load('assets/images/chair.jpeg');
      final Uint8List assetBytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      debugPrint('✅ Test chair asset loaded: ${assetBytes.length} bytes');
      
      // Create a temporary file from the asset
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = path.join(tempDir.path, 'test_chair_compressed.jpg');
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(assetBytes);
      
      setState(() {
        _imageFile = tempFile;
      });
      
      // Start scanner animation
      _scanAnimationController.forward();
      
      // Record food scan usage after successful test scan (DISABLED for A/B test)
      if (QUOTA_SYSTEM_ENABLED) {
        await _quotaService.recordFoodScanUse();
      }
      
      // Analyze the test chair image with OpenAI Vision API
      try {
        final isFood = await _analyzeFood(tempFile.path);
        
        if (!isFood) {
          // Non-food item detected - show branded error dialog
          debugPrint('Non-food item (chair) detected in test image, showing error dialog');
          setState(() {
            _isScanning = false;
          });
          _scanAnimationController.stop();
          _showNonFoodDialog();
          return;
        }
        
        // Food detected (unexpected for chair) - proceed to alternatives screen
        debugPrint('Food detected in chair test image (unexpected), proceeding to alternatives screen');
        
        // After analysis completes, navigate to Food Alternatives Screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            FadePageRoute(
              child: FoodAlternativesScreen(imageFile: tempFile),
              settings: const RouteSettings(name: '/food_alternatives'),
            ),
          );
        }
      } catch (e) {
        // API error - show generic error for chair test
        debugPrint('Error during chair test food analysis: $e');
        setState(() {
          _isScanning = false;
        });
        _scanAnimationController.stop();
        _showErrorDialog('Chair test failed: $e');
      }
    } catch (e) {
      debugPrint('Error using test chair image: $e');
      setState(() {
        _isScanning = false;
      });
      _showErrorDialog('Could not load test chair image: $e');
    }
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
        debugPrint("Food Scan Paywall presented: ${name ?? 'Unknown'}");
        MixpanelService.trackEvent('Food Scan Quota Paywall Presented', 
          properties: {'paywall_name': name ?? 'Unknown'}
        );
      });

      handler.onDismiss((paywallInfo, paywallResult) async {
        String? name = await paywallInfo.name;
        debugPrint("Food Scan Paywall dismissed: ${name ?? 'Unknown'}, result: $paywallResult");
        MixpanelService.trackEvent('Food Scan Quota Paywall Dismissed', 
          properties: {
            'paywall_name': name ?? 'Unknown',
            'result': paywallResult.toString()
          }
        );
      });

      handler.onError((error) async {
        debugPrint("Food Scan Paywall error: $error");
        MixpanelService.trackEvent('Food Scan Quota Paywall Error', 
          properties: {'error': error.toString()}
        );
      });

      // Register the paywall placement
      await Superwall.shared.registerPlacement(
        "INSERT_YOUR_STANDARD_PAYWALL_PLACEMENT_ID_HERE",
        handler: handler,
        feature: () async {
          // FEATURE FLAG: Temporarily disable quota system for A/B test
          const bool QUOTA_SYSTEM_ENABLED = false; // Set to true to re-enable quota system
          
          // Reset quotas on successful purchase (DISABLED for A/B test)
          if (QUOTA_SYSTEM_ENABLED) {
            await _quotaService.resetAllQuotas();
            debugPrint("Food Scan: Quotas reset after successful purchase");
          }
        }
      );
    } catch (e) {
      debugPrint('Error showing Food Scan paywall: $e');
    }
  }

  // Show branded error dialog for non-food detection
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
              // Non-food icon
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
                  Icons.no_food,
                  color: Color(0xFFed3272), // Brand pink
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                AppLocalizations.of(context)!.translate('calorieTracker_nonConsumableDetected'),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A), // Dark text
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
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
                      AppLocalizations.of(context)!.translate('foodAlternatives_button_tryAgain'),
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
    if (!mounted) return; // Add guard here
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, // Clean white dialog background
        title: Text(
          AppLocalizations.of(context)!.translate('foodScan_dialogTitle_error'),
          style: const TextStyle(
            color: Color(0xFF1A1A1A), // Dark text for light background
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF666666), // Gray text for secondary content
            fontFamily: 'ElzaRound',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              AppLocalizations.of(context)!.translate('foodScan_dialogButton_ok'),
              style: const TextStyle(
                color: Color(0xFFed3272), // Brand pink for action button
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to show a snackbar when permission is denied
  void _showPermissionDeniedMessage(String permissionName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.translate('foodScan_snackbar_permissionDenied').replaceFirst('{permissionName}', permissionName),
          style: const TextStyle(
            color: Colors.white, // White text on red background is fine
            fontFamily: 'ElzaRound',
          ),
        ),
        backgroundColor: const Color(0xFFfd5d32), // Brand orange for error
      ),
    );
    setState(() {
      _isCameraInitialized = false; // Reflect denial in UI
    });
  }

  @override
  void dispose() {
    _scanAnimationController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8FA), // Light background - brand consistent
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDF8FA), // Light background
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)), // Dark icons for light background
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            AppLocalizations.of(context)!.translate('foodScan_appBarTitle'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A), // Dark text for light background
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
                  color: Color(0xFFE040FB), // Make it more visible with purple color
                  size: 28, // Larger icon
                ),
                tooltip: AppLocalizations.of(context)!.translate('foodScan_tooltip_useTestImage'),
                onPressed: _useTestPizzaImage,
              ),
            ),
          // Debug chair test button
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(
                  Icons.chair,
                  color: Color(0xFFFF5722), // Orange/Red for non-food debug
                  size: 24,
                ),
                tooltip: 'DEBUG: Test Chair Image (Non-Food)',
                onPressed: _useTestChairImage,
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
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // Dark icons for light background
          statusBarBrightness: Brightness.light, // For iOS
        ),
      ),
      body: Stack(
        children: [
          // Conditional UI based on permission, initialization, and scanning state
          if (_isScanning && _imageFile != null)
             _buildScanningOverlay() // Show scanning overlay when image is ready
          else if (_isPermissionGranted && _isCameraInitialized)
            _buildCameraPreview() // Show camera if permission granted and initialized
          else // Otherwise, show loading/error state
            _buildLoadingIndicator(), 
        ],
      ),
      floatingActionButton: _isPermissionGranted && _isCameraInitialized && !_isScanning && !_isTakingPicture
          ? FloatingActionButton(
              heroTag: null,
              onPressed: _takeAndAnalyzePicture,
              backgroundColor: const Color(0xFFed3272), // Brand pink
              child: const Icon(Icons.camera_alt, color: Colors.white),
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
                            top: BorderSide(color: const Color(0xFFed3272), width: 3), // Brand pink
                            left: BorderSide(color: const Color(0xFFed3272), width: 3), // Brand pink
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
                            AppLocalizations.of(context)!.translate('foodScan_guide_centerFood'),
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(context)!.translate('foodScan_guide_takeClearPhoto'),
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                  color: Colors.white.withOpacity(0.9), // Light background with transparency
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFed3272).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${_currentZoomLevel.toStringAsFixed(1)}x',
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A), // Dark text for light background
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
                      color: Colors.white.withOpacity(0.9), // Light background
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFed3272).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Color(0xFF1A1A1A), size: 20), // Dark icon
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
                      color: Colors.white.withOpacity(0.9), // Light background
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFed3272).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.remove, color: Color(0xFF1A1A1A), size: 20), // Dark icon
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
                    color: Colors.white.withOpacity(0.9), // Light background with transparency
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFed3272).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pinch_outlined,
                        color: Color(0xFF666666), // Gray icon for light background
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context)!.translate('foodScan_guide_pinchToZoom'),
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A), // Dark text for light background
                            fontFamily: 'ElzaRound',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom-left gallery import control (always visible when not scanning)
            if (!_isScanning)
              Positioned(
                bottom: 40,
                left: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFed3272).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.photo_library,
                          color: Color(0xFF1A1A1A),
                          size: 26,
                        ),
                        onPressed: _pickImageFromGallery,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!
                          .translate('calorieTracker_addPhoto'),
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 12,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Widget for Scanning Overlay
  Widget _buildScanningOverlay() {
    return Stack(
      children: [
        // Display captured image with corrected display
        Container(
          color: const Color(0xFFFDF8FA), // Light background matching app theme
          child: Center(
            child: Image.file(
              _imageFile!,
              fit: BoxFit.contain,
            ),
          ),
        ),
        
        // Enhanced scan effect with animated particles
        _buildScanParticles(),
        
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
                        top: BorderSide(color: const Color(0xFFed3272), width: 3), // Brand pink
                        left: BorderSide(color: const Color(0xFFed3272), width: 3), // Brand pink
                      ),
                    ),
                  ).animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  ).shimmer(
                    duration: 3.seconds,
                    color: Colors.purpleAccent.withOpacity(0.5),
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
                        top: BorderSide(color: const Color(0xFFed3272), width: 3), // Brand pink
                        right: BorderSide(color: const Color(0xFFed3272), width: 3), // Brand pink
                      ),
                    ),
                  ).animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  ).shimmer(
                    duration: 3.seconds,
                    color: Colors.purpleAccent.withOpacity(0.5),
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
                        bottom: BorderSide(color: const Color(0xFFed3272), width: 3), // Brand pink
                        left: BorderSide(color: const Color(0xFFed3272), width: 3), // Brand pink
                      ),
                    ),
                  ).animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  ).shimmer(
                    duration: 3.seconds,
                    color: Colors.purpleAccent.withOpacity(0.5),
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
                        bottom: BorderSide(color: const Color(0xFFed3272), width: 3), // Brand pink
                        right: BorderSide(color: const Color(0xFFed3272), width: 3), // Brand pink
                      ),
                    ),
                  ).animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  ).shimmer(
                    duration: 3.seconds,
                    color: Colors.purpleAccent.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Animated scanner line
        AnimatedBuilder(
          animation: _scanAnimation,
          builder: (context, child) {
            // Scanner moves up and down
            final double position = _scanAnimation.value <= 0.5 
                ? _scanAnimation.value * 2 // 0 to 1 during first half
                : (1 - (_scanAnimation.value - 0.5) * 2); // 1 to 0 during second half
            
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
                          const Color(0xFFE040FB).withOpacity(0.2),
                        ],
                      ),
                    ),
                  ),
                  // Main scanner line
                  Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE040FB),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE040FB).withOpacity(0.7),
                          blurRadius: 8.0,
                          spreadRadius: 2.0,
                        ),
                      ],
                    ),
                  ).animate(
                    onPlay: (controller) => controller.repeat(reverse: true),
                  ).shimmer(
                    duration: 800.ms,
                    color: Colors.white,
                  ),
                  // Gradient shadow below the line
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFE040FB).withOpacity(0.2),
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
        
        // Scanning text overlay
        Positioned(
          bottom: 80,
          left: 20,
          right: 20,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFed3272), // Brand pink
                      const Color(0xFFfd5d32), // Brand orange
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFed3272).withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFed3272).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  AppLocalizations.of(context)!.translate('foodScan_analyzingOverlayText'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white, // White text on gradient background
                    fontSize: 18,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3.0,
                        color: Color(0xFFed3272), // Brand pink shadow
                      ),
                    ],
                  ),
                ).animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                ).shimmer(
                    duration: 1.8.seconds,
                    color: Colors.white.withOpacity(0.7), // White shimmer on gradient is OK
                    angle: 0,
                    size: 2,
                    curve: Curves.easeInOutCubic,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white, // White background
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFed3272).withOpacity(0.2), // Brand pink border
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFed3272).withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  AppLocalizations.of(context)!.translate('foodAlternatives_loading_eta'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A), // Primary dark text for better contrast on white
                    fontSize: 14,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w500,
                  ),
                ).animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                ).shimmer(
                    duration: 1.8.seconds,
                    color: const Color(0xFFed3272).withOpacity(0.3), // Brand pink shimmer
                    angle: 0,
                    size: 2,
                    curve: Curves.easeInOutCubic,
                ),
              ),
              const SizedBox(height: 16), // Space before Lottie
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

  // (Removed processing overlay for this screen per spec)

  // New method to create scan particle effects
  Widget _buildScanParticles() {
    return Positioned.fill(
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: List.generate(20, (index) {
            final random = index * 50;
            final size = (index % 4) * 2.0 + 2.0;
            final left = (index % 5) * 80.0;
            return Positioned(
              left: left,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ).animate(
              onPlay: (controller) => controller.repeat(),
            ).moveY(
              begin: -20,
              end: MediaQuery.of(context).size.height + 20,
              curve: Curves.easeInOut,
              duration: 3.seconds,
              delay: (random).ms,
            ).fadeIn(
              duration: 500.ms,
            ).fadeOut(
              delay: 2.seconds,
              duration: 500.ms,
            );
          }),
        ),
      ),
    );
  }

  // Widget for Loading Indicator (now handles initial check and init states)
  Widget _buildLoadingIndicator() {
    String message = _isCheckingPermission 
        ? AppLocalizations.of(context)!.translate('foodScan_loading_checkingPermissions') 
        : AppLocalizations.of(context)!.translate('foodScan_loading_initializingCamera');
    if (!_isPermissionGranted && !_isCheckingPermission) {
       message = AppLocalizations.of(context)!.translate('foodScan_loading_permissionDenied');
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isPermissionGranted || _isCheckingPermission) // Show spinner only if checking or granted but initializing
             const CircularProgressIndicator(color: Color(0xFFed3272)), // Brand pink spinner
          if (!_isPermissionGranted && !_isCheckingPermission) // Show error icon if denied
             const Icon(Icons.error_outline, color: Color(0xFFfd5d32), size: 48), // Brand orange error
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0), // Add padding for longer messages
            child: Text(
              message,
              textAlign: TextAlign.center, // Center align text
              style: const TextStyle(
                color: Color(0xFF1A1A1A), // Dark text for light background
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