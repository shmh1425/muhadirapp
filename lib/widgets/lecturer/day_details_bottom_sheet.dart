import 'package:flutter/material.dart';
import '../../models/calendar_day.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../screens/lecturer/lecturer_language.dart';
import '../../screens/lecturer/lecturer_navigation.dart';
import '../../utils/hijri_converter.dart';
import 'lecture_detail_card.dart';

/// BottomSheet component لعرض تفاصيل يوم معين (من صفحة الكل — التقويم).
/// يفتح بحجم جزئي (Peek) مع handle وسكرول داخلي؛ التقويم يبقى ظاهراً فوق.
/// عند الضغط على محاضرة: يغلق الـ sheet ويفتح صفحة التحضير (قابلة للتعديل أو عرض فقط حسب اليوم).
class DayDetailsBottomSheet extends StatelessWidget {
  final ScrollController scrollController;
  final CalendarDay day;
  final List<LectureItem> lectures;
  final bool canEdit;

  const DayDetailsBottomSheet({
    super.key,
    required this.scrollController,
    required this.day,
    required this.lectures,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final gregorianDateText = LecturerLanguageController.isArabic
        ? '${HijriConverter.toArabicNumber(day.date.day)}/${HijriConverter.toArabicNumber(day.date.month)}/${HijriConverter.toArabicNumber(day.date.year)}'
        : '${day.date.day}/${day.date.month}/${day.date.year}';
    final hijriYear = LecturerLanguageController.isArabic
        ? HijriConverter.toArabicNumber(day.hijriYear)
        : '${day.hijriYear}';
    final dayName = LecturerLanguageController.dayNameFromWeekday(
      day.date.weekday,
    );
    final monthName = _hijriMonthName(day.hijriMonthName);
    final hijriSuffix = LecturerLanguageController.isArabic ? 'هـ' : ' AH';

    final headerColor = _getHeaderColor(day.status);

    return Directionality(
      textDirection: LecturerLanguageController.direction(),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle صغير للأعلى
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header بلون مطابق لحالة اليوم
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$dayName • $gregorianDateText',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Cairo',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_hijriDayText(day.hijriDay)} $monthName $hijriYear$hijriSuffix',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'Cairo',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
            // قائمة المحاضرات — سكرول داخل الـ Sheet فقط
            Expanded(
              child: lectures.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Center(
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
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: lectures.length,
                      itemBuilder: (context, index) {
                        final lecture = lectures[index];
                        return LectureDetailCard(
                          lecture: lecture,
                          canEdit: canEdit,
                          onTap: () {
                            final nav = Navigator.of(context);
                            nav.pop();
                            final ctx = nav.context;
                            if (canEdit) {
                              LecturerNavigation.goToAttendance(
                                ctx,
                                lecture,
                                selectedDate: day.date,
                              );
                            } else {
                              LecturerNavigation.goToAttendanceViewOnly(
                                ctx,
                                lecture,
                                day.date,
                              );
                            }
                          },
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
