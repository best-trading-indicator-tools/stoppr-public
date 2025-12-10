import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:stoppr/core/accountability/accountability_service.dart';
import 'package:stoppr/features/accountability/data/models/accountability_partner.dart';
import 'package:stoppr/features/accountability/data/models/partnership.dart';
import 'package:stoppr/features/accountability/data/repositories/accountability_repository.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/navigation/page_transitions.dart';
import 'package:share_plus/share_plus.dart';
import 'package:stoppr/core/streak/sharing_service.dart';
import 'package:stoppr/core/accountability/accountability_widget_service.dart';
import 'package:stoppr/core/streak/streak_service.dart';
import 'package:stoppr/core/notifications/notification_service.dart';
import '../widgets/partner_card_widget.dart';
import '../widgets/invite_friend_button.dart';
import '../widgets/pending_request_card.dart';
import '../widgets/unpair_confirmation_dialog.dart';
import '../widgets/partner_request_dialog.dart';
import '../widgets/available_partners_list.dart';
import '../../data/repositories/accountability_repository.dart';

/// Main screen for managing accountability partnerships
/// Shows current partner status, find partner options, and pending requests
class AccountabilityPartnerScreen extends StatefulWidget {
  const AccountabilityPartnerScreen({super.key});

  @override
  State<AccountabilityPartnerScreen> createState() =>
      _AccountabilityPartnerScreenState();
}

