import 'dart:convert'; // For JSON encoding/decoding for SharedPreferences
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/features/learn/domain/models/article_model.dart';
import 'package:stoppr/features/learn/domain/models/user_article_progress_model.dart';
import 'package:flutter/services.dart' show rootBundle; // Import for asset loading
import 'package:flutter/foundation.dart'; // For debugPrint

class ArticleService {
  final FirebaseFirestore _firestore;
  // SharedPreferences instance will be obtained when needed

  // Key for storing user progress in SharedPreferences
  static const String _userProgressPrefsKey = 'user_articles_progress';
  // Key for storing language preference
  static const String _languageCodePrefsKey = 'languageCode';

  ArticleService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Loads article metadata from local data source instead of Firestore
  Future<List<Article>> fetchArticles() async {
    try {
      final startTime = DateTime.now();
      debugPrint('ArticleService: Starting fetchArticles()');
      
      // Load data from local predefined list instead of Firestore
      final articles = await _getLocalArticles();
      
      final totalTime = DateTime.now().difference(startTime);
      debugPrint('ArticleService: Total fetchArticles() took ${totalTime.inMilliseconds}ms');

      return articles;
    } catch (e) {
      debugPrint('Error fetching articles: $e');
      rethrow; 
    }
  }

  // Method to get current language code from SharedPreferences
  Future<String> _getCurrentLanguageCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedLangCode = prefs.getString(_languageCodePrefsKey);
      
      // If no stored language code, default to 'en'
      if (storedLangCode == null || storedLangCode.isEmpty) {
        return 'en';
      }
      
