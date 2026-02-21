import 'package:flutter/material.dart';

enum LecturerLanguage { arabic, english }

class LecturerLanguageController {
  LecturerLanguageController._();

  static final ValueNotifier<LecturerLanguage> notifier = ValueNotifier(
    LecturerLanguage.arabic,
  );

  static LecturerLanguage get current => notifier.value;

  static bool get isArabic => current == LecturerLanguage.arabic;

  static TextDirection direction([LecturerLanguage? language]) {
    final lang = language ?? current;
    return lang == LecturerLanguage.arabic
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  static String tr(String ar, String en, {LecturerLanguage? language}) {
    final lang = language ?? current;
    return lang == LecturerLanguage.arabic ? ar : en;
  }

  static String dayNameFromWeekday(int weekday, {LecturerLanguage? language}) {
    switch (weekday) {
      case 7:
        return tr('الأحد', 'Sunday', language: language);
      case 1:
        return tr('الاثنين', 'Monday', language: language);
      case 2:
        return tr('الثلاثاء', 'Tuesday', language: language);
      case 3:
        return tr('الأربعاء', 'Wednesday', language: language);
      case 4:
        return tr('الخميس', 'Thursday', language: language);
      case 5:
        return tr('الجمعة', 'Friday', language: language);
      case 6:
        return tr('السبت', 'Saturday', language: language);
      default:
        return tr('غير محدد', 'Unknown', language: language);
    }
  }

  static String dayNameFromArabic(
    String arabicDay, {
    LecturerLanguage? language,
  }) {
    switch (arabicDay) {
      case 'اليوم':
        return tr('اليوم', 'Today', language: language);
      case 'غدًا':
        return tr('غدًا', 'Tomorrow', language: language);
      case 'الكل':
        return tr('الكل', 'All', language: language);
      case 'الأحد':
        return tr('الأحد', 'Sunday', language: language);
      case 'الاثنين':
        return tr('الاثنين', 'Monday', language: language);
      case 'الثلاثاء':
        return tr('الثلاثاء', 'Tuesday', language: language);
      case 'الأربعاء':
        return tr('الأربعاء', 'Wednesday', language: language);
      case 'الخميس':
        return tr('الخميس', 'Thursday', language: language);
      case 'الجمعة':
        return tr('الجمعة', 'Friday', language: language);
      case 'السبت':
        return tr('السبت', 'Saturday', language: language);
      default:
        return arabicDay;
    }
  }
}
