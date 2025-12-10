import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stoppr/features/community/data/models/post_model.dart';
import 'package:stoppr/features/community/data/repositories/community_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'community_state.dart';
part 'community_cubit.freezed.dart';

class CommunityCubit extends Cubit<CommunityState> {
  final CommunityRepository _communityRepository;
  StreamSubscription? _postsSubscription;
  StreamSubscription? _notificationSubscription;
  bool _hasNewMessages = false;

  // Getter for unread notifications state
  bool get hasNewMessages => _hasNewMessages;

  CommunityCubit(this._communityRepository) : super(const CommunityState.initial()) {
    // Optionally, seed data on initialization if in debug mode
    // _communityRepository.seedInitialPosts(); 
    // Uncomment above line temporarily during development if needed to seed posts
    _fetchPosts();
    _checkForNewMessages();
    _listenForNotifications();
  }

  // Listen for notification events from repository
  void _listenForNotifications() {
    _notificationSubscription = _communityRepository.notificationStream.listen((hasNew) {
      debugPrint('CommunityCubit: Received notification event: $hasNew');
      if (hasNew) {
        markHasNewMessages();
      }
    }, onError: (error) {
      debugPrint('CommunityCubit: Error in notification stream: $error');
    });
  }

  // Check saved notification state
  Future<void> _checkForNewMessages() async {
    final prefs = await SharedPreferences.getInstance();
    _hasNewMessages = prefs.getBool('has_new_community_messages') ?? false;
  }

  // Mark messages as read
  Future<void> markMessagesAsRead() async {
    if (_hasNewMessages) {
      _hasNewMessages = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_new_community_messages', false);
      
      // Force rebuild of UI to refresh dot status
      state.maybeWhen(
        loaded: (posts, currentSortOrder) {
          emit(CommunityState.loaded(posts: posts, currentSortOrder: currentSortOrder));
        },
        orElse: () {},
      );
    }
    
    // Update the last seen chat time unconditionally
    try {
      await _communityRepository.updateLastSeenChatTime();
    } catch (e) {
      debugPrint('Failed to update last seen chat time: $e');
    }
  }

  // Mark that there are new messages
  Future<void> markHasNewMessages() async {
    if (!_hasNewMessages) {
      _hasNewMessages = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_new_community_messages', true);
      // Force rebuild of UI to refresh dot status
      state.maybeWhen(
        loaded: (posts, currentSortOrder) {
          emit(CommunityState.loaded(posts: posts, currentSortOrder: currentSortOrder));
        },
        orElse: () {},
      );
    }
  }

  void _fetchPosts([PostSortOrder sortOrder = PostSortOrder.newest]) {
    emit(const CommunityState.loading());
    _postsSubscription?.cancel(); // Cancel previous subscription if any
    debugPrint("[Cubit] Subscribing to posts stream with sort: $sortOrder");
    _postsSubscription = _communityRepository.getPostsStream(sortOrder: sortOrder).listen(
      (posts) {
        debugPrint("[Cubit] Received ${posts.length} posts from repository stream.");
        // Log the first post if available to check data structure
        if (posts.isNotEmpty) {
          debugPrint("[Cubit] First post title: ${posts.first.title}, upvotes: ${posts.first.upvotes}");
        }
        emit(CommunityState.loaded(posts: posts, currentSortOrder: sortOrder));
      },
      onError: (error) {
        debugPrint("[Cubit] Error receiving posts from stream: $error");
        emit(CommunityState.error('Failed to load posts: $error'));
      },
      onDone: () {
        debugPrint("[Cubit] Posts stream done.");
      }
    );
  }

  void changeSortOrder(PostSortOrder newSortOrder) {
     state.maybeWhen(
      loaded: (posts, currentSortOrder) {
        if (newSortOrder != currentSortOrder) {
          _fetchPosts(newSortOrder);
        }
      },
      // If loading or error, just trigger fetch with new order
      orElse: () => _fetchPosts(newSortOrder), 
    );
  }

  Future<void> upvotePost(String postId, String userId) async {
     try {
       // Note: The stream will automatically update the UI, no need to re-emit state here
       await _communityRepository.toggleUpvote(postId: postId, userId: userId);
     } catch (e) {
       // Optionally handle error, e.g., show a snackbar
       print("Failed to upvote post: $e");
     }
  }

  /// Re-fetches posts using the current sort order
  void refreshPosts() {
    state.maybeWhen(
      loaded: (posts, currentSortOrder) {
        debugPrint("[Cubit] Refreshing posts with current sort order: $currentSortOrder");
        _fetchPosts(currentSortOrder); // Re-fetch with the existing sort order
      },
      orElse: () {
        // If state is not loaded (initial, loading, error), fetch with default (newest)
        debugPrint("[Cubit] Refresh requested but state not loaded. Fetching newest.");
        _fetchPosts(PostSortOrder.newest);
      },
    );
  }

  /// Deletes all sample posts from the database
  Future<void> deleteSamplePosts() async {
    debugPrint("CommunityCubit: Triggering deletion of sample posts");
    try {
      await _communityRepository.deleteSamplePosts();
      // Posts stream will automatically refresh with the updated data
    } catch (e) {
      debugPrint("CommunityCubit: Error deleting sample posts: $e");
    }
  }

  @override
  Future<void> close() {
    _postsSubscription?.cancel();
    _notificationSubscription?.cancel();
    return super.close();
  }
} 