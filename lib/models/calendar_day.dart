import 'package:flutter/material.dart';

/// موديل بيانات يوم في التقويم
class CalendarDay {
  final DateTime date; // التاريخ الميلادي
  final int hijriDay; // رقم اليوم الهجري
  final String hijriMonthName; // اسم الشهر الهجري
  final int hijriYear; // السنة الهجرية
  final int lecturesCount; // عدد المحاضرات
  final DayStatus status; // حالة اليوم

  CalendarDay({
    required this.date,
    required this.hijriDay,
    required this.hijriMonthName,
    required this.hijriYear,
    this.lecturesCount = 0,
    required this.status,
  });

  /// التحقق إذا كان اليوم هو اليوم الحالي
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
}

/// حالات اليوم في التقويم
enum DayStatus {
  none, // لا توجد محاضرات
  holiday, // عطلة رسمية
  futureLocked, // تاريخ مستقبلي غير متاح
  viewOnly, // عرض فقط
  editable, // قابل للتعديل
  today, // اليوم الحالي
}

/// امتداد للحصول على لون الحالة
extension DayStatusExtension on DayStatus {
  Color get color {
    switch (this) {
      case DayStatus.none:
        return Colors.transparent;
      case DayStatus.holiday:
        return const Color(0xFFD0D0D0); // رمادي مميز للعطلة (أغمق من يوم بدون محاضرات)
      case DayStatus.futureLocked:
        return const Color(0xFFFFE5E5); // أحمر فاتح
      case DayStatus.viewOnly:
        return const Color(0xFFE5F0FF); // أزرق فاتح
      case DayStatus.editable:
        return const Color(0xFFE5F5E5); // أخضر فاتح
      case DayStatus.today:
        return const Color(0xFF006571); // أخضر غامق (اللون الأساسي)
    }
  }

  String get description {
    switch (this) {
      case DayStatus.none:
        return 'لا توجد محاضرات';
      case DayStatus.holiday:
        return 'عطلة رسمية';
      case DayStatus.futureLocked:
        return 'لا يمكن فتح هذا التاريخ الآن';
      case DayStatus.viewOnly:
        return 'عرض فقط';
      case DayStatus.editable:
        return 'قابل للتعديل';
      case DayStatus.today:
        return 'اليوم';
    }
  }
}

