import 'package:flutter/material.dart';
import '../models/calendar_day.dart';
import '../utils/hijri_converter.dart';

/// تقويم شهري تفاعلي
class MonthlyCalendar extends StatelessWidget {
  final DateTime currentMonth;
  final List<CalendarDay> calendarDays;
  final Function(CalendarDay) onDayTap;
  final Function(DateTime) onMonthChanged;

  const MonthlyCalendar({
    super.key,
    required this.currentMonth,
    required this.calendarDays,
    required this.onDayTap,
    required this.onMonthChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hijriInfo = HijriConverter.gregorianToHijri(currentMonth);
    final monthName = hijriInfo['monthName'] as String;
    final year = hijriInfo['year'] as int;
    final yearArabic = HijriConverter.toArabicNumber(year);

    return Column(
      children: [
        // شريط الشهر مع الأسهم
        _buildMonthHeader(monthName, yearArabic),
        const SizedBox(height: 16),
        // صف أيام الأسبوع
        _buildWeekDaysHeader(),
        const SizedBox(height: 8),
        // شبكة التقويم
        _buildCalendarGrid(),
        const SizedBox(height: 16),
        // دليل الألوان
        _buildColorLegend(),
      ],
    );
  }

  Widget _buildMonthHeader(String monthName, String year) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // سهم الشهر السابق (يمين في RTL = الشهر السابق)
        IconButton(
          onPressed: () {
            final prevMonth = DateTime(
              currentMonth.year,
              currentMonth.month - 1,
              1,
            );
            onMonthChanged(prevMonth);
          },
          icon: const Icon(Icons.chevron_right),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF5F5F5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        // اسم الشهر والسنة
        Column(
          children: [
            Text(
              monthName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
                fontFamily: 'Cairo',
              ),
            ),
            Text(
              year,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF666666),
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
        // سهم الشهر التالي (يسار في RTL = الشهر التالي)
        IconButton(
          onPressed: () {
            final nextMonth = DateTime(
              currentMonth.year,
              currentMonth.month + 1,
              1,
            );
            onMonthChanged(nextMonth);
          },
          icon: const Icon(Icons.chevron_left),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF5F5F5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekDaysHeader() {
    const weekDays = [
      'الاحد',
      'الاثنين',
      'الثلاثاء',
      'الاربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];

    return Row(
      children: weekDays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF999999),
                fontFamily: 'Cairo',
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    // الحصول على أول يوم في الشهر
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    // الحصول على آخر يوم في الشهر
    final lastDayOfMonth = DateTime(
      currentMonth.year,
      currentMonth.month + 1,
      0,
    );

    // حساب عدد الأيام في الشهر
    final daysInMonth = lastDayOfMonth.day;

    // حساب يوم الأسبوع لأول يوم (1 = الاثنين، 7 = الأحد)
    // في التقويم العربي RTL: الأحد = أول يوم (0), الاثنين = 1, ..., السبت = 6
    int firstWeekday = firstDayOfMonth.weekday;
    // تحويل: 7=الأحد -> 0, 1=الاثنين -> 1, 2=الثلاثاء -> 2, ..., 6=السبت -> 6
    int startOffset = firstWeekday == 7 ? 0 : firstWeekday;

    // إنشاء قائمة بجميع الأيام (أيام الشهر السابق + أيام الشهر الحالي)
    final List<Widget> dayWidgets = [];

    // إضافة أيام الشهر السابق (للحشو)
    for (int i = startOffset - 1; i >= 0; i--) {
      dayWidgets.add(_buildEmptyDay());
    }

    // إضافة أيام الشهر الحالي
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(currentMonth.year, currentMonth.month, day);
      final calendarDay = _findCalendarDay(date);
      dayWidgets.add(_buildDayCell(calendarDay ?? _createDefaultDay(date)));
    }

    // حساب عدد الصفوف المطلوبة
    final totalCells = dayWidgets.length;
    final rowsNeeded = (totalCells / 7).ceil();
    final totalNeeded = rowsNeeded * 7;

    // إضافة أيام الشهر التالي (للحشو حتى تكتمل الصفوف)
    final remainingCells = totalNeeded - dayWidgets.length;
    for (int i = 0; i < remainingCells; i++) {
      dayWidgets.add(_buildEmptyDay());
    }

    // تقسيم الأيام إلى صفوف (كل صف 7 أيام)
    return Column(
      children: [
        for (int row = 0; row < rowsNeeded; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (int col = 0; col < 7; col++)
                  Expanded(
                    child: dayWidgets[row * 7 + col],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  CalendarDay? _findCalendarDay(DateTime date) {
    try {
      return calendarDays.firstWhere(
        (day) =>
            day.date.year == date.year &&
            day.date.month == date.month &&
            day.date.day == date.day,
      );
    } catch (e) {
      return null;
    }
  }

  /// إنشاء يوم افتراضي (للأيام غير الموجودة في calendarDays)
  CalendarDay _createDefaultDay(DateTime date) {
    final hijriInfo = HijriConverter.gregorianToHijri(date);
    final now = DateTime.now();
    // §6: مقارنة بالتاريخ فقط بدون الوقت
    final today = DateTime(now.year, now.month, now.day);

    final bool isToday = date.isAtSameMomentAs(today);
    final bool isWeekend = date.weekday == 5 || date.weekday == 6; // الجمعة أو السبت
    final bool isFuture = date.isAfter(today);

    DayStatus status;
    if (isToday) {
      status = DayStatus.today;
    } else if (isWeekend) {
      status = DayStatus.holiday;
    } else if (isFuture) {
      // §3: كل تاريخ مستقبلي = أحمر مقفل
      status = DayStatus.futureLocked;
    } else {
      status = DayStatus.none;
    }

    return CalendarDay(
      date: date,
      hijriDay: hijriInfo['day'] as int,
      hijriMonthName: hijriInfo['monthName'] as String,
      hijriYear: hijriInfo['year'] as int,
      lecturesCount: 0,
      status: status,
    );
  }

  Widget _buildDayCell(CalendarDay day) {
    final isToday = day.isToday;
    final hijriDay = HijriConverter.toArabicNumber(day.hijriDay);
    final status = day.status;
    final backgroundColor = status.color;
    final hasLectures = day.lecturesCount > 0;
    final isHoliday = status == DayStatus.holiday;

    return GestureDetector(
      onTap: () => onDayTap(day),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: isToday
              ? Border.all(
                  color: const Color(0xFF006571),
                  width: 2.5,
                )
              : isHoliday
                  ? Border.all(
                      color: const Color(0xFFB0B0B0),
                      width: 1.5,
                    )
                  : null,
          // إضافة ظل خفيف للأيام التي تحتوي على محاضرات
          boxShadow: hasLectures && !isHoliday
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // رقم اليوم
            Text(
              hijriDay,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                color: isToday ? Colors.white : _getTextColor(status),
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // النقاط الملوّنة (عدد النقاط = عدد المحاضرات)
            if (hasLectures)
              SizedBox(
                height: 8,
                child: _buildDots(day.lecturesCount, status),
              ),
          ],
        ),
      ),
    );
  }

  /// لون النص حسب حالة اليوم
  Color _getTextColor(DayStatus status) {
    switch (status) {
      case DayStatus.today:
        return Colors.white;
      case DayStatus.holiday:
        return const Color(0xFF999999);
      case DayStatus.futureLocked:
        return const Color(0xFFCC4444);
      default:
        return const Color(0xFF222222);
    }
  }

  Widget _buildDots(int count, DayStatus status) {
    // تحديد لون النقاط حسب الحالة
    Color dotColor;
    switch (status) {
      case DayStatus.viewOnly:
        dotColor = const Color(0xFF4A90E2); // أزرق
        break;
      case DayStatus.editable:
        dotColor = const Color(0xFF4CAF50); // أخضر
        break;
      case DayStatus.today:
        dotColor = Colors.white; // أبيض على خلفية خضراء غامقة
        break;
      case DayStatus.futureLocked:
        dotColor = const Color(0xFFCC4444); // أحمر
        break;
      default:
        dotColor = const Color(0xFF999999); // رمادي
    }

    // عرض جميع النقاط (كل نقطة = محاضرة واحدة)
    // إذا كان العدد كبيراً جداً، نعرض حد معقول للعرض (مثلاً 4 نقاط)
    final maxDotsForDisplay = 4;
    final dotCount = count > maxDotsForDisplay ? maxDotsForDisplay : count;

    return LayoutBuilder(
      builder: (context, constraints) {
        // حساب الحجم المناسب للنقاط بناءً على المساحة المتاحة
        final availableWidth = constraints.maxWidth;
        final dotSize = availableWidth > 30 ? 4.0 : 3.5;
        final dotSpacing = availableWidth > 30 ? 1.5 : 1.0;
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(
              dotCount,
              (index) => Container(
                margin: EdgeInsets.symmetric(horizontal: dotSpacing),
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // إذا كان العدد أكبر من الحد الأقصى، نعرض علامة "+"
            if (count > maxDotsForDisplay)
              Padding(
                padding: EdgeInsets.only(right: dotSpacing),
                child: Text(
                  '+',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: dotColor,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyDay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    );
  }

  /// دليل الألوان (Legend) — يوضح معنى كل لون
  Widget _buildColorLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          _legendItem(const Color(0xFF006571), 'اليوم الحالي', true),
          _legendItem(const Color(0xFFE5F5E5), 'قابل للتعديل', false),
          _legendItem(const Color(0xFFE5F0FF), 'عرض فقط', false),
          _legendItem(const Color(0xFFFFE5E5), 'تاريخ مستقبلي', false),
          _legendItem(const Color(0xFFD0D0D0), 'عطلة', false),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, bool isToday) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: const Color(0xFF006571), width: 2)
                : Border.all(color: const Color(0xFFCCCCCC), width: 0.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF666666),
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }
}
