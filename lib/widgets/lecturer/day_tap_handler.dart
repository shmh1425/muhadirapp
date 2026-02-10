import 'package:flutter/material.dart';
import '../../models/calendar_day.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../services/lecturer/lecture_repository.dart';
import 'day_details_bottom_sheet.dart';

/// Handler للتعامل مع الضغط على يوم في التقويم
class DayTapHandler {
  final LectureRepository repository;

  DayTapHandler({
    required this.repository,
  });

  /// معالجة الضغط على يوم في التقويم
  void handleDayTap(BuildContext context, CalendarDay day, List<LectureItem> allLectures) {
    switch (day.status) {
      case DayStatus.futureLocked:
        // 🔴 يوم مستقبلي: لا يفتح → تظهر رسالة "لا يمكن فتح هذا التاريخ الآن"
        _showSnackBar(
          context: context,
          message: 'لا يمكن فتح هذا التاريخ الآن',
          icon: Icons.lock,
          backgroundColor: Colors.red.shade500,
        );
        break;

      case DayStatus.holiday:
        // ⚪ عطلة: تظهر رسالة "عطلة رسمية"
        _showSnackBar(
          context: context,
          message: 'عطلة رسمية',
          icon: Icons.event_busy,
          backgroundColor: Colors.grey.shade600,
        );
        break;

      case DayStatus.viewOnly:
        // 🔵 عرض فقط: تفتح التفاصيل بدون إمكانية تعديل
        _showDayDetails(context, day, allLectures, canEdit: false);
        break;

      case DayStatus.editable:
        // 🟢 قابل للتعديل: تفتح التفاصيل مع إمكانية تعديل الحضور
        _showDayDetails(context, day, allLectures, canEdit: true);
        break;

      case DayStatus.none:
        // ⚪ بدون محاضرات: تظهر رسالة "لا توجد محاضرات في هذا اليوم"
        _showSnackBar(
          context: context,
          message: 'لا توجد محاضرات في هذا اليوم',
          icon: Icons.info_outline,
          backgroundColor: Colors.grey.shade700,
        );
        break;

      case DayStatus.today:
        // 🟩 اليوم الحالي: إذا فيه محاضرات يفتح BottomSheet، وإلا يطلع "لا توجد محاضرات في هذا اليوم"
        if (day.lecturesCount > 0) {
          _showDayDetails(context, day, allLectures, canEdit: true);
        } else {
          _showSnackBar(
            context: context,
            message: 'لا توجد محاضرات في هذا اليوم',
            icon: Icons.calendar_today,
            backgroundColor: const Color(0xFF006571),
          );
        }
        break;
    }
  }

  void _showDayDetails(BuildContext context, CalendarDay day, List<LectureItem> allLectures, {required bool canEdit}) {
    final dayOfWeek = day.date.weekday;
    final lecturesForDay = repository.getLecturesForDay(dayOfWeek, allLectures: allLectures);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DayDetailsBottomSheet(
        day: day,
        lectures: lecturesForDay,
        canEdit: canEdit,
      ),
    );
  }

  void _showSnackBar({
    required BuildContext context,
    required String message,
    required IconData icon,
    required Color backgroundColor,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

