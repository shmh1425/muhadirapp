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

  String get normalizedStartTime {
    var s = startTime.trim();
    if (s.length == 4 && s.isNotEmpty && s[0] != '0') {
      s = '0$s';
    }
    return s;
  }

  String get normalizedEndTime {
    var s = endTime.trim();
    if (s.length == 4 && s.isNotEmpty && s[0] != '0') {
      s = '0$s';
    }
    return s;
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
