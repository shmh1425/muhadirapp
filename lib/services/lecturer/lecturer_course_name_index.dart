import '../../models/lecturer/unified_lecturer_catalog.dart';

/// In-memory bilingual course names keyed by course code and section id.
/// Populated from [UnifiedLecturerCatalog] for notification display fallbacks.
class LecturerCourseNameIndex {
  LecturerCourseNameIndex._();

  static final LecturerCourseNameIndex instance = LecturerCourseNameIndex._();

  final Map<String, BilingualCourseName> _byCourseCode = {};
  final Map<String, BilingualCourseName> _bySectionId = {};

  void updateFromCatalog(UnifiedLecturerCatalog catalog) {
    _byCourseCode.clear();
    _bySectionId.clear();
    for (final row in catalog.rows) {
      final names = BilingualCourseName(
        ar: row.courseNameAr.trim(),
        en: row.courseNameEn.trim(),
      );
      final code = row.courseCode.trim();
      if (code.isNotEmpty) {
        final prev = _byCourseCode[code];
        _byCourseCode[code] = prev == null ? names : prev.merge(names);
      }
      final sectionId = row.sectionId.trim();
      if (sectionId.isNotEmpty) {
        _bySectionId[sectionId] = names;
      }
    }
  }

  void clear() {
    _byCourseCode.clear();
    _bySectionId.clear();
  }

  BilingualCourseName? lookup({String? courseCode, String? sectionId}) {
    final sid = (sectionId ?? '').trim();
    if (sid.isNotEmpty) {
      final hit = _bySectionId[sid];
      if (hit != null) return hit;
    }
    final code = (courseCode ?? '').trim();
    if (code.isNotEmpty) {
      return _byCourseCode[code];
    }
    return null;
  }
}

class BilingualCourseName {
  const BilingualCourseName({required this.ar, required this.en});

  final String ar;
  final String en;

  BilingualCourseName merge(BilingualCourseName other) {
    return BilingualCourseName(
      ar: ar.isNotEmpty ? ar : other.ar,
      en: en.isNotEmpty ? en : other.en,
    );
  }

  String pick({required bool isArabic}) {
    if (isArabic) {
      return ar.isNotEmpty ? ar : en;
    }
    return en.isNotEmpty ? en : ar;
  }
}
