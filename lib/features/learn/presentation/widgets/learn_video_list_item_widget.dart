import 'package:flutter/material.dart';
import 'package:stoppr/features/learn/domain/models/learn_video_lesson.dart';
import 'package:stoppr/core/localization/app_localizations.dart'; // Import localization
import 'package:flutter_svg/flutter_svg.dart'; // Import flutter_svg

class LearnVideoListItemWidget extends StatelessWidget {
  final LearnVideoLesson lesson;
  final bool isLastItem;
  final VoidCallback? onTap;
  final bool nextLessonIsCompleted;
  final bool isFirstItem;
  final bool prevLessonIsCompleted;

  const LearnVideoListItemWidget({
    super.key,
    required this.lesson,
    required this.isLastItem,
    this.onTap,
    this.nextLessonIsCompleted = false,
    this.isFirstItem = false,
    this.prevLessonIsCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = Colors.blue.shade400; // Kept for reference, but specific colors will be used
    final Color lockedColor = Colors.grey.shade600;
    final Color completedColor = const Color(0xFF32B07F); // Green from learn_lesson_done.svg
    final Color inProgressColor = const Color(0xFF008CFF); // Blue from learn_lesson_in_progress.svg

    final bool isLocked = lesson.isLocked;
    final bool isCompleted = lesson.isCompleted;
    
    // Debug print to check if isFirstItem is working
    //debugPrint('LearnVideoListItemWidget: isFirstItem=$isFirstItem, title=${lesson.title}');
    
    Widget circleIndicator;
    Color lineConnectorColor;

    if (isCompleted) {
      circleIndicator = SvgPicture.asset(
        'assets/images/learn/learn_lesson_done.svg',
        width: 24, 
        height: 24,
        // colorFilter: ColorFilter.mode(activeColor, BlendMode.srcIn), // Removed colorFilter
      );
      lineConnectorColor = completedColor; // Use green for completed
    } else if (!isLocked) { // This is the current, uncompleted lesson
      circleIndicator = SvgPicture.asset(
        'assets/images/learn/learn_lesson_in_progress.svg',
        width: 24, 
        height: 24,
        // colorFilter: ColorFilter.mode(activeColor, BlendMode.srcIn), // Removed colorFilter
      );
      lineConnectorColor = inProgressColor; // Use blue for in-progress
    } else { // Locked
      circleIndicator = Container(
        width: 25, // Figma spec
        height: 25,
        decoration: BoxDecoration(
          color: Colors.white, // White fill
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFF2F0F3), // Figma stroke color
            width: 4, // Figma stroke weight
          ),
        ),
      );
      lineConnectorColor = const Color(0xFFF2F0F3); // Updated color
    }

    // Text Colors based on brand guidelines
    final Color titleColor = Color(0xFF1A1A1A); // Brand primary text color
    final Color durationColor = Color(0xFF666666); // Brand secondary text color
    final Color lockIconColor = Color(0xFF666666); // Brand secondary text color

