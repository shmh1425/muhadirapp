import '../models/lecturer/lecture_item.dart';

/// Determines whether a lecture can still receive delay/cancel actions.
///
/// Rule: actionable when `lectureEndDateTime > now`.
/// If the end time cannot be parsed safely, the lecture is not actionable.
class LectureActionEligibility {
  LectureActionEligibility._();

  static const String messageAr =
      'لا يمكن تعديل محاضرة انتهى وقتها.';
  static const String messageEn =
      'This lecture has already ended and cannot be modified.';

  static const String noUpcomingManageableAr =
      'لا توجد محاضرات قادمة قابلة للإدارة.';
  static const String noUpcomingManageableEn =
      'No upcoming lectures available to manage.';

  /// Parses `HH:mm` (or `H:mm`). Returns null when invalid.
  static (int hour, int minute)? parseHhmm(String hhmm) {
    final trimmed = hhmm.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split(':');
    if (parts.isEmpty) return null;

    final hour = int.tryParse(parts[0].trim());
    if (hour == null || hour < 0 || hour > 23) return null;

    final minute = parts.length > 1 ? int.tryParse(parts[1].trim()) : 0;
    if (minute == null || minute < 0 || minute > 59) return null;

    return (hour, minute);
  }

  /// Builds lecture end datetime on [lectureDate] using [lectureEndTime].
  ///
  /// When [lectureStartTime] is provided and end is before start on the same
  /// calendar day, end is moved to the next day (overnight slot).
  static DateTime? lectureEndDateTime({
    required DateTime lectureDate,
    required String lectureEndTime,
    String? lectureStartTime,
  }) {
    final endParts = parseHhmm(lectureEndTime);
    if (endParts == null) return null;

    final base = DateTime(lectureDate.year, lectureDate.month, lectureDate.day);
    var end = DateTime(base.year, base.month, base.day, endParts.$1, endParts.$2);

    if (lectureStartTime != null && lectureStartTime.trim().isNotEmpty) {
      final startParts = parseHhmm(lectureStartTime);
      if (startParts != null) {
        final start = DateTime(
          base.year,
          base.month,
          base.day,
          startParts.$1,
          startParts.$2,
        );
        if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
          end = end.add(const Duration(days: 1));
        }
      }
    }

    return end;
  }

  /// `true` when the lecture has not ended yet (`lectureEndDateTime > now`).
  static bool isLectureActionable({
    required DateTime lectureDate,
    required String lectureEndTime,
    String? lectureStartTime,
    DateTime? now,
  }) {
    final end = lectureEndDateTime(
      lectureDate: lectureDate,
      lectureEndTime: lectureEndTime,
      lectureStartTime: lectureStartTime,
    );
    if (end == null) return false;

    final current = now ?? DateTime.now();
    return end.isAfter(current);
  }

  static bool isLectureItemActionable({
    required LectureItem lecture,
    required DateTime lectureDate,
    DateTime? now,
  }) {
    return isLectureActionable(
      lectureDate: lectureDate,
      lectureEndTime: lecture.endTime,
      lectureStartTime: lecture.startTime,
      now: now,
    );
  }

}
