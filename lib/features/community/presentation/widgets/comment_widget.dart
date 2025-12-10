import 'package:flutter/material.dart';
import 'package:stoppr/features/community/data/models/comment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';

class CommentWidget extends StatelessWidget {
  final CommentModel comment;

  const CommentWidget({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Brand colors following style guide
    final Color commentBackgroundColor = const Color(0xFFFBFBFB); // Updated neutral background
    final Color primaryTextColor = const Color(0xFF1A1A1A); // Brand dark text
    final Color secondaryTextColor = const Color(0xFF666666); // Brand gray text
    final Color accentColor = const Color(0xFFed3272); // Brand pink

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User avatar with brand colors
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withOpacity(0.8), // Brand pink
                  const Color(0xFFfd5d32).withOpacity(0.8), // Brand orange
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          // Comment content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Username and streak info
                Row(
                  children: [
                    Text(
                      TextSanitizer.sanitizeForDisplay(comment.authorName),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                        color: primaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '·',
                      style: TextStyle(color: secondaryTextColor, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    // Streak info
                    FutureBuilder<int>(
                      future: _getUserStreak(comment.authorId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox(
                            width: 10, 
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Color(0xFF666666),
                            ),
                          );
                        }
                        
                        final int streak = snapshot.data ?? 0;
                        return Text(
                          streak > 0 ? '$streak Day Streak' : 'New User',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                            fontSize: 13,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Comment text in container with brand styling
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.white, // White comment bubbles for contrast
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: accentColor.withOpacity(0.1), // Subtle brand pink border
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.08), // Soft brand pink shadow
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    TextSanitizer.sanitizeForDisplay(comment.text),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w500,
                      color: primaryTextColor,
                      fontSize: 15,
                      height: 1.4, // Line spacing for readability
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        return 0;
      }
      
      final userData = userDoc.data();
      if (userData == null) {
        return 0;
      }
      
      // Fetch streak from user data
      final streak = userData['streak'] as int? ?? 0;
      return streak;
    } catch (e) {
      return 0; // Return default value on error
    }
  }
}