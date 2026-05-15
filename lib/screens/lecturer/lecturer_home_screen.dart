import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lecturer_catalog_providers.dart';
import '../student/components/notification_bell.dart';
import 'lecturer_notifications_screen.dart';
import 'lecturer_language.dart';
import '../../widgets/monthly_calendar.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../models/lecturer/unified_lecturer_catalog.dart';
import '../../models/calendar_day.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../services/lecturer/calendar_service.dart';
import '../../services/lecturer/calendar_sync_service.dart';
import '../../services/lecturer/filter_service.dart';
import '../../services/notifications/lecture_action_notification_service.dart';
import '../../widgets/lecturer/lecturer_home_header.dart';
import '../../widgets/lecturer/lecture_card.dart';
import '../../widgets/lecturer/day_tap_handler.dart';
import 'lecturer_navigation.dart';
import '../../utils/shared/time_utils.dart';
import 'widgets/modern_popup_dialog.dart';

class LecturerHomeScreen extends ConsumerStatefulWidget {
  const LecturerHomeScreen({super.key, this.lecturerName});

  final String? lecturerName;

  @override
  ConsumerState<LecturerHomeScreen> createState() => _LecturerHomeScreenState();
}

class _LecturerHomeScreenState extends ConsumerState<LecturerHomeScreen> {
  final LectureRepository _repository = LectureRepository();
  final LectureActionNotificationService _lectureActionService =
      LectureActionNotificationService.instance;
  late final CalendarService _calendarService;
  late final DayTapHandler _dayTapHandler;

  bool _isLoadingCalendar = false;
  String? _calendarLoadError;
  DateTime _currentCalendarMonth = DateTime.now();

  StreamSubscription<void>? _calendarSyncSub;
  bool _isSyncRefreshing = false;
  bool _isDispatchingLectureAction = false;

  /// Last non-empty catalog lectures (survives provider reload / invalidate).
  List<LectureItem> _lastNonEmptyCatalogLectures = <LectureItem>[];

  @override
  void initState() {
    super.initState();
    _calendarService = CalendarService(_repository);
    _dayTapHandler = DayTapHandler(repository: _repository);
    _calendarSyncSub = CalendarSyncService.instance.watchChanges().listen(
      (_) => _handleRealtimeCalendarChange(),
    );
    // Render immediately; refresh calendar metadata in background.
    unawaited(_loadCalendarOnly());
  }

