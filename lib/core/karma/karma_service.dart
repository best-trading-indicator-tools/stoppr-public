import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../analytics/mixpanel_service.dart';

class KarmaService {
  // Singleton pattern
  static final KarmaService _instance = KarmaService._internal();
  
  factory KarmaService() {
    return _instance;
  }
  
  
  KarmaService._internal();
  
  // Keys for shared preferences
  static const String _karmaCountKey = 'user_karma_count';
  
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Stream controller for karma updates
  final StreamController<int> _karmaStreamController = StreamController<int>.broadcast();
  
  // Public stream for karma updates
  Stream<int> get karmaStream => _karmaStreamController.stream;
  
  // Current karma cache
  int _currentKarma = 0;
  
  /// Get current karma count
  int get currentKarma => _currentKarma;
  
  /// Initialize karma service and load current karma
  Future<void> initialize() async {
    await _loadKarma();
  }
  
  /// Load karma from SharedPreferences and sync with Firestore
  Future<void> _loadKarma() async {
    try {
      // Load from SharedPreferences first (faster)
      final prefs = await SharedPreferences.getInstance();
      _currentKarma = prefs.getInt(_karmaCountKey) ?? 0;
      
      // Emit current karma
      _karmaStreamController.add(_currentKarma);
      
      // Sync with Firestore in background
      await _syncWithFirestore();
    } catch (e) {
      debugPrint('Error loading karma: $e');
    }
  }
  
  /// Sync karma with Firestore
  Future<void> _syncWithFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final firestoreKarma = userDoc.data()?['karma'] ?? 0;
        
        // Use the higher value between local and Firestore
        if (firestoreKarma > _currentKarma) {
          _currentKarma = firestoreKarma;
          await _saveKarmaLocally(_currentKarma);
          _karmaStreamController.add(_currentKarma);
        }
      }
    } catch (e) {
      debugPrint('Error syncing karma with Firestore: $e');
    }
  }
  
  /// Save karma to SharedPreferences
  Future<void> _saveKarmaLocally(int karma) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_karmaCountKey, karma);
    } catch (e) {
      debugPrint('Error saving karma locally: $e');
    }
  }
  
  /// Save karma to Firestore
  Future<void> _saveKarmaToFirestore(int karma) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      await _firestore.collection('users').doc(user.uid).update({
        'karma': karma,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving karma to Firestore: $e');
    }
  }
  
  /// Grant karma points to the user
  Future<void> grantKarma(int points, String reason) async {
    try {
      final newKarma = _currentKarma + points;
      
      // Update local karma
      _currentKarma = newKarma;
      
      // Save to both SharedPreferences and Firestore
      await Future.wait([
        _saveKarmaLocally(newKarma),
        _saveKarmaToFirestore(newKarma),
      ]);
      
      // Emit updated karma
      _karmaStreamController.add(_currentKarma);
      
      // Track karma grant with Mixpanel
      MixpanelService.trackEvent('Karma Granted', properties: {
        'points': points,
        'reason': reason,
        'total_karma': newKarma,
      });
      
      debugPrint('✅ Granted $points karma for: $reason. Total: $newKarma');
      
    } catch (e) {
      debugPrint('Error granting karma: $e');
    }
  }
  
  /// Grant karma for posting a message in official chat
  Future<void> grantKarmaForMessage() async {
    await grantKarma(150, 'posted_message');
  }
  
  /// Grant karma for posting in community
  Future<void> grantKarmaForCommunityPost() async {
    await grantKarma(300, 'community_post');
  }
  
  /// Dispose resources
  void dispose() {
    _karmaStreamController.close();
  }
} 