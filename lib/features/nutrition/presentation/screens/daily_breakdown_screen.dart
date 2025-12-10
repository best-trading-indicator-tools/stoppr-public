import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/models/daily_summary.dart';
import '../../data/models/nutrition_goals.dart';
import '../../data/repositories/nutrition_repository.dart';
import '../../../../core/localization/app_localizations.dart';
import 'package:stoppr/features/nutrition/presentation/screens/nutrition_goals_screen.dart';
import '../../../../core/analytics/mixpanel_service.dart';

class DailyBreakdownScreen extends StatefulWidget {
  final DateTime date;

  const DailyBreakdownScreen({
    Key? key,
    required this.date,
  }) : super(key: key);

  @override
  State<DailyBreakdownScreen> createState() => _DailyBreakdownScreenState();
}

class _DailyBreakdownScreenState extends State<DailyBreakdownScreen> {
  final _nutritionRepository = NutritionRepository();

  @override
  void initState() {
    super.initState();
    
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    MixpanelService.trackPageView('Daily Breakdown Screen');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            MixpanelService.trackButtonTap('Daily Breakdown Screen: Back Button');
            Navigator.pop(context);
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('calorieTracker_dashboard_title'),
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: StreamBuilder<NutritionGoals?>(
        stream: _nutritionRepository.getNutritionGoals(),
        builder: (context, goalsSnapshot) {
          return StreamBuilder<DailySummary?>(
            stream: _nutritionRepository.getDailySummary(widget.date),
            builder: (context, summarySnapshot) {
              final goals = goalsSnapshot.data;
              final summary = summarySnapshot.data;

              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Calories section
                    _buildMainSection(
                      AppLocalizations.of(context)!.translate('calorieTracker_calories'),
                      summary?.totalCalories ?? 0,
                      goals?.calories ?? 1662,
                      '🔥',
                    ),

                    const SizedBox(height: 16),

                    // Macronutrients
                    _buildNutrientRow(
                      icon: '🥩',
                      label: AppLocalizations.of(context)!.translate('calorieTracker_protein'),
                      current: summary?.totalProtein ?? 0,
                      goal: goals?.protein ?? 150,
                      unit: AppLocalizations.of(context)!.translate('unit_g'),
                      color: const Color(0xFFFF6B6B),
                    ),
                    _buildNutrientRow(
                      icon: '🥖',
                      label: AppLocalizations.of(context)!.translate('calorieTracker_carbs'),
                      current: summary?.totalCarbs ?? 0,
                      goal: goals?.carbs ?? 161,
                      unit: AppLocalizations.of(context)!.translate('unit_g'),
                      color: const Color(0xFFFFA726),
                    ),
                    _buildNutrientRow(
                      icon: '🧈',
                      label: AppLocalizations.of(context)!.translate('calorieTracker_fat'),
                      current: summary?.totalFat ?? 0,
                      goal: goals?.fat ?? 46,
                      unit: AppLocalizations.of(context)!.translate('unit_g'),
                      color: const Color(0xFF42A5F5),
                    ),

                    // Sugar
                    _buildNutrientRow(
                      icon: '🍬',
                      label: AppLocalizations.of(context)!.translate('calorieTracker_sugar'),
                      current: summary?.totalSugar ?? 0,
                      goal: goals?.sugar ?? 25,
                      unit: AppLocalizations.of(context)!.translate('unit_g'),
                      color: const Color(0xFFAB47BC),
                    ),

                    // Water
                    _buildNutrientRow(
                      icon: '💧',
                      label: AppLocalizations.of(context)!.translate('calorieTracker_water'),
                      current: ((summary?.waterIntake ?? 0) / 1000.0),
                      goal: ((goals?.water ?? 2000) / 1000.0),
                      unit: AppLocalizations.of(context)!.translate('unit_l'),
                      color: const Color(0xFF29B6F6),
                    ),

                    const Spacer(),

                    // Edit Daily Goals button
                    GestureDetector(
                      onTap: () {
                        MixpanelService.trackButtonTap('Daily Breakdown Screen: Edit Daily Goals Button');
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const NutritionGoalsScreen(),
                            settings: const RouteSettings(name: '/nutrition_goals'),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context)!.translate('calorieTracker_editDailyGoals'),
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMainSection(String label, double current, double goal, String emoji) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${current.toStringAsFixed(0)}/${goal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: const Color(0xFFF0F0F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34C759)),
                  strokeCap: StrokeCap.round,
                ),
                Text(emoji, style: const TextStyle(fontSize: 20)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientRow({
    required String icon,
    required String label,
    required double current,
    required double goal,
    required String unit,
    required Color color,
  }) {
    final percentage = goal > 0 ? (current / goal * 100).clamp(0, 100) : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${current.toStringAsFixed(0)}/${goal.toStringAsFixed(0)}$unit',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
