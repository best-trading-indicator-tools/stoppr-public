import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/features/recipes/data/repositories/recipe_repository.dart';
import 'package:stoppr/features/recipes/presentation/cubit/recipes_cubit.dart';
import 'package:stoppr/features/recipes/presentation/cubit/recipes_state.dart';
import 'package:stoppr/features/recipes/presentation/widgets/diet_filter_chip.dart';
import 'package:stoppr/features/recipes/presentation/widgets/meal_type_chip.dart';
import 'package:stoppr/features/recipes/presentation/widgets/calorie_range_card.dart';
import 'package:stoppr/features/recipes/presentation/widgets/recipe_card.dart';
import 'package:stoppr/features/recipes/presentation/screens/recipe_detail_screen.dart';
import 'package:stoppr/features/recipes/presentation/screens/recipes_favorites_screen.dart';

/// Recipes list screen with grid layout
/// Styled per style_brand.md with white background, brand gradients
/// Reference: User's screenshot showing grid layout with recipe cards
class RecipesListScreen extends StatefulWidget {
  final String? initialMealType;
  final String? initialCalorieRange;
  final String? initialDietFilter;
  final String? screenTitle;

  const RecipesListScreen({
    super.key,
    this.initialMealType,
    this.initialCalorieRange,
    this.initialDietFilter,
    this.screenTitle,
  });

  @override
  State<RecipesListScreen> createState() => _RecipesListScreenState();
}

