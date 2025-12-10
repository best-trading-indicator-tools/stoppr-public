import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import 'package:stoppr/core/utils/text_sanitizer.dart';

class PledgeCheckInWidget extends StatefulWidget {
  final Function(bool successful, String feeling, String? notes) onSubmit;
  final VoidCallback onClose;

  const PledgeCheckInWidget({
    super.key,
    required this.onSubmit,
    required this.onClose,
  });

  @override
  State<PledgeCheckInWidget> createState() => PledgeCheckInWidgetState();
}

class PledgeCheckInWidgetState extends State<PledgeCheckInWidget> with SingleTickerProviderStateMixin {
  bool _successfulPledge = true;
  String _feeling = 'Controlled';
  final TextEditingController _notesController = TextEditingController();
  bool _showDropdown = false;
  final List<String> _feelingOptions = ['Tempted', 'Controlled', 'Confident', 'Struggling'];
  bool _initializedFeeling = false;
  
  // Animation controller for slide up
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
  }
  
  void _initializeAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),  // Start from bottom
      end: Offset.zero,           // End at original position
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    // Start the animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  // Public method to start the slide-down animation
  void animateOut() {
    _animationController.reverse();
  }

  // Additional method to handle submission with animation
  void submitWithAnimation(bool successful, String feeling, String? notes) {
    // Animate first, then submit
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Localized feeling options (computed at build time)
    final List<String> localizedFeelingOptions = [
      l10n.translate('pledge_checkin_feeling_tempted'),
      l10n.translate('pledge_checkin_feeling_controlled'),
      l10n.translate('pledge_checkin_feeling_confident'),
      l10n.translate('pledge_checkin_feeling_struggling'),
    ];
    // Initialize default feeling once with the localized value
    if (!_initializedFeeling) {
      _feeling = localizedFeelingOptions[1];
      _initializedFeeling = true;
    }
    final size = MediaQuery.of(context).size;
    
    // Create the content widget
    Widget content = Container(
      height: size.height * 0.65, // 65% of screen height
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1), // Light gray border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)), // Dark icon for white background
                  onPressed: () {
                    // Animate out and close
                    _animationController.reverse();
                    widget.onClose();
                  },
                ),
                Text(
                  l10n.translate('pledge_checkin_title'),
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A), // Dark text for white background
                    fontSize: 18,
                    fontFamily: 'ElzaRound',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 48), // Empty space to balance the layout
              ],
            ),
          ),
          
          // Content - wrap in Expanded and SingleChildScrollView to handle overflow
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Successful Pledge toggle
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: const Color(0xFFE0E0E0), width: 0.5), // Light gray divider
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.translate('pledge_checkin_successful'),
                            style: const TextStyle(
                              color: const Color(0xFF1A1A1A), // Dark text for white background
                              fontSize: 18,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Switch(
                            value: _successfulPledge,
                            onChanged: (value) {
                              setState(() {
                                _successfulPledge = value;
                              });
                            },
                            activeColor: const Color(0xFFed3272),
                            activeTrackColor: const Color(0xFFfae6ec),
                            inactiveThumbColor: const Color(0xFFBDBDBD),
                            inactiveTrackColor: const Color(0xFFE0E0E0),
                          ),
                        ],
                      ),
                    ),

                    // How did you feel dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: const Color(0xFFE0E0E0), width: 0.5), // Light gray divider
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('pledge_checkin_howDidYouFeel'),
                            style: const TextStyle(
                              color: const Color(0xFF1A1A1A), // Dark text for white background
                              fontSize: 18,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showDropdown = !_showDropdown;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5), // Light gray background
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5), // Light gray border
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _feeling,
                                    style: const TextStyle(
                                      color: const Color(0xFF1A1A1A), // Dark text for white background
                                      fontSize: 16,
                                      fontFamily: 'ElzaRound',
                                    ),
                                  ),
                                  Icon(
                                    _showDropdown ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                    color: const Color(0xFF1A1A1A), // Dark text for white background
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Dropdown options
                          if (_showDropdown)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5), // Light gray border
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: localizedFeelingOptions.map((option) {
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _feeling = option;
                                        _showDropdown = false;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: option != localizedFeelingOptions.last
                                                ? Colors.white.withOpacity(0.3)
                                                : Colors.transparent,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          if (option == _feeling)
                                            const Icon(
                                              Icons.check,
                                              color: const Color(0xFF1A1A1A), // Dark text for white background
                                              size: 20,
                                            ),
                                          const SizedBox(width: 8),
                                          Text(
                                            option,
                                            style: TextStyle(
                                              color: const Color(0xFF1A1A1A), // Dark text for white background
                                              fontSize: 16,
                                              fontFamily: 'ElzaRound',
                                              fontWeight: option == _feeling ? FontWeight.w600 : FontWeight.w400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Additional notes input
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.translate('pledge_checkin_additionalNotes'),
                            style: const TextStyle(
                              color: const Color(0xFF1A1A1A), // Dark text for white background
                              fontSize: 18,
                              fontFamily: 'ElzaRound',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          TextField(
                            controller: _notesController,
                            style: const TextStyle(
                              color: const Color(0xFF1A1A1A), // Dark text for white background
                              fontFamily: 'ElzaRound',
                            ),
                            decoration: InputDecoration(
                              hintText: AppLocalizations.of(context)!.translate('pledge_thoughtsHint'),
                              hintStyle: const TextStyle(
                                color: Color(0xFF999999), // Light gray hint text
                                fontFamily: 'ElzaRound',
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE0E0E0)), // Light gray border
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFE0E0E0)), // Light gray border
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFed3272)), // Brand pink when focused
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF5F5F5), // Light gray background
                              contentPadding: const EdgeInsets.all(12),
                            ),
                            maxLines: 4,
                            minLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Submit button - fixed at bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: () {
                _animationController.reverse();
                final String? rawNotes = _notesController.text.isEmpty ? null : _notesController.text;
                final String? sanitizedNotes = rawNotes == null
                    ? null
                    : TextSanitizer.sanitizeForDisplay(rawNotes);
                widget.onSubmit(
                  _successfulPledge,
                  _feeling,
                  sanitizedNotes,
                );
              },
              child: Ink(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFFed3272), Color(0xFFfd5d32)],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(28)),
                ),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  child: Text(
                    AppLocalizations.of(context)!.translate('common_submit'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'ElzaRound',
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    
    // Wrap with animation and positioning
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent background overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                // Animate out and close
                _animationController.reverse();
                widget.onClose();
              },
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          ),
          
          // Animated slide-up panel
          Positioned(
            bottom: 0, // Start from the bottom edge of the screen
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: content,
            ),
          ),
        ],
      ),
    );
  }
} 