import 'package:flutter/material.dart';

import '../lecturer_language.dart';

/// Back/forward chevrons for lecturer screens — keyed off [LecturerLanguageController]
/// so the arrow flips when Arabic is active, independent of ambient [Directionality].
class LecturerDirectionalBackIcon extends StatelessWidget {
  const LecturerDirectionalBackIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, language, _) {
        final isArabic = language == LecturerLanguage.arabic;
        return Icon(
          isArabic ? Icons.chevron_right : Icons.chevron_left,
          size: size,
          color: color,
          textDirection: TextDirection.ltr,
        );
      },
    );
  }
}

class LecturerDirectionalForwardIcon extends StatelessWidget {
  const LecturerDirectionalForwardIcon({super.key, this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, language, _) {
        final isArabic = language == LecturerLanguage.arabic;
        return Icon(
          isArabic ? Icons.chevron_left : Icons.chevron_right,
          size: size,
          color: color,
          textDirection: TextDirection.ltr,
        );
      },
    );
  }
}
