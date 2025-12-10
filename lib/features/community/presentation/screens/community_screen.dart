import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stoppr/features/community/data/models/post_model.dart';
import 'package:stoppr/features/community/data/repositories/community_repository.dart';
import 'package:stoppr/features/community/presentation/screens/add_post_screen.dart';
import 'package:stoppr/features/community/presentation/screens/community_rules_screen.dart';
import 'package:stoppr/features/community/presentation/screens/post_detail_screen.dart';
import 'package:stoppr/features/community/presentation/state/community_cubit.dart';
import 'package:stoppr/features/community/presentation/widgets/post_list_item.dart';
import 'package:stoppr/features/community/presentation/screens/language_chat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get current user ID
import 'package:flutter/services.dart'; // Import for SystemChrome
import 'package:flutter/foundation.dart'; // For kDebugMode constant
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide the Cubit to the widget tree
    return BlocProvider(
      // Read the RepositoryProvider from context
      create: (context) => CommunityCubit(context.read<CommunityRepository>()),
      child: const _CommunityView(),
    );
  }
}

class _CommunityView extends StatefulWidget {
  const _CommunityView();

  @override
  State<_CommunityView> createState() => _CommunityViewState();
}

class _CommunityViewState extends State<_CommunityView> {
  @override
  void initState() {
    super.initState();
    // Set status bar icons to dark for white background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color primaryTextColor = const Color(0xFF1A1A1A); // Brand dark text
    final Color secondaryTextColor = const Color(0xFF666666); // Brand gray text
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB), // Updated neutral background
        extendBodyBehindAppBar: false,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: const Color(0xFFFBFBFB), // Updated neutral background
          elevation: 0,
          centerTitle: false,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          title: Text(
            AppLocalizations.of(context)!.translate('community_title'),
            style: TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w700, 
              fontSize: 24,
              color: primaryTextColor,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.menu_book, color: primaryTextColor), 
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CommunityRulesScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            child: _buildForumTab(context, currentUserId, secondaryTextColor),
          ),
        ),
        
        floatingActionButton: Container(
          margin: const EdgeInsets.only(bottom: 100.0),
          width: 70.0,
          height: 70.0,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFed3272), // Brand pink
                Color(0xFFfd5d32), // Brand orange
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFed3272).withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              borderRadius: BorderRadius.circular(35.0),
              onTap: () => _navigateToAddPost(context),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 34.0,
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildForumTab(BuildContext context, String? currentUserId, Color secondaryTextColor) {
    return Column(
      children: [
        _buildLanguageChatRooms(context),
        _buildSortDropdown(context, secondaryTextColor),
        Expanded(
          child: BlocBuilder<CommunityCubit, CommunityState>(
            builder: (context, state) {
              return state.when(
                initial: () => const Center(child: CircularProgressIndicator(color: Color(0xFFed3272))),
                loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFed3272))),
                loaded: (posts, sortOrder) {
                  if (posts.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.2),
                        child: Text(
                          'No posts yet. Be the first to start a discussion!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'ElzaRound',
                            color: secondaryTextColor, 
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }
                  return RefreshIndicator(
                     onRefresh: () async {
                        // Re-fetch posts using the current sort order when pulled
                        context.read<CommunityCubit>().changeSortOrder(sortOrder);
                     },
                     color: const Color(0xFFed3272),
                     backgroundColor: Colors.white,
                     child: ListView.builder(
                       padding: const EdgeInsets.only(top: 0, bottom: 72.0), // Reduced top padding to close gap with "New" dropdown
                       itemCount: posts.length,
                       itemBuilder: (context, index) {
                         final post = posts[index];
                         final bool isUpvotedByUser = currentUserId != null && post.upvotedBy.contains(currentUserId);
                         return PostListItem(
                           post: post,
                           currentUserId: currentUserId,
                           isUpvotedByUser: isUpvotedByUser,
                           onTap: () async {
                             // Get cubit and current sort order BEFORE the await
                             final cubit = context.read<CommunityCubit>();
                             // Ensure we get the sortOrder from the current state safely
                             final currentSortOrder = cubit.state.maybeWhen(
                               loaded: (_, order) => order,
                               orElse: () => PostSortOrder.newest, // Fallback if state is not loaded
                             );
                             
                             debugPrint('[CommunityScreen] Navigating to PostDetailScreen for post ID: ${post.id}');
                             // Wait for a result from PostDetailScreen
                             final result = await Navigator.of(context).push(MaterialPageRoute(
                               builder: (_) => PostDetailScreen(postId: post.id),
                             ));
                               
                             debugPrint('[CommunityScreen] Returned from PostDetailScreen. Result: $result (Type: ${result.runtimeType})');
                             
                             // If the post was deleted (result == true), refresh the posts list
                             if (result == true) {
                               debugPrint('Post was deleted, refreshing posts list');
                               // Use the captured cubit and sortOrder
                               cubit.refreshPosts(); 
                             }
                           },
                           onUpvote: () {
                             // Generate a consistent anonymous ID if user is not logged in
                             final String userId = currentUserId ?? 'anon_${DateTime.now().millisecondsSinceEpoch}';
                             context.read<CommunityCubit>().upvotePost(post.id, userId);
                           },
                         );
                       },
                     ),
                  );
                },
                error: (message) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    // Use SelectableText.rich for inline error display
                    child: SelectableText.rich(
                      TextSpan(
                        text: 'Error loading posts: \n', 
                        style: TextStyle(
                          fontFamily: 'ElzaRound',
                          color: secondaryTextColor, 
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: message,
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Colors.redAccent, 
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageChatRooms(BuildContext context) {
    const Map<String, String> languageFlags = {
      'en': '🇺🇸',
      'es': '🇪🇸',
      'de': '🇩🇪',
      'zh': '🇨🇳',
      'ru': '🇷🇺',
      'fr': '🇫🇷',
      'sk': '🇸🇰',
      'cs': '🇨🇿',
      'it': '🇮🇹',
      'pl': '🇵🇱',
    };

    const Map<String, String> languageNames = {
      'en': 'English',
      'es': 'Español',
      'de': 'Deutsch',
      'zh': '中文',
      'ru': 'Русский',
      'fr': 'Français',
      'sk': 'Slovenčina',
      'cs': 'Čeština',
      'it': 'Italiano',
      'pl': 'Polski',
    };

    final ScrollController scrollController = ScrollController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            AppLocalizations.of(context)!.translate('community_chatRooms'),
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: Stack(
            children: [
              ListView.builder(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16, right: 80),
                itemCount: languageFlags.length,
                itemBuilder: (context, index) {
                  final languageCode = languageFlags.keys.elementAt(index);
                  final flag = languageFlags[languageCode]!;
                  final languageName = languageNames[languageCode]!;

                  return GestureDetector(
                    onTap: () {
                      MixpanelService.trackButtonTap('Community Language Chat Room Tap',
                        additionalProps: {'language': languageCode}
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LanguageChatScreen(languageCode: languageCode),
                        ),
                      );
                    },
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFed3272),
                            Color(0xFFfd5d32),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFed3272).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            flag,
                            style: const TextStyle(fontSize: 48),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            languageName,
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Gradient fade on the right to indicate more content
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () {
                    MixpanelService.trackButtonTap('Community Language Chat Scroll Arrow Tap');
                    // Scroll forward by 250 pixels (about 2 cards)
                    final double currentOffset = scrollController.offset;
                    final double maxScrollExtent = scrollController.position.maxScrollExtent;
                    final double targetOffset = (currentOffset + 250).clamp(0.0, maxScrollExtent);
                    
                    scrollController.animateTo(
                      targetOffset,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Container(
                    width: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFFFBFBFB).withOpacity(0.0),
                          const Color(0xFFFBFBFB).withOpacity(0.7),
                          const Color(0xFFFBFBFB),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chevron_right,
                        color: Color(0xFF666666),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSortDropdown(BuildContext context, Color secondaryTextColor) {
    // Get the current sort order from the cubit state
    final currentSortOrder = context.select((CommunityCubit cubit) => 
      cubit.state.maybeWhen(
        loaded: (_, sortOrder) => sortOrder,
        orElse: () => PostSortOrder.newest, // Default if not loaded yet
      )
    );
    
    final Color primaryTextColor = const Color(0xFF1A1A1A); // Brand dark text
    
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 2.0), // Reduced top padding for white background
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
                      Container(
              padding: const EdgeInsets.all(0), // Remove all padding to minimize spacing
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: const Color(0xFFE0E0E0),
                  width: 1,
                ),
              ),
            child: DropdownButtonHideUnderline(
              child: SizedBox(
                width: 100,
                child: DropdownButton<PostSortOrder>(
                value: currentSortOrder,
                icon: Icon(Icons.keyboard_arrow_down, color: primaryTextColor, size: 18),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                isDense: true, // Make the button more compact
                style: TextStyle(
                  fontFamily: 'ElzaRound',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: primaryTextColor,
                ),
                // This builder creates the widget for the selected item, allowing us to remove the extra padding.
                selectedItemBuilder: (BuildContext context) {
                  return PostSortOrder.values.map((PostSortOrder value) {
                    return Text(
                      value == PostSortOrder.newest ? 'New' : 'Trending',
                      style: TextStyle(
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: primaryTextColor,
                      ),
                    );
                  }).toList();
                },
                items: [
                  DropdownMenuItem(
                    value: PostSortOrder.newest,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Text(
                        'New', 
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 14,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: PostSortOrder.mostVoted,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Text(
                        'Trending', 
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 14,
                          fontFamily: 'ElzaRound',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
                onChanged: (PostSortOrder? newValue) {
                  if (newValue != null) {
                    context.read<CommunityCubit>().changeSortOrder(newValue);
                  }
                                  },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Navigate to the add post screen
  void _navigateToAddPost(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const AddPostScreen(),
    ));
  }

  // Debug-only function to delete sample posts
  void _deleteSamplePosts(BuildContext context) {
    // Show a confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('community_deleteSamplePostsTitle')),
        content: Text(AppLocalizations.of(context)!.translate('community_deleteSamplePostsMessage')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.translate('common_cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Delete the posts
              context.read<CommunityCubit>().deleteSamplePosts();
              // Show a snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppLocalizations.of(context)!.translate('community_deletingSamplePosts'))),
              );
            },
            child: Text(AppLocalizations.of(context)!.translate('common_delete'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
} 