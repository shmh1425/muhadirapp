import 'package:cloud_firestore/cloud_firestore.dart';

/// Semester type for an academic term.
enum SemesterType { first, second, summer }

/// Status of a week within a term.
enum WeekStatus { instructional, break_ }

/// Model for a document in academic_terms collection.
class AcademicTerm {
  const AcademicTerm({
    required this.termId,
    required this.termNameAr,
    required this.termNameEn,
    required this.academicYear,
    required this.semesterType,
    required this.officialWeeksCount,
    required this.effectiveTeachingWeeks,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  final String termId;
  final String termNameAr;
  final String termNameEn;
  final String academicYear;
  final SemesterType semesterType;
  final int officialWeeksCount;
  final int effectiveTeachingWeeks;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Display label for admin (e.g. "2026-1 - الفصل الأول").
  String get displayLabel => '$termNameAr ($academicYear-${semesterType.name})';

  /// Slug for backward compatibility with existing "term" string (e.g. "2026-1").
  String get termSlug => '$academicYear-${_semesterNumber(semesterType)}';

  static int _semesterNumber(SemesterType t) {
    switch (t) {
      case SemesterType.first:
        return 1;
      case SemesterType.second:
        return 2;
      case SemesterType.summer:
        return 3;
    }
  }

  static SemesterType semesterTypeFromString(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'second':
        return SemesterType.second;
      case 'summer':
        return SemesterType.summer;
      case 'first':
      default:
        return SemesterType.first;
    }
  }

  static String semesterTypeToString(SemesterType t) {
    switch (t) {
      case SemesterType.first:
        return 'first';
      case SemesterType.second:
        return 'second';
      case SemesterType.summer:
        return 'summer';
    }
  }

  factory AcademicTerm.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final startRaw = data['startDate'];
    final endRaw = data['endDate'];
    final startDate = startRaw is Timestamp
        ? startRaw.toDate()
        : DateTime.tryParse((startRaw ?? '').toString()) ?? DateTime.now();
    final endDate = endRaw is Timestamp
        ? endRaw.toDate()
        : DateTime.tryParse((endRaw ?? '').toString()) ?? DateTime.now();
    return AcademicTerm(
      termId: (data['termId'] ?? doc.id).toString(),
      termNameAr: (data['termNameAr'] ?? '').toString(),
      termNameEn: (data['termNameEn'] ?? '').toString(),
      academicYear: (data['academicYear'] ?? '').toString(),
      semesterType: semesterTypeFromString((data['semesterType'] ?? '').toString()),
      officialWeeksCount: _safeInt(data['officialWeeksCount']),
      effectiveTeachingWeeks: _safeInt(data['effectiveTeachingWeeks']),
      startDate: startDate,
      endDate: endDate,
      isActive: data['isActive'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'termId': termId,
      'termNameAr': termNameAr,
      'termNameEn': termNameEn,
      'academicYear': academicYear,
      'semesterType': semesterTypeToString(semesterType),
      'officialWeeksCount': officialWeeksCount,
      'effectiveTeachingWeeks': effectiveTeachingWeeks,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
