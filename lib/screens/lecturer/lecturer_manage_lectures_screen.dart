import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/calendar_day.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../services/lecturer/calendar_service.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../services/lecturer/calendar_sync_service.dart';
import '../../services/lecturer/lecturer_sections_service.dart';
import '../../services/notifications/lecture_action_notification_service.dart';
import '../../utils/shared/time_utils.dart';
import '../../widgets/monthly_calendar.dart';
import 'lecturer_language.dart';
import 'lecturer_navigation.dart';
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

  List<LectureItem> _allLectures = [];
  final LectureRepository _calendarRepository = LectureRepository();
  late final CalendarService _calendarService;
  final LectureActionNotificationService _notificationService =
      LectureActionNotificationService.instance;
  bool _isLoadingLectures = true;
  String? _loadError;
  StreamSubscription<void>? _calendarSyncSub;
  bool _isSyncRefreshing = false;

  // اختيار المادة ثم اليوم من التقويم
  DateTime _selectedDate = DateTime.now();
  DateTime _currentCalendarMonth = DateTime.now();
  late int _selectedDayOfWeek;
  String? _selectedCourse;

  /// محاضرات تم إرسال إشعار لها في هذه الجلسة (لتجنب إرسال مرتين)
  final Set<String> _delaySentFor = {};
  final Set<String> _cancelSentFor = {};

  @override
  void initState() {
    super.initState();
    _calendarService = CalendarService(_calendarRepository);
    _selectedDayOfWeek = DateTime.now().weekday;
    _calendarSyncSub = CalendarSyncService.instance.watchChanges().listen(
      (_) => _handleRealtimeCalendarChange(),
    );
    _loadLectures();
  }

  @override
  void dispose() {
    _calendarSyncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadLectures() async {
    setState(() {
      _isLoadingLectures = true;
      _loadError = null;
    });
    try {
      await _calendarRepository.refreshAcademicCalendar();
      final now = _calendarRepository.currentDateTime;
      final list = await LecturerSectionsService.instance
          .getLecturesForCurrentLecturer();
      if (!mounted) return;
      final courseOptions =
          list
              .map((l) => l.courseName.trim())
              .where((n) => n.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      setState(() {
        _allLectures = list;
        _selectedDate = DateTime(now.year, now.month, now.day);
        _selectedDayOfWeek = _selectedDate.weekday;
        _currentCalendarMonth = DateTime(now.year, now.month, 1);
        if (_selectedCourse == null && courseOptions.isNotEmpty) {
          _selectedCourse = courseOptions.first;
        } else if (_selectedCourse != null &&
            !courseOptions.contains(_selectedCourse)) {
          _selectedCourse = courseOptions.isNotEmpty
              ? courseOptions.first
              : null;
        }
        _isLoadingLectures = false;
        _loadError = null;
        _applyFilters();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLectures = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _handleRealtimeCalendarChange() async {
    if (!mounted || _isSyncRefreshing) return;
    _isSyncRefreshing = true;
    try {
      await _calendarRepository.refreshAcademicCalendar();
      if (!mounted) return;
      setState(() {
        final now = _calendarRepository.currentDateTime;
        final previous = _selectedDate;
        final today = DateTime(now.year, now.month, now.day);
        if (previous.year == today.year &&
            previous.month == today.month &&
            previous.day == today.day) {
          _selectedDate = today;
          _selectedDayOfWeek = today.weekday;
          _currentCalendarMonth = DateTime(today.year, today.month, 1);
        }
        _applyFilters();
      });
    } catch (_) {
      // Ignore transient realtime listener errors.
    } finally {
      _isSyncRefreshing = false;
    }
  }

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  int _getTargetWeekday() => _selectedDayOfWeek;

  DateTime _getReferenceDate() => _selectedDate;

  /// تحقق من انتهاء المحاضرة باستخدام تاريخ فقط ثم وقت النهاية عند الحاجة.
  bool _isLectureEnded(LectureItem lecture) {
    final refDate = _getReferenceDate();
    final now = _calendarRepository.currentDateTime;
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

  List<LectureItem> _computeFilteredLectures() {
    if (_selectedCourse == null || _selectedCourse!.trim().isEmpty) {
      return <LectureItem>[];
    }
    final target = _getTargetWeekday();
    var list = _allLectures
        .where(
          (l) =>
              l.dayOfWeek == target &&
              l.courseName.trim() == _selectedCourse!.trim(),
        )
        .toList();
    return TimeUtils.sortLecturesByTime(list, (l) => l.startTime);
  }

  List<String> get _uniqueCourseNames {
    final names =
        _allLectures
            .map((l) => l.courseName.trim())
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return names;
  }

  void _applyFilters() {}

  Future<void> _openLectureActionsForLecture(LectureItem lecture) async {
    await _openLectureActionScreen(
      lecture,
      initialAction: _ManageActionType.delay,
    );
  }

  Future<void> _openDayActionsPopup() async {
    if (_selectedCourse == null || _selectedCourse!.trim().isEmpty) return;

    if (_calendarRepository.isHoliday(_selectedDate)) {
      _showActionSnack(
        _tr(
          'اليوم المختار إجازة، لا يمكن تنفيذ تأخير أو إلغاء',
          'Selected day is a holiday, no delay/cancellation actions',
        ),
      );
      return;
    }

    final lectures = _computeFilteredLectures();
    if (lectures.isEmpty) {
      _showActionSnack(
        _tr(
          'لا توجد محاضرات في هذا اليوم للمادة المختارة',
          'No lectures on this day for selected course',
        ),
      );
      return;
    }

    LectureItem? selectedLecture;
    if (lectures.length == 1) {
      selectedLecture = lectures.first;
    } else {
      selectedLecture = await _pickLectureFromDayDialog(lectures);
    }
    if (!mounted || selectedLecture == null) return;
    await _openLectureActionsForLecture(selectedLecture);
  }

  Future<LectureItem?> _pickLectureFromDayDialog(
    List<LectureItem> lectures,
  ) async {
    return showDialog<LectureItem>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: AlertDialog(
            title: Text(_tr('اختاري المحاضرة', 'Choose lecture')),
            content: SizedBox(
              width: 420,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: lectures.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final lecture = lectures[index];
                  final timeRange = TimeUtils.formatTimeRange(
                    lecture.startTime,
                    lecture.endTime,
                  );
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => Navigator.of(dialogContext).pop(lecture),
                    title: Text(
                      lecture.courseName,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2E33),
                      ),
                    ),
                    subtitle: Text(
                      '${_tr('الشعبة', 'Section')} ${lecture.section} • $timeRange',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Color(0xFF5A6F76),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(_tr('إغلاق', 'Close')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openLectureActionScreen(
    LectureItem lecture, {
    required _ManageActionType initialAction,
  }) async {
    final result = await showDialog<_ManageLectureActionResult>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 22,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
              child: _LectureActionDialog(
                lecture: lecture,
                selectedDate: _selectedDate,
                delayYellow: _delayYellow,
                cancelRed: _cancelRed,
                isEnded: _isLectureEnded(lecture),
                delaySent: _delaySentFor.contains(lecture.crn),
                cancelSent: _cancelSentFor.contains(lecture.crn),
                initialAction: initialAction,
                tr: _tr,
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || result == null) return;

    if (result.action == _ManageActionType.delay) {
      final delayMinutes = result.delayMinutes;
      if (delayMinutes == null || delayMinutes <= 0) {
        _showActionSnack(
          _tr('مدة التأخير غير صحيحة', 'Invalid delay duration'),
          error: true,
        );
        return;
      }
      if (_isLectureEnded(lecture)) {
        _showActionSnack(
          _tr('لا يمكن تأخير محاضرة منتهية', 'Cannot delay a finished lecture'),
          error: true,
        );
        return;
      }
      if (_delaySentFor.contains(lecture.crn)) {
        _showActionSnack(
          _tr(
            'تم إرسال إشعار التأخير لهذه المحاضرة مسبقاً',
            'Delay notification was already sent for this lecture',
          ),
        );
        return;
      }
      await _sendDelayNotification(lecture, delayMinutes);
      return;
    }

    if (_isLectureEnded(lecture)) {
      _showActionSnack(
        _tr('لا يمكن إلغاء محاضرة ماضية', 'Cannot cancel a past lecture'),
        error: true,
      );
      return;
    }
    if (_cancelSentFor.contains(lecture.crn)) {
      _showActionSnack(
        _tr(
          'تم إرسال إشعار الإلغاء لهذه المحاضرة مسبقاً',
          'Cancellation notification was already sent for this lecture',
        ),
      );
      return;
    }
    await _sendCancellationNotification(lecture);
  }

  void _showActionSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? _cancelRed : Colors.grey.shade700,
      ),
    );
  }

  Future<void> _sendDelayNotification(
    LectureItem lecture,
    int delayMinutes,
  ) async {
    try {
      final result = await _notificationService.sendDelayNotification(
        lecture: lecture,
        delayMinutes: delayMinutes,
        lectureDayOfWeek: _getTargetWeekday(),
        lectureDate: _selectedDate,
      );
      if (!mounted) return;
      setState(() {
        _delaySentFor.add(lecture.crn);
      });
      _showDelaySuccessScreen(
        lecture,
        delayMinutes,
        dispatchMessage: _tr(
          result.lecturerMessageAr,
          result.lecturerMessageEn,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'تعذر إرسال الإشعار. حاول مرة أخرى.',
              'Failed to send notification. Please try again.',
            ),
          ),
          backgroundColor: _cancelRed,
        ),
      );
    }
  }

  Future<void> _sendCancellationNotification(LectureItem lecture) async {
    try {
      final result = await _notificationService.sendCancellationNotification(
        lecture: lecture,
        lectureDayOfWeek: _getTargetWeekday(),
        lectureDate: _selectedDate,
      );
      if (!mounted) return;
      setState(() {
        _cancelSentFor.add(lecture.crn);
      });
      _showCancelSuccessScreen(
        lecture,
        dispatchMessage: _tr(
          result.lecturerMessageAr,
          result.lecturerMessageEn,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'تعذر إرسال الإشعار. حاول مرة أخرى.',
              'Failed to send notification. Please try again.',
            ),
          ),
          backgroundColor: _cancelRed,
        ),
      );
    }
  }

  void _showDelaySuccessScreen(
    LectureItem lecture,
    int delayMinutes, {
    required String dispatchMessage,
  }) {
    final (sh, sm) = TimeUtils.parseTimeString(lecture.startTime);
    final newStart = (sh * 60 + sm + delayMinutes) % (24 * 60);
    final nh = newStart ~/ 60;
    final nm = newStart % 60;
    final newTimeStr =
        '${nh.toString().padLeft(2, '0')}:${nm.toString().padLeft(2, '0')}';
    final newTimeDisplay = TimeUtils.formatTimeRange(
      newTimeStr,
      lecture.endTime,
    ).split(' - ').first;

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
            border: Border.all(color: _primary.withValues(alpha: 0.35)),
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
              Icon(Icons.check_circle_rounded, size: 56, color: _primary),
              const SizedBox(height: 16),
              Text(
                _tr(
                  'تم إرسال التأخير وإشعار الطلاب',
                  'Delay sent and students notified',
                ),
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
              const SizedBox(height: 6),
              Text(
                dispatchMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
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

  void _showCancelSuccessScreen(
    LectureItem lecture, {
    required String dispatchMessage,
  }) {
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
            border: Border.all(color: _cancelRed.withValues(alpha: 0.35)),
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
                _tr(
                  'تم إرسال الإلغاء وإشعار الطلاب',
                  'Cancellation sent and students notified',
                ),
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
                dispatchMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
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
              actions: [
                IconButton(
                  tooltip: _tr('جلسة NFC', 'NFC session'),
                  onPressed: () =>
                      LecturerNavigation.goToNfcSessionManagement(context),
                  icon: const Icon(Icons.nfc_rounded, color: _primary),
                ),
              ],
            ),
            body: SafeArea(
              child: _isLoadingLectures
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          color: Color(0xFF006571),
                        ),
                      ),
                    )
                  : _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _tr(
                                'حدث خطأ في تحميل المحاضرات',
                                'Failed to load lectures',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: _loadLectures,
                              icon: const Icon(Icons.refresh),
                              label: Text(_tr('إعادة المحاولة', 'Retry')),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSelectionPanel(),
                        Expanded(child: _buildContent()),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectionPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 470),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _tr('1) اختاري المادة', '1) Select course'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2E33),
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 10),
              _buildCourseCards(),
              const SizedBox(height: 14),
              Text(
                _tr(
                  '2) اختاري اليوم من التقويم',
                  '2) Select day from calendar',
                ),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2E33),
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 10),
              _buildCalendarPicker(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseCards() {
    final options = _uniqueCourseNames;
    if (options.isEmpty) {
      return _compactInfoCard(
        icon: Icons.menu_book_outlined,
        message: _tr(
          'لا توجد مواد مرتبطة بحسابك حالياً',
          'No courses linked to your account yet',
        ),
      );
    }

    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final course = options[index];
          final selected = _selectedCourse == course;
          final count = _allLectures
              .where((l) => l.courseName.trim() == course)
              .length;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCourse = course;
                _applyFilters();
              });
            },
            child: Container(
              width: 210,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFFE6F3F5) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _primary : const Color(0xFFE2E8EA),
                  width: selected ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_stories_outlined,
                        size: 18,
                        color: selected ? _primary : const Color(0xFF607D85),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          course,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? const Color(0xFF0A5A63)
                                : const Color(0xFF243238),
                            fontFamily: 'Cairo',
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFD3E9EC)
                          : const Color(0xFFF2F6F7),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      _tr('$count شعبة/موعد', '$count lecture slots'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF45616A),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendarPicker() {
    final selectedCourse = _selectedCourse;
    if (selectedCourse == null || selectedCourse.trim().isEmpty) {
      return _compactInfoCard(
        icon: Icons.touch_app_outlined,
        message: _tr(
          'اختاري مادة أولاً حتى يظهر التقويم الخاص بها',
          'Select a course first to show its calendar',
        ),
      );
    }

    final courseLectures = _allLectures
        .where((l) => l.courseName.trim() == selectedCourse.trim())
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MonthlyCalendar(
          currentMonth: _currentCalendarMonth,
          calendarDays: _calendarService.buildCalendarDays(
            _currentCalendarMonth,
            courseLectures,
          ),
          onDayTap: (CalendarDay day) {
            setState(() {
              _selectedDate = DateTime(
                day.date.year,
                day.date.month,
                day.date.day,
              );
              _selectedDayOfWeek = day.date.weekday;
              _applyFilters();
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _openDayActionsPopup();
            });
          },
          onMonthChanged: (DateTime month) {
            setState(() {
              _currentCalendarMonth = month;
            });
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(
              Icons.event_available_rounded,
              size: 17,
              color: _primary,
            ),
            const SizedBox(width: 6),
            Text(
              _tr(
                'اليوم المختار: ${LecturerLanguageController.dayNameFromWeekday(_selectedDate.weekday)} ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                'Selected day: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF52646A),
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _compactInfoCard({required IconData icon, required String message}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2ECEF)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF648087)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF5A6F76),
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedCourse == null || _selectedCourse!.trim().isEmpty) {
      return _buildEmptyState(
        _tr(
          'اختاري مادة من الكروت بالأعلى ثم اختاري اليوم من التقويم',
          'Select a course card then pick a day from calendar',
        ),
      );
    }
    return _buildEmptyState(
      _tr(
        'اختاري اليوم من التقويم، وستظهر نافذة منبثقة للتأخير أو الإلغاء',
        'Pick a day from calendar and a popup will open for delay/cancellation',
      ),
    );
  }

  Widget _buildEmptyState(String title) {
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
              title,
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
                'يمكنك اختيار مادة أو يوم آخر للمتابعة',
                'You can choose another course or day',
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

enum _ManageActionType { delay, cancel }

class _ManageLectureActionResult {
  const _ManageLectureActionResult.delay(this.delayMinutes)
    : action = _ManageActionType.delay;

  const _ManageLectureActionResult.cancel()
    : action = _ManageActionType.cancel,
      delayMinutes = null;

  final _ManageActionType action;
  final int? delayMinutes;
}

class _LectureActionDialog extends StatefulWidget {
  const _LectureActionDialog({
    required this.lecture,
    required this.selectedDate,
    required this.delayYellow,
    required this.cancelRed,
    required this.isEnded,
    required this.delaySent,
    required this.cancelSent,
    required this.initialAction,
    required this.tr,
  });

  final LectureItem lecture;
  final DateTime selectedDate;
  final Color delayYellow;
  final Color cancelRed;
  final bool isEnded;
  final bool delaySent;
  final bool cancelSent;
  final _ManageActionType initialAction;
  final String Function(String ar, String en) tr;

  @override
  State<_LectureActionDialog> createState() => _LectureActionDialogState();
}

class _LectureActionDialogState extends State<_LectureActionDialog> {
  late _ManageActionType _selectedAction;
  int? _selectedMinutes = 10;
  bool _otherSelected = false;
  final TextEditingController _otherController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedAction = widget.initialAction;
  }

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  int? get _effectiveMinutes {
    if (_otherSelected) {
      final value = int.tryParse(_otherController.text.trim());
      return (value != null && value > 0) ? value : null;
    }
    return _selectedMinutes;
  }

  bool get _canSubmitDelay =>
      !widget.isEnded && !widget.delaySent && (_effectiveMinutes ?? 0) > 0;

  bool get _canSubmitCancel => !widget.isEnded && !widget.cancelSent;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${widget.selectedDate.day}/${widget.selectedDate.month}/${widget.selectedDate.year}';
    final dayLabel = LecturerLanguageController.dayNameFromWeekday(
      widget.selectedDate.weekday,
    );
    final timeRange = TimeUtils.formatTimeRange(
      widget.lecture.startTime,
      widget.lecture.endTime,
    );

    return Scaffold(
      body: ColoredBox(
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.tr('إجراء المحاضرة', 'Lecture action'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222222),
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: widget.tr('إغلاق', 'Close'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2ECEF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lecture.courseName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2E33),
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$dayLabel - $dateLabel',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF5A6F76),
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.tr('الوقت', 'Time')}: $timeRange',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF5A6F76),
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ),
            if (widget.isEnded) ...[
              const SizedBox(height: 12),
              _ActionInfoBanner(
                icon: Icons.info_outline_rounded,
                text: widget.tr(
                  'المحاضرة منتهية، لا يمكن تنفيذ تأخير أو إلغاء',
                  'Lecture ended, delay and cancellation are unavailable',
                ),
                color: const Color(0xFFB71C1C),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionModeButton(
                    label: widget.tr('تأخير', 'Delay'),
                    active: _selectedAction == _ManageActionType.delay,
                    color: widget.delayYellow,
                    onTap: () => setState(
                      () => _selectedAction = _ManageActionType.delay,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionModeButton(
                    label: widget.tr('إلغاء', 'Cancel'),
                    active: _selectedAction == _ManageActionType.cancel,
                    color: widget.cancelRed,
                    onTap: () => setState(
                      () => _selectedAction = _ManageActionType.cancel,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_selectedAction == _ManageActionType.delay) ...[
              _buildDelayPanel(),
            ] else ...[
              _buildCancelPanel(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDelayPanel() {
    final options = <int>[5, 10, 15, 20, 30];
    final disabledReason = widget.delaySent
        ? widget.tr(
            'تم إرسال إشعار التأخير مسبقًا لهذه المحاضرة',
            'Delay notification already sent for this lecture',
          )
        : widget.tr(
            'لا يمكن التأخير لمحاضرة منتهية',
            'Cannot delay a finished lecture',
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.tr('مدة التأخير', 'Delay duration'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2E33),
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in options)
                _DurationChoiceChip(
                  label: widget.tr('$m دقائق', '$m min'),
                  selected: !_otherSelected && _selectedMinutes == m,
                  onTap: () => setState(() {
                    _selectedMinutes = m;
                    _otherSelected = false;
                  }),
                ),
              _DurationChoiceChip(
                label: widget.tr('مدة أخرى', 'Other'),
                selected: _otherSelected,
                onTap: () => setState(() {
                  _otherSelected = true;
                  _selectedMinutes = null;
                }),
              ),
            ],
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _canSubmitDelay
                  ? () {
                      final minutes = _effectiveMinutes;
                      if (minutes == null || minutes <= 0) return;
                      Navigator.of(
                        context,
                      ).pop(_ManageLectureActionResult.delay(minutes));
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: widget.delayYellow,
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.schedule_rounded),
              label: Text(
                widget.tr('إرسال إشعار التأخير', 'Send delay notification'),
              ),
            ),
          ),
          if (!_canSubmitDelay) ...[
            const SizedBox(height: 8),
            Text(
              widget.isEnded || widget.delaySent
                  ? disabledReason
                  : widget.tr(
                      'اختاري مدة تأخير صحيحة',
                      'Select a valid delay duration',
                    ),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCancelPanel() {
    final disabledReason = widget.cancelSent
        ? widget.tr(
            'تم إرسال إشعار الإلغاء مسبقًا لهذه المحاضرة',
            'Cancellation notification already sent for this lecture',
          )
        : widget.tr(
            'لا يمكن الإلغاء لمحاضرة منتهية',
            'Cannot cancel a finished lecture',
          );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActionInfoBanner(
            icon: Icons.warning_amber_rounded,
            text: widget.tr(
              'عند الإلغاء سيتم إشعار جميع الطلاب المسجلين في الشعبة',
              'All enrolled students will be notified',
            ),
            color: widget.cancelRed,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _canSubmitCancel
                  ? () => Navigator.of(
                      context,
                    ).pop(const _ManageLectureActionResult.cancel())
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: widget.cancelRed,
                disabledBackgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.event_busy_rounded),
              label: Text(
                widget.tr(
                  'تأكيد إلغاء المحاضرة',
                  'Confirm lecture cancellation',
                ),
              ),
            ),
          ),
          if (!_canSubmitCancel) ...[
            const SizedBox(height: 8),
            Text(
              disabledReason,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionModeButton extends StatelessWidget {
  const _ActionModeButton({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? color : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? Colors.transparent : const Color(0xFFD7E4E8),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : const Color(0xFF3F565D),
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ),
    );
  }
}

class _DurationChoiceChip extends StatelessWidget {
  const _DurationChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE5F5F7) : const Color(0xFFF7FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF006571) : const Color(0xFFDCE7EA),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? const Color(0xFF00525A) : const Color(0xFF586E75),
            fontWeight: FontWeight.w600,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}

class _ActionInfoBanner extends StatelessWidget {
  const _ActionInfoBanner({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
