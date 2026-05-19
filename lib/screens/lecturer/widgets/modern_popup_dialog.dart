import 'package:flutter/material.dart';

import '../lecturer_language.dart';

class ModernPopupDialog extends StatelessWidget {
  const ModernPopupDialog({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.accentColor = const Color(0xFF006571),
  });

  static const TextStyle _titleStyle = TextStyle(
    fontFamily: 'Cairo',
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: Color(0xFF213236),
    height: 1.25,
  );

  static const TextStyle _bodyStyle = TextStyle(
    fontFamily: 'Cairo',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFF475569),
    height: 1.45,
  );

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
            DefaultTextStyle(
              style: _titleStyle.copyWith(color: accentColor),
              textAlign: TextAlign.center,
              child: Center(child: title),
            ),
            const SizedBox(height: 12),
            DefaultTextStyle(
              style: _bodyStyle,
              textAlign: TextAlign.center,
              child: Center(child: child),
            ),
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

class ModernPopupSheet extends StatelessWidget {
  const ModernPopupSheet({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.onClose,
    this.accentColor = const Color(0xFF006571),
    this.padding = const EdgeInsets.fromLTRB(18, 12, 18, 16),
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.showHandle = true,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final VoidCallback? onClose;
  final Color accentColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final hasHeader =
        (title != null && title!.trim().isNotEmpty) ||
        (subtitle != null && subtitle!.trim().isNotEmpty) ||
        onClose != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        // Bottom sheets pass a finite max height; keep header visible and scroll body.
        const reservedForChrome = 140.0;
        Widget body = child;
        if (maxH.isFinite && maxH < double.infinity) {
          final cap = (maxH - reservedForChrome).clamp(0.0, maxH);
          if (cap > 0) {
            body = ConstrainedBox(
              constraints: BoxConstraints(maxHeight: cap),
              child: SingleChildScrollView(child: child),
            );
          }
        }

        return Container(
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accentColor.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHandle)
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: EdgeInsets.only(bottom: hasHeader ? 12 : 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6DDE0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              if (hasHeader) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null && title!.trim().isNotEmpty)
                            Text(
                              title!,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                              ),
                            ),
                          if (subtitle != null &&
                              subtitle!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle!,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF60757A),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onClose != null)
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded),
                        color: const Color(0xFF60757A),
                        tooltip: LecturerLanguageController.tr(
                          'إغلاق',
                          'Close',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              body,
            ],
          ),
        );
      },
    );
  }
}
