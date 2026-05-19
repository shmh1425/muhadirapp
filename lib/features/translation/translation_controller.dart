import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';

/// Global translation + direction controller.
///
/// - Default: Arabic UI (RTL) with original strings.
/// - Toggled: English UI (LTR) where Arabic strings are translated.
class TranslationController extends ChangeNotifier {
  TranslationController._();
  static final TranslationController instance = TranslationController._();

  static const String _boxName = 'translation_preferences';
  static const String _translateToEnglishKey = 'translate_to_english';

  bool _translateToEnglish = false;
  Box<dynamic>? _box;

  bool get translateToEnglish => _translateToEnglish;
  TextDirection get textDirection =>
      _translateToEnglish ? TextDirection.ltr : TextDirection.rtl;

  Locale get locale =>
      _translateToEnglish ? const Locale('en') : const Locale('ar');

  /// Bilingual helper used across login, admin, and role screens.
  String tr(String ar, String en) => _translateToEnglish ? en : ar;

  /// Label on the language chip: target language after tap.
  String get languageSwitchTarget => _translateToEnglish ? 'عربي' : 'EN';

  void toggle() {
    setTranslateToEnglish(!_translateToEnglish);
  }

  void setTranslateToEnglish(bool toEnglish) {
    if (_translateToEnglish == toEnglish) return;
    _translateToEnglish = toEnglish;
    unawaited(_savePreference(toEnglish));
    notifyListeners();
  }

  Future<void> loadSavedPreference() async {
    final box = await Hive.openBox<dynamic>(_boxName);
    _box = box;
    final saved =
        box.get(_translateToEnglishKey, defaultValue: false) == true;
    if (_translateToEnglish != saved) {
      _translateToEnglish = saved;
      notifyListeners();
    }
  }

  Future<void> _savePreference(bool toEnglish) async {
    final box = _box ?? await Hive.openBox<dynamic>(_boxName);
    _box = box;
    await box.put(_translateToEnglishKey, toEnglish);
  }

  /// Tooltip for language icon buttons (settings header, welcome, etc.).
  String get toggleLabel => 'English | عربي';
}
