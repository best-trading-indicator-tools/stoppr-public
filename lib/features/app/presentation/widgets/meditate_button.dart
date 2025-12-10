import 'package:flutter/material.dart';
import '../../../../core/navigation/page_transitions.dart';
import '../screens/meditate_screen.dart';

class MeditateButton extends StatelessWidget {
  final VoidCallback? onPressed;
  
  const MeditateButton({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed ?? () {
        Navigator.of(context).push(
          BottomToTopPageRoute(
            child: const MeditateScreen(),
            settings: const RouteSettings(name: '/meditate'),
          ),
        );
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF231132),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.self_improvement,
            size: 32,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
} 