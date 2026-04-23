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
    _translateToEnglish = !_translateToEnglish;
    notifyListeners();
  }

  /// Returns proper label for the toggle button.
  String get toggleLabel =>
      _translateToEnglish ? 'Translate to Arabic' : 'Translate to English';
}