  @override
  void dispose() {
    _calendarSyncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCalendarOnly() async {
    final showCalendarProgress = _calendarLoadError != null || _isLoadingCalendar;
    if (showCalendarProgress) {
      setState(() {
        _isLoadingCalendar = true;
        _calendarLoadError = null;
      });
    } else {
      setState(() => _calendarLoadError = null);
    }
    try {
      await _repository.refreshAcademicCalendar().timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
      if (!mounted) return;
      setState(() {
        _currentCalendarMonth = DateTime(
          _repository.currentDateTime.year,
          _repository.currentDateTime.month,
          1,
        );
        _isLoadingCalendar = false;
        _calendarLoadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingCalendar = false;
        _calendarLoadError = e.toString();
      });
    }
  }

  Future<void> _handleRealtimeCalendarChange() async {
    if (!mounted || _isSyncRefreshing) return;
    _isSyncRefreshing = true;
    try {
      await _repository.refreshAcademicCalendar().timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
      if (!mounted) return;
      setState(() {
        _currentCalendarMonth = DateTime(
          _repository.currentDateTime.year,
          _repository.currentDateTime.month,
          1,
        );
      });
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

  List<LectureItem> _todayLectures(List<LectureItem> all) {
    return FilterService.filterLectures(
      all,
      'اليوم',
      baseDate: _repository.currentDateTime,
    );
  }

  List<LectureItem> _tomorrowLectures(List<LectureItem> all) {
    final tomorrow = _normalizedTomorrow();
    if (_repository.isHoliday(tomorrow)) return [];
    return FilterService.filterLectures(
      all,
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
          child: ModernPopupDialog(
            accentColor: const Color(0xFF006571),
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
            actions: [
              ModernPopupActionButton(
                label: LecturerLanguageController.tr('إلغاء', 'Cancel'),
                onTap: () => Navigator.of(ctx).pop(),
                isPrimary: false,
              ),
            ],
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((m) {
                return OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(m),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF006571),
                    side: const BorderSide(color: Color(0xFF006571)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    LecturerLanguageController.tr('$m دقيقة', '$m min'),
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                );
              }).toList(),
            ),
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
        child: ModernPopupDialog(
          accentColor: const Color(0xFFD32F2F),
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
          actions: [
            ModernPopupActionButton(
              label: LecturerLanguageController.tr('تراجع', 'Back'),
              onTap: () => Navigator.of(ctx).pop(false),
              isPrimary: false,
            ),
            ModernPopupActionButton(
              label: LecturerLanguageController.tr('تأكيد', 'Confirm'),
              onTap: () => Navigator.of(ctx).pop(true),
              isPrimary: true,
              primaryColor: const Color(0xFFD32F2F),
            ),
          ],
          child: Text(
            LecturerLanguageController.tr(
              'سيتم إشعار الطلاب بإلغاء هذه المحاضرة. هل تريد المتابعة؟',
              'Students will be notified that this lecture is canceled. Continue?',
            ),
            style: const TextStyle(fontFamily: 'Cairo', height: 1.45),
          ),
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

  void _handleDayTap(CalendarDay day, List<LectureItem> allLectures) {
    _dayTapHandler.handleDayTap(context, day, allLectures);
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
    final sortedLectures = TimeUtils.sortLecturesByTime(
      lectures,
      (lecture) => lecture.startTime,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(titleAr, titleEn),
        if (sortedLectures.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                LecturerLanguageController.tr(
                  'لا توجد محاضرات',
                  'No lectures available',
                ),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF999999),
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 292,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: sortedLectures.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final lecture = sortedLectures[index];
                final timeLabel = lecture.timeSlots.isNotEmpty
                    ? lecture.timeSlots.join('  •  ')
                    : lecture.startTime;
                return SizedBox(
                  width: 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            timeLabel,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF006571),
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: LectureCard(
                          lecture: lecture,
                          onTap: onAttendTap != null
                              ? () => onAttendTap(lecture)
                              : null,
                          onDelayTap: () => _onDelayLectureFromCard(
                            lecture,
                            actionDateResolver(lecture),
                          ),
                          onCancelTap: () => _onCancelLectureFromCard(
                            lecture,
                            actionDateResolver(lecture),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildAllCalendarSection(List<LectureItem> allLectures) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('تقويم المحاضرات', 'Lectures Calendar'),
        MonthlyCalendar(
          currentMonth: _currentCalendarMonth,
          calendarDays: _calendarService.buildCalendarDays(
            _currentCalendarMonth,
            allLectures,
          ),
          onDayTap: (day) => _handleDayTap(day, allLectures),
          onMonthChanged: _handleMonthChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UnifiedLecturerCatalog>>(
      lecturerUnifiedCatalogProvider,
      (prev, next) {
        next.whenData((cat) {
          if (!mounted) return;
          final isArabic = LecturerLanguageController.isArabic;
          final items = cat.toLectureItems(isArabic: isArabic);
          if (items.isNotEmpty) {
            setState(() => _lastNonEmptyCatalogLectures = items);
          }
        });
      },
    );
    final catalogAsync = ref.watch(lecturerUnifiedCatalogProvider);
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, lang, __) {
        final isArabic = lang == LecturerLanguage.arabic;
        final fromState = catalogAsync.maybeWhen(
          data: (c) => c.toLectureItems(isArabic: isArabic),
          orElse: () => <LectureItem>[],
        );
        final cached = catalogAsync.valueOrNull;
        final fromCachedValue = (cached != null && !cached.isEmpty)
            ? cached.toLectureItems(isArabic: isArabic)
            : <LectureItem>[];
        final allLectures = fromState.isNotEmpty
            ? fromState
            : (fromCachedValue.isNotEmpty
                ? fromCachedValue
                : _lastNonEmptyCatalogLectures);
        final catalogLoading = catalogAsync.isLoading;
        final catalogErr = catalogAsync.hasError ? catalogAsync.error : null;
        final blockFullScreenSpinner =
            catalogLoading && allLectures.isEmpty && !catalogAsync.hasValue;

        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: blockFullScreenSpinner
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          color: Color(0xFF006571),
                        ),
                      ),
                    )
                  : catalogErr != null && allLectures.isEmpty
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
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () => ref.invalidate(
                                lecturerUnifiedCatalogProvider,
                              ),
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
                        if (catalogLoading && allLectures.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              color: Color(0xFF006571),
                              backgroundColor: Color(0xFFE6F1F2),
                            ),
                          ),
                        if (_isLoadingCalendar)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              color: Color(0xFF006571),
                              backgroundColor: Color(0xFFE6F1F2),
                            ),
                          ),
                        if (_calendarLoadError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    LecturerLanguageController.tr(
                                      'تعذر تحديث التقويم الآن.',
                                      'Calendar refresh failed.',
                                    ),
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loadCalendarOnly,
                                  child: Text(
                                    LecturerLanguageController.tr(
                                      'إعادة المحاولة',
                                      'Retry',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                          lectures: _todayLectures(allLectures),
                          actionDateResolver: (_) => _normalizedToday(),
                          onAttendTap: _openAttendanceForToday,
                        ),
                        const SizedBox(height: 30),
                        _buildLectureSection(
                          titleAr: 'محاضرات الغد',
                          titleEn: "Tomorrow's Lectures",
                          lectures: _tomorrowLectures(allLectures),
                          actionDateResolver: (_) => _normalizedTomorrow(),
                          onAttendTap: _openAttendanceForTomorrowViewOnly,
                        ),
                        const SizedBox(height: 30),
                        _buildAllCalendarSection(allLectures),
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
