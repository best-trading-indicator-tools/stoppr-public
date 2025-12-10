import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'streak_service.dart';
import '../notifications/notification_service.dart';

class Achievement {
  final String id;
  final String name;
  final String description;
  final String imageAsset;
  final int daysRequired;
  final int currentProgress;
  final bool isUnlocked;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.imageAsset,
    required this.daysRequired,
    this.currentProgress = 0,
    this.isUnlocked = false,
  });

  Achievement copyWith({
    String? id,
    String? name,
    String? description,
    String? imageAsset,
    int? daysRequired,
    int? currentProgress,
    bool? isUnlocked,
  }) {
    return Achievement(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageAsset: imageAsset ?? this.imageAsset,
      daysRequired: daysRequired ?? this.daysRequired,
      currentProgress: currentProgress ?? this.currentProgress,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

class AchievementsService {
  // Singleton pattern
  static final AchievementsService _instance = AchievementsService._internal();
  
  factory AchievementsService() {
    return _instance;
  }
  
  AchievementsService._internal();
  
  // Stream controller for achievement updates
  final StreamController<List<Achievement>> _achievementsController = 
      StreamController<List<Achievement>>.broadcast();
  
  // Stream of achievements that widgets can listen to
  Stream<List<Achievement>> get achievementsStream => _achievementsController.stream;
  
  // Streak service instance
  final StreakService _streakService = StreakService();
  
  // Current list of achievements
  List<Achievement> _achievements = [];
  bool _isInitialized = false;
  
  // Get the current achievements without subscribing to updates
  List<Achievement> get achievements => _achievements;

  // Get the available achievements (static list)
  static List<Achievement> get availableAchievements => _availableAchievements;

  // Available achievements - these match the exact ones from the screenshots
  static final List<Achievement> _availableAchievements = [
    Achievement(
      id: 'seed',
      name: 'Seed',
      description: 'Plant the seed of self-control by staying clean for 1 day.',
      imageAsset: 'assets/images/rosaces/achievements_seed.json',
      daysRequired: 1,
    ),
    Achievement(
      id: 'sprout',
      name: 'Sprout',
      description: 'Nurture your discipline by staying clean for 3 days.',
      imageAsset: 'assets/images/rosaces/achievements_sprout.json',
      daysRequired: 3,
    ),
    Achievement(
      id: 'pioneer',
      name: 'Pioneer',
      description: 'Become a pioneer of change by staying clean for 7 days.',
      imageAsset: 'assets/images/rosaces/achievements_pioneer.json',
      daysRequired: 7,
    ),
    Achievement(
      id: 'momentum',
      name: 'Momentum',
      description: 'Build unstoppable momentum by staying clean for 10 days.',
      imageAsset: 'assets/images/rosaces/achievements_momentum.json',
      daysRequired: 10,
    ),
    Achievement(
      id: 'fortress',
      name: 'Fortress',
      description: 'Fortify your resolve by staying clean for 14 days.',
      imageAsset: 'assets/images/rosaces/achievements_fortress.json',
      daysRequired: 14,
    ),
    Achievement(
      id: 'guardian',
      name: 'Guardian',
      description: 'Guard your progress with strength by staying clean for 30 days.',
      imageAsset: 'assets/images/rosaces/achievements_guardian.json',
      daysRequired: 30,
    ),
    Achievement(
      id: 'trailblazer',
      name: 'Trailblazer',
      description: 'Blaze the trail of success by staying clean for 45 days.',
      imageAsset: 'assets/images/rosaces/achievements_trailblazer.json',
      daysRequired: 45,
    ),
    Achievement(
      id: 'ascendant',
      name: 'Ascendant',
      description: 'Ascend to new heights of control by staying clean for 60 days.',
      imageAsset: 'assets/images/rosaces/achievements_ascendant.json',
      daysRequired: 60,
    ),
    Achievement(
      id: 'nirvana',
      name: 'Nirvana',
      description: 'Achieve ultimate peace and freedom by staying clean for 90 days.',
      imageAsset: 'assets/images/rosaces/achievements_nirvana.json',
      daysRequired: 90,
    ),
  ];
  
  // Initialize achievement service
  Future<void> initialize() async {
    if (_isInitialized) return;
    // Make sure streak service is initialized first
    await _streakService.initialize();
    
    // Then load achievements
    await _loadAchievements();
    
    // Listen to streak updates to update achievements
    _streakService.streakStream.listen(_updateAchievements);
    _isInitialized = true;
  }
  
  // Load achievements data from shared preferences
  Future<void> _loadAchievements() async {
    final streakData = _streakService.currentStreak;
    final currentDays = streakData.days;
    
    _achievements = _availableAchievements.map((achievement) {
      final progress = currentDays >= achievement.daysRequired 
          ? achievement.daysRequired 
          : currentDays;
      
      return achievement.copyWith(
        currentProgress: progress,
        isUnlocked: currentDays >= achievement.daysRequired,
      );
    }).toList();
    
    // Notify listeners of the loaded achievements
    _achievementsController.add(_achievements);
  }
  
  // Update achievements based on streak data
  void _updateAchievements(StreakData streakData) {
    final currentDays = streakData.days;
    final notificationService = NotificationService();
    
    bool hasUpdates = false;
    
    for (int i = 0; i < _achievements.length; i++) {
      final achievement = _achievements[i];
      
      // Calculate progress (capped at the required days)
      final progress = currentDays >= achievement.daysRequired 
          ? achievement.daysRequired 
          : currentDays;
      
      // Check if achievement was just unlocked
      final wasUnlocked = achievement.isUnlocked;
      final isNowUnlocked = currentDays >= achievement.daysRequired;
      
      if (progress != achievement.currentProgress || wasUnlocked != isNowUnlocked) {
        _achievements[i] = achievement.copyWith(
          currentProgress: progress,
          isUnlocked: isNowUnlocked,
        );
        hasUpdates = true;
        
        // If achievement has just been unlocked, send a notification
        if (!wasUnlocked && isNowUnlocked) {
          notificationService.sendAchievementUnlockedNotification(
            achievementName: achievement.name,
            achievementDescription: achievement.description,
          );
        }
      }
    }
    
    // Only notify if there were updates
    if (hasUpdates) {
      _achievementsController.add(_achievements);
    }
  }
  
  // Get a user's name from SharedPreferences
  Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_first_name') ?? ''; // Default to '' if not set
  }
  
  // Get the highest unlocked achievement (most recent)
  Achievement? getHighestUnlockedAchievement() {
    if (!_isInitialized) {
      debugPrint(
        "Warning: AchievementsService.getHighestUnlockedAchievement was called before initialization was complete.",
      );
      return null;
    }
    final unlockedAchievements = _achievements.where((a) => a.isUnlocked).toList();
    
    if (unlockedAchievements.isEmpty) {
      return null; // No achievements unlocked yet
    }
    
    // Return the achievement with the highest days requirement
    return unlockedAchievements.reduce((a, b) => 
      a.daysRequired > b.daysRequired ? a : b);
  }
  
  // Dispose resources
  void dispose() {
    _achievementsController.close();
  }
} 