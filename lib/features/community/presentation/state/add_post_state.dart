part of 'add_post_cubit.dart';

@freezed
sealed class AddPostState with _$AddPostState {
  const factory AddPostState.initial() = _Initial;
  const factory AddPostState.submitting() = _Submitting;
  const factory AddPostState.success() = _Success;
  const factory AddPostState.error(String message) = _Error;
} 