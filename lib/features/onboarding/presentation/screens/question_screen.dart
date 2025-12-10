import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'symptoms_screen.dart'; // Add import for direct navigation
import 'package:stoppr/core/navigation/page_transitions.dart';

class QuestionScreen extends StatefulWidget {
  final VoidCallback? onNext;
  final VoidCallback? onSkip;
  final int questionNumber;
  final String question;
  final List<String> options;
  final VoidCallback? onPrevious;
  
  const QuestionScreen({
    super.key,
    required this.questionNumber,
    required this.question,
    required this.options,
    required this.onNext,
    this.onPrevious,
    this.onSkip,
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  int? _selectedOption;

  void _handleOptionSelected(int index) {
    setState(() {
      _selectedOption = index;
    });
    
    // Automatically proceed to next question after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (widget.onNext != null) {
        widget.onNext!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF2F4),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Progress bar and back button row
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (widget.onPrevious != null) {
                        // Always use the onPrevious callback if it exists
                        widget.onPrevious!();
                      } else {
                        // Fallback - only if no onPrevious is provided
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
                    child: SvgPicture.asset(
                      'assets/images/svg/questions_back_icon.svg',
                      width: 16,
                      height: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: widget.questionNumber / 14, // Updated to 14 questions total
                        minHeight: 8,
                        backgroundColor: const Color(0xFFFFE3E3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Question title
            Center(
              child: Text(
                'Question #${widget.questionNumber}',
                style: const TextStyle(
                  fontFamily: 'ElzaRound',
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A051D),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Question text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Center(
                child: Text(
                  widget.question,
                  style: const TextStyle(
                    fontFamily: 'ElzaRound',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A051D),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Options list
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(
                    widget.options.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(
                        left: 24.0, 
                        right: 24.0, 
                        bottom: 16.0
                      ),
                      child: GestureDetector(
                        onTap: () => _handleOptionSelected(index),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: _selectedOption == index
                                ? Border.all(color: const Color(0xFFFF9988), width: 2)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16.0,
                              horizontal: 16.0,
                            ),
                            child: Row(
                              children: [
                                // Numbered circle
                                Container(
                                  width: 29,
                                  height: 29,
                                  decoration: BoxDecoration(
                                    color: _selectedOption == index
                                        ? const Color(0xFFFE5C71) // Pinkish-red when selected
                                        : const Color(0xFFFF9988), // Default coral color
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        fontFamily: 'ElzaRound',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Option text
                                Expanded(
                                  child: Text(
                                    widget.options[index],
                                    style: const TextStyle(
                                      fontFamily: 'ElzaRound',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1A051D),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Skip test button
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: GestureDetector(
                  onTap: () {
                    if (widget.onSkip != null) {
                      widget.onSkip!();
                    } else {
                      // If no callback provided, navigate directly to SymptomsScreen with fade transition
                      Navigator.of(context).pushReplacement(
                        FadePageRoute(
                          child: const SymptomsScreen(),
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Skip test',
                    style: TextStyle(
                      fontFamily: 'ElzaRound',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 