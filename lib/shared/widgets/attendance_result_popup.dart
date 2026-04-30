import 'dart:async';

import 'package:flutter/material.dart';

class AttendanceResultPopup {
  AttendanceResultPopup._();

  static const Color _tiffanyBg = Color(0xFFE7FAF7);
  static const Color _tiffanyFg = Color(0xFF1A8F86);
  static const Color _errorFg = Color(0xFFD32F2F);

  static Future<void> show(
    BuildContext context, {
    required bool success,
    required String message,
    String? subtitle,
    bool autoDismiss = true,
    Duration autoDismissAfter = const Duration(seconds: 2),
  }) async {
    if (!context.mounted) return;

    Timer? timer;
    if (autoDismiss) {
      timer = Timer(autoDismissAfter, () {
        if (context.mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      });
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final fg = success ? _tiffanyFg : _errorFg;
        final icon = success ? Icons.check_rounded : Icons.priority_high_rounded;

        return Dialog(
          backgroundColor: _tiffanyBg,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fg.withValues(alpha: 0.10),
                    border: Border.all(
                      color: fg.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 110, color: fg),
                ),
                const SizedBox(height: 18),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Color(0xFF3A3A3A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ).whenComplete(() => timer?.cancel());
  }
}

