import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/nutrition/presentation/onboarding/screens/height_weight_screen.dart';

class WorkoutsPerWeekScreen extends StatefulWidget {
  const WorkoutsPerWeekScreen({
    super.key,
    this.isOnboarding = true,
  });
  
  final bool isOnboarding;

  @override
  State<WorkoutsPerWeekScreen> createState() => _WorkoutsPerWeekScreenState();
}

class _WorkoutsPerWeekScreenState extends State<WorkoutsPerWeekScreen> {
  String _selectedActivity = 'moderate';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBFBFB),
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button
        title: Padding(
          padding: const EdgeInsets.only(right: 40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 1 / 4, // Step 1 of 4
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E5EA),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFed3272)),
            ),
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              // Title
              Text(
                l10n.translate('calorieOnboarding_activity_title'),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                l10n.translate('calorieOnboarding_activity_subtitle'),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 24),
              
              // Option 1
              _buildOption(
                value: 'light',
                title: '0–2',
                subtitle: l10n.translate('calorieOnboarding_activity_0_2').split('\n').length > 1 
                    ? l10n.translate('calorieOnboarding_activity_0_2').split('\n')[1] 
                    : 'Workouts now and then',
              ),
              const SizedBox(height: 12),
              
              // Option 2
              _buildOption(
                value: 'moderate',
                title: '3–5',
                subtitle: l10n.translate('calorieOnboarding_activity_3_5').split('\n').length > 1 
                    ? l10n.translate('calorieOnboarding_activity_3_5').split('\n')[1] 
                    : 'A few workouts per week',
              ),
              const SizedBox(height: 12),
              
              // Option 3
              _buildOption(
                value: 'active',
                title: '6+',
                subtitle: l10n.translate('calorieOnboarding_activity_6_plus').split('\n').length > 1 
                    ? l10n.translate('calorieOnboarding_activity_6_plus').split('\n')[1] 
                    : 'Dedicated athlete',
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
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HeightWeightScreen(
                      activity: _selectedActivity,
                      isOnboarding: widget.isOnboarding,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: Text(
                l10n.translate('calorieOnboarding_next'),
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
  
  Widget _buildOption({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedActivity == value;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedActivity = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected ? const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFFed3272), // Brand pink
              Color(0xFFfd5d32), // Brand orange
            ],
          ) : null,
          color: isSelected ? null : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.white : Colors.black,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}