class _AccountabilityPartnerScreenState
    extends State<AccountabilityPartnerScreen> {
  final AccountabilityService _accountabilityService =
      AccountabilityService.instance;
  final AccountabilityRepository _repository = AccountabilityRepository();

  AccountabilityPartner? _currentPartner;
  List<Partnership> _pendingRequests = [];
  List<Partnership> _outgoingRequests = [];
  bool _isLoadingPartner = true;
  bool _isLoadingRequests = true;
  bool _isInPool = false;
  bool _isJoiningPool = false;
  bool _isInviting = false;
  bool _isAcceptingRequest = false;
  Timer? _poolCheckTimer;

  @override
  void initState() {
    super.initState();

    // Track page view
    MixpanelService.trackPageView('Accountability Partner Screen');

    // Force dark status bar icons for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadPartnerData(),
      _loadPendingRequests(),
      _loadOutgoingRequests(),
    ]);
    // Don't auto-check pool status - only when user clicks "Find Random Partner"
    
    // Update accountability widget
    if (kDebugMode) {
      debugPrint('🧪 Updating accountability widget with debug data...');
    }
    AccountabilityWidgetService.instance.updateWidget();
  }

  Future<void> _loadPartnerData() async {
    setState(() => _isLoadingPartner = true);

    try {
      final partner = await _repository.getMyPartnerData();
      if (mounted) {
        setState(() {
          _currentPartner = partner;
          _isLoadingPartner = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading partner data: $e');
      if (mounted) {
        setState(() => _isLoadingPartner = false);
      }
    }
  }

  Future<void> _loadPendingRequests() async {
    setState(() => _isLoadingRequests = true);

    try {
      final requests = await _accountabilityService.getPendingRequests();
      if (mounted) {
        setState(() {
          _pendingRequests = requests;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending requests: $e');
      if (mounted) {
        setState(() => _isLoadingRequests = false);
      }
    }
  }

  Future<void> _loadOutgoingRequests() async {
    try {
      final requests = await _repository.getOutgoingPendingRequests();
      if (mounted) {
        setState(() {
          _outgoingRequests = requests;
        });
      }
    } catch (e) {
      debugPrint('Error loading outgoing requests: $e');
    }
  }

  /// Check and request notification permissions before sending partnership request
  /// Returns true if permissions are granted, false otherwise
  Future<bool> _checkAndRequestNotificationPermission() async {
    try {
      // Request permissions using the same method as onboarding
      // This handles both local notifications AND Firebase Messaging permissions
      debugPrint('📱 Requesting notification permissions for accountability...');
      final granted = await NotificationService().initializeOnboardingNotifications(
        context: 'accountability_partner',
        forceRequest: true,
      );
      
      if (granted) {
        debugPrint('✅ Notification permissions granted');
        // Register FCM token now that permissions are granted
        await _registerFCMToken();
      } else {
        debugPrint('❌ Notification permissions denied');
      }
      
      return granted;
    } catch (e) {
      debugPrint('Error checking/requesting notification permissions: $e');
      // If there's an error, continue anyway (don't block the flow)
      return true;
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
        debugPrint('✅ FCM token saved to Firestore: ${fcmToken.substring(0, 20)}...');
      } else {
        debugPrint('⚠️  FCM token is still null after requesting permissions');
      }
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  Future<void> _onFindPartner() async {
    // Track button tap
    MixpanelService.trackButtonTap('Find Random Partner', screenName: 'Accountability Partner Screen');

    final l10n = AppLocalizations.of(context)!;

    // Check and request notification permissions first
    final hasPermission = await _checkAndRequestNotificationPermission();
    if (!hasPermission) {
      _showMessage(l10n.translate('accountability_notifications_required'));
      return;
    }

    // DEBUG/TESTFLIGHT: Show fake incoming request for UI testing
    if (kDebugMode) {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'test_user';
      final fakeRequest = Partnership(
        id: 'debug_request_${DateTime.now().millisecondsSinceEpoch}',
        user1Id: 'debug_sender_id',
        user2Id: currentUserId,
        user1Name: 'Sarah M.',
        user2Name: 'You',
        status: 'pending',
        initiatedBy: 'debug_sender_id',
        inviteMethod: 'random',
        createdAt: DateTime.now(),
      );
      
      setState(() {
        _pendingRequests = [fakeRequest, ..._pendingRequests];
      });
      
      _showMessage('🧪 Debug: Fake incoming request added!');
      return;
    }

    // Check if already has active partner
    if (_currentPartner?.status == 'paired' && _currentPartner?.partnerId != null) {
      _showMessage(l10n.translate('accountability_already_paired'));
      return;
    }

    setState(() => _isJoiningPool = true);

    try {
      // First join the pool
      await _accountabilityService.joinPool();

      // Then immediately get available partners and pick a random one
      var availablePartners = await _repository.getPoolUsers(limit: 50);
      
      // Filter out users who already have pending requests from current user
      final pendingUserIds = _outgoingRequests
          .map((request) => request.user2Id)
          .toSet();
      
      availablePartners = availablePartners
          .where((partner) => !pendingUserIds.contains(partner.userId))
          .toList();
      
      if (availablePartners.isEmpty) {
        if (mounted) {
          setState(() {
            _isJoiningPool = false;
            _isInPool = true;
          });
          _showMessage(l10n.translate('accountability_finding_partner'));
          _startPoolPolling();
        }
        return;
      }

      // Pick a random partner
      final random = availablePartners[DateTime.now().millisecond % availablePartners.length];
      
      // Send them a request immediately
      await _accountabilityService.sendPartnerRequest(
        partnerId: random.userId,
        partnerName: random.firstName,
        inviteMethod: 'random_match',
      );

      if (mounted) {
        setState(() => _isJoiningPool = false);
        _showPartnerRequestBanner(random.firstName, random.currentStreak);
        await _loadData();
      }
    } catch (e) {
      debugPrint('Error finding random partner: $e');

      if (mounted) {
        setState(() => _isJoiningPool = false);

        _showMessage(
          e.toString().contains('subscription')
              ? l10n.translate('accountability_subscription_required')
              : l10n.translate('accountability_error_joining_pool'),
        );
      }
    }
  }

  Future<void> _onSelectSpecificPartner(PoolEntry partner) async {
    // Track button tap
    MixpanelService.trackButtonTap('Select Specific Partner', screenName: 'Accountability Partner Screen');

    final l10n = AppLocalizations.of(context)!;

    // Check and request notification permissions first
    final hasPermission = await _checkAndRequestNotificationPermission();
    if (!hasPermission) {
      _showMessage(l10n.translate('accountability_notifications_required'));
      return;
    }

    // Check if already has active partner
    if (_currentPartner?.status == 'paired' && _currentPartner?.partnerId != null) {
      _showMessage(l10n.translate('accountability_already_paired'));
      return;
    }

    // Check if already sent request to this user
    final hasPendingRequest = _outgoingRequests.any(
      (request) => request.user2Id == partner.userId
    );
    
    if (hasPendingRequest) {
      _showMessage(l10n.translate('accountability_request_already_sent'));
      return;
    }

    // Show confirmation bottom sheet
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPartnerConfirmationSheet(partner, l10n),
    );

    if (confirmed == true && mounted) {
      try {
        // Send partnership request
        await _accountabilityService.sendPartnerRequest(
          partnerId: partner.userId,
          partnerName: partner.firstName,
          inviteMethod: 'direct_select',
        );
        
        if (mounted) {
          _showMessage('Request sent to ${partner.firstName}! 🎉');
          await _loadData(); // Refresh to show pending request
        }
      } catch (e) {
        debugPrint('Error sending request: $e');
        if (mounted) {
          _showMessage(l10n.translate('accountability_error_joining_pool'));
        }
      }
    }
  }

  Widget _buildPartnerConfirmationSheet(PoolEntry partner, AppLocalizations l10n) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Partner avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),

          // Partner name
          Text(
            partner.firstName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              fontFamily: 'ElzaRound',
            ),
          ),
          const SizedBox(height: 8),

          // Streak info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFAE6EC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Color(0xFFed3272),
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '${partner.currentStreak} ${partner.currentStreak == 1 ? "day" : "days"} sugar-free',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFed3272),
                    fontFamily: 'ElzaRound',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Explanation text
          Text(
            l10n.translate('accountability_send_request_title').replaceAll('{name}', partner.firstName),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
              fontFamily: 'ElzaRound',
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.translate('accountability_send_request_explanation'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF666666),
              fontFamily: 'ElzaRound',
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Send request button
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFed3272).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  l10n.translate('accountability_send_request_button'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Cancel button
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              l10n.translate('accountability_cancel_button'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF666666),
                fontFamily: 'ElzaRound',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onInviteFriend() async {
    // Track button tap
    MixpanelService.trackButtonTap('Invite Friend', screenName: 'Accountability Partner Screen');

    final l10n = AppLocalizations.of(context)!;

    setState(() => _isInviting = true);

    try {
      // Generate invite link
      final inviteLink = await SharingService.instance.generateAccountabilityInviteLink();

      if (inviteLink == null) {
        if (mounted) {
          setState(() => _isInviting = false);
          _showMessage(l10n.translate('accountability_error_generating_link'));
        }
        return;
      }

      // Track invite sent
      MixpanelService.trackEvent('Accountability Invite Sent');

      // Get current user's own streak for message
      final currentStreak = StreakService().currentStreak.days;

      // Build share message
      final message = Platform.isIOS
          ? l10n.translate('accountability_invite_message_ios')
              .replaceAll('{days}', currentStreak.toString())
              .replaceAll('{link}', inviteLink)
          : l10n.translate('accountability_invite_message_android')
              .replaceAll('{days}', currentStreak.toString())
              .replaceAll('{link}', inviteLink);

      if (!mounted) return;

      // Share
      debugPrint('Opening share dialog with message: ${message.substring(0, 50)}...');
      final result = await Share.share(
        message,
        subject: l10n.translate('accountability_invite_subject'),
      );
      debugPrint('Share result status: ${result.status}');

      if (mounted) {
        setState(() => _isInviting = false);
      }
    } catch (e) {
      debugPrint('Error inviting friend: $e');
      if (mounted) {
        setState(() => _isInviting = false);
        _showMessage(l10n.translate('accountability_error_inviting'));
      }
    }
  }

  Future<void> _onAcceptRequest(Partnership partnership) async {
    // Track button tap
    MixpanelService.trackButtonTap('Accept Partner Request', screenName: 'Accountability Partner Screen');

    final l10n = AppLocalizations.of(context)!;

    // DEBUG: Handle fake debug requests locally and simulate full partnership
    if (kDebugMode && partnership.id.startsWith('debug_request_')) {
      setState(() {
        _isAcceptingRequest = true;
      });
      
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      setState(() {
        _pendingRequests.removeWhere((r) => r.id == partnership.id);
        
        // Simulate what Cloud Function does - update partner data
        _currentPartner = AccountabilityPartner(
          partnerId: partnership.user1Id,
          partnerFirstName: partnership.user1Name,
          partnerStreak: 42, // Fake streak for debug
          status: 'paired',
          pairedAt: DateTime.now(),
          lastSyncedAt: DateTime.now(),
        );
        _isAcceptingRequest = false;
      });
      _showMessage('🧪 Debug: Fake request accepted - partner card updated!');
      return;
    }

    setState(() => _isAcceptingRequest = true);

    try {
      await _accountabilityService.acceptPartnerRequest(partnership.id);

      // Track event
      MixpanelService.trackEvent('Accountability Partner Paired', properties: {
        'method': partnership.inviteMethod,
      });

      // Only reload partner data and pending requests (skip heavy available partners list)
      await Future.wait([
        _loadPartnerData(),
        _loadPendingRequests(),
      ]);

      if (mounted) {
        setState(() => _isAcceptingRequest = false);
        _showMessage(l10n.translate('accountability_partnership_accepted'));
      }
    } catch (e) {
      debugPrint('Error accepting request: $e');
      if (mounted) {
        setState(() => _isAcceptingRequest = false);
        _showMessage(l10n.translate('accountability_error_accepting'));
      }
    }
  }

  Future<void> _onDeclineRequest(Partnership partnership) async {
    // Track button tap
    MixpanelService.trackButtonTap('Decline Partner Request', screenName: 'Accountability Partner Screen');

    final l10n = AppLocalizations.of(context)!;

    // DEBUG: Handle fake debug requests locally
    if (kDebugMode && partnership.id.startsWith('debug_request_')) {
      setState(() {
        _pendingRequests.removeWhere((r) => r.id == partnership.id);
      });
      _showMessage('🧪 Debug: Fake request declined (UI only)');
      return;
    }

    try {
      await _accountabilityService.declinePartnerRequest(partnership.id);

      // Reload requests
      await _loadPendingRequests();

      _showMessage(l10n.translate('accountability_request_declined'));
    } catch (e) {
      debugPrint('Error declining request: $e');
      _showMessage(l10n.translate('accountability_error_declining'));
    }
  }

  Future<void> _onUnpair() async {
    final l10n = AppLocalizations.of(context)!;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const UnpairConfirmationDialog(),
    );

    if (confirmed != true) return;

    // Track button tap
    MixpanelService.trackButtonTap('Unpair Partner', screenName: 'Accountability Partner Screen');

    try {
      await _accountabilityService.unpair();

      // Track event
      MixpanelService.trackEvent('Accountability Partner Unpairing', properties: {
        'reason': 'manual',
      });

      // Reload data
      await _loadData();

      _showMessage(l10n.translate('accountability_unpaired'));
    } catch (e) {
      debugPrint('Error unpairing: $e');
      _showMessage(l10n.translate('accountability_error_unpairing'));
    }
  }

  /// Start polling for partnership updates while in pool
  void _startPoolPolling() {
    _poolCheckTimer?.cancel();
    _poolCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || !_isInPool) {
        _poolCheckTimer?.cancel();
        return;
      }

      // Check if we got matched
      final partner = await _repository.getMyPartnerData();
      if (partner != null && partner.status == 'paired') {
        if (mounted) {
          setState(() {
            _isInPool = false;
            _currentPartner = partner;
          });
          _poolCheckTimer?.cancel();
          
          final l10n = AppLocalizations.of(context)!;
          _showMessage(l10n.translate('accountability_paired_title'));
        }
      }
    });
  }

  @override
  void dispose() {
    _poolCheckTimer?.cancel();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showPartnerRequestBanner(String partnerName, int partnerStreak) {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            // Avatar icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('accountability_request_sent_to')
                        .replaceAll('{name}', partnerName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Color(0xFFfd5d32),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$partnerStreak ${partnerStreak == 1 ? l10n.translate("day") : l10n.translate("days")}',
                        style: const TextStyle(
                          color: Color(0xFFCCCCCC),
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Success icon
            const Icon(
              Icons.check_circle,
              color: Color(0xFF4CAF50),
              size: 24,
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Future<void> _createDebugUsers() async {
    try {
      await AccountabilityService.instance.createDebugPoolUsers();
      
      // Reload data to show new users
      await Future.delayed(const Duration(seconds: 1));
      await _loadData();
      
      if (!mounted) return;
      _showMessage('✅ Debug users created!');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Error creating debug users: $e');
    }
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
        backgroundColor: const Color(0xFFFBFBFB), // Brand neutral white
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            l10n.translate('accountability_partner_title'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 20,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: _isLoadingPartner
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFed3272)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: const Color(0xFFed3272),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Subtitle
                        Text(
                          l10n.translate('accountability_partner_subtitle'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 15,
                            fontFamily: 'ElzaRound',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Current partner card or no partner state
                        if (_currentPartner?.status == 'paired' &&
                            _currentPartner?.partnerId != null)
                          PartnerCardWidget(
                            partner: _currentPartner!,
                            onUnpair: _onUnpair,
                          )
                        else
                          _buildNoPartnerCard(l10n),

                        const SizedBox(height: 24),

                        // Invite friend button (top position, white background)
                        if (_currentPartner?.status != 'paired') ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                            child: InviteFriendButton(
                              onTap: _onInviteFriend,
                              isLoading: _isInviting,
                            ),
                          ),
                        ],

                        // Pending requests (show prominently at top if no partner)
                        if (_pendingRequests.isNotEmpty && _currentPartner?.status != 'paired') ...[
                          Text(
                            l10n.translate('accountability_pending_requests'),
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 18,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._pendingRequests.map((request) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: PendingRequestCard(
                                partnership: request,
                                onAccept: () => _onAcceptRequest(request),
                                onDecline: () => _onDeclineRequest(request),
                                isLoading: _isAcceptingRequest,
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 24),
                        ],

                        // Available partners list with random button (only show if no partner)
                        if (_currentPartner?.status != 'paired')
                          AvailablePartnersList(
                            onRandomPartnerTap: _onFindPartner,
                            onPartnerSelect: _onSelectSpecificPartner,
                            outgoingPendingRequests: _outgoingRequests,
                          ),

                        const SizedBox(height: 24),

                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildNoPartnerCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFFed3272),
                  Color(0xFFfd5d32),
                ],
              ),
            ),
            child: const Icon(
              Icons.people_outline,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          
          // Title
          Text(
            l10n.translate('accountability_no_partner'),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 20,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            l10n.translate('accountability_no_partner_subtitle'),
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 15,
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

