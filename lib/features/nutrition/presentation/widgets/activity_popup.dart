import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/analytics/mixpanel_service.dart';
import '../../../../core/navigation/page_transitions.dart';
import '../screens/food_scanner_screen.dart';
import '../screens/log_exercice/exercise_type_screen.dart';
import '../screens/food_database_entry_screen.dart';
import 'package:stoppr/features/recipes/presentation/screens/recipes_list_screen.dart';

class ActivityPopup extends StatelessWidget {
  const ActivityPopup({
    super.key,
    required this.targetDate,
    required this.onDismiss,
  });

  final DateTime targetDate;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss, // Dismiss when tapping outside
        child: Stack(
          children: [
            // Positioned popup near the FAB
            Positioned(
              bottom: 200, // Move higher above the FAB for better reach
              // Place the popup exactly top-left of the centered + button (72px wide)
              left: (((MediaQuery.of(context).size.width / 2) - 36 - 320 - 12)
                      .clamp(16.0, double.infinity)) as double,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {},
                child: SizedBox(
                  width: 320, // Wider to improve readability for long locales
                  child: Builder(builder: (context) {
                    final double cardWidth = (320 - 16) / 2; // two per row
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        // Scan food/drink (top-left)
                        SizedBox(
                          width: cardWidth,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              onDismiss();
                              MixpanelService.trackButtonTap('Activity Popup: Scan Food');
                              Navigator.of(context).push(
                                BottomToTopPageRoute(
                                  child: FoodScannerScreen(targetDate: targetDate),
                                  settings: const RouteSettings(name: '/food_scanner'),
                                ),
                              );
                            },
                            child: _buildPopupOptionCard(
                              icon: Icons.camera_alt_outlined,
                              title: l10n.translate('activitySelector_scanFood'),
                            ),
                          ),
                        ),
                        // Log exercise (top-right)
                        SizedBox(
                          width: cardWidth,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              onDismiss();
                              MixpanelService.trackButtonTap('Activity Popup: Log Exercise');
                              Navigator.of(context).push(
                                BottomToTopPageRoute(
                                  child: ExerciseTypeScreen(targetDate: targetDate),
                                  settings: const RouteSettings(name: '/exercise_type'),
                                ),
                              );
                            },
                            child: _buildPopupOptionCard(
                              icon: Icons.directions_run,
                              title: l10n.translate('activitySelector_logExercise'),
                            ),
                          ),
                        ),
                        // Food database renamed to Log food/drink manually (next row under Scan)
                        SizedBox(
                          width: cardWidth,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              onDismiss();
                              MixpanelService.trackButtonTap('Activity Popup: Food Database');
                              Navigator.of(context).push(
                                BottomToTopPageRoute(
                                  child: FoodDatabaseEntryScreen(targetDate: targetDate),
                                  settings: const RouteSettings(name: '/food_database_entry'),
                                ),
                              );
                            },
                            child: _buildPopupOptionCard(
                              icon: Icons.search,
                              title: l10n.translate('activitySelector_logFoodManually'),
                            ),
                          ),
                        ),
                        // Browse Recipes (bottom-right)
                        SizedBox(
                          width: cardWidth,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              onDismiss();
                              MixpanelService.trackButtonTap('Activity Popup: Browse Recipes');
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const RecipesListScreen(),
                                  settings: const RouteSettings(name: '/recipes_list'),
                                ),
                              );
                            },
                            child: _buildPopupOptionCard(
                              icon: Icons.restaurant_menu,
                              title: l10n.translate('activitySelector_browseRecipes'),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
            ),
          ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupOptionCard({
    required IconData icon,
    required String title,
  }) {
    // Dynamically adjust label font size based on length to fit across locales
    final int len = title.length;
    final double labelFontSize = len > 32
        ? 12
        : (len > 26
            ? 13
            : (len > 22
                ? 14
                : 15));
    return Container(
      height: 116,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Brand gradient icon without any background
          ShaderMask(
            shaderCallback: (Rect bounds) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
            ).createShader(bounds),
            child: Icon(
              icon,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              title,
              textAlign: TextAlign.center,
              softWrap: true,
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                fontFamily: 'ElzaRound',
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
