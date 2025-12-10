import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Utility class for Superwall user attributes management
class SuperwallUtils {
  /// Sets Superwall user attributes for audience filtering
  static Future<void> setUserAttributes({
    String? firstName,
    String? age,
    String? gender,
    String? email,
  }) async {
    try {
      final Map<String, Object> attributes = {};
      
      // Add attributes only if they have values
      if (firstName != null && firstName.isNotEmpty) {
        attributes['name'] = firstName;
        attributes['first_name'] = firstName;
      }
      
      if (age != null && age.isNotEmpty) {
        final ageInt = int.tryParse(age);
        if (ageInt != null) {
          attributes['age'] = ageInt;
          // Add age group for easier filtering
          if (ageInt < 25) {
            attributes['age_group'] = '18_24';
          } else if (ageInt < 35) {
            attributes['age_group'] = '25_34';
          } else if (ageInt < 45) {
            attributes['age_group'] = '35_44';
          } else if (ageInt < 55) {
            attributes['age_group'] = '45_54';
          } else {
            attributes['age_group'] = '55_plus';
          }
        }
      }
      
      if (gender != null && gender.isNotEmpty) {
        attributes['gender'] = gender.toLowerCase();
      }
      
      if (email != null && email.isNotEmpty) {
        attributes['email'] = email;
      }
      
      // Add country from device locale
      try {
        final deviceLocale = Platform.localeName; // e.g., "en_US", "es_ES", "fr_FR"
        if (deviceLocale.contains('_')) {
          final countryCode = deviceLocale.split('_')[1]; // Extract "US", "ES", "FR"
          attributes['country'] = countryCode.toUpperCase();
        }
      } catch (e) {
        debugPrint('Could not determine country from locale: $e');
      }
      
      // Set the attributes if we have any
      if (attributes.isNotEmpty) {
        await Superwall.shared.setUserAttributes(attributes);
        debugPrint('✅ Superwall user attributes set: $attributes');
        
        // Superwall user attributes set successfully
      }
    } catch (e) {
      debugPrint('❌ Error setting Superwall user attributes: $e');
      if (!kDebugMode) {
        FirebaseCrashlytics.instance.recordError(
          e,
          StackTrace.current,
          reason: 'Superwall User Attributes Error',
        );
      }
    }
  }

} 