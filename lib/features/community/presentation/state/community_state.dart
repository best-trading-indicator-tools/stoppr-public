part of 'community_cubit.dart';

@freezed
sealed class CommunityState with _$CommunityState {
  const factory CommunityState.initial() = _Initial;
  const factory CommunityState.loading() = _Loading;
  const factory CommunityState.loaded({
    required List<PostModel> posts,
    required PostSortOrder currentSortOrder,
  }) = _Loaded;
  const factory CommunityState.error(String message) = _Error;
} 