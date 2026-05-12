import 'course_weekly_slot.dart';

/// Combined course data for one student enrollment (section + optional course doc).
///
/// UI-agnostic (no [Color], no widgets).
class CourseModel {
  const CourseModel({
    required this.studentId,
    required this.sectionId,
    required this.sectionLabel,
    required this.courseCode,
    required this.courseNameAr,
    required this.courseNameEn,
    required this.lecturerName,
    required this.courseType,
    required this.creditHours,
    this.weeklySlots = const <CourseWeeklySlot>[],
  });

  /// Student id used to fetch enrollments (kept as passed to repository).
  final String studentId;

  /// Firestore document id of `sections/{sectionId}` (as stored in enrollments).
  final String sectionId;

  /// Human label/number for the section (when available).
  final String sectionLabel;

  /// Course code (typically used as `courses/{courseCode}` doc id).
  final String courseCode;

  /// Arabic name (prefers section override, falls back to course doc).
  final String courseNameAr;

  /// English name (prefers section, falls back to course doc).
  final String courseNameEn;

  /// Lecturer display name as stored on the section (best-effort).
  final String lecturerName;

  /// Course type (theoretical/practical/...) best-effort from section/course doc.
  final String courseType;

  /// Credit hours best-effort from course doc, normalized as string.
  final String creditHours;

  /// Weekly section schedule rows from Firestore `sections.schedule`.
  final List<CourseWeeklySlot> weeklySlots;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'studentId': studentId,
        'sectionId': sectionId,
        'sectionLabel': sectionLabel,
        'courseCode': courseCode,
        'courseNameAr': courseNameAr,
        'courseNameEn': courseNameEn,
        'lecturerName': lecturerName,
        'courseType': courseType,
        'creditHours': creditHours,
        'weeklySlots': weeklySlots.map((e) => e.toJson()).toList(),
      };

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    String s(String key) => (json[key] ?? '').toString();
    final rawSlots = json['weeklySlots'];
    final slots = <CourseWeeklySlot>[];
    if (rawSlots is List<dynamic>) {
      for (final item in rawSlots) {
        if (item is Map) {
          slots.add(
            CourseWeeklySlot.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return CourseModel(
      studentId: s('studentId'),
      sectionId: s('sectionId'),
      sectionLabel: s('sectionLabel'),
      courseCode: s('courseCode'),
      courseNameAr: s('courseNameAr'),
      courseNameEn: s('courseNameEn'),
      lecturerName: s('lecturerName'),
      courseType: s('courseType'),
      creditHours: s('creditHours'),
      weeklySlots: slots,
    );
  }
}
