import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/calendar_day.dart';
import '../../models/attendance/nfc_attendance_session.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../models/lecturer/unified_lecturer_catalog.dart';
import '../../providers/lecturer_catalog_providers.dart';
import '../../services/attendance/attendance_status_policy.dart';
import '../../services/attendance/manual_attendance_service.dart';
import '../../services/attendance/nfc_attendance_service.dart';
import '../../services/lecturer/calendar_service.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../widgets/monthly_calendar.dart';
import 'lecturer_language.dart';
import 'widgets/profile_back_button.dart';

class LecturerNfcSessionManagementScreen extends ConsumerStatefulWidget {
  const LecturerNfcSessionManagementScreen({super.key});

  @override
  ConsumerState<LecturerNfcSessionManagementScreen> createState() =>
      _LecturerNfcSessionManagementScreenState();
}

class _LecturerNfcSessionManagementScreenState
    extends ConsumerState<LecturerNfcSessionManagementScreen> {
  static const Color _primary = Color(0xFF006571);
  static const Color _danger = Color(0xFFD32F2F);

  final LectureRepository _lectureRepository = LectureRepository();
  late final CalendarService _calendarService;
  final NfcAttendanceService _nfcAttendance = NfcAttendanceService.instance;

  List<LectureItem> _allLectures = <LectureItem>[];
  DateTime _selectedDate = DateTime.now();
  DateTime _currentCalendarMonth = DateTime.now();
  int _selectedDayOfWeek = DateTime.now().weekday;
  String? _selectedCourse;

  bool _isLoading = false;
  bool _catalogRefreshing = false;
  String? _loadError;

  String? _lecturerCardId;
  bool _loadingCard = true;

  List<NfcAttendanceSession> _openSessions = <NfcAttendanceSession>[];
  StreamSubscription<List<NfcAttendanceSession>>? _openSessionsSub;

  final Set<String> _openingSessionIds = <String>{};
  final Set<String> _closingSessionIds = <String>{};

  @override
  void initState() {
    super.initState();
    _calendarService = CalendarService(_lectureRepository);
    LecturerLanguageController.notifier.addListener(_onLecturerLanguageChanged);
    final cat = ref.read(lecturerUnifiedCatalogProvider).valueOrNull;
    if (cat != null && !cat.isEmpty) {
      final lectures =
          cat.toLectureItems(isArabic: LecturerLanguageController.isArabic);
      final courseOptions = _extractUniqueCourseNames(lectures);
      _allLectures = lectures;
      final now = DateTime.now();
      _selectedDate = DateTime(now.year, now.month, now.day);
      _selectedDayOfWeek = _selectedDate.weekday;
      _currentCalendarMonth = DateTime(now.year, now.month, 1);
      _selectedCourse = courseOptions.isNotEmpty ? courseOptions.first : null;
    }
    _loadPageData();
    _attachOpenSessionsStream();
  }

  @override
  void dispose() {
    LecturerLanguageController.notifier.removeListener(_onLecturerLanguageChanged);
    _openSessionsSub?.cancel();
    super.dispose();
  }

  void _onLecturerLanguageChanged() {
    final cat = ref.read(lecturerUnifiedCatalogProvider).valueOrNull;
    if (cat == null || !mounted) return;
    final lectures =
        cat.toLectureItems(isArabic: LecturerLanguageController.isArabic);
    final courseOptions = _extractUniqueCourseNames(lectures);
    setState(() {
      _allLectures = lectures;
      if (_selectedCourse != null &&
          !courseOptions.any((n) => n == _selectedCourse)) {
        _selectedCourse =
            courseOptions.isNotEmpty ? courseOptions.first : null;
      }
    });
  }

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  Future<void> _loadPageData() async {
    final hadLectures = _allLectures.isNotEmpty;
    setState(() {
      _loadError = null;
      if (!hadLectures) {
        _isLoading = true;
      }
      _loadingCard = true;
    });

    try {
      if (!hadLectures) {
        final results = await Future.wait<dynamic>([
          _lectureRepository.refreshAcademicCalendar(),
          ref.read(lecturerUnifiedCatalogProvider.future),
          _nfcAttendance.getCurrentLecturerCardId(),
        ]);
        final now = _lectureRepository.currentDateTime;
        final cat = results[1] as UnifiedLecturerCatalog;
        final lectures =
            cat.toLectureItems(isArabic: LecturerLanguageController.isArabic);
        final courseOptions = _extractUniqueCourseNames(lectures);
        final cardId = results[2] as String?;

        if (!mounted) return;
        setState(() {
          _allLectures = lectures;
          _selectedDate = DateTime(now.year, now.month, now.day);
          _selectedDayOfWeek = _selectedDate.weekday;
          _currentCalendarMonth = DateTime(now.year, now.month, 1);
          _selectedCourse =
              courseOptions.isNotEmpty ? courseOptions.first : null;
          _lecturerCardId = cardId;
          _isLoading = false;
          _loadingCard = false;
        });
      } else {
        final cardId = await _nfcAttendance.getCurrentLecturerCardId();
        if (!mounted) return;
        setState(() {
          _lecturerCardId = cardId;
          _loadingCard = false;
        });
        unawaited(_refreshNfcPageCatalogAndCalendar());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadingCard = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _refreshNfcPageCatalogAndCalendar() async {
    if (!mounted) return;
    setState(() => _catalogRefreshing = true);
    try {
      await Future.wait<Object?>([
        _lectureRepository.refreshAcademicCalendar(),
        ref.read(lecturerUnifiedCatalogProvider.future),
      ]);
      if (!mounted) return;
      final now = _lectureRepository.currentDateTime;
      final cat = ref.read(lecturerUnifiedCatalogProvider).requireValue;
      final lectures =
          cat.toLectureItems(isArabic: LecturerLanguageController.isArabic);
      final courseOptions = _extractUniqueCourseNames(lectures);
      setState(() {
        _allLectures = lectures;
        _selectedDate = DateTime(now.year, now.month, now.day);
        _selectedDayOfWeek = _selectedDate.weekday;
        _currentCalendarMonth = DateTime(now.year, now.month, 1);
        if (_selectedCourse != null &&
            !courseOptions.any((n) => n == _selectedCourse)) {
          _selectedCourse =
              courseOptions.isNotEmpty ? courseOptions.first : null;
        }
      });
    } catch (_) {
      // Keep hydrated lectures; silent refresh failure.
    } finally {
      if (mounted) setState(() => _catalogRefreshing = false);
    }
  }

  void _attachOpenSessionsStream() {
    _openSessionsSub?.cancel();
    _openSessionsSub = _nfcAttendance
        .watchOpenSessionsForCurrentLecturer()
        .listen((sessions) {
          if (!mounted) return;
          setState(() => _openSessions = sessions);
        });
  }

  List<String> _extractUniqueCourseNames(List<LectureItem> lectures) {
    final names =
        lectures
            .map((l) => l.courseName.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return names;
  }

  List<LectureItem> _lecturesForSelectedDay() {
    final selectedCourse = _selectedCourse;
    if (selectedCourse == null || selectedCourse.trim().isEmpty) {
      return <LectureItem>[];
    }

    final filtered = _allLectures
        .where(
          (lecture) =>
              lecture.dayOfWeek == _selectedDayOfWeek &&
              lecture.courseName.trim() == selectedCourse.trim(),
        )
        .toList();

    filtered.sort((a, b) => a.startTime.compareTo(b.startTime));
    return filtered;
  }

  String _sessionIdForLecture(LectureItem lecture) {
    final sectionId = (lecture.sectionId ?? '').trim();
    if (sectionId.isEmpty) return '';
    return ManualAttendanceService.buildSessionId(
      sectionId: sectionId,
      sessionDate: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      ),
      lectureStartTime: lecture.startTime,
    );
  }

  NfcAttendanceSession? _openSessionForLecture(LectureItem lecture) {
    final sessionId = _sessionIdForLecture(lecture);
    if (sessionId.isEmpty) return null;
    for (final session in _openSessions) {
      if (session.sessionId == sessionId && session.isOpen) {
        return session;
      }
    }
    return null;
  }

  bool _isTodaySelected() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return selected == today;
  }

  bool _isLectureWithinAttendanceWindow(LectureItem lecture) {
    return AttendanceStatusPolicy.isSessionWithinAttendanceWindow(
      lectureDate: DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      ),
      lectureStartTime: lecture.startTime,
      lectureEndTime: lecture.endTime,
      currentTime: DateTime.now(),
    );
  }

  Future<void> _openNfcSession(LectureItem lecture) async {
    final sessionId = _sessionIdForLecture(lecture);
    if (sessionId.isEmpty) {
      _showSnack(
        _tr(
          'لا يمكن فتح الجلسة لأن معرّف الشعبة غير مكتمل.',
          'Cannot open session because sectionId is missing.',
        ),
        error: true,
      );
      return;
    }

    setState(() => _openingSessionIds.add(sessionId));
    try {
      await _nfcAttendance.openSessionForLecture(
        lecture: lecture,
        lectureDate: _selectedDate,
      );
      if (!mounted) return;
      _showSnack(
        _tr(
          'تم فتح جلسة NFC ويمكن للطلاب التحضير الآن.',
          'NFC session is open. Students can mark attendance now.',
        ),
      );
    } on NfcAttendanceException catch (e) {
      if (!mounted) return;
      _showSnack(_mapNfcErrorToMessage(e), error: true);
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        _tr('فشل فتح جلسة NFC: $e', 'Failed to open NFC session: $e'),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _openingSessionIds.remove(sessionId));
      }
    }
  }

  Future<void> _closeNfcSession(NfcAttendanceSession session) async {
    setState(() => _closingSessionIds.add(session.sessionId));
    try {
      await _nfcAttendance.closeSession(session.sessionId);
      if (!mounted) return;
      _showSnack(
        _tr(
          'تم إغلاق جلسة NFC لهذه المحاضرة.',
          'NFC session has been closed for this lecture.',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        _tr('فشل إغلاق الجلسة: $e', 'Failed to close session: $e'),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() => _closingSessionIds.remove(session.sessionId));
      }
    }
  }

  String _mapNfcErrorToMessage(NfcAttendanceException error) {
    switch (error.code) {
      case NfcAttendanceErrorCode.missingLecturerCard:
        return _tr(
          'لا توجد بطاقة NFC مرتبطة بحسابك. يرجى إضافتها من صفحة الأدمن.',
          'No NFC card is linked to your account. Please add it from the Admin page.',
        );
      case NfcAttendanceErrorCode.invalidInput:
        return _tr(
          'البيانات غير مكتملة لفتح الجلسة.',
          'Session data is incomplete.',
        );
      case NfcAttendanceErrorCode.outsideLectureWindow:
        return _tr(
          'لا يمكن فتح جلسة NFC الآن. متاح فقط أثناء نافذة وقت المحاضرة.',
          'NFC session can only be opened during the lecture time window.',
        );
      default:
        return error.message;
    }
  }

  void _showSnack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? _danger : Colors.grey.shade700,
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
          final lectures = cat.toLectureItems(
            isArabic: LecturerLanguageController.isArabic,
          );
          final courseOptions = _extractUniqueCourseNames(lectures);
          setState(() {
            _allLectures = lectures;
            _selectedCourse = courseOptions.isNotEmpty
                ? courseOptions.first
                : _selectedCourse;
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
                _tr('إدارة جلسة NFC', 'NFC Session Control'),
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
                  onPressed: _loadPageData,
                  icon: const Icon(Icons.refresh),
                  tooltip: _tr('تحديث', 'Refresh'),
                ),
              ],
            ),
            body: SafeArea(
              child: (_isLoading && _allLectures.isEmpty)
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: _primary),
                      ),
                    )
                  : _loadError != null
                  ? _buildLoadError()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        if (_isLoading || _catalogRefreshing)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              color: _primary,
                              backgroundColor: Color(0xFFE6F1F2),
                            ),
                          ),
                        _buildLecturerCardStatus(),
                        const SizedBox(height: 16),
                        _buildCourseSelector(),
                        const SizedBox(height: 16),
                        _buildCalendar(),
                        const SizedBox(height: 14),
                        _buildLecturesForDay(),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_tr('تعذر تحميل بيانات الصفحة', 'Failed to load page data')),
            const SizedBox(height: 10),
            Text(
              _loadError ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _loadPageData,
              icon: const Icon(Icons.refresh),
              label: Text(_tr('إعادة المحاولة', 'Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLecturerCardStatus() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE8EA)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFE6F3F5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.nfc_rounded, color: _primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _loadingCard
                ? Text(_tr('جاري تحميل البطاقة...', 'Loading card...'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tr('بطاقة المحاضر المرتبطة', 'Linked lecturer card'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF607279),
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (_lecturerCardId == null || _lecturerCardId!.isEmpty)
                            ? _tr(
                                'غير مضافة بعد (يرجى إضافتها من صفحة الأدمن)',
                                'Not assigned yet (please add it from the Admin page)',
                              )
                            : _lecturerCardId!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color:
                              (_lecturerCardId == null ||
                                  _lecturerCardId!.isEmpty)
                              ? _danger
                              : const Color(0xFF1F2E33),
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseSelector() {
    final options = _extractUniqueCourseNames(_allLectures);
    if (options.isEmpty) {
      return _infoCard(
        icon: Icons.menu_book_outlined,
        message: _tr(
          'لا توجد مواد مرتبطة بحسابك حالياً.',
          'No courses are linked to your account yet.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr('1) اختر المقرر', '1) Select course'),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2E33),
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final course = options[index];
              final selected = _selectedCourse == course;
              return GestureDetector(
                onTap: () => setState(() => _selectedCourse = course),
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFE6F3F5) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? _primary : const Color(0xFFE2E8EA),
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
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
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _tr(
                          'اضغط لاختيار المقرر',
                          'Tap to select this course',
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6A7D84),
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    final selectedCourse = _selectedCourse;
    if (selectedCourse == null || selectedCourse.trim().isEmpty) {
      return _infoCard(
        icon: Icons.touch_app_outlined,
        message: _tr(
          'يرجى اختيار مقرر أولاً لعرض التقويم.',
          'Select a course first to show its calendar.',
        ),
      );
    }

    final courseLectures = _allLectures
        .where((l) => l.courseName.trim() == selectedCourse.trim())
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr('2) اختر اليوم', '2) Select day'),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2E33),
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 10),
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
            });
          },
          onMonthChanged: (DateTime month) {
            setState(() => _currentCalendarMonth = month);
          },
        ),
        const SizedBox(height: 8),
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
    );
  }

  Widget _buildLecturesForDay() {
    final lectures = _lecturesForSelectedDay();
    if (lectures.isEmpty) {
      return _infoCard(
        icon: Icons.event_busy_outlined,
        message: _tr(
          'لا توجد محاضرات لهذا المقرر في اليوم المختار.',
          'No lectures for this course on the selected day.',
        ),
      );
    }

    final todaySelected = _isTodaySelected();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr('جلسات اليوم', 'Day sessions'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2E33),
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 8),
        if (!todaySelected)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _tr(
                'فتح جلسة NFC متاح لليوم الحالي فقط.',
                'Opening NFC session is available only for today.',
              ),
              style: const TextStyle(
                color: _danger,
                fontSize: 12,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ...lectures.map((lecture) {
          final sessionId = _sessionIdForLecture(lecture);
          final openSession = _openSessionForLecture(lecture);
          final isOpening = _openingSessionIds.contains(sessionId);
          final isClosing =
              openSession != null &&
              _closingSessionIds.contains(openSession.sessionId);
          final withinTimeWindow = _isLectureWithinAttendanceWindow(lecture);
          final busy = isOpening || isClosing;
          final canOpenNow = todaySelected && withinTimeWindow;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDCE6E8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lecture.courseName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Cairo',
                          color: Color(0xFF1F2E33),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: openSession == null
                            ? const Color(0xFFE9EEF0)
                            : const Color(0xFFE1F5E9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        openSession == null
                            ? _tr('مغلقة', 'Closed')
                            : _tr('مفتوحة', 'Open'),
                        style: TextStyle(
                          color: openSession == null
                              ? const Color(0xFF5C6E75)
                              : const Color(0xFF1B5E20),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_tr('الوقت', 'Time')}: ${lecture.startTime} - ${lecture.endTime}  •  ${_tr('الشعبة', 'Section')}: ${lecture.section}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF556A71),
                    fontFamily: 'Cairo',
                  ),
                ),
                if (openSession == null && !canOpenNow) ...[
                  const SizedBox(height: 8),
                  Text(
                    _tr(
                      'يمكن فتح NFC فقط خلال نافذة وقت المحاضرة.',
                      'NFC can only be opened during lecture time window.',
                    ),
                    style: const TextStyle(
                      color: _danger,
                      fontSize: 12,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: ((openSession == null && !canOpenNow) || busy)
                        ? null
                        : () {
                            if (openSession == null) {
                              _openNfcSession(lecture);
                            } else {
                              _closeNfcSession(openSession);
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: openSession == null ? _primary : _danger,
                      disabledBackgroundColor: const Color(0xFFB0BEC5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            openSession == null
                                ? _tr('فتح جلسة NFC', 'Open NFC Session')
                                : _tr('إغلاق الجلسة', 'Close Session'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Cairo',
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _infoCard({required IconData icon, required String message}) {
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
}
