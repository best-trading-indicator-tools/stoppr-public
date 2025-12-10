import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:stoppr/features/onboarding/presentation/screens/onboarding_card_2.dart';
import 'package:stoppr/features/onboarding/presentation/screens/onboarding_screen2.dart';
import 'package:stoppr/features/onboarding/presentation/screens/onboarding_screen4.dart';
import 'package:stoppr/features/onboarding/presentation/screens/questionnaire_screen.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stoppr/core/auth/cubit/auth_cubit.dart';
import 'package:stoppr/core/auth/cubit/auth_state.dart';
import 'package:stoppr/core/repositories/user_repository.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:stoppr/features/onboarding/presentation/screens/congratulations_payment_screen.dart';
import 'package:stoppr/core/notifications/notification_service.dart';
import 'package:stoppr/features/app/presentation/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/core/streak/streak_service.dart';
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:stoppr/core/auth/models/app_user.dart';
import 'package:stoppr/core/repositories/user_repository.dart';
import 'package:stoppr/features/onboarding/presentation/screens/congratulations/congratulations_screen_1.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stoppr/permissions/permission_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stoppr/core/subscription/subscription_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart'; // Add this import
import 'dart:async';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:stoppr/core/services/onboarding_audio_service.dart';
import 'package:stoppr/core/subscription/post_purchase_handler.dart';


class PrePaywallScreen extends StatefulWidget {
  const PrePaywallScreen({super.key});

  @override
  State<PrePaywallScreen> createState() => _PrePaywallScreenState();
}

class _PrePaywallScreenState extends State<PrePaywallScreen> {
  final ScrollController _scrollController = ScrollController();
  final OnboardingProgressService _progressService = OnboardingProgressService();
  final UserRepository _userRepository = UserRepository();
  final NotificationService _notificationService = NotificationService();
  final PermissionService _permissionService = PermissionService();
  final StreakService _streakService = StreakService();
  // Add SubscriptionService instance
  final SubscriptionService _subscriptionService = SubscriptionService();
  String _firstName = '';
  String _quitDate = '';
  DateTime _targetQuitDateTime = DateTime.now().add(const Duration(days: 90));
  // String _selectedStandardPaywallProductId = 'com.stoppr.app.annual'; // REMOVED - Will determine dynamically after purchase
  bool _isInTestFlight = false; // Add state variable to track TestFlight mode
  
  // Countdown timer for the discount offer (8 minutes = 480 seconds)
  int _remainingDiscountSeconds = 480;
  Timer? _discountTimer;
  bool _isStandardPaywallRegistered = false; // Track if standard paywall is already registered
  bool _isGiftPaywallRegistered = false; // Track if gift paywall is already registered
  
  // Add slideshow state variables
  PageController? _reviewPageController;
  int _currentReviewIndex = 0;
  
