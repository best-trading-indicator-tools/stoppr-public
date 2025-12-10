import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // Import Bloc
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart'; // Ensure provider is imported for Provider.of
import 'package:stoppr/core/auth/cubit/auth_cubit.dart'; // For userId
import 'package:stoppr/features/learn/data/services/article_service.dart'; // Import service
import 'package:stoppr/features/learn/domain/models/article_model.dart';
import 'package:stoppr/features/learn/domain/models/user_article_progress_model.dart';
import 'package:stoppr/features/learn/presentation/state/article_detail_cubit.dart'; // Import Cubit
import 'package:stoppr/features/learn/presentation/state/article_detail_state.dart'; // Import State
import 'package:stoppr/features/learn/presentation/state/articles_cubit.dart'; // To get initial progress
import 'package:stoppr/features/learn/presentation/state/articles_state.dart'; // To get initial progress
import 'package:stoppr/core/analytics/mixpanel_service.dart'; // Import MixpanelService
import 'package:stoppr/core/localization/app_localizations.dart'; // Import AppLocalizations
import 'package:stoppr/core/services/in_app_review_service.dart'; // Added import
import 'package:stoppr/core/utils/text_sanitizer.dart';

// TODO: Integrate with ArticleDetailCubit for content loading and completion

class ArticleDetailScreen extends StatefulWidget { // Changed to StatefulWidget
  final Article article;
  // final ArticleService articleService; // No longer needed here, obtained from Provider

  const ArticleDetailScreen({
    super.key, 
    required this.article,
    // required this.articleService, // No longer needed here
  });

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState(); // Create state
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> { // New State class
  final InAppReviewService _reviewService = InAppReviewService(); // Instantiate here for initState access

  @override
  void initState() {
    super.initState();
    _checkAndRequestReviewOnArticleOpen(); // New method call

    // Track page view with Mixpanel, including article details
    MixpanelService.trackPageView(
      'Article Detail Screen',
      additionalProps: {
        'article_id': widget.article.id,
        'article_title': widget.article.title,
        'article_category': widget.article.category,
      },
    );
  }

  Future<void> _checkAndRequestReviewOnArticleOpen() async {
    try {
      final bool promptAlreadyShown = await _reviewService.hasShownSecondArticleOpenedPrompt();
      if (promptAlreadyShown) {
        return; // Don't proceed if this specific prompt was already shown
      }

      final Set<String> completedArticleIds = await _reviewService.getCompletedArticleIdsForReviewTrigger();
      
      // Condition: At least one article completed, AND current article is NEW (not in completed list)
      if (completedArticleIds.isNotEmpty && !completedArticleIds.contains(widget.article.id)) {
        debugPrint('ArticleDetailScreen: Conditions met for 2nd article opened review prompt.');
        await _reviewService.requestReviewOnSecondArticleOpened(screenName: 'ArticleDetailScreen - Opened 2nd Unique');
      }
    } catch (e) {
        debugPrint('Error in _checkAndRequestReviewOnArticleOpen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure dark status bar icons for light background
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // For iOS
    ));

    // Dependencies needed for the Cubit
    final authState = context.read<AuthCubit>().state;
    final userId = authState.maybeMap(
      authenticated: (s) => s.user.uid,
      authenticatedWithSubscription: (s) => s.user.uid,
      authenticatedPaidUser: (s) => s.user.uid,
      authenticatedFreeUser: (s) => s.user.uid,
      orElse: () => '',
    );
    
    // Get initial progress state from the list cubit (might be fragile)
    // A better approach might be to pass initialProgress directly or fetch it again
    final articlesListState = context.read<ArticlesCubit>().state;
    final initialProgress = articlesListState is ArticlesLoaded 
                            ? articlesListState.userProgress 
                            : const UserArticleProgress(); // Default if not loaded
    
    // Callback to refresh the list screen
    final onComplete = () => context.read<ArticlesCubit>().loadArticles();

    // Get ArticleService from Provider, assuming it's provided higher up the tree
    // If not, ArticleService would need to be instantiated here or passed differently.
    final articleService = Provider.of<ArticleService>(context, listen: false);
    // final inAppReviewService = InAppReviewService(); // Already instantiated as a field

    return BlocProvider<ArticleDetailCubit>(
      create: (_) => ArticleDetailCubit(
        articleService: articleService, 
        reviewService: _reviewService, // Pass the field instance
        article: widget.article,
        initialProgress: initialProgress,
        userId: userId, 
        onCompleteCallback: onComplete, 
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFDF8FA), // Brand soft pink-tinted white background
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A1A1A), size: 28),
            onPressed: () {
              // Track button tap
              MixpanelService.trackButtonTap(
                'Back From Article', 
                screenName: 'Article Detail Screen',
                additionalProps: {
                  'article_id': widget.article.id,
                  'article_title': widget.article.title,
                }
              );
              Navigator.of(context).pop();
            },
          ),
          title: Text(AppLocalizations.of(context)!.translate('common_back'), 
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          titleSpacing: 0,
          centerTitle: false,
          actions: [
            BlocBuilder<ArticleDetailCubit, ArticleDetailState>(
              builder: (context, state) {
                // Get completion status
                bool isCompleted = false;
                state.maybeWhen(
                  loaded: (_, completed) => isCompleted = completed,
                  orElse: () {},
                );

                return isCompleted 
                  ? Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Row(
                        children: [
                          Text(
                            AppLocalizations.of(context)!.translate('articleDetail_completedStatus'),
                            style: const TextStyle(
                              color: Color(0xFFed3272),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              fontFamily: 'ElzaRound',
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFed3272),
                                  Color(0xFFfd5d32),
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink();
              },
            ),
          ],
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light, // For iOS
          ),
        ),
        body: BlocBuilder<ArticleDetailCubit, ArticleDetailState>(
          builder: (context, state) {
            return _buildBody(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ArticleDetailState state) {
    return state.when(
      initial: () => const Center(child: CircularProgressIndicator(color: Color(0xFFed3272))),
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFed3272))),
      markingComplete: (contentFromState) => _buildLoadedContent(
        context,
        contentFromState, // Use content from the state
        true, // Treat as completed for UI purposes (e.g., hide button)
      ),
      loaded: (content, isCompleted) => _buildLoadedContent(context, content, isCompleted),
      error: (message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SelectableText.rich(
            TextSpan(
              text: 'Error: \n' + TextSanitizer.sanitizeForDisplay(message),
              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadedContent(BuildContext context, String content, bool isCompleted) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          
          // Article number circle
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _getCategoryColor(),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${widget.article.order}', // Use widget.article
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Article Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              AppLocalizations.of(context)!.translate(widget.article.title),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                height: 1.2,
                fontFamily: 'ElzaRound',
              ),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Article content
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: MarkdownBody(
              data: _preprocessMarkdown(content),
              shrinkWrap: true,
              styleSheet: _markdownStyleSheet(),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Mark as Complete button - only show if not completed
          if (!isCompleted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFed3272),
                      Color(0xFFfd5d32),
                    ],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(40)),
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Track button tap
                    MixpanelService.trackButtonTap(
                      'Mark Article As Complete', 
                      screenName: 'Article Detail Screen',
                      additionalProps: {
                        'article_id': widget.article.id,
                        'article_title': widget.article.title,
                      }
                    );
                    context.read<ArticleDetailCubit>().markAsComplete();
                  },
                  icon: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                  label: Text(
                    AppLocalizations.of(context)!.translate('articleDetail_markAsComplete'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: 'ElzaRound',
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                    ),
                  ),
                ),
              ),
            ),
            
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Color _getCategoryColor() {
    switch (widget.article.category) { // Use widget.article
      case 'addiction_myths':
        return Colors.orange;
      case 'health_effects':
        return Colors.pink;
      case 'recovery_strategies':
        return Colors.blue;
      case 'stopping_benefits':
        return Colors.purple;
      default:
        return Colors.teal;
    }
  }

