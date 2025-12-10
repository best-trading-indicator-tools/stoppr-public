import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/core/localization/app_localizations.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';

class OnboardingFomoStatsScreen extends StatefulWidget {
  final VoidCallback onContinue;
  
  const OnboardingFomoStatsScreen({
    super.key,
    required this.onContinue,
  });

  @override
  State<OnboardingFomoStatsScreen> createState() => _OnboardingFomoStatsScreenState();
}

class _OnboardingFomoStatsScreenState extends State<OnboardingFomoStatsScreen>
    with TickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<double>? _titleAnimation;
  Animation<double>? _stat1Animation;
  Animation<double>? _stat2Animation;
  Animation<double>? _stat4Animation;
  Animation<double>? _buttonAnimation;

  @override
  void initState() {
    super.initState();
    MixpanelService.trackPageView('Onboarding Progress Card Creation Screen: Page Viewed');
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Staggered animations with different start times
    _titleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    ));

    _stat1Animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: const Interval(0.1, 0.5, curve: Curves.easeOut),
    ));

    _stat2Animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
    ));

    _stat4Animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
    ));

    _buttonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
    ));

    // Start the animation
    _animationController!.forward();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean white background
      body: Stack(
        children: [
          SafeArea(
            child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                      const SizedBox(height: 40), // Top padding for scroll
                      
                      // Animated Title
                      if (_titleAnimation != null)
                        _buildAnimatedItem(
                          animation: _titleAnimation!,
                          child: _GradientStrikeTitle(
                            title: AppLocalizations.of(context)!
                                .translate('onboarding_fomo_title'),
                          ),
                        )
                      else
                        _GradientStrikeTitle(
                          title: AppLocalizations.of(context)!
                              .translate('onboarding_fomo_title'),
                        ),
                      
                      const SizedBox(height: 64),
                      
                      // Animated Stats with laurel icons
                      if (_stat1Animation != null)
                        _buildAnimatedItem(
                          animation: _stat1Animation!,
                          child: _buildStatItem(
                            text: AppLocalizations.of(context)!.translate('onboarding_fomo_stat1'),
                          ),
                        )
                      else
                        _buildStatItem(
                          text: AppLocalizations.of(context)!.translate('onboarding_fomo_stat1'),
                        ),
                      
                      const SizedBox(height: 60),
                      
                      if (_stat2Animation != null)
                        _buildAnimatedItem(
                          animation: _stat2Animation!,
                          child: _buildStatItem(
                            text: AppLocalizations.of(context)!.translate('onboarding_fomo_stat2'),
                          ),
                        )
                      else
                        _buildStatItem(
                          text: AppLocalizations.of(context)!.translate('onboarding_fomo_stat2'),
                        ),
                      
                      const SizedBox(height: 60),
                      
                      if (_stat4Animation != null)
                        _buildAnimatedItem(
                          animation: _stat4Animation!,
                          child: _buildStatItem(
                            text: AppLocalizations.of(context)!.translate('onboarding_fomo_stat4'),
                          ),
                        )
                      else
                        _buildStatItem(
                          text: AppLocalizations.of(context)!.translate('onboarding_fomo_stat4'),
                        ),
                      
                      const SizedBox(height: 36), // Bottom padding for scroll
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Subtitle above button
            if (_buttonAnimation != null)
              _buildAnimatedItem(
                animation: _buttonAnimation!,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 4.0),
                  child: Text(
                    AppLocalizations.of(context)!.translate('onboarding_fomo_subtitle'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                      height: 1.3,
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 4.0),
                child: Text(
                  AppLocalizations.of(context)!.translate('onboarding_fomo_subtitle'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                    height: 1.3,
                  ),
                ),
              ),
            
            // Animated Continue Button
            if (_buttonAnimation != null)
              _buildAnimatedItem(
                animation: _buttonAnimation!,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 24.0),
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFed3272), // Strong pink/magenta
                          Color(0xFFfd5d32), // Vivid orange
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        MixpanelService.trackEvent('Onboarding Progress Card Creation Screen: Button Tap');
                        widget.onContinue();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.translate('onboarding_fomo_continue_button'),
                        style: const TextStyle(
                          fontFamily: 'ElzaRound',
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          height: 0.9,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 24.0),
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFed3272), // Strong pink/magenta
                        Color(0xFFfd5d32), // Vivid orange
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      MixpanelService.trackEvent('Onboarding Progress Card Creation Screen: Button Tap');
                      widget.onContinue();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.translate('onboarding_fomo_continue_button'),
                      style: const TextStyle(
                        fontFamily: 'ElzaRound',
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        height: 0.9,
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
    );
  }
  
  Widget _buildAnimatedItem({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 50 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
  
  Widget _buildStatItem({required String text}) {
    final List<String> lines = text.split('\n');
    final String firstLine = lines.isNotEmpty ? lines.first : text;
    final String secondLine = lines.length > 1 ? lines.sublist(1).join('\n') : '';

    final bool isNumericFirstLine = RegExp(r'[0-9]')
        .hasMatch(firstLine);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isNumericFirstLine)
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
            ).createShader(bounds),
            child: Text(
              // Only keep the numeric token and trailing '+' for gradient
              firstLine.split(' ').first,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'ElzaRound',
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          )
        else
          Text(
            firstLine,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
              height: 1.2,
            ),
          ),
        // Compose the remainder of the description, including any words from
        // the first line after the numeric token, plus subsequent lines.
        if (secondLine.isNotEmpty || (isNumericFirstLine && firstLine.contains(' '))) ...[
          const SizedBox(height: 6),
          Text(
            [
              if (isNumericFirstLine && firstLine.contains(' '))
                firstLine.split(' ').sublist(1).join(' '),
              if (secondLine.isNotEmpty) secondLine,
            ].where((e) => e.isNotEmpty).join('\n'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'ElzaRound',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}

// Summary: Ensure the FOMO title renders on exactly two lines max across all
// locales by hard-limiting each gradient text line to a single line with
// ellipsis overflow. This prevents wrapping to a third line with long words.
class _GradientStrikeTitle extends StatelessWidget {
  const _GradientStrikeTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final List<String> lines = title.split('\n');
    final String top = lines.isNotEmpty ? lines.first : title;
    final String bottom = lines.length > 1 ? lines[1] : '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final fontSize = _resolveFontSize(
            [top, if (bottom.isNotEmpty) bottom],
            availableWidth,
          );
        final letterSpacing = -0.02 * fontSize;

        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
          ).createShader(bounds),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Text(
                  top,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: 'ElzaRound',
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: letterSpacing,
                    height: 1.05,
                  ),
                ),
              ),
              if (bottom.isNotEmpty) const SizedBox(height: 8),
              if (bottom.isNotEmpty)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    bottom,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: letterSpacing,
                      height: 1.05,
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

  double _resolveFontSize(List<String> lines, double maxWidth) {
    const double maxFontSize = 90;
    const double minFontSize = 44;
    const double decrement = 2;

    final displayLines = lines.where((line) => line.trim().isNotEmpty).toList();
    if (displayLines.isEmpty || maxWidth.isInfinite) {
      return maxFontSize;
    }

    double fontSize = maxFontSize;
    while (fontSize > minFontSize) {
      final fits = displayLines.every(
        (line) => _measureLineWidth(line, fontSize) <= maxWidth,
      );

      if (fits) {
        break;
      }

      fontSize -= decrement;
    }

    return fontSize.clamp(minFontSize, maxFontSize);
  }

  double _measureLineWidth(String line, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: line,
        style: TextStyle(
          fontFamily: 'ElzaRound',
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.02 * fontSize,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    return painter.width;
  }
}