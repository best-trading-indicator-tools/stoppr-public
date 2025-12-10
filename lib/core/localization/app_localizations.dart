import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  // Helper method to keep the syntax concise
  // Localizations.of<AppLocalizations>(context, AppLocalizations);
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  // Static member to have a simple access to the delegate from MaterialApp
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  // NEW: Evict a specific locale's asset from the cache.
  static Future<void> evictFromCache(Locale locale) async {
    if (kDebugMode) {
      final key = 'assets/l10n/${locale.languageCode}.json';
      // FIX: evict() is synchronous and returns void, so don't await it
      rootBundle.evict(key);
      debugPrint('🔥 AppLocalizations: Evicted "$key" from asset cache.');
    }
  }
  
  // Nuclear option: clear ALL localization caches
  static void evictAllFromCache() {
    if (kDebugMode) {
      const locales = ['en', 'es', 'de', 'zh', 'ru', 'fr', 'sk', 'cs', 'pl', 'it'];
      for (final lang in locales) {
        final key = 'assets/l10n/$lang.json';
        rootBundle.evict(key);
      }
      // Also clear the cache without extensions for safety
      rootBundle.clear();
      debugPrint('🔥 AppLocalizations: Evicted ALL localization files from cache.');
    }
  }

  late Map<String, String> _localizedStrings;
  bool _isInitialized = false;

  // Force reload for debug hot reload
  Future<void> forceReload() async {
    if (kDebugMode) {
      _isInitialized = false;
      _localizedStrings.clear(); // Clear existing strings
      await load();
      debugPrint('🔥 AppLocalizations: Force reloaded strings for ${locale.languageCode}');
    }
  }

  Future<bool> load() async {
    try {
      // Load the language JSON file from the "assets/l10n" folder
      final key = 'assets/l10n/${locale.languageCode}.json';
      
      // In debug mode, force a completely fresh load
      if (kDebugMode) {
        // Clear any existing cache first
        rootBundle.evict(key);
      }
      
      String jsonString = await rootBundle.loadString(
        key,
        cache: !kDebugMode, // Cache in production, not in debug
      );
      
      // Sanitize the JSON string itself in case it contains malformed UTF-16
      jsonString = TextSanitizer.sanitizeForDisplay(jsonString);
      
      Map<String, dynamic> jsonMap = json.decode(jsonString);

      _localizedStrings = jsonMap.map((key, value) {
        // Sanitize each localized string value
        return MapEntry(key, TextSanitizer.sanitizeForDisplay(value.toString()));
      });

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error loading localization file for ${locale.languageCode}: $e');
      // Initialize with empty map as fallback
      _localizedStrings = <String, String>{};
      _isInitialized = true;
      return false;
    }
  }

  // This method will be called from every widget which needs a localized text
  String translate(String key) {
    if (!_isInitialized) {
      debugPrint('Warning: translate called before load() completed for key: $key');
      return TextSanitizer.sanitizeForDisplay(key);
    }
    // Return the translated string or the key as fallback, sanitized for display
    final rawString = _localizedStrings[key] ?? key;
    return TextSanitizer.sanitizeForDisplay(rawString);
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  // This delegate never changes (it doesn't depend on the user's locale)
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Include all of your supported language codes here
    return ['en', 'es', 'de', 'zh','ru', 'fr', 'sk', 'cs', 'pl', 'it'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // AppLocalizations class is where the JSON loading happens
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => kDebugMode; // Only reload in debug for hot reload
} 