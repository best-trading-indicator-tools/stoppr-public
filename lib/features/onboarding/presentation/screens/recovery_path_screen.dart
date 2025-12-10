import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'benefits_page_view.dart';
import 'onboarding_sugar_painpoints_page_view.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:stoppr/core/localization/app_localizations.dart';

// Path tracking statically - reliable way to break loops
class NavigationState {
  static bool hasVisitedFromBenefits = false;
}

class RecoveryPathScreen extends StatefulWidget {
  final bool showNextButton;
  final bool showPageIndicators; // This will be ignored - page indicators should only be in parent PageView
  
  const RecoveryPathScreen({
    super.key,
    this.showNextButton = true,
    this.showPageIndicators = true,
  });

  @override
  State<RecoveryPathScreen> createState() => _RecoveryPathScreenState();
}

class _RecoveryPathScreenState extends State<RecoveryPathScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _fromBenefits = false;
  
  @override
  void initState() {
    super.initState();
    debugPrint('[RecoveryPath] Initializing RecoveryPathScreen');
    
    // Mixpanel Page View Tracking
    MixpanelService.trackPageView('Onboarding Painpoint Recovery Path Screen Viewed');
    
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    
    _animationController.forward();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final args = ModalRoute.of(context)?.settings.arguments;
    debugPrint('[RecoveryPath] didChangeDependencies called. args: $args');
    
    if (args is String && args == 'fromBenefits') {
      _fromBenefits = true;
      debugPrint('[RecoveryPath] Coming from Benefits. hasVisitedFromBenefits=${NavigationState.hasVisitedFromBenefits}');
    } else {
      _fromBenefits = false;
      debugPrint('[RecoveryPath] Not coming from Benefits');
    }
  }

  @override
  void dispose() {
    debugPrint('[RecoveryPath] Disposing RecoveryPathScreen');
    _animationController.dispose();
    super.dispose();
  }
  
  // SIMPLIFIED: Always go to sugar unhappiness screen on back navigation
  void _navigateBack(BuildContext context) {
    debugPrint('[RecoveryPath] ALWAYS navigating to SugarUnhappinessScreen');
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          const OnboardingSugarPainpointsPageView(initialPage: 3),
        settings: const RouteSettings(name: 'SugarUnhappinessScreen'),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(-1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
  
  // Navigate forward to benefits
  void _navigateForward(BuildContext context) {
    debugPrint('[RecoveryPath] Navigating forward to BenefitsPageView');
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          const BenefitsPageView(),
        settings: const RouteSettings(name: 'BenefitsPageView'),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    
    return Scaffold(
      backgroundColor: const Color(0xFF033E8C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: SafeArea(
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 100) return; // Ignore small swipes
            
            if (velocity > 0) {
              // Right swipe = back
              _navigateBack(context);
            } else if (velocity < 0) {
              // Left swipe = forward to benefits
              _navigateForward(context);
            }
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => _navigateBack(context),
                      child: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    
                    Expanded(
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.translate('recoveryPath_appBarTitle'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                            letterSpacing: -0.04 * 24,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 24),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        Lottie.asset(
                          'assets/images/lotties/Plant.json',
                          controller: _animationController,
                          repeat: false,
                          onLoaded: (composition) {
                            _animationController.forward();
                          },
                          width: 210,
                          height: 210,
                        ),
                        
                        const SizedBox(height: 40),
                        
                        Text(
                          AppLocalizations.of(context)!.translate('recoveryPath_title'),
                          style: const TextStyle(
                            fontFamily: 'ElzaRound',
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 1.7,
                            ),
                            children: <TextSpan>[
                              TextSpan(
                                text: AppLocalizations.of(context)!.translate('recoveryPath_description_part1'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: AppLocalizations.of(context)!.translate('recoveryPath_description_part2')),
                              TextSpan(
                                text: AppLocalizations.of(context)!.translate('recoveryPath_description_reducingSugar'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: AppLocalizations.of(context)!.translate('recoveryPath_description_part3')),
                              TextSpan(
                                text: AppLocalizations.of(context)!.translate('recoveryPath_description_resetDopamine'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: AppLocalizations.of(context)!.translate('recoveryPath_description_part4')),
                              TextSpan(
                                text: AppLocalizations.of(context)!.translate('recoveryPath_description_betterMood'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: AppLocalizations.of(context)!.translate('recoveryPath_description_part5')),
                              TextSpan(
                                text: AppLocalizations.of(context)!.translate('recoveryPath_description_increasedEnergy'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: AppLocalizations.of(context)!.translate('recoveryPath_description_part6')),
                              TextSpan(
                                text: AppLocalizations.of(context)!.translate('recoveryPath_description_improvedHealth'),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: AppLocalizations.of(context)!.translate('recoveryPath_description_part7')),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 160), // Add more space to bottom to ensure Next button has enough room
                      ],
                    ),
                  ),
                ),
              ),
              
              // Only show the Next button, no page indicators
              if (widget.showNextButton)
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 40),
                  child: GestureDetector(
                    onTap: () => _navigateForward(context),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.translate('recoveryPath_nextButton'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              color: Color(0xFF1A051D),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF1A051D),
                            size: 20,
                          ),
                        ],
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