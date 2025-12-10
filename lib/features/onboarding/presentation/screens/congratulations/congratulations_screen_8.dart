import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:lottie/lottie.dart';
import 'package:stoppr/features/app/presentation/screens/main_scaffold.dart';
import 'package:stoppr/core/navigation/page_transitions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:flutter/foundation.dart';

class CongratulationsScreen8 extends StatefulWidget {
  const CongratulationsScreen8({super.key});

  @override
  State<CongratulationsScreen8> createState() => _CongratulationsScreen8State();
}

class _CongratulationsScreen8State extends State<CongratulationsScreen8> {
  String? _firstName;

  @override
  void initState() {
    super.initState();
    _loadUserFirstName();
    
    // Apply system UI settings to ensure dark status bar icons for light bg
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

  Future<void> _loadUserFirstName() async {
    try {
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

  Future<void> _navigateToHome() async {
    // Set flag in SharedPreferences to indicate coming from congratulations screen
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('coming_from_congratulations', true);
    
    // Navigate to home screen
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        FadePageRoute(
          child: const MainScaffold(initialIndex: 0, fromCongratulations: true),
        ),
        (route) => false,
      );
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
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      body: Stack(
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
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Whenever you need us,\nwe\'re right here',
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
              
              // Together animation centered
              SizedBox(
                height: screenSize.height * 0.4,
                child: Lottie.asset(
                  'assets/images/lotties/Together.json',
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
              
              // Expanded space to push bottom content
              const Spacer(),
              
              // Let's go button at bottom
              Padding(
                padding: EdgeInsets.only(
                  bottom: Platform.isAndroid ? 110.0 : 80.0,
                  left: 32.0,
                  right: 32.0
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFed3272),
                          Color(0xFFfd5d32),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: _navigateToHome,
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'Let\'s go',
                                style: TextStyle(
                                  fontFamily: 'ElzaRound',
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 