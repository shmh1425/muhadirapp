import 'package:flutter/material.dart';
import '../../screens/lecturer/lecturer_language.dart';
import '../../screens/lecturer/lecturer_navigation.dart';

/// زر إدارة المحاضرات — يستدعي التنقل الموحد لصفحة إدارة المحاضرات.
class ManageLecturesButton extends StatelessWidget {
  const ManageLecturesButton({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => LecturerNavigation.goToManageLectures(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF27A2A9), Color(0xFF006571)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF006571).withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.settings,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              LecturerLanguageController.tr('ادارة المحاضرات', 'Manage Lectures'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
