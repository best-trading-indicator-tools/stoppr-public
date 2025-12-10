import 'package:flutter/material.dart';
import '../../../../core/navigation/page_transitions.dart';
import '../screens/pledge_screen.dart';

class PledgeButton extends StatelessWidget {
  final VoidCallback? onPressed;
  
  const PledgeButton({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed ?? () {
        // Use bottom-to-top transition for pledges
        Navigator.of(context).pushReplacement(
          BottomToTopPageRoute(
            child: const PledgeScreen(),
            settings: const RouteSettings(name: '/pledge'),
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
        child: Center(
          child: Image.asset(
            'assets/images/onboarding/raising_hand.png',
            width: 32,
            height: 32,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
} 