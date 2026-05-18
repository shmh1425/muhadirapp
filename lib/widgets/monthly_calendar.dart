import 'package:flutter/material.dart';
import '../models/calendar_day.dart';
import '../screens/lecturer/lecturer_language.dart';
import '../shared/widgets/directional_navigation_icon.dart';
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
    final monthName = LecturerLanguageController.isArabic
        ? _gregorianMonthNameAr(currentMonth.month)
        : _gregorianMonthNameEn(currentMonth.month);
    final yearText = LecturerLanguageController.isArabic
        ? HijriConverter.toArabicNumber(currentMonth.year)
        : '${currentMonth.year}';

    return Column(
      children: [
        // شريط الشهر مع الأسهم
        _buildMonthHeader(monthName, yearText),
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
        _MonthNavButton(
          tooltip: _tr('الشهر السابق', 'Previous month'),
          label: _tr('السابق', 'Previous'),
          icon: const DirectionalPreviousIcon(),
          onPressed: () {
            onMonthChanged(
              DateTime(currentMonth.year, currentMonth.month - 1, 1),
            );
          },
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
        _MonthNavButton(
          tooltip: _tr('الشهر التالي', 'Next month'),
          label: _tr('التالي', 'Next'),
          icon: const DirectionalNextIcon(),
          onPressed: () {
            onMonthChanged(
              DateTime(currentMonth.year, currentMonth.month + 1, 1),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWeekDaysHeader() {
    final weekDays = LecturerLanguageController.isArabic
        ? const [
            'الاحد',
            'الاثنين',
            'الثلاثاء',
            'الاربعاء',
            'الخميس',
            'الجمعة',
            'السبت',
          ]
        : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

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
                  Expanded(child: dayWidgets[row * 7 + col]),
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

    DayStatus status;
    if (isToday) {
      status = DayStatus.today;
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
    final dayNumber = LecturerLanguageController.isArabic
        ? HijriConverter.toArabicNumber(day.date.day)
        : '${day.date.day}';
    final status = day.status;
    final visualHolidayType = day.holidayType;
    final hasLectures = day.lecturesCount > 0;
    final isHoliday = status == DayStatus.holiday;
    final isFutureLocked = status == DayStatus.futureLocked;
    final isViewOnly = status == DayStatus.viewOnly;
    final isEditable =
        status == DayStatus.editable || status == DayStatus.today;
    final isLectureDay =
        hasLectures && (isEditable || isViewOnly || isFutureLocked);
    final backgroundColor = isToday
        ? DayStatus.today.color
        : isHoliday
        ? _holidayFillColor(visualHolidayType)
        : isFutureLocked
        ? DayStatus.futureLocked.color
        : isViewOnly
        ? DayStatus.viewOnly.color
        : status == DayStatus.editable
        ? DayStatus.editable.color
        : Colors.transparent;

    return GestureDetector(
      onTap: () => onDayTap(day),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: isToday
              ? Border.all(color: const Color(0xFF006571), width: 2.5)
              : isHoliday
              ? Border.all(
                  color: _holidayBorderColor(visualHolidayType),
                  width: 1.5,
                )
              : isFutureLocked
              ? Border.all(color: const Color(0xFFD14A4A), width: 1.2)
              : isViewOnly
              ? Border.all(color: const Color(0xFF4A90E2), width: 1.2)
              : status == DayStatus.editable
              ? Border.all(color: _lectureDayBorderColor(), width: 1.2)
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
              dayNumber,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                color: isToday
                    ? Colors.white
                    : _getTextColor(
                        status,
                        holidayType: visualHolidayType,
                        isLectureDay: isLectureDay,
                      ),
                fontFamily: 'Cairo',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // النقاط الملوّنة (عدد النقاط = عدد المحاضرات)
            if (hasLectures)
              SizedBox(height: 8, child: _buildDots(day.lecturesCount, status)),
          ],
        ),
      ),
    );
  }

  /// لون النص حسب حالة اليوم
  Color _getTextColor(
    DayStatus status, {
    String? holidayType,
    bool isLectureDay = false,
  }) {
    switch (status) {
      case DayStatus.today:
        return Colors.white;
      case DayStatus.holiday:
        return _holidayTextColor(holidayType);
      case DayStatus.futureLocked:
        return const Color(0xFFB3261E);
      case DayStatus.viewOnly:
        return const Color(0xFF1E5AA8);
      case DayStatus.editable:
        return const Color(0xFF1B5E20);
      default:
        if (isLectureDay) return const Color(0xFF1B5E20);
        return const Color(0xFF222222);
    }
  }

  Widget _buildDots(int count, DayStatus status) {
    // تحديد لون النقاط حسب الحالة
    Color dotColor;
    switch (status) {
      case DayStatus.today:
        dotColor = Colors.white; // أبيض على خلفية خضراء غامقة
        break;
      case DayStatus.futureLocked:
        dotColor = const Color(0xFFB3261E);
        break;
      case DayStatus.viewOnly:
        dotColor = const Color(0xFF1E5AA8);
        break;
      case DayStatus.editable:
        dotColor = const Color(0xFF1B5E20);
        break;
      default:
        dotColor = const Color(0xFF1B5E20);
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
    final monthHolidayTypes = _collectHolidayTypes();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          _legendItem(
            const Color(0xFF006571),
            _tr('اليوم الحالي', 'Today'),
            true,
          ),
          _legendItem(
            _lectureDayFillColor(),
            _tr(
              'داخل آخر أسبوعين (قابل للتعديل)',
              'Within last 2 weeks (editable)',
            ),
            false,
          ),
          _legendItem(
            DayStatus.viewOnly.color,
            _tr('أقدم من أسبوعين (عرض فقط)', 'Older than 2 weeks (view only)'),
            false,
          ),
          _legendItem(
            DayStatus.futureLocked.color,
            _tr('تاريخ مستقبلي (مغلق)', 'Future date (locked)'),
            false,
          ),
          _legendItem(
            _holidayFillColor('weekend'),
            _tr('عطلة', 'Holiday'),
            false,
          ),
          ...monthHolidayTypes.map(
            (type) => _legendItem(
              _holidayFillColor(type),
              _holidayLabel(type),
              false,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _collectHolidayTypes() {
    final types = calendarDays
        .where((d) => d.status == DayStatus.holiday)
        .map((d) => (d.holidayType ?? '').trim().toLowerCase())
        .where((t) => t.isNotEmpty && t != 'weekend')
        .toSet()
        .toList();
    types.sort((a, b) => _holidayTypeOrder(a).compareTo(_holidayTypeOrder(b)));
    return types;
  }

  int _holidayTypeOrder(String type) {
    switch (type) {
      case 'holiday':
        return 1;
      case 'break':
        return 2;
      case 'suspension':
        return 3;
      case 'other':
        return 4;
      case 'weekend':
        return 5;
      default:
        return 6;
    }
  }

  String _holidayLabel(String? type) {
    switch ((type ?? '').trim().toLowerCase()) {
      case 'holiday':
        return _tr('عطلة رسمية', 'Official holiday');
      case 'break':
        return _tr('إجازة أكاديمية', 'Academic break');
      case 'suspension':
        return _tr('تعليق دراسة', 'Suspension');
      case 'other':
        return _tr('عطلة أخرى', 'Other holiday');
      case 'weekend':
        return _tr('عطلة أسبوعية', 'Weekend');
      default:
        return _tr('عطلة مسجلة', 'Registered holiday');
    }
  }

  Color _holidayFillColor(String? type) {
    switch ((type ?? '').trim().toLowerCase()) {
      case 'break':
        // Academic break: keep it clearly yellow.
        return const Color(0xFFFFF5CC);
      default:
        return const Color(0xFFE0E0E0);
    }
  }

  Color _holidayBorderColor(String? type) {
    switch ((type ?? '').trim().toLowerCase()) {
      case 'break':
        return const Color(0xFFE0B422);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  Color _holidayTextColor(String? type) {
    switch ((type ?? '').trim().toLowerCase()) {
      case 'break':
        return const Color(0xFF8A6A00);
      default:
        return const Color(0xFF616161);
    }
  }

  Color _lectureDayFillColor() => const Color(0xFFE7F6E9);
  Color _lectureDayBorderColor() => const Color(0xFF81C784);

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  String _gregorianMonthNameAr(int month) {
    switch (month) {
      case 1:
        return 'يناير';
      case 2:
        return 'فبراير';
      case 3:
        return 'مارس';
      case 4:
        return 'أبريل';
      case 5:
        return 'مايو';
      case 6:
        return 'يونيو';
      case 7:
        return 'يوليو';
      case 8:
        return 'أغسطس';
      case 9:
        return 'سبتمبر';
      case 10:
        return 'أكتوبر';
      case 11:
        return 'نوفمبر';
      case 12:
        return 'ديسمبر';
      default:
        return 'شهر';
    }
  }

  String _gregorianMonthNameEn(int month) {
    switch (month) {
      case 1:
        return 'January';
      case 2:
        return 'February';
      case 3:
        return 'March';
      case 4:
        return 'April';
      case 5:
        return 'May';
      case 6:
        return 'June';
      case 7:
        return 'July';
      case 8:
        return 'August';
      case 9:
        return 'September';
      case 10:
        return 'October';
      case 11:
        return 'November';
      case 12:
        return 'December';
      default:
        return 'Month';
    }
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

class _MonthNavButton extends StatelessWidget {
  const _MonthNavButton({
    required this.tooltip,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final String label;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFE6F3F5),
          foregroundColor: const Color(0xFF006571),
          elevation: 0,
          minimumSize: const Size(96, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFB8DDE2)),
          ),
        ),
        icon: IconTheme(data: const IconThemeData(size: 22), child: icon),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
