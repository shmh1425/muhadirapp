import 'package:flutter/material.dart';

import '../translation_controller.dart';
import '../translation_service.dart';

/// Drop-in replacement for [Text] that translates Arabic text to English
/// when [TranslationController.translateToEnglish] is enabled.
class TText extends StatelessWidget {
  const TText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    final controller = TranslationController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final shouldTranslate = controller.translateToEnglish &&
            TranslationService.instance.containsArabic(data);
        if (!shouldTranslate) {
          return Text(
            data,
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
            softWrap: softWrap,
          );
        }

        return FutureBuilder<String>(
          future: TranslationService.instance.toEnglish(data),
          builder: (context, snap) {
            final text = snap.data ?? data;
            return Text(
              text,
              style: style,
              textAlign: textAlign,
              maxLines: maxLines,
              overflow: overflow,
              softWrap: softWrap,
            );
          },
        );
      },
    );
  }
}

