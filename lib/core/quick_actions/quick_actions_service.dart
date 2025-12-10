import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';
import '../chat/crisp_service.dart';
import '../../features/onboarding/data/services/onboarding_progress_service.dart';
import '../../features/onboarding/presentation/screens/onboarding_page.dart';
import '../navigation/page_transitions.dart';
import '../analytics/mixpanel_service.dart';
import '../config/env_config.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import '../repositories/user_repository.dart';
import '../../features/onboarding/presentation/screens/congratulations/congratulations_screen_1.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/core/subscription/subscription_service.dart';
import 'package:stoppr/core/streak/streak_service.dart';
import 'package:stoppr/core/subscription/post_purchase_handler.dart';

/// Service for handling quick actions (app icon actions)
class QuickActionsService {
  // Singleton instance
  static final QuickActionsService _instance = QuickActionsService._internal();
  factory QuickActionsService() => _instance;

  // Quick actions instance
  final QuickActions _quickActions = const QuickActions();
  
  // Services
  final OnboardingProgressService _progressService = OnboardingProgressService();
  final UserRepository _userRepository = UserRepository();
  
  // Action identifiers
  static const String dontDeleteMeActionId = 'action_dont_delete_me';
  static const String contactUsActionId = 'action_contact_us';
  // Removed panic button action ID - no longer needed

  // Private constructor
  QuickActionsService._internal();
  
  // Direct action handlers for when the app is launched via quick action
  static final _actionHandlers = <String, Function()>{};
  
  // Keep a static reference to the most recent valid context
  static BuildContext? _lastValidContext;
  
  // Store pending action to execute when context becomes available
  static String? _pendingAction;
  
  // Flag to indicate if we're initialized
  bool _isInitialized = false;
  
  // Localization cache
  Map<String, String>? _cachedLocalizedStrings;
  String? _cachedLanguageCode;
  
  /// Register a direct handler for a quick action
  /// This allows actions to work even when launched from outside the app
  void registerActionHandler(String actionType, Function() handler) {
    _actionHandlers[actionType] = handler;
  }
  
  /// Check and process any pending actions
  void checkPendingActions() {
    if (_pendingAction != null && _lastValidContext != null && _lastValidContext!.mounted) {
      final actionType = _pendingAction;
      _pendingAction = null; // Clear pending action
      
      // Handle the action
      _handleQuickAction(actionType!, _lastValidContext!);
    }
  }
  
  /// Set the last known valid context
  void setLastValidContext(BuildContext context) {
    try {
      final isContextValid = _isContextValid(context);
      if (isContextValid) {
        _lastValidContext = context;
      }
    } catch (e) {
      debugPrint('Error setting last valid context: $e');
    }
  }
  
  /// Setup actions that can be handled directly without context
  void setupDirectActionHandlers() {
    // Prevent duplicate initialization
    if (_isInitialized) {
      return;
    }
    
    // Register handlers for each action type
    registerActionHandler(dontDeleteMeActionId, () {
      // Use last valid context if available
      if (_lastValidContext != null && _lastValidContext!.mounted) {
        _handleDontDeleteMe(_lastValidContext!);
      } else {
        // Store as pending action to process when context becomes available
        _pendingAction = dontDeleteMeActionId;
        
        // Try to force handle without context
        forceHandleDontDeleteMe();
      }
    });
    
    registerActionHandler(contactUsActionId, () {
      // Use last valid context if available
      if (_lastValidContext != null && _lastValidContext!.mounted) {
        _openCrispChat(_lastValidContext!);
      } else {
        // Store as pending action to process when context becomes available
        _pendingAction = contactUsActionId;
        
        // Try to force open without context
        forceOpenCrispChat();
      }
    });
    
    // Set up the initial action callback
    _quickActions.initialize((type) {
      // Check if we have a registered handler
      final handler = _actionHandlers[type];
      if (handler != null) {
        handler();
      } else {
        // If we have a valid context, handle it right away
        if (_lastValidContext != null && _lastValidContext!.mounted) {
          _handleQuickAction(type, _lastValidContext!);
        } else {
          // Store as pending action
          _pendingAction = type;
        }
      }
    });
    
    _isInitialized = true;
  }
  