class _RecipesListScreenState extends State<RecipesListScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedFilter;
  String? _selectedMealType;
  String? _selectedCalorieRange;
  final TextEditingController _searchController = TextEditingController();
  bool _hasSearchText = false;
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    // Track page view
    MixpanelService.trackPageView('Recipes List Screen');

    // Set initial filters if provided
    if (widget.initialMealType != null) {
      _selectedMealType = widget.initialMealType;
    }
    if (widget.initialCalorieRange != null) {
      _selectedCalorieRange = widget.initialCalorieRange;
    }
    if (widget.initialDietFilter != null) {
      _selectedFilter = widget.initialDietFilter;
    }

    // Initialize tab controller
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted && _tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
        MixpanelService.trackButtonTap(
          _currentTabIndex == 0 ? 'Tab: Discover' : 'Tab: My Favorites',
          screenName: 'Recipes List Screen',
        );
      }
    });

    // Listen to search text changes for UI updates
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _hasSearchText = _searchController.text.isNotEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, BuildContext context) {
    if (query.isEmpty) {
      // If any filter is active, reapply filters; otherwise load all recipes
      if (_selectedFilter != null ||
          _selectedMealType != null ||
          _selectedCalorieRange != null) {
        _applyFilters(context);
      } else {
        context.read<RecipesCubit>().loadInitialRecipes();
      }
      MixpanelService.trackButtonTap(
        'Search Cleared',
        screenName: 'Recipes List Screen',
      );
      return;
    }

    if (query.length >= 2) {
      // Search with active filters preserved
      _applyFilters(context);
      MixpanelService.trackButtonTap(
        'Search: $query',
        screenName: 'Recipes List Screen',
      );
    }
  }

  bool _isDietFilter(String filter) {
    return filter == 'low-carb' || filter == 'high-protein';
  }

  void _applyFilters(BuildContext context) {
    // Use initial filters if on filtered view, otherwise use selected filters
    final calorieRange = widget.initialCalorieRange ?? _selectedCalorieRange;
    final mealType = widget.initialMealType ?? _selectedMealType;
    final dietFilter = widget.initialDietFilter ?? _selectedFilter;

    // Parse calorie range if selected
    String? calories;
    if (calorieRange != null) {
      // Handle "700+" format - convert to "700-9999" for API
      if (calorieRange.contains('+')) {
        final minCal = calorieRange.replaceAll('+', '');
        calories = '$minCal-9999';
      } else {
        final parts = calorieRange.split('-');
        if (parts.length == 2) {
          calories = calorieRange;
        }
      }
    }

    // Build diet and health labels from selected filter
    List<String>? dietLabels;
    List<String>? healthLabels;
    if (dietFilter != null) {
      if (_isDietFilter(dietFilter)) {
        dietLabels = [dietFilter];
      } else {
        healthLabels = [dietFilter];
      }
    }

    // Apply combined filters
    context.read<RecipesCubit>().filterRecipes(
      mealType: mealType,
      calories: calories,
      dietLabels: dietLabels,
      healthLabels: healthLabels,
      query: _searchController.text.isNotEmpty ? _searchController.text : null,
    );
  }

  void _selectFilter({
    String? mealType,
    String? calorieRange,
    String? dietFilter,
  }) {
    if (mounted) {
      setState(() {
        // Toggle selection: if already selected, deselect; otherwise select
        if (mealType != null) {
          _selectedMealType =
              _selectedMealType == mealType ? null : mealType;
        }
        if (calorieRange != null) {
          _selectedCalorieRange =
              _selectedCalorieRange == calorieRange ? null : calorieRange;
        }
        if (dietFilter != null) {
          _selectedFilter = _selectedFilter == dietFilter ? null : dietFilter;
        }
      });
    }
  }

  bool _hasAnyFilterSelected() {
    return _selectedFilter != null ||
        _selectedMealType != null ||
        _selectedCalorieRange != null;
  }

  bool get _isFilteredView {
    return widget.initialMealType != null ||
        widget.initialCalorieRange != null ||
        widget.initialDietFilter != null;
  }

  void _handleFilterTap(
    BuildContext context, {
    String? mealType,
    String? calorieRange,
    String? dietFilter,
    required String mixpanelEvent,
  }) {
    // Select/deselect the filter (no automatic navigation)
    _selectFilter(
      mealType: mealType,
      calorieRange: calorieRange,
      dietFilter: dietFilter,
    );

    MixpanelService.trackButtonTap(
      mixpanelEvent,
      screenName: 'Recipes List Screen',
    );
  }

  void _navigateToFilteredRecipes(
    BuildContext context, {
    String? mealType,
    String? calorieRange,
    String? dietFilter,
  }) {
    // Use all selected filters
    final combinedMealType = mealType ?? _selectedMealType;
    final combinedCalorieRange = calorieRange ?? _selectedCalorieRange;
    final combinedDietFilter = dietFilter ?? _selectedFilter;

    // Build screen title from combined filters
    final localizations = AppLocalizations.of(context)!;
    final List<String> titleParts = [];

    if (combinedDietFilter != null) {
      final dietTitle = combinedDietFilter
          .replaceAll('-', ' ')
          .split(' ')
          .map(
            (word) =>
                word.substring(0, 1).toUpperCase() + word.substring(1),
          )
          .join(' ');
      titleParts.add(dietTitle);
    }

    if (combinedMealType != null) {
      titleParts.add(
        combinedMealType.substring(0, 1).toUpperCase() +
            combinedMealType.substring(1),
      );
    }

    if (combinedCalorieRange != null) {
      final displayRange = combinedCalorieRange.contains('+')
          ? '$combinedCalorieRange ${localizations.translate('recipes_kcal')}'
          : '$combinedCalorieRange ${localizations.translate('recipes_kcal')}';
      titleParts.add(displayRange);
    }

    final String title = titleParts.isEmpty
        ? 'Recipes'
        : titleParts.join(' • ');

    // Navigate to filtered recipes screen
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder:
            (_) => RecipesListScreen(
              initialMealType: combinedMealType,
              initialCalorieRange: combinedCalorieRange,
              initialDietFilter: combinedDietFilter,
              screenTitle: title,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocProvider(
      create: (context) {
        final cubit = RecipesCubit(RecipeRepository());
        // Apply initial filters or load recipes after cubit is created
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (widget.initialMealType != null ||
              widget.initialCalorieRange != null ||
              widget.initialDietFilter != null) {
            // Filters will be applied in _buildDiscoverTab
          } else {
            cubit.loadInitialRecipes();
          }
        });
        return cubit;
      },
      child: Builder(
        builder: (context) {
          // Apply initial filters if provided
          if (widget.initialMealType != null ||
              widget.initialCalorieRange != null ||
              widget.initialDietFilter != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final state = context.read<RecipesCubit>().state;
                // Only apply if not already loaded
                if (state is RecipesInitial || state is RecipesLoading) {
                  _applyFilters(context);
                }
              }
            });
          }
          return Scaffold(
            backgroundColor: const Color(
              0xFFFBFBFB,
            ), // White background per style guide
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              toolbarHeight: 80,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    Brightness.dark, // Dark icons per style guide
                statusBarBrightness: Brightness.light,
              ),
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Color(0xFF1A1A1A), // Dark for visibility
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                widget.screenTitle ?? localizations.translate('recipes_title'),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A), // Dark text per style guide
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              centerTitle: false,
              bottom: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFFed3272),
                unselectedLabelColor: const Color(0xFF666666),
                indicatorColor: const Color(0xFFed3272),
                labelStyle: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  Tab(text: localizations.translate('recipes_discover')),
                  Tab(text: localizations.translate('recipes_myFavorites')),
                ],
              ),
            ),
            body: Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    // Discover Tab
                    _buildDiscoverTab(context, localizations),
                    // My Favorites Tab
                    const RecipesFavoritesScreen(),
                  ],
                ),
                // Sticky CTA Button - Show when filters are selected on main screen
                if (!_isFilteredView && _hasAnyFilterSelected())
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: MediaQuery.of(context).padding.bottom + 16,
                      ),
                      child: Container(
                        width: double.infinity,
                        height: 56,
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
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _navigateToFilteredRecipes(context);
                              MixpanelService.trackButtonTap(
                                'View Filtered Recipes',
                                screenName: 'Recipes List Screen',
                              );
                            },
                            borderRadius: BorderRadius.circular(28),
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context)!
                                        .translate('recipes_viewResults') ??
                                    'View your meals',
                                style: const TextStyle(
                                  fontFamily: 'ElzaRound',
                                  fontSize: 19,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiscoverTab(
    BuildContext context,
    AppLocalizations localizations,
  ) {

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<RecipesCubit>().refreshRecipes();
      },
      color: const Color(0xFFed3272), // Brand pink
      child: CustomScrollView(
        slivers: [
          // Search field - Always show at the top
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (query) => _onSearchChanged(query, context),
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontSize: 16,
                  color: Color(0xFF1A1A1A),
                ),
                decoration: InputDecoration(
                  hintText: localizations.translate('recipes_search_hint'),
                  hintStyle: const TextStyle(
                    fontFamily: 'ElzaRound',
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF666666),
                    size: 22,
                  ),
                  suffixIcon:
                      _hasSearchText
                          ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Color(0xFF666666),
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              context.read<RecipesCubit>().loadInitialRecipes();
                            },
                          )
                          : null,
                  filled: true,
                  fillColor: const Color(0xFFFBFBFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFed3272),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                textInputAction: TextInputAction.search,
                keyboardType: TextInputType.text,
              ),
            ),
          ),

          // Categories Section (Diet Filters) - Only show on main discover screen
          if (!_isFilteredView) ...[
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.category,
                          size: 20,
                          color: Color(0xFFed3272),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          localizations.translate('recipes_mealTypes'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Filter chips section - part of Categories
            SliverToBoxAdapter(
              child: Container(
                height: 60,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    DietFilterChip(
                      label: localizations.translate('recipes_filter_all'),
                      isSelected:
                          _selectedFilter == null &&
                          _selectedMealType == null &&
                          _selectedCalorieRange == null,
                      onTap: () {
                        if (mounted) {
                          setState(() {
                            _selectedFilter = null;
                            _selectedMealType = null;
                            _selectedCalorieRange = null;
                          });
                        }
                        // If there's search text, search without filter, otherwise show all
                        if (_searchController.text.isNotEmpty) {
                          context.read<RecipesCubit>().searchRecipes(
                            query: _searchController.text,
                          );
                        } else {
                          context.read<RecipesCubit>().clearFilters();
                        }
                        MixpanelService.trackButtonTap(
                          'Filter All',
                          screenName: 'Recipes List Screen',
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    DietFilterChip(
                      label: localizations.translate('recipes_filter_lowCarb'),
                      isSelected: _selectedFilter == 'low-carb',
                      onTap: () => _handleFilterTap(
                        context,
                        dietFilter: 'low-carb',
                        mixpanelEvent: 'Filter Low-Carb',
                      ),
                    ),
                    const SizedBox(width: 8),
                    DietFilterChip(
                      label: localizations.translate('recipes_filter_lowSugar'),
                      isSelected: _selectedFilter == 'low-sugar',
                      onTap: () => _handleFilterTap(
                        context,
                        dietFilter: 'low-sugar',
                        mixpanelEvent: 'Filter Low Sugar',
                      ),
                    ),
                    const SizedBox(width: 8),
                    DietFilterChip(
                      label: localizations.translate(
                        'recipes_filter_sugarConscious',
                      ),
                      isSelected: _selectedFilter == 'sugar-conscious',
                      onTap: () => _handleFilterTap(
                        context,
                        dietFilter: 'sugar-conscious',
                        mixpanelEvent: 'Filter Sugar-Conscious',
                      ),
                    ),
                    const SizedBox(width: 8),
                    DietFilterChip(
                      label: localizations.translate(
                        'recipes_filter_carnivore',
                      ),
                      isSelected: _selectedFilter == 'high-protein',
                      onTap: () => _handleFilterTap(
                        context,
                        dietFilter: 'high-protein',
                        mixpanelEvent: 'Filter Carnivore',
                      ),
                    ),
                    const SizedBox(width: 8),
                    DietFilterChip(
                      label: localizations.translate('recipes_filter_kosher'),
                      isSelected: _selectedFilter == 'kosher',
                      onTap: () => _handleFilterTap(
                        context,
                        dietFilter: 'kosher',
                        mixpanelEvent: 'Filter Kosher',
                      ),
                    ),
                    const SizedBox(width: 8),
                    DietFilterChip(
                      label: localizations.translate('recipes_filter_keto'),
                      isSelected: _selectedFilter == 'keto-friendly',
                      onTap: () => _handleFilterTap(
                        context,
                        dietFilter: 'keto-friendly',
                        mixpanelEvent: 'Filter Keto',
                      ),
                    ),
                    const SizedBox(width: 8),
                    DietFilterChip(
                      label: localizations.translate(
                        'recipes_filter_glutenFree',
                      ),
                      isSelected: _selectedFilter == 'gluten-free',
                      onTap: () => _handleFilterTap(
                        context,
                        dietFilter: 'gluten-free',
                        mixpanelEvent: 'Filter Gluten-Free',
                      ),
                    ),
                    const SizedBox(width: 8),
                    DietFilterChip(
                      label: localizations.translate(
                        'recipes_filter_peanutFree',
                      ),
                      isSelected: _selectedFilter == 'peanut-free',
                      onTap: () => _handleFilterTap(
                        context,
                        dietFilter: 'peanut-free',
                        mixpanelEvent: 'Filter Peanut-Free',
                      ),
                    ),
                    const SizedBox(width: 8),
                    DietFilterChip(
                      label: localizations.translate(
                        'recipes_filter_wheatFree',
                      ),
                      isSelected: _selectedFilter == 'wheat-free',
                      onTap: () => _handleFilterTap(
                        context,
                        dietFilter: 'wheat-free',
                        mixpanelEvent: 'Filter Wheat-Free',
                      ),
                    ),
                    const SizedBox(width: 8),
                    DietFilterChip(
                      label: localizations.translate(
                        'recipes_filter_dairyFree',
                      ),
                      isSelected: _selectedFilter == 'dairy-free',
                      onTap: () => _handleFilterTap(
                        context,
                        dietFilter: 'dairy-free',
                        mixpanelEvent: 'Filter Dairy-Free',
                      ),
                    ),
                    const SizedBox(width: 8),
                    DietFilterChip(
                      label: localizations.translate('recipes_filter_vegan'),
                      isSelected: _selectedFilter == 'vegan',
                      onTap: () => _handleFilterTap(
                        context,
                        dietFilter: 'vegan',
                        mixpanelEvent: 'Filter Vegan',
                      ),
                    ),
                    const SizedBox(width: 8),
                    DietFilterChip(
                      label: localizations.translate(
                        'recipes_filter_vegetarian',
                      ),
                      isSelected: _selectedFilter == 'vegetarian',
                      onTap: () => _handleFilterTap(
                        context,
                        dietFilter: 'vegetarian',
                        mixpanelEvent: 'Filter Vegetarian',
                      ),
                    ),
                    const SizedBox(width: 8),
                    DietFilterChip(
                      label: localizations.translate(
                        'recipes_filter_mediterranean',
                      ),
                      isSelected: _selectedFilter == 'Mediterranean',
                      onTap: () => _handleFilterTap(
                        context,
                        dietFilter: 'Mediterranean',
                        mixpanelEvent: 'Filter Mediterranean',
                      ),
                    ),
                    const SizedBox(width: 8),
                    DietFilterChip(
                      label: localizations.translate(
                        'recipes_filter_highProtein',
                      ),
                      isSelected: _selectedFilter == 'high-protein',
                      onTap: () => _handleFilterTap(
                        context,
                        dietFilter: 'high-protein',
                        mixpanelEvent: 'Filter High-Protein',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Sub-Categories Section (Meal Types) - Only show on main discover screen
          if (!_isFilteredView) ...[
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.restaurant_menu,
                          size: 18,
                          color: Color(0xFFed3272),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          localizations.translate('recipes_timeOfDay'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          MealTypeChip(
                            label: 'Breakfast',
                            emoji: '☕',
                            isSelected: _selectedMealType == 'breakfast',
                            onTap: () => _handleFilterTap(
                              context,
                              mealType: 'breakfast',
                              mixpanelEvent: 'Meal Type: Breakfast',
                            ),
                          ),
                          const SizedBox(width: 8),
                          MealTypeChip(
                            label: 'Lunch',
                            emoji: '🍲',
                            isSelected: _selectedMealType == 'lunch',
                            onTap: () => _handleFilterTap(
                              context,
                              mealType: 'lunch',
                              mixpanelEvent: 'Meal Type: Lunch',
                            ),
                          ),
                          const SizedBox(width: 8),
                          MealTypeChip(
                            label: 'Dinner',
                            emoji: '🥗',
                            isSelected: _selectedMealType == 'dinner',
                            onTap: () => _handleFilterTap(
                              context,
                              mealType: 'dinner',
                              mixpanelEvent: 'Meal Type: Dinner',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Sub-Sub-Categories Section (Calorie Ranges) - Only show on main discover screen
          if (!_isFilteredView) ...[
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          size: 18,
                          color: Color(0xFFed3272),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          localizations.translate('recipes_calorieRanges'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0,
                      children: [
                        CalorieRangeCard(
                          emoji: '🍉',
                          calorieRange:
                              '50-100 ${localizations.translate('recipes_kcal')}',
                          isSelected: _selectedCalorieRange == '50-100',
                          onTap: () => _handleFilterTap(
                            context,
                            calorieRange: '50-100',
                            mixpanelEvent: 'Calorie Range: 50-100',
                          ),
                        ),
                        CalorieRangeCard(
                          emoji: '🥪',
                          calorieRange:
                              '100-200 ${localizations.translate('recipes_kcal')}',
                          isSelected: _selectedCalorieRange == '100-200',
                          onTap: () => _handleFilterTap(
                            context,
                            calorieRange: '100-200',
                            mixpanelEvent: 'Calorie Range: 100-200',
                          ),
                        ),
                        CalorieRangeCard(
                          emoji: '🥯',
                          calorieRange:
                              '200-300 ${localizations.translate('recipes_kcal')}',
                          isSelected: _selectedCalorieRange == '200-300',
                          onTap: () => _handleFilterTap(
                            context,
                            calorieRange: '200-300',
                            mixpanelEvent: 'Calorie Range: 200-300',
                          ),
                        ),
                        CalorieRangeCard(
                          emoji: '🥞',
                          calorieRange:
                              '300-400 ${localizations.translate('recipes_kcal')}',
                          isSelected: _selectedCalorieRange == '300-400',
                          onTap: () => _handleFilterTap(
                            context,
                            calorieRange: '300-400',
                            mixpanelEvent: 'Calorie Range: 300-400',
                          ),
                        ),
                        CalorieRangeCard(
                          emoji: '🍛',
                          calorieRange:
                              '400-500 ${localizations.translate('recipes_kcal')}',
                          isSelected: _selectedCalorieRange == '400-500',
                          onTap: () => _handleFilterTap(
                            context,
                            calorieRange: '400-500',
                            mixpanelEvent: 'Calorie Range: 400-500',
                          ),
                        ),
                        CalorieRangeCard(
                          emoji: '🍱',
                          calorieRange:
                              '500-600 ${localizations.translate('recipes_kcal')}',
                          isSelected: _selectedCalorieRange == '500-600',
                          onTap: () => _handleFilterTap(
                            context,
                            calorieRange: '500-600',
                            mixpanelEvent: 'Calorie Range: 500-600',
                          ),
                        ),
                        CalorieRangeCard(
                          emoji: '🍕',
                          calorieRange:
                              '600-700 ${localizations.translate('recipes_kcal')}',
                          isSelected: _selectedCalorieRange == '600-700',
                          onTap: () => _handleFilterTap(
                            context,
                            calorieRange: '600-700',
                            mixpanelEvent: 'Calorie Range: 600-700',
                          ),
                        ),
                        CalorieRangeCard(
                          emoji: '🍔',
                          calorieRange:
                              '700+ ${localizations.translate('recipes_kcal')}',
                          isSelected: _selectedCalorieRange == '700+',
                          onTap: () => _handleFilterTap(
                            context,
                            calorieRange: '700+',
                            mixpanelEvent: 'Calorie Range: 700+',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Add bottom padding to prevent content from being hidden by sticky button
          if (!_isFilteredView && _hasAnyFilterSelected())
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 88,
              ),
            ),

          // Recipes grid - Only show on filtered views
          if (_isFilteredView)
            BlocBuilder<RecipesCubit, RecipesState>(
              builder: (context, state) {
                return state.when(
                  initial:
                      () => SliverFillRemaining(
                        child: const Center(child: Text('Ready to load recipes')),
                      ),
                  loading:
                      () => SliverFillRemaining(
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFed3272), // Brand pink per style guide
                            ),
                          ),
                        ),
                      ),
                  loaded: (recipes, activeFilters, searchQuery) {
                    return SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.75, // Taller cards for images
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final recipe = recipes[index];
                          return RecipeCard(
                            recipe: recipe,
                            onTap: () {
                              MixpanelService.trackButtonTap(
                                'Recipe Card: ${recipe.label}',
                                screenName: 'Recipes List Screen',
                              );
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder:
                                      (_) => RecipeDetailScreen(recipe: recipe),
                                ),
                              );
                            },
                          );
                        }, childCount: recipes.length),
                      ),
                    );
                  },
                  error:
                      (message) => SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: SelectableText.rich(
                              TextSpan(
                                children: [
                                  const WidgetSpan(
                                    child: Icon(
                                    Icons.error_outline,
                                    color: Color(0xFFed3272),
                                    size: 48,
                                  ),
                                ),
                                const TextSpan(text: '\n\n'),
                                TextSpan(
                                  text: message,
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(
                                      0xFFed3272,
                                    ), // Brand pink for errors
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
              );
            },
          ),
        ],
      ),
    );
  }
}
