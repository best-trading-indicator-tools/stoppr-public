import 'dart:async';
import 'dart:math'; // Added for Random

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/features/community/data/models/comment_model.dart';
import 'package:stoppr/features/community/data/models/post_model.dart';
import 'package:stoppr/features/community/data/models/chat_message_model.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:shared_preferences/shared_preferences.dart';

// Helper functions for Timestamp conversion
Timestamp _timestampToJson(DateTime date) => Timestamp.fromDate(date);
DateTime _timestampFromJson(Timestamp timestamp) => timestamp.toDate();

enum PostSortOrder {
  newest,
  mostVoted,
}

class CommunityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference<PostModel> _postsCollection;
  
  // Collection names
  static const String _postsCollectionName = 'community_posts';
  static const String _commentsSubCollectionName = 'comments';
  static const String _blockedUsersCollectionName = 'blocked_users';
  static const String _chatCollectionName = 'official_chat';

  // Stream controller for notification events
  final _notificationStreamController = StreamController<bool>.broadcast();
  Stream<bool> get notificationStream => _notificationStreamController.stream;

  // Chat message subscription
  StreamSubscription<QuerySnapshot>? _chatSubscription;
  DateTime? _lastSeenMessageTime;

  CommunityRepository() {
    _postsCollection = _firestore.collection(_postsCollectionName).withConverter<PostModel>(
      fromFirestore: (snapshot, _) => PostModel.fromFirestore(snapshot),
      toFirestore: (post, _) => {
        'title': post.title,
        'content': post.content,
        'authorId': post.authorId,
        'authorName': post.authorName,
        'createdAt': _timestampToJson(post.createdAt),
        'upvotes': post.upvotes,
        'upvotedBy': post.upvotedBy,
        'commentCount': post.commentCount,
        'sample': post.sample, // Include sample flag
      }, // Don't include 'id' field in Firestore document
    );
    
    // Initialize chat message monitoring
    _initializeChatMessageMonitoring();
  }

  // Initialize chat message monitoring
  void _initializeChatMessageMonitoring() async {
    // Get the last seen message time from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final lastSeenTimestamp = prefs.getInt('last_seen_chat_message_timestamp');
    if (lastSeenTimestamp != null) {
      _lastSeenMessageTime = DateTime.fromMillisecondsSinceEpoch(lastSeenTimestamp);
    } else {
      // Set to current time to establish baseline and prevent false notifications on first launch
      _lastSeenMessageTime = DateTime.now();
    }

    // Listen to chat messages
    _chatSubscription = _firestore
        .collection(_chatCollectionName)
        .orderBy('createdAt', descending: true)
        .limit(1) // Only listen to the most recent message
        .snapshots()
        .listen((snapshot) {
      try {
        if (snapshot.docs.isNotEmpty) {
          final latestMessage = ChatMessage.fromFirestore(snapshot.docs.first);
          final currentUser = FirebaseAuth.instance.currentUser;
          
          debugPrint('Chat monitoring: Latest message from ${latestMessage.userName} at ${latestMessage.createdAt}');
          debugPrint('Chat monitoring: Last seen time: $_lastSeenMessageTime');
          debugPrint('Chat monitoring: Current user ID: ${currentUser?.uid}, Message user ID: ${latestMessage.userId}');
          
          // Check if this is a new message (not from current user and newer than last seen)
          if (currentUser != null && 
              latestMessage.userId != currentUser.uid && 
              _lastSeenMessageTime != null &&
              latestMessage.createdAt.isAfter(_lastSeenMessageTime!)) {
            
            debugPrint('New chat message detected, triggering notification');
            _notificationStreamController.add(true);
          }
        }
      } catch (e) {
        debugPrint('Error in chat message monitoring: $e');
      }
    }, onError: (error) {
      debugPrint('Error listening to chat messages: $error');
    });
  }

  // Update last seen message time (called when user opens chat)
  Future<void> updateLastSeenChatTime() async {
    _lastSeenMessageTime = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_seen_chat_message_timestamp', _lastSeenMessageTime!.millisecondsSinceEpoch);
  }

  // --- Posts ---

  Stream<List<PostModel>> getPostsStream({PostSortOrder sortOrder = PostSortOrder.newest}) {
    Query<PostModel> query = _postsCollection;

    switch (sortOrder) {
      case PostSortOrder.newest:
        query = query.orderBy('createdAt', descending: true);
        break;
      case PostSortOrder.mostVoted:
        query = query.orderBy('upvotes', descending: true).orderBy('createdAt', descending: true);
        break;
    }

    return query.snapshots().map((snapshot) {
      debugPrint("[Repo Stream] Received snapshot with ${snapshot.docs.length} docs.");
      
      // Map each document individually with error handling
      final List<PostModel> posts = [];
      for (var doc in snapshot.docs) {
        try {
          final post = doc.data();
          posts.add(post);
        } catch (e, stack) {
          debugPrint("[Repo Stream] Error converting document ${doc.id}: $e");
          debugPrint("[Repo Stream] Stack: $stack");
          // Skip this document but continue processing others
        }
      }
      
      debugPrint("[Repo Stream] Successfully mapped ${posts.length} out of ${snapshot.docs.length} documents");
      return posts;
    }).handleError((error, stackTrace) {
      debugPrint("[Repo Stream] Error fetching posts stream: $error");
      debugPrint("[Repo Stream] Stream Error StackTrace: $stackTrace");
      return <PostModel>[];
    });
  }

  Future<void> addPost({required String title, required String content, required String authorId, required String authorName}) async {
    try {
      // Create a temporary model without an ID for Firestore to generate one
      final newPostData = PostModel(
        id: '', // Firestore will generate this
        title: title,
        content: content,
        authorId: authorId,
        authorName: authorName,
        createdAt: DateTime.now(),
        // Defaults for upvotes, upvotedBy, commentCount are handled by the model
      );
      await _postsCollection.add(newPostData);
    } catch (e) {
      debugPrint("Error adding post: $e");
      rethrow; // Rethrow to allow UI layer to handle
    }
  }

  // Check if a post belongs to the current user
  bool _isCurrentUserPost(String authorId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && currentUser.uid == authorId;
  }

  // Notify when interaction happens on current user's post
  void _checkForUserPostInteraction(String postId, String authorId) async {
    if (_isCurrentUserPost(authorId)) {
      debugPrint("Notification: Activity on current user's post");
      _notificationStreamController.add(true);
    }
  }

  Future<void> toggleUpvote({required String postId, required String userId}) async {
    final postRef = _postsCollection.doc(postId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      if (!snapshot.exists) {
        throw Exception("Post does not exist!");
      }

      final post = snapshot.data()!;
      final currentUpvotedBy = List<String>.from(post.upvotedBy);
      int currentUpvotes = post.upvotes;

      if (currentUpvotedBy.contains(userId)) {
        // User already upvoted, so remove vote
        currentUpvotedBy.remove(userId);
        currentUpvotes--;
      } else {
        // User hasn't upvoted, so add vote
        currentUpvotedBy.add(userId);
        currentUpvotes++;
        
        // Check if this is on the current user's post and notify
        _checkForUserPostInteraction(postId, post.authorId);
      }

      transaction.update(postRef, {
        'upvotedBy': currentUpvotedBy,
        'upvotes': currentUpvotes,
      });
    }).catchError((error) {
       debugPrint("Error toggling upvote: $error");
    });
  }

  // --- Comments ---

  CollectionReference<CommentModel> _commentsCollection(String postId) {
    return _postsCollection
        .doc(postId)
        .collection(_commentsSubCollectionName)
        .withConverter<CommentModel>(
          fromFirestore: (snapshot, _) => CommentModel.fromFirestore(snapshot),
          toFirestore: (comment, _) {
            final json = comment.toJson();
            json.remove('id');
            return json.cast<String, Object?>();
          },
        );
  }

  Stream<List<CommentModel>> getCommentsStream(String postId) {
    debugPrint("Getting comments stream for post: $postId");
    return _commentsCollection(postId)
        .orderBy('createdAt', descending: false) // Show oldest comments first
        .snapshots()
        .map((snapshot) {
           debugPrint("Received ${snapshot.docs.length} comments for post $postId");
           
           final comments = snapshot.docs.map((doc) {
             try {
               return doc.data();
             } catch (e) {
               debugPrint("Error converting comment doc ${doc.id}: $e");
               throw e; // Rethrow to be caught by handleError
             }
           }).toList();
           
           debugPrint("Successfully mapped ${comments.length} comments for post $postId");
           return comments;
        })
        .handleError((error, stack) {
           debugPrint("Error fetching comments stream for post $postId: $error");
           debugPrint("Stack trace: $stack");
           return [];
        });
  }

  Future<void> addComment({
    required String postId,
    required String text,
    required String authorId,
    required String authorName,
  }) async {
    final postRef = _postsCollection.doc(postId);
    // Use raw (untyped) reference for comment writes to avoid converter/type issues
    final rawCommentsRef = _firestore
        .collection(_postsCollectionName)
        .doc(postId)
        .collection(_commentsSubCollectionName);

    try {
      // Get post data to check ownership
      final postSnapshot = await postRef.get();
      final post = postSnapshot.data();
      
      if (post != null) {
        // Check if this is on the current user's post and notify
        _checkForUserPostInteraction(postId, post.authorId);
      }

      // Create comment data as Map<String, dynamic> directly for Firestore
      final commentData = <String, dynamic>{
        'postId': postId,
        'text': text,
        'authorId': authorId,
        'authorName': authorName,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };

      // Write comment first, then update post count (separate ops for clearer errors)
      final commentDocRef = rawCommentsRef.doc();
      debugPrint("Creating comment with authorId: $authorId at ${commentDocRef.path}");
      
      try {
        await commentDocRef.set(commentData);
        debugPrint("✅ Comment created successfully!");
      } catch (e) {
        debugPrint("❌ Comment creation failed: $e");
        rethrow;
      }

      try {
        debugPrint("Incrementing commentCount on ${postRef.path}");
        await postRef.update({
          'commentCount': FieldValue.increment(1),
        });
        debugPrint("✅ Comment count updated successfully!");
      } catch (e) {
        debugPrint("❌ Comment count update failed: $e");
        rethrow;
      }
    } catch (e) {
      debugPrint("Error adding comment for post $postId: $e");
      rethrow;
    }
  }
  
   // --- Seeding (for initial setup) ---

  Future<void> seedInitialPosts() async {
    debugPrint("--- Attempting to seed initial posts ---");
    if (!kDebugMode) {
      // Only allow seeding in debug mode
      debugPrint("[Seed] Seeding only allowed in debug mode. Exiting.");
      return;
    }
    debugPrint("[Seed] Running in debug mode. Proceeding...");

    try {
      debugPrint("[Seed] Checking for existing posts...");
      final QuerySnapshot existingPosts = await _firestore.collection(_postsCollectionName).limit(1).get();
      
      if (existingPosts.docs.isNotEmpty) {
        debugPrint("[Seed] Posts collection already contains ${existingPosts.docs.length} document(s). Skipping seed.");
        return;
      }

      debugPrint("[Seed] Posts collection is empty. Preparing batch...");
      final batch = _firestore.batch();
      final initialPosts = _generateSamplePosts();
      debugPrint("[Seed] Generated ${initialPosts.length} sample posts.");
      
      final Map<String, String> postIdMap = {}; // Track postId to later add comments
      final Map<String, int> commentCountMap = {}; // Track comment counts per post

      for (final postData in initialPosts) {
        // Create the post data directly without converter
        final postRef = _firestore.collection(_postsCollectionName).doc();
        final postId = postRef.id;
        postIdMap[postData['title'] as String] = postId; // Save post ID
        
        // Random number of comments (0-5) for this post
        final commentCount = Random().nextInt(6);
        commentCountMap[postData['title'] as String] = commentCount; // Store comment count for later
        
        batch.set(postRef, {
          'title': postData['title'],
          'content': postData['content'],
          'authorId': postData['authorId'],
          'authorName': postData['authorName'],
          'createdAt': Timestamp.fromDate(DateTime.now().subtract(Duration(hours: initialPosts.indexOf(postData)))),
          'upvotes': postData['upvotes'],
          'upvotedBy': [],
          'commentCount': commentCount, // Set the correct comment count
          'sample': true, // Flag to identify sample posts
        });
      }

      debugPrint("[Seed] Committing batch...");
      await batch.commit();
      debugPrint("[Seed] Successfully committed batch and seeded ${initialPosts.length} posts.");
      
      // Now add comments for each post
      debugPrint("[Seed] Adding comments to posts...");
      for (final postData in initialPosts) {
        final postTitle = postData['title'] as String;
        final postId = postIdMap[postTitle];
        final commentCount = commentCountMap[postTitle] ?? 0;
        
        if (postId != null && commentCount > 0) {
          debugPrint("[Seed] Adding $commentCount comments to post '$postTitle'");
          final commentsBatch = _firestore.batch();
          final comments = _generateSampleComments(postId, commentCount);
          
          for (final comment in comments) {
            final commentRef = _firestore.collection(_postsCollectionName)
                .doc(postId)
                .collection(_commentsSubCollectionName)
                .doc();
                
            commentsBatch.set(commentRef, comment);
          }
          
          await commentsBatch.commit();
        }
      }
      
      debugPrint("[Seed] Successfully added comments to posts.");

    } catch (e, stackTrace) {
      debugPrint("[Seed] Error seeding initial posts: $e");
      debugPrint("[Seed] StackTrace: $stackTrace"); // Print stack trace for more detail
    }
     debugPrint("--- Finished seeding attempt ---");
  }

  List<Map<String, dynamic>> _generateSamplePosts() {
    final random = Random(); // Create Random instance
    // Simple sample data
    return [
      {'title': 'Day three - why am I quitting?', 'content': '''why am I quitting? there are too many reasons. ever since admitting i have an addiction, every day has brought new insights into just how much sugar has taken over my life...''', 'authorId': 'user_anna', 'authorName': 'Anna', 'upvotes': random.nextInt(150)},
      {'title': 'Words of Wisdom #1: Patience is Key.', 'content': '''First, I want you to remember the key strength of quitting porn, hentai, whatever it is: patience. It's not about instant results, it's about the long game.''', 'authorId': 'user_mal', 'authorName': 'Mal', 'upvotes': random.nextInt(150)},
      {'title': 'The app definitely works.', 'content': '''Having other people constantly posting and getting notifications that others are succeeding motivates me.''', 'authorId': 'user_ben', 'authorName': 'Ben', 'upvotes': random.nextInt(150)},
      {'title': 'Tempted', 'content': '''Soooo is fapping without porn a problem? Or no? Someone please help''', 'authorId': 'user_manny', 'authorName': 'Manny', 'upvotes': random.nextInt(150)},
      {'title': 'Just checking in - Day 10!', 'content': '''Feeling stronger each day. The cravings are still there sometimes, but managing them better. Reading everyone's posts helps a lot!''', 'authorId': 'user_chloe', 'authorName': 'Chloe', 'upvotes': random.nextInt(150)},
      {'title': 'Had a slip-up, but not giving up', 'content': '''Feeling disappointed but reminding myself that recovery isn't linear. Back on track starting now. Any tips for handling intense evening cravings?''', 'authorId': 'user_david', 'authorName': 'David', 'upvotes': random.nextInt(150)},
      {'title': 'What are your go-to healthy snacks?', 'content': '''Need some new ideas! Trying to replace my usual sugary treats. What works for you guys?''', 'authorId': 'user_emily', 'authorName': 'Emily', 'upvotes': random.nextInt(150)},
      {'title': 'Month 1 milestone!', 'content': '''Can't believe it's been a month already. Feeling so much clearer mentally and physically. Keep going everyone!''', 'authorId': 'user_frank', 'authorName': 'Frank', 'upvotes': random.nextInt(150)},
      {'title': 'How do you handle social situations?', 'content': '''Going to a party this weekend and worried about sugary drinks and desserts. How do you navigate these events?''', 'authorId': 'user_grace', 'authorName': 'Grace', 'upvotes': random.nextInt(150)},
      {'title': 'Finding new hobbies', 'content': '''Realized a lot of my sugar consumption was linked to boredom. Started painting and it's really helping!''', 'authorId': 'user_henry', 'authorName': 'Henry', 'upvotes': random.nextInt(150)},
      {'title': 'Energy levels are SO much better', 'content': '''Used to have that afternoon slump every day. Now my energy feels much more stable throughout the day. Anyone else notice this?''', 'authorId': 'user_isla', 'authorName': 'Isla', 'upvotes': random.nextInt(150)},
      {'title': 'Question about withdrawal', 'content': '''How long did the headaches last for others? I'm on day 4 and they're still pretty persistent.''', 'authorId': 'user_jack', 'authorName': 'Jack', 'upvotes': random.nextInt(150)},
      {'title': 'Celebrating small wins', 'content': '''Said no to a free donut at work today! It felt surprisingly good. Remember to acknowledge the small victories!''', 'authorId': 'user_katie', 'authorName': 'Katie', 'upvotes': random.nextInt(150)},
      {'title': 'Recipe Share: Healthy Brownies', 'content': '''Found an amazing recipe using dates and cocoa powder. Tastes incredible! Happy to share if anyone's interested.''', 'authorId': 'user_liam', 'authorName': 'Liam', 'upvotes': random.nextInt(150)},
      {'title': 'Support needed', 'content': '''Feeling really low today and the urge to binge is strong. Could use some encouragement.''', 'authorId': 'user_mia', 'authorName': 'Mia', 'upvotes': random.nextInt(150)},
    ];
  }

  // Helper method to generate sample comments
  List<Map<String, dynamic>> _generateSampleComments(String postId, int count) {
    final comments = <Map<String, dynamic>>[];
    final random = Random();
    final userIds = [
      'user_alex', 'user_taylor', 'user_jordan', 'user_morgan', 'user_casey',
      'user_sam', 'user_pat', 'user_robin', 'user_jamie', 'user_quinn'
    ];
    final sampleTexts = [
      'I totally agree with you!',
      'Thanks for sharing this, it helps a lot.',
      'I\'ve been through this too. It gets better!',
      'Have you tried meditation? It really helped me.',
      'Keep it up! We\'re in this together.',
      'This is exactly what I needed to hear today.',
      'I\'m wondering if anyone else has similar experiences?',
      'I find that exercise really helps with the cravings.',
      'What about trying herbal tea as a substitute?',
      'Day by day, we\'re making progress. Stay strong!',
      'This community is so supportive, thank you all.',
      'I had the same struggle last week.',
      'Your post inspired me to keep going.',
      'Any specific tips that worked for you?',
      'I appreciate your honesty.',
    ];
    
    for (int i = 0; i < count; i++) {
      final randomUserIndex = random.nextInt(userIds.length);
      final userId = userIds[randomUserIndex];
      final userName = userId.substring(5).capitalize(); // Remove 'user_' and capitalize
      
      final randomTextIndex = random.nextInt(sampleTexts.length);
      final text = sampleTexts[randomTextIndex];
      
      // Create timestamp with slight variation
      final createdAt = DateTime.now().subtract(Duration(
        hours: random.nextInt(24),
        minutes: random.nextInt(60)
      ));
      
      comments.add({
        'postId': postId,
        'text': text,
        'authorId': userId,
        'authorName': userName,
        'createdAt': Timestamp.fromDate(createdAt),
      });
    }
    
    return comments;
  }

  /// Utility method to delete all sample posts
  /// Use this to clean up sample data when needed
  Future<void> deleteSamplePosts() async {
    debugPrint("--- Attempting to delete all sample posts ---");
    
    // Only allow deleting sample posts in debug mode
    if (!kDebugMode) {
      debugPrint("[Delete] Operation only allowed in debug mode. Exiting.");
      return;
    }
    
    try {
      // Query for all posts with sample=true flag
      final QuerySnapshot samplePostsSnapshot = await _firestore
          .collection(_postsCollectionName)
          .where('sample', isEqualTo: true)
          .get();
      
      if (samplePostsSnapshot.docs.isEmpty) {
        debugPrint("No sample posts found to delete.");
        return;
      }
      
      debugPrint("Found ${samplePostsSnapshot.docs.length} sample posts to delete.");
      
      // Create a batch to perform deletion
      final WriteBatch batch = _firestore.batch();
      
      // Process each sample post
      for (final doc in samplePostsSnapshot.docs) {
        final postId = doc.id;
        
        // First delete all comments for this post
        final commentsSnapshot = await _firestore
            .collection(_postsCollectionName)
            .doc(postId)
            .collection(_commentsSubCollectionName)
            .get();
            
        debugPrint("Deleting ${commentsSnapshot.docs.length} comments for post $postId");
        
        // Add comment deletions to batch
        for (final commentDoc in commentsSnapshot.docs) {
          batch.delete(commentDoc.reference);
        }
        
        // Then delete the post itself
        batch.delete(doc.reference);
      }
      
      // Commit the batch
      await batch.commit();
      debugPrint("Successfully deleted ${samplePostsSnapshot.docs.length} sample posts and their comments.");
      
    } catch (e, stackTrace) {
      debugPrint("Error deleting sample posts: $e");
      debugPrint("Stack trace: $stackTrace");
    }
  }

  /// Deletes a specific post and all its associated comments.
  Future<void> deletePostAndComments(String postId) async {
    final postRef = _firestore.collection(_postsCollectionName).doc(postId);
    
    debugPrint('[Repository] Starting deletion for post $postId');

    try {
      // First, check if the post exists
      final postDoc = await postRef.get();
      if (!postDoc.exists) {
        debugPrint('[Repository] Post $postId does not exist. No deletion performed.');
        return; // Or throw an exception if preferred
      }

      // 1. First get all comments outside of the transaction
      final commentsRef = postRef.collection(_commentsSubCollectionName);
      final commentsSnapshot = await commentsRef.get();
      
      int commentsCount = commentsSnapshot.docs.length;
      debugPrint('[Repository] Found $commentsCount comments to delete for post $postId');
      
      // 2. Create a write batch for efficient deletion
      final batch = _firestore.batch();
      
      // Add comment deletions to batch
      for (final commentDoc in commentsSnapshot.docs) {
        batch.delete(commentDoc.reference);
      }
      
      // Add post deletion to batch
      batch.delete(postRef);
      
      // 3. Commit the batch
      await batch.commit();
      debugPrint('[Repository] Successfully deleted post and $commentsCount comments');

    } catch (e, stack) {
      debugPrint('[Repository] Error deleting post $postId: $e');
      debugPrint('[Repository] Stack trace: $stack');
      rethrow; // Rethrow the error for the cubit to catch
    }
  }

  // Properly dispose resources
  void dispose() {
    _chatSubscription?.cancel();
    _notificationStreamController.close();
  }

  // Add this method to block a user
  Future<void> blockUser(String currentUserId, String blockedUserId, String blockedUserName) async {
    try {
      final userRef = _firestore.collection('users').doc(currentUserId);
      final blockedUsersRef = userRef.collection(_blockedUsersCollectionName);

      await blockedUsersRef.doc(blockedUserId).set({
        'userId': blockedUserId,
        'userName': blockedUserName,
        'blockedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Successfully blocked user $blockedUserId');
    } catch (e) {
      debugPrint('Error blocking user: $e');
      throw Exception('Failed to block user');
    }
  }

  // Add this method to unblock a user
  Future<void> unblockUser(String currentUserId, String blockedUserId) async {
    try {
      final userRef = _firestore.collection('users').doc(currentUserId);
      final blockedUsersRef = userRef.collection(_blockedUsersCollectionName);

      await blockedUsersRef.doc(blockedUserId).delete();
      debugPrint('Successfully unblocked user $blockedUserId');
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      throw Exception('Failed to unblock user');
    }
  }

  // Add this method to check if a user is blocked
  Future<bool> isUserBlocked(String currentUserId, String targetUserId) async {
    try {
      final userRef = _firestore.collection('users').doc(currentUserId);
      final blockedUserDoc = await userRef
          .collection(_blockedUsersCollectionName)
          .doc(targetUserId)
          .get();
      
      return blockedUserDoc.exists;
    } catch (e) {
      debugPrint('Error checking blocked status: $e');
      return false;
    }
  }

  // Add this method to get all blocked users
  Future<List<String>> getBlockedUserIds(String currentUserId) async {
    try {
      final userRef = _firestore.collection('users').doc(currentUserId);
      final blockedUsersSnapshot = await userRef
          .collection(_blockedUsersCollectionName)
          .get();
      
      return blockedUsersSnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('Error getting blocked users: $e');
      return [];
    }
  }

  // Add helper method for sorting
  String _getSortField(PostSortOrder sortOrder) {
    switch (sortOrder) {
      case PostSortOrder.newest:
        return 'createdAt';
      case PostSortOrder.mostVoted:
        return 'upvotes';
    }
  }

  // Modify the existing getPosts method to filter out blocked users
  Stream<List<PostModel>> getPosts(PostSortOrder sortOrder) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    return _postsCollection
        .orderBy(_getSortField(sortOrder), descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          if (currentUser == null) {
            return snapshot.docs.map((doc) => doc.data()).toList();
          }

          // Get blocked users
          final blockedUserIds = await getBlockedUserIds(currentUser.uid);
          
          // Filter out posts from blocked users
          return snapshot.docs
              .map((doc) => doc.data())
              .where((post) => !blockedUserIds.contains(post.authorId))
              .toList();
        });
  }

  // Modify the getPost method to check if the post author is blocked
  Stream<PostModel?> getPost(String postId) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    return _postsCollection
        .doc(postId)
        .snapshots()
        .asyncMap((snapshot) async {
          if (!snapshot.exists) return null;
          
          final post = snapshot.data()!;
          
          if (currentUser != null) {
            final isBlocked = await isUserBlocked(currentUser.uid, post.authorId);
            if (isBlocked) {
              throw Exception('This post is from a blocked user');
            }
          }
          
          return post;
        });
  }
}

// Extension to capitalize first letter of a string
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
} 