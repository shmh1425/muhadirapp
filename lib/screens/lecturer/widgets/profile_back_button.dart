import 'package:flutter/material.dart';

import 'directional_navigation_icon.dart';

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
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
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? scheme.outlineVariant.withValues(alpha: 0.45)
                  : const Color(0xFFD6E6E8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
                blurRadius: 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LecturerDirectionalBackIcon(color: color, size: 15),
        ),
      ),
    );
  }
}
