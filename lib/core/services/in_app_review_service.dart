import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:developer'; // Will be removed if log is no longer used
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/subscription/subscription_service.dart';

class InAppReviewService {
  static const String _sharedPrefsKeyHasRatedOrPrompted = 'has_rated_or_prompted_app';
  static const String _sharedPrefsKeyLastRequestDate = 'last_review_request_date';
  static const int _minDaysBetweenRequests = 1;
  static const String _sharedPrefsKeyHasRatedOrPromptedDaily = 'has_rated_or_prompted_app_daily';
  static const String _sharedPrefsKeyLastDailyRequestDate = 'last_review_daily_request_date';
  static const String _sharedPrefsKeyHasShownSecondArticleReviewPrompt = 'has_shown_second_article_review_prompt';
  static const int _minDaysBetweenDailyRequests = 1;
  static const String _articleReadCountKey = 'article_read_count_for_review';
  static const String _completedArticleIdsForReviewKey = 'completed_article_ids_for_review';

  // Keys for the one-time "second article opened after first completion" review prompt
  static const String _sharedPrefsKeyHasShownSecondArticleOpenedPrompt = 'has_shown_second_article_opened_prompt'; // Renamed for clarity
  static const String _completedArticleIdsForReviewTriggerKey = 'completed_article_ids_for_review_trigger'; // Renamed for clarity

  final InAppReview _inAppReview = InAppReview.instance;
  final SubscriptionService _subscriptionService = SubscriptionService();

  /// Checks if user is a paid subscriber before showing review prompts
  Future<bool> _isPaidSubscriber() async {
    try {
      return await _subscriptionService.isPaidSubscriber(null);
    } catch (e) {
      debugPrint('InAppReviewService: Error checking subscription status: $e');
      return false; // Default to not showing review if subscription check fails
    }
  }

