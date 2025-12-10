import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart'; // For groupBy
import 'package:stoppr/features/learn/data/services/article_service.dart';
import 'package:stoppr/features/learn/domain/models/article_model.dart';
import 'package:stoppr/features/learn/domain/models/user_article_progress_model.dart';
import 'articles_state.dart'; // Import the state

class ArticlesCubit extends Cubit<ArticlesState> {
  final ArticleService _articleService;
  final String userId; // Assuming userId is passed in or retrieved from auth state

  ArticlesCubit({required ArticleService articleService, required this.userId}) 
      : _articleService = articleService,
        super(const ArticlesState.initial()) {
    // Automatically load articles regardless of userId presence
    loadArticles(); 
  }

  Future<void> loadArticles() async {
    emit(const ArticlesState.loading());
    print('ArticlesCubit: Starting loadArticles() for userId: "$userId"');
    final startTime = DateTime.now();

    try {
      // Fetch articles always
      final articlesFuture = _articleService.fetchArticles();

      // Fetch progress based on userId
      // Uses the updated fetchUserProgress which handles anonymous internally
      final progressFuture = _articleService.fetchUserProgress(userId);

      // Wait for fetches to complete
      print('ArticlesCubit: Waiting for futures...');
      final fetchStartTime = DateTime.now();
      // Fetch articles and progress concurrently
      final results = await Future.wait([articlesFuture, progressFuture]);
      final fetchTime = DateTime.now().difference(fetchStartTime);
      print('ArticlesCubit: Futures completed in ${fetchTime.inMilliseconds}ms');

      // Explicitly cast results for clarity
      final List<Article> articles = results[0] as List<Article>;
      final UserArticleProgress userProgress = results[1] as UserArticleProgress;

      if (articles.isEmpty) {
         print('ArticlesCubit: No articles found.');
         emit(ArticlesState.loaded(categories: [], userProgress: userProgress)); 
         return;
      }

      // Process data and calculate percentages
      print('ArticlesCubit: Building category view models...');
      final buildStartTime = DateTime.now();
      final categoriesViewModel = _buildCategoryViewModels(articles, userProgress);
      final buildTime = DateTime.now().difference(buildStartTime);
      print('ArticlesCubit: Built view models in ${buildTime.inMilliseconds}ms');

      // Emit loaded state
      final emitStartTime = DateTime.now();
      emit(ArticlesState.loaded(
        categories: categoriesViewModel,
        userProgress: userProgress, 
      ));
      final emitTime = DateTime.now().difference(emitStartTime);
      print('ArticlesCubit: Emitted state in ${emitTime.inMilliseconds}ms');

      // Caching: Only save progress to cache if a user is logged in
      // For anonymous users, SharedPreferences is the primary source via fetchUserProgress
      // if (userId.isNotEmpty) {
      //   _articleService.saveUserProgressToCache(userProgress); 
      //   print('ArticlesCubit: Saved latest progress to cache for user $userId.');
      // } 
      // Commented out: saveUserProgressToCache is now handled within the service 
      // after successful Firestore fetch/update to ensure consistency.

      final totalTime = DateTime.now().difference(startTime);
      print('ArticlesCubit: Total loadArticles() took ${totalTime.inMilliseconds}ms');

    } catch (e, stackTrace) {
      print('Error loading articles data: $e\n$stackTrace');
      emit(ArticlesState.error('Failed to load articles. Please try again. Error: ${e.toString()}'));
    }
  }

  // Helper to group articles and calculate completion
  List<ArticleCategoryViewModel> _buildCategoryViewModels(
      List<Article> allArticles, UserArticleProgress progress) 
  {
    final groupedArticles = groupBy(allArticles, (Article article) => article.category);
    final List<ArticleCategoryViewModel> viewModels = [];

    groupedArticles.forEach((categoryId, articlesInCategory) {
      if (articlesInCategory.isEmpty) return; // Skip empty categories

      // isCompleted works correctly now for both anonymous (cache) and logged-in (firestore)
      final completedCount = articlesInCategory
          .where((article) => progress.isCompleted(article.id))
          .length;
      
      final totalCount = articlesInCategory.length;
      final percentage = totalCount > 0 ? ((completedCount / totalCount) * 100).round() : 0;

      final displayProps = getCategoryDisplayProperties(categoryId);

      viewModels.add(ArticleCategoryViewModel(
        categoryId: categoryId,
        title: displayProps.$1,
        articles: articlesInCategory, // Already sorted by order from service fetch
        completionPercentage: percentage,
        color: displayProps.$2,
        icon: displayProps.$3,
      ));
    });

    // Optional: Sort categories if needed (e.g., by a predefined order)
    // viewModels.sort((a, b) => predefinedOrder[a.categoryId]!.compareTo(predefinedOrder[b.categoryId]!));

    return viewModels;
  }

  // TODO: Add method for marking article as complete (ensure userId check)
  // Future<void> markArticleComplete(String articleId) async { ... }
} 