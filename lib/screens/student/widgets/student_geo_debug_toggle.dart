import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../features/translation/translation_controller.dart';
import '../../../services/geo/student_campus_geo_guard.dart';

/// Debug-only switch to bypass student geo-fence (gate QR + attendance QR).
class StudentGeoDebugToggle extends StatelessWidget {
  const StudentGeoDebugToggle({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();

    final en = TranslationController.instance.translateToEnglish;

    return ValueListenableBuilder<bool>(
      valueListenable: StudentCampusGeoGuard.debugSkipGeoFenceForTesting,
      builder: (context, skipped, _) {
        return Material(
          color: skipped ? const Color(0xFFFFF8E1) : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          child: SwitchListTile(
            value: skipped,
            activeThumbColor: const Color(0xFF006571),
            onChanged: (value) {
              StudentCampusGeoGuard.debugSkipGeoFenceForTesting.value = value;
              if (value) {
                StudentCampusGeoGuard.invalidateGateCache();
              }
            },
            title: Text(
              en
                  ? 'Disable geo-fence (testing)'
                  : 'تعطيل القيود الجغرافية (اختبار)',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            subtitle: Text(
              en
                  ? 'Gate QR and attendance QR only — for QA builds'
                  : 'بوابة QR وتحضير QR فقط — للتجربة في وضع التطوير',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        );
      },
    );
  }
}
