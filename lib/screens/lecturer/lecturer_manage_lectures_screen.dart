import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/lecturer/lecture_item.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../services/lecturer/calendar_sync_service.dart';
import '../../services/lecturer/lecturer_sections_service.dart';
import '../../services/notifications/lecture_action_notification_service.dart';
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

  List<LectureItem> _allLectures = [];
  final LectureRepository _calendarRepository = LectureRepository();
  final LectureActionNotificationService _notificationService =
      LectureActionNotificationService.instance;
  bool _isLoadingLectures = true;
  String? _loadError;
  StreamSubscription<void>? _calendarSyncSub;
  bool _isSyncRefreshing = false;

  // اختيار: الأسبوع + اليوم -> التاريخ -> المقرر
  bool _weekIsAuto = true;
  int? _selectedWeekNumber;
  final List<int> _dayOrder = const [7, 1, 2, 3, 4];
  DateTime? _selectedDate;
  String? _selectedCourseCode;
  final Set<String> _selectedLectureKeys = <String>{};
  Map<String, LectureActionStatus> _lectureActionStatuses = const {};

  @override
  void initState() {
    super.initState();
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
      final list = await LecturerSectionsService.instance
          .getLecturesForCurrentLecturer();
      if (!mounted) return;
      setState(() {
        _allLectures = list;
        _weekIsAuto = true;
        _selectedWeekNumber = _currentWeekNumber;
        _selectedDate = null;
        _selectedCourseCode = null;
        _selectedLectureKeys.clear();
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
        _applyFilters();
      });
    } catch (_) {
      // Ignore transient realtime listener errors.
    } finally {
      _isSyncRefreshing = false;
    }
  }

  void _onManageWeekChanged({required bool auto, int? week}) {
    setState(() {
      _weekIsAuto = auto;
      _selectedWeekNumber = auto ? _currentWeekNumber : week;
      _selectedDate = null;
      _selectedLectureKeys.clear();
      _applyFilters();
    });
  }

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  int get _currentWeekNumber =>
      _calendarRepository.getWeekNumber(_calendarRepository.currentDateTime);
  int get _maxSelectableWeeks => _calendarRepository.semesterWeeks.clamp(1, 60);

  int? _getTargetWeekday() {
    final selected = _selectedLectures;
    if (selected.isNotEmpty) return selected.first.dayOfWeek;
    return _selectedDate?.weekday;
  }

  DateTime _getReferenceDate() =>
      _selectedDate ?? _calendarRepository.currentDateTime;

  DateTime? _dateForLectureInSelectedWeek(LectureItem lecture) {
    if (_selectedWeekNumber == null) return null;
    return _calendarRepository.dateForWeekAndWeekday(
      _selectedWeekNumber!,
      lecture.dayOfWeek,
    );
  }

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

  List<LectureItem> _computeLecturesForDateAndCourse() {
    final selectedCourseCode = _selectedCourseCode?.trim();
    if (selectedCourseCode == null ||
        selectedCourseCode.isEmpty ||
        _selectedWeekNumber == null) {
      return <LectureItem>[];
    }
    var list = _allLectures
        .where(
          (l) =>
              _dayOrder.contains(l.dayOfWeek) &&
              l.crn.trim() == selectedCourseCode,
        )
        .toList();
    list.sort((a, b) {
      final dayCompare = _dayOrder
          .indexOf(a.dayOfWeek)
          .compareTo(_dayOrder.indexOf(b.dayOfWeek));
      if (dayCompare != 0) return dayCompare;
      final at = TimeUtils.parseTimeString(a.startTime);
      final bt = TimeUtils.parseTimeString(b.startTime);
      return (at.$1 * 60 + at.$2).compareTo(bt.$1 * 60 + bt.$2);
    });
    return list;
  }

  List<({String code, String name})> get _courseOptionsForDate {
    final map = <String, String>{};
    for (final lecture in _allLectures.where(
      (l) => _dayOrder.contains(l.dayOfWeek),
    )) {
      final code = lecture.crn.trim();
      if (code.isEmpty) continue;
      map.putIfAbsent(code, () => lecture.courseName.trim());
    }
    final options =
        map.entries.map((e) => (code: e.key, name: e.value)).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return options;
  }

  void _applyFilters() {
    unawaited(_refreshLectureActionStatuses());
  }

  String _actionStatusKey(LectureItem lecture) {
    final sectionKey = (lecture.sectionId ?? '').trim().isNotEmpty
        ? (lecture.sectionId ?? '').trim()
        : lecture.section.trim();
    return '$sectionKey|${lecture.startTime}';
  }

  LectureActionStatus _statusForLecture(LectureItem lecture) {
    return _lectureActionStatuses[_actionStatusKey(lecture)] ??
        const LectureActionStatus.normal();
  }

  Future<void> _refreshLectureActionStatuses() async {
    final selectedDate = _selectedDate;
    if (selectedDate == null) {
      if (mounted && _lectureActionStatuses.isNotEmpty) {
        setState(() {
          _lectureActionStatuses = const {};
        });
      }
      return;
    }
    final lectures = _computeLecturesForDateAndCourse();
    if (lectures.isEmpty) {
      if (mounted && _lectureActionStatuses.isNotEmpty) {
        setState(() {
          _lectureActionStatuses = const {};
        });
      }
      return;
    }
    try {
      final statuses = await _notificationService.loadLectureActionStatuses(
        lectures: lectures,
        lectureDate: selectedDate,
      );
      if (!mounted) return;
      setState(() {
        _lectureActionStatuses = statuses;
      });
    } catch (_) {
      // Keep UI usable even if status sync fails temporarily.
    }
  }

  bool get _hasDateAndCourseSelection {
    return _selectedCourseCode != null &&
        _selectedCourseCode!.trim().isNotEmpty &&
        _selectedWeekNumber != null;
  }

  String _lectureSelectionKey(LectureItem lecture) {
    final sectionKey = (lecture.sectionId ?? '').trim().isNotEmpty
        ? (lecture.sectionId ?? '').trim()
        : lecture.section.trim();
    return '$sectionKey|${lecture.startTime}|${lecture.endTime}|${lecture.activity}|${lecture.hall}';
  }

  List<LectureItem> get _selectedLectures {
    final all = _computeLecturesForDateAndCourse();
    return all
        .where(
          (lecture) =>
              _selectedLectureKeys.contains(_lectureSelectionKey(lecture)),
        )
        .toList();
  }

  bool get _isPastSelectedDate {
    if (_selectedDate == null) return false;
    final now = _calendarRepository.currentDateTime;
    final selected = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    return selected.isBefore(today);
  }

  Future<void> _openLectureActionsForSelection() async {
    final selected = _selectedLectures;
    if (selected.isEmpty || _selectedDate == null) return;

    final multi = selected.length > 1;
    final primary = selected.first;
    final primaryStatus = _statusForLecture(primary);

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
                lecture: primary,
                multiSelection: multi ? selected : null,
                selectedDate:
                    _selectedDate ?? _calendarRepository.currentDateTime,
                delayYellow: _delayYellow,
                cancelRed: _cancelRed,
                isEnded: multi ? false : _isLectureEnded(primary),
                delaySent: multi
                    ? false
                    : (primaryStatus.isDelayed || primaryStatus.isCanceled),
                cancelSent: multi ? false : primaryStatus.isCanceled,
                initialAction: _ManageActionType.delay,
                tr: _tr,
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || result == null) return;

    if (multi) {
      if (result.action == _ManageActionType.delay) {
        final delayMinutes = result.delayMinutes;
        if (delayMinutes == null || delayMinutes <= 0) {
          _showActionSnack(
            _tr('مدة التأخير غير صحيحة', 'Invalid delay duration'),
            error: true,
          );
          return;
        }
        await _applyDelayForSelectedLectures(presetMinutes: delayMinutes);
        return;
      }
      await _applyCancelForSelectedLectures();
      return;
    }

    await _handleSingleLectureActionResult(primary, result);
  }

  Future<void> _handleSingleLectureActionResult(
    LectureItem lecture,
    _ManageLectureActionResult result,
  ) async {
    final status = _statusForLecture(lecture);
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
      if (status.isCanceled) {
        _showActionSnack(
          _tr('هذه المحاضرة ملغية بالفعل', 'This lecture is already canceled'),
          error: true,
        );
        return;
      }
      if (status.isDelayed) {
        _showActionSnack(
          _tr('تم إرسال هذا الإجراء مسبقًا', 'This action was already sent'),
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
    if (status.isCanceled) {
      _showActionSnack(
        _tr('هذه المحاضرة ملغية بالفعل', 'This lecture is already canceled'),
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
    final targetWeekday = _getTargetWeekday();
    if (targetWeekday == null || _selectedDate == null) {
      _showActionSnack(
        _tr('يرجى اختيار تاريخ صالح أولاً', 'Please select a valid date first'),
        error: true,
      );
      return;
    }
    try {
      final result = await _notificationService.sendDelayNotification(
        lecture: lecture,
        delayMinutes: delayMinutes,
        lectureDayOfWeek: targetWeekday,
        lectureDate: _selectedDate!,
      );
      if (!mounted) return;
      await _refreshLectureActionStatuses();
      _showDelaySuccessScreen(
        lecture,
        delayMinutes,
        dispatchMessage: _tr(
          result.lecturerMessageAr,
          result.lecturerMessageEn,
        ),
      );
    } on LectureActionBlockedException catch (e) {
      if (!mounted) return;
      _showActionSnack(_mapBlockedActionMessage(e.reason), error: true);
    } on LectureActionPartialFailureException {
      if (!mounted) return;
      await _refreshLectureActionStatuses();
      _showActionSnack(
        _tr(
          'تم تسجيل تأخير المحاضرة، لكن حدثت مشكلة في بعض الإشعارات',
          'Delay action recorded, but some notifications failed',
        ),
        error: true,
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('[ManageLectures] delay send failed: $e');
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
    final targetWeekday = _getTargetWeekday();
    if (targetWeekday == null || _selectedDate == null) {
      _showActionSnack(
        _tr('يرجى اختيار تاريخ صالح أولاً', 'Please select a valid date first'),
        error: true,
      );
      return;
    }
    try {
      final result = await _notificationService.sendCancellationNotification(
        lecture: lecture,
        lectureDayOfWeek: targetWeekday,
        lectureDate: _selectedDate!,
      );
      if (!mounted) return;
      await _refreshLectureActionStatuses();
      _showCancelSuccessScreen(
        lecture,
        dispatchMessage: _tr(
          result.lecturerMessageAr,
          result.lecturerMessageEn,
        ),
      );
    } on LectureActionBlockedException catch (e) {
      if (!mounted) return;
      _showActionSnack(_mapBlockedActionMessage(e.reason), error: true);
    } on LectureActionPartialFailureException {
      if (!mounted) return;
      await _refreshLectureActionStatuses();
      _showActionSnack(
        _tr(
          'تم تسجيل إلغاء المحاضرة، لكن حدثت مشكلة في بعض الإشعارات',
          'Cancellation action recorded, but some notifications failed',
        ),
        error: true,
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('[ManageLectures] cancel send failed: $e');
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

  Future<int?> _pickDelayMinutesDialog() async {
    final controller = TextEditingController(text: '10');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_tr('مدة التأخير', 'Delay duration')),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: _tr('عدد الدقائق', 'Minutes'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_tr('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(int.tryParse(controller.text.trim()));
              },
              child: Text(_tr('تأكيد', 'Confirm')),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _applyDelayForSelectedLectures({int? presetMinutes}) async {
    final lectures = _selectedLectures;
    if (lectures.isEmpty ||
        _selectedDate == null ||
        _getTargetWeekday() == null) {
      return;
    }
    final minutes = presetMinutes ?? await _pickDelayMinutesDialog();
    if (!mounted || minutes == null || minutes <= 0) return;

    int success = 0;
    int skipped = 0;
    int failed = 0;
    for (final lecture in lectures) {
      final status = _statusForLecture(lecture);
      if (_isLectureEnded(lecture) || status.isCanceled || status.isDelayed) {
        skipped += 1;
        continue;
      }
      try {
        await _notificationService.sendDelayNotification(
          lecture: lecture,
          delayMinutes: minutes,
          lectureDayOfWeek: _getTargetWeekday()!,
          lectureDate: _selectedDate!,
        );
        success += 1;
      } on LectureActionBlockedException {
        skipped += 1;
      } on LectureActionPartialFailureException {
        success += 1;
        failed += 1;
      } catch (_) {
        failed += 1;
      }
    }
    if (!mounted) return;
    await _refreshLectureActionStatuses();
    _showActionSnack(
      failed == 0
          ? _tr(
              'تم التنفيذ لـ $success وتم تخطي $skipped',
              'Applied to $success and skipped $skipped',
            )
          : _tr(
              'تم التنفيذ لـ $success وتخطي $skipped وفشل $failed',
              'Applied $success, skipped $skipped, failed $failed',
            ),
      error: failed > 0,
    );
  }

  Future<void> _applyCancelForSelectedLectures() async {
    final lectures = _selectedLectures;
    if (lectures.isEmpty ||
        _selectedDate == null ||
        _getTargetWeekday() == null) {
      return;
    }
    int success = 0;
    int skipped = 0;
    int failed = 0;
    for (final lecture in lectures) {
      final status = _statusForLecture(lecture);
      if (_isLectureEnded(lecture) || status.isCanceled) {
        skipped += 1;
        continue;
      }
      try {
        await _notificationService.sendCancellationNotification(
          lecture: lecture,
          lectureDayOfWeek: _getTargetWeekday()!,
          lectureDate: _selectedDate!,
        );
        success += 1;
      } on LectureActionBlockedException {
        skipped += 1;
      } on LectureActionPartialFailureException {
        success += 1;
        failed += 1;
      } catch (_) {
        failed += 1;
      }
    }
    if (!mounted) return;
    await _refreshLectureActionStatuses();
    _showActionSnack(
      failed == 0
          ? _tr(
              'تم التنفيذ لـ $success وتم تخطي $skipped',
              'Applied to $success and skipped $skipped',
            )
          : _tr(
              'تم التنفيذ لـ $success وتخطي $skipped وفشل $failed',
              'Applied $success, skipped $skipped, failed $failed',
            ),
      error: failed > 0,
    );
  }

  String _mapBlockedActionMessage(LectureActionBlockReason reason) {
    switch (reason) {
      case LectureActionBlockReason.alreadyDelayed:
        return _tr(
          'تم إرسال هذا الإجراء مسبقًا',
          'This action was already sent',
        );
      case LectureActionBlockReason.alreadyCanceled:
        return _tr(
          'هذه المحاضرة ملغية بالفعل',
          'This lecture is already canceled',
        );
      case LectureActionBlockReason.canceledCannotDelay:
        return _tr(
          'لا يمكن تأخير محاضرة ملغية',
          'Cannot delay a canceled lecture',
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
              actions: const [],
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
                        Expanded(child: _buildContent()),
                        _buildSelectionPanel(),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectionPanel() {
    final weekLabel = _selectedWeekNumber == null
        ? _tr('غير محدد', 'Not selected')
        : '${_tr('أسبوع', 'Week')} $_selectedWeekNumber';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDDE9EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: _primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  _tr('فلترة سريعة', 'Quick Filter'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2F4449),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ManageFilterCard(
                    title: _tr('المقرر', 'Course'),
                    value:
                        _selectedCourseCode == null ||
                            _selectedCourseCode!.trim().isEmpty
                        ? _tr('غير محدد', 'Not selected')
                        : _buildCourseSelectorValue(),
                    subtitle: _tr('الخطوة الأولى', 'Step 1'),
                    icon: Icons.menu_book_rounded,
                    onPressed: () => _pickCourseForDate(_courseOptionsForDate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ManageFilterCard(
              title: _tr('الأسبوع الدراسي', 'Academic Week'),
              value: weekLabel,
              subtitle: _tr('الخطوة الثانية', 'Step 2'),
              icon: Icons.view_week_rounded,
              onPressed: _isCourseSelectedForManage
                  ? _showManageWeekPickerSheet
                  : () {
                      _showActionSnack(
                        _tr('اختاري المقرر أولاً', 'Select course first'),
                        error: true,
                      );
                    },
            ),
            const SizedBox(height: 8),
            _buildSelectionStateBanner(),
          ],
        ),
      ),
    );
  }

  bool get _isCourseSelectedForManage =>
      _selectedCourseCode != null && _selectedCourseCode!.trim().isNotEmpty;

  String _buildCourseSelectorValue() {
    final options = _courseOptionsForDate;
    final selected = options
        .where((o) => o.code == _selectedCourseCode)
        .cast<({String code, String name})?>()
        .firstWhere((o) => o != null, orElse: () => null);
    return selected == null
        ? (_selectedCourseCode ?? _tr('غير محدد', 'Not selected'))
        : '${selected.name} (${selected.code})';
  }

  void _showManageWeekPickerSheet() {
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
              _tr('اختيار الأسبوع', 'Week picker'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
                color: Color(0xFF222222),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              title: Text(
                '${_tr('الأسبوع الحالي', 'Current week')} (${_tr('تلقائي', 'Auto')})',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: _weekIsAuto ? FontWeight.w700 : FontWeight.normal,
                  color: _weekIsAuto ? _primary : const Color(0xFF222222),
                ),
              ),
              trailing: _weekIsAuto
                  ? const Icon(Icons.check_rounded, color: _primary, size: 22)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _onManageWeekChanged(auto: true);
              },
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _maxSelectableWeeks,
                itemBuilder: (_, index) {
                  final week = index + 1;
                  final selected = !_weekIsAuto && _selectedWeekNumber == week;
                  return ListTile(
                    title: Text(
                      '${_tr('أسبوع', 'Week')} $week',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: selected ? _primary : const Color(0xFF222222),
                      ),
                    ),
                    trailing: selected
                        ? const Icon(
                            Icons.check_rounded,
                            color: _primary,
                            size: 22,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _onManageWeekChanged(auto: false, week: week);
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

  Widget _buildSelectionStateBanner() {
    String message;
    Color bg = const Color(0xFFF3F7F8);
    Color border = const Color(0xFFD8E4E7);
    Color text = const Color(0xFF455D63);
    IconData icon = Icons.info_outline_rounded;

    if (!_isCourseSelectedForManage) {
      message = _tr('اختاري المقرر أولاً.', 'Select the course first.');
    } else if (_selectedWeekNumber == null) {
      message = _tr('اختاري الأسبوع الدراسي.', 'Select the academic week.');
      icon = Icons.view_week_rounded;
    } else {
      message = _tr(
        'تم اختيار المقرر والأسبوع، اختاري محاضرة من الكروت.',
        'Course and week selected, choose a lecture card.',
      );
      bg = const Color(0xFFEAF7EF);
      border = const Color(0xFFCBE8D2);
      text = const Color(0xFF24643A);
      icon = Icons.check_circle_outline_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: text),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCourseForDate(
    List<({String code, String name})> options,
  ) async {
    if (options.isEmpty) {
      _showActionSnack(
        _tr(
          'لا توجد مقررات متاحة حالياً',
          'No courses are currently available',
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF8FBFB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: SafeArea(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: options.length + 1,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFE2ECEF)),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    tileColor: const Color(0xFFF8FBFB),
                    leading: const Icon(
                      Icons.apps_rounded,
                      color: Color(0xFF006571),
                      size: 18,
                    ),
                    title: Text(
                      _tr('كل المقررات', 'All courses'),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F3338),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 14,
                      color: Color(0xFF006571),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(null),
                  );
                }
                final course = options[index - 1];
                return ListTile(
                  tileColor: const Color(0xFFF8FBFB),
                  leading: const Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFF006571),
                    size: 18,
                  ),
                  title: Text(
                    course.name,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F3338),
                    ),
                  ),
                  subtitle: Text(
                    course.code,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Color(0xFF6A838A),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14,
                    color: Color(0xFF006571),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(course.code),
                );
              },
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() {
      _selectedCourseCode = selected;
      _selectedWeekNumber = null;
      _selectedDate = null;
      _selectedLectureKeys.clear();
      _applyFilters();
    });
  }

  Widget _buildContent() {
    if (!_hasDateAndCourseSelection) {
      final guidance = _tr(
        'يرجى اختيار الأسبوع واليوم لعرض المحاضرات.',
        'Choose week and day to view lectures.',
      );
      return _buildEmptyState(guidance, showSecondaryHint: false);
    }
    final lectures = _computeLecturesForDateAndCourse();
    if (lectures.isEmpty) {
      return _buildEmptyState(
        _tr(
          'لا توجد محاضرات لهذا المقرر في الأسبوع المحدد',
          'No lectures for this course in the selected week',
        ),
        showSecondaryHint: false,
      );
    }

    final selectedLectures = _selectedLectures;
    final canManage = !_isPastSelectedDate;
    final selectedCanceled =
        selectedLectures.isNotEmpty &&
        selectedLectures.every((l) => _statusForLecture(l).isCanceled);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Text(
          _tr('المحاضرات', 'Lectures'),
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2E33),
          ),
        ),
        const SizedBox(height: 6),
        ...lectures.map(
          (lecture) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildLectureSelectionCard(lecture: lecture),
          ),
        ),
        const SizedBox(height: 6),
        if (_selectedLectureKeys.isEmpty)
          Text(
            _tr('اختر محاضرة واحدة للمتابعة', 'Select one lecture to continue'),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: Color(0xFF6E848B),
            ),
          ),
        if (!canManage)
          Text(
            _tr('لا يمكن إدارة محاضرة سابقة', 'Cannot manage a past lecture'),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              color: Color(0xFF8A5A00),
            ),
          ),
        if (selectedCanceled && canManage)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _tr(
                'هذه المحاضرة ملغية بالفعل',
                'This lecture is already canceled',
              ),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: Color(0xFFB71C1C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (selectedLectures.isNotEmpty && canManage) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: selectedCanceled
                  ? null
                  : _openLectureActionsForSelection,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.assignment_turned_in_rounded),
              label: Text(
                _tr('إدارة المحاضرة المحددة', 'Manage selected lecture'),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLectureSelectionCard({required LectureItem lecture}) {
    final key = _lectureSelectionKey(lecture);
    final isSelected = _selectedLectureKeys.contains(key);
    final timeRange = TimeUtils.formatTimeRange(
      lecture.startTime,
      lecture.endTime,
    );
    final locationText = lecture.location?.trim().isNotEmpty == true
        ? lecture.location!.trim()
        : lecture.hall.trim();
    final date = _dateForLectureInSelectedWeek(lecture) ?? _getReferenceDate();
    final now = _calendarRepository.currentDateTime;
    final todayOnly = DateTime(now.year, now.month, now.day);
    final lectureDateOnly = DateTime(date.year, date.month, date.day);
    final status = lectureDateOnly.isBefore(todayOnly)
        ? _tr('ماضي', 'Past')
        : (lectureDateOnly.isAfter(todayOnly)
              ? _tr('مستقبل', 'Future')
              : _tr('اليوم', 'Today'));
    final dateLabel = '${date.day}/${date.month}/${date.year}';
    final dayLabel = LecturerLanguageController.dayNameFromWeekday(
      date.weekday,
    );
    final actionStatus = _statusForLecture(lecture);
    final Color actionAccent = actionStatus.isCanceled
        ? _cancelRed
        : (actionStatus.isDelayed ? _delayYellow : _primary);
    final Color actionSoftBg = actionStatus.isCanceled
        ? const Color(0xFFFFEBEE)
        : (actionStatus.isDelayed
              ? const Color(0xFFFFF8E1)
              : const Color(0xFFEAF7F8));
    final actionBannerText = actionStatus.isCanceled
        ? _tr('هذه المحاضرة ملغية بالفعل', 'This lecture is already canceled')
        : actionStatus.isDelayed
        ? _tr(
            'تم إرسال تأخير ${actionStatus.delayMinutes ?? 0} دقيقة',
            'Delay sent: ${actionStatus.delayMinutes ?? 0} min',
          )
        : null;
    final actionBannerIcon = actionStatus.isCanceled
        ? Icons.cancel_rounded
        : Icons.schedule_rounded;

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedLectureKeys.remove(key);
            _selectedDate = null;
          } else {
            _selectedLectureKeys
              ..clear()
              ..add(key);
            _selectedDate = date;
            _applyFilters();
          }
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF7F8) : actionSoftBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _primary : actionAccent.withValues(alpha: 0.35),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 26,
                color: isSelected ? _primary : const Color(0xFF8EA3A9),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lecture.courseName.trim().isEmpty
                        ? '${_tr('الشعبة', 'Section')} ${lecture.section}'
                        : lecture.courseName,
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
                    '${_tr('الوقت', 'Time')}: $timeRange',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF5A6F76),
                      fontFamily: 'Cairo',
                    ),
                  ),
                  if (actionBannerText != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: actionAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: actionAccent.withValues(alpha: 0.34),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(actionBannerIcon, size: 16, color: actionAccent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              actionBannerText,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: actionAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildSectionSelectionMetaChip(
                        '${_tr('الشعبة', 'Section')} ${lecture.section}',
                      ),
                      _buildSectionSelectionMetaChip(
                        '${_tr('القاعة', 'Hall')}: ${locationText.isEmpty ? '—' : locationText}',
                      ),
                      if (lecture.activity.trim().isNotEmpty)
                        _buildSectionSelectionMetaChip(
                          '${_tr('النشاط', 'Activity')}: ${lecture.activity.trim()}',
                        ),
                      _buildSectionSelectionStatusChip(status),
                      if (actionStatus.isCanceled)
                        _buildSectionSelectionStatusChip(
                          _tr('ملغية بالفعل', 'Already canceled'),
                          color: _cancelRed,
                        ),
                      if (actionStatus.isDelayed)
                        _buildSectionSelectionStatusChip(
                          _tr(
                            'مؤجلة ${actionStatus.delayMinutes ?? 0} دقيقة',
                            'Delayed ${actionStatus.delayMinutes ?? 0} min',
                          ),
                          color: _delayYellow,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// شارة صغيرة للقاعة/الشعبة/النشاط — ألوان ثابتة فوق خلفية فاتحة (بما يتوافق مع ثيم إجراء المحاضرة).
  Widget _buildSectionSelectionMetaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE7EA)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF586E75),
        ),
      ),
    );
  }

  Widget _buildSectionSelectionStatusChip(String status, {Color? color}) {
    final base = color ?? const Color(0xFF5A7279);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: base.withValues(alpha: 0.30)),
      ),
      child: Text(
        status,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ).copyWith(color: base),
      ),
    );
  }

  Widget _buildEmptyState(String title, {bool showSecondaryHint = true}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 40,
              color: _primary.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF516166),
                fontFamily: 'Cairo',
                height: 1.35,
              ),
            ),
            if (showSecondaryHint) ...[
              const SizedBox(height: 6),
              Text(
                _tr(
                  'يمكنك تغيير التاريخ أو المقرر أو الشعبة.',
                  'Try another date, course, or section.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade600,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
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
    this.multiSelection,
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

  /// عند تحديد أكثر من شعبة: نفس القائمة المحددة (يشمل [lecture] كأول عنصر).
  final List<LectureItem>? multiSelection;
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

  bool get _isMulti =>
      widget.multiSelection != null && widget.multiSelection!.length > 1;

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
    final multiList = widget.multiSelection ?? const <LectureItem>[];

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
              child: _isMulti
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tr(
                            'سيطبق الإجراء على جميع الشعب المحددة',
                            'The action will apply to all selected sections',
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2E33),
                            fontFamily: 'Cairo',
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.tr('عدد الشعب', 'Sections')}: ${multiList.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5A6F76),
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
                        const SizedBox(height: 10),
                        ..._buildMultiSelectionPreviewRows(multiList),
                      ],
                    )
                  : Column(
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
                text: _isMulti
                    ? widget.tr(
                        'إحدى المحاضرات ضمن التحديد منتهية، لا يمكن تنفيذ تأخير أو إلغاء',
                        'One or more selected lectures have ended; delay and cancel are unavailable',
                      )
                    : widget.tr(
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

  List<Widget> _buildMultiSelectionPreviewRows(List<LectureItem> list) {
    const maxLines = 5;
    final rows = <Widget>[];
    for (var i = 0; i < list.length && i < maxLines; i++) {
      final l = list[i];
      final range = TimeUtils.formatTimeRange(l.startTime, l.endTime);
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '• ${widget.tr('الشعبة', 'Section')} ${l.section} · ${widget.tr('الوقت', 'Time')}: $range',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5A6F76),
              fontFamily: 'Cairo',
            ),
          ),
        ),
      );
    }
    if (list.length > maxLines) {
      rows.add(
        Text(
          widget.tr('وغيرها...', 'And more…'),
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.grey.shade600,
            fontFamily: 'Cairo',
          ),
        ),
      );
    }
    return rows;
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
              cursorColor: const Color(0xFF006571),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: widget.tr('أدخل عدد الدقائق', 'Enter minutes'),
                hintStyle: const TextStyle(
                  color: Color(0xFF7D9095),
                  fontFamily: 'Cairo',
                ),
                filled: true,
                fillColor: const Color(0xFFF8FBFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDCE7EA)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFDCE7EA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF006571),
                    width: 1.4,
                  ),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: Color(0xFF1F2E33),
              ),
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

class _ManageFilterCard extends StatelessWidget {
  const _ManageFilterCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.onPressed,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FBFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDCE9EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4F5),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF006571)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.8,
                        color: Color(0xFF688085),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        color: Color(0xFF1F3338),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: Color(0xFF7D9095),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: Color(0xFF006571),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
