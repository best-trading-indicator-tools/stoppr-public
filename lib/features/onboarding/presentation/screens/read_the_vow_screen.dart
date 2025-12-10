import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/features/onboarding/presentation/screens/letter_from_future_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/onboarding_card_2.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:flutter_animate/flutter_animate.dart'; // Add this import for animations
import 'package:stoppr/core/utils/text_sanitizer.dart';

class SlideRightRoute extends PageRouteBuilder {
  final Widget page;
  SlideRightRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(-1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}

class ReadTheVowScreen extends StatefulWidget {
  const ReadTheVowScreen({super.key});

  @override
  State<ReadTheVowScreen> createState() => _ReadTheVowScreenState();
}

class _ReadTheVowScreenState extends State<ReadTheVowScreen> with TickerProviderStateMixin {
  final List<List<Offset>> _signatureStrokes = [];
  List<Offset> _currentStroke = [];
  final OnboardingProgressService _progressService = OnboardingProgressService();
  String _currentDate = '';
  bool _hasSignature = false;
  bool _isSigningComplete = false;
  String _firstName = 'You';

  @override
  void initState() {
    super.initState();
    
    // Format current date like "4 Jul 2025"
    final now = DateTime.now();
    _currentDate = DateFormat('d MMM yyyy').format(now);

    // Load first name for personalization
    _loadUserData();

    // Save current screen state
    _saveCurrentScreen();

    // Mixpanel tracking
    MixpanelService.trackEvent('Onboarding Read The Vow Screen: Page Viewed');
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.readTheVowScreen);
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedFirstName = prefs.getString('user_first_name');
      if (savedFirstName != null && savedFirstName.isNotEmpty) {
        if (mounted) {
          setState(() {
            _firstName = savedFirstName;
          });
        }
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser?.displayName != null && currentUser!.displayName!.isNotEmpty) {
        final parts = currentUser.displayName!.split(' ');
        if (parts.isNotEmpty && mounted) {
          setState(() {
            _firstName = parts.first;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading first name (ReadTheVow): $e');
    }
  }

    void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentStroke = [details.localPosition];
      _hasSignature = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentStroke.add(details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      if (_currentStroke.isNotEmpty) {
        _signatureStrokes.add(List.from(_currentStroke));
        _currentStroke.clear();
      }
    });
  }

  void _clearSignature() {
    // Track clear signature event
    MixpanelService.trackEvent('Onboarding Read The Vow Screen: Button Tap', properties: {
      'action': 'signature_cleared',
      'had_signature': _hasSignature,
    });

    setState(() {
      _signatureStrokes.clear();
      _currentStroke.clear();
      _hasSignature = false;
      _isSigningComplete = false;
    });
  }

