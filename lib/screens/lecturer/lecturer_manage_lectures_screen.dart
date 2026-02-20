import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/lecturer/lecture_item.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../utils/shared/time_utils.dart';
import 'lecturer_language.dart';
import 'widgets/profile_back_button.dart';

/// شاشة إدارة المحاضرات: فلترة، إشعار تأخير، إشعار إلغاء
class LecturerManageLecturesScreen extends StatefulWidget {
  const LecturerManageLecturesScreen({super.key});

  @override
  State<LecturerManageLecturesScreen> createState() =>
      _LecturerManageLecturesScreenState();
}

class _LecturerManageLecturesScreenState
    extends State<LecturerManageLecturesScreen> {
  static const Color _primary = Color(0xFF006571);
  static const Color _delayYellow = Color(0xFFF9A825);
  static const Color _cancelRed = Color(0xFFD32F2F);

  final LectureRepository _repository = LectureRepository();
  late List<LectureItem> _allLectures;

  // فلترة: الأسبوع (تلقائي أو يدوي)، اليوم، الشعبة، المقرر
  bool _weekIsAuto = true;
  int? _selectedWeekNumber; // عند عدم التلقائي: أسبوع 1..53
  late int _selectedDayOfWeek;
  String? _selectedCourse;
  String? _selectedSection;

  /// محاضرات تم إرسال إشعار لها في هذه الجلسة (لتجنب إرسال مرتين)
  final Set<String> _delaySentFor = {};
  final Set<String> _cancelSentFor = {};

  @override
  void initState() {
    super.initState();
    _allLectures = _repository.getAllLectures();
    _selectedDayOfWeek = DateTime.now().weekday;
    _applyFilters();
  }

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  int _getTargetWeekday() => _selectedDayOfWeek;

  /// رقم الأسبوع (ISO) للتاريخ المرجعي لليوم المحدد
  int get _weekNumber {
    final d = _getReferenceDate();
    final startOfYear = DateTime(d.year, 1, 1);
    final dayOfYear = d.difference(startOfYear).inDays + 1;
    final w = ((dayOfYear - d.weekday + 10) / 7).floor();
    return w.clamp(1, 53);
  }

  /// القيمة المعروضة في الشريط: تلقائي = حسب اليوم، وإلا الأسبوع المختار يدوياً
  int get _displayWeekNumber =>
      _weekIsAuto ? _weekNumber : (_selectedWeekNumber ?? _weekNumber);

  static const int _maxWeeks = 53;

  DateTime _getReferenceDate() {
    final now = DateTime.now();
    final target = _getTargetWeekday();
    if (target == now.weekday) return now;
    if (target == now.add(const Duration(days: 1)).weekday) {
      return now.add(const Duration(days: 1));
    }
    // أقرب تاريخ لهذا اليوم من الأسبوع
    int diff = target - now.weekday;
    if (diff <= 0) diff += 7;
    return now.add(Duration(days: diff));
  }

  /// تحقق من انتهاء المحاضرة باستخدام تاريخ فقط ثم وقت النهاية عند الحاجة.
  bool _isLectureEnded(LectureItem lecture) {
    final refDate = _getReferenceDate();
    final now = DateTime.now();
    final refDateOnly = DateTime(refDate.year, refDate.month, refDate.day);
    final todayOnly = DateTime(now.year, now.month, now.day);

    if (refDateOnly.isBefore(todayOnly)) {
      return true;
    }
    if (refDateOnly.isAfter(todayOnly)) {
      return false;
    }
    // نفس اليوم: نقارن وقت النهاية فقط
    final (h, m) = TimeUtils.parseTimeString(lecture.endTime);
    final endDt = DateTime(refDate.year, refDate.month, refDate.day, h, m);
    return now.isAfter(endDt) || now.isAtSameMomentAs(endDt);
  }

  List<LectureItem> _filteredLectures = [];

  List<LectureItem> _computeFilteredLectures() {
    final target = _getTargetWeekday();
    var list = _allLectures.where((l) => l.dayOfWeek == target).toList();
    if (_selectedCourse != null &&
        _selectedCourse!.trim().isNotEmpty &&
        _selectedCourse != _tr('الكل', 'All')) {
      list = list.where((l) => l.courseName == _selectedCourse).toList();
    }
    if (_selectedSection != null &&
        _selectedSection!.trim().isNotEmpty &&
        _selectedSection != _tr('الكل', 'All')) {
      list = list.where((l) => l.section == _selectedSection).toList();
    }
    return TimeUtils.sortLecturesByTime(list, (l) => l.startTime);
  }

  /// محاضرات اليوم المحدد فقط (لخيارات المقرر والشعبة)
  List<LectureItem> get _lecturesForSelectedDay {
    final target = _getTargetWeekday();
    return _allLectures.where((l) => l.dayOfWeek == target).toList();
  }

  List<String> get _uniqueCourseNames {
    final names = _lecturesForSelectedDay
        .map((l) => l.courseName)
        .toSet()
        .toList()
      ..sort();
    return names;
  }

  List<String> get _uniqueSections {
    final sections =
        _lecturesForSelectedDay.map((l) => l.section).toSet().toList()
          ..sort();
    return sections;
  }

  void _applyFilters() {
    _filteredLectures = _computeFilteredLectures();
  }

  void _openDelaySheet(LectureItem lecture) {
    if (_isLectureEnded(lecture)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('لا يمكن تأخير محاضرة منتهية', 'Cannot delay a finished lecture')),
          backgroundColor: _cancelRed,
        ),
      );
      return;
    }
    if (_delaySentFor.contains(lecture.crn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr(
            'تم إرسال إشعار التأخير لهذه المحاضرة مسبقاً',
            'Delay notification was already sent for this lecture',
          )),
          backgroundColor: Colors.grey.shade700,
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DelayDurationSheet(
        lecture: lecture,
        primary: _primary,
        onConfirm: (int minutes) {
          Navigator.pop(ctx);
          _delaySentFor.add(lecture.crn);
          _showDelaySuccessScreen(lecture, minutes);
        },
        tr: _tr,
      ),
    );
  }

  void _openCancelConfirm(LectureItem lecture) {
    if (_isLectureEnded(lecture)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('لا يمكن إلغاء محاضرة ماضية', 'Cannot cancel a past lecture')),
          backgroundColor: _cancelRed,
        ),
      );
      return;
    }
    if (_cancelSentFor.contains(lecture.crn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr(
            'تم إرسال إشعار الإلغاء لهذه المحاضرة مسبقاً',
            'Cancellation notification was already sent for this lecture',
          )),
          backgroundColor: Colors.grey.shade700,
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_tr('تأكيد الإلغاء', 'Confirm Cancellation')),
        content: Text(
          _tr(
            'هل تريد إرسال إشعار إلغاء محاضرة "${lecture.courseName}"؟',
            'Send cancellation notification for "${lecture.courseName}"?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_tr('لا', 'No')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _cancelRed),
            onPressed: () {
              Navigator.pop(ctx);
              _cancelSentFor.add(lecture.crn);
              _showCancelSuccessScreen(lecture);
            },
            child: Text(_tr('نعم، إرسال', 'Yes, Send')),
          ),
        ],
      ),
    );
  }

  void _showDelaySuccessScreen(LectureItem lecture, int delayMinutes) {
    final (sh, sm) = TimeUtils.parseTimeString(lecture.startTime);
    final newStart = (sh * 60 + sm + delayMinutes) % (24 * 60);
    final nh = newStart ~/ 60;
    final nm = newStart % 60;
    final newTimeStr =
        '${nh.toString().padLeft(2, '0')}:${nm.toString().padLeft(2, '0')}';
    final newTimeDisplay =
        TimeUtils.formatTimeRange(newTimeStr, lecture.endTime).split(' - ').first;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _primary.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 56, color: _primary),
              const SizedBox(height: 16),
              Text(
                _tr('تم إرسال إشعار التأخير', 'Delay notification sent'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lecture.courseName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_tr('وقت المحاضرة المحدث', 'Updated time')}: $newTimeDisplay',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_tr('حسناً', 'OK')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelSuccessScreen(LectureItem lecture) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _cancelRed.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 56, color: _cancelRed),
              const SizedBox(height: 16),
              Text(
                _tr('تم إرسال إشعار الإلغاء', 'Cancellation notification sent'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lecture.courseName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: _cancelRed,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_tr('حسناً', 'OK')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCourseDescription(String courseName) {
    final map = <String, String>{
      'هندسة البرمجيات': _tr(
        'مقر تمهيدي يعرف الطلاب على المبادئ الأساسية في هندسة البرمجيات.',
        'Introductory course on core software engineering principles.',
      ),
      'قواعد البيانات': _tr(
        'مقرر يركز على تصميم وإدارة قواعد البيانات وأنظمة المعلومات.',
        'Focuses on database design and information systems management.',
      ),
      'الذكاء الاصطناعي': _tr(
        'مقرر يعرف الطلاب على مفاهيم وتقنيات الذكاء الاصطناعي والتعلم الآلي.',
        'Introduces AI concepts and machine learning techniques.',
      ),
      'أمن المعلومات': _tr(
        'مقرر يغطي أساسيات أمن المعلومات وحماية الأنظمة والشبكات.',
        'Covers information security fundamentals and systems protection.',
      ),
      'الشبكات الحاسوبية': _tr(
        'مقرر يتناول مبادئ الشبكات وبروتوكولات الاتصال.',
        'Covers networking principles and communication protocols.',
      ),
      'تطوير التطبيقات': _tr(
        'مقرر يركز على تطوير التطبيقات الحديثة وتقنيات الويب.',
        'Focuses on modern app development and web technologies.',
      ),
    };
    return map[courseName] ??
        _tr(
          'مقرر أكاديمي في مجال الحاسوب وتقنية المعلومات.',
          'Academic course in computing and information technology.',
        );
  }

  static const List<int> _weekdayOrder = [7, 1, 2, 3, 4];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, _, __) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FBFB),
            appBar: AppBar(
              backgroundColor: const Color(0xFFF8FBFB),
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: ProfileBackButton(
                  onTap: () => Navigator.of(context).pop(),
                  color: const Color(0xFF222222),
                ),
              ),
              title: Text(
                _tr('إدارة المحاضرات', 'Manage Lectures'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                ),
              ),
              centerTitle: true,
            ),
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilterBar(),
                  Expanded(
                    child: _buildContent(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    final now = DateTime.now();
    final todayWeekday = now.weekday;
    final tomorrowWeekday = now.add(const Duration(days: 1)).weekday;
    final dayLabel = _selectedDayOfWeek == todayWeekday
        ? _tr('اليوم', 'Today')
        : _selectedDayOfWeek == tomorrowWeekday
            ? _tr('غداً', 'Tomorrow')
            : LecturerLanguageController.dayNameFromWeekday(_selectedDayOfWeek);
    const double barRadius = 14;
    const double barPaddingH = 12;
    const double barPaddingV = 10;

    // عرض ثابت لكل فلتر (يمين → يسار: اليوم، الأسبوع، المقرر، الشعبة)
    const double widthDay = 92;
    const double widthWeek = 80;
    const double widthCourse = 124;
    const double widthSection = 68;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: barPaddingH,
            vertical: barPaddingV,
          ),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(barRadius),
              border: Border.all(color: const Color(0xFFE8E8E8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: widthDay,
                  child: _FilterSegment(
                    value: dayLabel,
                    segmentWidth: widthDay,
                    primary: _primary,
                    onTap: () => _showDayPickerSheet(
                      todayWeekday: todayWeekday,
                      tomorrowWeekday: tomorrowWeekday,
                    ),
                  ),
                ),
                _FilterBarDivider(),
                SizedBox(
                  width: widthWeek,
                  child: _FilterSegment(
                    value: '$_displayWeekNumber',
                    label: _tr('أسبوع', 'Week'),
                    segmentWidth: widthWeek,
                    primary: _primary,
                    onTap: () => _showWeekPickerSheet(),
                  ),
                ),
                _FilterBarDivider(),
                SizedBox(
                  width: widthCourse,
                  child: _FilterSegment(
                    value: _selectedCourse ?? _tr('الكل', 'All'),
                    segmentWidth: widthCourse,
                    primary: _primary,
                    onTap: () => _showCoursePickerSheet(),
                  ),
                ),
                _FilterBarDivider(),
                SizedBox(
                  width: widthSection,
                  child: _FilterSegment(
                    value: _selectedSection ?? _tr('الكل', 'All'),
                    segmentWidth: widthSection,
                    primary: _primary,
                    onTap: () => _showSectionPickerSheet(),
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }

  void _showWeekPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: 24 + MediaQuery.paddingOf(ctx).bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8D8D8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _tr('رقم الأسبوع', 'Week number'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Cairo',
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 8),
              // تلقائي (Auto)
              ListTile(
                title: Text(
                  _tr('تلقائي (حسب اليوم المحدد)', 'Auto (by selected day)'),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight:
                        _weekIsAuto ? FontWeight.w600 : FontWeight.normal,
                    color: _weekIsAuto ? _primary : const Color(0xFF222222),
                  ),
                ),
                trailing: _weekIsAuto
                    ? Icon(Icons.check_rounded, color: _primary, size: 22)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _weekIsAuto = true;
                    _selectedWeekNumber = null;
                    _applyFilters();
                  });
                },
              ),
              const Divider(height: 1),
              // قائمة الأسابيع 1..53
              Flexible(
                child: ListView.builder(
                  controller: scrollController,
                  shrinkWrap: true,
                  itemCount: _maxWeeks,
                  itemBuilder: (_, index) {
                    final week = index + 1;
                    final selected =
                        !_weekIsAuto && _selectedWeekNumber == week;
                    return ListTile(
                      title: Text(
                        '${_tr('أسبوع', 'Week')} $week',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
                          color:
                              selected ? _primary : const Color(0xFF222222),
                        ),
                      ),
                      trailing: selected
                          ? Icon(Icons.check_rounded,
                              color: _primary, size: 22)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _weekIsAuto = false;
                          _selectedWeekNumber = week;
                          _applyFilters();
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDayPickerSheet({
    required int todayWeekday,
    required int tomorrowWeekday,
  }) {
    final options = <int>[todayWeekday, tomorrowWeekday]
      ..addAll(
        _weekdayOrder.where(
          (w) => w != todayWeekday && w != tomorrowWeekday,
        ),
      );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: 24 + MediaQuery.paddingOf(ctx).bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D8D8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _tr('اليوم', 'Day'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: options.map((w) {
                    final label = w == todayWeekday
                        ? _tr('اليوم', 'Today')
                        : w == tomorrowWeekday
                            ? _tr('غداً', 'Tomorrow')
                            : LecturerLanguageController.dayNameFromWeekday(w);
                    final selected = _selectedDayOfWeek == w;
                    return ListTile(
                      title: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.normal,
                          color: selected ? _primary : const Color(0xFF222222),
                        ),
                      ),
                      trailing: selected
                          ? Icon(Icons.check_rounded, color: _primary, size: 22)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedDayOfWeek = w;
                          _applyFilters();
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSectionPickerSheet() {
    final options = [null, ..._uniqueSections];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: 24 + MediaQuery.paddingOf(ctx).bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D8D8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _tr('الشعبة', 'Section'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 8),
            ...options.map((s) {
              final label = s ?? _tr('الكل', 'All');
              final selected = _selectedSection == s;
              return ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? _primary : const Color(0xFF222222),
                  ),
                ),
                trailing: selected
                    ? Icon(Icons.check_rounded, color: _primary, size: 22)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedSection = s;
                    _applyFilters();
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showCoursePickerSheet() {
    final options = [null, ..._uniqueCourseNames];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: 24 + MediaQuery.paddingOf(ctx).bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D8D8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _tr('المقرر', 'Course'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 8),
            ...options.map((name) {
              final label = name ?? _tr('الكل', 'All');
              final selected = _selectedCourse == name;
              return ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? _primary : const Color(0xFF222222),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: selected
                    ? Icon(Icons.check_rounded, color: _primary, size: 22)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectedCourse = name;
                    _applyFilters();
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final list = _filteredLectures;
    if (list.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _ManageLectureCard(
            lecture: list[index],
            description: _getCourseDescription(list[index].courseName),
            isEnded: _isLectureEnded(list[index]),
            delaySent: _delaySentFor.contains(list[index].crn),
            cancelSent: _cancelSentFor.contains(list[index].crn),
            onDelay: () => _openDelaySheet(list[index]),
            onCancel: () => _openCancelConfirm(list[index]),
            primary: _primary,
            delayYellow: _delayYellow,
            cancelRed: _cancelRed,
            tr: _tr,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                size: 48,
                color: _primary.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _tr(
                _selectedDayOfWeek == DateTime.now().weekday
                    ? 'لا توجد محاضرات لهذا اليوم'
                    : 'لا توجد محاضرات لليوم المحدد',
                'No lectures for the selected day',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF516166),
                fontFamily: 'Cairo',
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _tr(
                'غيّر اليوم أو المقرر أو الشعبة للعثور على محاضرات',
                'Change day, course or section to find lectures',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// خانة فلتر بعرض ثابت: المحتوى يتكيّف (padding ديناميكي)، النص ellipsis، السهم بعرض ثابت.
class _FilterSegment extends StatelessWidget {
  final String value;
  final String? label;
  final double segmentWidth;
  final Color primary;
  final VoidCallback onTap;

  const _FilterSegment({
    required this.value,
    this.label,
    required this.segmentWidth,
    required this.primary,
    required this.onTap,
  });

  static const double _iconWidth = 20;
  static const double _gap = 4;

  /// padding أفقي يتكيّف مع عرض الخانة: واسع → مريح، ضيق → أقل
  static double _paddingHForWidth(double w) {
    if (w >= 100) return 12;
    if (w >= 75) return 8;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final display = label != null ? '$label $value' : value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableW = constraints.maxWidth;
            final dynamicPadding = _paddingHForWidth(availableW);
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: dynamicPadding,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      display,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222222),
                        fontFamily: 'Cairo',
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: _gap),
                  SizedBox(
                    width: _iconWidth,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: primary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// فاصل عمودي خفيف داخل شريط الفلتر
class _FilterBarDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 1,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: const Color(0xFFE8E8E8),
      ),
    );
  }
}

// --- بطاقة محاضرة واحدة مع أزرار التأخير والإلغاء ---
class _ManageLectureCard extends StatelessWidget {
  final LectureItem lecture;
  final String description;
  final bool isEnded;
  final bool delaySent;
  final bool cancelSent;
  final VoidCallback onDelay;
  final VoidCallback onCancel;
  final Color primary;
  final Color delayYellow;
  final Color cancelRed;
  final String Function(String ar, String en) tr;

  const _ManageLectureCard({
    required this.lecture,
    required this.description,
    required this.isEnded,
    required this.delaySent,
    required this.cancelSent,
    required this.onDelay,
    required this.onCancel,
    required this.primary,
    required this.delayYellow,
    required this.cancelRed,
    required this.tr,
  });

  @override
  Widget build(BuildContext context) {
    final timeRange =
        TimeUtils.formatTimeRange(lecture.startTime, lecture.endTime);
    final canAct = !isEnded;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // اسم المقرر — واضح وكبير
          Text(
            lecture.courseName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222222),
              fontFamily: 'Cairo',
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          // الوقت، القاعة، الشعبة
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 18, color: primary),
              const SizedBox(width: 6),
              Text(
                timeRange,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.room_rounded, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                '${tr('القاعة', 'Hall')} ${lecture.hall}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.groups_rounded, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                '${tr('الشعبة', 'Section')} ${lecture.section}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
          if (isEnded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(
                        'المحاضرة منتهية — لا يمكن تنفيذ إجراء',
                        'Lecture ended — no actions available',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.schedule_rounded,
                  label: tr('إشعار تأخير', 'Delay notification'),
                  color: delayYellow,
                  enabled: canAct && !delaySent,
                  onTap: onDelay,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.event_busy_rounded,
                  label: tr('إشعار إلغاء', 'Cancel notification'),
                  color: cancelRed,
                  enabled: canAct && !cancelSent,
                  onTap: onCancel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? color : Colors.grey.shade400,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Cairo',
                  ),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- BottomSheet اختيار مدة التأخير ---
class _DelayDurationSheet extends StatefulWidget {
  final LectureItem lecture;
  final Color primary;
  final void Function(int minutes) onConfirm;
  final String Function(String ar, String en) tr;

  const _DelayDurationSheet({
    required this.lecture,
    required this.primary,
    required this.onConfirm,
    required this.tr,
  });

  @override
  State<_DelayDurationSheet> createState() => _DelayDurationSheetState();
}

class _DelayDurationSheetState extends State<_DelayDurationSheet> {
  int? _selectedMinutes;
  final _otherController = TextEditingController();
  bool _otherSelected = false;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  bool get _canConfirm {
    if (_selectedMinutes != null && !_otherSelected) return true;
    if (_otherSelected) {
      final t = int.tryParse(_otherController.text.trim());
      return t != null && t > 0;
    }
    return false;
  }

  int? get _effectiveMinutes {
    if (_otherSelected) {
      final t = int.tryParse(_otherController.text.trim());
      return (t != null && t > 0) ? t : null;
    }
    return _selectedMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: 24 + padding.bottom + viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D8D8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              widget.tr('مدة التأخير', 'Delay duration'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF222222),
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 20),
            _Option(
              label: widget.tr('10 دقائق', '10 minutes'),
              selected: _selectedMinutes == 10 && !_otherSelected,
              onTap: () => setState(() {
                _selectedMinutes = 10;
                _otherSelected = false;
              }),
            ),
            const SizedBox(height: 10),
            _Option(
              label: widget.tr('30 دقيقة', '30 minutes'),
              selected: _selectedMinutes == 30 && !_otherSelected,
              onTap: () => setState(() {
                _selectedMinutes = 30;
                _otherSelected = false;
              }),
            ),
            const SizedBox(height: 10),
            _Option(
              label: widget.tr('مدة أخرى', 'Other duration'),
              selected: _otherSelected,
              onTap: () => setState(() {
                _otherSelected = true;
                _selectedMinutes = null;
              }),
            ),
            if (_otherSelected) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _otherController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: widget.tr('أدخل عدد الدقائق', 'Enter minutes'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF666666),
                      side: BorderSide(color: Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(widget.tr('رجوع', 'Back')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _canConfirm
                        ? () {
                            final m = _effectiveMinutes;
                            if (m != null) widget.onConfirm(m);
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(widget.tr('تأكيد', 'Confirm')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Option({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? const Color(0xFF006571) : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontFamily: 'Cairo',
                color: Color(0xFF222222),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

