import 'package:flutter/material.dart';
import '../../screens/lecturer/lecturer_language.dart';

/// Button لإدارة المحاضرات
class ManageLecturesButton extends StatelessWidget {
  final VoidCallback? onTap;

  const ManageLecturesButton({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ??
          () {
            // Placeholder - يمكن ربطه بشاشة إدارة المحاضرات لاحقاً
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  LecturerLanguageController.tr(
                    'شاشة إدارة المحاضرات - قيد التطوير',
                    'Manage lectures screen is under development',
                  ),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
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
