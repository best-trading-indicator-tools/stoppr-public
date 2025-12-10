import 'package:shared_preferences/shared_preferences.dart';

class WelcomeManager {
  static const String _lastOpenedKey = 'last_opened_date';
  final SharedPreferences _prefs;

  WelcomeManager(this._prefs);

  // Determines whether to show the onboarding flow
  // We've kept the method name the same for now to avoid breaking existing code
  Future<bool> shouldShowWelcomeScreen() async {
    // TEMPORARY: Force onboarding to appear for testing
    return true;
    
    // Original logic (comment out for testing):
    // final String today = DateTime.now().toIso8601String().split('T')[0];
    // final String? lastOpened = _prefs.getString(_lastOpenedKey);
    
    // // Update last opened date
    // await _prefs.setString(_lastOpenedKey, today);
    
    // // Show onboarding flow if it's the first time today or no record exists
    // return lastOpened == null || lastOpened != today;
  }
} 