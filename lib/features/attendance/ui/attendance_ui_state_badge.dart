import 'package:flutter/material.dart';

import '../state/attendance_operation_ui_state.dart';

/// Compact state badge for lecturer/student attendance UI.
class AttendanceUiStateBadge extends StatelessWidget {
  const AttendanceUiStateBadge({
    super.key,
    required this.state,
    this.compact = false,
  });

  final AttendanceUIState state;
  final bool compact;

  static Color colorFor(AttendanceUIState state) {
    switch (state) {
      case AttendanceUIState.pending:
        return const Color(0xFFF9A825);
      case AttendanceUIState.syncing:
        return const Color(0xFF1976D2);
      case AttendanceUIState.synced:
        return const Color(0xFF2E7D32);
      case AttendanceUIState.failed:
        return const Color(0xFFC62828);
      case AttendanceUIState.idle:
        return const Color(0xFF9E9E9E);
    }
  }

  static String emojiFor(AttendanceUIState state) {
    switch (state) {
      case AttendanceUIState.pending:
        return '🟡';
      case AttendanceUIState.syncing:
        return '🔵';
      case AttendanceUIState.synced:
        return '🟢';
      case AttendanceUIState.failed:
        return '🔴';
      case AttendanceUIState.idle:
        return '⚪';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(state);
    if (compact) {
      return Text(emojiFor(state), style: const TextStyle(fontSize: 14));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emojiFor(state), style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
