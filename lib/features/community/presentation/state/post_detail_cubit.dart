import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stoppr/features/community/data/models/comment_model.dart';
import 'package:stoppr/features/community/data/models/post_model.dart';
import 'package:stoppr/features/community/data/repositories/community_repository.dart';
import 'package:flutter/foundation.dart';

part 'post_detail_state.dart';
part 'post_detail_cubit.freezed.dart';

class PostDetailCubit extends Cubit<PostDetailState> {
  final CommunityRepository _communityRepository;
  final String postId;
  StreamSubscription? _postSubscription;
  StreamSubscription? _commentsSubscription;

  PostDetailCubit(this._communityRepository, this.postId) 
      : super(const PostDetailState.loading()) {
    _fetchPostDetails();
    _fetchComments();
  }

  void _fetchPostDetails() {
     // In a real app, fetch single post details if repository supports it.
     // For now, we leverage the main posts stream and filter.
     // This isn't ideal for performance if the list is huge.
     // A better approach: repository.getPostStream(postId)
     _postSubscription?.cancel();
     // Temporary workaround: Listen to all posts and find the one we need.
     // Replace this with a direct post fetch method if possible.
     _postSubscription = _communityRepository.getPostsStream().listen((posts) {
       // final post = posts.firstWhere((p) => p.id == postId, orElse: () => null);
       // Manually find the post to handle non-nullable return type safely
       PostModel? foundPost;
       for (final p in posts) {
         if (p.id == postId) {
           foundPost = p;
           break;
         }
       }
       
       if (foundPost != null) {
         // Post found, update the loaded state
         state.maybeWhen(
           loaded: (_, comments, __) => emit(PostDetailState.loaded(post: foundPost!, comments: comments, isSendingComment: false)),
           orElse: () => emit(PostDetailState.loaded(post: foundPost!, comments: [], isSendingComment: false)),
         );
       } else {
         // Post not found in the stream.
         // Only emit error if we weren't already in a loaded state.
         // If we were loaded, it means the post was deleted, and the deletion flow will handle navigation.
         if (state is! _Loaded) {
           emit(const PostDetailState.error('Post not found.'));
         } else {
           debugPrint('Post $postId disappeared from stream, likely deleted. Ignoring error emission.');
         }
       }
     }, onError: (error) {
       emit(PostDetailState.error('Failed to load post details: $error'));
     });
  }

  void _fetchComments() {
    _commentsSubscription?.cancel();
    debugPrint("Fetching comments for post $postId...");
    _commentsSubscription = _communityRepository.getCommentsStream(postId).listen(
      (comments) {
         debugPrint("Received ${comments.length} comments for post $postId from stream");
         state.maybeWhen(
           loaded: (post, _, __) {
             debugPrint("Emitting loaded state with ${comments.length} comments for post ${post.title}");
             emit(PostDetailState.loaded(post: post, comments: comments, isSendingComment: false));
           },
           // If post isn't loaded yet, we might hit initial/loading states
           orElse: () { 
             // If state is already error, don't overwrite
             if (state is! _Error) { 
                debugPrint("Post not loaded yet, waiting to show comments"); 
                // We need a post to be loaded to show comments. If post loading failed, 
                // this might result in an inconsistent state. Consider how to handle.
                // For now, if we get comments but the post isn't loaded, we wait. 
                // This could be improved by having separate states for post/comment loading.
             }
           }
         );
      },
      onError: (error) {
        // Handle comment loading error separately if needed
        debugPrint("Error loading comments for post $postId: $error");
         state.maybeWhen(
           loaded: (post, _, __) {
             debugPrint("Error fetching comments, showing post without comments");
             emit(PostDetailState.loaded(post: post, comments: [], isSendingComment: false)); // Show post, empty comments
           },
           orElse: () => emit(const PostDetailState.error('Failed to load comments.')), 
        );
      },
    );
  }

  Future<void> addComment(String text, String authorId, String authorName) async {
     final currentState = state;
     if (currentState is _Loaded) {
       emit(currentState.copyWith(isSendingComment: true));
       try {
         await _communityRepository.addComment(
           postId: postId,
           text: text,
           authorId: authorId,
           authorName: authorName,
         );
         // Stream will update the comment list, just reset sending state
         // No need to manually add comment to state
         emit(currentState.copyWith(isSendingComment: false));
       } catch (e) {
         print("Failed to add comment: $e");
         // Revert sending state and potentially show error
         emit(currentState.copyWith(isSendingComment: false));
         // Optionally emit an error state or show snackbar
       }
     }
  }
  
  Future<void> toggleUpvote(String userId) async {
     final currentState = state;
      if (currentState is _Loaded) {
       try {
         // The post stream listener in _fetchPostDetails will update the UI
         await _communityRepository.toggleUpvote(postId: postId, userId: userId);
       } catch (e) {
         print("Failed to toggle upvote: $e");
         // Handle error (e.g., snackbar)
       }
     }
  }

  Future<void> blockUser(String currentUserId, String blockedUserId, String blockedUserName) async {
    try {
      await _communityRepository.blockUser(currentUserId, blockedUserId, blockedUserName);
      // The post stream will automatically update to hide blocked user's posts
    } catch (e) {
      debugPrint('Error in cubit while blocking user: $e');
      throw Exception('Failed to block user');
    }
  }

  Future<void> unblockUser(String currentUserId, String blockedUserId) async {
    try {
      await _communityRepository.unblockUser(currentUserId, blockedUserId);
      // The post stream will automatically update to show unblocked user's posts
    } catch (e) {
      debugPrint('Error in cubit while unblocking user: $e');
      throw Exception('Failed to unblock user');
    }
  }

  /// Deletes the current post and its comments.
  /// Returns true if successful, false otherwise.
  Future<bool> deletePost() async {
    debugPrint('[PostDetailCubit] Initiating post deletion for ID: $postId');
    // Cancel streams immediately to prevent state updates during deletion
    await _postSubscription?.cancel();
    await _commentsSubscription?.cancel();
    _postSubscription = null;
    _commentsSubscription = null;
    debugPrint('[PostDetailCubit] Subscriptions cancelled.');

    try {
      // Assuming CommunityRepository has a method to delete post and comments
      await _communityRepository.deletePostAndComments(postId);
      debugPrint('[PostDetailCubit] Post deletion successful via repository for ID: $postId');
      // No need to emit a state here, the screen will handle navigation
      return true;
    } catch (e, stack) {
      debugPrint('[PostDetailCubit] Error deleting post via repository: $e');
      debugPrint('Stack trace: $stack');
      // Optionally emit an error state if navigation doesn't happen
      // emit(PostDetailState.error('Failed to delete post: $e'));
      return false;
    }
  }

  @override
  Future<void> close() {
    _postSubscription?.cancel();
    _commentsSubscription?.cancel();
    return super.close();
  }
} 