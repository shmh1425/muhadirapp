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
  final bool showAttendanceAction;

  const LectureCard({
    super.key,
    required this.lecture,
    this.onTap,
    this.onDelayTap,
    this.onCancelTap,
    this.showAttendanceAction = true,
  });

  @override
  Widget build(BuildContext context) {
    String tr(String ar, String en) => LecturerLanguageController.tr(ar, en);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = colorScheme.surface;
    final borderColor = colorScheme.outlineVariant.withValues(
      alpha: isDark ? 0.34 : 1,
    );
    final titleColor = colorScheme.onSurface;
    final secondaryTextColor = colorScheme.onSurfaceVariant;

    final content = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.04),
            blurRadius: isDark ? 14 : 10,
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
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: titleColor,
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
                  context,
                  Icons.location_on_outlined,
                  '${tr('القاعة', 'Hall')} ${lecture.hall}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailItem(
                  context,
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
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  lecture.crn,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  LecturerActivityLocalization.label(lecture.activity),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: secondaryTextColor,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          if ((showAttendanceAction && onTap != null) ||
              onDelayTap != null ||
              onCancelTap != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (showAttendanceAction && onTap != null)
                  _buildActionChip(
                    context: context,
                    label: tr('حضر', 'Attend'),
                    icon: Icons.play_arrow_rounded,
                    filled: true,
                    onPressed: onTap!,
                  ),
                if (onDelayTap != null)
                  _buildActionChip(
                    context: context,
                    label: tr('تأخير المحاضرة', 'Delay Lecture'),
                    icon: Icons.schedule_rounded,
                    filled: false,
                    onPressed: onDelayTap!,
                  ),
                if (onCancelTap != null)
                  _buildActionChip(
                    context: context,
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
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onPressed,
    Color? customTextColor,
    Color? customBorderColor,
    Color? customBackgroundColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(10);
    final textColor = customTextColor ?? colorScheme.primary;
    final borderColor =
        customBorderColor ??
        colorScheme.outlineVariant.withValues(alpha: isDark ? 0.42 : 1);
    final backgroundColor =
        customBackgroundColor ?? colorScheme.primary.withValues(alpha: 0.08);
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

  Widget _buildDetailItem(BuildContext context, IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
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