  /// Process the initial action when app launches
  /// Call this from your app's first screen to handle any action that launched the app
  void processInitialAction(BuildContext context) {
    // Store this context for future use
    setLastValidContext(context);
    
    // Check if there are any pending actions to process
    checkPendingActions();
    
    // For iOS, ensure we handle home screen quick actions properly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Do this after a short delay to ensure the app is fully loaded
      Future.delayed(const Duration(milliseconds: 300), () {
        if (context.mounted) {
          setLastValidContext(context);
          checkPendingActions();
        }
      });
    });
  }
  
  /// Initialize quick actions
  Future<void> initialize() async {
    try {
      // Discount labels
      final String discountTitle = await _getLocalizedString(
        'quick_actions_discount_title',
        fallback: '🎉 80% off Annual',
      );
      final String discountSubtitle = await _getLocalizedString(
        'quick_actions_discount_subtitle',
        fallback: 'Get unlimited access to the STOPPR app',
      );

      // Contact labels
      final String contactTitle = await _getLocalizedString(
        'quick_actions_contact_us_title',
        fallback: "Don't delete yet 🙏",
      );
      final String contactSubtitle = await _getLocalizedString(
        'quick_actions_contact_us_subtitle',
        fallback: 'Let us know what we can do for you',
      );

      // Build actions list
      List<ShortcutItem> actions = [];

      // Primary promo action (always gift discount)
      actions.add(ShortcutItem(
        type: dontDeleteMeActionId,
        localizedTitle: discountTitle,
        localizedSubtitle: discountSubtitle,
        icon: 'ic_gift',
      ));

      // Standard Contact Us action (localized)
      actions.addAll([
        ShortcutItem(
          type: contactUsActionId,
          localizedTitle: contactTitle,
          localizedSubtitle: contactSubtitle,
          icon: 'ic_contact_us',
        ),
      ]);

      debugPrint('🔍 QuickActions: Setting ${actions.length} quick actions');
      for (var action in actions) {
        debugPrint('  - ${action.localizedTitle} (${action.type})');
      }

      // Set up available quick actions
      _quickActions.setShortcutItems(actions);
      debugPrint('✅ QuickActions: Quick actions initialized successfully');
    } catch (e) {
      debugPrint('❌ QuickActions: Error initializing quick actions: $e');
    }
  }

  /// Public helper to refresh shortcut items when user attributes change
  Future<void> refreshQuickActions() async {
    try {
      await initialize();
    } catch (e) {
      debugPrint('QuickActions: refreshQuickActions error: $e');
    }
  }
  
  /// Handle quick action when app is launched
  void setupInteractiveCallbacks(BuildContext context) {
    try {
      // Just update the context and don't set up duplicate listeners
      setLastValidContext(context);
    } catch (e) {
      debugPrint('Error setting up quick actions callbacks: $e');
    }
  }
  
  /// Handle a specific quick action
  void _handleQuickAction(String type, BuildContext context) {
    // Track quick action usage in Mixpanel
    MixpanelService.trackEvent('Quick_Action_Used', properties: {
      'action_type': type,
    });
    
    switch (type) {
      case dontDeleteMeActionId:
        _handleDontDeleteMe(context);
        break;
      case contactUsActionId:
        _openCrispChat(context);
        break;
    }
  }
  
  /// Open the Crisp chat window
  void _openCrispChat(BuildContext context) {
    try {
      // Get the CrispService instance
      final crispService = CrispService();
      
      // Validate context before proceeding
      if (!context.mounted || !_isContextValid(context)) {
        return;
      }
      
      // Check if the crisp website ID is available
      final websiteId = EnvConfig.crispWebsiteId;
      if (websiteId == null || websiteId.isEmpty) {
        debugPrint('Error: Crisp Website ID is missing in .env file');
        _showSnackBarSafely(
          context,
          'Support chat is currently unavailable',
          Colors.red,
        );
        return;
      }
      
      // Track contact us action in Mixpanel
      MixpanelService.trackEvent('Quick_Action_Contact_Us');
      
      // Initialize Crisp first
      crispService.initialize();
      
      debugPrint('Opening Crisp chat directly from quick action');
      
      // Ensure the context is still valid before opening chat
      if (context.mounted) {
        try {
          crispService.openChat(context);
        } catch (chatError) {
          debugPrint('Error directly opening Crisp chat: $chatError');
            
          // Try with a small delay as fallback
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              try {
                crispService.openChat(context);
              } catch (delayedError) {
                debugPrint('Error opening Crisp chat after delay: $delayedError');
                _showSnackBarSafely(
                  context,
                  'Could not open support chat. Please try again.',
                  Colors.red,
                );
              }
            }
          });
        }
      }
    } catch (e) {
      if (context.mounted && _isContextValid(context)) {
        _showSnackBarSafely(
          context,
          'Could not open support chat: $e',
          Colors.red,
        );
      }
    }
  }
  
  /// Helper to validate if the context has a valid scaffold messenger
  bool _isContextValid(BuildContext context) {
    try {
      // Only check that the context is mounted and has a navigator
      final hasNavigator = Navigator.maybeOf(context) != null;
      return context.mounted && hasNavigator;
    } catch (e) {
      debugPrint('Error checking context validity: $e');
      return false;
    }
  }
  
  /// Safe way to show a snackbar that won't crash if scaffold is not available
  void _showSnackBarSafely(BuildContext context, String message, Color backgroundColor) {
    try {
      if (!context.mounted) return;
      
      final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
      if (scaffoldMessenger != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
          ),
        );
      } else {
        debugPrint('Cannot show snackbar: ScaffoldMessenger not found in context');
      }
    } catch (e) {
      debugPrint('Error showing snackbar: $e');
    }
  }
  
  // Helper method to navigate to specific onboarding screen
  void _navigateToOnboardingScreen(BuildContext context, OnboardingScreen screen) {
    // Based on the screen enum, navigate to the appropriate screen
    // This is a simplified version and might need to be expanded based on your app's routing
    Navigator.of(context).pushReplacement(
      FadePageRoute(
        child: const OnboardingPage(), // Default to onboarding page for now
        settings: const RouteSettings(name: '/onboarding'),
      ),
    );
    
    // In a real implementation, you would need to handle each specific screen case
    // and navigate to the appropriate widget with necessary parameters
  }
  
  /// Force process a pending action without context
  void forcePendingAction() {
    if (_pendingAction == null) {
      return;
    }
    
    final action = _pendingAction;
    _pendingAction = null;
    
    switch (action) {
      case contactUsActionId:
        forceOpenCrispChat();
        break;
      case dontDeleteMeActionId:
        forceHandleDontDeleteMe();
        break;
    }
  }
  
  /// Directly open Crisp chat without context
  void forceOpenCrispChat() {
    try {
      if (_lastValidContext != null && _isContextValid(_lastValidContext!)) {
        final crispService = CrispService();
        crispService.initialize();
        crispService.openChat(_lastValidContext!);
      } else {
        debugPrint('forceOpenCrispChat: No valid _lastValidContext. Action will be queued/retried.');
        _pendingAction = contactUsActionId;
      }
    } catch (e) {
      debugPrint('Error in forceOpenCrispChat: $e. Action will be queued/retried.');
      _pendingAction = contactUsActionId;
    }
  }
  
  /// Handle "Don't Delete Me" quick action - remove subscription update
  Future<void> _handleDontDeleteMe(BuildContext context) async {
    try {
      MixpanelService.trackEvent('Quick_Action_Dont_Delete_Me');
      final handler = PaywallPresentationHandler();
      handler.onPresent((paywallInfo) async {
        final name = paywallInfo.name;
        MixpanelService.trackEvent('Dont_Delete_Me_Paywall_Presented', properties: {
          'paywall_name': name ?? 'unknown',
        });
      });
      handler.onDismiss((paywallInfo, paywallResult) async {
        final resultString = paywallResult?.toString() ?? 'null';
        final name = paywallInfo.name;
        MixpanelService.trackEvent('Dont_Delete_Me_Paywall_Dismissed', properties: {
          'paywall_name': name ?? 'unknown',
          'result': resultString,
        });
      });
      handler.onError((error) {
        MixpanelService.trackEvent('Dont_Delete_Me_Paywall_Error', properties: {
          'error': error.toString(),
        });
      });

      await Superwall.shared.registerPlacement(
        'INSERT_YOUR_QUICK_ACTIONS_80OFF_PLACEMENT_ID_HERE',
        handler: handler,
        feature: () async {
          final defaultProductId = Theme.of(context).platform == TargetPlatform.iOS
              ? 'com.stoppr.app.annual80OFF'
              : 'com.stoppr.sugar.app.annual80off:annual80off';
          
          await PostPurchaseHandler.handlePostPurchase(
            context,
            defaultProductId: defaultProductId,
          );
        },
      );
    } catch (e) {
      debugPrint('Error handling DontDeleteMe action: $e');
      // Queue for retry to avoid crashes if SDK not ready yet
      _pendingAction = dontDeleteMeActionId;
    }
  }

  /// Attempt to process DontDeleteMe action without a widget context (best-effort)
  void forceHandleDontDeleteMe() {
    try {
      if (_lastValidContext != null && _isContextValid(_lastValidContext!)) {
        _handleDontDeleteMe(_lastValidContext!);
      } else {
        debugPrint('forceHandleDontDeleteMe: No valid _lastValidContext. Action will be queued/retried.');
        _pendingAction = dontDeleteMeActionId;
      }
    } catch (e) {
      debugPrint('Error in forceHandleDontDeleteMe: $e. Action will be queued/retried.');
      _pendingAction = dontDeleteMeActionId;
    }
  }

  // Add a public getter to check if the dont delete me quick action is pending
  bool get isDontDeleteMePending => _pendingAction == dontDeleteMeActionId;
  
  // Add a method to clear pending action
