import 'package:flutter/material.dart';

class BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 55,
      decoration: const BoxDecoration(
        color: Color(0xFF140120),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              Icons.grid_view,
              color: currentIndex == 0 ? Colors.white : Colors.grey,
              size: 24
            ),
            onPressed: () => onTap(0),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: Icon(
              Icons.bar_chart,
              color: currentIndex == 1 ? Colors.white : Colors.grey,
              size: 24
            ),
            onPressed: () => onTap(1),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: Icon(
              Icons.star,
              color: currentIndex == 2 ? Colors.white : Colors.grey,
              size: 24
            ),
            onPressed: () => onTap(2),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: Icon(
              Icons.menu,
              color: currentIndex == 3 ? Colors.white : Colors.grey,
              size: 24
            ),
            onPressed: () => onTap(3),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
} 