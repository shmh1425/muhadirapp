import '../../models/attendance/manual_attendance_record.dart';
import '../../models/excuse/excuse_request.dart';

/// Shared merge rules for student attendance rows + excuse requests + pending
/// student-notification markers. Used by [ExcuseScreen] and home "active absences"
/// so both stay in sync.
class ExcuseAttendanceMerge {
  ExcuseAttendanceMerge._();

  /// Same wording as the excuse-management cards (Arabic weekday + day + month).
  static String formatArabicLectureDate(DateTime date) {
    return '${_arabicWeekday(date.weekday)}, ${date.day} ${_arabicMonth(date.month)}';
  }

  static String _arabicWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'الاثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.thursday:
        return 'الخميس';
      case DateTime.friday:
        return 'الجمعة';
      case DateTime.saturday:
        return 'السبت';
      case DateTime.sunday:
      default:
        return 'الأحد';
    }
  }

  static String _arabicMonth(int month) {
    const months = <int, String>{
      1: 'يناير',
      2: 'فبراير',
      3: 'مارس',
      4: 'أبريل',
      5: 'مايو',
      6: 'يونيو',
      7: 'يوليو',
      8: 'أغسطس',
      9: 'سبتمبر',
      10: 'أكتوبر',
      11: 'نوفمبر',
      12: 'ديسمبر',
    };
    return months[month] ?? month.toString();
  }

  static String lectureKey(
    DateTime lectureDate,
    String lectureStartTime,
    String sectionId,
  ) {
    final d = DateTime(lectureDate.year, lectureDate.month, lectureDate.day);
    return '${d.toIso8601String()}|${lectureStartTime.trim()}|${sectionId.trim()}';
  }

  static Map<String, ExcuseRequest> indexRequestsByLectureKey(
    Iterable<ExcuseRequest> requests,
  ) {
    final map = <String, ExcuseRequest>{};
    for (final r in requests) {
      map[lectureKey(r.lectureDate, r.lectureStartTime, r.sectionId)] = r;
    }
    return map;
  }

  static bool isExcuseSubmissionClosedForAbsent(DateTime lectureDate) {
    final d = DateTime(lectureDate.year, lectureDate.month, lectureDate.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(d).inDays >= 3;
  }

  /// After a rejection, the student may resubmit until this deadline; when it passes,
  /// the row is treated like other closed rows (e.g. hidden from home "active").
  static bool rejectedResubmitStillAllowed(ExcuseRequest request) {
    if (request.status != ExcuseRequestStatus.rejected) return false;
    final deadline = request.reviewDeadlineAt;
    if (deadline != null) {
      return !DateTime.now().isAfter(deadline);
    }
    final reviewed = request.reviewedAt ?? request.updatedAt;
    if (reviewed != null) {
      final reviewedDay = DateTime(reviewed.year, reviewed.month, reviewed.day);
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      return today.difference(reviewedDay).inDays < 3;
    }
    return true;
  }

  /// Status strings match the excuse-management list (`_ExcuseItem.status`).
  static String mergedStatus({
    required ManualAttendanceRecord attendance,
    ExcuseRequest? request,
    required Set<String> pendingAttendanceRecordIds,
  }) {
    final closed = attendance.status == ManualAttendanceStatus.absent &&
        isExcuseSubmissionClosedForAbsent(attendance.lectureDate);
    var status = closed
        ? 'مغلق'
        : (attendance.status == ManualAttendanceStatus.excused
            ? 'تم القبول'
            : 'معلقة');

    if (request != null) {
      status = switch (request.status) {
        ExcuseRequestStatus.pending => 'قيد الانتظار',
        ExcuseRequestStatus.accepted => 'تم القبول',
        ExcuseRequestStatus.rejected =>
          rejectedResubmitStillAllowed(request) ? 'تم الرفض' : 'مغلق',
        ExcuseRequestStatus.expired => 'منتهي',
      };
    }

    final rid = attendance.recordId.trim();
    if (rid.isNotEmpty &&
        pendingAttendanceRecordIds.contains(rid) &&
        (status == 'معلقة' || status == 'رفع عذر')) {
      return 'قيد الانتظار';
    }
    return status;
  }

  /// Course label override from the excuse document when present.
  static String? mergedCourseNameArOverride(ExcuseRequest? request) {
    if (request == null) return null;
    final ar = request.courseNameAr.trim();
    return ar.isNotEmpty ? ar : null;
  }
}
