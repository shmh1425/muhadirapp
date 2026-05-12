/// One weekly time row for attendance time-matching (mirrors section schedule slots).
class AttendanceScheduleSlot {
  const AttendanceScheduleSlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  final int dayOfWeek;
  final String startTime;
  final String endTime;
}
