import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stoppr/core/services/in_app_review_service.dart';
import 'package:stoppr/features/learn/data/services/article_service.dart';
import 'package:stoppr/features/learn/domain/models/article_model.dart';
import 'package:stoppr/features/learn/domain/models/user_article_progress_model.dart';
import 'article_detail_state.dart';

class ArticleDetailCubit extends Cubit<ArticleDetailState> {
  final ArticleService _articleService;
  final InAppReviewService _reviewService;
  final Article article;
  final UserArticleProgress initialProgress; // Pass initial progress
  final String userId; 

  // Callback to notify the list screen to refresh
  final Function()? onCompleteCallback; 

  ArticleDetailCubit({
    required ArticleService articleService,
    required InAppReviewService reviewService,
    required this.article,
    required this.initialProgress,
    required this.userId,
    this.onCompleteCallback,
  })  : _articleService = articleService,
        _reviewService = reviewService,
        super(const ArticleDetailState.initial()) {
          _loadContent(); // Load content immediately on creation
        }

  Future<void> _loadContent() async {
    emit(const ArticleDetailState.loading());
    try {
      if (article.contentPath == null || article.contentPath!.isEmpty) {
        emit(const ArticleDetailState.error('Article content path is missing.'));
        return;
      }
      final content = await _articleService.loadArticleContent(article.contentPath!);
      final isCompleted = initialProgress.isCompleted(article.id);
      emit(ArticleDetailState.loaded(content: content, isCompleted: isCompleted));
    } catch (e) {
      emit(ArticleDetailState.error('Failed to load article content: ${e.toString()}'));
    }
  }

  Future<void> markAsComplete() async {
     final stateBeforeMarking = state; // Capture state at the beginning of the method

     // Prevent marking again if already processing or completed
     if (stateBeforeMarking is ArticleDetailMarkingComplete || 
         (stateBeforeMarking is ArticleDetailLoaded && stateBeforeMarking.isCompleted)) {
       print('ArticleDetailCubit: Already marking complete or is completed.');
       return;
     }

     String contentForMarkingState = '';
     if (stateBeforeMarking is ArticleDetailLoaded) {
       contentForMarkingState = stateBeforeMarking.content;
     } else {
        // This situation implies the "Mark as Complete" button was shown
        // when the state wasn't ArticleDetailLoaded, which would be a UI bug.
        print('Warning: markAsComplete initiated when state was not ArticleDetailLoaded. Content for UI during marking might be missing or empty.');
        // If this happens, contentForMarkingState will be empty. The UI will need to handle empty content if this path is ever hit.
     }

     emit(ArticleDetailState.markingComplete(content: contentForMarkingState));

     try {
        // Call the service method - it now handles both anonymous and logged-in
        await _articleService.markArticleAsComplete(userId, article.id);
        
        // Call InAppReviewService to log completion for the review trigger
        await _reviewService.articleMarkedCompleteForReviewTrigger(article.id);
        
        // Update state to reflect completion, using the same content
        emit(ArticleDetailState.loaded(content: contentForMarkingState, isCompleted: true));

        // Trigger the callback to refresh the list screen
        onCompleteCallback?.call();

     } catch (e) {
       print('ArticleDetailCubit: Error marking article as complete: $e');
       // Revert to the state that existed before we tried to mark as complete,
       // or show a specific error state.
       if (stateBeforeMarking is ArticleDetailLoaded) {
         // Re-emit the previous loaded state (which had isCompleted: false)
         emit(stateBeforeMarking); 
       } else {
         // If previous state wasn't loaded (e.g., error, initial, loading),
         // which shouldn't happen if UI is correct, then go to a general error state.
         // Pass the original error message for clarity.
         emit(ArticleDetailState.error('Failed to mark as complete: ${e.toString()}'));
       }
     }
  }
} 