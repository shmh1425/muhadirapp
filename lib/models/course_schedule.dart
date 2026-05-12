import 'package:flutter/material.dart';

/// Weekly grid time slot label (schedule UI).
class TimeSlot {
  const TimeSlot({required this.start, required this.end});

  final String start;
  final String end;
}

/// One scheduled occurrence on the student weekly grid.
class CourseSchedule {
  const CourseSchedule({
    required this.courseName,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.courseCode,
    required this.activity,
    required this.section,
    required this.hours,
    required this.lecturer,
    required this.location,
    required this.room,
  });

  final String courseName;
  final String day;
  final String startTime;
  final String endTime;
  final Color color;
  final String courseCode;
  final String activity;
  final String section;
  final String hours;
  final String lecturer;
  final String location;
  final String room;
}
