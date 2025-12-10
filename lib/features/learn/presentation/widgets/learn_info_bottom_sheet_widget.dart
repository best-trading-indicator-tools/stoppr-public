import 'package:flutter/material.dart';

class LearnInfoBottomSheetWidget extends StatelessWidget {
  final Widget icon;
  final String title;
  final TextStyle? titleTextStyle;
  final String message;
  final String primaryButtonText;
  final VoidCallback onPrimaryButtonPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryButtonPressed;
  final Color primaryButtonColor;
  final Color primaryButtonTextColor;
  final Color secondaryButtonTextColor;

  const LearnInfoBottomSheetWidget({
    super.key,
    required this.icon,
    required this.title,
    this.titleTextStyle,
    required this.message,
    required this.primaryButtonText,
    required this.onPrimaryButtonPressed,
    this.secondaryButtonText,
    this.onSecondaryButtonPressed,
    this.primaryButtonColor = const Color(0xFFF0F0F0), // Default light grey
    this.primaryButtonTextColor = Colors.black87,
    this.secondaryButtonTextColor = Colors.black54,
  });

  @override
  Widget build(BuildContext context) {
    // Using MediaQuery to make it somewhat responsive to screen height,
    // but DraggableScrollableSheet is better for precise 50% height.
    // For now, simple fixed padding and content.
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      margin: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 64.0), // Add horizontal and bottom margin
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(
          Radius.circular(42.0), // Increased border radius
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 12.0), // Reduced bottom padding
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: icon,
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: titleTextStyle ?? const TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                color: Colors.black87, // Color from image
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.0,
                color: Colors.grey.shade600, // Color from image
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28.0), // Space before button, adjust as needed
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryButtonColor,
                foregroundColor: primaryButtonTextColor,
                minimumSize: const Size(double.infinity, 56), // Full width, specific height
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0), // More rounded corners
                ),
                elevation: 0,
              ),
              onPressed: onPrimaryButtonPressed,
              child: Text(primaryButtonText, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            if (secondaryButtonText != null && onSecondaryButtonPressed != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0), // Space between buttons
                child: TextButton(
                  onPressed: onSecondaryButtonPressed,
                  style: TextButton.styleFrom(
                     minimumSize: const Size(double.infinity, 44), // Full width for tappable area
                  ),
                  child: Text(
                    secondaryButtonText!,
                    style: TextStyle(
                      fontSize: 17.0,
                      color: secondaryButtonTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8.0 : 12.0), // Less bottom space
          ],
        ),
      ),
    );
  }
}

// Helper function to show the bottom sheet
Future<void> showLearnInfoBottomSheet(BuildContext context, {
  required Widget icon,
  required String title,
  TextStyle? titleTextStyle,
  required String message,
  required String primaryButtonText,
  required VoidCallback onPrimaryButtonPressed,
  String? secondaryButtonText,
  VoidCallback? onSecondaryButtonPressed,
  Color primaryButtonColor = const Color(0xFFF0F0F0),
  Color primaryButtonTextColor = Colors.black87,
  Color secondaryButtonTextColor = Colors.black54,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, 
    backgroundColor: Colors.transparent, 
    builder: (BuildContext sheetContext) {
      return Padding(
        // Padding to ensure the sheet doesn't go under navigation bars etc.
        // and to control its maximum extent if not using DraggableScrollableSheet strictly.
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Wrap( // Wrap content to allow sheet to take natural height up to a point
            children: [
                LearnInfoBottomSheetWidget(
                    icon: icon,
                    title: title,
                    titleTextStyle: titleTextStyle,
                    message: message,
                    primaryButtonText: primaryButtonText,
                    onPrimaryButtonPressed: onPrimaryButtonPressed,
                    secondaryButtonText: secondaryButtonText,
                    onSecondaryButtonPressed: onSecondaryButtonPressed,
                    primaryButtonColor: primaryButtonColor,
                    primaryButtonTextColor: primaryButtonTextColor,
                    secondaryButtonTextColor: secondaryButtonTextColor,
                ),
            ],
        ),
      );
    },
  );
} 