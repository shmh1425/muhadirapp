import '../screens/lecturer/lecturer_language.dart';

enum LecturerActivityKind { theoretical, practical, unknown }

/// Normalizes Firestore / schedule activity values for lecturer UI labels.
class LecturerActivityLocalization {
  LecturerActivityLocalization._();

  static const List<String> _practicalTokens = [
    'عملي',
    'practical',
    'practice',
    'lab',
    'laboratory',
    'معمل',
  ];

  static const List<String> _theoreticalTokens = [
    'نظري',
    'theoretical',
    'theory',
    'lecture',
  ];

  static LecturerActivityKind kindFromValue(String? raw) {
    final normalized = _normalize(raw);
    if (normalized.isEmpty) return LecturerActivityKind.unknown;

    if (_matchesTokens(normalized, _practicalTokens)) {
      return LecturerActivityKind.practical;
    }
    if (_matchesTokens(normalized, _theoreticalTokens)) {
      return LecturerActivityKind.theoretical;
    }
    return LecturerActivityKind.unknown;
  }

  static bool isPractical(String? raw) =>
      kindFromValue(raw) == LecturerActivityKind.practical;

  static String label(String? raw, {LecturerLanguage? language}) {
    switch (kindFromValue(raw)) {
      case LecturerActivityKind.practical:
        return LecturerLanguageController.tr(
          'عملي',
          'Practical',
          language: language,
        );
      case LecturerActivityKind.theoretical:
        return LecturerLanguageController.tr(
          'نظري',
          'Theoretical',
          language: language,
        );
      case LecturerActivityKind.unknown:
        return (raw ?? '').trim();
    }
  }

  static String _normalize(String? raw) {
    return (raw ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
  }

  static bool _matchesTokens(String normalized, List<String> tokens) {
    for (final token in tokens) {
      final t = token.toLowerCase();
      if (normalized == t) return true;
      if (normalized.contains(t)) return true;
    }
    return false;
  }
}
