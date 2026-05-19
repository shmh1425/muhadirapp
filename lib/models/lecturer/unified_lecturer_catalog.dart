import 'lecture_item.dart';

/// Bilingual schedule rows for a lecturer (cacheable metadata).
///
/// [toLectureItems] applies the current UI language without re-hitting Firestore.
class UnifiedLecturerCatalog {
  const UnifiedLecturerCatalog({required this.rows});

  final List<LecturerCatalogRow> rows;

  factory UnifiedLecturerCatalog.empty() =>
      const UnifiedLecturerCatalog(rows: <LecturerCatalogRow>[]);

  bool get isEmpty => rows.isEmpty;

  Set<String> get sectionIds =>
      rows.map((r) => r.sectionId).where((id) => id.isNotEmpty).toSet();

  List<LectureItem> toLectureItems({required bool isArabic}) =>
      rows.map((r) => r.toLectureItem(isArabic: isArabic)).toList();

  Map<String, dynamic> toHiveMap() => <String, dynamic>{
        'v': 1,
        'rows': rows.map((r) => r.toJson()).toList(),
      };

  factory UnifiedLecturerCatalog.fromHiveMap(dynamic raw) {
    if (raw is! Map) return UnifiedLecturerCatalog.empty();
    final list = raw['rows'];
    if (list is! List) return UnifiedLecturerCatalog.empty();
    final rows = <LecturerCatalogRow>[];
    for (final e in list) {
      if (e is Map) {
        rows.add(LecturerCatalogRow.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return UnifiedLecturerCatalog(rows: rows);
  }
}

/// One schedule slot row derived from Firestore `sections` + `courses`.
class LecturerCatalogRow {
  const LecturerCatalogRow({
    required this.sectionId,
    required this.courseCode,
    required this.courseNameAr,
    required this.courseNameEn,
    required this.sectionNum,
    required this.dayOfWeek,
    required this.startTime,
    required this.scheduleEndTime,
    required this.hall,
    required this.activity,
    this.location,
    required this.isDouble,
  });

  final String sectionId;
  final String courseCode;
  final String courseNameAr;
  final String courseNameEn;
  final String sectionNum;
  final int dayOfWeek;
  final String startTime;
  final String scheduleEndTime;
  final String hall;
  final String activity;
  final String? location;
  final bool isDouble;

  LectureItem toLectureItem({required bool isArabic}) {
    final nameAr = courseNameAr.trim();
    final nameEn = courseNameEn.trim();
    final fallback = nameAr.isNotEmpty ? nameAr : nameEn;
    final display = isArabic
        ? (nameAr.isNotEmpty
            ? nameAr
            : (nameEn.isNotEmpty ? nameEn : fallback))
        : (nameEn.isNotEmpty
            ? nameEn
            : (nameAr.isNotEmpty ? nameAr : fallback));
    final code = courseCode.trim();
    final crn = code.isNotEmpty ? code : sectionId;
    final loc = location?.trim();
    return LectureItem(
      courseName: display.isNotEmpty ? display : crn,
      courseNameAr: nameAr.isNotEmpty ? nameAr : null,
      courseNameEn: nameEn.isNotEmpty ? nameEn : null,
      crn: crn,
      hall: hall.trim().isNotEmpty ? hall.trim() : '—',
      section: sectionNum.trim().isNotEmpty ? sectionNum.trim() : '1',
      activity: activity.trim().isNotEmpty
          ? activity.trim()
          : (isArabic ? 'نظري' : 'Theory'),
      startTime: startTime,
      isDouble: isDouble,
      dayOfWeek: dayOfWeek,
      sectionId: sectionId.trim().isNotEmpty ? sectionId : null,
      location: loc != null && loc.isNotEmpty ? loc : null,
      scheduleEndTime:
          scheduleEndTime.trim().isNotEmpty ? scheduleEndTime.trim() : null,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sectionId': sectionId,
        'courseCode': courseCode,
        'courseNameAr': courseNameAr,
        'courseNameEn': courseNameEn,
        'sectionNum': sectionNum,
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'scheduleEndTime': scheduleEndTime,
        'hall': hall,
        'activity': activity,
        'location': location,
        'isDouble': isDouble,
      };

  factory LecturerCatalogRow.fromJson(Map<String, dynamic> m) {
    return LecturerCatalogRow(
      sectionId: (m['sectionId'] ?? '').toString(),
      courseCode: (m['courseCode'] ?? '').toString(),
      courseNameAr: (m['courseNameAr'] ?? '').toString(),
      courseNameEn: (m['courseNameEn'] ?? '').toString(),
      sectionNum: (m['sectionNum'] ?? '').toString(),
      dayOfWeek: _parseInt(m['dayOfWeek'], 1),
      startTime: (m['startTime'] ?? '08:00').toString(),
      scheduleEndTime: (m['scheduleEndTime'] ?? '10:00').toString(),
      hall: (m['hall'] ?? '').toString(),
      activity: (m['activity'] ?? 'نظري').toString(),
      location: m['location']?.toString(),
      isDouble: m['isDouble'] == true,
    );
  }

  static int _parseInt(dynamic v, int fallback) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }
}