    return Opacity(
      opacity: isLocked ? 0.6 : 1.0,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.grey.withOpacity(0.1), // Adjust highlight for light background
        child: Padding(
          padding: const EdgeInsets.only(left: 4.0, right: 16.0), // Increased right padding for margin
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center, 
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: SizedBox(
                  width: 40,
                  height: 128, // Reduced height for smaller item
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Continuous line behind the icons - Fixed layout without Expanded/Flexible inside Positioned
                      if (!isFirstItem)
                        Positioned(
                          top: 0,
                          left: 18,
                          height: 64, // Half of container height (128/2)
                          child: Container(
                            width: 4,
                            child: _buildAboveConnector(
                              isCompleted: isCompleted,
                              prevCompleted: prevLessonIsCompleted,
                              defaultColor: lineConnectorColor,
                              completedColor: completedColor,
                            ),
                          ),
                        ),
                      if (!isLastItem)
                        Positioned(
                          bottom: 0,
                          left: 18,
                          height: 64, // Half of container height (128/2)
                          child: Container(
                            width: 4,
                            child: _buildBelowConnector(
                              isCompleted: isCompleted,
                              nextCompleted: nextLessonIsCompleted,
                              defaultColor: lineConnectorColor,
                              completedColor: completedColor,
                            ),
                          ),
                        ),
                      // Icon on top of the line
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: circleIndicator,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8), // Reduced space to the right of the progress bar
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2.0), // Reduced vertical spacing
                  child: Stack(
                    children: [
                      // 3D effect: solid shadow
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        top: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(10.0), // Slightly smaller radius
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(bottom: 2.0),
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0), // Smaller padding
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F3F5),
                          borderRadius: BorderRadius.circular(10.0), // Slightly smaller radius
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4.0), // Added left padding to the title
                                    child: Text(
                                      AppLocalizations.of(context)!.translate(lesson.title),
                                      style: TextStyle(
                                        color: const Color(0xFF1A1A1A), // Brand primary text color
                                        fontSize: 24, // Increased font size
                                        fontWeight: FontWeight.w700, // Made font bolder
                                        fontFamily: 'ElzaRound', // Added ElzaRound font family
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (isLocked)
                                        SvgPicture.asset(
                                          'assets/images/learn/locker.svg',
                                          width: 16,
                                          height: 16,
                                          color: const Color(0x66153251), // 40% opacity
                                        ),
                                      if (isLocked)
                                        const SizedBox(width: 4),
                                      Text(
                                        lesson.duration,
                                        style: TextStyle(
                                          color: durationColor, // Updated text color
                                          fontSize: 13, // Slightly smaller
                                          fontFamily: 'ElzaRound',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10), // Smaller gap before thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8.0), // Slightly smaller radius
                              child: lesson.thumbnailAssetPath != null && lesson.thumbnailAssetPath!.isNotEmpty
                                  ? Image.asset(
                                      lesson.thumbnailAssetPath!,
                                      width: 65, // Smaller thumbnail
                                      height: 75, // Smaller thumbnail
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 65,
                                          height: 75,
                                          color: Colors.grey.shade300, 
                                          child: Icon(Icons.image_not_supported, color: Color(0xFF666666)), // Brand secondary text color
                                        );
                                      },
                                    )
                                  : Container( // Fallback for no thumbnail at all
                                      width: 65,
                                      height: 75,
                                      color: Colors.grey.shade300,
                                      child: Icon(Icons.image_not_supported, color: Color(0xFF666666)), // Brand secondary text color
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
          ),
        ),
      ),
    );
  }

  Widget _buildAboveConnector({
    required bool isCompleted,
    required bool prevCompleted,
    required Color defaultColor,
    required Color completedColor,
  }) {
    if (prevCompleted) {
      return _SolidLine(color: completedColor);
    }
    return _DashedLine(color: const Color(0xFFF2F0F3)); // Updated color
  }

  Widget _buildBelowConnector({
    required bool isCompleted,
    required bool nextCompleted,
    required Color defaultColor,
    required Color completedColor,
  }) {
    if (isCompleted) {
      return _SolidLine(color: completedColor);
    }
    return _DashedLine(color: const Color(0xFFF2F0F3)); // Updated color
  }
}

class _SolidLine extends StatelessWidget {
  final Color color;
  const _SolidLine({required this.color});

  @override
  Widget build(BuildContext context) => Container(width: 4, color: color); // Thicker line
}

class _DashedLine extends StatelessWidget {
  final Color color;
  final double dashHeight;
  final double dashGap;
  const _DashedLine({
    required this.color,
    this.dashHeight = 10, // Increased dash height
    this.dashGap = 6, // Increased dash gap
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxHeight = constraints.maxHeight;
        final dashCount = (boxHeight / (dashHeight + dashGap)).floor();
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashCount,
            (_) => SizedBox(
              width: 4, // Thicker dash
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            ),
          ),
        );
      },
    );
  }
} 