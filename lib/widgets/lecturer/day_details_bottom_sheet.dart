import 'package:flutter/material.dart';
import '../../models/calendar_day.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../utils/shared/date_utils.dart' as date_utils;
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
    final hijriYear = HijriConverter.toArabicNumber(day.hijriYear);
    final dayName = date_utils.AppDateUtils.getArabicDayName(day.date);
    
    // تحديد لون Header حسب حالة اليوم
    final headerColor = _getHeaderColor(day.status);

    return Directionality(
      textDirection: TextDirection.rtl,
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$dayName ${HijriConverter.toArabicNumber(day.hijriDay)} ${day.hijriMonthName} $hijriYearهـ',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  if (canEdit)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'قابل للتعديل',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'عرض فقط',
                        style: TextStyle(
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
                        'لا توجد محاضرات في هذا اليوم',
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
}

