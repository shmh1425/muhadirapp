import 'package:flutter/material.dart';
import '../../utils/shared/date_utils.dart' as date_utils;
import '../../screens/lecturer/lecturer_language.dart';

/// Header component للشاشة الرئيسية (التحية والتاريخ)
class LecturerHomeHeader extends StatelessWidget {
  final String selectedFilter;

  const LecturerHomeHeader({
    super.key,
    required this.selectedFilter,
  });

  @override
  Widget build(BuildContext context) {
    final language = LecturerLanguageController.current;
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
              ),
              const SizedBox(height: 12),
              _buildDateSection(language),
            ],
          ),
        ),
      ],
    );
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
    final now = DateTime.now();
    switch (selectedFilter) {
      case 'غدًا':
        return now.add(const Duration(days: 1));
      default:
        return now;
    }
  }

  String _getGreeting(LecturerLanguage language) {
    if (language == LecturerLanguage.arabic) {
      return date_utils.AppDateUtils.getGreeting();
    }
    final hour = DateTime.now().hour;
    return hour < 12 ? 'Good Morning' : 'Good Evening';
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
