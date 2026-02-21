// ─────────────────────────────────────────────────────────────────────────────
// Example: How to open SecurityVerifyStudentDialog from accepted_screen.dart
// Copy the relevant parts into your screen (e.g. where the eye icon is tapped).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'security_verify_student_dialog.dart';

void openVerifyDialogExample(BuildContext context) {
  final result = StudentGateScanResult(
    fullName: 'خديجة فيصل الهاشمي',
    universityId: '444000018',
    major: 'هندسة برمجيات',
    scanTime: '09:15:39',
    photoUrl: null, // or 'https://example.com/photo.jpg'
  );

  SecurityVerifyStudentDialog.show(
    context,
    result: result,
    onApprove: () {
      // Handle confirm – e.g. mark as verified, refresh list
    },
    onReject: () {
      // Handle reject – e.g. move to rejected list
    },
    onClose: () {
      // Optional: handle dialog closed without action
    },
  );
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
//     onApprove: () => setState(() { /* update UI */ }),
//     onReject: () => setState(() { /* update UI */ }),
//   );
// }
