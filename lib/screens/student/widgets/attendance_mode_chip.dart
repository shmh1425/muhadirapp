import 'package:flutter/material.dart';

/// QR / NFC / Bluetooth mode pill (student attendance & gate screens).
class AttendanceModeChip extends StatelessWidget {
  const AttendanceModeChip({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF006571) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isActive
              ? null
              : Border.all(
                  color: const Color(0xFF006571).withValues(alpha: 0.22),
                ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF006571),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
