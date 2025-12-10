import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'congratulations_screen_5.dart';
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart';
import 'package:stoppr/core/navigation/page_transitions.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';

class CongratulationsScreen4 extends StatefulWidget {
  const CongratulationsScreen4({super.key});

  @override
  State<CongratulationsScreen4> createState() => _CongratulationsScreen4State();
}

class _CongratulationsScreen4State extends State<CongratulationsScreen4> {
  String? _firstName;

  @override
  void initState() {
    super.initState();
    _loadUserFirstName();
    
    // Apply system UI settings to ensure white status bar icons
    _setSystemUIOverlayStyle();

    // Track page view
    // MIXPANEL_COST_CUT: Removed congratulations page view - keep only Screen 1
  }
  
  void _setSystemUIOverlayStyle() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  void _navigateToNextScreen() {
    Navigator.of(context).pushReplacement(
      FadePageRoute(
        child: const CongratulationsScreen5(),
      ),
    );
  }

  void _skipToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      FadePageRoute(
        child: const MainScaffold(initialIndex: 0),
      ),
      (route) => false,
    );
  }

  Future<void> _loadUserFirstName() async {
    try {
      // Try to get name from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedFirstName = prefs.getString('user_first_name');
      
      if (savedFirstName != null && savedFirstName.isNotEmpty) {
        if (mounted) {
          setState(() {
            _firstName = savedFirstName;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user first name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Skip button in the top-right corner
          TextButton(
            onPressed: _skipToHome,
            child: const Text(
              'SKIP',
              style: TextStyle(
                color: Color(0xFFed3272),
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      body: GestureDetector(
        onTap: _navigateToNextScreen,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFBFBFB),
                    Color(0xFFFBFBFB),
                  ],
                ),
              ),
            ),
            
            // Content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top padding to move content down from AppBar
                const SizedBox(height: 20),
                
                // Main text
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    '... and sometimes there are\nbumps along the way',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      height: 1.3,
                    ),
                  ),
                ),
                
                // Expanded space to push content to top and bottom
                const Spacer(),
                
                // Dog guitar animation centered
                SizedBox(
                  height: screenSize.height * 0.4,
                  child: Lottie.asset(
                    'assets/images/lotties/dog_guitar.json',
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
                
                // Expanded space to push bottom content
                const Spacer(),
                
                // Tap to continue text at bottom
                Padding(
                  padding: EdgeInsets.only(bottom: Platform.isAndroid ? 70.0 : 40.0),
                  child: const Text(
                    'TAP TO CONTINUE',
                    style: TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF666666),
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildColorfulHand(Color color, double rotation) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.front_hand,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
} 