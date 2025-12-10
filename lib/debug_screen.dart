import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DebugScreen extends StatelessWidget {
  final String title;
  final List<String> debugInfo;
  final Color backgroundColor;

  const DebugScreen({
    super.key,
    required this.title,
    required this.debugInfo,
    this.backgroundColor = Colors.green,
  });

  static void showSuccess({
    required BuildContext context,
    required String title,
    required List<String> debugInfo,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DebugScreen(
          title: title,
          debugInfo: debugInfo,
          backgroundColor: Colors.green,
        ),
      ),
    );
  }

  static void showError({
    required BuildContext context,
    required String title,
    required List<String> debugInfo,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DebugScreen(
          title: title,
          debugInfo: debugInfo,
          backgroundColor: Colors.red,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = FirebaseAuth.instance;
    
    return Scaffold(
      backgroundColor: backgroundColor.withOpacity(0.1),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // X button top left
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: backgroundColor,
                      size: 32,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Title
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Current user info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '👤 Current User:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      auth.currentUser != null 
                          ? 'UID: ${auth.currentUser!.uid}'
                          : 'No user authenticated',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                    if (auth.currentUser != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Anonymous: ${auth.currentUser!.isAnonymous}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Debug info
              const Text(
                '🐛 Debug Information:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 12),
              
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: debugInfo.map((info) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          info,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: backgroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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