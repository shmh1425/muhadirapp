import 'package:flutter/material.dart';

import '../translation_controller.dart';

/// Shared language switch used on login, welcome, settings headers, admin, etc.
///
/// Toggles [TranslationController] globally (persisted via Hive).
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({
    super.key,
    this.style = LanguageToggleStyle.chip,
    this.iconColor = const Color(0xFF006571),
  });

  final LanguageToggleStyle style;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final translation = TranslationController.instance;
    return AnimatedBuilder(
      animation: translation,
      builder: (context, _) {
        switch (style) {
          case LanguageToggleStyle.icon:
            return IconButton(
              onPressed: translation.toggle,
              tooltip: translation.toggleLabel,
              icon: Icon(Icons.language, color: iconColor),
            );
          case LanguageToggleStyle.chip:
            return Tooltip(
              message: translation.toggleLabel,
              child: Material(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: translation.toggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.language, color: iconColor, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          translation.languageSwitchTarget,
                          style: TextStyle(
                            color: iconColor,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}

enum LanguageToggleStyle { chip, icon }