  void _onButtonTap() {
    if (!_isSigningComplete) {
      // Track button tap event
      MixpanelService.trackEvent('Onboarding Read The Vow Screen: Button Tap', properties: {
        'action': 'button_tapped',
        'has_signature': _hasSignature,
      });

      setState(() {
        _isSigningComplete = true;
      });
      
      // Provide haptic feedback
      HapticFeedback.mediumImpact();
      
      // Navigate to OnboardingCard2Screen after a brief delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => 
                const OnboardingCard2Screen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOutCubic;
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 400; // iPhone 16 Plus and similar

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for white background
        statusBarBrightness: Brightness.light, // For iOS
      ),
      child: Scaffold(
        backgroundColor: Colors.white, // White background branding
        body: SafeArea(
          child: Stack(
            children: [
              // Main content - scrollable
              Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isLargeScreen ? 500 : 400),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 100, top: 20, left: 20, right: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Title
                        Text(
                          l10n.translate('readTheVow_title'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            color: Colors.black, // Pure black for maximum contrast
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Vow content
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Vow text
                              Builder(
                                builder: (_) {
                                  final base = l10n.translate('readTheVow_vowText');
                                  final vow = base.replaceAll('{firstName}', _firstName);
                                  final idx = vow.indexOf(_firstName);
                                  final baseStyle = TextStyle(
                                    fontFamily: 'ElzaRound',
                                    color: Colors.black,
                                    fontSize: isLargeScreen ? 17 : 15,
                                    fontWeight: FontWeight.w400,
                                    height: 1.5,
                                    fontStyle: FontStyle.italic,
                                  );
                                  if (idx < 0) {
                                    return Text(vow, style: baseStyle);
                                  }
                                  final safeFirstName = TextSanitizer.sanitizeForDisplay(_firstName);
                                  final safeVow = vow.replaceAll(_firstName, safeFirstName);
                                  final safeIdx = safeVow.indexOf(safeFirstName);
                                  return RichText(
                                    text: TextSpan(
                                      style: baseStyle,
                                      children: [
                                        TextSpan(
                                          text: TextSanitizer.safeSubstring(
                                            safeVow,
                                            0,
                                            safeIdx,
                                          ),
                                        ),
                                        TextSpan(
                                          text: safeFirstName,
                                          style: baseStyle.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(
                                          text: TextSanitizer.safeSubstring(
                                            safeVow,
                                            safeIdx + safeFirstName.length,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Date
                              Text(
                                _currentDate,
                                style: TextStyle(
                                  fontFamily: 'ElzaRound',
                                  color: Colors.black, // Pure black for better readability
                                  fontSize: isLargeScreen ? 20 : 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Signature area
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          child: Container(
                            height: 160,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA), // Light gray background
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.4), // Darker border for definition
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                // FIRST: Background elements that should not interfere
                                // Fingerprint icon in center - fades out when signing
                                IgnorePointer(
                                  ignoring: true,
                                  child: AnimatedOpacity(
                                    opacity: _hasSignature ? 0.0 : 0.4,
                                    duration: const Duration(milliseconds: 300),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.fingerprint,
                                            size: 50,
                                            color: Color(0xFF333333), // Darker icon for better visibility
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            l10n.translate('readTheVow_signatureInstruction'),
                                            style: TextStyle(
                                              fontFamily: 'ElzaRound',
                                              color: Color(0xFF333333), // Darker text for better visibility
                                              fontSize: isLargeScreen ? 14 : 13,
                                              fontWeight: FontWeight.w500, // Slightly bolder
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // LAST: Gesture detector on top to catch ALL touches
                                Positioned.fill(
                                  child: GestureDetector(
                                    onPanStart: _onPanStart,
                                    onPanUpdate: _onPanUpdate,
                                    onPanEnd: _onPanEnd,
                                    dragStartBehavior: DragStartBehavior.down,
                                    onPanCancel: () {
                                      setState(() {
                                        if (_currentStroke.isNotEmpty) {
                                          _signatureStrokes.add(List.from(_currentStroke));
                                          _currentStroke.clear();
                                        }
                                      });
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: CustomPaint(
                                      painter: SignaturePainter(
                                        strokes: _signatureStrokes,
                                        currentStroke: _currentStroke,
                                        isDarkTheme: false, // Light theme
                                      ),
                                      size: Size.infinite,
                                    ),
                                  ),
                                ),
                                
                                // Clear button on top of everything
                                if (_hasSignature)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: _clearSignature,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.9),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.grey.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.clear,
                                          color: Color(0xFF666666), // Gray icon for light theme
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Disclaimer
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          child: Text(
                            l10n.translate('readTheVow_signatureDisclaimer'),
                            style: TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Color(0xFF555555), // Darker gray for better readability
                              fontSize: isLargeScreen ? 12 : 11,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Continue button at bottom
              Positioned(
                bottom: 20, // Further down for better spacing
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: GestureDetector(
                    onTap: _hasSignature ? _onButtonTap : null,
                    child: Opacity(
                      opacity: _hasSignature ? 1.0 : 0.5,
                      child: Container(
                        width: double.infinity,
                        height: 56,
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isSigningComplete) ...[
                              const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _isSigningComplete
                                  ? l10n.translate('readTheVow_signed')
                                  : l10n.translate('readTheVow_continueButton'),
                              style: TextStyle(
                                fontFamily: 'ElzaRound',
                                color: Colors.white,
                                fontSize: isLargeScreen ? 20 : 19,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!_isSigningComplete) ...[
                              const SizedBox(width: 8),
                              const Text(
                                '→',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom painter for signature
class SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final bool isDarkTheme;

  const SignaturePainter({
    required this.strokes,
    required this.currentStroke,
    this.isDarkTheme = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFed3272)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Draw completed strokes
    for (final stroke in strokes) {
      if (stroke.length > 1) {
        final path = Path();
        path.moveTo(stroke[0].dx, stroke[0].dy);
        
        for (int i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx, stroke[i].dy);
        }
        
        canvas.drawPath(path, paint);
      } else if (stroke.length == 1) {
        // Draw a dot for single point
        canvas.drawCircle(stroke[0], 1.5, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke; // Reset style
      }
    }

    // Draw current stroke
    if (currentStroke.length > 1) {
      final path = Path();
      path.moveTo(currentStroke[0].dx, currentStroke[0].dy);
      
      for (int i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].dx, currentStroke[i].dy);
      }
      
      canvas.drawPath(path, paint);
    } else if (currentStroke.length == 1) {
      // Draw a dot for single point
      canvas.drawCircle(currentStroke[0], 1.5, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 