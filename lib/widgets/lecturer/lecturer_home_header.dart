import 'package:flutter/material.dart';
import '../../services/lecturer_auth_service.dart';
import '../../utils/shared/date_utils.dart' as date_utils;
import '../../screens/lecturer/lecturer_language.dart';

/// Header component للشاشة الرئيسية (التحية والتاريخ)
class LecturerHomeHeader extends StatelessWidget {
  final String selectedFilter;
  final String? lecturerName;
  final DateTime referenceDateTime;

  const LecturerHomeHeader({
    super.key,
    required this.selectedFilter,
    required this.referenceDateTime,
    this.lecturerName,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, language, _) {
        final displayName = _resolveLecturerName(language);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(language),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006571),
                      fontFamily: 'Cairo',
                      height: 1.2,
                    ),
                    textAlign: TextAlign.start,
                  ),
                  if (displayName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F7F86),
                        fontFamily: 'Cairo',
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildDateSection(language),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _resolveLecturerName(LecturerLanguage language) {
    final isArabic = language == LecturerLanguage.arabic;
    final fromAuth =
        LecturerAuthService.instance.currentLecturer?.displayNameFor(isArabic);
    if (fromAuth != null && fromAuth.trim().isNotEmpty) {
      return fromAuth.trim();
    }
    final fallback = lecturerName?.trim() ?? '';
    if (fallback.isNotEmpty) return fallback;
    return LecturerLanguageController.tr('محاضر', 'Lecturer', language: language);
  }

  Widget _buildDateSection(LecturerLanguage language) {
    final date = _getSelectedDate();
    final dateInfo = _getDateInfo(date, language);

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              dateInfo['dayName']!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF006571),
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF006571),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dateInfo['dayNumber']!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF006571),
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF006571),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dateInfo['monthName']!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF006571),
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ],
    );
  }

  DateTime _getSelectedDate() {
    final now = referenceDateTime;
    switch (selectedFilter) {
      case 'غدًا':
        return now.add(const Duration(days: 1));
      default:
        return now;
    }
  }

  String _getGreeting(LecturerLanguage language) {
    final hour = referenceDateTime.hour;
    return LecturerLanguageController.tr(
      hour < 12 ? 'صباح الخير' : 'مساء الخير',
      hour < 12 ? 'Good morning' : 'Good evening',
      language: language,
    );
  }

  Map<String, String> _getDateInfo(DateTime date, LecturerLanguage language) {
    if (language == LecturerLanguage.arabic) {
      return date_utils.AppDateUtils.getDateInfo(date);
    }
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return {
      'dayName': days[date.weekday - 1],
      'dayNumber': '${date.day}',
      'monthName': months[date.month - 1],
    };
  }
}
