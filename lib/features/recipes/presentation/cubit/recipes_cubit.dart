import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:stoppr/features/recipes/data/repositories/recipe_repository.dart';
import 'package:stoppr/features/recipes/presentation/cubit/recipes_state.dart';

/// Cubit for managing recipes state
class RecipesCubit extends Cubit<RecipesState> {
  final RecipeRepository _repository;

  RecipesCubit(this._repository) : super(const RecipesState.initial());

  /// Load initial healthy recipes
  Future<void> loadInitialRecipes() async {
    emit(const RecipesState.loading());
    
    try {
      final recipes = await _repository.getHealthyRecipes();
      
      if (recipes.isEmpty) {
        emit(const RecipesState.error(
          message: 'No recipes found. Please try again.',
        ));
      } else {
        emit(RecipesState.loaded(
          recipes: recipes,
          activeFilters: [],
          searchQuery: '',
        ));
      }
    } catch (e) {
      debugPrint('❌ Error loading recipes: $e');
      emit(RecipesState.error(
        message: 'Could not load recipes. Please check your connection.',
      ));
    }
  }

  /// Filter recipes by health label (vegan, vegetarian, etc.)
  Future<void> filterByHealthLabel(String healthLabel) async {
    emit(const RecipesState.loading());
    
    try {
      final recipes = await _repository.getRecipesByHealthLabel(healthLabel);
      
      if (recipes.isEmpty) {
        emit(const RecipesState.error(
          message: 'No recipes found for this filter.',
        ));
      } else {
        emit(RecipesState.loaded(
          recipes: recipes,
          activeFilters: [healthLabel],
          searchQuery: '',
        ));
      }
    } catch (e) {
      debugPrint('❌ Error filtering recipes: $e');
      emit(RecipesState.error(
        message: 'Could not load recipes. Please try again.',
      ));
    }
  }

  /// Filter recipes by diet type (balanced, low-carb, etc.)
  Future<void> filterByDiet(String diet) async {
    emit(const RecipesState.loading());
    
    try {
      final recipes = await _repository.getRecipesByDiet(diet);
      
      if (recipes.isEmpty) {
        emit(const RecipesState.error(
          message: 'No recipes found for this filter.',
        ));
      } else {
        emit(RecipesState.loaded(
          recipes: recipes,
          activeFilters: [diet],
          searchQuery: '',
        ));
      }
    } catch (e) {
      debugPrint('❌ Error filtering recipes: $e');
      emit(RecipesState.error(
        message: 'Could not load recipes. Please try again.',
      ));
    }
  }

  /// Search recipes by query with optional filters
  Future<void> searchRecipes({
    String? query,
    List<String>? healthLabels,
    List<String>? dietLabels,
    String? mealType,
    String? calories,
  }) async {
    emit(const RecipesState.loading());
    
    try {
      final recipes = await _repository.searchRecipes(
        query: query,
        healthLabels: healthLabels,
        dietLabels: dietLabels,
        mealType: mealType,
        calories: calories,
      );
      
      if (recipes.isEmpty) {
        emit(const RecipesState.error(
          message: 'No recipes found. Try different filters.',
        ));
      } else {
        emit(RecipesState.loaded(
          recipes: recipes,
          activeFilters: [
            ...?healthLabels,
            ...?dietLabels,
          ],
          searchQuery: query ?? '',
        ));
      }
    } catch (e) {
      debugPrint('❌ Error searching recipes: $e');
      emit(RecipesState.error(
        message: 'Could not load recipes. Please try again.',
      ));
    }
  }

  /// Filter recipes by meal type (breakfast, lunch, dinner)
  Future<void> filterByMealType(String mealType) async {
    emit(const RecipesState.loading());
    
    try {
      final recipes = await _repository.searchRecipes(
        mealType: mealType,
      );
      
      if (recipes.isEmpty) {
        emit(const RecipesState.error(
          message: 'No recipes found for this meal type.',
        ));
      } else {
        emit(RecipesState.loaded(
          recipes: recipes,
          activeFilters: [],
          searchQuery: '',
        ));
      }
    } catch (e) {
      debugPrint('❌ Error filtering by meal type: $e');
      emit(RecipesState.error(
        message: 'Could not load recipes. Please try again.',
      ));
    }
  }

  /// Filter recipes by calorie range
  Future<void> filterByCalorieRange(String minCal, String maxCal) async {
    emit(const RecipesState.loading());
    
    try {
      final calories = '$minCal-$maxCal';
      final recipes = await _repository.searchRecipes(
        calories: calories,
      );
      
      if (recipes.isEmpty) {
        emit(const RecipesState.error(
          message: 'No recipes found for this calorie range.',
        ));
      } else {
        emit(RecipesState.loaded(
          recipes: recipes,
          activeFilters: [],
          searchQuery: '',
        ));
      }
    } catch (e) {
      debugPrint('❌ Error filtering by calorie range: $e');
      emit(RecipesState.error(
        message: 'Could not load recipes. Please try again.',
      ));
    }
  }

  /// Clear all filters and reload healthy recipes
  Future<void> clearFilters() async {
    await loadInitialRecipes();
  }

  /// Refresh recipes (for pull-to-refresh)
  Future<void> refreshRecipes() async {
    final currentState = state;
    
    if (currentState is RecipesLoaded) {
      // Reload with current filters
      if (currentState.activeFilters.isEmpty) {
        await loadInitialRecipes();
      } else {
        await searchRecipes(
          query: currentState.searchQuery.isEmpty ? null : currentState.searchQuery,
          healthLabels: currentState.activeFilters,
        );
      }
    } else {
      await loadInitialRecipes();
    }
  }

  /// Filter recipes with combined filters (meal type, calories, diet, health)
  Future<void> filterRecipes({
    String? mealType,
    String? calories,
    List<String>? dietLabels,
    List<String>? healthLabels,
    String? query,
  }) async {
    emit(const RecipesState.loading());
    
    try {
      final recipes = await _repository.searchRecipes(
        query: query,
        mealType: mealType,
        calories: calories,
        dietLabels: dietLabels,
        healthLabels: healthLabels,
      );
      
      if (recipes.isEmpty) {
        emit(const RecipesState.error(
          message: 'No recipes found. Try different filters.',
        ));
      } else {
        emit(RecipesState.loaded(
          recipes: recipes,
          activeFilters: [
            ...?healthLabels,
            ...?dietLabels,
          ],
          searchQuery: query ?? '',
        ));
      }
    } catch (e) {
      debugPrint('❌ Error filtering recipes: $e');
      emit(RecipesState.error(
        message: 'Could not load recipes. Please try again.',
      ));
    }
  }
}