      return storedLangCode;
    } catch (e) {
      debugPrint('Error fetching language code from SharedPreferences: $e');
      return 'en'; // Default to 'en' on error
    }
  }

  /// Returns locally defined article metadata, organized by category and order
  Future<List<Article>> _getLocalArticles() async {
    final langCode = await _getCurrentLanguageCode();
    String pathPrefix = ""; // Default empty prefix
    
    // Map language codes to folder prefixes
    switch (langCode) {
      case 'en':
        pathPrefix = 'en/';
        break;
      case 'es':
        pathPrefix = 'es/';
        break;
      case 'fr':
        pathPrefix = 'fr/';
        break;
      case 'ru':
        pathPrefix = 'ru/';
        break;
      case 'sk':
        pathPrefix = 'sk/';
        break;
      case 'cs':
        pathPrefix = 'cs/';
        break;
      default:
        // Default to English for any unknown language codes
        pathPrefix = 'en/';
        break;
    }
    
    String key(String id) => 'article_${id}_title';

    return [
      // Addiction and Myths category
      Article(
        id: 'addiction_1',
        title: key('addiction_1'),
        category: 'addiction_myths',
        order: 1,
        contentPath: 'assets/articles/${pathPrefix}neuroscience_sugar_addiction.md',
      ),
      Article(
        id: 'addiction_2',
        title: key('addiction_2'),
        category: 'addiction_myths',
        order: 2,
        contentPath: 'assets/articles/${pathPrefix}sugar_vs_other_addictions.md',
      ),
      Article(
        id: 'addiction_3',
        title: key('addiction_3'),
        category: 'addiction_myths',
        order: 3,
        contentPath: 'assets/articles/${pathPrefix}debunking_sugar_myths.md',
      ),
      Article(
        id: 'addiction_4',
        title: key('addiction_4'),
        category: 'addiction_myths',
        order: 4,
        contentPath: 'assets/articles/${pathPrefix}psychological_emotional_effects.md',
      ),
      Article(
        id: 'addiction_5',
        title: key('addiction_5'),
        category: 'addiction_myths',
        order: 5,
        contentPath: 'assets/articles/${pathPrefix}managing_cravings_triggers.md',
      ),
      
      // Health Effects category
      Article(
        id: 'health_1',
        title: key('health_1'),
        category: 'health_effects',
        order: 1,
        contentPath: 'assets/articles/${pathPrefix}physical_health_consequences.md',
      ),
      Article(
        id: 'health_2',
        title: key('health_2'),
        category: 'health_effects',
        order: 2,
        contentPath: 'assets/articles/${pathPrefix}natural_vs_added_sugar_deep_dive.md',
      ),
      Article(
        id: 'health_3',
        title: key('health_3'),
        category: 'health_effects',
        order: 3,
        contentPath: 'assets/articles/${pathPrefix}psychological_environment_sugar.md',
      ),
      Article(
        id: 'health_4',
        title: key('health_4'),
        category: 'health_effects',
        order: 4,
        contentPath: 'assets/articles/${pathPrefix}sugar_skin_aging.md',
      ),
      Article(
        id: 'health_5',
        title: key('health_5'),
        category: 'health_effects',
        order: 5,
        contentPath: 'assets/articles/${pathPrefix}sugar_gut_health.md',
      ),
      
      // Stopping Benefits category
      Article(
        id: 'benefits_1',
        title: key('benefits_1'),
        category: 'stopping_benefits',
        order: 1,
        contentPath: 'assets/articles/${pathPrefix}reclaiming_mental_clarity.md',
      ),
      Article(
        id: 'benefits_2',
        title: key('benefits_2'),
        category: 'stopping_benefits',
        order: 2,
        contentPath: 'assets/articles/${pathPrefix}improving_sleep_quality.md',
      ),
      Article(
        id: 'benefits_3',
        title: key('benefits_3'),
        category: 'stopping_benefits',
        order: 3,
        contentPath: 'assets/articles/${pathPrefix}impact_overall_wellbeing.md',
      ),
      Article(
        id: 'benefits_4',
        title: key('benefits_4'),
        category: 'stopping_benefits',
        order: 4,
        contentPath: 'assets/articles/${pathPrefix}boosting_productivity.md',
      ),
      Article(
        id: 'benefits_5',
        title: key('benefits_5'),
        category: 'stopping_benefits',
        order: 5,
        contentPath: 'assets/articles/${pathPrefix}rediscovering_food_enjoyment.md',
      ),
      
      // Recovery Strategies category
      Article(
        id: 'strategies_1',
        title: key('strategies_1'),
        category: 'recovery_strategies',
        order: 1,
        contentPath: 'assets/articles/${pathPrefix}creating_personalized_plan.md',
      ),
      Article(
        id: 'strategies_2',
        title: key('strategies_2'),
        category: 'recovery_strategies',
        order: 2,
        contentPath: 'assets/articles/${pathPrefix}healthy_coping_mechanisms.md',
      ),
      Article(
        id: 'strategies_3',
        title: key('strategies_3'),
        category: 'recovery_strategies',
        order: 3,
        contentPath: 'assets/articles/${pathPrefix}leveraging_community_support.md',
      ),
      Article(
        id: 'strategies_4',
        title: key('strategies_4'),
        category: 'recovery_strategies',
        order: 4,
        contentPath: 'assets/articles/${pathPrefix}strengthening_relationships.md',
      ),
      Article(
        id: 'strategies_5',
        title: key('strategies_5'),
        category: 'recovery_strategies',
        order: 5,
        contentPath: 'assets/articles/${pathPrefix}embracing_mindfulness_meditation.md',
      ),
    ];
  }

  /// Fetches user progress.
  /// Loads from SharedPreferences if userId is empty (anonymous user).
  /// For authenticated users: loads from cache first (for speed), then syncs with Firestore.
  Future<UserArticleProgress> fetchUserProgress(String userId) async {
    if (userId.isEmpty) {
      // Anonymous user: Load from cache (SharedPreferences)
      debugPrint('ArticleService: Fetching progress for anonymous user from cache.');
      final cachedProgress = await loadUserProgressFromCache();
      return cachedProgress ?? const UserArticleProgress(); // Return default if cache empty
    } else {
      // Authenticated user: Load from cache FIRST for immediate display
      debugPrint('ArticleService: Fetching progress for user $userId.');
      
      // STEP 1: Load from cache immediately (for speed and offline support)
      UserArticleProgress cachedProgress = await loadUserProgressFromCache() ?? const UserArticleProgress();
      debugPrint('ArticleService: Loaded ${cachedProgress.completedArticles.length} completed articles from cache.');
      
      // STEP 2: Try to sync with Firestore in the background
      try {
        debugPrint('ArticleService: Attempting to sync with Firestore...');
        final docRef = _firestore.collection('users').doc(userId).collection('progress').doc('articles');
        final snapshot = await docRef.get();

        if (snapshot.exists) {
          final firestoreProgress = UserArticleProgress.fromFirestore(snapshot);
          
          // Merge cache and Firestore data (in case user completed articles offline)
          final Map<String, DateTime> mergedCompleted = Map.from(cachedProgress.completedArticles);
          
          // Add all Firestore progress
          firestoreProgress.completedArticles.forEach((articleId, completionTime) {
            // Keep the earliest completion time if article exists in both
            if (!mergedCompleted.containsKey(articleId) || 
                mergedCompleted[articleId]!.isAfter(completionTime)) {
              mergedCompleted[articleId] = completionTime;
            }
          });
          
          final mergedProgress = UserArticleProgress(completedArticles: mergedCompleted);
          
          // Update cache with merged data
          await saveUserProgressToCache(mergedProgress);
          debugPrint('ArticleService: Synced with Firestore - ${mergedProgress.completedArticles.length} total completed articles.');
          
          return mergedProgress;
        } else {
          // No Firestore document exists yet, use cached data
          debugPrint('ArticleService: No Firestore document found, using cached progress.');
          return cachedProgress;
        }
      } catch (e) {
        // Firestore sync failed (likely offline) - use cached data
        debugPrint('Warning: Could not sync with Firestore (likely offline): $e');
        debugPrint('ArticleService: Using cached progress with ${cachedProgress.completedArticles.length} completed articles.');
        return cachedProgress; // Return cached data as fallback
      }
    }
  }

  /// Loads user progress from SharedPreferences cache.
  /// Returns null if no cached data is found or on error.
  Future<UserArticleProgress?> loadUserProgressFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? progressJson = prefs.getString(_userProgressPrefsKey);
      if (progressJson != null) {
        debugPrint('ArticleService: Loaded progress from SharedPreferences cache.');
        return UserArticleProgress.fromJson(jsonDecode(progressJson));
      } else {
        debugPrint('ArticleService: No progress found in SharedPreferences cache.');
      }
    } catch (e) {
      debugPrint('Error loading user progress from cache: $e');
    }
    return null;
  }

  /// Saves user progress to SharedPreferences cache.
  Future<void> saveUserProgressToCache(UserArticleProgress progress) async {
     try {
       final prefs = await SharedPreferences.getInstance();
       final String progressJson = jsonEncode(progress.toJsonForPrefs());
       await prefs.setString(_userProgressPrefsKey, progressJson);
       debugPrint('ArticleService: Saved progress to SharedPreferences cache.');
     } catch (e) {
       debugPrint('Error saving user progress to cache: $e');
     }
  }

  /// Updates progress when an article is completed.
  /// Saves to SharedPreferences for anonymous users (empty userId).
  /// Saves to Firestore and updates cache for authenticated users.
  Future<void> markArticleAsComplete(String userId, String articleId) async {
    if (articleId.isEmpty) {
      debugPrint('Error: articleId is empty in markArticleAsComplete');
      throw ArgumentError('Article ID cannot be empty.');
    }

    final completionTime = DateTime.now(); // Use DateTime for both

    if (userId.isEmpty) {
      // --- Anonymous User: Update SharedPreferences ---
      debugPrint('ArticleService: Marking article $articleId complete for anonymous user in cache.');
      try {
        UserArticleProgress currentProgress = await loadUserProgressFromCache() ?? const UserArticleProgress();

        // Check if already completed
        if (currentProgress.isCompleted(articleId)) {
           debugPrint('Article $articleId already marked complete in cache.');
           return; 
        }

        // Create the updated progress map
        final Map<String, DateTime> updatedCompleted = Map.from(currentProgress.completedArticles);
        updatedCompleted[articleId] = completionTime; // Store DateTime
        
        final newProgress = UserArticleProgress(completedArticles: updatedCompleted);

        // Save updated progress back to cache
        await saveUserProgressToCache(newProgress);
        debugPrint('ArticleService: Successfully marked article $articleId as complete in cache.');

      } catch (e) {
        debugPrint('Error marking article $articleId as complete in cache: $e');
        rethrow; // Rethrow so the Cubit can handle it
      }

    } else {
      // --- Authenticated User: Update SharedPreferences FIRST, then Firestore ---
      debugPrint('ArticleService: Marking article $articleId complete for user $userId.');
      
      try {
        // STEP 1: Load current progress from cache (for offline support)
        UserArticleProgress currentProgress = await loadUserProgressFromCache() ?? const UserArticleProgress();
        
        // Check if already completed
        if (currentProgress.isCompleted(articleId)) {
          debugPrint('Article $articleId already marked complete in cache.');
          return;
        }
        
        // Create the updated progress map
        final Map<String, DateTime> updatedCompleted = Map.from(currentProgress.completedArticles);
        updatedCompleted[articleId] = completionTime;
        
        final newProgress = UserArticleProgress(completedArticles: updatedCompleted);
        
        // STEP 2: ALWAYS save to SharedPreferences FIRST (ensures offline support)
        await saveUserProgressToCache(newProgress);
        debugPrint('ArticleService: Saved article completion to cache for offline support.');
        
        // STEP 3: Attempt to sync with Firestore (but don't fail if offline)
        try {
          debugPrint('ArticleService: Attempting to sync with Firestore...');
          final docRef = _firestore.collection('users').doc(userId).collection('progress').doc('articles');
          
          // Use a transaction to safely update Firestore
          await _firestore.runTransaction((transaction) async {
            final snapshot = await transaction.get(docRef);
            UserArticleProgress firestoreProgress;
            
            if (snapshot.exists) {
              firestoreProgress = UserArticleProgress.fromFirestore(snapshot);
            } else {
              firestoreProgress = const UserArticleProgress();
            }
            
            // Merge local progress with Firestore progress (in case of conflicts)
            final Map<String, DateTime> mergedCompleted = Map.from(firestoreProgress.completedArticles);
            
            // Add all local progress (this preserves any offline completions)
            updatedCompleted.forEach((articleId, completionTime) {
              // Keep the earliest completion time if article exists in both
              if (!mergedCompleted.containsKey(articleId) || 
                  mergedCompleted[articleId]!.isAfter(completionTime)) {
                mergedCompleted[articleId] = completionTime;
              }
            });
            
            final mergedProgress = UserArticleProgress(completedArticles: mergedCompleted);
            
            // Update Firestore with merged progress
            transaction.set(docRef, mergedProgress.toJson());
          });
          
          debugPrint('Successfully synced article progress to Firestore for user $userId.');
          
        } catch (firestoreError) {
          // Firestore sync failed (likely offline) - but that's OK!
          // Progress is already saved locally in SharedPreferences
          debugPrint('Warning: Could not sync to Firestore (likely offline): $firestoreError');
          debugPrint('Article progress is saved locally and will sync when online.');
          // Do NOT rethrow - we want the operation to succeed even offline
        }
        
      } catch (e) {
        debugPrint('Error marking article $articleId as complete: $e');
        rethrow; // Only rethrow if the local save failed
      }
    }
  }

  /// Loads article content from the specified asset file path.
  Future<String> loadArticleContent(String contentPath) async {
    if (contentPath.isEmpty) {
       debugPrint('Error: contentPath is empty in loadArticleContent');
       return 'Error: Article content path is missing.';
    }
    try {
      // Load the string from the asset bundle
      final String markdownContent = await rootBundle.loadString(contentPath);
      return markdownContent;
    } catch (e) {
      debugPrint('Error loading article content from $contentPath: $e');
      // Return an error message or rethrow
      return 'Error: Could not load article content.'; 
    }
  }

} 