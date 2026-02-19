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

  // فلترة: اليوم = يوم الأسبوع الحالي، غداً، أو يوم محدد
  int? _selectedDayOfWeek; // null = اليوم (today)
  String _courseNameFilter = '';
  final String _sectionFilter = '';
  final String _crnFilter = '';

  /// محاضرات تم إرسال إشعار لها في هذه الجلسة (لتجنب إرسال مرتين)
  final Set<String> _delaySentFor = {};
  final Set<String> _cancelSentFor = {};

  @override
  void initState() {
    super.initState();
    _allLectures = _repository.getAllLectures();
    _selectedDayOfWeek = DateTime.now().weekday; // افتراضي: اليوم
    _applyFilters();
  }

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  int _getTargetWeekday() => _selectedDayOfWeek ?? DateTime.now().weekday;

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
    if (_courseNameFilter.trim().isNotEmpty) {
      list = list
          .where((l) =>
              l.courseName.toLowerCase().contains(_courseNameFilter.trim().toLowerCase()))
          .toList();
    }
    if (_sectionFilter.trim().isNotEmpty) {
      list =
          list.where((l) => l.section.contains(_sectionFilter.trim())).toList();
    }
    if (_crnFilter.trim().isNotEmpty) {
      list = list
          .where((l) =>
              l.crn.toLowerCase().contains(_crnFilter.trim().toLowerCase()))
          .toList();
    }
    return TimeUtils.sortLecturesByTime(list, (l) => l.startTime);
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
    final newTimeStr = '${nh.toString().padLeft(2, '0')}:${nm.toString().padLeft(2, '0')}';
    final newTimeDisplay = TimeUtils.formatTimeRange(newTimeStr, lecture.endTime).split(' - ').first;

    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _SuccessScreen(
          title: _tr('تم إرسال إشعار التأخير', 'Delay notification sent'),
          courseName: lecture.courseName,
          description: _getCourseDescription(lecture.courseName),
          extraLines: [
            '${_tr('وقت المحاضرة المحدث', 'Updated lecture time')}: $newTimeDisplay',
            '${_tr('القاعة', 'Hall')}: ${lecture.hall}',
          ],
          backLabel: _tr('رجوع', 'Back'),
          primary: _primary,
        ),
      ),
    );
  }

  void _showCancelSuccessScreen(LectureItem lecture) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _CancelSuccessScreen(
          courseName: lecture.courseName,
          description: _getCourseDescription(lecture.courseName),
          backLabel: _tr('رجوع', 'Back'),
          primary: _primary,
          cancelRed: _cancelRed,
          tr: _tr,
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

  static const List<int> _weekdayOrder = [7, 1, 2, 3, 4, 5, 6];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, _, __) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.only(left: 8),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, size: 20, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _selectedDayOfWeek,
                    isExpanded: true,
                    hint: Text(_tr('اليوم', 'Day')),
                    items: [
                      DropdownMenuItem<int?>(
                        value: DateTime.now().weekday,
                        child: Text(_tr('اليوم', 'Today')),
                      ),
                      ..._weekdayOrder
                          .where((w) => w != DateTime.now().weekday)
                          .map((w) => DropdownMenuItem<int?>(
                                value: w,
                                child: Text(
                                    LecturerLanguageController.dayNameFromWeekday(w)),
                              )),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedDayOfWeek = v;
                        _applyFilters();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) {
              setState(() {
                _courseNameFilter = v;
                _applyFilters();
              });
            },
            decoration: InputDecoration(
              hintText: _tr('اسم المقرر', 'Course name'),
              hintStyle: TextStyle(color: Colors.grey.shade600, fontFamily: 'Cairo'),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final list = _filteredLectures;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _tr(
                  _selectedDayOfWeek == null || _selectedDayOfWeek == DateTime.now().weekday
                      ? 'لا توجد محاضرات لهذا اليوم'
                      : 'لا توجد محاضرات لليوم المحدد',
                  'No lectures for the selected day',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return _ManageLectureCard(
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
        );
      },
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeRange,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                ),
              ),
              Icon(Icons.access_time, size: 18, color: primary),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lecture.courseName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF222222),
              fontFamily: 'Cairo',
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontFamily: 'Cairo',
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            '${tr('القاعة', 'Hall')} ${lecture.hall}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontFamily: 'Cairo',
            ),
          ),
          if (isEnded) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.grey.shade700),
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
                  icon: Icons.notifications_active_outlined,
                  label: tr('إشعار بتأخير المحاضرة', 'Notify lecture delay'),
                  color: delayYellow,
                  enabled: canAct && !delaySent,
                  onTap: onDelay,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  icon: Icons.cancel_outlined,
                  label: tr('إشعار بإلغاء المحاضرة', 'Notify lecture cancellation'),
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
        top: 24,
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

// --- شاشة النجاح للتأخير ---
class _SuccessScreen extends StatelessWidget {
  final String title;
  final String courseName;
  final String description;
  final List<String> extraLines;
  final String backLabel;
  final Color primary;

  const _SuccessScreen({
    required this.title,
    required this.courseName,
    required this.description,
    required this.extraLines,
    required this.backLabel,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          color: const Color(0xFF222222),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                courseName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontFamily: 'Cairo',
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ...extraLines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Cairo',
                      color: Color(0xFF222222),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
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
                  child: Text(backLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- شاشة النجاح للإلغاء ---
class _CancelSuccessScreen extends StatelessWidget {
  final String courseName;
  final String description;
  final String backLabel;
  final Color primary;
  final Color cancelRed;
  final String Function(String ar, String en) tr;

  const _CancelSuccessScreen({
    required this.courseName,
    required this.description,
    required this.backLabel,
    required this.primary,
    required this.cancelRed,
    required this.tr,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          color: const Color(0xFF222222),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('تم إرسال إشعار الإلغاء', 'Cancellation notification sent'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                courseName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  fontFamily: 'Cairo',
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: cancelRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cancelRed.withValues(alpha: 0.3)),
                ),
                child: Text(
                  tr('تم إلغاء المحاضرة', 'The lecture has been cancelled'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cancelRed,
                    fontFamily: 'Cairo',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
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
                  child: Text(backLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
