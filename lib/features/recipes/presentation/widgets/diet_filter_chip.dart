import 'package:flutter/material.dart';

/// Diet filter chip widget with Stoppr brand styling
/// Per style_brand.md: gradient when selected, white when unselected
class DietFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const DietFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          // Per style_brand.md: gradient when selected, white when unselected
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFFed3272), // Brand pink
                    Color(0xFFfd5d32), // Brand orange
                  ],
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(16), // Per style guide
          border: isSelected
              ? null
              : Border.all(
                  color: const Color(0xFFE0E0E0), // Light gray border
                  width: 1,
                ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'ElzaRound',
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white // White text on gradient
                : const Color(0xFF1A1A1A), // Dark text on white
          ),
        ),
      ),
    );
  }
}

