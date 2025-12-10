import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:stoppr/features/community/data/models/chat_message_model.dart';
import 'package:stoppr/core/repositories/user_repository.dart';

class ChatRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final UserRepository _userRepository;
  final String? languageCode;

  ChatRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    UserRepository? userRepository,
    this.languageCode,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _userRepository = userRepository ?? UserRepository();

  CollectionReference get _chatCollection => _firestore.collection(
    languageCode != null ? 'official_chat_$languageCode' : 'official_chat'
  );

  // Stream of chat messages
  Stream<List<ChatMessage>> getChatMessages({int limit = 50}) {
    return _chatCollection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList();
      }

      // Get blocked user IDs
      final blockedUserIds = await getBlockedUserIds(currentUser.uid);

      // Filter out messages from blocked users
      return snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .where((message) => !blockedUserIds.contains(message.userId))
          .toList();
    });
  }

  // Send a message
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    User? user = _auth.currentUser;
    
    // Create anonymous user if none exists
    if (user == null) {
      debugPrint('No user signed in, creating anonymous user for chat');
      try {
        final userCredential = await _auth.signInAnonymously();
        user = userCredential.user;
        debugPrint('Created anonymous user: ${user?.uid}');
      } catch (e) {
        debugPrint('Error creating anonymous user: $e');
        return;
      }
    }
    
    if (user == null) {
      debugPrint('Failed to create or get user');
      return;
    }

    // Get user's first name from Firestore profile, similar to community screen
    String userName = 'Anonymous';
    try {
      final userProfile = await _userRepository.getUserProfile(user.uid);
      final firstName = userProfile?['firstName'] as String?;
      
      if (firstName?.isNotEmpty == true) {
        userName = firstName!;
      } else if (user.displayName?.isNotEmpty == true) {
        // Fallback to displayName if no firstName
        userName = user.displayName!.split(' ').first;
      } else if (!user.isAnonymous && user.email?.isNotEmpty == true) {
        // Fallback to email prefix for non-anonymous users
        userName = user.email!.split('@').first;
      }
    } catch (e) {
      debugPrint('Error getting user profile for chat: $e');
      // Keep default 'Anonymous' name if profile fetch fails
    }

    final message = ChatMessage(
      id: '', // Will be set by Firestore
      text: text.trim(),
      userId: user.uid,
      userName: userName,
      createdAt: DateTime.now(),
      isAnonymous: user.isAnonymous,
    );

    try {
      await _chatCollection.add(message.toFirestore());
      debugPrint('Successfully sent message from user: $userName');
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  // Delete a message (only for the message owner)
  Future<void> deleteMessage(String messageId) async {
    try {
      await _chatCollection.doc(messageId).delete();
    } catch (e) {
      debugPrint('Error deleting message: $e');
      rethrow;
    }
  }

  // Block a user
  Future<void> blockUser(
    String currentUserId,
    String blockedUserId,
    String blockedUserName,
  ) async {
    try {
      final userRef = _firestore.collection('users').doc(currentUserId);
      final blockedUsersRef = userRef.collection('blocked_users');

      await blockedUsersRef.doc(blockedUserId).set({
        'userId': blockedUserId,
        'userName': blockedUserName,
        'blockedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Successfully blocked user $blockedUserId');
    } catch (e) {
      debugPrint('Error blocking user: $e');
      rethrow;
    }
  }

  // Get blocked user IDs
  Future<List<String>> getBlockedUserIds(String currentUserId) async {
    try {
      final userRef = _firestore.collection('users').doc(currentUserId);
      final blockedUsersSnapshot =
          await userRef.collection('blocked_users').get();

      return blockedUsersSnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('Error getting blocked users: $e');
      return [];
    }
  }

  // Get blocked users with details
  Future<List<Map<String, dynamic>>> getBlockedUsers(
    String currentUserId,
  ) async {
    try {
      final userRef = _firestore.collection('users').doc(currentUserId);
      final blockedUsersSnapshot =
          await userRef.collection('blocked_users').get();

      return blockedUsersSnapshot.docs
          .map((doc) => {
                'userId': doc.id,
                'userName': doc.data()['userName'] as String? ?? 'Unknown',
                'blockedAt': doc.data()['blockedAt'],
              })
          .toList();
    } catch (e) {
      debugPrint('Error getting blocked users: $e');
      return [];
    }
  }

  // Unblock a user
  Future<void> unblockUser(String currentUserId, String blockedUserId) async {
    try {
      final userRef = _firestore.collection('users').doc(currentUserId);
      await userRef.collection('blocked_users').doc(blockedUserId).delete();

      debugPrint('Successfully unblocked user $blockedUserId');
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      rethrow;
    }
  }
} 