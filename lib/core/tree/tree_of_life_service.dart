import 'package:flutter/foundation.dart';

/// Service to handle tree of life growth calculations and stages
class TreeOfLifeService {
  static final TreeOfLifeService _instance = TreeOfLifeService._internal();
  
  factory TreeOfLifeService() {
    return _instance;
  }
  
  TreeOfLifeService._internal();
  
  /// Calculate tree growth progress based on streak days
  /// Returns a value between 0.0 and 1.0 for Lottie animation control
  double calculateTreeProgress(int streakDays, {bool hasPlantedTree = false, int hours = 0, int minutes = 0}) {
    // Complete tree growth cycle: 90 days to reach 100%
    // Day 0-1: seed stage (10-15% for visibility)
    // Day 2-30: early growth (15-50%)  
    // Day 31-90: final growth (50-100%)
    
    double calculatedProgress;
    
    if (streakDays <= 1) {
      // Seed stage - include sub-day progress (hours and minutes)
      double totalDays = streakDays + (hours / 24.0) + (minutes / (24.0 * 60.0));
      
      if (totalDays == 0) {
        calculatedProgress = 0.0;
      } else {
        // Progress from 10% to 15% during first day
        calculatedProgress = 0.10 + (totalDays * 0.05); // 0.10 to 0.15
      }
    } else if (streakDays <= 30) {
      // Early growth - steady development from 15% to 50%
      final progress = (streakDays - 1) / 29.0; // 0.0 to 1.0 within this range
      calculatedProgress = 0.15 + (progress * 0.35); // 0.15 to 0.50
    } else if (streakDays <= 90) {
      // Final growth - complete the tree from 50% to 100%
      final progress = (streakDays - 30) / 60.0; // 0.0 to 1.0 within this range
      calculatedProgress = 0.50 + (progress * 0.50); // 0.50 to 1.0
    } else {
      // Beyond 90 days - fully mature tree
      calculatedProgress = 1.0;
    }
    
    // Clamp between 0.0 and 1.0
    return calculatedProgress.clamp(0.0, 1.0);
  }
  
  /// Get growth stage description based on streak days
  TreeGrowthStage getGrowthStage(int streakDays) {
    if (streakDays <= 1) {
      return TreeGrowthStage.seed;
    } else if (streakDays <= 7) {
      return TreeGrowthStage.sprout;
    } else if (streakDays <= 30) {
      return TreeGrowthStage.sapling;
    } else if (streakDays <= 60) {
      return TreeGrowthStage.youngTree;
    } else if (streakDays <= 90) {
      return TreeGrowthStage.matureTree;
    } else {
      return TreeGrowthStage.ancientTree;
    }
  }
  
  /// Get localized key for growth stage description
  String getGrowthStageKey(TreeGrowthStage stage) {
    switch (stage) {
      case TreeGrowthStage.seed:
        return 'treeOfLife_stage_seed';
      case TreeGrowthStage.sprout:
        return 'treeOfLife_stage_sprout';
      case TreeGrowthStage.sapling:
        return 'treeOfLife_stage_sapling';
      case TreeGrowthStage.youngTree:
        return 'treeOfLife_stage_youngTree';
      case TreeGrowthStage.matureTree:
        return 'treeOfLife_stage_matureTree';
      case TreeGrowthStage.ancientTree:
        return 'treeOfLife_stage_ancientTree';
    }
  }
  
  /// Get inspirational message key based on growth stage
  String getInspirationMessageKey(TreeGrowthStage stage) {
    switch (stage) {
      case TreeGrowthStage.seed:
        return 'treeOfLife_inspiration_seed';
      case TreeGrowthStage.sprout:
        return 'treeOfLife_inspiration_sprout';
      case TreeGrowthStage.sapling:
        return 'treeOfLife_inspiration_sapling';
      case TreeGrowthStage.youngTree:
        return 'treeOfLife_inspiration_youngTree';
      case TreeGrowthStage.matureTree:
        return 'treeOfLife_inspiration_matureTree';
      case TreeGrowthStage.ancientTree:
        return 'treeOfLife_inspiration_ancientTree';
    }
  }
  
  /// Check if user should see "Plant Tree" CTA vs existing tree
  bool shouldShowPlantTreeCTA(int streakDays, {int hours = 0, int minutes = 0}) {
    // Show plant tree CTA only if completely at 0 (no progress at all)
    // If there's any time progress (hours or minutes), show the tree instead
    return streakDays == 0 && hours == 0 && minutes == 0;
  }
  
  /// Get next milestone day for motivation
  int getNextMilestone(int streakDays) {
    if (streakDays < 7) return 7;
    if (streakDays < 30) return 30;
    if (streakDays < 60) return 60;
    if (streakDays < 90) return 90;
    if (streakDays < 180) return 180; // 6 months
    return 365; // 1 year milestone
  }
}

/// Enum representing different tree growth stages
enum TreeGrowthStage {
  seed,
  sprout,
  sapling,
  youngTree,
  matureTree,
  ancientTree,
} 