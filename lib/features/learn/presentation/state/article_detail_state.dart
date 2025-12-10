import 'package:freezed_annotation/freezed_annotation.dart';

part 'article_detail_state.freezed.dart';

@freezed
sealed class ArticleDetailState with _$ArticleDetailState {
  const factory ArticleDetailState.initial() = ArticleDetailInitial;
  const factory ArticleDetailState.loading() = ArticleDetailLoading;
  const factory ArticleDetailState.loaded({
    required String content,
    required bool isCompleted,
  }) = ArticleDetailLoaded;
  const factory ArticleDetailState.error(String message) = ArticleDetailError;

  // State specifically for when marking as complete is in progress
  const factory ArticleDetailState.markingComplete({required String content}) = ArticleDetailMarkingComplete;
} 