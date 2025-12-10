import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stoppr/core/utils/time_formatter.dart';
import 'package:stoppr/features/community/data/models/post_model.dart';
import 'package:stoppr/features/community/data/repositories/community_repository.dart';
import 'package:stoppr/features/community/presentation/state/post_detail_cubit.dart';
import 'package:stoppr/features/community/presentation/widgets/comment_widget.dart'; // Needs to be created
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // Import for SystemChrome
import 'package:stoppr/core/repositories/user_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    // Set status bar icons to dark for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
    ));
    
    return BlocProvider(
      create: (context) => PostDetailCubit(context.read<CommunityRepository>(), postId),
      child: _PostDetailView(postId: postId),
    );
  }
}

class _PostDetailView extends StatefulWidget {
  final String postId;
  const _PostDetailView({required this.postId});

  @override
  State<_PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<_PostDetailView> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final UserRepository _userRepository = UserRepository();
  String? _userFirstName;
  bool _isLoadingUserProfile = false;
  
  // Brand colors as class constants
  static const Color primaryTextColor = Color(0xFF1A1A1A);
  static const Color secondaryTextColor = Color(0xFF666666);
  static const Color accentColor = Color(0xFFed3272);

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        _isLoadingUserProfile = true;
      });
      
      try {
        // Get the user profile from Firestore
        final userProfile = await _userRepository.getUserProfile(currentUser.uid);
        
        setState(() {
          // Use firstName from profile if available
          _userFirstName = userProfile?['firstName'] as String?;
          _isLoadingUserProfile = false;
        });
        
        debugPrint("Loaded user profile with firstName: $_userFirstName");
        
        // If we have a valid first name, update all previous comments
        if (_userFirstName != null && _userFirstName!.isNotEmpty) {
          _updatePreviousComments(currentUser.uid, _userFirstName!);
        }
      } catch (e) {
        debugPrint("Error loading user profile: $e");
        setState(() {
          _isLoadingUserProfile = false;
        });
      }
    }
  }
  
  // Update all previous comments made by this user to use their first name
  Future<void> _updatePreviousComments(String userId, String firstName) async {
    try {
      debugPrint("Updating previous comments to use first name: $firstName");
      await _userRepository.updateCommunityCommentsAuthorName(userId, firstName);
      
      // Remove the SnackBar notification
    } catch (e) {
      debugPrint("Error updating previous comments: $e");
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _addComment(BuildContext context, String? currentUserId, String? currentUserDisplayName) {
    final text = _commentController.text.trim();
    if (text.isNotEmpty) {
      // Generate an anonymous ID if user is not logged in
      final String userId = currentUserId ?? 'anon_${DateTime.now().millisecondsSinceEpoch}';
      
      // Use first name from profile if available, otherwise fall back to displayName or email
      final String userName = _userFirstName?.isNotEmpty == true 
          ? _userFirstName! 
          : (currentUserDisplayName ?? 'Anonymous');
      
      debugPrint("Adding comment: '$text' by user: $userName (${currentUserId != null ? 'authenticated' : 'anonymous'})");
      context.read<PostDetailCubit>().addComment(text, userId, userName);
      _commentController.clear();
      _commentFocusNode.unfocus(); // Hide keyboard after sending
    } else if (text.isEmpty) {
      debugPrint("Comment attempt failed: Empty comment text");
      // Optional: Show message if comment is empty
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.translate('postDetail_enterComment'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primaryBackgroundColor = const Color(0xFFFBFBFB); // Slightly less pink, more neutral white
    final Color inputBackgroundColor = Colors.white; // White input background
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    // Use firstName from profile first, then fall back to Firebase Auth values
    final String? currentUserDisplayName = _userFirstName?.isNotEmpty == true
        ? _userFirstName
        : (FirebaseAuth.instance.currentUser?.displayName ?? 
           FirebaseAuth.instance.currentUser?.email ?? 
           'Anonymous');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: primaryBackgroundColor,
        appBar: AppBar(
          backgroundColor: primaryBackgroundColor,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: primaryTextColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Post',
             style: TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600, 
              fontSize: 18, // Slightly smaller than Community title
              color: primaryTextColor,
            ),
          ),
          actions: [
            BlocBuilder<PostDetailCubit, PostDetailState>(
              builder: (context, state) {
                return state.maybeWhen(
                  loaded: (post, _, __) {
                    final isPostCreator = FirebaseAuth.instance.currentUser?.uid == post.authorId;
                    final canDelete = kDebugMode || isPostCreator;
                    
                    return Row(
                      children: [
                        if (canDelete)
                          IconButton(
                            icon: Icon(Icons.more_vert, color: primaryTextColor),
                            onPressed: () {
                              _confirmDeletePost(context, post);
                            },
                          )
                        else
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: primaryTextColor),
                            color: Colors.white,
                            position: PopupMenuPosition.under,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem<String>(
                                value: 'report',
                                height: 48,
                                child: Row(
                                  children: [
                                    Icon(Icons.flag_outlined, color: primaryTextColor),
                                    const SizedBox(width: 12),
                                    Text(
                                      AppLocalizations.of(context)!.translate('reportPost_title'),
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontFamily: 'ElzaRound',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'report') {
                                _showReportDialog(context, post);
                              }
                            },
                          ),
                        _buildUpvoteButton(
                          context,
                          post,
                          currentUserId,
                          accentColor,
                          Colors.white, 
                        ),
                      ],
                    );
                  },
                  orElse: () => Container(), // Show nothing while loading/error
                );
              },
            ),
            const SizedBox(width: 8), // Padding for the button
          ],
        ),
        body: BlocBuilder<PostDetailCubit, PostDetailState>(
          builder: (context, state) {
            return state.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFed3272))),
              loaded: (post, comments, isSendingComment) {
                debugPrint("Post loaded: '${post.title}' with ${comments.length} comments");
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          _buildPostHeader(context, post),
                          const SizedBox(height: 16),
                          Text(
                            TextSanitizer.sanitizeForDisplay(post.content),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w500,
                              color: primaryTextColor,
                              fontSize: 18,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Divider(color: secondaryTextColor.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          
                          Text(
                            'Comments',
                             style: theme.textTheme.titleMedium?.copyWith(
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                             ),
                          ),
                          const SizedBox(height: 16),
                          if (comments.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              child: Center(
                                child: Text(
                                  'No comments yet.',
                                  style: TextStyle(
                                    fontFamily: 'ElzaRound',
                                    color: secondaryTextColor, 
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: comments.length,
                              itemBuilder: (context, index) {
                                final comment = comments[index];
                                return CommentWidget(comment: comment); // Needs CommentWidget
                              },
                            ),
                        ],
                      ),
                    ),
                    // Reduced spacer to push the comment input field less far down
                    // const Spacer(flex: 2), // Removed Spacer
                    // Comment input higher on the screen
                    Padding(
                      // Adjusted padding for spacing around input field
                      // Increase bottom padding to move the input field higher
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 82.0, top: 8.0),
                      child: _buildCommentInputField(
                        context, 
                        inputBackgroundColor, 
                        accentColor, 
                        isSendingComment,
                        currentUserId,
                        currentUserDisplayName,
                      ),
                    ),
                    // Small spacer to keep some distance from the bottom
                    // const Spacer(flex: 1), // Removed Spacer
                  ],
                );
              },
              error: (message) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                                        child: SelectableText.rich(
                  TextSpan(
                    text: 'Error loading post details: \n', 
                    style: TextStyle(
                      fontFamily: 'ElzaRound',
                      color: secondaryTextColor, 
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    children: <TextSpan>[
                      TextSpan(
                        text: TextSanitizer.sanitizeForDisplay(message),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          color: Colors.redAccent, 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPostHeader(BuildContext context, PostModel post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          TextSanitizer.sanitizeForDisplay(post.title),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w700,
            color: primaryTextColor,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
             Container(
               width: 24,
               height: 24,
               decoration: BoxDecoration(
                 color: const Color(0xFF666666).withOpacity(0.3),
                 shape: BoxShape.circle,
               ),
             ),
             const SizedBox(width: 8),
             Text(
               TextSanitizer.sanitizeForDisplay(post.authorName),
               style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                 fontFamily: 'ElzaRound',
                 fontWeight: FontWeight.w500,
                 color: secondaryTextColor,
                 fontSize: 14,
               ),
             ),
             const SizedBox(width: 4),
             Text(
               '·', 
               style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold),
             ),
             const SizedBox(width: 4),
             FutureBuilder<int>(
               future: _getUserStreak(post.authorId),
               builder: (context, snapshot) {
                 if (snapshot.connectionState == ConnectionState.waiting) {
                   return SizedBox(
                     width: 12, 
                     height: 12,
                     child: CircularProgressIndicator(
                       strokeWidth: 2,
                       color: secondaryTextColor,
                     )
                   );
                 }
                 
                 final int streak = snapshot.data ?? 0;
                 return Text(
                   streak > 0 ? '$streak Day Streak' : 'New User',
                   style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                     fontFamily: 'ElzaRound',
                     fontWeight: FontWeight.w500,
                     color: secondaryTextColor,
                     fontSize: 14,
                   ),
                 );
               }
             ),
             const SizedBox(width: 4),
             Text(
               '·', 
               style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold),
             ),
             const SizedBox(width: 4),
             Text(
               formatRelativeTime(post.createdAt),
               style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                 fontFamily: 'ElzaRound',
                 fontWeight: FontWeight.w500,
                 color: secondaryTextColor,
                 fontSize: 14,
               ),
             ),
          ],
        ),
      ],
    );
  }

  /// Fetches the streak count for a user from Firestore
  Future<int> _getUserStreak(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        debugPrint('User document not found for ID: $userId');
        return 0;
      }
      
      final userData = userDoc.data();
      if (userData == null) {
        return 0;
      }
      
      // Fetch streak from user data
      final streak = userData['streak'] as int? ?? 0;
      
      // Optional: Verify that streak is still valid by checking lastCheckIn date
      final lastCheckIn = userData['lastCheckIn'] as Timestamp?;
      if (lastCheckIn != null) {
        final lastCheckInDate = lastCheckIn.toDate();
        final now = DateTime.now();
        final difference = now.difference(lastCheckInDate).inDays;
        
        // If user hasn't checked in for more than a day, streak might be invalid
        // This depends on your business logic - you might have different rules
        if (difference > 1) {
          debugPrint('User $userId has outdated streak (last check-in was $difference days ago)');
          // You might want to update the streak in Firestore here or have a backend function for this
        }
      }
      
      return streak;
    } catch (e) {
      debugPrint('Error fetching user streak: $e');
      return 0; // Return default value on error
    }
  }

  Widget _buildCommentInputField(
    BuildContext context, 
    Color backgroundColor, 
    Color sendButtonColor, 
    bool isSending,
    String? currentUserId,
    String? currentUserDisplayName,
  ) {
    // Calculate bottom padding to avoid keyboard overlap
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);
    
    debugPrint("Building comment input field, keyboard padding: $bottomPadding");

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocusNode,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'ElzaRound',
                  color: const Color(0xFF1A1A1A),
                ),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.translate('postDetail_commentHint'),
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'ElzaRound',
                    color: const Color(0xFF666666),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14.0), // Adjust vertical padding
                ),
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
              ),
            ),
          ),
          IconButton(
            icon: isSending 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Icon(Icons.arrow_upward),
            onPressed: isSending ? null : () {
              debugPrint("Send comment button pressed");
              _addComment(context, currentUserId, currentUserDisplayName);
            },
            style: IconButton.styleFrom(
              backgroundColor: sendButtonColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
  
  // Re-use upvote button logic, adapted for the detail screen state
  Widget _buildUpvoteButton(
    BuildContext context, 
    PostModel post, 
    String? currentUserId, 
    Color accentColor, 
    Color primaryTextColor
  ) {
    final bool isUpvotedByUser = currentUserId != null && post.upvotedBy.contains(currentUserId);
    
    return Row(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.5),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            post.upvotes.toString(),
            key: ValueKey<int>(post.upvotes),
            style: TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
              color: primaryTextColor,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            // Generate a consistent anonymous ID if user is not logged in
            final String userId = currentUserId ?? 'anon_${DateTime.now().millisecondsSinceEpoch}';
            context.read<PostDetailCubit>().toggleUpvote(userId);
          },
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 1.0, end: isUpvotedByUser ? 1.1 : 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            builder: (context, scale, _) {
              return Transform.scale(
                scale: scale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isUpvotedByUser 
                        ? accentColor.withOpacity(0.1) 
                        : const Color(0xFFE0E0E0).withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isUpvotedByUser 
                          ? accentColor 
                          : const Color(0xFFE0E0E0),
                      width: 1,
                    )
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: Icon(
                          Icons.keyboard_arrow_up,
                          key: ValueKey<bool>(isUpvotedByUser),
                          size: 20,
                          color: isUpvotedByUser 
                              ? accentColor 
                              : const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Show delete confirmation dialog directly
  void _confirmDeletePost(BuildContext context, PostModel post) {
    // Capture the cubit here, before showing the dialog
    final cubit = context.read<PostDetailCubit>();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
          title: Text(
            AppLocalizations.of(context)!.translate('deletePost_title'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
              fontSize: 24,
            ),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Are you sure you want to delete this post?',
            style: TextStyle(
              color: Color(0xFF666666),
              fontFamily: 'ElzaRound',
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.only(bottom: 16),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFE0E0E0),
                minimumSize: const Size(100, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // Close the dialog
              },
            ),
            const SizedBox(width: 16),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFed3272),
                minimumSize: const Size(100, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'YES',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // Close the dialog
                _deletePost(context, post.id);
              },
            ),
          ],
        );
      },
    );
  }
  
  // Updated method for simplified deletion and immediate navigation
  void _deletePost(BuildContext context, String postId) async {
    // CRITICAL CHANGE: Navigate first, before any async operations
    debugPrint('[PostDetailScreen] Navigating back first with result=true');
    
    // Capture repository before navigation 
    final repository = context.read<CommunityRepository>();
    
    // Return true to trigger refresh in CommunityScreen
    Navigator.of(context).pop(true);
    
    // After navigation is complete, then perform the deletion
    try {
      debugPrint('[PostDetailScreen] Starting deletion of post $postId after navigation');
      
      // Delete the post directly using the repository
      await repository.deletePostAndComments(postId);
      
      debugPrint('[PostDetailScreen] Deletion successful after navigation');
    } catch (e) {
      debugPrint('[PostDetailScreen] Error during post deletion after navigation: $e');
      // We can't show UI errors here since we've already navigated away
    }
  }

  void _showReportDialog(BuildContext context, PostModel post) {
    final TextEditingController reportController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('reportPost_title'),
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reportController,
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                color: Color(0xFF1A1A1A),
              ),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.translate('reportPost_reasonHint'),
                hintStyle: const TextStyle(
                  fontFamily: 'ElzaRound',
                  color: Color(0xFF666666),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFed3272),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFE0E0E0),
                  minimumSize: const Size(100, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 16),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFed3272),
                  minimumSize: const Size(100, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Report',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                onPressed: () async {
                  final reportText = reportController.text.trim();
                  if (reportText.isNotEmpty) {
                    // Send email to support
                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: 'support@stoppr.app',
                      query: encodeQueryParameters({
                        'subject': 'Post Report: ${post.id}',
                        'body': 'Post ID: ${post.id}\nAuthor: ${post.authorName}\nReport reason: $reportText',
                      }),
                    );
                    
                    Navigator.pop(context); // Close dialog
                    
                    try {
                      await launchUrl(emailLaunchUri);
                    } catch (e) {
                      debugPrint('Error launching email: $e');
                    }
                    
                    // Show success notification
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.black),
                              SizedBox(width: 12),
                              Text(
                                'Post has been reported.',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontFamily: 'ElzaRound',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.white,
                          behavior: SnackBarBehavior.floating,
                          margin: EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
} 