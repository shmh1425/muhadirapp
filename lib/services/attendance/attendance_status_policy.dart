import '../../models/attendance/manual_attendance_record.dart';

class AttendanceStatusPolicy {
  AttendanceStatusPolicy._();

  static const Duration attendanceEarlyWindow = Duration(minutes: 20);
  static const Duration attendanceLateWindow = Duration(minutes: 30);

  static Duration calculateLectureDuration({
    required String lectureStartTime,
    required String lectureEndTime,
    DateTime? lectureDate,
  }) {
    final baseDate = _normalizedDate(lectureDate ?? DateTime.now());
    final start = _combineDateAndTime(baseDate, lectureStartTime);
    var end = _combineDateAndTime(baseDate, lectureEndTime);
    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }
    return end.difference(start);
  }

  static DateTime calculatePresentUntil({
    required DateTime sessionOpenedAt,
    required String lectureStartTime,
    required String lectureEndTime,
    DateTime? lectureDate,
  }) {
    final duration = calculateLectureDuration(
      lectureStartTime: lectureStartTime,
      lectureEndTime: lectureEndTime,
      lectureDate: lectureDate,
    );
    final halfMinutes = duration.inMinutes ~/ 2;
    return sessionOpenedAt.add(Duration(minutes: halfMinutes));
  }

  static ManualAttendanceStatus calculateCheckInStatus({
    required DateTime sessionOpenedAt,
    required String lectureStartTime,
    required String lectureEndTime,
    required DateTime checkInTime,
    DateTime? lectureDate,
  }) {
    final presentUntil = calculatePresentUntil(
      sessionOpenedAt: sessionOpenedAt,
      lectureStartTime: lectureStartTime,
      lectureEndTime: lectureEndTime,
      lectureDate: lectureDate,
    );
    return checkInTime.isAfter(presentUntil)
        ? ManualAttendanceStatus.late
        : ManualAttendanceStatus.present;
  }

  static bool shouldCountLectureWithoutSession() => false;

  static bool shouldFinalizePendingToAbsent({
    required DateTime sessionOpenedAt,
    required String lectureStartTime,
    required String lectureEndTime,
    required DateTime currentTime,
    DateTime? lectureDate,
  }) {
    final baseDate = _normalizedDate(lectureDate ?? sessionOpenedAt);
    var lectureEnd = _combineDateAndTime(baseDate, lectureEndTime);
    final lectureStart = _combineDateAndTime(baseDate, lectureStartTime);
    if (lectureEnd.isBefore(lectureStart)) {
      lectureEnd = lectureEnd.add(const Duration(days: 1));
    }
    final finalizeAt = lectureEnd.add(attendanceLateWindow);
    return currentTime.isAfter(finalizeAt) ||
        currentTime.isAtSameMomentAs(finalizeAt);
  }

  static bool isSessionWithinAttendanceWindow({
    required DateTime lectureDate,
    required String lectureStartTime,
    required String lectureEndTime,
    required DateTime currentTime,
  }) {
    final start = _combineDateAndTime(lectureDate, lectureStartTime);
    final end = _combineDateAndTime(lectureDate, lectureEndTime);
    final adjustedEnd =
        end.isBefore(start) ? end.add(const Duration(days: 1)) : end;
    final openWindowStart = start.subtract(attendanceEarlyWindow);
    final openWindowEnd = adjustedEnd.add(attendanceLateWindow);
    return (currentTime.isAfter(openWindowStart) ||
            currentTime.isAtSameMomentAs(openWindowStart)) &&
        (currentTime.isBefore(openWindowEnd) ||
            currentTime.isAtSameMomentAs(openWindowEnd));
  }

  static DateTime combineDateAndTime(DateTime date, String hhmm) {
    return _combineDateAndTime(date, hhmm);
  }

  static DateTime _combineDateAndTime(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0].trim()) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static DateTime _normalizedDate(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