/// Clears the pending action only if it matches the supplied [actionId].
void clearPendingAction([String? actionId]) {
  if (actionId == null || _pendingAction == actionId) {
    _pendingAction = null;
  }
}

  // ---- Localization helpers (service-scope, no BuildContext) ----
  Future<Map<String, String>> _loadLocalizedStrings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String currentLanguageCode =
          prefs.getString('languageCode') ?? 'en';

      if (_cachedLocalizedStrings != null &&
          _cachedLanguageCode == currentLanguageCode) {
        return _cachedLocalizedStrings!;
      }

      // Try current language first
      Map<String, String>? strings;
      try {
        final jsonString = await rootBundle
            .loadString('assets/l10n/$currentLanguageCode.json');
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        strings = jsonMap
            .map((key, value) => MapEntry(key, value.toString()));
      } catch (_) {}

      // Fallback to English if needed
      if (strings == null) {
        try {
          final jsonString = await rootBundle
              .loadString('assets/l10n/en.json');
          final Map<String, dynamic> jsonMap = json.decode(jsonString);
          strings = jsonMap
              .map((key, value) => MapEntry(key, value.toString()));
        } catch (_) {
          strings = <String, String>{};
        }
      }

      _cachedLocalizedStrings = strings;
      _cachedLanguageCode = currentLanguageCode;
      return strings;
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<String> _getLocalizedString(String key, {String? fallback}) async {
    final map = await _loadLocalizedStrings();
    return map[key] ?? (fallback ?? key);
  }

  // ---- User age resolution ----
  Future<int?> _getUserAgeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? ageString = prefs.getString('user_age');
      if (ageString == null || ageString.trim().isEmpty) return null;
      final int? age = int.tryParse(ageString.trim());
      return age;
    } catch (_) {
      return null;
    }
  }
} 