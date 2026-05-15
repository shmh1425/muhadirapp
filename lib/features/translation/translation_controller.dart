import 'package:flutter/widgets.dart';

/// Global translation + direction controller.
///
/// - Default: Arabic UI (RTL) with original strings.
/// - Toggled: English UI (LTR) where Arabic strings are translated.
class TranslationController extends ChangeNotifier {
  TranslationController._();
  static final TranslationController instance = TranslationController._();

  bool _translateToEnglish = false;

  bool get translateToEnglish => _translateToEnglish;
  TextDirection get textDirection =>
      _translateToEnglish ? TextDirection.ltr : TextDirection.rtl;

  Locale get locale =>
      _translateToEnglish ? const Locale('en') : const Locale('ar');

  void toggle() {
    setTranslateToEnglish(!_translateToEnglish);
  }

  void setTranslateToEnglish(bool toEnglish) {
    if (_translateToEnglish == toEnglish) return;
    _translateToEnglish = toEnglish;
    notifyListeners();
  }

  /// Tooltip for language icon buttons (settings header, welcome, etc.).
  String get toggleLabel => 'English | عربي';
}

