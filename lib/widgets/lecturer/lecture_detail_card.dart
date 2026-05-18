import 'package:flutter/material.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../screens/lecturer/lecturer_language.dart';
import '../../utils/shared/time_utils.dart';

/// Card component لعرض تفاصيل المحاضرة في BottomSheet.
/// كل البيانات (الموقع، القاعة، الوقت، اليوم) من الـ section.schedule المرتبط بالمحاضرة.
class LectureDetailCard extends StatelessWidget {
  final LectureItem lecture;
  final bool canEdit;
  final VoidCallback? onTap;

  const LectureDetailCard({
    super.key,
    required this.lecture,
    required this.canEdit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

    final timeRange = TimeUtils.formatTimeRange(
      lecture.startTime,
      lecture.endTime,
    );
    final dayName = LecturerLanguageController.dayNameFromWeekday(
      lecture.dayOfWeek,
    );
    final displayLocation = (lecture.location ?? '').trim().isNotEmpty
        ? lecture.location!.trim()
        : null;
    final displayHall = (lecture.hall.trim().isNotEmpty && lecture.hall != '—')
        ? lecture.hall
        : null;

    final normalizedActivity = lecture.activity.trim().toLowerCase();
    final isPractical =
        normalizedActivity == 'عملي' || normalizedActivity == 'lab';
    final iconData = isPractical ? Icons.science : Icons.menu_book;
    final iconColor = isPractical
        ? const Color(0xFF4A90E2)
        : const Color(0xFF8B6F47);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeRange,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222222),
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(iconData, size: 20, color: iconColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                lecture.courseName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.tag,
                label: tr('رمز المقرر', 'Course code'),
                value: lecture.crn,
              ),
              _DetailRow(
                icon: Icons.groups_outlined,
                label: tr('الشعبة', 'Section'),
                value: lecture.section,
              ),
              _DetailRow(
                icon: Icons.calendar_today,
                label: tr('اليوم', 'Day'),
                value: dayName,
              ),
              if (displayHall != null)
                _DetailRow(
                  icon: Icons.door_front_door_outlined,
                  label: tr('القاعة', 'Hall'),
                  value: displayHall,
                ),
              if (displayLocation != null)
                _DetailRow(
                  icon: Icons.location_on,
                  label: tr('الموقع', 'Location'),
                  value: displayLocation,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontFamily: 'Cairo',
                ),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
