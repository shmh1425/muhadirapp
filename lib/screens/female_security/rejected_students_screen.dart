import 'package:flutter/material.dart';

import 'security_records_screen.dart';

class RejectedStudentsScreen extends StatelessWidget {
  const RejectedStudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SecurityRecordsScreen(
      initialStatus: SecurityRecordsStatus.rejected,
    );
  }
}