  // Preprocess markdown to fix heading line breaks
  String _preprocessMarkdown(String content) {
    // Find H2 headings that might be broken across multiple lines
    // and join them into a single line
    final RegExp h2Regex = RegExp(r'##\s+(.*?)(?=\n\n|\n##|\n###|\n#|\n\*|\n[0-9]|\n$)', dotAll: true);
    
    return content.replaceAllMapped(h2Regex, (match) {
      // Get the heading text and remove any newlines
      String headingText = match.group(1)?.replaceAll(RegExp(r'\n'), ' ') ?? '';
      // Trim extra spaces that might result from joining lines
      headingText = headingText.replaceAll(RegExp(r'\s+'), ' ').trim();
      return '## $headingText';
    });
  }

  // Updated Markdown styling
  MarkdownStyleSheet _markdownStyleSheet() {
    // Base text style for paragraphs (not bold)
    const baseTextStyle = TextStyle(
      color: Color(0xFF1A1A1A), 
      fontSize: 18,
      height: 1.6,
      fontFamily: 'ElzaRound',
    );

    return MarkdownStyleSheet(
      h1: baseTextStyle.copyWith(
        fontSize: 28, 
        fontWeight: FontWeight.w600, // Slightly bolder than normal, but not full bold
        height: 2.2,
      ),
      h2: baseTextStyle.copyWith(
        fontSize: 24, 
        fontWeight: FontWeight.w600,
        height: 1.8, // Reduced height but still keeping some spacing
      ),
      h3: baseTextStyle.copyWith(
        fontSize: 22, 
        fontWeight: FontWeight.w600, // Slightly bolder than normal
        height: 2.2,
      ),
      p: baseTextStyle, // Use the base style (not bold)
      strong: baseTextStyle.copyWith(
        fontWeight: FontWeight.bold, // Make explicitly bold text stand out
      ),
      a: const TextStyle(color: Color(0xFFed3272), decoration: TextDecoration.underline),
      listBullet: baseTextStyle.copyWith(fontSize: 18), // Match base size, not bold
      blockquoteDecoration: BoxDecoration(
        color: const Color(0xFFFAE6EC).withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      blockquotePadding: const EdgeInsets.all(16),
      textAlign: WrapAlignment.start,
      h1Padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      h2Padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
      h3Padding: const EdgeInsets.only(top: 28.0, bottom: 14.0),
      listIndent: 24.0,
    );
  }
} 