import 'package:flutter/material.dart';
import '../../models/calendar_day.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../screens/lecturer/lecturer_language.dart';
import '../../utils/hijri_converter.dart';
import 'lecture_detail_card.dart';

/// BottomSheet component لعرض تفاصيل يوم معين
class DayDetailsBottomSheet extends StatelessWidget {
  final CalendarDay day;
  final List<LectureItem> lectures;
  final bool canEdit;

  const DayDetailsBottomSheet({
    super.key,
    required this.day,
    required this.lectures,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hijriYear = LecturerLanguageController.isArabic
        ? HijriConverter.toArabicNumber(day.hijriYear)
        : '${day.hijriYear}';
    final dayName = LecturerLanguageController.dayNameFromWeekday(
      day.date.weekday,
    );
    final monthName = _hijriMonthName(day.hijriMonthName);
    final hijriSuffix = LecturerLanguageController.isArabic ? 'هـ' : ' AH';

    // تحديد لون Header حسب حالة اليوم
    final headerColor = _getHeaderColor(day.status);

    return Directionality(
      textDirection: LecturerLanguageController.direction(),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header بلون مطابق لحالة اليوم
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$dayName ${_hijriDayText(day.hijriDay)} $monthName $hijriYear$hijriSuffix',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  if (canEdit)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _tr('قابل للتعديل', 'Editable'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _tr('عرض فقط', 'View only'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // قائمة المحاضرات
            Flexible(
              child: lectures.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        _tr(
                          'لا توجد محاضرات في هذا اليوم',
                          'No lectures for this day',
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true,
                      itemCount: lectures.length,
                      itemBuilder: (context, index) {
                        return LectureDetailCard(
                          lecture: lectures[index],
                          canEdit: canEdit,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // الحصول على لون Header حسب حالة اليوم
  Color _getHeaderColor(DayStatus status) {
    switch (status) {
      case DayStatus.today:
        // اليوم الحالي: أخضر غامق
        return const Color(0xFF006571);
      case DayStatus.editable:
        // قابل للتعديل: أخضر (استخدام لون أغمق قليلاً للوضوح)
        return const Color(0xFF4CAF50);
      case DayStatus.viewOnly:
        // عرض فقط: أزرق (استخدام لون أغمق قليلاً للوضوح)
        return const Color(0xFF4A90E2);
      case DayStatus.holiday:
        // عطلة: رمادي
        return const Color(0xFF999999);
      case DayStatus.futureLocked:
        // مستقبلي: أحمر
        return const Color(0xFFE53935);
      default:
        // افتراضي: teal
        return const Color(0xFF27A2A9);
    }
  }

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  String _hijriDayText(int dayValue) {
    if (LecturerLanguageController.isArabic) {
      return HijriConverter.toArabicNumber(dayValue);
    }
    return '$dayValue';
  }

  String _hijriMonthName(String arabicMonth) {
    if (LecturerLanguageController.isArabic) {
      return arabicMonth;
    }
    switch (arabicMonth) {
      case 'محرم':
        return 'Muharram';
      case 'صفر':
        return 'Safar';
      case 'ربيع الأول':
        return 'Rabi I';
      case 'ربيع الثاني':
        return 'Rabi II';
      case 'جمادى الأولى':
        return 'Jumada I';
      case 'جمادى الثانية':
        return 'Jumada II';
      case 'رجب':
        return 'Rajab';
      case 'شعبان':
        return 'Shaaban';
      case 'رمضان':
        return 'Ramadan';
      case 'شوال':
        return 'Shawwal';
      case 'ذو القعدة':
        return 'Dhul Qadah';
      case 'ذو الحجة':
        return 'Dhul Hijjah';
      default:
        return arabicMonth;
    }
  }
}
