import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/notifications/notification_service.dart';
import 'package:stoppr/features/onboarding/presentation/screens/stoppr_science_backed_plan.dart';

// This screen requests notification permission aggressively during onboarding
// and previews branded notifications. It also lets users preselect times for
// motivation and pledge reminders. On returning from the permission prompt
// (granted or denied), the flow automatically advances to the questionnaire.

class OnboardingNotificationsPermissionScreen extends StatefulWidget {
  const OnboardingNotificationsPermissionScreen({super.key});

  @override
  State<OnboardingNotificationsPermissionScreen> createState() => _OnboardingNotificationsPermissionScreenState();
}

class _OnboardingNotificationsPermissionScreenState extends State<OnboardingNotificationsPermissionScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();

  TimeOfDay? _motivationTime; // morning motivation
  TimeOfDay? _pledgeTime; // checkup/pledge reminders

  late final AnimationController _arrowController;
  late final Animation<Offset> _arrowOffset;

  bool _requestedThisSession = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Page view event
    MixpanelService.trackPageView('Onboarding Notifications Permission Screen');

    // Status bar style for white BG
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));

    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _arrowOffset = Tween<Offset>(begin: const Offset(0, 0.15), end: const Offset(0, -0.05))
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_arrowController);

    _loadInitialTimes();

    // Check if permissions are already granted or denied
    _checkPermissionStatusAndAutoSkip();
  }

  /// Check if notification permissions are already granted or denied.
  /// If a decision was already made, auto-skip after 2 seconds.
  Future<void> _checkPermissionStatusAndAutoSkip() async {
    try {
      final status = await Permission.notification.status;
      debugPrint('Notification permission status: ${status.toString()}');
      
      // New rule: If already granted → skip. Otherwise ALWAYS request.
      // Some environments may incorrectly report .denied on first run; requesting
      // ensures the system dialog appears if it hasn't been shown yet.
      if (status.isGranted) {
        debugPrint('Notification permissions already granted. Auto-skipping in 1 second.');
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && !_navigated) {
            _navigateNext();
          }
        });
        return;
      }
      
      debugPrint('Notification permissions not granted. Requesting now...');
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !_requestedThisSession) {
          _requestIfNeeded(force: true);
        }
      });
    } catch (e) {
      debugPrint('Error checking permission status: $e');
      // On error, proceed with normal flow
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && !_requestedThisSession) {
          _requestIfNeeded(force: true);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _requestedThisSession && !_navigated) {
      _navigateNext();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _arrowController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialTimes() async {
    try {
      final motivation = await _notificationService.getMotivationReminderTime();
      final pledge = await _notificationService.getPledgeReminderTime();
      if (mounted) {
        setState(() {
          _motivationTime = motivation ?? const TimeOfDay(hour: 8, minute: 42);
          _pledgeTime = pledge ?? const TimeOfDay(hour: 19, minute: 23);
        });
      }
    } catch (e) {
      debugPrint('Load initial times error: $e');
    }
  }

  /// Register FCM token to Firestore after permissions are granted
  Future<void> _registerFCMToken() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get FCM token (should work now that permissions are granted)
      final fcmToken = await FirebaseMessaging.instance.getToken();
      
      if (fcmToken != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({
          'fcmToken': fcmToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('✅ FCM token saved to Firestore from onboarding: ${fcmToken.substring(0, 20)}...');
      } else {
        debugPrint('⚠️  FCM token is still null after requesting permissions');
      }
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  Future<void> _requestIfNeeded({bool force = false}) async {
    try {
      _requestedThisSession = true;
      debugPrint('Requesting notification permissions...');
      
      final granted = await _notificationService.initializeOnboardingNotifications(
        context: 'onboarding_permission_screen',
        forceRequest: force,
      );
      
      debugPrint('Permission request completed. Granted: $granted');
      MixpanelService.trackEvent('Onboarding Notifications Permission Result', properties: {
        'granted': granted,
        'context': 'onboarding_permission_screen',
      });
      
      // Register FCM token if permissions were granted
      if (granted) {
        await _registerFCMToken();
      }
      
      // Don't navigate immediately - wait for app lifecycle to resume
      // The didChangeAppLifecycleState will handle navigation when user returns from system dialog
      // Add a fallback timeout in case lifecycle doesn't fire (shouldn't happen, but safety net)
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && !_navigated) {
          debugPrint('Fallback: Navigating after permission request timeout');
          _navigateNext();
        }
      });
    } catch (e) {
      debugPrint('Permission request error: $e');
      // On error, still wait a bit before navigating to allow system dialog to appear
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_navigated) {
          _navigateNext();
        }
      });
    }
  }

  Future<String> _getFirstNameOrFallback(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final n = prefs.getString('user_first_name');
      if (n != null && n.trim().isNotEmpty) return n.trim();
    } catch (_) {}
    return AppLocalizations.of(context)!.translate('profile_you_fallback');
  }

  void _navigateNext() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const StopprScienceBackedPlanScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title
                  Text(
                    l10n.translate('notifications_permission_title'),
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      color: Color(0xFF1A1A1A),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 20),

                  // Branded preview notification card
                  FutureBuilder<String>(
                    future: _getFirstNameOrFallback(context),
                    builder: (context, snapshot) {
                      final firstName = snapshot.data ?? '';
                      final message = l10n
                          .translate('notifications_permission_preview_message_template')
                          .replaceFirst('{name}', firstName);
                      return Container(
                        width: double.infinity,
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
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(
                                'assets/images/logo/180.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message,
                                    style: const TextStyle(
                                      color: Color(0xFF1A1A1A),
                                      fontSize: 14,
                                      fontFamily: 'ElzaRound',
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'now',
                                    style: TextStyle(
                                      color: Color(0xFF666666),
                                      fontSize: 12,
                                      fontFamily: 'ElzaRound',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 36),

                  // Simulated iOS system permission alert (visual preview only)
                  Builder(
                    builder: (context) {
                      final double screenWidth = MediaQuery.of(context).size.width;
                      final double dialogWidth = (screenWidth * 0.62).clamp(220.0, 300.0);
                      return Center(
                        child: SizedBox(
                          width: dialogWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                                      child: Column(
                                        children: [
                                          Text(
                                            '“Stoppr” ${l10n.translate('notifications_would_like_to_send_you')}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Color(0xFF1A1A1A),
                                              fontSize: 17,
                                              fontFamily: 'ElzaRound',
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            l10n.translate('notifications_permission_prompt_text'),
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Color(0xFF1A1A1A),
                                              fontSize: 11,
                                              fontFamily: 'ElzaRound',
                                              height: 1.22,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Top divider
                                    Container(height: 0.8, color: const Color(0xFFCACACA)),
                                    SizedBox(
                                      height: 44,
                                      child: Row(
                                        children: [
                                          // Don't Allow (no action)
                                          Expanded(
                                            child: InkWell(
                                              onTap: () {
                                                // Proceed without requesting system dialog
                                                _navigateNext();
                                              },
                                              child: Center(
                                                child: Text(
                                                  l10n.translate('common_dont_allow'),
                                                  style: const TextStyle(
                                                    color: Color(0xFF007AFF),
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Middle divider
                                          Container(width: 0.8, color: const Color(0xFFCACACA)),
                                          // Allow (disabled - prompt auto shown)
                                          Expanded(
                                            child: InkWell(
                                              onTap: null,
                                              child: Center(
                                                child: Text(
                                                  l10n.translate('common_allow'),
                                                  style: const TextStyle(
                                                    color: Color(0xFF007AFF),
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Arrow centered under the Allow button (right-half center)
                              SizedBox(
                                width: dialogWidth,
                                child: Align(
                                  alignment: const Alignment(0.5, 0),
                                  child: SlideTransition(
                                    position: _arrowOffset,
                                    child: const Icon(
                                      Icons.keyboard_arrow_up_rounded,
                                      size: 42,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 58),

                  // Customization title
                  Text(
                    l10n.translate('notifications_permission_customize_title'),
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      color: Color(0xFF1A1A1A),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Two small cards for time selection
                  _TimeSelectionCard(
                    title: l10n.translate('notifications_motivation_title'),
                    description: l10n.translate('notifications_motivation_description'),
                    time: _motivationTime,
                  ),
                  const SizedBox(height: 12),
                  // Pledge reminder card removed per request; only keep Motivation card
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeSelectionCard extends StatelessWidget {
  final String title;
  final String description;
  final TimeOfDay? time;

  const _TimeSelectionCard({
    required this.title,
    required this.description,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFed3272), Color(0xFFfd5d32)]),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: const Icon(Icons.bolt_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 14,
                        fontFamily: 'ElzaRound',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFBFBFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Color(0xFF666666), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.translate('meal_notification_time'),
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 15,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        time != null ? time!.format(context) : '--:--',
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 17,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, color: Color(0xFF666666), size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


