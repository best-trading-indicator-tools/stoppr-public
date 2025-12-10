part of 'learn_video_cubit.dart';

@freezed
class LearnVideoState with _$LearnVideoState {
  const factory LearnVideoState.initial() = _Initial;
  const factory LearnVideoState.loading() = _Loading;
  const factory LearnVideoState.loaded({
    required List<LearnVideoLesson> lessons,
    @Default(false) bool showComingSoonMessage,
    String? error,
  }) = _Loaded;
  const factory LearnVideoState.error(String message) = _Error;
} 