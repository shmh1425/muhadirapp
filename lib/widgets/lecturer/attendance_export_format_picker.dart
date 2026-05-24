import 'package:flutter/material.dart';

import '../../screens/lecturer/lecturer_language.dart';
import '../../services/attendance/export/attendance_session_export_format.dart';

/// Centered dialog to choose PDF or CSV before export.
Future<AttendanceSessionExportFormat?> showAttendanceExportFormatPicker(
  BuildContext context,
) {
  final tr = LecturerLanguageController.tr;
  const accentColor = Color(0xFF006571);

  return showDialog<AttendanceSessionExportFormat>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final scheme = theme.colorScheme;
      return Directionality(
        textDirection: LecturerLanguageController.direction(),
        child: Dialog(
          backgroundColor: scheme.surface,
          elevation: 8,
          insetPadding: const EdgeInsets.symmetric(horizontal: 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tr('اختيار صيغة التصدير', 'Choose export format'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ExportFormatOption(
                    icon: Icons.picture_as_pdf_rounded,
                    label: tr('تصدير كملف PDF', 'Export as PDF'),
                    onTap: () => Navigator.of(
                      dialogContext,
                    ).pop(AttendanceSessionExportFormat.pdf),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Divider(height: 1, color: theme.dividerColor),
                  ),
                  _ExportFormatOption(
                    icon: Icons.table_chart_rounded,
                    label: tr('تصدير كملف CSV', 'Export as CSV'),
                    onTap: () => Navigator.of(
                      dialogContext,
                    ).pop(AttendanceSessionExportFormat.csv),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: accentColor,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      tr('إلغاء', 'Cancel'),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ExportFormatOption extends StatelessWidget {
  const _ExportFormatOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  static const Color _iconColor = Color(0xFF006571);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: _iconColor, size: 22),
                const SizedBox(width: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: scheme.onSurface,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
