part of 'post_detail_cubit.dart';

@freezed
sealed class PostDetailState with _$PostDetailState {
  const factory PostDetailState.loading() = _Loading;
  const factory PostDetailState.loaded({
    required PostModel post,
    required List<CommentModel> comments,
    @Default(false) bool isSendingComment,
  }) = _Loaded;
  const factory PostDetailState.error(String message) = _Error;
} 