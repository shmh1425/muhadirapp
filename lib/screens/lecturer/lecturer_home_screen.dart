import 'dart:async';

import 'package:flutter/material.dart';
import '../student/components/notification_bell.dart';
import 'lecturer_notifications_screen.dart';
import 'lecturer_language.dart';
import '../../widgets/monthly_calendar.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../models/calendar_day.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../services/lecturer/calendar_service.dart';
import '../../services/lecturer/calendar_sync_service.dart';
import '../../services/lecturer/filter_service.dart';
import '../../services/lecturer/lecturer_sections_service.dart';
import '../../services/notifications/lecture_action_notification_service.dart';
import '../../widgets/lecturer/lecturer_home_header.dart';
import '../../widgets/lecturer/lecture_timeline.dart';
import '../../widgets/lecturer/day_tap_handler.dart';
import 'lecturer_navigation.dart';

class LecturerHomeScreen extends StatefulWidget {
  const LecturerHomeScreen({super.key, this.lecturerName});

  final String? lecturerName;

  @override
  State<LecturerHomeScreen> createState() => _LecturerHomeScreenState();
}

class _LecturerHomeScreenState extends State<LecturerHomeScreen> {
  final LectureRepository _repository = LectureRepository();
  final LectureActionNotificationService _lectureActionService =
      LectureActionNotificationService.instance;
  late final CalendarService _calendarService;
  late final DayTapHandler _dayTapHandler;

  List<LectureItem> _allLectures = [];
  bool _isLoadingLectures = true;
  String? _loadError;
  DateTime _currentCalendarMonth = DateTime.now();

  StreamSubscription<void>? _calendarSyncSub;
  bool _isSyncRefreshing = false;
  bool _isDispatchingLectureAction = false;

  @override
  void initState() {
    super.initState();
    _calendarService = CalendarService(_repository);
    _dayTapHandler = DayTapHandler(repository: _repository);
    _calendarSyncSub = CalendarSyncService.instance.watchChanges().listen(
      (_) => _handleRealtimeCalendarChange(),
    );
    _loadHomeData();
  }

