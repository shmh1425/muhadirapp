import 'package:flutter/material.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../screens/lecturer/lecturer_language.dart';

/// Card component لعرض معلومات المحاضرة في Timeline
class LectureCard extends StatelessWidget {
  final LectureItem lecture;
  final VoidCallback? onTap;

  const LectureCard({super.key, required this.lecture, this.onTap});

  @override
  Widget build(BuildContext context) {
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

    final content = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E8E8), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course name
          Text(
            lecture.courseName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222222),
              fontFamily: 'Cairo',
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          // Details row
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  Icons.location_on_outlined,
                  '${tr('القاعة', 'Hall')} ${lecture.hall}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailItem(
                  Icons.group_outlined,
                  '${tr('الشعبة', 'Section')} ${lecture.section}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // CRN and activity
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  lecture.crn,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF006571),
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _activityLabel(lecture.activity),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF666666),
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: content,
        ),
      );
    }
    return content;
  }

  String _activityLabel(String activity) {
    switch (activity) {
      case 'عملي':
        return LecturerLanguageController.tr('عملي', 'Lab');
      case 'نظري':
        return LecturerLanguageController.tr('نظري', 'Theory');
      default:
        return activity;
    }
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF006571)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
              fontFamily: 'Cairo',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
