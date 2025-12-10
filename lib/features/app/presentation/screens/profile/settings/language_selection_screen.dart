import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for SystemUiOverlayStyle
import 'package:shared_preferences/shared_preferences.dart'; // For debugging stored locale
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart'; // For tracking language changes
import 'package:stoppr/main.dart'; // For MyApp.setLocale

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  Locale? _currentLocale;
  bool _isChangingLanguageManually = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Skip if we're manually changing the language to avoid race condition
    if (_isChangingLanguageManually) {
      debugPrint('🌐 Language selection screen: Skipping didChangeDependencies - manual change in progress');
      return;
    }
    
    final newLocale = Localizations.localeOf(context);
    debugPrint('🌐 Language selection screen: didChangeDependencies - Current locale: ${newLocale.languageCode}');
    if (_currentLocale == null) {
      _currentLocale = newLocale;
    } else if (_currentLocale != newLocale) {
      debugPrint('🌐 Language selection screen: Locale changed from ${_currentLocale?.languageCode} to ${newLocale.languageCode}');
      _currentLocale = newLocale;
      // Track when locale changes are detected
      MixpanelService.trackEvent('Language Selection Screen: Locale Detected', properties: {
        'detected_language': newLocale.languageCode,
        'source': 'didChangeDependencies',
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Track screen view
    MixpanelService.trackPageView('Language Selection Screen');
    
    // Debug: Check what's actually stored in SharedPreferences
    _debugCheckStoredLocale();
  }

  // Debug method to check what's stored in SharedPreferences
  Future<void> _debugCheckStoredLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedLanguageCode = prefs.getString('languageCode');
      final currentDisplayLocale = Localizations.localeOf(context);
      
      debugPrint('🔍 Language selection debug:');
      debugPrint('  - Stored in SharedPreferences: $storedLanguageCode');
      debugPrint('  - Current display locale: ${currentDisplayLocale.languageCode}');
      debugPrint('  - Widget _currentLocale: ${_currentLocale?.languageCode}');
      
      MixpanelService.trackEvent('Language Selection Screen: Debug Check', properties: {
        'stored_language': storedLanguageCode ?? 'null',
        'display_language': currentDisplayLocale.languageCode,
        'widget_language': _currentLocale?.languageCode ?? 'null',
        'languages_match': storedLanguageCode == currentDisplayLocale.languageCode,
      });
    } catch (e) {
      debugPrint('❌ Error in debug check: $e');
    }
  }

  void _changeLanguage(Locale newLocale) async {
    if (_currentLocale == null || _currentLocale != newLocale) {
      debugPrint('🌐 Language selection screen: Changing from ${_currentLocale?.languageCode ?? 'null'} to ${newLocale.languageCode}');
      
      _isChangingLanguageManually = true;
      
      try {
        // Persist immediately to reduce risk of loss on force-quit
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('languageCode', newLocale.languageCode);
        debugPrint('✅ Persisted languageCode immediately: ${newLocale.languageCode}');
        
        // Update local state immediately for UI feedback
        setState(() {
          _currentLocale = newLocale;
        });
        
        // Call the main app locale change
        MyApp.setLocale(context, newLocale);
        
        // Track the language change attempt
        MixpanelService.trackEvent('Language Selection Screen: Language Changed', properties: {
          'new_language': newLocale.languageCode,
        });
        
        debugPrint('✅ Language change completed');
        
      } catch (e) {
        debugPrint('❌ Error changing language: $e');
        if (mounted) {
          // Revert to previous locale on error - get it from Localizations
          final currentDisplayLocale = Localizations.localeOf(context);
          setState(() {
            _currentLocale = currentDisplayLocale;
          });
          MixpanelService.trackEvent('Language Selection Screen: Change Error', properties: {
            'error': e.toString(),
            'attempted_language': newLocale.languageCode,
          });
        }
      } finally {
        // Always reset the flag, even if there's an error
        _isChangingLanguageManually = false;
      }
    } else {
      debugPrint('ℹ️ Language selection: No change needed, already ${newLocale.languageCode}');
    }
  }

  Widget _buildLanguageOption(BuildContext context, String languageName, String languageCode, List<String> flags) {
    final locale = Locale(languageCode); // Generic locale for the language
    // Check if the current app locale's language code matches this option's language code.
    // This is a simplified check for the generic language (e.g., 'en' or 'es').
    final bool isSelected = _currentLocale?.languageCode == locale.languageCode;

    String displayFlags = flags.join(' '); // Join flags with a space

    final listTile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      title: Text(
        '$languageName $displayFlags', // Display language name and then flags
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
          fontFamily: 'ElzaRound',
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.white)
          : null,
      onTap: () => _changeLanguage(locale),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFed3272), // Brand pink
                  Color(0xFFfd5d32), // Brand orange
                ],
              )
            : null,
        color: isSelected ? null : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? null
            : Border.all(
                color: const Color(0xFFE0E0E0),
              ),
      ),
      child: listTile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light, // iOS: dark icons on light bg
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
          title: Text(
            l10n.translate('languageScreen_title'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildLanguageOption(context, 'English', 'en', ['🇺🇸', '🇬🇧', '🇦🇺', '🇳🇿']),
            const SizedBox(height: 12),
            _buildLanguageOption(context, 'Español', 'es', ['🇪🇸', '🇲🇽']),
            const SizedBox(height: 12),
            _buildLanguageOption(context, 'Deutsch', 'de', ['🇩🇪', '🇦🇹', '🇨🇭']),
            const SizedBox(height: 12),
            _buildLanguageOption(context, 'Русский', 'ru', ['🇷🇺']),
            const SizedBox(height: 12),
            _buildLanguageOption(context, '中文', 'zh', ['🇨🇳', '🇹🇼', '🇭🇰']),
            const SizedBox(height: 12),
            _buildLanguageOption(context, 'Français', 'fr', ['🇫🇷', '🇨🇦', '🇧🇪', '🇨🇭']),
            const SizedBox(height: 12),
            _buildLanguageOption(context, 'Slovenčina', 'sk', ['🇸🇰']),
            const SizedBox(height: 12),
            _buildLanguageOption(context, 'Čeština', 'cs', ['🇨🇿']),
            const SizedBox(height: 12),
            _buildLanguageOption(context, 'Polski', 'pl', ['🇵🇱']),
            const SizedBox(height: 12),
            _buildLanguageOption(context, 'Italiano', 'it', ['🇮🇹']),
          ],
        ),
      ),
    );
  }
} 