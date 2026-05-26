import 'package:flutter/material.dart';

import '../state/attendance_operation_ui_state.dart';
import 'attendance_ui_state_badge.dart';

/// Student-facing status line (read-only; no business logic).
class StudentAttendanceStatusBanner extends StatelessWidget {
  const StudentAttendanceStatusBanner({
    super.key,
    required this.state,
    this.message,
    this.translate,
  });

  final AttendanceUIState state;
  final String? message;
  final String Function(String ar, String en)? translate;

  String _tr(String ar, String en) => translate?.call(ar, en) ?? ar;

  @override
  Widget build(BuildContext context) {
    if (state == AttendanceUIState.idle) return const SizedBox.shrink();

    final (Color bg, Color fg, String text) = switch (state) {
      AttendanceUIState.pending => (
          const Color(0xFFFFF8E1),
          const Color(0xFFF57F17),
          _tr(
            'حضورك بانتظار المزامنة…',
            'Your attendance is pending sync…',
          ),
        ),
      AttendanceUIState.syncing => (
          const Color(0xFFE3F2FD),
          const Color(0xFF1565C0),
          _tr(
            'جاري مزامنة حضورك…',
            'Syncing your attendance…',
          ),
        ),
      AttendanceUIState.synced => (
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32),
          _tr(
            'تم تسجيل الحضور بنجاح',
            'Attendance recorded successfully',
          ),
        ),
      AttendanceUIState.failed => (
          const Color(0xFFFFEBEE),
          const Color(0xFFC62828),
          message?.trim().isNotEmpty == true
              ? message!.trim()
              : _tr(
                  'تعذر مزامنة الحضور',
                  'Attendance sync failed',
                ),
        ),
      AttendanceUIState.idle => (
          Colors.transparent,
          Colors.transparent,
          '',
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              AttendanceUiStateBadge(state: state, compact: true),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
