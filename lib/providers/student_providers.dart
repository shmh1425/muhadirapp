import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/external_student.dart';
import '../services/student_auth_service.dart';

/// Current logged-in student snapshot (backed by [StudentAuthService]).
///
/// Not auto-invalidated on profile updates; screens that stream Firestore can
/// keep doing so. Extend with [Notifier] later when auth lifecycle is centralized.
final currentStudentProvider = Provider<ExternalStudent?>((ref) {
  return StudentAuthService.instance.currentStudent;
});

/// Numeric id string for API providers, e.g. `"444800009"`.
final currentStudentIdProvider = Provider<String?>((ref) {
  final id = ref.watch(currentStudentProvider)?.studentId ?? 0;
  if (id <= 0) return null;
  return id.toString();
});

// Placeholders for incremental migration:
// final studentAttendanceRecordsProvider = ...
// final studentNotificationsInboxProvider = ...
