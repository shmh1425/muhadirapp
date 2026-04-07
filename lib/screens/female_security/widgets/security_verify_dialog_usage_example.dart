// ─────────────────────────────────────────────────────────────────────────────
// Example: How to open SecurityVerifyStudentDialog from accepted_screen.dart
// Copy the relevant parts into your screen (e.g. where the eye icon is tapped).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../../../services/female_security/security_gate_scan_service.dart';
import 'security_verify_student_dialog.dart';

Future<void> openVerifyDialogExample(BuildContext context) async {
  final result = StudentGateScanResult(
    fullName: 'خديجة فيصل الهاشمي',
    universityId: '444000018',
    major: 'هندسة برمجيات',
    scanTime: '09:15:39',
    photoUrl: null, // or 'https://example.com/photo.jpg'
  );

  final decision = await SecurityVerifyStudentDialog.show(
    context,
    result: result,
    rejectionReasons: const [
      SecurityRejectionReason(reasonId: 'graduated', titleAr: 'الطالبة متخرجة'),
    ],
  );

  if (decision == null) return;
  if (decision.isApproved) {
    // Handle confirm – e.g. write accepted scan record.
  } else {
    // Handle reject – e.g. write rejected scan record with decision.rejectionReason.
  }
}

// In accepted_screen.dart, call from the eye icon's onTap, e.g.:
//
// onTap: () {
//   SecurityVerifyStudentDialog.show(
//     context,
//     result: StudentGateScanResult(
//       fullName: student.name,
//       universityId: student.universityId,
//       major: 'التخصص', // from your data if available
//       scanTime: student.time,
//       photoUrl: null,
//     ),
//     rejectionReasons: reasonsFromDatabase,
//   );
// }
