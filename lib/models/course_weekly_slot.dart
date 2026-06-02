/// One row in a section's `schedule` array (weekly recurrence).
class CourseWeeklySlot {
  const CourseWeeklySlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.hall,
    required this.location,
  });

  /// Same convention as stored in Firestore / legacy UI: `DateTime.weekday`
  /// (1 = Monday … 7 = Sunday).
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String hall;
  final String location;

  static const int systemEndOffsetMinutes = 10;

  String get normalizedStartTime {
    return _normalizeHhmm(startTime);
  }

  String get normalizedScheduleEndTime {
    return _normalizeHhmm(endTime);
  }

  String get normalizedEndTime {
    final minutes = _tryMinutesFromHhmm(normalizedScheduleEndTime);
    if (minutes == null) return normalizedScheduleEndTime;
    return _formatMinutes(minutes - systemEndOffsetMinutes);
  }

  static String _normalizeHhmm(String value) {
    var s = value.trim();
    if (s.length == 4 && s.isNotEmpty && s[0] != '0') {
      s = '0$s';
    }
    return s;
  }

  static int? _tryMinutesFromHhmm(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  static String _formatMinutes(int totalMinutes) {
    final normalized = totalMinutes % (24 * 60);
    final positive = normalized < 0 ? normalized + (24 * 60) : normalized;
    final hour = positive ~/ 60;
    final minute = positive % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'hall': hall,
    'location': location,
  };

  factory CourseWeeklySlot.fromJson(Map<String, dynamic> json) {
    final dayRaw = json['dayOfWeek'];
    final day = dayRaw is int
        ? dayRaw
        : int.tryParse((dayRaw ?? '').toString()) ?? 0;
    return CourseWeeklySlot(
      dayOfWeek: day,
      startTime: (json['startTime'] ?? '').toString(),
      endTime: (json['endTime'] ?? '').toString(),
      hall: (json['hall'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
    );
  }
}