  @override
  void initState() {
    super.initState();
    // Initialize page controller
    _reviewPageController = PageController(initialPage: 0);
    
    // _clearPendingPurchases(); // Commented out to prevent Apple sign-in prompt
    _saveCurrentScreen();
    // _calculateQuitDate(); // Call will be made in didChangeDependencies
    _initializeStreakService();
    _checkTestFlightMode(); // Add call to check TestFlight mode
    debugPrint('⭐️ initState calculated date: $_quitDate');
    
    // Track page view event with Mixpanel
    MixpanelService.trackPageView('Onboarding Pre Paywall Screen'); // New format
    
    // Check if user already has an active subscription
    _checkSubscriptionStatus();

    // Add a delay before initializing notifications to ensure UI is ready
    // Removed notification permission request here; handled in OnboardingScreen2

    // Start the 8-minute countdown timer for the discount box
    _startDiscountTimer();
    // Stop onboarding music upon entering pre-paywall
    OnboardingAudioService.instance.stop();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load user data after widget is mounted and context is available
    _loadUserData();
    _calculateQuitDate(context); // Calculate/recalculate quit date when dependencies change
  }
  
  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.prePaywallScreen);
    debugPrint('🔥 PrePaywall: Saved current screen as prePaywallScreen');
  }
  
  Future<void> _loadUserData() async {
    try {
      // First try to get name from SharedPreferences (saved during profile info screen)
      final prefs = await SharedPreferences.getInstance();
      final savedFirstName = prefs.getString('user_first_name');
      
      if (savedFirstName != null && savedFirstName.isNotEmpty) {
        if (mounted) {
          setState(() {
            _firstName = savedFirstName;
          });
        }
        return; // Exit if we found a name
      }
      
      // Fallback to Firebase if name not in SharedPreferences
      if (!mounted) return;
      
      final currentUser = context.read<AuthCubit>().getCurrentUser();
      if (currentUser != null) {
        final userData = await _userRepository.getUserProfile(currentUser.uid);
        if (userData != null && userData['firstName'] != null) {
          if (mounted) {
            setState(() {
              _firstName = userData['firstName'];
            });
          }
        } else if (currentUser.displayName != null) {
          // Try to get name from Firebase Auth displayName if available
          final displayNameParts = currentUser.displayName!.split(' ');
          if (displayNameParts.isNotEmpty) {
            if (mounted) {
              setState(() {
                _firstName = displayNameParts[0]; // Get first name from display name
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }
  
  // Initialize notification service using centralized method
  Future<void> _initializeNotifications() async {
    debugPrint('PrePaywall: Initializing notifications via centralized method...');
    
    try {
      final isGranted = await _notificationService.initializeOnboardingNotifications(
        context: 'pre_paywall',
        // No force re-request here; respect prior user choice
      );
      
      debugPrint('PrePaywall: Notification initialization result: $isGranted');
    } catch (e) {
      debugPrint('PrePaywall: Error during notification initialization: $e');
    }
  }
  
  // Initialize the streak service with the target quit date
  Future<void> _initializeStreakService() async {
    // Initialize streak service first (this is needed for the service to be ready)
    await _streakService.initialize();
    
    final prefs = await SharedPreferences.getInstance();
    // Remove first-run auto-reset: never set start to now from pre-paywall.
    // Only compute and store target date for UI purposes.
    await prefs.setInt('target_quit_timestamp', _targetQuitDateTime.millisecondsSinceEpoch);
  }
  
  void _calculateQuitDate(BuildContext context) {
    // Calculate quit date (current date + 90 days)
    final now = DateTime.now();
    final quitDate = now.add(const Duration(days: 90));
    
    // Save target date for streak calculations
    _targetQuitDateTime = quitDate;
    
    // Get current locale for date formatting
    final currentLocale = Localizations.localeOf(context).languageCode;
    
    // Format date as "Month DD, YYYY" (e.g., "May 14, 2025") using the current locale
    String formattedDate = DateFormat('MMMM d, yyyy', currentLocale).format(quitDate);
    
    // Capitalize the first letter of the month if the locale is Spanish
    formattedDate = _capitalizeSpanishMonth(formattedDate, currentLocale);

    debugPrint('⭐️ Calculated quit date with locale $currentLocale: $formattedDate');
    
    if (mounted && _quitDate != formattedDate) { // Only call setState if the date string actually changes
      setState(() {
        _quitDate = formattedDate;
      });
    }
  }
  
  // Always returns a valid formatted date
  String get formattedQuitDate {
    if (_quitDate.isNotEmpty) {
      return _quitDate; // Already formatted and potentially capitalized
    }
    
    // Calculate on the spot as fallback using the current context's locale
    final currentLocale = Localizations.localeOf(context).languageCode;
    final now = DateTime.now();
    final quitDate = now.add(const Duration(days: 90));
    String dateStr = DateFormat('MMMM d, yyyy', currentLocale).format(quitDate);
    return _capitalizeSpanishMonth(dateStr, currentLocale);
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    _reviewPageController?.dispose();
    // Cancel discount countdown timer if active
    _discountTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _testStoreKitPurchase() async {
    try {
      debugPrint('🛍️ Starting direct purchase test...');
      
      // Check if running in Xcode with StoreKit configuration
      final bool isRunningWithStoreKitConfiguration = Platform.isIOS && 
          await _checkStoreKitConfigurationActive();
      
      debugPrint('🛍️ Running with StoreKit Configuration: $isRunningWithStoreKitConfiguration');
      
      // First, let's verify StoreKit is available
      final bool available = await InAppPurchase.instance.isAvailable();
      debugPrint('🛍️ StoreKit Available: $available');
      
      if (!available) {
        debugPrint('🛍️ Store not available');
        return;
      }
      
      // Query iOS product details
      const Set<String> productIds = {
        'com.stoppr.app.monthly',
        'com.stoppr.app.annual',
        'com.stoppr.app.annual.trial',
        'com.stoppr.app.annual80OFF',
        'com.stoppr.app.trial.paid', // Trial paid access for iOS
      };
      
      debugPrint('🛍️ Querying products...');
      final ProductDetailsResponse response = 
          await InAppPurchase.instance.queryProductDetails(productIds);
      
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('🛍️ Products not found: ${response.notFoundIDs}');
      }
      
      if (response.productDetails.isEmpty) {
        debugPrint('🛍️ No products found');
        return;
      }
      
      // Display found products
      for (final product in response.productDetails) {
        debugPrint('🛍️ Found product: ${product.id} - ${product.title}');
      }
      
      // Select the monthly product for testing - Fixed approach
      ProductDetails? productToPurchase;
      
      // First try to find the specific product we want
      for (final product in response.productDetails) {
        if (product.id == 'com.stoppr.app.monthly') {
          productToPurchase = product;
          break;
        }
      }
      
      // Fallback to first product if specific one not found
      if (productToPurchase == null && response.productDetails.isNotEmpty) {
        productToPurchase = response.productDetails.first;
      }
      
      // Exit if no product found
      if (productToPurchase == null) {
        debugPrint('🛍️ No suitable product found for purchase');
        return;
      }
      
      // Clear any pending transactions first ONLY if not in StoreKit test configuration
      // This is likely what's causing your Apple ID authentication prompt
      if (Platform.isIOS && !isRunningWithStoreKitConfiguration) {
        debugPrint('🛍️ Clearing any pending transactions using direct StoreKit approach...');
        try {
          final transactions = await SKPaymentQueueWrapper().transactions();
          debugPrint('🛍️ Found ${transactions.length} pending transactions');
          
          for (var transaction in transactions) {
            try {
              debugPrint('🛍️ Finishing transaction: ${transaction.transactionIdentifier}');
              await SKPaymentQueueWrapper().finishTransaction(transaction);
              debugPrint('🛍️ Successfully finished transaction');
            } catch (e) {
              debugPrint('🛍️ Error finishing transaction: $e');
            }
          }
        } catch (e) {
          debugPrint('🛍️ Error accessing StoreKit transactions: $e');
        }
      }
      
      // Set up a listener to handle this specific purchase
      final purchaseListener = InAppPurchase.instance.purchaseStream.listen(
        (purchaseDetailsList) async {
          for (var purchaseDetails in purchaseDetailsList) {
            if (purchaseDetails.productID == productToPurchase?.id) {
              debugPrint('🛍️ Purchase status update for ${purchaseDetails.productID}: ${purchaseDetails.status}');
              
              if (purchaseDetails.status == PurchaseStatus.purchased) {
                debugPrint('🛍️ Purchase successful!');
                // Complete the purchase to avoid future issues
                try {
                  await InAppPurchase.instance.completePurchase(purchaseDetails);
                  debugPrint('🛍️ Successfully completed purchase');
                } catch (e) {
                  debugPrint('🛍️ Error completing purchase: $e');
                }
              } else if (purchaseDetails.status == PurchaseStatus.error) {
                debugPrint('🛍️ Purchase error: ${purchaseDetails.error}');
              } else if (purchaseDetails.status == PurchaseStatus.canceled) {
                debugPrint('🛍️ Purchase canceled by user');
              }
            }
          }
        },
        onError: (error) {
          debugPrint('🛍️ Purchase stream error: $error');
        }
      );
      
      // Start purchase
      debugPrint('🛍️ Initiating purchase for ${productToPurchase.id}...');
      final purchaseParam = PurchaseParam(productDetails: productToPurchase);
      
      // Initialize the purchase
      final bool purchaseStarted = await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
      
      if (purchaseStarted) {
        debugPrint('🛍️ Purchase request sent successfully.');
      } else {
        debugPrint('🛍️ Failed to send purchase request.');
      }
      
      // Clean up the listener after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        purchaseListener.cancel();
        debugPrint('🛍️ Purchase listener canceled after timeout.');
      });
      
    } catch (e) {
      debugPrint('🛍️ Error: $e');
    }
  }
  
  // New helper method to check if StoreKit Configuration is active
  Future<bool> _checkStoreKitConfigurationActive() async {
    try {
      // Try to read a test-only property - this will fail if not in test mode
      const MethodChannel channel = MethodChannel('plugins.flutter.io/in_app_purchase_storekit');
      final bool result = await channel.invokeMethod('isStoreKitConfigurationActive') ?? false;
      return result;
    } catch (e) {
      // If we get an error, we're probably not running with StoreKit Configuration
      return false;
    }
  }
  
  Future<void> _clearPendingPurchases() async {
    debugPrint('🧹 Clearing pending purchases...');
    
    // Method 1: Direct StoreKit approach for iOS (more reliable)
    if (Platform.isIOS) {
      try {
        debugPrint('🧹 Using direct StoreKit approach to clear transactions...');
        final transactions = await SKPaymentQueueWrapper().transactions();
        debugPrint('🧹 Found ${transactions.length} pending StoreKit transactions');
        
        for (var transaction in transactions) {
          try {
            debugPrint('🧹 Finishing transaction: ${transaction.transactionIdentifier}');
            await SKPaymentQueueWrapper().finishTransaction(transaction);
            debugPrint('🧹 Successfully finished transaction');
          } catch (e) {
            debugPrint('🧹 Error finishing transaction: $e');
          }
        }
      } catch (e) {
        debugPrint('🧹 Error accessing StoreKit transactions: $e');
      }
    }
    
    // Method 2: Generic in_app_purchase approach (backup method)
    try {
      debugPrint('🧹 Using in_app_purchase to clear pending purchases...');
      // Listen to purchase updates and complete them
      InAppPurchase.instance.purchaseStream.listen((purchaseDetailsList) async {
        debugPrint('🧹 Found ${purchaseDetailsList.length} pending purchases in stream');
        for (var purchaseDetails in purchaseDetailsList) {
          debugPrint('🧹 Purchase: ${purchaseDetails.productID}, Pending? ${purchaseDetails.pendingCompletePurchase}');
          if (purchaseDetails.pendingCompletePurchase) {
            // Complete the purchase
            debugPrint('🧹 Completing pending purchase: ${purchaseDetails.productID}');
            try {
              await InAppPurchase.instance.completePurchase(purchaseDetails);
              debugPrint('🧹 Successfully completed purchase');
            } catch (e) {
              debugPrint('🧹 Error completing purchase: $e');
            }
          }
        }
      });
      
      // Restore purchases - will trigger InAppPurchase.instance.purchaseStream.listen
      debugPrint('🧹 Restoring purchases to find pending transactions...');
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      debugPrint('🧹 Error in generic in_app_purchase approach: $e');
    }
    
    // Method 3: For iOS, also try to refresh the receipt verification data
    if (Platform.isIOS) {
      try {
        final InAppPurchaseStoreKitPlatformAddition storeKitAddition =
            InAppPurchase.instance.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
        
        debugPrint('🧹 Refreshing StoreKit purchase verification data...');
        await storeKitAddition.refreshPurchaseVerificationData();
        debugPrint('🧹 Successfully refreshed verification data');
      } catch (e) {
        debugPrint('🧹 Error refreshing verification data: $e');
      }
    }
    
    debugPrint('🧹 Finished clearing pending purchases.');
  }
  
  // New method to check if user is already subscribed and skip paywall if so
  Future<void> _checkSubscriptionStatus() async {
    // In debug builds, keep the PrePaywall screen visible for testing
    if (kDebugMode) {
      debugPrint('🟡 PrePaywallScreen (debug): Skipping subscription auto-navigation.');
      return;
    }
    // In TestFlight, also keep the PrePaywall screen visible for testing
    try {
      final bool inTestFlight = await _isRunningInTestFlight();
      if (inTestFlight) {
        debugPrint('🟡 PrePaywallScreen (TestFlight): Skipping subscription auto-navigation.');
        return;
      }
    } catch (_) {}
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('🔴 PrePaywallScreen: Cannot check subscription status, no user logged in.');
      return;
    }
    
    try {
      // Use getSubscriptionInfo() for a more comprehensive check including Firestore status
      final subscriptionInfo = await _subscriptionService.getSubscriptionInfo(currentUser.uid);
      debugPrint('🔶 PrePaywallScreen: Checking subscription status via SubscriptionService.getSubscriptionInfo: \${subscriptionInfo.isPaid}');
      
      // If user has active subscription (isPaid is true), skip directly to home screen
      if (subscriptionInfo.isPaid) {
        debugPrint('🟢 PrePaywallScreen: User has active access (isPaid: true), navigating to HomeScreen');
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const MainScaffold(
                initialIndex: 0,
                showCheckInOnLoad: true,
              ),
            ),
            (route) => false,
          );
        }
      } else {
        debugPrint('🔴 PrePaywallScreen: User does not have active subscription, showing paywall');
      }
    } catch (e) {
      debugPrint('🔴 PrePaywallScreen: Error checking subscription status: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!; // Added l10n definition
    
    final screenSize = MediaQuery.of(context).size;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for white background
        statusBarBrightness: Brightness.light, // For iOS
      ),
      child: Container(
        color: Colors.white, // Pure white background
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 50,
            automaticallyImplyLeading: false,
            title: const Text(''),
          actions: [
            if (kDebugMode || _isInTestFlight) // Show in both debug mode and TestFlight
              IconButton(
                icon: const Icon(Icons.settings, size: 28),
                onPressed: () {
                  _updateFirebaseSubscriptionData(); // Add this call
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const CongratulationsScreen1(),
                    ),
                    (route) => false,
                  );
                },
              ),
            // Add test button for congratulations screens
            if (kDebugMode || _isInTestFlight) // Show in both debug mode and TestFlight
              IconButton(
                icon: const Icon(Icons.celebration, size: 28),
                onPressed: () {
                  _updateFirebaseSubscriptionData(); // Add this call
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CongratulationsScreen1(),
                    ),
                  );
                },
              ),
          ],
        ),
        body: Column(
          children: [
            // Main scrollable content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      
                      // Custom plan section - NEW SECTION
                      _buildCustomPlanSection(),
                      
                      const SizedBox(height: 16),
                    
                      // Special offer section (duplicated above the first Lottie)
                      Center(
                        child: _buildDiscountContainer(sectionTag: 'first'),
                      ),
                      const SizedBox(height: 30),
                      
                      
                      // Top Lottie animation
                      SizedBox(
                        height: 280,
                        child: Center(
                          child: SizedBox(
                            width: screenSize.width * 0.85,
                            child: Lottie.asset(
                              'assets/images/lotties/PinkWomanYoga.json',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      
                      // Main Title 1
                      _buildSectionTitle(l10n.translate('prePaywall_conquerYourself_title')),
                      
                      // Pride Container with 5 stars and testimonial
                      _buildSectionContainerWithTestimonial([
                        _buildFeatureItem(
                          icon: 'lock_circle_fill.svg',
                          textKey: 'prePaywall_feature_buildSelfControl',
                          iconColor: const Color(0xFFFF3B30),
                        ),
                        _buildFeatureItem(
                          icon: 'attractiveness_icon.svg',
                          textKey: 'prePaywall_feature_becomeAttractiveConfident',
                          iconColor: const Color(0xFFAF52DE),
                        ),
                        _buildFeatureItem(
                          icon: 'self_worth_icon.svg',
                          textKey: 'prePaywall_feature_boostSelfWorth',
                          iconColor: const Color(0xFF28CD41),
                        ),
                        _buildFeatureItem(
                          icon: 'pride_icon.svg',
                          textKey: 'prePaywall_feature_fillDayWithPride',
                          iconColor: const Color(0xFFFFCC00),
                        ),
                      ], 
                      testimonialTextKey: 'prePaywall_testimonial1_text',
                      testimonialAuthorKey: 'prePaywall_testimonial1_author',
                      ),
                      const SizedBox(height: 15),
                      
                      // WinnerTrophy Lottie animation
                      SizedBox(
                        height: 280,
                        child: Center(
                          child: SizedBox(
                            width: screenSize.width * 0.85,
                            child: Lottie.asset(
                              'assets/images/lotties/WinnerTrophy.json',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      
                      // Main Title 2
                      _buildSectionTitle(l10n.translate('prePaywall_buildBetterRelationships_title')),

                      const SizedBox(height: 25),
                      
                      // Deserve Container
                      _buildSectionContainer([
                        _buildFeatureItem(
                          icon: 'emotional_intelligence_icon.svg',
                          textKey: 'prePaywall_feature_enhanceEmotionalIntelligence',
                          iconColor: const Color(0xFF007AFF),
                        ),
                        _buildFeatureItem(
                          icon: 'socially_present_active_icon.svg',
                          textKey: 'prePaywall_feature_beSociallyPresent',
                          iconColor: const Color(0xFFAF52DE),
                        ),
                        _buildFeatureItem(
                          icon: 'real_energy_reactiveness.svg',
                          textKey: 'prePaywall_feature_experienceRealEnergy',
                          iconColor: const Color(0xFFFF3B30),
                        ),
                        _buildFeatureItem(
                          icon: 'deserve_icon.svg',
                          textKey: 'prePaywall_feature_becomePersonTheyDeserve',
                          iconColor: const Color(0xFF28CD41),
                        ),
                      ]),
                      const SizedBox(height: 25),
                      
                      // Testimonial 2
                      _buildTestimonial(
                        textKey: 'prePaywall_testimonial2_text',
                        authorKey: 'prePaywall_testimonial2_author',
                      ),
                      const SizedBox(height: 25),
                      _buildSectionTitle(l10n.translate('prePaywall_restoreEnergy_title')), // Moved this title up
                      const SizedBox(height: 20),
                      _buildSectionContainer([
                        _buildCustomFeatureItem(
                          icon: 'rewire_brain.svg',
                          boldPrefixKey: 'prePaywall_feature_rewireBrain_bold', // Assuming a new key for bold part
                          normalTextKey: 'prePaywall_feature_rewireBrain_normal', // Assuming a new key for normal part
                          iconColor: const Color(0xFF28CD41),
                        ),
                        _buildCustomFeatureItem(
                          icon: 'reverse_sugar.svg',
                          boldPrefixKey: 'prePaywall_feature_reverseDesensitization_bold',
                          normalTextKey: 'prePaywall_feature_reverseDesensitization_normal',
                          iconColor: const Color(0xFFAF52DE),
                        ),
                        _buildFeatureItem(
                          icon: 'enjoy_healthy_experiences.svg',
                          textKey: 'prePaywall_feature_enjoyHealthyExperiences',
                          iconColor: const Color(0xFFFF2D55),
                        ),
                      ]),
                      const SizedBox(height: 25),
                      _buildTestimonial(
                        textKey: 'prePaywall_testimonial3_text',
                        authorKey: 'prePaywall_testimonial3_author',
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        height: 280,
                        child: Center(
                          child: SizedBox(
                            width: screenSize.width * 0.85,
                            child: Lottie.asset(
                              'assets/images/lotties/SuperPopcorn.json',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildSectionTitle(l10n.translate('prePaywall_takeControl_title')),
                      const SizedBox(height: 20),
                      _buildSectionContainer([
                        _buildFeatureItem(
                          icon: 'redirect_harmful_cravings.svg',
                          textKey: 'prePaywall_feature_redirectCravings', // Corrected key
                          iconColor: const Color(0xFF28CD41),
                        ),
                        _buildFeatureItem(
                          icon: 'regain_focus_motivation.svg',
                          textKey: 'prePaywall_feature_regainFocus',
                          iconColor: const Color(0xFFFF3B30),
                        ),
                        _buildFeatureItem(
                          icon: 'find_joy.svg',
                          textKey: 'prePaywall_feature_findJoy', // Corrected key
                          iconColor: const Color(0xFF007AFF),
                        ),
                      ]),
                      const SizedBox(height: 20),

                      // Testimonial 4
                      _buildTestimonial(
                        textKey: 'prePaywall_testimonial4_text',
                        authorKey: 'prePaywall_testimonial4_author',
                        showSeparator: false,
                      ),
                      const SizedBox(height:15),
                      
                      // Review Slideshow
                      _buildReviewSlideshow(),
                      const SizedBox(height: 35),
                                      
                      // Discount Container
                      Center(
                        child: _buildDiscountContainer(sectionTag: 'second'),
                      ),
                      // Add padding to ensure the fixed bottom section doesn't hide content
                      const SizedBox(height: 70),
                    ],
                  ),
                ),
              ),
            ),
            
            // Sticky bottom section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              decoration: BoxDecoration(
                color: Colors.white, // Clean white background
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16), // Add top margin to button
                    // Become a STOPPR Button
                    _buildBecomeStopprButton(),
                    // Privacy and Terms Links
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _launchURL('https://www.stoppr.app/privacy-policy'),
                            child: const Text(
                              'Privacy Policy',
                              style: TextStyle(
                                fontFamily: 'ElzaRound',
                                fontSize: 14,
                                color: Color(0xFF666666), // Gray links for white background
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          GestureDetector(
                            onTap: () => _launchURL('https://www.stoppr.app/terms-conditions'),
                            child: const Text(
                              'Terms of Use',
                              style: TextStyle(
                                fontFamily: 'ElzaRound',
                                fontSize: 14,
                                color: Color(0xFF666666), // Gray links for white background
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
          ],
        ),
      ),
      ),
    );
  }
  
  // Build a section container with list of feature items
  Widget _buildSectionContainer(List<Widget> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      ),
    );
  }
  
  // New method to build section container with testimonial
  Widget _buildSectionContainerWithTestimonial(List<Widget> items, {required String testimonialTextKey, required String testimonialAuthorKey}) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ...items,
          const SizedBox(height: 40),
          // 5 stars SVG - Conditionally rendered
          SvgPicture.asset(
            'assets/images/svg/5 stars prewall.svg',
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 30),
          // Testimonial text in italic
          Text(
            l10n.translate(testimonialTextKey),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w400,
              fontSize: 17,
              color: Color(0xFF333333), // Dark gray for testimonials on white background
              height: 1.29,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate(testimonialAuthorKey),
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w400,
              fontSize: 12,
              color: Color(0xFF666666), // Gray for author on white background
            ),
          ),
          const SizedBox(height: 15),
          // Horizontal line separator
          Container(
            width: 200,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0), // Light gray line for white background
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
  
  // Build a feature item with icon and text
  Widget _buildFeatureItem({
    required String icon,
    required String textKey, 
    required Color iconColor,
  }) {
    final l10n = AppLocalizations.of(context)!;
    String translatedText = l10n.translate(textKey);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: SvgPicture.asset(
              'assets/images/svg/$icon',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    color: Color(0xFF1A1A1A), // Dark text for white background
                  ),
                  children: _buildStyledText(translatedText), // Pass translated text
                ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Custom feature item with specifically controlled bold styling
  Widget _buildCustomFeatureItem({
    required String icon,
    required String boldPrefixKey, // Changed to key
    required String normalTextKey, // Changed to key
    required Color iconColor,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: SvgPicture.asset(
              'assets/images/svg/$icon',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  color: Color(0xFF1A1A1A), // Dark text for white background
                ),
                children: [
                  TextSpan(
                    text: l10n.translate(boldPrefixKey),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: l10n.translate(normalTextKey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to build styled text with bold words
  List<TextSpan> _buildStyledText(String text) {
    // Sanitize input text to prevent UTF-16 crashes
    final safeText = TextSanitizer.sanitizeForDisplay(text);
    
    final Map<String, bool> boldWords = {
      'unbreakable': true,
      'self': true,
      'more attractive': true,
      'confident': true,
      'self-worth': true,
      'pride': true,
      'happiness': true,
      'emotional intelligence': true,
      'socially present': true,
      'active': true,
      'real energy': true,
      'reactiveness': true,
      'deserve': true,
      'real food': true,
      'sugar-induced': true,
      'healthy': true,
      'satisfying': true,
      'harmful': true,
      'focus': true,
      'motivation': true,
      'real joy': true,
      'satisfaction': true,
    };

    try {
      final words = safeText.split(' ');
      final List<TextSpan> spans = [];
      
      int i = 0;
      while (i < words.length) {
        String currentWord = words[i];
        String twoWords = i + 1 < words.length ? '$currentWord ${words[i + 1]}' : currentWord;
        String threeWords = i + 2 < words.length ? '$twoWords ${words[i + 2]}' : twoWords;
        
        if (boldWords.containsKey(threeWords)) {
          spans.add(TextSpan(
            text: '$threeWords ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ));
          i += 3;
        } else if (boldWords.containsKey(twoWords)) {
          spans.add(TextSpan(
            text: '$twoWords ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ));
          i += 2;
        } else if (boldWords.containsKey(currentWord)) {
          spans.add(TextSpan(
            text: '$currentWord ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ));
          i++;
        } else {
          spans.add(TextSpan(text: '$currentWord '));
          i++;
        }
      }
      
      return spans;
    } catch (e) {
      debugPrint('Error building styled text: $e');
      // Fallback to simple text if string manipulation fails
      return [TextSpan(text: safeText)];
    }
  }
  
  // Build a testimonial box
  Widget _buildTestimonial({
    required String textKey, // Changed
    required String authorKey, // Changed
    bool showSeparator = true,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
      child: Column(
        children: [
          // Stars moved to the top of the testimonial - Conditionally rendered
          _buildRatingContainer(),
          const SizedBox(height: 30),
          Text(
            l10n.translate(textKey), // Use key
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w400,
              fontSize: 16,
              color: Color(0xFF333333), // Dark gray for testimonials on white background
              height: 1.29,
              fontStyle: FontStyle.italic, // Added italic style
            ),
          ),
          const SizedBox(height: 15),
          Text(
            l10n.translate(authorKey), // Use key
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w400,
              fontSize: 12,
              color: Color(0xFF666666), // Gray for author on white background
            ),
          ),
          const SizedBox(height: 20),
          if (showSeparator)
            Container(
              width: 200,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0), // Light gray line for white background
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
  
  // Build rating stars container
  Widget _buildRatingContainer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF), // 8% opacity white
        borderRadius: BorderRadius.circular(120),
        border: Border.all(
          color: const Color(0x1EFFFFFF), // 12% opacity white
          width: 1,
        ),
      ),
      child: const Text(
        '★★★★★', // This is the text that should be hidden on Android
        style: TextStyle(
          fontFamily: 'SF Pro Rounded',
          fontWeight: FontWeight.w800,
          fontSize: 26,
          letterSpacing: 4,
          color: Color(0xFFFFB515), // Yellow color
        ),
      ),
    );
  }
  
  // Build progress container
  Widget _buildProgressContainer() {
    final l10n = AppLocalizations.of(context)!; // Ensure l10n is available
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF), // 6% opacity white
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Raising hand icon centered using the same method as other SVGs
          Center(
            child: Image.asset(
              'assets/images/onboarding/raising_hand.png',
              width: 60,
              height: 60,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 15),
          
          Text(
            l10n.translate('prePaywall_progressContainer_title1'),
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
              fontSize: 19,
              letterSpacing: 0.19,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          
          Text(
            l10n.translate('prePaywall_progressContainer_description'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w400,
              fontSize: 16,
              letterSpacing: 0.16,
              height: 1.42,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          
          Text(
            l10n.translate('prePaywall_progressContainer_quitByPrompt'),
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w500,
              fontSize: 14,
              letterSpacing: 0.13,
              color: Color(0x66FFFFFF), // 40% opacity white
            ),
          ),
          const SizedBox(height: 20),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF), // 8% opacity white
              borderRadius: BorderRadius.circular(120),
              border: Border.all(
                color: const Color(0x1EFFFFFF), // 12% opacity white
                width: 1,
              ),
            ),
            child: Text(
              formattedQuitDate,
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w500,
                fontSize: 16,
                letterSpacing: 0.16,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 45),
          
          // Left-aligned "Simple, daily habits:" text
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.translate('prePaywall_progressContainer_title2'),
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
                fontSize: 17,
                letterSpacing: 0.32,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 15),

          // Use feature items with icons
          _buildFeatureItemWithPNG(
            icon: 'panic_button.png',
            textKey: 'prePaywall_feature_panicButton',
            iconColor: const Color(0xFFFF3B30), // Red
          ),
          
          _buildFeatureItemWithPNG(
            icon: 'pledge_daily.png',
            textKey: 'prePaywall_feature_pledgeDaily',
            iconColor: const Color(0xFFFFCC00), // Yellow/Gold
          ),
          
          _buildFeatureItemWithPNG(
            icon: 'track_progress.png',
            textKey: 'prePaywall_feature_trackProgress',
            iconColor: const Color(0xFF007AFF), // Blue
          ),
        ],
      ),
    );
  }
  
  // Helper to get month name from month number
  String _getMonth(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
  
  // Build discount container
  Widget _buildDiscountContainer({required String sectionTag}) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: 320,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8), // More visible gray background
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "Special offer expires in:" text
          const Text(
            'Special offer expires in:',
            style: TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w500,
              fontSize: 18,
              color: Color(0xFF1A1A1A), // Darker text for better contrast
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          
          // Countdown timer boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimeBox((_remainingDiscountSeconds ~/ 60).toString().padLeft(2, '0')),
              const SizedBox(width: 8),
              _buildTimeBox((_remainingDiscountSeconds % 60).toString().padLeft(2, '0')),
            ],
          ),
          
          const SizedBox(height: 15),
          
          // Claim Limited Discount button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFed3272), // Brand pink
                  Color(0xFFfd5d32), // Brand orange
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFed3272).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () async {
                              // Add Mixpanel tracking for the "Claim Limited Discount" button tap
              MixpanelService.trackButtonTap(
                'See One-Time Offer',
                screenName: 'PrePaywallScreen',
                additionalProps: {
                  'button_type': 'discount',
                  'discount_type': '80_percent_off',
                  'discount_section': sectionTag,
                }
              );
              debugPrint('🔘 Claim Limited Discount button tapped - tracked in Mixpanel');
              
              // Track Facebook and Firebase Analytics checkout events
              await _trackCheckoutEvent(
                productType: 'annual80off',
                price: 19.99,
                itemName: 'Annual 80% OFF Subscription',
                itemVariant: 'annual80off',
                buttonType: 'discount button - ' + sectionTag,
              );
                
                // Check if placement is already registered to avoid stacking handlers
                if (_isGiftPaywallRegistered) {
                  debugPrint('Gift paywall placement already registered, skipping registration');
                  return;
                }

                // Mark as registered immediately to prevent race conditions
                _isGiftPaywallRegistered = true;

                // Trigger the first Superwall campaign
                try {
                  // MIXPANEL_COST_CUT: Removed gift campaign trigger - Superwall has its own analytics
                  
                  debugPrint('Attempting to trigger Superwall campaign...');
                  
                  // Create a handler for paywall presentation (for gift_step_1)
                  PaywallPresentationHandler handler = PaywallPresentationHandler();
                  
                  handler.onPresent((paywallInfo) async {
                    String? name = await paywallInfo.name;
                    print("Handler (onPresent): ${name ?? 'Unknown'}");
                    // MIXPANEL_COST_CUT: Removed gift paywall presentation tracking - Superwall analytics
                  });

                  handler.onDismiss((paywallInfo, paywallResult) async {
                    String? name = await paywallInfo.name;
                    print("Handler (onDismiss): ${name ?? 'Unknown'}");
                    
                    // Reset the registration flag to allow the button to work again
                    _isGiftPaywallRegistered = false;
                    
                    // Log detailed paywall result to help with debugging in TestFlight
                    String resultString = paywallResult?.toString() ?? 'null';
                    debugPrint('🔍 Gift Paywall dismissed - detailed result: $resultString');
                    
                    // MIXPANEL_COST_CUT: Removed gift paywall dismiss tracking - Superwall analytics
                    
                    // Check if this is a successful purchase result from either paywall
                    if (resultString.contains('PurchasedPaywallResult')) {
                      debugPrint('✅ Purchase detected in gift_step_1 handler! Navigating to congratulations screen');
                      
                      // MIXPANEL_COST_CUT: Removed gift purchase success tracking - Superwall analytics
                      
                      // Navigate to congratulations screen
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const CongratulationsScreen1(),
                          ),
                          (route) => false,
                        );
                      }
                    } else if (resultString.contains('DeclinedPaywallResult')) {
                      debugPrint('🔍 Gift Paywall dismissed by X button');
                    } else {
                      debugPrint('ℹ️ Gift Paywall dismissed - result: $paywallResult (not showing email dialog)');
                    }
                  });

                  handler.onError((error) {
                    // Reset flag before handling error
                    _isGiftPaywallRegistered = false;
                    _handleSuperwallError(error);
                  });

                  handler.onSkip((skipReason) async {
                    // Reset the registration flag when paywall is skipped
                    _isGiftPaywallRegistered = false;
                    String reasonString = skipReason.toString();

                    if (skipReason is PaywallSkippedReasonHoldout) {
                      print("Handler (onSkip): Holdout - $reasonString");
                      print("Holdout details included in reason: $reasonString");
                    } else if (skipReason is PaywallSkippedReasonNoAudienceMatch) {
                      print("Handler (onSkip): No Audience Match - $reasonString");
                    } else if (skipReason is PaywallSkippedReasonPlacementNotFound) {
                      print("Handler (onSkip): Placement Not Found - $reasonString");
                    } else {
                      print("Handler (onSkip): Unknown skip reason - $reasonString");
                    }
                  });

                  // Log subscription status (guarded by readiness)
                  if (NotificationService.isSuperwallReady) {
                    await Superwall.shared.getSubscriptionStatus().then((status) {
                      debugPrint('Current subscription status: $status');
                    });
                  } else {
                    debugPrint('Superwall not ready; skipping subscription status log');
                  }
                  
                  // Use the correct method to register a placement with feature callback and handler
                  await Superwall.shared.registerPlacement(
                    "INSERT_YOUR_GIFT_STEP_1_PLACEMENT_ID_HERE", 
                    handler: handler,
                    feature: () async {
                      final giftProductId = Platform.isIOS
                        ? 'com.stoppr.app.annual80OFF'
                        : 'com.stoppr.sugar.app.annual80off:annual80off';
                      
                      await PostPurchaseHandler.handlePostPurchase(
                        context,
                        defaultProductId: giftProductId,
                      );
                    }
                  );
                  
                  debugPrint('Registered Superwall placement: INSERT_YOUR_GIFT_STEP_1_PLACEMENT_ID_HERE');

                } catch (e) {
                  debugPrint('Error registering/triggering Superwall gift campaign: $e');
                  // Reset flag if registration/triggering fails
                  _isGiftPaywallRegistered = false;
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.card_giftcard,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.translate('prePaywall_seeOneTimeOffer'),
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build time boxes
  Widget _buildTimeBox(String time) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFFDF8FA), // Slight pink background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Center(
        child: Text(
          time,
          style: const TextStyle(
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w700,
            fontSize: 28,
            color: Color(0xFFed3272), // Brand pink for time numbers
          ),
        ),
      ),
    );
  }

  // Add this new method for section titles
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'ElzaRound',
          fontWeight: FontWeight.w600,
          fontSize: 22,
          color: Color(0xFF1A1A1A), // Dark text for white background
          height: 1.3,
        ),
      ),
    );
  }

  // Build the Become a STOPPR button with text
  Widget _buildBecomeStopprButton() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFed3272), // Brand pink
                Color(0xFFfd5d32), // Brand orange
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFed3272).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () async {
              // Add Mixpanel tracking for the "Become a STOPPR" button tap
              MixpanelService.trackButtonTap(
                'Become a STOPPR',
                screenName: 'PrePaywallScreen',
                additionalProps: {'button_type': 'primary_cta', 'location': 'bottom_bar'}
              );
              debugPrint('🔘 Become a STOPPR button tapped - tracked in Mixpanel');
              
              // Track Facebook and Firebase Analytics checkout events
              await _trackCheckoutEvent(
                productType: 'annual',
                price: 49.99,
                itemName: 'Annual Subscription',
                itemVariant: 'annual',
                buttonType: 'main CTA button',
              );
              
              // Check if placement is already registered to avoid stacking handlers
              if (_isStandardPaywallRegistered) {
                debugPrint('Standard paywall placement already registered, skipping registration');
                return;
              }

              // Mark as registered immediately to prevent race conditions
              _isStandardPaywallRegistered = true;

              // Trigger the standard paywall campaign directly
              try {
                // MIXPANEL_COST_CUT: Removed standard paywall trigger - Superwall analytics
                
                debugPrint('Attempting to trigger standard_paywall Superwall campaign...');
                
                // Reset Superwall's state completely
                // await Superwall.shared.reset();
                
                // Set subscription status explicitly to inactive
                // await Superwall.shared.setSubscriptionStatus(SubscriptionStatusInactive());
                
                // Create a handler for paywall presentation
                PaywallPresentationHandler handler = PaywallPresentationHandler();
                
                handler.onPresent((paywallInfo) async {
                  // String name = await paywallInfo.name; // Old way
                  String? name = await paywallInfo.name; // New way
                  print("Handler (onPresent): ${name ?? 'Unknown'}");
                  // MIXPANEL_COST_CUT: Removed standard paywall presentation - Superwall analytics
                });

                handler.onDismiss((paywallInfo, paywallResult) async {
                  // String name = await paywallInfo.name; // Old way
                  String? name = await paywallInfo.name; // New way
                  print("Handler (onDismiss): ${name ?? 'Unknown'}");
                  
                  // Reset the registration flag to allow the button to work again
                  _isStandardPaywallRegistered = false;
                  
                  // MIXPANEL_COST_CUT: Removed standard paywall dismiss tracking - Superwall analytics
                  
                  // Capture the selected product ID if this is a successful purchase
                  if (paywallResult.toString().contains('PurchasedPaywallResult')) {
                    // Try to extract the product ID from the result
                    try {
                      // The exact method to extract this depends on what paywallResult gives you
                      // This is a simplified approach - you may need to adjust based on the actual object structure
                      String resultString = paywallResult.toString();
                      debugPrint('🔍 Standard Paywall purchase result detected in onDismiss: $resultString'); // Log the raw result
                      
                      // MOVED TO FEATURE CALLBACK: Update Firebase with the extracted product ID
                      // debugPrint('✅ Purchase successful via Superwall dismissal! Updating Firebase...');
                      // _updateFirebaseSubscriptionWithProductId(purchasedProductId);

                      // MOVED TO FEATURE CALLBACK: Navigate to congratulations screen
                      // debugPrint('✅ Navigating to congratulations screen after purchase...');
                      // if (mounted) {
                      //   Navigator.of(context).pushAndRemoveUntil(
                      //     MaterialPageRoute(
                      //       builder: (context) => const CongratulationsScreen1(),
                      //     ),
                      //     (route) => false,
                      //   );
                      // }

                    } catch (e) {
                      debugPrint('❌ Error processing purchase result in onDismiss: $e');
                      // Optionally show an error message to the user
                    }
                  }
                  
                  // Check if dismissed by X button (user cancelled)
                  // The paywallResult will be DeclinedPaywallResult when user clicks X
                  if (paywallResult.toString().contains('DeclinedPaywallResult')) {
                    debugPrint('🔍 Standard Paywall dismissed by X button - triggering x_tap paywall');
                    
                    // --- Start: Trigger x_tap placement ---
                    try {
                      // MIXPANEL_COST_CUT: Removed X tap paywall trigger - Superwall analytics
                      
                      debugPrint('Attempting to trigger x_tap Superwall campaign...');
                      
                      // Create a handler for the x_tap paywall presentation
                      PaywallPresentationHandler xTapHandler = PaywallPresentationHandler();
                      
                      xTapHandler.onPresent((xTapPaywallInfo) async {
                        // String xTapName = await xTapPaywallInfo.name; // Old way
                        String? xTapName = await xTapPaywallInfo.name; // New way
                        print("Handler (onPresent - x_tap): ${xTapName ?? 'Unknown'}");
                        // MIXPANEL_COST_CUT: Removed X tap paywall present - Superwall analytics
                      });

                      xTapHandler.onDismiss((xTapPaywallInfo, xTapPaywallResult) async {
                        // String xTapName = await xTapPaywallInfo.name; // Old way
                        String? xTapName = await xTapPaywallInfo.name; // New way
                        String resultString = xTapPaywallResult?.toString() ?? 'null';
                        
                        print("Handler (onDismiss - x_tap): ${xTapName ?? 'Unknown'}");
                        debugPrint('🔍 X Tap Paywall dismissed - detailed result: $resultString');
                        
                        // MIXPANEL_COST_CUT: Removed X tap paywall dismiss - Superwall analytics
                        
                        // Check if this is a successful purchase result
                        if (resultString.contains('PurchasedPaywallResult')) {
                          debugPrint('✅ Purchase detected in x_tap handler! Navigating to congratulations screen');
                          
                          // MIXPANEL_COST_CUT: Removed X tap purchase success - Superwall analytics
                          
                          // Update Firebase with subscription data
                          _updateFirebaseSubscriptionWithProductId('com.stoppr.app.annual80OFF');
                          
                          // Navigate to congratulations screen
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const CongratulationsScreen1(),
                              ),
                              (route) => false,
                            );
                          }
                        } else if (resultString.contains('DeclinedPaywallResult')) {
                          debugPrint('🔍 X Tap Paywall dismissed by X button');
                        }
                      });

                      xTapHandler.onError((error) {
                        _handleSuperwallError(error);
                      });

                      xTapHandler.onSkip((skipReason) async {
                        // String description = await skipReason.description; // Old way
                        String reasonString = skipReason.toString(); // New way
                        print("Handler (onSkip - x_tap): $reasonString");
                        // MIXPANEL_COST_CUT: Removed X tap paywall skip - Superwall analytics
                      });

                      // Register and trigger the INSERT_YOUR_X_TAP_PLACEMENT_ID_HERE placement
                      /*
                      await Superwall.shared.registerPlacement(
                        "INSERT_YOUR_X_TAP_PLACEMENT_ID_HERE", 
                        handler: xTapHandler,
                        feature: () async {
                          MixpanelService.trackEvent('X Tap Paywall - Feature Callback Executed', 
                            properties: {'placement': 'INSERT_YOUR_X_TAP_PLACEMENT_ID_HERE'}
                          );                  
                          
                          // Update Firebase with subscription data - using 80% off product ID
                          _updateFirebaseSubscriptionWithProductId('com.stoppr.app.annual80OFF');
                          
                          // Navigate to congratulations screen on successful purchase
                          debugPrint('✅ Purchase successful via x_tap Superwall! Navigating to congratulations screen');
                          
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const CongratulationsScreen1(),
                              ),
                              (route) => false,
                            );
                          }
                        }
                      );
                      */
                      debugPrint('Triggered Superwall campaign with INSERT_YOUR_X_TAP_PLACEMENT_ID_HERE placement');
                    } catch (e) {
                       debugPrint('Error triggering x_tap Superwall campaign: $e');
                       // MIXPANEL_COST_CUT: Removed X tap trigger failed - use Crashlytics for errors
                    }
                    // --- End: Trigger INSERT_YOUR_X_TAP_PLACEMENT_ID_HERE placement ---
                    
                  } else {
                    debugPrint('ℹ️ Standard Paywall dismissed - result: $paywallResult (not showing x_tap or email dialog)');
                  }
                  // ... existing code ...
                });

                handler.onError((error) {
                  // Reset flag before handling error (will also be reset in _handleSuperwallError but being explicit)
                  _isStandardPaywallRegistered = false;
                  _handleSuperwallError(error);
                });

                handler.onSkip((skipReason) async {
                  // Reset the registration flag when paywall is skipped
                  _isStandardPaywallRegistered = false;
                  
                  // String description = await skipReason.description; // Old way
                  String reasonString = skipReason.toString(); // New way

                  if (skipReason is PaywallSkippedReasonHoldout) {
                    // print("Handler (onSkip): $description"); // Old way
                    print("Handler (onSkip): Holdout - $reasonString"); // New way

                    // final experiment = await skipReason.experiment; // Old way
                    // final experimentId = await experiment.id; // Old way
                    // print("Holdout with experiment: ${experimentId}");
                    print("Holdout details included in reason: $reasonString"); // New way logging
                  } else if (skipReason is PaywallSkippedReasonNoAudienceMatch) {
                    // print("Handler (onSkip): $description"); // Old way
                    print("Handler (onSkip): No Audience Match - $reasonString"); // New way
                  } else if (skipReason is PaywallSkippedReasonPlacementNotFound) {
                    // print("Handler (onSkip): $description"); // Old way
                    print("Handler (onSkip): Placement Not Found - $reasonString"); // New way
                  } else {
                    // print("Handler (onSkip): Unknown skip reason"); // Old way
                    print("Handler (onSkip): Unknown skip reason - $reasonString"); // New way
                  }
                });

                // Log subscription status (guarded by readiness)
                if (NotificationService.isSuperwallReady) {
                  await Superwall.shared.getSubscriptionStatus().then((status) {
                    debugPrint('Current subscription status: $status');
                  });
                } else {
                  debugPrint('Superwall not ready; skipping subscription status log');
                }

                // Use the correct method to register a placement with feature callback and handler
                await Superwall.shared.registerPlacement(
                  "INSERT_YOUR_STANDARD_PAYWALL_PLACEMENT_ID_HERE", 
                  handler: handler,
                  feature: () async {
                    await PostPurchaseHandler.handlePostPurchase(context);
                  }
                );
                
                debugPrint('Triggered Superwall campaign with INSERT_YOUR_STANDARD_PAYWALL_PLACEMENT_ID_HERE placement');
              } catch (e) {
                debugPrint('Error triggering Superwall standard campaign: $e');
                // Reset flag if registration/triggering fails
                _isStandardPaywallRegistered = false;
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent, // Transparent for gradient
              foregroundColor: Colors.white, // White text on gradient
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30), // More rounded corners
              ),
              elevation: 0, // No elevation for flat gradient look
              shadowColor: Colors.transparent,
            ),
            child: Text(
              l10n.translate('prePaywall_becomeStopprButton') == 'prePaywall_becomeStopprButton' 
                  ? 'Become a STOPPR' 
                  : l10n.translate('prePaywall_becomeStopprButton'),
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Colors.white, // White text on gradient
              ),
            ),
          ),
        ),
        const SizedBox(height: 4), // Reduced from 8
        // Text( // Commented out
        //   l10n.translate('prePaywall_purchaseNote'),
        //   textAlign: TextAlign.center,
        //   style: const TextStyle(
        //     fontFamily: 'ElzaRound',
        //     fontWeight: FontWeight.w400,
        //     fontSize: 14,
        //     color: Colors.white,
        //   ),
        // ),
        // const SizedBox(height: 4), // Commented out or adjust if purchaseNote is removed
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4.0, // Adjust spacing as needed
          runSpacing: 4.0, // Adjust runSpacing as needed
          children: [
            Text(
              '${l10n.translate('prePaywall_cancelAnytime')} ', 
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Color(0xFF666666), // Gray text for white background
              ),
            ),
            const Text(
              '✅',
              style: TextStyle(fontSize: 14),
            ),
            Text(
              ' ${l10n.translate('prePaywall_moneyBack')} ', 
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Color(0xFF666666), // Gray text for white background
              ),
            ),
            const Text(
              '🛡️',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 10), // Reduced from 16
      ],
    );
  }

  // New method to build feature item with PNG icon and text
  Widget _buildFeatureItemWithPNG({
    required String icon,
    required String textKey, // Changed to textKey
    required Color iconColor,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            child: Image.asset(
              'assets/images/onboarding/$icon',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  color: Color(0xFF1A1A1A), // Dark text for white background
                ),
                children: _buildStyledText(l10n.translate(textKey)), // Translate here
              ),
            ),
          ),
        ],
      ),
    );
  }

  // New method to build custom plan section
  Widget _buildCustomPlanSection() {
    final l10n = AppLocalizations.of(context)!;
    // Get name with fallback to "Friend" if empty
    final displayName = _firstName.isNotEmpty ? _firstName : l10n.translate('prePaywall_friendFallbackName');
    
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10), // Reduced from 20
          
          // Checkmark with visible circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFed3272), // Brand pink background
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFed3272).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 24,
            ),
          ),
          
          const SizedBox(height: 35),
          
          // Custom plan text
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A), // Dark text for white background
                height: 1.2,
              ),
              children: _firstName.isEmpty 
                ? [
                    TextSpan(
                      text: l10n.translate('prePaywall_customPlan_title_noName'),
                    ),
                  ]
                : [
                    TextSpan(
                      text: l10n
                          .translate('prePaywall_customPlan_title_withName')
                          .replaceFirst('{firstName}', TextSanitizer.sanitizeForDisplay(displayName)),
                    ),
                  ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // You will quit sugar by text
          Text(
            AppLocalizations.of(context)!.translate('prePaywall_quitByPrompt'),
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A), // Dark text for white background
              letterSpacing: 0.13,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 20),
          
          // Quit date in rounded container
          Container(
            width: MediaQuery.of(context).size.width * 0.75, // Increased from 0.55 to fit date in one line
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), // Increased vertical padding
            decoration: BoxDecoration(
              color: const Color(0xFFFDF8FA), // Slight pink background
              borderRadius: BorderRadius.circular(30), // Reduced radius
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              formattedQuitDate,
              textAlign: TextAlign.center,
              maxLines: 1, // Force single line display
              overflow: TextOverflow.ellipsis, // Handle overflow gracefully
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w700,
                fontSize: 20, // Reduced from 24
                color: Color(0xFF1A1A1A), // Dark text instead of purple
              ),
            ),
          ),
          
          const SizedBox(height: 10), // Reduced from 50
          
          // Horizontal line separator
          Container(
            width: 200,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0x30FFFFFF), // 19% opacity white
            ),
          ),
          
          const SizedBox(height: 10), // Reduced from 30
          
          // Stars with wings image
          Image.asset(
            'assets/images/onboarding/stars_wings.png',
            width: 200,
            height: 100,
            fit: BoxFit.contain,
          ),
          
          const SizedBox(height: 20),
          
          // Stronger, Healthier, Happier
          const Text(
            'Stronger. Healthier. Happier.',
            style: TextStyle(
              fontFamily: 'ElzaRound',
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A), // Dark text for white background
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 15),
          
          /*
          // Interaction instruction (TEMPORARILY DISABLED)
          Text(
            l10n.translate('benefitsImpact_instruction'),
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              color: Color(0xFF666666), // Gray text for instruction
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 16),

          // Interactive Benefits Chart (TEMPORARILY DISABLED)
          _buildInteractiveBenefitsChart(),

          const SizedBox(height: 10),

          const SizedBox(height: 10),
          */
        ],
      ),
    );
  }

  // Helper method to track checkout events in Facebook and Firebase Analytics
  Future<void> _trackCheckoutEvent({
    required String productType,
    required double price,
    required String itemName,
    required String itemVariant,
    required String buttonType,
    String? orderId,
  }) async {
    // Generate order ID if not provided (using timestamp for checkout initiation)
    final fbOrderId = orderId ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    // Track Facebook InitiateCheckout event
    try {
      final facebookAppEvents = FacebookAppEvents();
      await facebookAppEvents.logEvent(
        name: 'fb_mobile_initiated_checkout',
        parameters: {
          'fb_content_type': 'product',
          'fb_content_id': _getPlatformProductId(productType),
          'fb_currency': 'USD',
          '_valueToSum': price,
          'fb_num_items': 1,
          'fb_payment_info_available': true,
          'fb_order_id': fbOrderId, // Added order ID for deduplication
        },
      );
      debugPrint('📘 Facebook fb_mobile_initiated_checkout event tracked for $buttonType with order ID: $fbOrderId');
      
      // MIXPANEL_COST_CUT: Removed Facebook tracking success - native Facebook analytics sufficient
    } catch (e) {
      debugPrint('❌ Error tracking Facebook event: $e');
      
      // MIXPANEL_COST_CUT: Removed Facebook tracking failure - use Crashlytics for errors
    }
    
    // Track Firebase Analytics InitiateCheckout event
    try {
      await FirebaseAnalytics.instance.logBeginCheckout(
        value: price,
        currency: 'USD',
        items: [
          AnalyticsEventItem(
            itemId: _getPlatformProductId(productType),
            itemName: itemName,
            itemCategory: 'subscription',
            itemVariant: itemVariant,
          ),
        ],
      );
      debugPrint('📊 Firebase Analytics begin_checkout event tracked for $buttonType');
      
      // MIXPANEL_COST_CUT: Removed Firebase Analytics tracking - native Firebase sufficient
    } catch (e) {
      debugPrint('❌ Error tracking Firebase Analytics event: $e');
      
      // MIXPANEL_COST_CUT: Removed Firebase Analytics failure - use Crashlytics for errors
    }
  }

  // Helper method to update Firebase with subscription data
  Future<void> _updateFirebaseSubscriptionData() async {
    try {
      debugPrint('🔄 Starting _updateFirebaseSubscriptionData()');
      
      // Get the current user ID - Assume user MUST exist at this point
      final uid = FirebaseAuth.instance.currentUser?.uid;
      
      // If uid is null here, it's an unexpected error state
      if (uid == null) {
        debugPrint('❌❌❌ CRITICAL ERROR: User ID is null in _updateFirebaseSubscriptionData where it should exist!');
        // Optionally: Log to Crashlytics or other error reporting service
        // FirebaseCrashlytics.instance.recordError(
        //   Exception('_updateFirebaseSubscriptionData: UID is null unexpectedly'),
        //   StackTrace.current,
        //   reason: 'User should have been authenticated (likely anonymously) earlier in the flow.'
        // );
        // MIXPANEL_COST_CUT: Removed error tracking - use Crashlytics
        // TODO: Add Crashlytics.recordError() here if needed
        return; // Exit the function as we cannot proceed without a UID
      }
      
      debugPrint('🔍 Current user ID: $uid');
      
      // REMOVED: Block that checked for null uid, signed out, and signed in anonymously.
      
      // Proceed only if we have a valid uid (check already performed)
      // For debug buttons, simulate a standard subscription
      debugPrint('🛍️ Debug button pressed - Setting up simulated premium subscription');
      final now = DateTime.now();
      final subscriptionStartDate = now;
      // Annual subscription: current date + 1 year
      final subscriptionExpirationDate = DateTime(
        now.year + 1, 
        now.month, 
        now.day, 
        now.hour, 
        now.minute, 
        now.second
      );
      
      // Use a standard annual subscription product ID
      const productId = 'com.stoppr.app.annual';
      
      debugPrint('📅 Simulating subscription dates - Start: $subscriptionStartDate, Expiration: $subscriptionExpirationDate');
      
      // Update user subscription status
      await _userRepository.updateUserSubscriptionStatus(
        uid, 
        SubscriptionType.paid_standard,
        productId: productId,
        startDate: subscriptionStartDate,
        expirationDate: subscriptionExpirationDate
      );
      
      // Mark as debug user if in debug mode
      if (kDebugMode) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({'debugUser': true}, SetOptions(merge: true));
        debugPrint('🧪 Marked user as debug user in Firestore');
      }
      
      // FOR DEBUG: Preserve existing streak data instead of resetting it
      // Only initialize streak if user doesn't have one already
      try {
        final existingStreakData = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        
        final hasExistingStreak = existingStreakData.data()?['streak_start_timestamp'] != null;
        
        if (!hasExistingStreak) {
          debugPrint('🧪 Debug: No existing streak found, initializing new streak');
          await _streakService.setCustomStreakStartDate(now);
        } else {
          debugPrint('🧪 Debug: Existing streak found, preserving it (NOT resetting)');
        }
      } catch (e) {
        debugPrint('⚠️ Debug: Error checking existing streak, initializing new one: $e');
        await _streakService.setCustomStreakStartDate(now);
      }

      debugPrint('📱 Updated Firebase: User granted PREMIUM subscription ($productId)');
    } catch (e, stack) {
      debugPrint('⚠️ Error updating Firebase (Debug Data): $e');
      debugPrint('Stack trace: $stack');
      // Optionally log to Crashlytics
      // FirebaseCrashlytics.instance.recordError(e, stack, reason: 'Error in _updateFirebaseSubscriptionData');
    }
  }

  // Static channel for environment checks
  static const MethodChannel _environmentChannel = MethodChannel('com.stoppr.app/environment');
  
  // Helper method to get platform-specific product IDs
  String _getPlatformProductId(String productType) {
    if (Platform.isIOS) {
      switch (productType) {
        case 'annual':
          return 'com.stoppr.app.annual';
        case 'annual_trial':
          return 'com.stoppr.app.annual.trial';
        case 'annual80off':
          return 'com.stoppr.app.annual80OFF';
        case 'monthly':
          return 'com.stoppr.app.monthly';
        // lifetime removed
        case 'trial_paid':
          return 'com.stoppr.app.trial.paid';
        default:
          return 'com.stoppr.app.annual';
      }
    } else {
      // Android product IDs
      switch (productType) {
        case 'annual':
          return 'com.stoppr.sugar.app.annual:com-stoppr-sugar-app-annual';
        case 'annual_trial':
          return 'com.stoppr.sugar.app.annual.trial:com-stoppr-sugar-app-annual-trial';
        case 'annual80off':
          return 'com.stoppr.sugar.app.annual80OFF:com-stoppr-sugar-app-annual80OFF';
        case 'annual33off':
          return 'com.stoppr.sugar.app.33OFF:com-stoppr-sugar-app-33OFF';
        case 'monthly':
          return 'com.stoppr.sugar.app.monthly:com-stoppr-sugar-app-monthly';
        case 'weekly':
          return 'com.stoppr.sugar.app.weekly:com-stoppr-sugar-app-weekly';
        // lifetime removed
        case 'trial_paid':
          // trial_paid is iOS-only, fallback to annual for Android
          debugPrint('⚠️ trial_paid requested on Android, falling back to annual subscription');
          return 'com.stoppr.sugar.app.annual:com-stoppr-sugar-app-annual';
        default:
          return 'com.stoppr.sugar.app.annual:com-stoppr-sugar-app-annual';
      }
    }
  }
  
  // New helper method to detect TestFlight environment - consistent with MixpanelService
  Future<bool> _isRunningInTestFlight() async {
    try {
      // Direct check for TestFlight environment
      if (Platform.isIOS) {
        final result = await _environmentChannel.invokeMethod<bool>('isTestFlight');
        final isTestFlight = result ?? false;
        debugPrint('📱 Is TestFlight build (direct check): $isTestFlight');
        return isTestFlight;
      }
      return false;
    } catch (e) {
      debugPrint('⚠️ Error checking TestFlight status: $e');
      // Default to false if we can't determine
      return false;
    }
  }

  // Modified method to include TestFlight information
  Future<void> _updateFirebaseSubscriptionWithProductId(String productId) async {
    try {
      debugPrint('🔄 Starting _updateFirebaseSubscriptionWithProductId() with productId: $productId');
      
      // Check if running in TestFlight
      final bool isTestFlight = await _isRunningInTestFlight();
      debugPrint('🧪 Running in TestFlight: $isTestFlight');
      
      // Track the purchase source in Mixpanel
      // MIXPANEL_COST_CUT: Removed subscription purchase tracking - Superwall handles this
      
      // Get the current user ID - Assume user MUST exist at this point
      final uid = FirebaseAuth.instance.currentUser?.uid;
      
      // If uid is null here, it's an unexpected error state
      if (uid == null) {
        debugPrint('❌❌❌ CRITICAL ERROR: User ID is null in _updateFirebaseSubscriptionWithProductId where it should exist!');
        // Optionally: Log to Crashlytics or other error reporting service
        // FirebaseCrashlytics.instance.recordError(
        //   Exception('_updateFirebaseSubscriptionWithProductId: UID is null unexpectedly'),
        //   StackTrace.current,
        //   reason: 'User should have been authenticated (likely anonymously) earlier in the flow after purchase.'
        // );
        // MIXPANEL_COST_CUT: Removed error tracking - use Crashlytics
        // TODO: Add Crashlytics.recordError() here if needed
        return; // Exit the function as we cannot proceed without a UID
      }
      
      debugPrint('🔍 Current user ID: $uid');
      
      // REMOVED: Block that checked for null uid, signed out, and signed in anonymously.
      
      // Proceed only if we have a valid uid (check already performed)
      final now = DateTime.now();
      final subscriptionStartDate = now;
      
      // Determine subscription type and expiration date based on product ID
      SubscriptionType subscriptionType;
      DateTime subscriptionExpirationDate;
      
      // Get base product ID if it's in the new format (platformID:baseID)
      String baseProductId = productId;
      if (productId.contains(':')) {
        baseProductId = productId.split(':')[0];
        debugPrint('📱 Using base product ID for subscription detection: $baseProductId');
      }
      
      // Customize subscription details based on product ID
      if (baseProductId.toLowerCase().contains('lifetime') || 
          baseProductId == 'com.stoppr.lifetime' ||
          baseProductId == 'com.stoppr.sugar.lifetime') {
        // For lifetime purchases - no expiration
        subscriptionType = SubscriptionType.paid_lifetime;
        // Lifetime: No expiration needed (one-time purchase)
        subscriptionExpirationDate = now; // Will not be stored for lifetime
        debugPrint('📅 Setting LIFETIME purchase - no expiration date');
      } else if (baseProductId.toLowerCase().contains('annual80off') || 
          baseProductId.toLowerCase() == 'sugar.app.annual80off') {
        // For the 80% off annual plan
        subscriptionType = SubscriptionType.paid_gift;
        // Annual: current date + 1 year
        subscriptionExpirationDate = DateTime(
          now.year + 1, 
          now.month, 
          now.day, 
          now.hour, 
          now.minute, 
          now.second
        );
        debugPrint('📅 Setting GIFT annual subscription - Expiring in 1 year');
      } else if (baseProductId.toLowerCase().contains('33off')) {
        // For the 33% off plan
        subscriptionType = SubscriptionType.paid_standard;
        // Annual: current date + 1 year
        subscriptionExpirationDate = DateTime(
          now.year + 1, 
          now.month, 
          now.day, 
          now.hour, 
          now.minute, 
          now.second
        );
        debugPrint('📅 Setting STANDARD 33% OFF subscription - Expiring in 1 year');
      } else if (baseProductId.toLowerCase().contains('annual') || 
                baseProductId.toLowerCase().contains('trial')) {
        // For regular annual plans and trial annual plans
        subscriptionType = SubscriptionType.paid_standard;
        // Annual: current date + 1 year
        subscriptionExpirationDate = DateTime(
          now.year + 1, 
          now.month, 
          now.day, 
          now.hour, 
          now.minute, 
          now.second
        );
        debugPrint('📅 Setting STANDARD annual subscription - Expiring in 1 year');
      } else if (baseProductId.toLowerCase().contains('monthly')) {
        // For monthly plans
        subscriptionType = SubscriptionType.paid_standard;
        // Monthly: current date + 1 month
        subscriptionExpirationDate = DateTime(
          now.year, 
          now.month + 1, 
          now.day, 
          now.hour, 
          now.minute, 
          now.second
        );
        debugPrint('📅 Setting STANDARD monthly subscription - Expiring in 1 month');
      } else if (baseProductId.toLowerCase().contains('weekly')) {
        // For weekly plans
        subscriptionType = SubscriptionType.paid_standard;
        // Weekly: current date + 7 days
        subscriptionExpirationDate = now.add(const Duration(days: 7));
        debugPrint('📅 Setting STANDARD weekly subscription - Expiring in 7 days');
      } else {
        // Default to standard annual if unknown
        subscriptionType = SubscriptionType.paid_standard;
        subscriptionExpirationDate = DateTime(
          now.year + 1, 
          now.month, 
          now.day, 
          now.hour, 
          now.minute, 
          now.second
        );
        debugPrint('📅 Setting DEFAULT subscription for unknown product ID - Expiring in 1 year');
      }
      
      debugPrint('📅 Subscription details - Product: $productId, Type: $subscriptionType, Start: $subscriptionStartDate, Expiration: $subscriptionExpirationDate');
      
      // Create the subscription data with TestFlight flag when appropriate
      Map<String, dynamic> subscriptionData = {
        'subscriptionStatus': subscriptionType.toString(),
        'subscriptionProductId': productId,
        'subscriptionStartDate': subscriptionStartDate,
        'subscriptionExpirationDate': subscriptionExpirationDate,
        'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
      };
      
      // Add TestFlight flag if needed
      if (isTestFlight) {
        subscriptionData['isTestFlightPurchase'] = true;
      }
      
      // Update Firestore directly to include all fields - COMMENTED OUT as redundant
      /*
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(subscriptionData, SetOptions(merge: true));
      */
      
      // Verify user is still authenticated before updating
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != uid) {
        // MIXPANEL_COST_CUT: Removed Firestore permission error - use Crashlytics
        debugPrint('⚠️ User authentication state changed - skipping subscription update');
        return;
      }
            
      // Also use the UserRepository method to ensure all standard fields are updated
      await _userRepository.updateUserSubscriptionStatus(
        uid, 
        subscriptionType,
        productId: productId,
        startDate: subscriptionStartDate,
        expirationDate: subscriptionExpirationDate
      );
      
      // Initialize streak - StreakService handles SharedPreferences, Firestore, and widget
      await _streakService.setCustomStreakStartDate(now);
      debugPrint('✅ Streak auto-started for paid user: $now');
      
      debugPrint('📱 Updated Firebase: User granted subscription ($productId, type: $subscriptionType, TestFlight: $isTestFlight)');
    } catch (e, stack) {
      debugPrint('⚠️ Error updating Firebase: $e');
      debugPrint('Stack trace: $stack');
      if (e.toString().contains('permission-denied')) {
        // MIXPANEL_COST_CUT: Removed Firestore permission error - use Crashlytics
        debugPrint('⚠️ Permission denied - user may not be authenticated properly');
      }
      // Optionally log to Crashlytics
      // FirebaseCrashlytics.instance.recordError(e, stack, reason: 'Error in _updateFirebaseSubscriptionWithProductId');
    }
  }

  // Method to open URL with in-app browser
  Future<void> _launchURL(String urlString) async {
    final l10n = AppLocalizations.of(context)!; // Add l10n initialization
    try {
      final Uri url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.inAppWebView);
      } else {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('prePaywall_error_couldNotOpenLink').replaceAll('{error}', e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Email collection dialog removed as per request
  
  // Email saving helper removed as per request

  // Add this new helper method inside the _PrePaywallScreenState class

  Future<bool> _isUserSubscribedCheck() async {
    try {
      // SECURITY FIX: Only check Superwall/RevenueCat - no Firebase bypass
      bool isActiveSuperwall = false;
      if (NotificationService.isSuperwallReady) {
        final status = await Superwall.shared.getSubscriptionStatus();
        isActiveSuperwall = status is SubscriptionStatusActive;
      } else {
        debugPrint('PrePaywall: Superwall not ready; treating as not subscribed for now');
      }

      debugPrint('PrePaywall (_isUserSubscribedCheck): Subscription check - Superwall: $isActiveSuperwall');
      return isActiveSuperwall;
    } catch (e) {
      debugPrint('PrePaywall (_isUserSubscribedCheck): Error checking subscription: $e');
      return false; // Default to non-subscribed if check fails
    }
  }

  // Add method to check TestFlight mode
  Future<void> _checkTestFlightMode() async {
    try {
      final isTestFlight = await MixpanelService.isTestFlight();
      if (mounted) {
        setState(() {
          _isInTestFlight = isTestFlight;
        });
      }
      debugPrint('🧪 Is running in TestFlight: $_isInTestFlight');
    } catch (e) {
      debugPrint('⚠️ Error checking TestFlight status: $e');
    }
  }

  String _capitalizeSpanishMonth(String dateStr, String localeCode) {
    if (localeCode == 'es' && dateStr.isNotEmpty) {
      return dateStr[0].toUpperCase() + dateStr.substring(1);
    }
    return dateStr;
  }

  // Helper method to reset paywall registration flags
  void _resetPaywallFlags() {
    _isStandardPaywallRegistered = false;
    _isGiftPaywallRegistered = false;
    debugPrint('🔄 Reset paywall registration flags');
  }

  // Centralized Superwall error handler to avoid crashes and provide user feedback
  void _handleSuperwallError(Object error) {
    debugPrint('🛑 Superwall error: $error');
    
    // Reset paywall flags to prevent permanent disable
    _resetPaywallFlags();
    
    // MIXPANEL_COST_CUT: Removed purchase error tracking - use Crashlytics
    // TODO: Add Crashlytics.recordError(error, StackTrace.current) if needed

    // Show a friendly message if UI is available
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.translate('errorMessage_purchaseProcessing')),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    // Attempt to reset Superwall in case internal state is corrupted
    try {
      Superwall.shared.reset();
    } catch (e) {
      debugPrint('⚠️ Error calling Superwall.reset(): $e');
    }

    // Persist a record to Firestore for monitoring
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';
      FirebaseFirestore.instance.collection('transactions_fail').add({
        'uid': uid,
        'error': error.toString(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ Error logging transaction failure to Firestore: $e');
    }
  }

  // ---------------- Countdown timer helpers ----------------

  void _startDiscountTimer() {
    _discountTimer?.cancel();
    _discountTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingDiscountSeconds > 0) {
        setState(() {
          _remainingDiscountSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatCountdown(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Build the review slideshow
  Widget _buildReviewSlideshow() {
    return Container(
      height: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Slideshow
          Expanded(
            child: PageView.builder(
              controller: _reviewPageController ??= PageController(initialPage: 0),
              onPageChanged: (index) {
                setState(() {
                  _currentReviewIndex = index;
                });
              },
              itemCount: _reviewData.length,
              itemBuilder: (context, index) {
                final review = _reviewData[index];
                return _buildReviewCard(
                  review['nameKey']!,
                  review['textKey']!,
                  review['avatar']!,
                );
              },
            ),
          ),
          
          // Page indicators
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _reviewData.length,
              (index) => Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentReviewIndex == index 
                    ? const Color(0xFF1A1A1A) // Dark active indicator
                    : const Color(0xFF666666), // Gray inactive indicator
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build individual review card
  Widget _buildReviewCard(String nameKey, String textKey, String avatar) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA), // Light background for cards
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE0E0E0), // Light border
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // User info with stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.translate(nameKey),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Color(0xFF1A1A1A), // Dark text for light cards
                ),
              ),
              const SizedBox(width: 10),
              Row(
                children: List.generate(
                  5,
                  (index) => const Icon(
                    Icons.star,
                    color: Color(0xFFFFB515),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Review text
          Text(
            l10n.translate(textKey),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w400,
              fontSize: 15,
              color: Color(0xFF333333), // Dark gray text for light cards
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }



  // Review data
  static const List<Map<String, String>> _reviewData = [
    {
      'nameKey': 'prePaywall_review1_name',
      'textKey': 'prePaywall_review1_text',
      'avatar': 'SM',
    },
    {
      'nameKey': 'prePaywall_review2_name',
      'textKey': 'prePaywall_review2_text',
      'avatar': 'MJ',
    },
    {
      'nameKey': 'prePaywall_review3_name',
      'textKey': 'prePaywall_review3_text',
      'avatar': 'ER',
    },
    {
      'nameKey': 'prePaywall_review4_name',
      'textKey': 'prePaywall_review4_text',
      'avatar': 'DC',
    },
    {
      'nameKey': 'prePaywall_review5_name',
      'textKey': 'prePaywall_review5_text',
      'avatar': 'JW',
    },
    {
      'nameKey': 'prePaywall_review6_name',
      'textKey': 'prePaywall_review6_text',
      'avatar': 'AT',
    },
    {
      'nameKey': 'prePaywall_review7_name',
      'textKey': 'prePaywall_review7_text',
      'avatar': 'LK',
    },
    {
      'nameKey': 'prePaywall_review8_name',
      'textKey': 'prePaywall_review8_text',
      'avatar': 'RS',
    },
    {
      'nameKey': 'prePaywall_review9_name',
      'textKey': 'prePaywall_review9_text',
      'avatar': 'MG',
    },
    {
      'nameKey': 'prePaywall_review10_name',
      'textKey': 'prePaywall_review10_text',
      'avatar': 'NK',
    },
  ];

  // Build interactive benefits chart widget
  Widget _buildInteractiveBenefitsChart() {
    return _InteractiveBenefitsChart();
  }
}

// Interactive Benefits Chart Widget - Exact same design as BenefitsImpactScreen
class _InteractiveBenefitsChart extends StatefulWidget {
  @override
  _InteractiveBenefitsChartState createState() => _InteractiveBenefitsChartState();
}

class _InteractiveBenefitsChartState extends State<_InteractiveBenefitsChart>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _dotAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Animation<double>? _dotAnimation;
  
  int _selectedBenefitIndex = 0;
  int _selectedWeekIndex = 5; // Default to Week 6
  
  // Same benefit data as BenefitsImpactScreen
  final List<_PrePaywallBenefitData> _benefits = [
    _PrePaywallBenefitData(
      iconData: Icons.bolt,
      titleKey: 'benefitsImpact_energy_title',
      yAxisKey: 'benefitsImpact_energy_yAxis',
      weeklyDescriptionKeyPrefix: 'benefitsImpact_energy',
      color: const Color(0xFFFF6B35),
      weeklyValues: [0.1, 0.2, 0.4, 0.6, 0.75, 0.85, 0.9, 0.95],
      peakWeek: 5,
    ),
    _PrePaywallBenefitData(
      iconData: Icons.wb_sunny,
      titleKey: 'benefitsImpact_mood_title',
      yAxisKey: 'benefitsImpact_mood_yAxis',
      weeklyDescriptionKeyPrefix: 'benefitsImpact_mood',
      color: const Color(0xFFFFA726),
      weeklyValues: [0.1, 0.15, 0.25, 0.4, 0.6, 0.8, 0.9, 0.95],
      peakWeek: 5,
    ),
    _PrePaywallBenefitData(
      iconData: Icons.psychology,
      titleKey: 'benefitsImpact_focus_title',
      yAxisKey: 'benefitsImpact_focus_yAxis',
      weeklyDescriptionKeyPrefix: 'benefitsImpact_focus',
      color: const Color(0xFF42A5F5),
      weeklyValues: [0.1, 0.2, 0.35, 0.5, 0.7, 0.85, 0.92, 0.97],
      peakWeek: 5,
    ),
    _PrePaywallBenefitData(
      iconData: Icons.fitness_center,
      titleKey: 'benefitsImpact_strength_title',
      yAxisKey: 'benefitsImpact_strength_yAxis',
      weeklyDescriptionKeyPrefix: 'benefitsImpact_strength',
      color: const Color(0xFF66BB6A),
      weeklyValues: [0.1, 0.18, 0.3, 0.45, 0.65, 0.8, 0.9, 0.95],
      peakWeek: 5,
    ),
    _PrePaywallBenefitData(
      iconData: Icons.bedtime,
      titleKey: 'benefitsImpact_sleep_title',
      yAxisKey: 'benefitsImpact_sleep_yAxis',
      weeklyDescriptionKeyPrefix: 'benefitsImpact_sleep',
      color: const Color(0xFF9C27B0),
      weeklyValues: [0.1, 0.25, 0.4, 0.6, 0.75, 0.85, 0.9, 0.95],
      peakWeek: 5,
    ),
    _PrePaywallBenefitData(
      iconData: Icons.favorite,
      titleKey: 'benefitsImpact_hormones_title',
      yAxisKey: 'benefitsImpact_hormones_yAxis',
      weeklyDescriptionKeyPrefix: 'benefitsImpact_hormones',
      color: const Color(0xFFE91E63),
      weeklyValues: [0.1, 0.12, 0.2, 0.35, 0.55, 0.75, 0.85, 0.9],
      peakWeek: 5,
    ),
    _PrePaywallBenefitData(
      iconData: Icons.self_improvement,
      titleKey: 'benefitsImpact_confidence_title',
      yAxisKey: 'benefitsImpact_confidence_yAxis',
      weeklyDescriptionKeyPrefix: 'benefitsImpact_confidence',
      color: const Color(0xFF7E57C2),
      weeklyValues: [0.1, 0.15, 0.22, 0.35, 0.5, 0.7, 0.85, 0.92],
      peakWeek: 5,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _dotAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _dotAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dotAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
    _dotAnimationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dotAnimationController.dispose();
    super.dispose();
  }

  void _selectBenefit(int index) {
    if (index == _selectedBenefitIndex) return;
    
    setState(() {
      _selectedBenefitIndex = index;
      // Reset to default week when switching benefits
      _selectedWeekIndex = 5;
    });
    
    _animationController.reset();
    _animationController.forward();
    
    // MIXPANEL_COST_CUT: Removed chart benefit selection - pure noise
  }

  void _selectWeek(int weekIndex) {
    if (weekIndex == _selectedWeekIndex) return;
    setState(() {
      _selectedWeekIndex = weekIndex;
    });
    if (_dotAnimation != null) {
      _dotAnimationController.reset();
      _dotAnimationController.forward();
    }
    
    // MIXPANEL_COST_CUT: Removed chart week selection - pure noise
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selectedBenefit = _benefits[_selectedBenefitIndex];
    
    return Column(
      children: [
        // Icons row - same as BenefitsImpactScreen
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_benefits.length, (index) {
            final isSelected = index == _selectedBenefitIndex;
            return GestureDetector(
              onTap: () => _selectBenefit(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: 36,
                height: 36,
                                  decoration: BoxDecoration(
                    color: isSelected 
                        ? _benefits[index].color 
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? _benefits[index].color : const Color(0xFFCCCCCC),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: _benefits[index].color.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Icon(
                    _benefits[index].iconData,
                    color: isSelected ? Colors.white : const Color(0xFF666666),
                    size: 18,
                  ),
              ),
            );
          }),
        ),
        
        const SizedBox(height: 20),
        
        // Chart container - same design as BenefitsImpactScreen
        AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child:                 Container(
                  width: double.infinity,
                  height: 300,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA), // Light gray background
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFCCCCCC), // Darker border for better visibility
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chart title
                      Text(
                        l10n.translate(selectedBenefit.titleKey),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          color: Color(0xFF1A1A1A), // Dark text for light background
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Y-axis label as subtitle
                      Text(
                        l10n.translate(selectedBenefit.yAxisKey),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          color: Color(0xFF666666), // Gray subtitle for light background
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Chart
                      Expanded(
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            final RenderBox renderBox = context.findRenderObject() as RenderBox;
                            final localPosition = renderBox.globalToLocal(details.globalPosition);
                            
                            // Calculate chart area (matching the painter's chartArea)
                            const chartPadding = 20.0;
                            const chartLeft = 60.0;
                            const chartRight = 100.0;
                            final chartWidth = renderBox.size.width - chartLeft - chartRight;
                            
                            // Calculate which week the user is touching
                            final relativeX = localPosition.dx - chartLeft - chartPadding;
                            final stepX = chartWidth / (selectedBenefit.weeklyValues.length - 1);
                            final weekIndex = (relativeX / stepX).round().clamp(0, selectedBenefit.weeklyValues.length - 1);
                            
                            _selectWeek(weekIndex);
                          },
                          onTapDown: (details) {
                            final RenderBox renderBox = context.findRenderObject() as RenderBox;
                            final localPosition = renderBox.globalToLocal(details.globalPosition);
                            
                            // Calculate chart area (matching the painter's chartArea)
                            const chartPadding = 20.0;
                            const chartLeft = 60.0;
                            const chartRight = 100.0;
                            final chartWidth = renderBox.size.width - chartLeft - chartRight;
                            
                            // Calculate which week the user is touching
                            final relativeX = localPosition.dx - chartLeft - chartPadding;
                            final stepX = chartWidth / (selectedBenefit.weeklyValues.length - 1);
                            final weekIndex = (relativeX / stepX).round().clamp(0, selectedBenefit.weeklyValues.length - 1);
                            
                            _selectWeek(weekIndex);
                          },
                          child: AnimatedBuilder(
                            animation: _dotAnimation ?? _animationController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _PrePaywallChartPainter(
                                  values: selectedBenefit.weeklyValues,
                                  color: selectedBenefit.color,
                                  peakWeek: selectedBenefit.peakWeek,
                                  selectedWeek: _selectedWeekIndex,
                                  yAxisLabel: l10n.translate(selectedBenefit.yAxisKey),
                                  animation: _fadeAnimation.value,
                                  dotAnimation: _dotAnimation?.value ?? 1.0,
                                ),
                                child: const SizedBox(
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              );
                            },
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
        
        const SizedBox(height: 15),
        
        // Legend - same as BenefitsImpactScreen
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: selectedBenefit.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.translate('benefitsImpact_withSTOPPR'),
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                color: Color(0xFF1A1A1A), // Dark text for light background
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 20),
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF666666), // Gray dot for light background
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.translate('benefitsImpact_withoutSTOPPR'),
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                color: Color(0xFF666666), // Gray text for light background
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // Dynamic description - same design as BenefitsImpactScreen
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: selectedBenefit.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selectedBenefit.color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_graph,
                      color: selectedBenefit.color,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.3),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          l10n.translate(selectedBenefit.getWeeklyDescriptionKey(_selectedWeekIndex)),
                          key: ValueKey(_selectedWeekIndex),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            color: Color(0xFF1A1A1A), // Dark text for light background
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Data model for pre-paywall benefit
class _PrePaywallBenefitData {
  final IconData iconData;
  final String titleKey;
  final String yAxisKey;
  final String weeklyDescriptionKeyPrefix;
  final Color color;
  final List<double> weeklyValues;
  final int peakWeek;

  _PrePaywallBenefitData({
    required this.iconData,
    required this.titleKey,
    required this.yAxisKey,
    required this.weeklyDescriptionKeyPrefix,
    required this.color,
    required this.weeklyValues,
    required this.peakWeek,
  });
  
  String getWeeklyDescriptionKey(int weekIndex) {
    return '${weeklyDescriptionKeyPrefix}_week${weekIndex + 1}';
  }
}

// Custom painter for the pre-paywall chart
class _PrePaywallChartPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final int peakWeek;
  final int selectedWeek;
  final String yAxisLabel;
  final double animation;
  final double dotAnimation;

  _PrePaywallChartPainter({
    required this.values,
    required this.color,
    required this.peakWeek,
    required this.selectedWeek,
    required this.yAxisLabel,
    required this.animation,
    required this.dotAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final baselinePaint = Paint()
      ..color = const Color(0xFF666666) // Gray baseline for light background
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = const Color(0xFF1A1A1A).withOpacity(0.1) // Dark grid lines
      ..strokeWidth = 1;

    final chartArea = Rect.fromLTWH(60, 20, size.width - 100, size.height - 60);

    // Draw grid lines
    for (int i = 0; i <= 4; i++) {
      final y = chartArea.top + (chartArea.height / 4) * i;
      canvas.drawLine(
        Offset(chartArea.left, y),
        Offset(chartArea.right, y),
        gridPaint,
      );
    }

    // Draw Y-axis labels
    final textPainter = TextPainter(
      textDirection: ui.TextDirection.ltr,
    );

    for (int i = 0; i <= 4; i++) {
      final y = chartArea.top + (chartArea.height / 4) * i;
      final value = (4 - i) * 25; // 0, 25, 50, 75, 100
      
      textPainter.text = TextSpan(
        text: '$value%',
        style: const TextStyle(
          color: Color(0xFF666666), // Gray text for light background
          fontSize: 12,
          fontFamily: 'ElzaRound',
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(15, y - textPainter.height / 2));
    }

    // Draw baseline (without Stoppr) - gradual improvement
    final baselinePath = Path();
    final stepX = chartArea.width / (values.length - 1);
    final baselineValues = [0.1, 0.12, 0.15, 0.18, 0.22, 0.25, 0.28, 0.3]; // Gradual increase
    
    for (int i = 0; i < values.length; i++) {
      final x = chartArea.left + stepX * i;
      final y = chartArea.bottom - (chartArea.height * baselineValues[i]);
      
      if (i == 0) {
        baselinePath.moveTo(x, y);
      } else {
        baselinePath.lineTo(x, y);
      }
    }
    canvas.drawPath(baselinePath, baselinePaint);

    // Draw main curve (with Stoppr)
    final path = Path();
    final fillPath = Path();
    
    for (int i = 0; i < values.length; i++) {
      final x = chartArea.left + stepX * i;
      final animatedValue = values[i] * animation;
      final y = chartArea.bottom - (chartArea.height * animatedValue);
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, chartArea.bottom);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    
    // Complete fill path
    fillPath.lineTo(chartArea.right, chartArea.bottom);
    fillPath.close();
    
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw interactive selected week highlight
    if (selectedWeek < values.length) {
      final selectedX = chartArea.left + stepX * selectedWeek;
      final selectedY = chartArea.bottom - (chartArea.height * values[selectedWeek] * animation);
      
      // Draw vertical dashed line
      final dashPaint = Paint()
        ..color = color
        ..strokeWidth = 2;
      
      final dashHeight = 5;
      final dashSpace = 5;
      double currentY = chartArea.bottom;
      
      while (currentY > selectedY) {
        canvas.drawLine(
          Offset(selectedX, currentY),
          Offset(selectedX, math.max(currentY - dashHeight, selectedY)),
          dashPaint,
        );
        currentY -= dashHeight + dashSpace;
      }
      
      // Draw interactive glowing dot with enhanced light effect and animation
      final animatedScale = 0.8 + (0.2 * dotAnimation); // Scale from 0.8 to 1.0
      
      // Outermost glow (largest, most subtle)
      final outerGlowPaint = Paint()
        ..color = color.withOpacity(0.15 * dotAnimation)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(selectedX, selectedY), 20 * animatedScale, outerGlowPaint);
      
      // Large glow layer
      final largeGlowPaint = Paint()
        ..color = color.withOpacity(0.25 * dotAnimation)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(selectedX, selectedY), 16 * animatedScale, largeGlowPaint);
      
      // Medium glow layer
      final mediumGlowPaint = Paint()
        ..color = color.withOpacity(0.4 * dotAnimation)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(selectedX, selectedY), 12 * animatedScale, mediumGlowPaint);
      
      // Inner glow layer
      final innerGlowPaint = Paint()
        ..color = color.withOpacity(0.7 * dotAnimation)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(selectedX, selectedY), 8 * animatedScale, innerGlowPaint);
      
      // Core bright dot
      final corePaint = Paint()
        ..color = color.withOpacity(dotAnimation)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(selectedX, selectedY), 5 * animatedScale, corePaint);
      
      // Bright white center highlight
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.9 * dotAnimation)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(selectedX, selectedY), 3 * animatedScale, highlightPaint);
      
      // Dynamic week label
      textPainter.text = TextSpan(
        text: 'Week ${selectedWeek + 1}',
        style: TextStyle(
          color: const Color(0xFF1A1A1A), // Dark text for light background
          fontSize: 14,
          fontFamily: 'ElzaRound',
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(selectedX - textPainter.width / 2, chartArea.bottom + 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 