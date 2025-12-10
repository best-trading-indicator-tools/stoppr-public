import 'package:flutter/material.dart';
import 'package:stoppr/features/recipes/data/models/recipe_model.dart';

/// Recipe card widget styled per style_brand.md
/// Reference: User's screenshot showing recipe card layout
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeCard({
    required this.recipe,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate calories per serving
    final caloriesPerServing = (recipe.calories / recipe.yield).round();
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // Per style guide
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08), // Subtle shadow
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section (60% of card height)
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Image.network(
                  recipe.image,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback for failed image loads
                    return Container(
                      color: const Color(0xFFFBFBFB),
                      child: const Center(
                        child: Icon(
                          Icons.restaurant,
                          size: 40,
                          color: Color(0xFFed3272), // Brand pink
                        ),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: const Color(0xFFFBFBFB),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFFed3272), // Brand pink
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Info section (40% of card height)
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Recipe title
                    Expanded(
                      child: Text(
                        recipe.label,
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A), // Dark text per style guide
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Calories and time info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Calories
                        Flexible(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.local_fire_department,
                                size: 14,
                                color: Color(0xFF666666), // Gray per style guide
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '$caloriesPerServing cal',
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF666666), // Gray
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Cooking time (if available)
                        if (recipe.totalTime > 0)
                          Flexible(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Color(0xFF666666),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${recipe.totalTime}min',
                                    style: const TextStyle(
                                      fontFamily: 'ElzaRound',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF666666),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

