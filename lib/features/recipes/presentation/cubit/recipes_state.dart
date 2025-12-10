import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stoppr/features/recipes/data/models/recipe_model.dart';

part 'recipes_state.freezed.dart';

@freezed
class RecipesState with _$RecipesState {
  const factory RecipesState.initial() = RecipesInitial;
  
  const factory RecipesState.loading() = RecipesLoading;
  
  const factory RecipesState.loaded({
    required List<Recipe> recipes,
    @Default([]) List<String> activeFilters,
    @Default('') String searchQuery,
  }) = RecipesLoaded;
  
  const factory RecipesState.error({
    required String message,
  }) = RecipesError;
}

