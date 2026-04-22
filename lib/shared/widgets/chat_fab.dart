import 'package:flutter/material.dart';

import '../../features/chatbot/screens/chatbot_screen.dart';

/// زر عائم = الصورة فقط (هوية محاضر) بدون خلفية ولا مربع.
class ChatFAB extends StatelessWidget {
  const ChatFAB({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Transform.translate(
        offset: const Offset(-22, 40),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ChatbotScreen(),
              ),
            );
          },
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 120,
            height: 120,
            child: Image.asset(
              'assets/images/chatbot_icon.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.chat_bubble_rounded,
                color: Color(0xFF006571),
                size: 36,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
