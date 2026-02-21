import 'package:flutter/material.dart';

class ModernPopupDialog extends StatelessWidget {
  const ModernPopupDialog({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.accentColor = const Color(0xFF006571),
  });

  final Widget title;
  final Widget child;
  final List<Widget> actions;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accentColor.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFD8D8D8),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            title,
            const SizedBox(height: 12),
            child,
            const SizedBox(height: 14),
            Row(
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  Expanded(child: actions[i]),
                  if (i != actions.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ModernPopupActionButton extends StatelessWidget {
  const ModernPopupActionButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.isPrimary,
    this.primaryColor = const Color(0xFF006571),
  });

  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    final button = Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isPrimary ? null : const Color(0xFFF2F2F2),
        gradient: isPrimary
            ? LinearGradient(
                colors: [primaryColor.withValues(alpha: 0.8), primaryColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w700,
          color: isPrimary ? Colors.white : const Color(0xFF444444),
        ),
      ),
    );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: button,
    );
  }
}
