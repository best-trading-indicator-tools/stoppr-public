import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:stoppr/core/auth/cubit/auth_cubit.dart'; // Assuming AuthCubit path
import 'package:stoppr/features/learn/data/services/article_service.dart';
import 'package:stoppr/features/learn/domain/models/article_model.dart';
import 'package:stoppr/features/learn/domain/models/user_article_progress_model.dart';
import 'package:stoppr/features/learn/presentation/state/articles_cubit.dart';
import 'package:stoppr/features/learn/presentation/state/articles_state.dart';
import 'package:stoppr/features/learn/presentation/screens/article_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/rendering.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart'; // Import MixpanelService
import 'package:stoppr/core/localization/app_localizations.dart'; // Add this import
import 'package:stoppr/core/utils/text_sanitizer.dart';

// TODO: Define Article and UserProgress models
// TODO: Import necessary Bloc/Cubit and Service classes

// Changed to StatefulWidget to easily call loadArticles in initState
class ArticlesListScreen extends StatefulWidget {
  const ArticlesListScreen({super.key});

  @override
  State<ArticlesListScreen> createState() => _ArticlesListScreenState();
}

class _ArticlesListScreenState extends State<ArticlesListScreen> {

  @override
  void initState() {
    super.initState();
    // Track page view with Mixpanel
    MixpanelService.trackPageView('Articles List Screen');
  }

