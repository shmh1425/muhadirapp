import 'package:flutter/material.dart';

class ProfileBackButton extends StatelessWidget {
  const ProfileBackButton({
    super.key,
    required this.onTap,
    this.color = const Color(0xFF006571),
  });

  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD6E6E8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconTheme(
            data: IconThemeData(color: color, size: 15),
            child: const BackButtonIcon(),
          ),
        ),
      ),
    );
  }
}
