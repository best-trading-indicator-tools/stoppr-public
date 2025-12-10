import 'package:flutter/material.dart';
import 'package:stoppr/core/utils/time_formatter.dart'; // Import the custom time formatter
import 'package:stoppr/features/community/data/models/post_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';

// Summary: Sanitize community post title/content/author to prevent malformed UTF-16 in UI.

class PostListItem extends StatelessWidget {
  final PostModel post;
  final String? currentUserId; // Needed to determine initial upvote state
  final bool isUpvotedByUser;
  final VoidCallback onTap;
  final VoidCallback onUpvote;

  const PostListItem({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.isUpvotedByUser,
    required this.onTap,
    required this.onUpvote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color cardColor = Colors.white; // White background per brand guide
    final Color primaryTextColor = const Color(0xFF1A1A1A); // Brand dark text
    final Color secondaryTextColor = const Color(0xFF666666); // Brand gray text
    final Color accentColor = const Color(0xFFed3272); // Brand pink for upvote button

    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.0), // Light gray border per brand guide
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                TextSanitizer.sanitizeForDisplay(post.title),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                  fontSize: 17, 
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              
              // Content Preview with Upvote Button
              if (post.content.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        TextSanitizer.sanitizeForDisplay(post.content),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: secondaryTextColor, // Brand gray text
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w500, // Medium weight
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        _buildUpvoteButton(accentColor, primaryTextColor),
                        const SizedBox(height: 4),
                        _buildUpvoteCount(primaryTextColor),
                      ],
                    ),
                  ],
                ),
              //const SizedBox(height: 1), // Reduced margin below content

              // Bottom Row: Author, Streak, Time
              Row(
                children: [
                  // Person icon
                  Icon(
                    Icons.person, 
                    size: 20, 
                    color: secondaryTextColor, // Use the defined secondary text color
                  ),
                  const SizedBox(width: 8),
                  
                  // Combine author name and streak into a FutureBuilder
                  FutureBuilder<int>(
                    future: _getUserStreak(post), // Pass the entire post object
                    builder: (context, snapshot) {
                      // Default streak to 0 if there's any error or null data
                      final int streak = snapshot.data ?? 0;
                      final String streakText = streak > 0 ? '$streak Day Streak' : 'New User';
                      
                      // First section: name - streak
                      return Expanded(
                        child: Row(
                          children: [
                            // Author name
                            Text(
                              TextSanitizer.sanitizeForDisplay(post.authorName), // Use denormalized author name
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'ElzaRound',
                                fontWeight: FontWeight.w500,
                                color: secondaryTextColor,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '·', // Separator
                              style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            
                            // Streak (with loading indicator if needed)
                            snapshot.connectionState == ConnectionState.waiting 
                              ? SizedBox(
                                  width: 10, 
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: secondaryTextColor,
                                  )
                                )
                              : Text(
                                  streakText,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'ElzaRound',
                                    fontWeight: FontWeight.w500,
                                    color: secondaryTextColor,
                                    fontSize: 13,
                                  ),
                                ),
                            const SizedBox(width: 4),
                            Text(
                              '·', // Separator
                              style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 4),
                            
                            // Time ago
                            Text(
                              formatRelativeTime(post.createdAt), // Use the custom formatter
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'ElzaRound',
                                fontWeight: FontWeight.w500,
                                color: secondaryTextColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpvoteButton(Color accentColor, Color primaryTextColor) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: isUpvotedByUser ? 1.0 : 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return GestureDetector(
          onTap: () {
            onUpvote();
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
        );
      },
    );
  }

  // Bottom widget to display the upvote count
  Widget _buildUpvoteCount(Color textColor) {
    return AnimatedSwitcher(
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
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'ElzaRound',
          fontWeight: FontWeight.w600,
          color: textColor, // Use passed text color
          fontSize: 16,
        ),
      ),
    );
  }

  /// Fetches the streak count for a user, either from the post document (for sample posts)
  /// or from the user's document (for regular posts)
  Future<int> _getUserStreak(PostModel post) async {
    try {
      // If this is a sample post, use the streak_days field from the post
      if (post.sample) {
        // Try to get the streak directly from the post document
        final postDoc = await FirebaseFirestore.instance
            .collection('community_posts')
            .doc(post.id)
            .get();
            
        if (postDoc.exists) {
          final postData = postDoc.data();
          if (postData != null && postData.containsKey('streak_days')) {
            final dynamic streakValue = postData['streak_days'];
            if (streakValue is int) {
              return streakValue;
            }
          }
        }
        
        // If we couldn't get the streak from the post, return 0
        return 0;
      }
      
      // For regular posts, get the streak from the user's document
      // Ensure we have a valid userId
      final String userId = post.authorId;
      if (userId.isEmpty) {
        return 0;
      }
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        return 0;
      }
      
      final userData = userDoc.data();
      if (userData == null) {
        return 0;
      }
      
      // First check 'currentStreakDays' (from UserRepository)
      if (userData.containsKey('currentStreakDays')) {
        final dynamic streakValue = userData['currentStreakDays'];
        if (streakValue is int) {
          return streakValue;
        }
      }
      
      // Fallback to 'streak' field (in case that's used elsewhere)
      if (userData.containsKey('streak')) {
        final dynamic streakValue = userData['streak'];
        if (streakValue is int) {
          return streakValue;
        }
      }
      
      // If neither field exists or they're not integers, return 0
      return 0;
    } catch (e) {
      // Log error but don't crash
      print('Error fetching user streak: $e');
      return 0;
    }
  }
} 