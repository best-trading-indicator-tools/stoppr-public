import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/nutrition/presentation/onboarding/screens/height_weight_screen.dart';
import 'package:stoppr/features/nutrition/presentation/onboarding/screens/results_calories_onboarding_screen.dart';
import 'package:stoppr/features/nutrition/presentation/onboarding/screens/results_screen.dart';

class GoalSelectionScreen extends StatefulWidget {
  const GoalSelectionScreen({
    super.key,
    required this.activity,
    required this.heightCm,
    required this.weightKg,
    required this.isMetric,
    this.isOnboarding = true,
  });
  
  final String activity;
  final int heightCm;
  final int weightKg;
  final bool isMetric;
  final bool isOnboarding;

  @override
  State<GoalSelectionScreen> createState() => _GoalSelectionScreenState();
}

class _GoalSelectionScreenState extends State<GoalSelectionScreen> {
  String _selectedGoal = 'maintain';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFBFB),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HeightWeightScreen(activity: widget.activity),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 3 / 4, // Step 3 of 4
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E5EA),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFed3272)),
            ),
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('calorieOnboarding_goal_title'),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.translate('calorieOnboarding_goal_subtitle'),
                style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
              ),
              const SizedBox(height: 60),
              
              _GoalOption(
                value: 'lose',
                title: l10n.translate('calorieOnboarding_goal_lose'),
                isSelected: _selectedGoal == 'lose',
                onTap: () => setState(() => _selectedGoal = 'lose'),
              ),
              const SizedBox(height: 20),
              
              _GoalOption(
                value: 'maintain',
                title: l10n.translate('calorieOnboarding_goal_maintain'),
                isSelected: _selectedGoal == 'maintain',
                onTap: () => setState(() => _selectedGoal = 'maintain'),
              ),
              const SizedBox(height: 20),
              
              _GoalOption(
                value: 'gain',
                title: l10n.translate('calorieOnboarding_goal_gain'),
                isSelected: _selectedGoal == 'gain',
                onTap: () => setState(() => _selectedGoal = 'gain'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFed3272), // Brand pink
                    Color(0xFFfd5d32), // Brand orange
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: ElevatedButton(
              onPressed: _isLoading ? null : () async {
                setState(() => _isLoading = true);
                
                // Show loader for 1 second
                await Future.delayed(const Duration(seconds: 1));
                
                if (mounted) {
                  if (widget.isOnboarding) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResultsCaloriesOnboardingScreen(
                          activity: widget.activity,
                          heightCm: widget.heightCm,
                          weightKg: widget.weightKg,
                          goal: _selectedGoal,
                          isMetric: widget.isMetric,
                        ),
                      ),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResultsScreen(
                          activity: widget.activity,
                          heightCm: widget.heightCm,
                          weightKg: widget.weightKg,
                          goal: _selectedGoal,
                          isMetric: widget.isMetric,
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      l10n.translate('calorieOnboarding_autoGenerate'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalOption extends StatelessWidget {
  const _GoalOption({
    required this.value,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String value;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          gradient: isSelected ? const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFFed3272), // Brand pink
              Color(0xFFfd5d32), // Brand orange
            ],
          ) : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFE0E0E0),
            width: 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
