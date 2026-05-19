import 'package:flutter/material.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../screens/lecturer/lecturer_language.dart';
import '../../utils/lecturer_activity_localization.dart';

/// Card component لعرض معلومات المحاضرة في Timeline
class LectureCard extends StatelessWidget {
  final LectureItem lecture;
  final VoidCallback? onTap;
  final VoidCallback? onDelayTap;
  final VoidCallback? onCancelTap;

  const LectureCard({
    super.key,
    required this.lecture,
    this.onTap,
    this.onDelayTap,
    this.onCancelTap,
  });

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
                  LecturerActivityLocalization.label(lecture.activity),
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
          if (onTap != null || onDelayTap != null || onCancelTap != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onTap != null)
                  _buildActionChip(
                    label: tr('حضر', 'Attend'),
                    icon: Icons.play_arrow_rounded,
                    filled: true,
                    onPressed: onTap!,
                  ),
                if (onDelayTap != null)
                  _buildActionChip(
                    label: tr('تأخير المحاضرة', 'Delay Lecture'),
                    icon: Icons.schedule_rounded,
                    filled: false,
                    onPressed: onDelayTap!,
                  ),
                if (onCancelTap != null)
                  _buildActionChip(
                    label: tr('إلغاء المحاضرة', 'Cancel Lecture'),
                    icon: Icons.cancel_outlined,
                    filled: false,
                    customTextColor: const Color(0xFFD32F2F),
                    customBorderColor: const Color(0xFFF2C8C7),
                    customBackgroundColor: const Color(0xFFFFF4F4),
                    onPressed: onCancelTap!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap != null && onDelayTap == null && onCancelTap == null) {
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

  Widget _buildActionChip({
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onPressed,
    Color? customTextColor,
    Color? customBorderColor,
    Color? customBackgroundColor,
  }) {
    final borderRadius = BorderRadius.circular(10);
    final textColor = customTextColor ?? const Color(0xFF006571);
    final borderColor = customBorderColor ?? const Color(0xFFD8E3E6);
    final backgroundColor = customBackgroundColor ?? const Color(0xFFF5F8F9);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            gradient: filled
                ? const LinearGradient(
                    colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
            color: filled ? null : backgroundColor,
            borderRadius: borderRadius,
            border: filled ? null : Border.all(color: borderColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: filled ? Colors.white : textColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: filled ? Colors.white : textColor,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
