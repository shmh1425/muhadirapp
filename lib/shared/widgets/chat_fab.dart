import 'package:flutter/material.dart';

import '../../features/chatbot/screens/chatbot_screen.dart';

/// Floating action button to open MUHADIR AI chatbot from any screen.
class ChatFAB extends StatelessWidget {
  const ChatFAB({super.key});

  static const Color _primaryColor = Color(0xFF006571);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ChatbotScreen(),
          ),
        );
      },
      backgroundColor: _primaryColor,
      child: const Icon(
        Icons.chat_bubble_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}
