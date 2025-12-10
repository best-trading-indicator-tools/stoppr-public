import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/features/recipes/data/repositories/recipe_favorites_repository.dart';
import 'package:stoppr/features/recipes/presentation/widgets/recipe_card.dart';
import 'package:stoppr/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:stoppr/features/recipes/data/models/recipe_model.dart';

/// Favorites screen showing user's saved favorite recipes
class RecipesFavoritesScreen extends StatefulWidget {
  const RecipesFavoritesScreen({super.key});

  @override
  State<RecipesFavoritesScreen> createState() => _RecipesFavoritesScreenState();
}

class _RecipesFavoritesScreenState extends State<RecipesFavoritesScreen> {
  final _favoritesRepository = RecipeFavoritesRepository();

  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('Recipes Favorites Screen');
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<Recipe>>(
        stream: _favoritesRepository.getFavoritesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFFed3272),
                ),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SelectableText.rich(
                  TextSpan(
                    children: [
                      const WidgetSpan(
                        child: Icon(
                          Icons.error_outline,
                          color: Color(0xFFed3272),
                          size: 48,
                        ),
                      ),
                      const TextSpan(text: '\n\n'),
                      TextSpan(
                        text: snapshot.error.toString(),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFed3272),
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final favorites = snapshot.data ?? [];

          if (favorites.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      size: 64,
                      color: Color(0xFF999999),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      localizations.translate('recipes_noFavorites'),
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF666666),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localizations.translate('recipes_noFavoritesDescription'),
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF999999),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              // Stream will automatically update
            },
            color: const Color(0xFFed3272),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final recipe = favorites[index];
                return RecipeCard(
                  recipe: recipe,
                  onTap: () {
                    MixpanelService.trackButtonTap(
                      'Favorite Recipe Card: ${recipe.label}',
                      screenName: 'Recipes Favorites Screen',
                    );
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => RecipeDetailScreen(recipe: recipe),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      );
  }
}

