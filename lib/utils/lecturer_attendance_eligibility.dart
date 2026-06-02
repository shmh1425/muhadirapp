enum LecturerAttendanceBlockReason {
  notToday,
  beforeStart,
  afterEnd,
  cancelled,
  invalidTime,
}

class LecturerAttendanceEligibilityResult {
  const LecturerAttendanceEligibilityResult._({
    required this.canTakeAttendance,
    this.reason,
  });

  const LecturerAttendanceEligibilityResult.allowed()
    : this._(canTakeAttendance: true);

  const LecturerAttendanceEligibilityResult.blocked(
    LecturerAttendanceBlockReason reason,
  ) : this._(canTakeAttendance: false, reason: reason);

  final bool canTakeAttendance;
  final LecturerAttendanceBlockReason? reason;

  String get messageAr {
    switch (reason) {
      case LecturerAttendanceBlockReason.notToday:
        return 'لا يمكن بدء التحضير لمحاضرة غير مجدولة اليوم.';
      case LecturerAttendanceBlockReason.beforeStart:
        return 'لا يمكن بدء التحضير قبل وقت المحاضرة.';
      case LecturerAttendanceBlockReason.afterEnd:
        return 'انتهى وقت المحاضرة ولا يمكن بدء التحضير.';
      case LecturerAttendanceBlockReason.cancelled:
        return 'لا يمكن بدء التحضير لمحاضرة ملغاة.';
      case LecturerAttendanceBlockReason.invalidTime:
        return 'وقت المحاضرة غير صالح ولا يمكن بدء التحضير.';
      case null:
        return '';
    }
  }

  String get messageEn {
    switch (reason) {
      case LecturerAttendanceBlockReason.notToday:
        return 'Attendance can only be started for lectures scheduled today.';
      case LecturerAttendanceBlockReason.beforeStart:
        return 'Attendance cannot be started before the lecture time.';
      case LecturerAttendanceBlockReason.afterEnd:
        return 'The lecture time has ended and attendance cannot be started.';
      case LecturerAttendanceBlockReason.cancelled:
        return 'Attendance cannot be started for a cancelled lecture.';
      case LecturerAttendanceBlockReason.invalidTime:
        return 'The lecture time is invalid and attendance cannot be started.';
      case null:
        return '';
    }
  }
}

class LecturerAttendanceBlockedException implements Exception {
  const LecturerAttendanceBlockedException(this.result);

  final LecturerAttendanceEligibilityResult result;

  LecturerAttendanceBlockReason? get reason => result.reason;
  String get messageAr => result.messageAr;
  String get messageEn => result.messageEn;

  @override
  String toString() => messageEn.isNotEmpty ? messageEn : super.toString();
}

class LecturerAttendanceEligibility {
  const LecturerAttendanceEligibility._();

  static bool canTakeAttendanceForLecture({
    required DateTime lectureDate,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required DateTime now,
    required String? lectureStatus,
  }) {
    return evaluate(
      lectureDate: lectureDate,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      now: now,
      lectureStatus: lectureStatus,
    ).canTakeAttendance;
  }

  static LecturerAttendanceEligibilityResult evaluateForTimes({
    required DateTime lectureDate,
    required String lectureStartTime,
    required String lectureEndTime,
    required DateTime now,
    required String? lectureStatus,
  }) {
    final start = combineDateAndTime(lectureDate, lectureStartTime);
    if (start == null) {
      return const LecturerAttendanceEligibilityResult.blocked(
        LecturerAttendanceBlockReason.invalidTime,
      );
    }

    var end = combineDateAndTime(lectureDate, lectureEndTime);
    if (end == null) {
      return const LecturerAttendanceEligibilityResult.blocked(
        LecturerAttendanceBlockReason.invalidTime,
      );
    }
    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }
    if (end.isAtSameMomentAs(start)) {
      return const LecturerAttendanceEligibilityResult.blocked(
        LecturerAttendanceBlockReason.invalidTime,
      );
    }

    return evaluate(
      lectureDate: lectureDate,
      startDateTime: start,
      endDateTime: end,
      now: now,
      lectureStatus: lectureStatus,
    );
  }

  static LecturerAttendanceEligibilityResult evaluate({
    required DateTime lectureDate,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required DateTime now,
    required String? lectureStatus,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final lectureDay = DateTime(
      lectureDate.year,
      lectureDate.month,
      lectureDate.day,
    );

    if (lectureDay != today) {
      return const LecturerAttendanceEligibilityResult.blocked(
        LecturerAttendanceBlockReason.notToday,
      );
    }

    final normalizedStatus = (lectureStatus ?? '').trim().toLowerCase();
    if (normalizedStatus == 'cancelled' ||
        normalizedStatus == 'canceled' ||
        normalizedStatus == 'ملغاة') {
      return const LecturerAttendanceEligibilityResult.blocked(
        LecturerAttendanceBlockReason.cancelled,
      );
    }

    if (now.isBefore(startDateTime)) {
      return const LecturerAttendanceEligibilityResult.blocked(
        LecturerAttendanceBlockReason.beforeStart,
      );
    }

    if (now.isAfter(endDateTime)) {
      return const LecturerAttendanceEligibilityResult.blocked(
        LecturerAttendanceBlockReason.afterEnd,
      );
    }

    return const LecturerAttendanceEligibilityResult.allowed();
  }

  static DateTime? combineDateAndTime(DateTime date, String hhmm) {
    final trimmed = hhmm.trim();
    if (trimmed.isEmpty) return null;

    final parts = trimmed.split(':');
    if (parts.isEmpty) return null;

    final hour = int.tryParse(parts[0].trim());
    if (hour == null || hour < 0 || hour > 23) return null;

    final minute = parts.length > 1 ? int.tryParse(parts[1].trim()) : 0;
    if (minute == null || minute < 0 || minute > 59) return null;

    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}
