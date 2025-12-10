import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stoppr/features/community/data/models/chat_message_model.dart';
import 'package:stoppr/features/community/data/repositories/chat_repository.dart';
import 'package:stoppr/features/community/presentation/state/chat_cubit.dart';
import 'package:stoppr/core/repositories/user_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:stoppr/core/streak/achievements_service.dart';
import 'package:stoppr/core/notifications/notification_service.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/karma/karma_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:lottie/lottie.dart';

class OfficialChatScreen extends StatelessWidget {
  const OfficialChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChatCubit(
        ChatRepository(
          userRepository: UserRepository(),
          languageCode: 'en',
        ),
      ),
      child: const _OfficialChatView(),
    );
  }
}

class _OfficialChatView extends StatefulWidget {
  const _OfficialChatView();

  @override
  State<_OfficialChatView> createState() => _OfficialChatViewState();
}

class _OfficialChatViewState extends State<_OfficialChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _showTelegramBanner = true;
  bool _chatNotificationsEnabled = false;
  final KarmaService _karmaService = KarmaService();

  @override
  void initState() {
    super.initState();
    // Track Mixpanel page view event
    MixpanelService.trackEvent('Official Chat Screen Page View');
    // Set status bar icons to dark for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    _loadChatNotificationSettings();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadChatNotificationSettings() async {
    final notificationService = NotificationService();
    final enabled = await notificationService.isNotificationTypeEnabled(NotificationType.chatNotifications);
    setState(() {
      _chatNotificationsEnabled = enabled;
    });
  }
  
  void _toggleChatNotifications() async {
    final notificationService = NotificationService();
    final newValue = !_chatNotificationsEnabled;
    
    if (newValue) {
      // Request permissions if enabling notifications
      final granted = await notificationService.requestAllNotificationPermissions(context: 'chat');
      if (!granted) {
        // Show dialog explaining that permissions are needed
        if (mounted) {
          _showPermissionDialog();
        }
        return;
      }
    }
    
    await notificationService.setNotificationTypeEnabled(NotificationType.chatNotifications, newValue);
    setState(() {
      _chatNotificationsEnabled = newValue;
    });
    
    // Show elegant floating notification
    if (mounted) {
      _showFloatingNotification(
        newValue ? 'Chat notifications enabled' : 'Chat notifications disabled',
        newValue,
      );
    }
  }
  
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Permission Required',
          style: TextStyle(
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'To receive chat notifications, please enable notifications in your device settings.',
          style: TextStyle(
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showFloatingNotification(String message, bool isEnabled) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isEnabled ? Colors.green.withOpacity(0.9) : Colors.grey.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isEnabled ? Icons.notifications_active : Icons.notifications_off,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    overlay.insert(overlayEntry);
    
    // Remove the notification after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }
  
  void _showOptionsMenu() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 200, // Position from right
        MediaQuery.of(context).padding.top + kToolbarHeight + 10, // Below app bar
        20, // Right margin
        0, // Bottom not used
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              if (_chatNotificationsEnabled)
                const Icon(Icons.check, color: Color(0xFFed3272), size: 20)
              else
                const SizedBox(width: 20),
              const SizedBox(width: 12),
              const Text(
                'Enable Notifications',
                style: TextStyle(
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          onTap: () {
            // Delay to allow popup to close
            Future.delayed(const Duration(milliseconds: 100), () {
              _toggleChatNotifications();
            });
          },
        ),
      ],
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      elevation: 8,
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      context.read<ChatCubit>().sendMessage(text);
      _messageController.clear();
      _focusNode.unfocus();
      
      // Grant karma for posting a message
      _karmaService.grantKarmaForMessage();
    }
  }

  void _openTelegramGroup() async {
    final Uri url = Uri.parse('https://t.me/+SKqx1P0D3iljZGRh');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not open Telegram group');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB), // Updated neutral background
        extendBodyBehindAppBar: false,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: const Color(0xFFFBFBFB), // Updated neutral background
          elevation: 0,
          centerTitle: true,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'STOPPR Official Chat',
            style: TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: Color(0xFF1A1A1A),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert, color: Color(0xFF1A1A1A)),
              onPressed: () {
                _showOptionsMenu();
              },
            ),
          ],
        ),
        body: Container(
          color: const Color(0xFFFBFBFB), // Updated neutral background
          child: Column(
            children: [
                // Spacing for content
                const SizedBox(height: 20),
                
                // Telegram banner
                if (_showTelegramBanner)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFed3272), // Brand pink
                              Color(0xFFfd5d32), // Brand orange
                            ],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFed3272).withOpacity(0.10),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  MixpanelService.trackEvent('Official Chat Screen Telegram Banner Tap');
                                  _openTelegramGroup();
                                },
                                child: const Text(
                                  'Click here to Join our Telegram chat',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: () {
                                MixpanelService.trackEvent('Official Chat Screen Telegram Banner Close Tap');
                                setState(() {
                                  _showTelegramBanner = false;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Color(0xFFed3272), size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Chat messages
                Expanded(
                  child: BlocBuilder<ChatCubit, ChatState>(
                    builder: (context, state) {
                      return state.when(
                        initial: () => const Center(
                          child: CircularProgressIndicator(color: Color(0xFFed3272)),
                        ),
                        loading: () => const Center(
                          child: CircularProgressIndicator(color: Color(0xFFed3272)),
                        ),
                        loaded: (messages) {
                          if (messages.isEmpty) {
                            return Center(
                              child: Text(
                                'No messages yet. Be the first to say hello!',
                                style: TextStyle(
                                  fontFamily: 'ElzaRound',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF666666),
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isCurrentUser = currentUserId != null && 
                                  message.userId == currentUserId;
                              
                              return _MessageBubble(
                                message: message,
                                isCurrentUser: isCurrentUser,
                                onDelete: (isCurrentUser || kDebugMode)
                                    ? () => context.read<ChatCubit>().deleteMessage(message.id)
                                    : null,
                                onBlock: !isCurrentUser && currentUserId != null
                                    ? () {
                                        final repository = context.read<ChatCubit>().repository;
                                        repository.blockUser(
                                          currentUserId,
                                          message.userId,
                                          message.userName,
                                        );
                                      }
                                    : null,
                              );
                            },
                          );
                        },
                        error: (error) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Error: $error',
                              style: const TextStyle(
                                fontFamily: 'ElzaRound',
                                color: Colors.redAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // Input field (background extends to bottom)
                Builder(
                  builder: (context) {
                    final bottomInset = MediaQuery.of(context).padding.bottom;
                    return Container(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0).withOpacity(0.3),
                        border: const Border(
                          top: BorderSide(
                            color: Color(0xFFE0E0E0),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              focusNode: _focusNode,
                              style: const TextStyle(
                                fontFamily: 'ElzaRound',
                                fontSize: 16,
                                color: Color(0xFF1A1A1A),
                              ),
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)!.translate('chat_messageHint'),
                                hintStyle: const TextStyle(
                                  fontFamily: 'ElzaRound',
                                  fontSize: 16,
                                  color: Color(0xFF666666),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE0E0E0),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE0E0E0),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFed3272),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              maxLines: null,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFFed3272), // Brand pink
                                  Color(0xFFfd5d32), // Brand orange
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_upward,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: _sendMessage,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                padding: const EdgeInsets.all(8),
                                minimumSize: const Size(36, 36),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isCurrentUser;
  final VoidCallback? onDelete;
  final VoidCallback? onBlock;

  const _MessageBubble({
    required this.message,
    required this.isCurrentUser,
    this.onDelete,
    this.onBlock,
  });
  
  Widget _buildFallbackAvatar() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF666666).withOpacity(0.3),
      ),
      child: const Icon(
        Icons.stars,
        color: Color(0xFF666666),
        size: 14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(message.createdAt);
    final displayName = message.isAnonymous ? 'Anonymous' : message.userName;

    Widget stoneAvatar(String userId) {
      // If this is a sample message and has streak_days, use it directly
      if (message.sample && message.streak_days != null) {
        final int streak = message.streak_days!;
        final achievements = AchievementsService.availableAchievements;
        final unlocked = achievements.where((a) => streak >= a.daysRequired).toList();
        final achievement = unlocked.isNotEmpty ? unlocked.last : achievements.first;
        
        // Wrap in try-catch for more robust error handling
        try {
          return Container(
            width: 24,
            height: 24,
            child: Lottie.asset(
              achievement.imageAsset,
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              animate: true,
              repeat: true,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Error loading rosace Lottie in chat: $error');
                return _buildFallbackAvatar();
              },
            ),
          );
        } catch (e) {
          debugPrint('Error creating rosace Lottie widget: $e');
          return _buildFallbackAvatar();
        }
      }
      // Otherwise, use the user's real streak (current logic)
      return FutureBuilder<Map<String, dynamic>?> (
        future: UserRepository().getUserProfile(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFed3272)),
            );
          }
          final data = snapshot.data;
          int streak = 0;
          if (data != null && data['currentStreakDays'] is int) {
            streak = data['currentStreakDays'] as int;
          }
          final achievements = AchievementsService.availableAchievements;
          final unlocked = achievements.where((a) => streak >= a.daysRequired).toList();
          final achievement = unlocked.isNotEmpty ? unlocked.last : achievements.first;
          
          // Wrap in try-catch for more robust error handling
          try {
            return Container(
              width: 24,
              height: 24,
              child: Lottie.asset(
                achievement.imageAsset,
                width: 24,
                height: 24,
                fit: BoxFit.contain,
                animate: true,
                repeat: true,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Error loading rosace Lottie in chat: $error');
                  return _buildFallbackAvatar();
                },
              ),
            );
          } catch (e) {
            debugPrint('Error creating rosace Lottie widget: $e');
            return _buildFallbackAvatar();
          }
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // Message content
          Flexible(
            child: Column(
              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Username with stone avatar
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      stoneAvatar(message.userId),
                      const SizedBox(width: 10),
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
                // Message bubble
                GestureDetector(
                  onLongPress: (onDelete != null || onBlock != null)
                      ? () => _showActionSheet(context)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: isCurrentUser 
                          ? const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFed3272), // Brand pink
                                Color(0xFFfd5d32), // Brand orange
                              ],
                            )
                          : null,
                      color: isCurrentUser ? null : const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        fontFamily: 'ElzaRound',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isCurrentUser 
                            ? Colors.white 
                            : const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    final title = kDebugMode && !isCurrentUser 
        ? 'Delete Message (Debug Mode)' 
        : 'Delete Message';
    final content = kDebugMode && !isCurrentUser
        ? 'Are you sure you want to delete this message? (Debug mode allows deleting any message)'
        : 'Are you sure you want to delete this message?';
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content,
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Cancel = Primary CTA (gradient)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFFed3272),
                            Color(0xFFfd5d32),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFed3272)
                                .withOpacity(0.10),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        AppLocalizations.of(context)!
                            .translate('common_cancel'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Delete = Secondary (gray background)
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFE0E0E0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      onDelete?.call();
                    },
                    child: Text(
                      AppLocalizations.of(context)!
                          .translate('common_delete'),
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Color(0xFF1A1A1A),
                      ),
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

  void _showActionSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Block User option (only for other users' messages)
            if (!isCurrentUser && onBlock != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFed3272).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.block,
                    color: Color(0xFFed3272),
                    size: 20,
                  ),
                ),
                title: Text(
                  l10n.translate('block_user'),
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showBlockDialog(context);
                },
              ),
            // Delete option (for current user or debug mode)
            if (onDelete != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF666666).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFF666666),
                    size: 20,
                  ),
                ),
                title: Text(
                  l10n.translate('common_delete'),
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showDeleteDialog(context);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showBlockDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          l10n.translate('block_user_title').replaceAll(
                '{username}',
                message.userName,
              ),
          style: const TextStyle(
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          l10n.translate('block_user_message'),
          style: const TextStyle(
            fontFamily: 'ElzaRound',
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: Color(0xFF666666),
          ),
        ),
        actions: [
          Row(
            children: [
              // Cancel button
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFE0E0E0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    l10n.translate('block_user_cancel'),
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Block button (gradient)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    onBlock?.call();
                  },
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFed3272),
                          Color(0xFFfd5d32),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFed3272).withOpacity(0.10),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.translate('block_user_confirm'),
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
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