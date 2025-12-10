import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:stoppr/features/recipes/data/models/recipe_model.dart';

/// Repository for managing favorite recipes in Firestore
class RecipeFavoritesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get the favorites collection path for current user
  CollectionReference<Map<String, dynamic>> _getFavoritesCollection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('favorite_recipes');
  }

  /// Helper method to extract recipe data map (non-async to avoid yield keyword conflict)
  Map<String, dynamic> _recipeToMap(Recipe recipe) {
    // Access yield property using dynamic cast to avoid reserved keyword conflict
    final recipeYield = (recipe as dynamic).yield as int;
    return {
      'uri': recipe.uri,
      'label': recipe.label,
      'image': recipe.image,
      'source': recipe.source,
      'url': recipe.url,
      'calories': recipe.calories,
      'totalWeight': recipe.totalWeight,
      'totalTime': recipe.totalTime,
      'yield': recipeYield,
      'dietLabels': recipe.dietLabels,
      'healthLabels': recipe.healthLabels,
      'ingredientLines': recipe.ingredientLines,
      'cuisineType': recipe.cuisineType,
      'mealType': recipe.mealType,
      'dishType': recipe.dishType,
      'totalNutrients': _nutrientsToMap(recipe.totalNutrients),
    };
  }

  /// Helper method to create Recipe from Firestore data (non-async/generator to avoid yield keyword conflict)
  Recipe _recipeFromMap(Map<String, dynamic> data) {
    // Extract yield value to avoid reserved keyword conflict
    final recipeYield = (data['yield'] as int?) ?? 1;
    return Recipe(
      uri: data['uri'] as String? ?? '',
      label: data['label'] as String? ?? 'Untitled Recipe',
      image: data['image'] as String? ?? '',
      source: data['source'] as String? ?? '',
      url: data['url'] as String? ?? '',
      calories: (data['calories'] as num?)?.toDouble() ?? 0.0,
      totalWeight: (data['totalWeight'] as num?)?.toDouble(),
      totalTime: (data['totalTime'] as int?) ?? 0,
      yield: recipeYield,
      dietLabels: (data['dietLabels'] as List<dynamic>?)?.cast<String>() ?? [],
      healthLabels: (data['healthLabels'] as List<dynamic>?)?.cast<String>() ?? [],
      ingredientLines: (data['ingredientLines'] as List<dynamic>?)?.cast<String>() ?? [],
      cuisineType: (data['cuisineType'] as List<dynamic>?)?.cast<String>() ?? [],
      mealType: (data['mealType'] as List<dynamic>?)?.cast<String>() ?? [],
      dishType: (data['dishType'] as List<dynamic>?)?.cast<String>() ?? [],
      totalNutrients: _mapToNutrients(data['totalNutrients'] as Map<String, dynamic>? ?? {}),
    );
  }

  /// Save a recipe as favorite
  Future<void> saveFavorite(Recipe recipe) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Use recipe URI as document ID for easy lookup
      final recipeId = recipe.uri.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      
      final recipeData = _recipeToMap(recipe);
      recipeData['createdAt'] = FieldValue.serverTimestamp();
      recipeData['updatedAt'] = FieldValue.serverTimestamp();
      
      await _getFavoritesCollection(userId).doc(recipeId).set(recipeData);

      debugPrint('✅ Saved favorite recipe: ${recipe.label}');
    } catch (e) {
      debugPrint('❌ Error saving favorite recipe: $e');
      rethrow;
    }
  }

  /// Remove a recipe from favorites
  Future<void> removeFavorite(String recipeUri) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final recipeId = recipeUri.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      await _getFavoritesCollection(userId).doc(recipeId).delete();
      debugPrint('✅ Removed favorite recipe: $recipeUri');
    } catch (e) {
      debugPrint('❌ Error removing favorite recipe: $e');
      rethrow;
    }
  }

  /// Check if a recipe is favorited
  Future<bool> isFavorite(String recipeUri) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final recipeId = recipeUri.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final doc = await _getFavoritesCollection(userId).doc(recipeId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('❌ Error checking favorite status: $e');
      return false;
    }
  }

  /// Get all favorite recipes
  Stream<List<Recipe>> getFavoritesStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value([]);
    }

    return _getFavoritesCollection(userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => _recipeFromMap(doc.data())).toList();
    });
  }

  /// Get all favorite recipes (one-time fetch)
  Future<List<Recipe>> getFavorites() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return [];
    }

    try {
      final snapshot = await _getFavoritesCollection(userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => _recipeFromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('❌ Error fetching favorites: $e');
      return [];
    }
  }

  /// Convert nutrients map to Firestore-compatible format
  Map<String, dynamic> _nutrientsToMap(Map<String, NutrientInfo> nutrients) {
    final result = <String, dynamic>{};
    nutrients.forEach((key, value) {
      result[key] = {
        'label': value.label,
        'quantity': value.quantity,
        'unit': value.unit,
      };
    });
    return result;
  }

  /// Convert Firestore map to nutrients
  Map<String, NutrientInfo> _mapToNutrients(Map<String, dynamic> data) {
    final result = <String, NutrientInfo>{};
    data.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        result[key] = NutrientInfo(
          label: value['label'] as String? ?? '',
          quantity: (value['quantity'] as num?)?.toDouble() ?? 0.0,
          unit: value['unit'] as String? ?? '',
        );
      }
    });
    return result;
  }
}

