import 'package:flutter/material.dart';

import '../models/course_model.dart';
import '../models/course_schedule.dart';

const List<String> _gridDays = <String>[
  'الأحد',
  'الأثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
];

const Map<int, String> _dayOfWeekToName = <int, String>{
  7: 'الأحد',
  1: 'الأثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
};

const List<Color> _courseColors = <Color>[
  Color(0xFF4CAF50),
  Color(0xFF2196F3),
  Color(0xFF03A9F4),
  Color(0xFF673AB7),
  Color(0xFFE91E63),
  Color(0xFFFF9800),
  Color(0xFF009688),
];

String _activityFromCourseType(String? courseType) {
  final t = (courseType ?? '').toString().trim().toLowerCase();
  switch (t) {
    case 'theoretical':
      return 'نظري';
    case 'practical':
      return 'عملي';
    case 'graduation_project':
      return 'مشروع التخرج';
    default:
      return 'نظري';
  }
}

String _dayNameFromDayOfWeek(int dayOfWeek) {
  return _dayOfWeekToName[dayOfWeek] ?? '$dayOfWeek';
}

String _displayName(CourseModel m) {
  final ar = m.courseNameAr.trim();
  final en = m.courseNameEn.trim();
  final code = m.courseCode.trim();
  if (ar.isNotEmpty) return ar;
  if (en.isNotEmpty) return en;
  return code;
}

String _sectionDisplay(CourseModel m) {
  final label = m.sectionLabel.trim();
  if (label.isNotEmpty) return label;
  final sid = m.sectionId.trim();
  if (sid.contains('-')) return sid.split('-').last;
  return '1';
}

/// Builds weekly grid rows from in-memory [CourseModel] rows (no Firestore).
List<CourseSchedule> courseModelsToScheduleGrid(List<CourseModel> models) {
  if (models.isEmpty) return <CourseSchedule>[];
  final courses = <CourseSchedule>[];
  var colorIndex = 0;
  for (final m in models) {
    final displayName = _displayName(m);
    final color = _courseColors[colorIndex % _courseColors.length];
    colorIndex++;
    final sectionNum = _sectionDisplay(m);
    final hours = m.creditHours.trim().isNotEmpty ? m.creditHours : '—';
    final lecturer = m.lecturerName.trim().isNotEmpty ? m.lecturerName : '—';
    for (final slot in m.weeklySlots) {
      final dayName = _dayNameFromDayOfWeek(slot.dayOfWeek);
      if (!_gridDays.contains(dayName)) continue;
      final location =
          slot.location.trim().isNotEmpty ? slot.location : '—';
      final room = slot.hall.trim().isNotEmpty ? slot.hall : '—';
      courses.add(
        CourseSchedule(
          courseName: displayName,
          day: dayName,
          startTime: slot.normalizedStartTime,
          endTime: slot.normalizedEndTime,
          color: color,
          courseCode: m.courseCode,
          activity: _activityFromCourseType(m.courseType),
          section: sectionNum,
          hours: hours,
          lecturer: lecturer,
          location: location,
          room: room,
        ),
      );
    }
  }
  return courses;
}
