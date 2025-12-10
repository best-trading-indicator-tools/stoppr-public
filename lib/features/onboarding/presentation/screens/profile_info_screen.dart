import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stoppr/core/repositories/user_repository.dart';
import 'package:stoppr/features/onboarding/data/repositories/questionnaire_repository.dart';
import 'package:stoppr/features/onboarding/presentation/screens/calculating_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/analysis_result_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/questionnaire_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/symptoms_screen.dart';
import 'package:stoppr/features/onboarding/presentation/screens/benefits_page_view.dart';
import 'package:flutter/services.dart';
import 'package:stoppr/features/onboarding/data/services/onboarding_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stoppr/core/analytics/mixpanel_service.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import 'package:stoppr/core/localization/app_localizations.dart';
import '../../../../core/analytics/superwall_utils.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:stoppr/core/quick_actions/quick_actions_service.dart';

// Custom route transition for slide animation
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final bool slideFromRight;
  
  SlidePageRoute({required this.page, this.slideFromRight = true})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final begin = slideFromRight ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutQuart;
            
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            
            return SlideTransition(position: offsetAnimation, child: child);
          },
        );
}

class ProfileInfoScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onPrevious;
  final Function({String? newFirstName, String? newAge})? onUpdateInfo;
  final String? firstName;
  final String? age;
  final String? gender;
  final bool hideHeader;
  final Map<int, String>? questionnaireAnswers;
  
  const ProfileInfoScreen({
    super.key,
    this.onComplete,
    this.onPrevious,
    this.onUpdateInfo,
    this.firstName,
    this.age,
    this.gender,
    this.hideHeader = false,
    this.questionnaireAnswers,
  });

  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _ageController;
  bool _isFormValid = false;
  final FocusNode _firstNameFocusNode = FocusNode();
  late final FocusNode _ageFocusNode; // Added for age field
  final UserRepository _userRepository = UserRepository();
  final QuestionnaireRepository _questionnaireRepository = QuestionnaireRepository();
  bool _isCapitalizing = false;
  final OnboardingProgressService _progressService = OnboardingProgressService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isProcessing = false; // Added for loading state
  bool _firstNameTouched = false;
  bool _ageTouched = false;
  bool _hideFirstNameField = false; // Hide when name provided by Apple/Google

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.firstName ?? '');
    _ageController = TextEditingController(text: widget.age ?? '');
    _ageFocusNode = FocusNode(); // Initialize age focus node
    
    // Determine if we should hide first name when provided by Apple/Google auth
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final bool isAppleOrGoogle = user.providerData.any(
          (p) => p.providerId.contains('apple') || p.providerId.contains('google'),
        );
        final String? displayName = user.displayName;
        final bool hasProviderName = displayName != null && displayName.trim().isNotEmpty;
        if (isAppleOrGoogle && hasProviderName) {
          _hideFirstNameField = true;
          // Prefill controller with first name if empty
          if ((_firstNameController.text).trim().isEmpty) {
            final String first = displayName!.split(' ').first;
            _firstNameController.text = first;
          }
        }
      }
    } catch (_) {
      // Safe no-op: if anything fails, we simply don't hide the field
      _hideFirstNameField = false;
    }
    
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for white background
      statusBarBrightness: Brightness.light, // iOS uses opposite naming
    ));
    
    // Add listeners to check form validity
    _firstNameController.addListener(_validateForm);
    _ageController.addListener(_validateForm);
    
    // Add listener to capitalize the first letter of the first name
    _firstNameController.addListener(_capitalizeFirstLetter);
    
    // Add focus listeners to track when fields lose focus (blurred)
    _firstNameFocusNode.addListener(() {
      if (!_firstNameFocusNode.hasFocus) {
        setState(() {
          _firstNameTouched = true;
        });
        _validateForm();
      }
    });
    
    _ageFocusNode.addListener(() {
      if (!_ageFocusNode.hasFocus) {
        setState(() {
          _ageTouched = true;
        });
        _validateForm();
      }
    });
    
    // Initial validation
    _validateForm();
    
    // Initial capitalization if needed
    _capitalizeFirstLetter();
    
    // Removed automatic focus to avoid triggering the keyboard on screen open,
    // which caused the layout to collapse on some iOS devices in release.
    
    // Save current screen
    _saveCurrentScreen();

    // Mixpanel
    MixpanelService.trackPageView('Onboarding Profile Info Screen');
  }
  
  Future<void> _saveCurrentScreen() async {
    await _progressService.saveCurrentScreen(OnboardingScreen.profileInfoScreen);
  }
  
  // Add method to dismiss keyboard
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }
  
  // Validate form inputs
  void _validateForm() {
    final firstName = _firstNameController.text.trim();
    final age = _ageController.text.trim();
    
    // First name is mandatory and must contain only letters (incl. accented), spaces, hyphens, apostrophes
    final nameRegex = RegExp(r"^[\p{L}\s\-']+$", unicode: true);
    final bool isFirstNameValid = firstName.isNotEmpty && nameRegex.hasMatch(firstName);
    
    // Age must be filled and contain only numbers between 0-140
    bool isAgeValid = false;
    if (age.isNotEmpty) {
      final ageRegex = RegExp(r'^[0-9]+$');
      isAgeValid = ageRegex.hasMatch(age);
      
      // Check age is within reasonable range
      if (isAgeValid) {
        final ageValue = int.tryParse(age);
        isAgeValid = ageValue != null && ageValue >= 0 && ageValue <= 140;
      }
    }
    
    final bool newFormValid = isFirstNameValid && isAgeValid;
    if (newFormValid != _isFormValid) {
      setState(() {
        _isFormValid = newFormValid;
      });
    }
  }

  // Capitalize the first letter of the first name
  void _capitalizeFirstLetter() {
    if (_isCapitalizing) return;
    
    final text = _firstNameController.text;
    if (text.isEmpty) return;
    
    // If the first letter is not capitalized, capitalize it
    if (text.length > 0 && text[0] != text[0].toUpperCase()) {
      _isCapitalizing = true;
      
      final capitalizedText = text[0].toUpperCase() + text.substring(1);
      
      // Save cursor position
      final cursorPosition = _firstNameController.selection.baseOffset;
      
      // Update text without triggering infinite loop
      _firstNameController.value = TextEditingValue(
        text: capitalizedText,
        selection: TextSelection.collapsed(
          offset: cursorPosition,
        ),
      );
      
      _isCapitalizing = false;
    }
  }

  Future<void> _handleComplete() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      _dismissKeyboard();

      final String firstNameValue = _firstNameController.text.trim();
      final String ageValue = _ageController.text.trim();
      final String deviceLocale = Platform.localeName;

      // Save firstName and age to SharedPreferences
      // This is fire-and-forget, doesn't need to be awaited for this flow
      SharedPreferences.getInstance().then((prefs) {
        if (firstNameValue.isNotEmpty) {
          prefs.setString('user_first_name', firstNameValue);
        }
        if (ageValue.isNotEmpty) {
          prefs.setString('user_age', ageValue);
          // Refresh quick actions so the shortcut text/audience updates
          QuickActionsService().refreshQuickActions();
        }
      });

      if (widget.onUpdateInfo != null) {
        widget.onUpdateInfo!(
          newFirstName: firstNameValue,
          newAge: ageValue,
        );
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      UserCredential? credential; 

      String userIdToUse;

      // SOFT LOGOUT: Check for preserved firestoreUserId
      final prefs = await SharedPreferences.getInstance();
      final preservedFirestoreUserId = prefs.getString('firestore_user_id');
      debugPrint('🔑 Checking for preserved firestoreUserId: $preservedFirestoreUserId');

      if (currentUser == null) {
        debugPrint('👤 User not authenticated. Creating anonymous account...');
        try {
          credential = await FirebaseAuth.instance.signInAnonymously();
          if (credential.user != null) {
            debugPrint('✅ Anonymous authentication successful: ${credential.user!.uid}');
            userIdToUse = credential.user!.uid;
            
            // Save the Firebase UID as firestoreUserId for future soft logouts
            await prefs.setString('firestore_user_id', userIdToUse);
            debugPrint('✅ Saved firestoreUserId for future use: $userIdToUse');
          } else {
            debugPrint('❌ Anonymous authentication failed: user is null');
            _navigateWithoutSaving(); 
            return; 
          }
        } catch (error) {
          debugPrint('❌ Error creating anonymous account: $error');
          _navigateWithoutSaving(); 
          return; 
        }
      } else {
        userIdToUse = currentUser.uid;
        
        // Save the Firebase UID as firestoreUserId if not already saved
        if (preservedFirestoreUserId == null) {
          await prefs.setString('firestore_user_id', userIdToUse);
          debugPrint('✅ Saved firestoreUserId for future use: $userIdToUse');
        }
      }
      
      await _performSaveDataAndNavigate(
        userIdToUse,
        firstNameValue,
        ageValue,
        widget.gender,
        deviceLocale,
        widget.questionnaireAnswers,
        currentUser?.isAnonymous ?? (credential != null) 
      );

    } catch (e) {
      debugPrint("Error in _handleComplete: $e");
      // Optionally: show a user-facing error message (e.g., SnackBar)
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _performSaveDataAndNavigate(
    String userId,
    String firstNameValue,
    String ageValue,
    String? gender,
    String deviceLocale,
    Map<int, String>? questionnaireAnswers,
    bool isAnonymous,
  ) async {
    debugPrint('✅ Saving profile data for user: $userId');
    
    MixpanelService.identifyUser(
      userId,
      name: firstNameValue.isEmpty ? null : firstNameValue,
      age: ageValue.isEmpty ? null : ageValue,
      gender: gender,
    );
    
    Superwall.shared.identify(userId);
    
    // Set Superwall user attributes for audience filtering
    await SuperwallUtils.setUserAttributes(
      firstName: firstNameValue.isEmpty ? null : firstNameValue,
      age: ageValue.isEmpty ? null : ageValue,
      gender: gender,
    );

    // Facebook Advanced Matching (set hashed user data when available)
    try {
      bool canSendMeta = true;
      if (Platform.isIOS) {
        final prefs = await SharedPreferences.getInstance();
        canSendMeta = prefs.getBool('fb_advertiser_tracking_enabled') ?? false;
      }

      if (canSendMeta) {
        final facebookAppEvents = FacebookAppEvents();
        final String? dobForMeta = _deriveDobFromAge(ageValue);
        await facebookAppEvents.setUserData(
          email: null, // email usually not set during onboarding
          firstName: firstNameValue.isEmpty ? null : firstNameValue,
          gender: gender?.isEmpty ?? true ? null : gender,
          dateOfBirth: dobForMeta,
        );
        debugPrint('✅ Facebook setUserData called from onboarding (dob=${dobForMeta ?? 'null'})');
      } else {
        debugPrint('ℹ️ Skipping Facebook setUserData due to ATT not authorized');
      }
    } catch (e) {
      debugPrint('❌ Facebook setUserData error (onboarding): $e');
    }
    
    await _userRepository.updateUserProfile(
      userId,
      firstName: firstNameValue.isEmpty ? null : firstNameValue,
      age: ageValue.isEmpty ? null : ageValue,
      gender: gender,
      locale: deviceLocale,
    );
    
    if (isAnonymous) {
      await _userRepository.refreshAnonymousUserTTL(userId);
    }
    
    if (questionnaireAnswers != null && questionnaireAnswers.isNotEmpty) {
      await _questionnaireRepository.saveQuestionnaireAnswers(
        userId: userId,
        answers: questionnaireAnswers,
      );
      
      // Create a batch for consumption and acquisition data
      WriteBatch batch = _firestore.batch();
      bool batchHasOperations = false;

      if (questionnaireAnswers.containsKey(100) && questionnaireAnswers.containsKey(104)) {
        final sugaryTreatsPerWeek = questionnaireAnswers[100];
        final String? rawConsumptionLevel = questionnaireAnswers[104];
        final String fullConsumptionLevel = rawConsumptionLevel ?? 'low (0)';
        final String baseLevel = fullConsumptionLevel.split(' (')[0];
        
        final consumptionData = {
          'sugaryTreatsPerWeek': sugaryTreatsPerWeek,
          'consumptionLevel': baseLevel,
          'formattedConsumptionLevel': fullConsumptionLevel,
          'treatSize': questionnaireAnswers[101] ?? 'medium',
          'caloriesPerTreat': questionnaireAnswers[102] ?? '0',
          'caloriesPerQuarter': questionnaireAnswers[103] ?? '0',
          'updatedAt': FieldValue.serverTimestamp(),
        };
        DocumentReference consumptionDocRef = _firestore.collection('users')
            .doc(userId)
            .collection('onboarding')
            .doc('consumption');
        batch.set(consumptionDocRef, consumptionData, SetOptions(merge: true));
        batchHasOperations = true;
            
        MixpanelService.trackEvent(
          'consumption_data_saved',
          properties: {
            'sugary_treats_per_week': sugaryTreatsPerWeek,
            'consumption_level': baseLevel,
            'formatted_consumption_level': fullConsumptionLevel,
            'treat_size': questionnaireAnswers[101] ?? 'medium'
          }
        );
      }
      
      if (questionnaireAnswers.containsKey(12)) {
        final acquisitionSource = questionnaireAnswers[12];
        
        final acquisitionData = {
          'source': acquisitionSource,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        DocumentReference acquisitionDocRef = _firestore.collection('users')
            .doc(userId)
            .collection('onboarding')
            .doc('acquisition');
        batch.set(acquisitionDocRef, acquisitionData, SetOptions(merge: true));
        batchHasOperations = true;
            
        MixpanelService.trackEvent(
          'acquisition_source_saved',
          properties: {
            'source': acquisitionSource
          }
        );
        MixpanelService.instance?.getPeople().set('acquisition_source', acquisitionSource);
      }

      if (batchHasOperations) {
        await batch.commit(); // Commit the batched writes
      }
    }
    
    await _progressService.clearOnboardingProgress();
    
    if (mounted) {
      // Check if user answered any questionnaire questions
      final hasQuestionnaireAnswers = questionnaireAnswers != null && questionnaireAnswers.isNotEmpty;
      
      // Redirect logic:
      // - If any questionnaire answers exist, go to Calculating
      // - If no answers, go to Symptoms
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => hasQuestionnaireAnswers
              ? const CalculatingScreen()
              : const SymptomsScreen(),
        ),
      );
    }
  }

  String? _deriveDobFromAge(String ageValue) {
    final intAge = int.tryParse(ageValue);
    if (intAge == null || intAge <= 0 || intAge > 120) return null;
    final now = DateTime.now();
    final year = now.year - intAge;
    return '${year.toString().padLeft(4, '0')}0101';
  }

  // Paywall logic removed from this screen.

  // Fallback navigation method when authentication fails
  void _navigateWithoutSaving() {
    // Check if user answered any questionnaire questions
    final hasQuestionnaireAnswers = widget.questionnaireAnswers != null && widget.questionnaireAnswers!.isNotEmpty;
    
    if (hasQuestionnaireAnswers) {
      // User answered questions - go to calculating/analysis flow
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const CalculatingScreen(),
        ),
      );
    } else {
      // User didn't answer any questions - go to symptoms screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const SymptomsScreen(),
        ),
      );
    }
  }
  
  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for white background
      statusBarBrightness: Brightness.light, // For iOS
    ));
    _firstNameController.dispose();
    _ageController.dispose();
    _firstNameFocusNode.dispose();
    _ageFocusNode.dispose(); // Dispose the age focus node
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for white background
        statusBarBrightness: Brightness.light, // For iOS
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              // Main content with scrollable area
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with back button and progress bar (optional)
                      if (!widget.hideHeader) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // Save current input values before going back
                                  if (widget.onUpdateInfo != null) {
                                    widget.onUpdateInfo!(
                                      newFirstName: _firstNameController.text.trim(),
                                      newAge: _ageController.text.trim(),
                                    );
                                  }
                                  
                                  // Always go back to question 13 (index 12) in QuestionnaireScreen
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) => QuestionnaireScreen(
                                        currentQuestionIndex: 12,
                                      ),
                                    ),
                                  );
                                },
                                child: SvgPicture.asset(
                                  'assets/images/svg/questions_back_icon.svg',
                                  width: 16,
                                  height: 14,
                                  colorFilter: const ColorFilter.mode(
                                    Color(0xFF1A1A1A), // Dark icon for white background
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: 15/16, // Almost complete
                                    minHeight: 8,
                                    backgroundColor: const Color(0xFFE0E0E0), // Light gray for white background
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFed3272)), // Brand pink
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Content area with scroll
                      Expanded(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.only(
                            top: widget.hideHeader ? 30 : 16,
                            bottom: 100, // Space for the fixed button
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Flexible spacing from top
                              SizedBox(height: widget.hideHeader ? 20 : 8),
                              
                              // Title
                              Center(
                                child: Text(
                                  AppLocalizations.of(context)!.translate('profileInfo_title'),
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A), // Dark text for white background
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Subtitle
                              Center(
                                child: Text(
                                  AppLocalizations.of(context)!.translate('profileInfo_subtitle'),
                                  style: const TextStyle(
                                    fontFamily: 'ElzaRound',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF666666), // Dark gray for white background
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // First name input (always show when coming from skip test)
                              if (!_hideFirstNameField || widget.questionnaireAnswers != null) ...[
                                _buildTextField(
                                  controller: _firstNameController,
                                  focusNode: _firstNameFocusNode,
                                  hintText: AppLocalizations.of(context)!.translate('profileInfo_firstNameHint'),
                                  keyboardType: TextInputType.name,
                                  isNameField: true,
                                ),
                                const SizedBox(height: 16),
                              ],
                              
                              // Age input field
                              _buildTextField(
                                controller: _ageController,
                                focusNode: _ageFocusNode,
                                hintText: AppLocalizations.of(context)!.translate('profileInfo_ageHint'),
                                keyboardType: TextInputType.number,
                                isNameField: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Fixed button at the bottom with keyboard-aware positioning
              Positioned(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom > 0 
                    ? MediaQuery.of(context).viewInsets.bottom + 12 
                    : 24,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: !_isFormValid ? null : const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFFed3272), // Strong pink/magenta
                        Color(0xFFfd5d32), // Vivid orange
                      ],
                    ),
                    color: !_isFormValid ? const Color(0xFF6B7280) : null, // Gray when disabled
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: ElevatedButton(
                    onPressed: (_isProcessing || !_isFormValid) ? null : _handleComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            AppLocalizations.of(context)!.translate('profileInfo_completeQuizButton'),
                            style: const TextStyle(
                              fontFamily: 'ElzaRound',
                              fontSize: 19, // Increased from 17 to 19
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required TextInputType keyboardType,
    required bool isNameField,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      scrollPadding: const EdgeInsets.only(bottom: 120),
      style: const TextStyle(color: Color(0xFF1A1A1A)), // Dark text for white background
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontFamily: 'ElzaRound',
          fontSize: 16,
          color: Color(0xFF999999), // Gray hint text
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)), // Light gray border
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)), // Light gray border
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFed3272), width: 2), // Brand pink focus
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        errorText: _getErrorMessage(controller, isNameField, focusNode),
        errorStyle: const TextStyle(
          color: Color(0xFFDC2626), // Better red for white background
          fontSize: 12,
          fontFamily: 'ElzaRound',
        ),
      ),
      textCapitalization: TextCapitalization.words,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      // Removed input formatters to allow all input
    );
  }

  // Helper method to determine the error message
  String? _getErrorMessage(TextEditingController controller, bool isNameField, FocusNode focusNode) {
    final text = controller.text.trim();
    
    // Show format errors immediately if text is not empty
    if (text.isEmpty) return null;
    
    if (isNameField) {
      final nameRegex = RegExp(r"^[\p{L}\s\-']+$", unicode: true);
      if (!nameRegex.hasMatch(text)) {
        return 'Please use only letters, spaces, hyphens or apostrophes';
      }
    } else { // Age field
      final ageRegex = RegExp(r'^[0-9]+$');
      if (!ageRegex.hasMatch(text)) {
        return AppLocalizations.of(context)!.translate('profileInfo_ageError_numbersOnly');
      }
      final ageValue = int.tryParse(text);
      if (ageValue == null || ageValue <= 0 || ageValue > 140) {
        return 'Please enter a valid age (1-140)';
      }
    }
    return null;
  }
} 