  @override
  void dispose() {
    _calendarSyncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoadingLectures = true;
      _loadError = null;
    });
    try {
      await _repository.refreshAcademicCalendar();
      final list = await LecturerSectionsService.instance
          .getLecturesForCurrentLecturer();
      if (!mounted) return;
      setState(() {
        _allLectures = list;
        _currentCalendarMonth = DateTime(
          _repository.currentDateTime.year,
          _repository.currentDateTime.month,
          1,
        );
        _isLoadingLectures = false;
        _loadError = null;
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
      await _loadHomeData();
    } finally {
      _isSyncRefreshing = false;
    }
  }

  DateTime _normalizedToday() {
    final now = _repository.currentDateTime;
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _normalizedTomorrow() {
    final tomorrow = _normalizedToday().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
  }

  List<LectureItem> _todayLectures() {
    return FilterService.filterLectures(
      _allLectures,
      'اليوم',
      baseDate: _repository.currentDateTime,
    );
  }

  List<LectureItem> _tomorrowLectures() {
    final tomorrow = _normalizedTomorrow();
    if (_repository.isHoliday(tomorrow)) return [];
    return FilterService.filterLectures(
      _allLectures,
      'غدًا',
      baseDate: _repository.currentDateTime,
    );
  }

  void _openAttendanceForToday(LectureItem lecture) {
    LecturerNavigation.goToAttendance(
      context,
      lecture,
      selectedDate: _normalizedToday(),
    );
  }

  void _openAttendanceForTomorrowViewOnly(LectureItem lecture) {
    LecturerNavigation.goToAttendanceViewOnly(
      context,
      lecture,
      _normalizedTomorrow(),
    );
  }

  String _mapBlockedActionMessage(LectureActionBlockReason reason) {
    switch (reason) {
      case LectureActionBlockReason.alreadyDelayed:
        return LecturerLanguageController.tr(
          'تم إرسال هذا الإجراء مسبقًا',
          'This action was already sent',
        );
      case LectureActionBlockReason.alreadyCanceled:
        return LecturerLanguageController.tr(
          'هذه المحاضرة ملغية بالفعل',
          'This lecture is already canceled',
        );
      case LectureActionBlockReason.canceledCannotDelay:
        return LecturerLanguageController.tr(
          'لا يمكن تأخير محاضرة ملغية',
          'Cannot delay a canceled lecture',
        );
    }
  }

  void _showActionSnack(
    String message, {
    bool error = false,
    bool warning = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error
            ? const Color(0xFFD32F2F)
            : (warning ? const Color(0xFFE6A700) : const Color(0xFF2B9E56)),
      ),
    );
  }

  Future<int?> _pickDelayMinutes() async {
    return showDialog<int>(
      context: context,
      builder: (ctx) {
        final options = [5, 10, 15, 20, 30];
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: AlertDialog(
            title: Text(
              LecturerLanguageController.tr(
                'اختيار مدة التأخير',
                'Delay Duration',
              ),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map(
                    (m) => OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(m),
                      child: Text(
                        LecturerLanguageController.tr('$m دقيقة', '$m min'),
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  )
                  .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  LecturerLanguageController.tr('إلغاء', 'Cancel'),
                  style: const TextStyle(fontFamily: 'Cairo'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onDelayLectureFromCard(
    LectureItem lecture,
    DateTime lectureDate,
  ) async {
    if (_isDispatchingLectureAction) return;
    final minutes = await _pickDelayMinutes();
    if (minutes == null || minutes <= 0) return;
    setState(() => _isDispatchingLectureAction = true);
    try {
      final result = await _lectureActionService.sendDelayNotification(
        lecture: lecture,
        delayMinutes: minutes,
        lectureDayOfWeek: lecture.dayOfWeek,
        lectureDate: lectureDate,
      );
      _showActionSnack(
        LecturerLanguageController.tr(
          'تم إرسال إشعار التأخير لـ ${result.recipientCount} طالب/ـة',
          'Delay notification sent to ${result.recipientCount} students',
        ),
      );
    } on LectureActionBlockedException catch (e) {
      _showActionSnack(_mapBlockedActionMessage(e.reason), error: true);
    } on LectureActionPartialFailureException {
      _showActionSnack(
        LecturerLanguageController.tr(
          'تم تسجيل التأخير لكن بعض الإشعارات لم تُرسل.',
          'Delay recorded, but some notifications failed.',
        ),
        warning: true,
      );
    } catch (_) {
      _showActionSnack(
        LecturerLanguageController.tr(
          'تعذر إرسال إشعار التأخير الآن.',
          'Unable to send delay notification now.',
        ),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _isDispatchingLectureAction = false);
    }
  }

  Future<void> _onCancelLectureFromCard(
    LectureItem lecture,
    DateTime lectureDate,
  ) async {
    if (_isDispatchingLectureAction) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: LecturerLanguageController.direction(),
        child: AlertDialog(
          title: Text(
            LecturerLanguageController.tr(
              'تأكيد إلغاء المحاضرة',
              'Confirm Cancellation',
            ),
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            LecturerLanguageController.tr(
              'سيتم إشعار الطلاب بإلغاء هذه المحاضرة. هل تريد المتابعة؟',
              'Students will be notified that this lecture is canceled. Continue?',
            ),
            style: const TextStyle(fontFamily: 'Cairo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                LecturerLanguageController.tr('تراجع', 'Back'),
                style: const TextStyle(fontFamily: 'Cairo'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                LecturerLanguageController.tr('تأكيد', 'Confirm'),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  color: Color(0xFFD32F2F),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDispatchingLectureAction = true);
    try {
      final result = await _lectureActionService.sendCancellationNotification(
        lecture: lecture,
        lectureDayOfWeek: lecture.dayOfWeek,
        lectureDate: lectureDate,
      );
      _showActionSnack(
        LecturerLanguageController.tr(
          'تم إرسال إشعار الإلغاء لـ ${result.recipientCount} طالب/ـة',
          'Cancellation sent to ${result.recipientCount} students',
        ),
      );
    } on LectureActionBlockedException catch (e) {
      _showActionSnack(_mapBlockedActionMessage(e.reason), error: true);
    } on LectureActionPartialFailureException {
      _showActionSnack(
        LecturerLanguageController.tr(
          'تم تسجيل الإلغاء لكن بعض الإشعارات لم تُرسل.',
          'Cancellation recorded, but some notifications failed.',
        ),
        warning: true,
      );
    } catch (_) {
      _showActionSnack(
        LecturerLanguageController.tr(
          'تعذر إرسال إشعار الإلغاء الآن.',
          'Unable to send cancellation notification now.',
        ),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _isDispatchingLectureAction = false);
    }
  }

  void _handleDayTap(CalendarDay day) {
    _dayTapHandler.handleDayTap(context, day, _allLectures);
  }

  void _handleMonthChanged(DateTime newMonth) {
    setState(() {
      _currentCalendarMonth = newMonth;
    });
  }

  Widget _buildSectionTitle(String ar, String en) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        LecturerLanguageController.tr(ar, en),
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF222222),
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  Widget _buildLectureSection({
    required String titleAr,
    required String titleEn,
    required List<LectureItem> lectures,
    required DateTime Function(LectureItem lecture) actionDateResolver,
    void Function(LectureItem lecture)? onAttendTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(titleAr, titleEn),
        LectureTimeline(
          lectures: lectures,
          onLectureTap: onAttendTap,
          onDelayLectureTap: (lecture) =>
              _onDelayLectureFromCard(lecture, actionDateResolver(lecture)),
          onCancelLectureTap: (lecture) =>
              _onCancelLectureFromCard(lecture, actionDateResolver(lecture)),
        ),
      ],
    );
  }

  Widget _buildAllCalendarSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('تقويم المحاضرات', 'Lectures Calendar'),
        MonthlyCalendar(
          currentMonth: _currentCalendarMonth,
          calendarDays: _calendarService.buildCalendarDays(
            _currentCalendarMonth,
            _allLectures,
          ),
          onDayTap: _handleDayTap,
          onMonthChanged: _handleMonthChanged,
        ),
      ],
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
            backgroundColor: Colors.white,
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
                              LecturerLanguageController.tr(
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
                              onPressed: _loadHomeData,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                LecturerLanguageController.tr(
                                  'إعادة المحاولة',
                                  'Retry',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: LecturerHomeHeader(
                                selectedFilter: 'اليوم',
                                referenceDateTime: _repository.currentDateTime,
                                lecturerName: widget.lecturerName,
                              ),
                            ),
                            NotificationBell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const LecturerNotificationsScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildLectureSection(
                          titleAr: 'محاضرات اليوم',
                          titleEn: "Today's Lectures",
                          lectures: _todayLectures(),
                          actionDateResolver: (_) => _normalizedToday(),
                          onAttendTap: _openAttendanceForToday,
                        ),
                        const SizedBox(height: 30),
                        _buildLectureSection(
                          titleAr: 'محاضرات الغد',
                          titleEn: "Tomorrow's Lectures",
                          lectures: _tomorrowLectures(),
                          actionDateResolver: (_) => _normalizedTomorrow(),
                          onAttendTap: _openAttendanceForTomorrowViewOnly,
                        ),
                        const SizedBox(height: 30),
                        _buildAllCalendarSection(),
                        const SizedBox(height: 20),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
