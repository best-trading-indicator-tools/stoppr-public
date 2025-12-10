import 'package:flutter/material.dart';
import 'package:crisp_chat/crisp_chat.dart';
import '../analytics/mixpanel_service.dart';
import '../config/env_config.dart';
import '../localization/app_localizations.dart';

/// Service for handling Crisp chat integration
class CrispService {
  // Singleton instance
  static final CrispService _instance = CrispService._internal();
  factory CrispService() => _instance;
  
  // Crisp configuration
  CrispConfig? _config;
  bool _isInitialized = false;

  // Private constructor
  CrispService._internal();
  
  /// Initialize Crisp chat configuration
  void initialize() {
    // Skip if already initialized
    if (_isInitialized && _config != null) {
      debugPrint('Crisp already initialized, skipping');
      return;
    }
    
    final websiteId = EnvConfig.crispWebsiteId;
    
    if (websiteId == null || websiteId.isEmpty) {
      debugPrint('Error: Crisp Website ID is missing in .env file');
      return;
    }
    
    try {
      _config = CrispConfig(
        websiteID: websiteId,
      );
      _isInitialized = true;
      debugPrint('Crisp config created with website ID: $websiteId');
    } catch (e) {
      debugPrint('Error configuring Crisp: $e');
    }
  }
  
  /// Set user information for the chat
  void setUserInformation({
    required String email,
    required String firstName,
    String? lastName,
    String? avatar,
  }) {
    try {
      // Update the config with user information
      _config = CrispConfig(
        websiteID: _config?.websiteID ?? EnvConfig.crispWebsiteId ?? '',
        user: User(
          email: email,
          nickName: firstName,
          avatar: avatar,
        ),
      );
      
      debugPrint('Crisp user info set successfully');
    } catch (e) {
      debugPrint('Error setting Crisp user info: $e');
    }
  }
  
  /// Reset user information (for logout)
  void resetUserInformation() {
    try {
      FlutterCrispChat.resetCrispChatSession();
      debugPrint('Crisp session reset successfully');
    } catch (e) {
      debugPrint('Error resetting Crisp session: $e');
    }
  }
  
  /// Open the Crisp chat window
  void openChat(BuildContext context) {
    // Track event in Mixpanel
    MixpanelService.trackEvent('Open_Support_Chat');
    
    try {
      if (_config != null) {
        FlutterCrispChat.openCrispChat(config: _config!);
        debugPrint('Crisp chat opened successfully');
      } else {
        throw Exception('Crisp not initialized');
      }
    } catch (e) {
      debugPrint('Error opening Crisp chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.translate('errorMessage_openSupportChat').replaceFirst('{error}', e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 