import 'package:flutter/material.dart';

import '../../models/lecturer/lecture_item.dart';
import 'lecturer_attendance_screen.dart';
import 'lecturer_excuse_management_screen.dart';
import 'lecturer_manage_lectures_screen.dart';

/// نقطة تنقل موحدة لشاشات المحاضر — تجنب تكرار منطق Navigator في أكثر من مكان.
class LecturerNavigation {
  LecturerNavigation._();

  /// الانتقال إلى صفحة إدارة المحاضرات (من الهوم، البروفايل، أو أي مكان).
  static void goToManageLectures(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LecturerManageLecturesScreen()),
    );
  }

  /// الانتقال إلى صفحة التحضير لمحاضرة محددة (من صفحة اليوم/غداً أو من التقويم).
  static void goToAttendance(
    BuildContext context,
    LectureItem lecture, {
    DateTime? selectedDate,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LecturerAttendanceScreen(
          lecture: lecture,
          selectedDate: selectedDate,
        ),
      ),
    );
  }

  /// الانتقال إلى صفحة التحضير بوضع عرض فقط (من صفحة الكل — يوم أزرق — عند اختيار محاضرة).
  /// مرتبط بالمقرر، وقت المحاضرة، وتاريخ اليوم المختار.
  static void goToAttendanceViewOnly(
    BuildContext context,
    LectureItem lecture,
    DateTime selectedDate,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LecturerAttendanceScreen(
          lecture: lecture,
          viewOnly: true,
          selectedDate: selectedDate,
        ),
      ),
    );
  }

  /// الانتقال إلى شاشة إدارة الأعذار (Figure 11) من صفحة التحضير — مرتبطة بنفس المحاضرة.
  /// يُرجع [true] عند الحفظ الناجح لتمكين صفحة التحضير من تحديث الحالات (مثلاً غياب بعذر).
  static Future<bool?> goToExcuseManagement(
    BuildContext context,
    LectureItem lecture, {
    required String sessionId,
    required DateTime sessionDate,
  }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LecturerExcuseManagementScreen(
          lecture: lecture,
          sessionId: sessionId,
          sessionDate: sessionDate,
        ),
      ),
    );
  }
}
