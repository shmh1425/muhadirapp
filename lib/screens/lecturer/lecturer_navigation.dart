import 'package:flutter/material.dart';

import 'lecturer_manage_lectures_screen.dart';

/// نقطة تنقل موحدة لشاشات المحاضر — تجنب تكرار منطق Navigator في أكثر من مكان.
class LecturerNavigation {
  LecturerNavigation._();

  /// الانتقال إلى صفحة إدارة المحاضرات (من الهوم، البروفايل، أو أي مكان).
  static void goToManageLectures(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LecturerManageLecturesScreen(),
      ),
    );
  }
}
