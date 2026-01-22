import 'package:flutter/material.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.size = 42, this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: ShaderMask(
          shaderCallback: (bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF27A2A9), Color(0xFF006571)],
            ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
          },
          child: const Icon(
            Icons.notifications,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
