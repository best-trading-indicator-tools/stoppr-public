import 'package:shared_preferences/shared_preferences.dart';

class UserAttributesService {
  const UserAttributesService();

  Future<int?> getUserAge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ageString = prefs.getString('user_age');
      if (ageString == null || ageString.trim().isEmpty) return null;
      final parsed = int.tryParse(ageString.trim());
      if (parsed == null || parsed <= 0 || parsed > 140) return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }
}


