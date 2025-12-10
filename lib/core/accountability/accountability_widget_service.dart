// Syncs accountability partner data to iOS/Android home widgets
// Updates widget with current user and partner streak information

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:stoppr/features/accountability/data/repositories/accountability_repository.dart';
import 'package:stoppr/core/streak/streak_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountabilityWidgetService {
  static final AccountabilityWidgetService instance = AccountabilityWidgetService._();
  AccountabilityWidgetService._();

  final AccountabilityRepository _repository = AccountabilityRepository();
  final StreakService _streakService = StreakService();

  /// Update accountability widget with current data
  Future<void> updateWidget() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // DEBUG MODE: Create fake partner for testing
      if (kDebugMode) {
        debugPrint('🧪 DEBUG MODE: Using fake accountability partner for widget testing');
        await _updateWidgetWithFakeData();
        return;
      }

      // Get partner data
      final partner = await _repository.getMyPartnerData();
      
      // Only update widget if user has an active partner
      if (partner == null || partner.status != 'paired' || partner.partnerId == null) {
        debugPrint('No active partner - widget will not show');
        await _clearWidgetData();
        return;
      }

      // Get current user's streak
      final myStreakData = _streakService.currentStreak;
      final myDays = myStreakData.startTime != null 
          ? DateTime.now().difference(myStreakData.startTime!).inDays 
          : 0;
      final myPercentage = (myDays / 90 * 100).round();

      // Get partner's streak
      final partnerDays = partner.partnerStreak;
      final partnerPercentage = (partnerDays / 90 * 100).round();

      // Get user's first name
      final prefs = await SharedPreferences.getInstance();
      final myName = prefs.getString('user_first_name') ?? 'Me';
      final partnerName = partner.partnerFirstName ?? 'Partner';

      // Get localized strings
      final localizedTitle = prefs.getString('widget_accountability_title') ?? 'Recovery';
      final localizedDaysSuffix = prefs.getString('widget_days_suffix') ?? 'Days';

      // Save data to widget shared preferences
      await HomeWidget.saveWidgetData<String>('accountability_my_name', myName);
      await HomeWidget.saveWidgetData<int>('accountability_my_days', myDays);
      await HomeWidget.saveWidgetData<int>('accountability_my_percentage', myPercentage);
      
      await HomeWidget.saveWidgetData<String>('accountability_partner_name', partnerName);
      await HomeWidget.saveWidgetData<int>('accountability_partner_days', partnerDays);
      await HomeWidget.saveWidgetData<int>('accountability_partner_percentage', partnerPercentage);
      
      await HomeWidget.saveWidgetData<String>('accountability_localized_title', localizedTitle);
      await HomeWidget.saveWidgetData<String>('accountability_localized_days_suffix', localizedDaysSuffix);
      
      await HomeWidget.saveWidgetData<bool>('accountability_has_partner', true);

      // Update the widget
      await HomeWidget.updateWidget(
        name: 'AccountabilityWidget',
        iOSName: 'AccountabilityWidget',
        androidName: 'AccountabilityWidgetProvider',
      );

      debugPrint('Accountability widget updated: $myName ($myDays days) vs $partnerName ($partnerDays days)');
    } catch (e) {
      debugPrint('Error updating accountability widget: $e');
    }
  }

  /// Clear widget data when no partner
  Future<void> _clearWidgetData() async {
    try {
      await HomeWidget.saveWidgetData<bool>('accountability_has_partner', false);
      await HomeWidget.updateWidget(
        name: 'AccountabilityWidget',
        iOSName: 'AccountabilityWidget',
        androidName: 'AccountabilityWidgetProvider',
      );
    } catch (e) {
      debugPrint('Error clearing accountability widget: $e');
    }
  }

  /// DEBUG ONLY: Update widget with fake partner data for testing
  Future<void> _updateWidgetWithFakeData() async {
    try {
      // Get current user's real streak
      final myStreakData = _streakService.currentStreak;
      final myDays = myStreakData.startTime != null 
          ? DateTime.now().difference(myStreakData.startTime!).inDays 
          : 0;
      final myPercentage = (myDays / 90 * 100).round();

      // Get user's first name
      final prefs = await SharedPreferences.getInstance();
      final myName = prefs.getString('user_first_name') ?? 'Me';

      // Create fake partner data
      final fakePartnerName = 'Alex'; // Test partner name
      final fakePartnerDays = 12; // Test partner streak
      final fakePartnerPercentage = (fakePartnerDays / 90 * 100).round();

      // Get localized strings
      final localizedTitle = prefs.getString('widget_accountability_title') ?? 'Recovery';
      final localizedDaysSuffix = prefs.getString('widget_days_suffix') ?? 'Days';

      // Save data to widget shared preferences
      await HomeWidget.saveWidgetData<String>('accountability_my_name', myName);
      await HomeWidget.saveWidgetData<int>('accountability_my_days', myDays);
      await HomeWidget.saveWidgetData<int>('accountability_my_percentage', myPercentage);
      
      await HomeWidget.saveWidgetData<String>('accountability_partner_name', fakePartnerName);
      await HomeWidget.saveWidgetData<int>('accountability_partner_days', fakePartnerDays);
      await HomeWidget.saveWidgetData<int>('accountability_partner_percentage', fakePartnerPercentage);
      
      await HomeWidget.saveWidgetData<String>('accountability_localized_title', localizedTitle);
      await HomeWidget.saveWidgetData<String>('accountability_localized_days_suffix', localizedDaysSuffix);
      
      await HomeWidget.saveWidgetData<bool>('accountability_has_partner', true);

      // Update the widget
      await HomeWidget.updateWidget(
        name: 'AccountabilityWidget',
        iOSName: 'AccountabilityWidget',
        androidName: 'AccountabilityWidgetProvider',
      );

      debugPrint('🧪 DEBUG: Fake accountability widget updated: $myName ($myDays days) vs $fakePartnerName ($fakePartnerDays days)');
    } catch (e) {
      debugPrint('Error updating fake accountability widget: $e');
    }
  }
}

