import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lecturer/lecture_item.dart';
import '../../models/lecturer/unified_lecturer_catalog.dart';
import '../../providers/lecturer_catalog_providers.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../services/lecturer/calendar_sync_service.dart';
import '../../services/lecturer_auth_service.dart';
import '../../services/notifications/lecture_action_notification_service.dart';
import '../../utils/lecture_action_eligibility.dart';
import '../../utils/shared/time_utils.dart';
import 'lecturer_language.dart';
import 'lecturer_screen_session_memory.dart';
import 'widgets/modern_popup_dialog.dart';
import 'widgets/profile_back_button.dart';

/// شاشة إدارة المحاضرات: فلترة، إشعار تأخير، إشعار إلغاء
class LecturerManageLecturesScreen extends ConsumerStatefulWidget {
  const LecturerManageLecturesScreen({super.key});

  @override
  ConsumerState<LecturerManageLecturesScreen> createState() =>
      _LecturerManageLecturesScreenState();
}

class _LecturerManageLecturesScreenState
    extends ConsumerState<LecturerManageLecturesScreen> {
  static const Color _primary = Color(0xFF006571);
  static const Color _delayYellow = Color(0xFFF9A825);
  static const Color _cancelRed = Color(0xFFD32F2F);

  List<LectureItem> _allLectures = [];
  final LectureRepository _calendarRepository = LectureRepository();
  final LectureActionNotificationService _notificationService =
      LectureActionNotificationService.instance;
  bool _isLoadingLectures = true;
  bool _bgRefreshing = false;
  String? _loadError;
  StreamSubscription<void>? _calendarSyncSub;
  bool _isSyncRefreshing = false;

  // اختيار: الأسبوع + اليوم -> التاريخ -> المقرر
  int? _selectedWeekNumber;
  final List<int> _dayOrder = const [7, 1, 2, 3, 4];
  DateTime? _selectedDate;
  String? _selectedCourseCode;
  final Set<String> _selectedLectureKeys = <String>{};
  Map<String, LectureActionStatus> _lectureActionStatuses = const {};

  @override
  void initState() {
    super.initState();
    LecturerLanguageController.notifier.addListener(_onLecturerLanguageChanged);
    _calendarSyncSub = CalendarSyncService.instance.watchChanges().listen(
      (_) => _handleRealtimeCalendarChange(),
    );
    _bootstrapLecturesScreen();
  }

  @override
  void dispose() {
    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
    if (lecturerId.isNotEmpty && _allLectures.isNotEmpty) {
      LecturerManageScreenSessionMemory.save(
        lecturerId: lecturerId,
        lectures: _allLectures,
        selectedWeekNumber: _selectedWeekNumber,
        selectedDate: _selectedDate,
        selectedCourseCode: _selectedCourseCode,
        selectedLectureKeys: Set<String>.from(_selectedLectureKeys),
      );
    }
    LecturerLanguageController.notifier.removeListener(
      _onLecturerLanguageChanged,
    );
    _calendarSyncSub?.cancel();
    super.dispose();
  }

  void _bootstrapLecturesScreen() {
    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
    final restored = lecturerId.isNotEmpty
        ? LecturerManageScreenSessionMemory.takeRestore(lecturerId)
        : null;

    if (restored != null) {
      _allLectures = restored.lectures;
      _selectedWeekNumber = restored.selectedWeekNumber;
      _selectedDate = restored.selectedDate;
      _selectedCourseCode = restored.selectedCourseCode;
      _selectedLectureKeys
        ..clear()
        ..addAll(restored.selectedLectureKeys);
      _isLoadingLectures = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyFilters();
        unawaited(_refreshLecturesInBackground());
      });
      return;
    }

    final cat = ref.read(lecturerUnifiedCatalogProvider).valueOrNull;
    if (cat != null && !cat.isEmpty) {
      _allLectures = cat.toLectureItems(
        isArabic: LecturerLanguageController.isArabic,
      );
      _selectedWeekNumber ??= _currentWeekNumber;
      _isLoadingLectures = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyFilters();
        unawaited(_refreshLecturesInBackground());
      });
      return;
    }

    unawaited(_awaitInitialLectureLoad());
  }

  void _onLecturerLanguageChanged() {
    final cat = ref.read(lecturerUnifiedCatalogProvider).valueOrNull;
    if (cat == null || !mounted) return;
    setState(() {
      _allLectures = cat.toLectureItems(
        isArabic: LecturerLanguageController.isArabic,
      );
    });
  }

  Future<void> _loadLectures({bool forceRefreshCatalog = false}) async {
    if (_allLectures.isEmpty) {
      await _awaitInitialLectureLoad(forceRefreshCatalog: forceRefreshCatalog);
    } else {
      await _refreshLecturesInBackground(
        forceRefreshCatalog: forceRefreshCatalog,
      );
    }
  }

  Future<void> _awaitInitialLectureLoad({
    bool forceRefreshCatalog = false,
  }) async {
    setState(() {
      _isLoadingLectures = true;
      _loadError = null;
    });
    try {
      if (forceRefreshCatalog) {
        ref.invalidate(lecturerUnifiedCatalogProvider);
      }
      await Future.wait<Object?>([
        _calendarRepository.refreshAcademicCalendar().timeout(
          const Duration(seconds: 4),
          onTimeout: () {},
        ),
        ref.read(lecturerUnifiedCatalogProvider.future),
      ]);
      if (!mounted) return;
      final cat = ref.read(lecturerUnifiedCatalogProvider).requireValue;
      final list = cat.toLectureItems(
        isArabic: LecturerLanguageController.isArabic,
      );
      setState(() {
        _allLectures = list;
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

  Future<void> _refreshLecturesInBackground({
    bool forceRefreshCatalog = false,
  }) async {
    if (_bgRefreshing) return;
    _bgRefreshing = true;
    if (mounted) setState(() {});
    try {
      if (forceRefreshCatalog) {
        ref.invalidate(lecturerUnifiedCatalogProvider);
      }
      await Future.wait<Object?>([
        _calendarRepository.refreshAcademicCalendar().timeout(
          const Duration(seconds: 4),
          onTimeout: () {},
        ),
        ref.read(lecturerUnifiedCatalogProvider.future),
      ]);
      if (!mounted) return;
      final cat = ref.read(lecturerUnifiedCatalogProvider).requireValue;
      final list = cat.toLectureItems(
        isArabic: LecturerLanguageController.isArabic,
      );
      setState(() {
        _allLectures = list;
        _loadError = null;
        _applyFilters();
      });
    } catch (e) {
      if (!mounted) return;
      if (_allLectures.isEmpty) {
        setState(() => _loadError = e.toString());
      }
    } finally {
      _bgRefreshing = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _handleRealtimeCalendarChange() async {
    if (!mounted || _isSyncRefreshing) return;
    _isSyncRefreshing = true;
    try {
      await _calendarRepository.refreshAcademicCalendar().timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
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

  void _onManageWeekChanged(int? week) {
    setState(() {
      _selectedWeekNumber = week;
      _selectedDate = null;
      _selectedLectureKeys.clear();
      _applyFilters();
    });
  }

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  int get _currentWeekNumber => _calendarRepository.getOfficialWeekNumber(
        _calendarRepository.currentDateTime,
      );
  int get _maxSelectableWeeks =>
      _calendarRepository.manageLecturesWeekUpperBound;

  int? _getTargetWeekday() {
    final selected = _selectedLectures;
    if (selected.isNotEmpty) return selected.first.dayOfWeek;
    return _selectedDate?.weekday;
  }

  DateTime _getReferenceDate() =>
      _selectedDate ?? _calendarRepository.currentDateTime;

  DateTime? _dateForLectureInSelectedWeek(LectureItem lecture) {
    if (_selectedWeekNumber == null) return null;
    return _calendarRepository.dateForOfficialWeekAndWeekday(
      _selectedWeekNumber!,
      lecture.dayOfWeek,
    );
  }

  DateTime? _lectureCalendarDate(LectureItem lecture) {
    return _selectedDate ?? _dateForLectureInSelectedWeek(lecture);
  }

  /// Manageable when inside the active term, not excluded, and not yet ended.
  bool _isManageableLectureOnDate(
    LectureItem lecture,
    DateTime lectureDate, {
    DateTime? now,
  }) {
    if (!_calendarRepository.isWithinActiveTerm(lectureDate)) return false;
    if (_calendarRepository.isScheduledLecturesExcluded(lectureDate)) {
      return false;
    }
    return LectureActionEligibility.isLectureItemActionable(
      lecture: lecture,
      lectureDate: lectureDate,
      now: now ?? _calendarRepository.currentDateTime,
    );
  }

  /// True when the lecture end datetime is not after now (not actionable).
  bool _isLectureEnded(LectureItem lecture) {
    final lectureDate = _lectureCalendarDate(lecture);
    if (lectureDate == null) return true;
    return !_isManageableLectureOnDate(lecture, lectureDate);
  }

  String get _lectureExpiredMessage => _tr(
        LectureActionEligibility.messageAr,
        LectureActionEligibility.messageEn,
      );

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

    final now = _calendarRepository.currentDateTime;
    return list.where((lecture) {
      final date = _dateForLectureInSelectedWeek(lecture);
      if (date == null) return false;
      return _isManageableLectureOnDate(lecture, date, now: now);
    }).toList();
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
    if (_ensureValidSelectedWeek() && mounted) {
      setState(() {});
    }
    unawaited(_refreshLectureActionStatuses());
  }

  List<LectureItem> _lecturesForCourse(String courseCode) {
    return _allLectures
        .where(
          (l) =>
              _dayOrder.contains(l.dayOfWeek) && l.crn.trim() == courseCode,
        )
        .toList();
  }

  bool _courseHasActionableLectureInWeek(
    String courseCode,
    int weekNumber,
    DateTime now,
  ) {
    for (final lecture in _lecturesForCourse(courseCode)) {
      final date = _calendarRepository.dateForOfficialWeekAndWeekday(
        weekNumber,
        lecture.dayOfWeek,
      );
      if (date == null) continue;
      if (_isManageableLectureOnDate(lecture, date, now: now)) {
        return true;
      }
    }
    return false;
  }

  List<int> _actionableWeeksForSelectedCourse() {
    final courseCode = _selectedCourseCode?.trim();
    if (courseCode == null || courseCode.isEmpty) return const [];

    final now = _calendarRepository.currentDateTime;
    final firstWeek = _currentWeekNumber;
    final weeks = <int>[];
    for (var week = firstWeek; week <= _maxSelectableWeeks; week++) {
      if (_courseHasActionableLectureInWeek(courseCode, week, now)) {
        weeks.add(week);
      }
    }
    return weeks;
  }

  /// Keeps [_selectedWeekNumber] on an actionable week for the selected course.
  bool _ensureValidSelectedWeek() {
    if (!_isCourseSelectedForManage) return false;

    final weeks = _actionableWeeksForSelectedCourse();
    var changed = false;

    if (weeks.isEmpty) {
      if (_selectedWeekNumber != null ||
          _selectedDate != null ||
          _selectedLectureKeys.isNotEmpty) {
        _selectedWeekNumber = null;
        _selectedDate = null;
        _selectedLectureKeys.clear();
        changed = true;
      }
      return changed;
    }

    if (_selectedWeekNumber == null || !weeks.contains(_selectedWeekNumber)) {
      _selectedWeekNumber = weeks.first;
      _selectedDate = null;
      _selectedLectureKeys.clear();
      changed = true;
    }
    return changed;
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

  bool _canManageSelectedLectures(List<LectureItem> lectures) {
    if (lectures.isEmpty) return false;
    return lectures.every((l) => !_isLectureEnded(l));
  }

  Future<void> _openLectureActionsForSelection() async {
    final selected = _selectedLectures;
    if (selected.isEmpty || _selectedDate == null) return;

    if (!_canManageSelectedLectures(selected)) {
      _showActionSnack(_lectureExpiredMessage, error: true);
      return;
    }

    final multi = selected.length > 1;
    final primary = selected.first;
    final primaryStatus = _statusForLecture(primary);
    final selectionEnded = selected.any(_isLectureEnded);

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
                isEnded: multi ? selectionEnded : _isLectureEnded(primary),
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
        _showActionSnack(_lectureExpiredMessage, error: true);
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
      _showActionSnack(_lectureExpiredMessage, error: true);
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
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: ModernPopupDialog(
            title: Text(
              _tr('مدة التأخير', 'Delay duration'),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                color: _primary,
              ),
            ),
            accentColor: _primary,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: _tr('عدد الدقائق', 'Minutes'),
              ),
            ),
            actions: [
              ModernPopupActionButton(
                label: _tr('إلغاء', 'Cancel'),
                onTap: () => Navigator.of(dialogContext).pop(),
                isPrimary: false,
              ),
              ModernPopupActionButton(
                label: _tr('تأكيد', 'Confirm'),
                onTap: () => Navigator.of(
                  dialogContext,
                ).pop(int.tryParse(controller.text.trim())),
                isPrimary: true,
                primaryColor: _primary,
              ),
            ],
          ),
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
      case LectureActionBlockReason.lectureExpired:
        return _lectureExpiredMessage;
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
      builder: (ctx) => Directionality(
        textDirection: LecturerLanguageController.direction(),
        child: ModernPopupDialog(
          accentColor: _primary,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, size: 28, color: _primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _tr(
                    'تم إرسال التأخير وإشعار الطلاب',
                    'Delay sent and students notified',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                lecture.courseName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF222222),
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_tr('وقت المحاضرة المحدث', 'Updated time')}: $newTimeDisplay',
                style: TextStyle(
                  fontSize: 13.5,
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
            ],
          ),
          actions: [
            ModernPopupActionButton(
              label: _tr('حسناً', 'OK'),
              onTap: () => Navigator.pop(ctx),
              isPrimary: true,
              primaryColor: _primary,
            ),
          ],
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
      builder: (ctx) => Directionality(
        textDirection: LecturerLanguageController.direction(),
        child: ModernPopupDialog(
          accentColor: _cancelRed,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, size: 28, color: _cancelRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _tr(
                    'تم إرسال الإلغاء وإشعار الطلاب',
                    'Cancellation sent and students notified',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF222222),
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                lecture.courseName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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
            ],
          ),
          actions: [
            ModernPopupActionButton(
              label: _tr('حسناً', 'OK'),
              onTap: () => Navigator.pop(ctx),
              isPrimary: true,
              primaryColor: _cancelRed,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UnifiedLecturerCatalog>>(
      lecturerUnifiedCatalogProvider,
      (prev, next) {
        next.whenData((cat) {
          if (!mounted) return;
          setState(() {
            _allLectures = cat.toLectureItems(
              isArabic: LecturerLanguageController.isArabic,
            );
            _applyFilters();
          });
        });
      },
    );
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, _, __) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FBFB),
            body: SafeArea(
              child: (_isLoadingLectures && _allLectures.isEmpty)
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
                              onPressed: () =>
                                  _loadLectures(forceRefreshCatalog: true),
                              icon: const Icon(Icons.refresh),
                              label: Text(_tr('إعادة المحاولة', 'Retry')),
                            ),
                          ],
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_isLoadingLectures || _bgRefreshing)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 10),
                                  child: LinearProgressIndicator(
                                    minHeight: 3,
                                    color: Color(0xFF006571),
                                    backgroundColor: Color(0xFFE6F1F2),
                                  ),
                                ),
                              _buildPageTopBar(),
                              const SizedBox(height: 12),
                              _buildManageHeroCard(),
                              const SizedBox(height: 12),
                              _buildSelectionPanel(),
                              const SizedBox(height: 10),
                              _buildManageSelectionStateBanner(),
                              const SizedBox(height: 10),
                              _buildContent(),
                              const SizedBox(height: 10),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageTopBar() {
    const backSlotSize = 38.0;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ProfileBackButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: backSlotSize + 8),
                child: Text(
                  _tr('إدارة المحاضرات', 'Manage Lectures'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF213236),
                    height: 1.25,
                  ),
                ),
              ),
            ),
            const Align(
              alignment: AlignmentDirectional.centerEnd,
              child: SizedBox(width: backSlotSize, height: backSlotSize),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManageHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B8793), Color(0xFF005B66)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.23),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.settings_suggest_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _tr(
                'اختيار المقرر والأسبوع ثم تنفيذ إجراء المحاضرة',
                'Choose course and week, then apply lecture action',
              ),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionPanel() {
    final courses = _courseOptionsForDate;
    final actionableWeeks = _isCourseSelectedForManage
        ? _actionableWeeksForSelectedCourse()
        : const <int>[];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD9E8EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B8793), Color(0xFF066A75)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune_rounded, color: Colors.white, size: 17),
                const SizedBox(width: 6),
                Text(
                  _tr('فلترة الإدارة', 'Management Filters'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12.6,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildManageFilterSectionTitle(
            icon: Icons.auto_stories_rounded,
            title: _tr('المقرر', 'Course'),
            hint: _tr('اختيار المقرر أولاً', 'Choose course first'),
          ),
          const SizedBox(height: 8),
          if (courses.isEmpty)
            _buildManageInlineFilterHint(
              _tr('لا توجد مقررات متاحة حالياً.', 'No courses available now.'),
            )
          else
            _buildManageCourseDropdown(courses),
          const SizedBox(height: 12),
          _buildManageFilterSectionTitle(
            icon: Icons.view_week_rounded,
            title: _tr('الأسبوع', 'Week'),
            hint: _tr('اختيار سريع بدون كروت', 'Compact dropdown selector'),
          ),
          const SizedBox(height: 8),
          if (!_isCourseSelectedForManage)
            _buildManageInlineFilterHint(
              _tr(
                'يرجى اختيار المقرر أولاً حتى تظهر الأسابيع.',
                'Please select a course first to show weeks.',
              ),
            )
          else if (actionableWeeks.isEmpty)
            _buildManageInlineFilterHint(
              _tr(
                LectureActionEligibility.noUpcomingManageableAr,
                LectureActionEligibility.noUpcomingManageableEn,
              ),
            )
          else
            _buildManageWeekDropdown(actionableWeeks),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedCourseCode = null;
                  _selectedWeekNumber = null;
                  _selectedDate = null;
                  _selectedLectureKeys.clear();
                  _applyFilters();
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(_tr('إعادة ضبط الفلتر', 'Reset filters')),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF5A757C),
                textStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManageFilterSectionTitle({
    required IconData icon,
    required String title,
    String? hint,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4F5),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: _primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13.2,
            fontWeight: FontWeight.w800,
            color: Color(0xFF24484F),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.2,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B8389),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildManageInlineFilterHint(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE8EA)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11.8,
          color: Color(0xFF698188),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  bool get _isCourseSelectedForManage =>
      _selectedCourseCode != null && _selectedCourseCode!.trim().isNotEmpty;

  Widget _buildManageCourseDropdown(
    List<({String code, String name})> courses,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E5E8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: _selectedCourseCode,
          hint: Text(_tr('اختر المقرر', 'Select course')),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF006571),
          ),
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          menuMaxHeight: 320,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2B4B52),
          ),
          items: courses
              .map(
                (course) => DropdownMenuItem<String?>(
                  value: course.code,
                  child: Text(
                    '${course.name} (${course.code})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (courseCode) {
            setState(() {
              _selectedCourseCode = courseCode;
              _selectedWeekNumber = null;
              _selectedDate = null;
              _selectedLectureKeys.clear();
            });
            _applyFilters();
          },
        ),
      ),
    );
  }

  Widget _buildManageWeekDropdown(List<int> weeks) {
    if (weeks.isEmpty) return const SizedBox.shrink();
    final selected = _selectedWeekNumber ?? weeks.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD6E5E8)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: weeks.contains(selected) ? selected : weeks.first,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF006571),
          ),
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Colors.white,
          menuMaxHeight: 300,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2B4B52),
          ),
          items: weeks
              .map(
                (week) => DropdownMenuItem<int>(
                  value: week,
                  child: Text(_tr('الأسبوع $week', 'Week $week')),
                ),
              )
              .toList(),
          onChanged: (week) {
            if (week == null) return;
            _onManageWeekChanged(week);
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (!_hasDateAndCourseSelection) {
      return const SizedBox.shrink();
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
    final canManage =
        !_isPastSelectedDate && _canManageSelectedLectures(selectedLectures);
    final selectedExpired =
        selectedLectures.isNotEmpty &&
        selectedLectures.any((l) => _isLectureEnded(l));
    final selectedCanceled =
        selectedLectures.isNotEmpty &&
        selectedLectures.every((l) => _statusForLecture(l).isCanceled);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        if (!canManage && (selectedExpired || _isPastSelectedDate))
          Text(
            selectedExpired
                ? _lectureExpiredMessage
                : _tr('لا يمكن إدارة محاضرة سابقة', 'Cannot manage a past lecture'),
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
              onPressed: selectedCanceled || selectedExpired
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

  Widget _buildManageSelectionStateBanner() {
    String message;
    Color bg = const Color(0xFFF3F7F8);
    Color border = const Color(0xFFD8E4E7);
    Color text = const Color(0xFF455D63);
    IconData icon = Icons.info_outline_rounded;

    if (!_isCourseSelectedForManage) {
      message = _tr(
        'يرجى اختيار المقرر أولاً.',
        'Please select the course first.',
      );
    } else if (_selectedWeekNumber == null) {
      message = _tr(
        'يرجى اختيار الأسبوع الدراسي بعد اختيار المقرر.',
        'Select the academic week after choosing the course.',
      );
      icon = Icons.view_week_rounded;
    } else if (_selectedLectureKeys.isEmpty) {
      message = _tr(
        'يرجى اختيار محاضرة من كروت الأسبوع لبدء الإدارة.',
        'Select a lecture card from the week to start management.',
      );
      icon = Icons.library_books_rounded;
    } else {
      message = _tr(
        'جاهز للتنفيذ: يمكنك إرسال تأخير أو إلغاء للمحاضرة المحددة.',
        'Ready: you can send delay or cancellation for the selected lecture.',
      );
      bg = const Color(0xFFEAF7EF);
      border = const Color(0xFFCBE8D2);
      text = const Color(0xFF24643A);
      icon = Icons.check_circle_outline_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

    final mainTitle = lecture.courseName.trim().isNotEmpty
        ? lecture.courseName.trim()
        : '${_tr('الشعبة', 'Section')} ${lecture.section}';
    final subTitle = '$dayLabel • $timeRange';

    return Material(
      color: Colors.transparent,
      child: InkWell(
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
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEAF7F8) : actionSoftBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0B7D88)
                  : const Color(0xFFDCE7E9),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSelected
                            ? const [Color(0xFF0B8793), Color(0xFF076772)]
                            : const [Color(0xFFCFE4E7), Color(0xFFC2DCE0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mainTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13.1,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? const Color(0xFF15414A)
                                : const Color(0xFF2E4348),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.3,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? const Color(0xFF2A5C65)
                                : const Color(0xFF627B82),
                          ),
                        ),
                        const SizedBox(height: 4),
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
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? const Color(0xFF2A5C65)
                              : const Color(0xFF769097),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: isSelected
                            ? const Color(0xFF006571)
                            : const Color(0xFF8AA0A6),
                      ),
                      const SizedBox(height: 6),
                      _buildSectionSelectionStatusChip(status),
                    ],
                  ),
                ],
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
              if (actionStatus.isCanceled || actionStatus.isDelayed) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
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
            ],
          ),
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
                text: widget.tr(
                  LectureActionEligibility.messageAr,
                  LectureActionEligibility.messageEn,
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
            LectureActionEligibility.messageAr,
            LectureActionEligibility.messageEn,
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
                      'يرجى اختيار مدة تأخير صحيحة',
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
            LectureActionEligibility.messageAr,
            LectureActionEligibility.messageEn,
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