  Future<bool> _hasRatedOrBeenPromptedRecently() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sharedPrefsKeyHasRatedOrPrompted) ?? false;
  }

  Future<void> _setHasRatedOrPrompted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sharedPrefsKeyHasRatedOrPrompted, value);
  }

  Future<DateTime?> _getLastRequestDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_sharedPrefsKeyLastRequestDate);
    return dateString != null ? DateTime.tryParse(dateString) : null;
  }

  Future<void> _setLastRequestDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sharedPrefsKeyLastRequestDate, date.toIso8601String());
  }

  Future<bool> _getHasRatedOrBeenPromptedDaily() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sharedPrefsKeyHasRatedOrPromptedDaily) ?? false;
  }

  Future<void> _setHasRatedOrPromptedDaily(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sharedPrefsKeyHasRatedOrPromptedDaily, value);
  }

  Future<DateTime?> _getLastDailyRequestDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_sharedPrefsKeyLastDailyRequestDate);
    return dateString != null ? DateTime.tryParse(dateString) : null;
  }

  Future<void> _setLastDailyRequestDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sharedPrefsKeyLastDailyRequestDate, date.toIso8601String());
  }

  Future<void> requestReviewIfAppropriate({
    required String screenName,
    bool bypassSubscriptionCheck = false,
  }) async {
    try {
      if (!bypassSubscriptionCheck) {
        // Check if user is a paid subscriber first
        final isPaid = await _isPaidSubscriber();
        if (!isPaid) {
          debugPrint('User is not a paid subscriber. Skipping review request from $screenName.');
          return;
        }
      }

      final hasRatedOrPrompted = await _hasRatedOrBeenPromptedRecently();
      final lastRequestDate = await _getLastRequestDate();
      final now = DateTime.now();

      if (hasRatedOrPrompted && lastRequestDate != null && now.difference(lastRequestDate).inDays < _minDaysBetweenRequests) {
        debugPrint('User has already rated or been prompted today. Skipping review request from $screenName.');
        return;
      }
      
      if (lastRequestDate != null && now.difference(lastRequestDate).inDays >= _minDaysBetweenRequests) {
        await _setHasRatedOrPrompted(false); 
        debugPrint('Resetting prompted flag for review, last prompt was >= $_minDaysBetweenRequests day(s) ago.');
      }

      final freshHasRatedOrPrompted = await _hasRatedOrBeenPromptedRecently();
      if (freshHasRatedOrPrompted && (lastRequestDate != null && now.difference(lastRequestDate).inDays < _minDaysBetweenRequests) ) {
         debugPrint('User has already rated or been prompted today (second check). Skipping review request from $screenName.');
        return;
      }

      if (await _inAppReview.isAvailable()) {
        debugPrint('Requesting in-app review from $screenName...');
        await _inAppReview.requestReview();
        
        MixpanelService.trackEvent(
          'In-App Review Requested',
          properties: {'screen_name': screenName},
        );
        
        await _setHasRatedOrPrompted(true); 
        await _setLastRequestDate(now);
        debugPrint('In-app review requested from $screenName. Marked as prompted for today.');
      } else {
        debugPrint('In-app review is not available on this device/platform (from $screenName).');
        MixpanelService.trackEvent(
          'In-App Review Not Available',
          properties: {'screen_name': screenName},
        );
      }
    } catch (e) {
      debugPrint('Error requesting in-app review from $screenName: $e');
      MixpanelService.trackEvent(
        'In-App Review Error',
        properties: {'screen_name': screenName, 'error': e.toString()},
      );
    }
  }

  Future<void> requestReviewIfAppropriateDaily({required String screenName}) async {
    try {
      // Check if user is a paid subscriber first
      final isPaid = await _isPaidSubscriber();
      if (!isPaid) {
        debugPrint('User is not a paid subscriber. Skipping daily review request from $screenName.');
        return;
      }

      final hasRatedOrPrompted = await _getHasRatedOrBeenPromptedDaily();
      final lastRequestDate = await _getLastDailyRequestDate();
      final now = DateTime.now();

      if (hasRatedOrPrompted && lastRequestDate != null && now.difference(lastRequestDate).inDays < _minDaysBetweenDailyRequests) {
        debugPrint('User has already rated or been prompted daily. Skipping review request from $screenName.');
        return;
      }
      
      if (lastRequestDate != null && now.difference(lastRequestDate).inDays >= _minDaysBetweenDailyRequests) {
        await _setHasRatedOrPromptedDaily(false); 
        debugPrint('Resetting daily prompted flag for review, last prompt was >= $_minDaysBetweenDailyRequests day(s) ago.');
      }

      final freshHasRatedOrPrompted = await _getHasRatedOrBeenPromptedDaily();
      if (freshHasRatedOrPrompted && (lastRequestDate != null && now.difference(lastRequestDate).inDays < _minDaysBetweenDailyRequests) ) {
         debugPrint('User has already rated or been prompted daily (second check). Skipping review request from $screenName.');
        return;
      }

      if (await _inAppReview.isAvailable()) {
        debugPrint('Requesting in-app review (Daily) from $screenName...');
        await _inAppReview.requestReview();
        
        MixpanelService.trackEvent(
          'In-App Review Requested (Daily)',
          properties: {'screen_name': screenName},
        );
        
        await _setHasRatedOrPromptedDaily(true); 
        await _setLastDailyRequestDate(now);
        debugPrint('In-app review (Daily) requested from $screenName. Marked as prompted for today.');
      } else {
        debugPrint('In-app review (Daily) is not available on this device/platform (from $screenName).');
        MixpanelService.trackEvent(
          'In-App Review Not Available (Daily)',
          properties: {'screen_name': screenName},
        );
      }
    } catch (e) {
      debugPrint('Error requesting in-app review (Daily) from $screenName: $e');
      MixpanelService.trackEvent(
        'In-App Review Error (Daily)',
        properties: {'screen_name': screenName, 'error': e.toString()},
      );
    }
  }

  Future<void> requestReviewAfterSecondArticleRead({required String screenName}) async {
    try {
      // Check if user is a paid subscriber first
      final isPaid = await _isPaidSubscriber();
      if (!isPaid) {
        debugPrint('User is not a paid subscriber. Skipping second article review request from $screenName.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final bool alreadyShown = prefs.getBool(_sharedPrefsKeyHasShownSecondArticleReviewPrompt) ?? false;

      if (alreadyShown) {
        debugPrint('Second article read review prompt already shown. Skipping. (from $screenName)');
        return;
      }

      final Set<String> completedArticleIds = (prefs.getStringList(_completedArticleIdsForReviewKey) ?? []).toSet();
      if (completedArticleIds.length < 2) {
        debugPrint('Not yet the second unique article read for review prompt. Count: ${completedArticleIds.length}. Skipping. (from $screenName)');
        return;
      }

      if (await _inAppReview.isAvailable()) {
        debugPrint('Requesting in-app review (2nd Article Read) from $screenName...');
        await _inAppReview.requestReview();
        
        MixpanelService.trackEvent(
          'In-App Review Requested (2nd Article Read)',
          properties: {'screen_name': screenName},
        );
        
        await prefs.setBool(_sharedPrefsKeyHasShownSecondArticleReviewPrompt, true);
        debugPrint('In-app review (2nd Article Read) requested from $screenName. Marked as shown for this trigger.');
      } else {
        debugPrint('In-app review (2nd Article Read) is not available on this device/platform (from $screenName).');
        MixpanelService.trackEvent(
          'In-App Review Not Available (2nd Article Read)',
          properties: {'screen_name': screenName},
        );
      }
    } catch (e) {
      debugPrint('Error requesting in-app review (2nd Article Read) from $screenName: $e');
      MixpanelService.trackEvent(
        'In-App Review Error (2nd Article Read)',
        properties: {'screen_name': screenName, 'error': e.toString()},
      );
    }
  }

  Future<void> articleMarkedComplete(String articleId) async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> completedArticleIds = (prefs.getStringList(_completedArticleIdsForReviewKey) ?? []).toSet();
    
    bool alreadyCounted = completedArticleIds.contains(articleId);
    if (!alreadyCounted) {
        completedArticleIds.add(articleId);
        await prefs.setStringList(_completedArticleIdsForReviewKey, completedArticleIds.toList());
        debugPrint('Article $articleId added to unique completed list for review trigger. Total unique: ${completedArticleIds.length}');

        if (completedArticleIds.length == 2) {
            await requestReviewAfterSecondArticleRead(screenName: 'ArticleCompletion'); 
        }
    }
  }

  Future<void> userManuallyIndicatedRating() async {
    await _setHasRatedOrPrompted(true);
    await _setLastRequestDate(DateTime.now());
    debugPrint('User manually indicated they have rated the app.');
    MixpanelService.trackEvent('User Manually Indicated Rating');
  }

  Future<void> userManuallyIndicatedRatingDaily() async {
    await _setHasRatedOrPromptedDaily(true);
    await _setLastDailyRequestDate(DateTime.now());
    debugPrint('User manually indicated they have rated the app (for daily prompt purposes).');
    MixpanelService.trackEvent('User Manually Indicated Rating (Daily)');
  }

  // Call this when an article is marked as complete
  Future<void> articleMarkedCompleteForReviewTrigger(String articleId) async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> completedArticleIds = (prefs.getStringList(_completedArticleIdsForReviewTriggerKey) ?? []).toSet();
    
    if (!completedArticleIds.contains(articleId)) {
        completedArticleIds.add(articleId);
        await prefs.setStringList(_completedArticleIdsForReviewTriggerKey, completedArticleIds.toList());
        debugPrint('Article $articleId added to unique completed list for review trigger. Total unique: ${completedArticleIds.length}');
    }
  }

  // Helper to get the set of completed articles (for the review trigger)
  Future<Set<String>> getCompletedArticleIdsForReviewTrigger() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_completedArticleIdsForReviewTriggerKey) ?? []).toSet();
  }

  // Helper to check if the specific "second article opened" prompt has been shown
  Future<bool> hasShownSecondArticleOpenedPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sharedPrefsKeyHasShownSecondArticleOpenedPrompt) ?? false;
  }
  
  // Call this from ArticleDetailScreen initState/didChangeDependencies when conditions are met
  Future<void> requestReviewOnSecondArticleOpened({required String screenName}) async {
    try {
      // Check if user is a paid subscriber first
      final isPaid = await _isPaidSubscriber();
      if (!isPaid) {
        debugPrint('User is not a paid subscriber. Skipping second article opened review request from $screenName.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      // This method assumes the calling site (ArticleDetailScreen) has already checked:
      // 1. That this prompt hasn't been shown before (using hasShownSecondArticleOpenedPrompt())
      // 2. That at least one article was completed (using getCompletedArticleIdsForReviewTrigger().isNotEmpty)
      // 3. That the current article is NEW and DIFFERENT from the completed ones.

      if (await _inAppReview.isAvailable()) {
        debugPrint('Requesting in-app review (2nd Article Opened) from $screenName...');
        await _inAppReview.requestReview();
        
        MixpanelService.trackEvent(
          'In-App Review Requested (2nd Article Opened)',
          properties: {'screen_name': screenName},
        );
        
        // Mark as shown so it doesn't show again for this trigger
        await prefs.setBool(_sharedPrefsKeyHasShownSecondArticleOpenedPrompt, true);
        debugPrint('In-App review (2nd Article Opened) requested from $screenName. Marked as shown for this trigger.');
      } else {
        debugPrint('In-App review (2nd Article Opened) is not available (from $screenName).');
        MixpanelService.trackEvent(
          'In-App Review Not Available (2nd Article Opened)',
          properties: {'screen_name': screenName},
        );
      }
    } catch (e) {
      debugPrint('Error requesting in-app review (2nd Article Opened) from $screenName: $e');
      MixpanelService.trackEvent(
        'In-App Review Error (2nd Article Opened)',
        properties: {'screen_name': screenName, 'error': e.toString()},
      );
    }
  }
} 