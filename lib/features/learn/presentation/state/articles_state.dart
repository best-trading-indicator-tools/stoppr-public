import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stoppr/features/learn/domain/models/article_model.dart';
import 'package:stoppr/features/learn/domain/models/user_article_progress_model.dart';

part 'articles_state.freezed.dart';

// Represents the data needed for a single category section in the UI
@freezed
class ArticleCategoryViewModel with _$ArticleCategoryViewModel {
  const factory ArticleCategoryViewModel({
    required String categoryId,        // e.g., 'addiction_myths'
    required String title,            // e.g., 'Addiction and Myths'
    required List<Article> articles, // Articles belonging to this category
    required int completionPercentage, // Calculated percentage
    required Color color,             // UI color for the category
    required IconData icon,           // UI icon for the category
  }) = _ArticleCategoryViewModel;
}

@freezed
sealed class ArticlesState with _$ArticlesState {
  // Initial state before loading
  const factory ArticlesState.initial() = ArticlesInitial;

  // State when data is being loaded
  const factory ArticlesState.loading() = ArticlesLoading;

  // State when data is successfully loaded
  const factory ArticlesState.loaded({
    required List<ArticleCategoryViewModel> categories, 
    required UserArticleProgress userProgress, // Keep raw progress for individual checks
  }) = ArticlesLoaded;

  // State when an error occurs during loading
  const factory ArticlesState.error(String message) = ArticlesError;
}

// Helper function to map category IDs to display properties (can be moved/improved)
(String, Color, IconData) getCategoryDisplayProperties(String categoryId) {
  switch (categoryId) {
    case 'addiction_myths':
      return ('articleCategory_addictionAndMyths', const Color(0xFFFB8C00), Icons.psychology_alt);
    case 'health_effects':
      return ('articleCategory_healthEffects', const Color(0xFFEC407A), Icons.monitor_heart);
    case 'stopping_benefits':
      return ('articleCategory_stoppingBenefits', const Color(0xFF8E24AA), Icons.auto_awesome);
    case 'recovery_strategies':
      return ('articleCategory_recoveryStrategies', const Color(0xFF42A5F5), Icons.support_agent);
    default:
      return ('Unknown Category', Colors.grey, Icons.help_outline); // Fallback
  }
} 