  // Helper method to launch URL
  Future<void> _launchNotionUrl() async {
    // Track button tap
    MixpanelService.trackButtonTap('Help & Info', screenName: 'Articles List Screen');
    final Uri url = Uri.parse('https://elevenlife.notion.site/Stoppr-1c3456d8905e80029856d5373ee08dfb?pvs=4');
    try {
       // Consider adding Mixpanel tracking here if needed
       if (await canLaunchUrl(url)) {
         await launchUrl(url, mode: LaunchMode.inAppWebView);
       } else {
         print('Could not launch $url');
         // Optionally show a snackbar or dialog on failure
       }
    } catch (e) {
       print('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Consistent status bar style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // For iOS
    ));

    // Fetch user ID again for BlocProvider creation (can be optimized)
    final authState = context.watch<AuthCubit>().state;
     final userId = authState.maybeMap(
      authenticated: (state) => state.user.uid,
      authenticatedWithSubscription: (state) => state.user.uid,
      authenticatedPaidUser: (state) => state.user.uid,
      authenticatedFreeUser: (state) => state.user.uid,
      orElse: () => '', 
    );

    // If userId is empty, we might want to show a different UI instead of providing the cubit
    // Or the cubit itself handles the empty userId case (as implemented in ArticlesCubit)
    
    // Provide ArticleService via RepositoryProvider
    return RepositoryProvider(
      create: (context) => ArticleService(),
      child: BlocProvider(
        // Read the ArticleService from the context
        create: (context) => ArticlesCubit(
          articleService: context.read<ArticleService>(), 
          userId: userId, // Pass the correctly fetched userId
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFFFDF8FA), // New brand background
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A1A1A)),
              onPressed: () {
                // Track button tap
                MixpanelService.trackButtonTap('Back', screenName: 'Articles List Screen');
                Navigator.of(context).pop();
              },
            ),
            title: Text(
              AppLocalizations.of(context)!.translate('articlesScreen_title'),
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 24,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.bold,
              ),
            ),
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light, // For iOS
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline, color: Color(0xFF1A1A1A)),
                onPressed: _launchNotionUrl,
                tooltip: AppLocalizations.of(context)!.translate('pledgeScreen_tooltip_help'),
              ),
            ],
          ),
          body: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return BlocBuilder<ArticlesCubit, ArticlesState>(
      builder: (context, state) {
        return state.when(
          initial: () => const Center(child: CircularProgressIndicator(color: Color(0xFFed3272))),
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFed3272))),
          error: (message) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SelectableText.rich(
                  TextSpan(
                    text: AppLocalizations.of(context)!.translate('common_error_prefix') +
                        '\n' + TextSanitizer.sanitizeForDisplay(message),
                    style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                  ),
                  textAlign: TextAlign.center,
                ),
            ),
          ),
          loaded: (categories, userProgress) {
            if (categories.isEmpty) {
              return Center(
                child: Text(
                  AppLocalizations.of(context)!.translate('articles_emptyListMessage'),
                  style: const TextStyle(color: Color(0xFF666666), fontSize: 16),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final categoryViewModel = categories[index];
                return _buildCategorySection(
                  context,
                  viewModel: categoryViewModel,
                  userProgress: userProgress,
                );
              },
            );
          },
        );
      },
    );
  }

  // Updated to take ViewModel and UserProgress
  Widget _buildCategorySection(
    BuildContext context, {
    required ArticleCategoryViewModel viewModel,
    required UserArticleProgress userProgress, // Pass progress down
  }) {
    // Calculate card width here for both card and title
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.33).floorToDouble(); // ~33% of screen width
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.translate(viewModel.title),
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 20,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              AppLocalizations.of(context)!
                  .translate('articles_completionPercentage')
                  .replaceFirst('{percent}', viewModel.completionPercentage.toString()),
              style: const TextStyle(
                color: Color(0xFF666666),
                fontSize: 14,
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Replace GridView with a horizontal ListView
        SizedBox(
          // Adjust height to accommodate card + title below
          height: 110, // Reduced from 130px to 120px (card height 70 + title + padding)
          child: ListView.separated(
            // Adjust padding: Less left padding, more effective right peek
            padding: const EdgeInsets.only(left: 0.0, right: 32.0), // Removed left padding
            clipBehavior: Clip.none, // Allow overflow for the peek effect
            scrollDirection: Axis.horizontal,
            itemCount: viewModel.articles.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12), // Reduced separator width
            itemBuilder: (context, index) {
              final article = viewModel.articles[index];
              // Wrap card and title in a Column
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildArticleCard(
                    context,
                    article: article,
                    isCompleted: userProgress.isCompleted(article.id),
                    color: viewModel.color,
                    cardWidth: cardWidth, // Pass the width down
                    onTap: () {
                      // Track tap before navigation
                      MixpanelService.trackButtonTap(
                        'Article Card - ${article.title}', 
                        screenName: 'Articles List Screen',
                        additionalProps: {
                          'article_id': article.id,
                          'article_category': article.category,
                          'article_order': article.order,
                        }
                      );
                      // Navigate to Article Detail Screen
                      print('Navigating to detail for: ${article.title}');
                      final articlesCubit = context.read<ArticlesCubit>();
                      final articlesState = articlesCubit.state;
                      // Get the ArticleService from Provider, already available in this context
                      // final articleService = context.read<ArticleService>(); 
                      
                      if (articlesState is ArticlesLoaded) {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => MultiProvider(
                              providers: [
                                BlocProvider.value(
                                  value: articlesCubit, // Pass the existing ArticlesCubit
                                ),
                                RepositoryProvider.value(
                                  value: context.read<ArticleService>(), // Pass the ArticleService
                                ),
                              ],
                              child: ArticleDetailScreen(
                                article: article,
                              ),
                            ),
                          ),
                        ).then((_) {
                          print('Returned from detail screen, refreshing list...');
                          articlesCubit.loadArticles();
                        });
                      } else {
                        print('Error: Cannot navigate, ArticlesCubit state is not ArticlesLoaded');
                      }
                    },
                  ),
                  const SizedBox(height: 6), // Reduced from 8px to 6px
                  // Title moved below the card
                  SizedBox(
                    width: cardWidth, // Use the same width calculated above
                    child: Text(
                      AppLocalizations.of(context)!.translate(article.title),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A), // Dark text
                        fontSize: 12,
                        fontFamily: 'ElzaRound',
                        fontWeight: FontWeight.bold, // Bold text
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // Updated to take Article model
  Widget _buildArticleCard(
    BuildContext context, {
    required Article article,
    required bool isCompleted,
    required Color color,
    required double cardWidth, // Accept width as parameter
    required VoidCallback onTap,
  }) {
    // Calculate a lighter start color for the gradient
    final HSLColor hslColor = HSLColor.fromColor(color);
    final Color startColor = hslColor.withLightness((hslColor.lightness + 0.1).clamp(0.0, 1.0)).toColor();
    final Color endColor = color; // Use original color as end color

    // Remove the width calculation from here
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: cardWidth, // Use the passed width
        height: 65, // Reduced height
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient( // Updated gradient
             colors: [startColor, endColor], // Use dynamic colors
             begin: Alignment.topLeft, // Revert to diagonal
             end: Alignment.bottomRight,
          ),
          boxShadow: [
             BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 5,
                offset: const Offset(0, 3),
             )
          ]
        ),
        child: Stack(
          alignment: Alignment.center, // Center stack children by default
          children: [
            // Top Right Checkmark
            if (isCompleted)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFed3272),
                        Color(0xFFfd5d32),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),

            // Centered Number
            Text(
              '${article.order}', 
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36, // Smaller number
                fontFamily: 'ElzaRound',
                fontWeight: FontWeight.bold,
                 shadows: [
                   Shadow( 
                     blurRadius: 4.0,
                     color: Colors.black54,
                     offset: Offset(1.0, 1.0),
                   ),
                 ]
              ),
            ), 
             // Removed the Positioned Title from here
          ],
        ),
      ),
    );
  }
} 