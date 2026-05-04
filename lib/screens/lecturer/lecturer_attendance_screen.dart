import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/attendance/manual_attendance_record.dart';
import '../../models/attendance/nfc_attendance_session.dart';
import '../../models/attendance/qr_attendance_session.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../services/attendance/attendance_session_export_service.dart';
import '../../services/attendance/manual_attendance_service.dart';
import '../../services/attendance/nfc_attendance_service.dart';
import '../../services/attendance/qr_attendance_service.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../services/lecturer/calendar_sync_service.dart';
import 'lecturer_language.dart';
import 'lecturer_navigation.dart';
import 'widgets/profile_back_button.dart';

/// Figure 10 – Live Attendance – Current Day & Lecture.
///
/// تعرض قائمة الطلاب المسجلين في المحاضرة الحالية، مع حالة التحضير حسب تسجيل
/// الدخول (QR أو NFC). الحالة تُحدَّث تلقائياً حسب وقت التحضير الفعلي المعروض
/// بجانب اسم كل طالب. إن سجّل الطالب دخوله دون اتصال، تُحدَّث الحالة بعد عودة
/// الاتصال ومزامنة البيانات؛ يظهر أيقونة مزامنة بجانب حقل الحالة للإشارة إلى
/// تحديث قيد الانتظار.
///
/// يُعرض فقط سجلات التحضير الفعلية لليوم الحالي والمحاضرة الحالية. التعديل
/// اللاحق على سجلات سابقة يتم من البروفايل عبر [Attendance Reports].
///
/// لون كل حالة (حاضر، غائب، غياب بعذر، تأخر) يعكس الحالة الفعلية، والمحاضر
/// يمكنه تعديلها يدوياً حسب الملاحظة. أزرار "معاينة الأعذار" و"حفظ" مع شريط
/// تنقل سفلي ثابت للوصول السريع لأقسام التطبيق.
///
/// تُفتح من صفحة "اليوم" عند الضغط على كارد المحاضرة.
class LecturerAttendanceScreen extends StatefulWidget {
  const LecturerAttendanceScreen({
    super.key,
    required this.lecture,
    this.viewOnly = false,
    this.selectedDate,
    this.sessionId,
  });

  final LectureItem lecture;

  /// عند true (من صفحة الكل — يوم أزرق): عرض تقارير الحضور فقط دون تعديل.
  final bool viewOnly;

  /// تاريخ اليوم المعروضة تقاريره (للوضع View Only من التقويم).
  final DateTime? selectedDate;

  /// Optional existing session id passed from Attendance Report.
  final String? sessionId;

  @override
  State<LecturerAttendanceScreen> createState() =>
      _LecturerAttendanceScreenState();
}

class _LecturerAttendanceScreenState extends State<LecturerAttendanceScreen> {
  static const Color _primary = Color(0xFF006571);

  final ManualAttendanceService _manualAttendanceService =
      ManualAttendanceService.instance;
  final LectureRepository _calendarRepository = LectureRepository();
  final NfcAttendanceService _nfcAttendanceService =
      NfcAttendanceService.instance;
  final QrAttendanceService _qrAttendanceService = QrAttendanceService.instance;
  StreamSubscription<List<ManualAttendanceRecord>>? _recordsSubscription;
  StreamSubscription<void>? _calendarSyncSub;
  StreamSubscription<List<NfcAttendanceSession>>? _nfcSessionsSubscription;

  String? _sessionId;
  List<_StudentRow> _students = <_StudentRow>[];
  AttendanceStatusFilter _statusFilter = AttendanceStatusFilter.all;
  Map<String, AttendanceStatus> _draftStatuses = {};
  bool _hasPendingChanges = false;
  bool _isSaving = false;
  bool _isExporting = false;
  bool _isLoadingAttendance = true;
  String? _attendanceLoadError;
  DateTime? _calendarReferenceDate;
  bool _isSyncRefreshing = false;
  AttendanceMethod _selectedMethod = AttendanceMethod.manual;
  bool _isProcessingMethodAction = false;
  bool _isNfcActiveForLecture = false;
  String? _methodStatusMessage;
  QrAttendanceSession? _qrSession;
  String _qrData = '';
  bool _isLoadingQr = false;
  bool _isRefreshingQrToken = false;
  bool _isUsingRosterFallback = false;
  Timer? _qrAutoRefreshTimer;
  static const int _qrAutoRefreshIntervalSeconds = 30;
  int _qrAutoRefreshSecondsLeft = _qrAutoRefreshIntervalSeconds;

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  LectureItem get _lecture => widget.lecture;
  bool get _viewOnly => widget.viewOnly;
  DateTime? get _selectedDate => widget.selectedDate;
  String? get _providedSessionId => widget.sessionId;
  bool get _effectiveViewOnly => _viewOnly;

  /// صيغة موحدة لعرض النسبة: "N٪" بدون مسافات أو رموز زيادة.
  String _formatPercentage(int value) => '$value٪';

  /// وقت المحاضرة بصيغة واضحة (24 ساعة، بدون AM/PM)
  String get _lectureTimeRange {
    final slots = _lecture.timeSlots;
    if (slots.isEmpty) return '${_lecture.startTime} - ${_lecture.endTime}';
    if (slots.length == 1) return slots.first;
    return '${slots.first} / ${slots.last}';
  }

  /// طلاب الجلسة الحالية فقط — مبنون من المحاضرة (ديناميكي).
  List<_StudentRow> get _allStudents => _students;

  /// الطلاب بعد تطبيق الفلتر فقط. الفلترة فورية في الذاكرة ولا تعيد تحميل الصفحة.
  List<_StudentRow> get _filteredStudents {
    if (_statusFilter == AttendanceStatusFilter.all) return _allStudents;
    return _allStudents.where((s) {
      final status = _effectiveStatus(s);
      return _statusToFilter(status) == _statusFilter;
    }).toList();
  }

  /// الحالة الفعلية مع توافق Hot Reload: إن كانت الحالة قديمة (مثل suspended المحذوف) نعيد حاضر.
  AttendanceStatus _effectiveStatus(_StudentRow student) {
    final s = _draftStatuses[student.academicNumber] ?? student.status;
    if (AttendanceStatus.values.contains(s)) return s;
    return AttendanceStatus.present;
  }

  void _setDraftStatus(String academicNumber, AttendanceStatus status) {
    setState(() {
      _draftStatuses[academicNumber] = status;
      _hasPendingChanges = true;
    });
  }

  /// هل يوجد طلاب حالتهم Pending Sync (Offline)؟
  bool get _hasPendingSyncStudents => _students.any((s) => s.isOffline);

  /// حفظ التعديلات للجلسة الحالية فقط (مربوط بـ CRN + تاريخ اليوم).
  /// التعديل على أيام سابقة من [Attendance Reports].
  Future<void> _saveChanges() async {
    if (_effectiveViewOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'عرض فقط — لا يمكن تعديل الحضور.',
              'Preview only — attendance cannot be edited.',
            ),
          ),
        ),
      );
      return;
    }
    if (!_hasPendingChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('لا توجد تغييرات للحفظ.', 'No changes to save.')),
        ),
      );
      return;
    }
    if (_isSaving) return;
    final sessionId = _sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'تعذر معرفة جلسة التحضير الحالية.',
              'Could not resolve the current attendance session.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updates = <int, ManualAttendanceStatus>{};
      for (final entry in _draftStatuses.entries) {
        final studentId = int.tryParse(entry.key);
        if (studentId == null) continue;
        updates[studentId] = _manualStatusFromUi(entry.value);
      }
      await _manualAttendanceService.updateSessionStatuses(
        sessionId: sessionId,
        updates: updates,
      );

      if (!mounted) return;

      setState(() {
        for (final s in _students) {
          final updated = _draftStatuses[s.academicNumber];
          if (updated != null) {
            s.status = updated;
            s.attendanceTime = _timeTextForStatus(updated);
            s.percentage = _percentageForStatus(updated);
          }
        }
        _draftStatuses = {};
        _hasPendingChanges = false;
      });

      final hasPendingSync = _hasPendingSyncStudents;
      final successMessage = hasPendingSync
          ? _tr(
              'تم الحفظ بنجاح. يوجد سجلات بانتظار المزامنة.',
              'Saved successfully. Some records are pending sync.',
            )
          : _tr('تم الحفظ بنجاح.', 'Saved successfully.');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF2B9E56),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('فشل الحفظ. حاول مرة أخرى.', 'Save failed. Please try again.'),
          ),
          backgroundColor: const Color(0xFFD32F2F),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Session-scoped CSV export (same service as attendance report). Hidden until session loads.
  bool get _exportButtonVisible {
    final sid = _sessionId;
    if (sid == null || sid.isEmpty) return false;
    if (_isLoadingAttendance) return false;
    if (_attendanceLoadError != null) return false;
    return true;
  }

  bool get _exportButtonEnabled {
    if (!_exportButtonVisible || _isExporting || _isSaving) return false;
    if (!_effectiveViewOnly && _hasPendingChanges) return false;
    return true;
  }

  Future<void> _exportSessionCsv() async {
    if (!_exportButtonEnabled) {
      if (!_effectiveViewOnly && _hasPendingChanges) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                'احفظي تعديلات الحضور قبل التصدير.',
                'Save attendance changes before exporting.',
              ),
            ),
          ),
        );
      }
      return;
    }
    final sid = _sessionId!;
    setState(() => _isExporting = true);
    try {
      await AttendanceSessionExportService.instance.exportSessionCsvAndShare(
        sid,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_tr('فشل التصدير.', 'Export failed.')} $e'),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _openPreviewExcuses() async {
    final sessionId = _sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'تعذر فتح الأعذار قبل تحميل جلسة التحضير.',
              'Cannot open excuses before the attendance session is loaded.',
            ),
          ),
        ),
      );
      return;
    }
    final saved = await LecturerNavigation.goToExcuseManagement(
      context,
      widget.lecture,
      sessionId: sessionId,
      sessionDate: _sessionDate,
    );
    if (saved == true && mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _calendarSyncSub = CalendarSyncService.instance.watchChanges().listen(
      (_) => _handleRealtimeCalendarChange(),
    );
    _bootstrapAttendance();
  }

  @override
  void dispose() {
    _recordsSubscription?.cancel();
    _calendarSyncSub?.cancel();
    _nfcSessionsSubscription?.cancel();
    _stopQrAutoRefreshTimer();
    super.dispose();
  }

  DateTime get _sessionDate => DateTime(
    (_selectedDate ?? _calendarReferenceDate ?? DateTime.now()).year,
    (_selectedDate ?? _calendarReferenceDate ?? DateTime.now()).month,
    (_selectedDate ?? _calendarReferenceDate ?? DateTime.now()).day,
  );

  Future<void> _bootstrapAttendance() async {
    try {
      await _calendarRepository.refreshAcademicCalendar();
      _calendarReferenceDate = DateTime(
        _calendarRepository.currentDateTime.year,
        _calendarRepository.currentDateTime.month,
        _calendarRepository.currentDateTime.day,
      );
    } catch (_) {
      _calendarReferenceDate = DateTime.now();
    }
    await _loadManualAttendance();
    _attachNfcSessionWatcher();
  }

  Future<void> _handleRealtimeCalendarChange() async {
    if (!mounted || _isSyncRefreshing) return;
    _isSyncRefreshing = true;
    try {
      await _calendarRepository.refreshAcademicCalendar();
      final newReference = DateTime(
        _calendarRepository.currentDateTime.year,
        _calendarRepository.currentDateTime.month,
        _calendarRepository.currentDateTime.day,
      );
      final previous = _calendarReferenceDate;
      _calendarReferenceDate = newReference;

      final dayChanged =
          previous == null ||
          previous.year != newReference.year ||
          previous.month != newReference.month ||
          previous.day != newReference.day;

      if (!_viewOnly && _selectedDate == null && dayChanged) {
        await _loadManualAttendance();
        return;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Ignore transient realtime listener errors.
    } finally {
      _isSyncRefreshing = false;
    }
  }

  Future<void> _loadManualAttendance() async {
    setState(() {
      _isLoadingAttendance = true;
      _attendanceLoadError = null;
    });

    try {
      final sectionId = (_lecture.sectionId ?? '').trim();
      if (sectionId.isEmpty) {
        throw StateError(
          _tr(
            'لا يوجد معرف سكشن لهذه المحاضرة.',
            'Section id is missing for this lecture.',
          ),
        );
      }

      final targetDate = _sessionDate;
      final providedSessionId = _providedSessionId?.trim() ?? '';
      final sessionId = providedSessionId.isNotEmpty
          ? providedSessionId
          : ManualAttendanceService.buildSessionId(
              sectionId: sectionId,
              sessionDate: targetDate,
              lectureStartTime: _lecture.startTime,
            );
      if (!_effectiveViewOnly && providedSessionId.isEmpty) {
        await _manualAttendanceService.prepareSessionForLecture(
          lecture: _lecture,
          sessionDate: targetDate,
        );
      }

      if (!mounted) return;
      _attachSessionStream(sessionId);
      _refreshNfcStatusFromSessionId();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAttendance = false;
        _attendanceLoadError = e.toString();
      });
    }
  }

  void _attachSessionStream(String sessionId) {
    _recordsSubscription?.cancel();
    _sessionId = sessionId;
    _recordsSubscription = _manualAttendanceService
        .watchSessionRecords(sessionId)
        .listen(
          (records) {
            if (!mounted) return;
            if (records.isNotEmpty) {
              setState(() {
                _students = records.map(_studentFromRecord).toList();
                if (_isUsingRosterFallback) {
                  _methodStatusMessage = null;
                }
                _isUsingRosterFallback = false;
                _isLoadingAttendance = false;
                _attendanceLoadError = null;
              });
              return;
            }
            setState(() {
              _students = <_StudentRow>[];
              _isUsingRosterFallback = false;
              _isLoadingAttendance = false;
              _attendanceLoadError = null;
            });
            unawaited(_loadFallbackRosterForSection(sessionId));
          },
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _isLoadingAttendance = false;
              _attendanceLoadError = error.toString();
            });
          },
        );
  }

  Future<void> _loadFallbackRosterForSection(String sessionId) async {
    final sectionId = (_lecture.sectionId ?? '').trim();
    if (sectionId.isEmpty) return;
    try {
      final roster = await _manualAttendanceService.getActiveSectionRoster(
        sectionId,
      );
      if (!mounted || _sessionId != sessionId) return;
      if (roster.isEmpty) return;
      setState(() {
        if (_students.isNotEmpty) return;
        _students = roster
            .map((s) => _studentFromEnrollment(s, sessionId))
            .toList();
        _isUsingRosterFallback = true;
        _methodStatusMessage = _tr(
          'تم عرض قائمة الطلاب من تسجيلات الشعبة (عرض فقط).',
          'Showing enrolled roster for preview mode.',
        );
      });
    } catch (_) {
      // Ignore fallback roster errors and keep current state.
    }
  }

  void _attachNfcSessionWatcher() {
    _nfcSessionsSubscription?.cancel();
    _nfcSessionsSubscription = _nfcAttendanceService
        .watchOpenSessionsForCurrentLecturer()
        .listen((sessions) {
          if (!mounted) return;
          final currentSessionId =
              _sessionId ?? _buildSessionIdForCurrentLecture();
          final isOpen = sessions.any(
            (s) => s.sessionId == currentSessionId && s.isOpen,
          );
          setState(() {
            _isNfcActiveForLecture = isOpen;
            if (isOpen) {
              _methodStatusMessage = _tr(
                'التحضير عبر NFC نشط لهذه المحاضرة.',
                'NFC attendance is active for this lecture.',
              );
            }
          });
        });
  }

  void _refreshNfcStatusFromSessionId() {
    // يتم تحديث الحالة الفعلية عبر الـ stream؛ هنا نعيد ضبط رسالة الحالة فقط.
    if (!mounted) return;
    setState(() {
      if (!_isNfcActiveForLecture) {
        _methodStatusMessage = null;
      }
    });
  }

  String _buildSessionIdForCurrentLecture() {
    final sectionId = (_lecture.sectionId ?? '').trim();
    if (sectionId.isEmpty) return '';
    return ManualAttendanceService.buildSessionId(
      sectionId: sectionId,
      sessionDate: _sessionDate,
      lectureStartTime: _lecture.startTime,
    );
  }

  bool _hasRequiredLectureData() {
    final sectionId = (_lecture.sectionId ?? '').trim();
    return sectionId.isNotEmpty &&
        _lecture.courseName.trim().isNotEmpty &&
        _lecture.startTime.trim().isNotEmpty &&
        _lecture.endTime.trim().isNotEmpty;
  }

  Future<void> _onSelectMethod(AttendanceMethod method) async {
    if (_isProcessingMethodAction) return;
    if (!_hasRequiredLectureData()) {
      _showMethodSnack(
        _tr(
          'بيانات المحاضرة ناقصة. لا يمكن اختيار طريقة التحضير.',
          'Lecture data is missing. Cannot select attendance method.',
        ),
        error: true,
      );
      return;
    }

    setState(() {
      _selectedMethod = method;
      _isProcessingMethodAction = true;
      _methodStatusMessage = null;
    });
    if (method != AttendanceMethod.qr) {
      _stopQrAutoRefreshTimer();
    }

    try {
      switch (method) {
        case AttendanceMethod.manual:
          setState(() {
            _methodStatusMessage = null;
          });
          break;
        case AttendanceMethod.qr:
          await _loadQrForCurrentLecture();
          break;
        case AttendanceMethod.nfc:
          await _openOrConfirmNfcForCurrentLecture();
          break;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingMethodAction = false;
        });
      }
    }
  }

  Future<void> _loadQrForCurrentLecture({bool refreshToken = false}) async {
    final sectionId = (_lecture.sectionId ?? '').trim();
    if (sectionId.isEmpty) {
      _showMethodSnack(
        _tr(
          'بيانات المحاضرة ناقصة: sectionId غير متوفر.',
          'Lecture data is missing: sectionId is not available.',
        ),
        error: true,
      );
      return;
    }
    if (_lecture.startTime.trim().isEmpty || _lecture.endTime.trim().isEmpty) {
      _showMethodSnack(
        _tr(
          'بيانات المحاضرة ناقصة: وقت المحاضرة غير مكتمل.',
          'Lecture data is missing: lecture time is incomplete.',
        ),
        error: true,
      );
      return;
    }

    setState(() {
      _isLoadingQr = true;
    });

    try {
      final session = await _qrAttendanceService.createOrGetSessionForLecture(
        lecture: _lecture,
        lectureDate: _sessionDate,
      );
      final effectiveSession = refreshToken
          ? await _qrAttendanceService.refreshSessionToken(session.sessionId)
          : session;
      if (!mounted) return;
      setState(() {
        _qrSession = effectiveSession;
        _qrData = _buildQrPayload(effectiveSession);
        _methodStatusMessage = _tr(
          'تم تفعيل التحضير عبر QR لهذه المحاضرة.',
          'QR attendance is active for this lecture.',
        );
      });
    } on FirebaseException catch (e) {
      final message = e.code == 'permission-denied'
          ? _tr(
              'تعذر إنشاء جلسة QR: لا توجد صلاحية للوصول إلى Firestore.',
              'Failed to create QR session: Firestore permission denied.',
            )
          : _tr(
              'فشل إنشاء/جلب جلسة QR لهذه المحاضرة.',
              'Failed to create/fetch QR session for this lecture.',
            );
      _showMethodSnack(message, error: true);
    } catch (_) {
      _showMethodSnack(
        _tr('فشل تحديث أو تحميل رمز QR.', 'Failed to load or refresh QR code.'),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingQr = false;
        });
      }
    }
  }

  Future<bool> _refreshQrSessionToken({bool showErrorSnack = true}) async {
    if (_isRefreshingQrToken || _qrSession == null) {
      return false;
    }
    if (_selectedMethod != AttendanceMethod.qr) {
      return false;
    }
    _isRefreshingQrToken = true;
    try {
      final refreshed = await _qrAttendanceService.refreshSessionToken(
        _qrSession!.sessionId,
      );
      if (!mounted) return false;
      setState(() {
        _qrSession = refreshed;
        _qrData = _buildQrPayload(refreshed);
      });
      return true;
    } on FirebaseException catch (e) {
      if (showErrorSnack) {
        final message = e.code == 'permission-denied'
            ? _tr(
                'تعذر تحديث رمز QR: لا توجد صلاحية للوصول إلى Firestore.',
                'Failed to refresh QR: Firestore permission denied.',
              )
            : _tr(
                'فشل تحديث رمز QR بسبب مشكلة اتصال أو صلاحيات.',
                'Failed to refresh QR due to network or permission issue.',
              );
        _showMethodSnack(message, error: true);
      }
      return false;
    } catch (_) {
      if (showErrorSnack) {
        _showMethodSnack(
          _tr(
            'فشل تحديث رمز QR. تأكدي من الاتصال ثم حاولي مجدداً.',
            'Failed to refresh QR. Check your network and try again.',
          ),
          error: true,
        );
      }
      return false;
    } finally {
      _isRefreshingQrToken = false;
    }
  }

  void _startQrAutoRefreshTimer({
    void Function(int secondsLeft)? onTick,
    void Function(String message)? onError,
    void Function(bool refreshing)? onRefreshStateChanged,
  }) {
    _stopQrAutoRefreshTimer();
    _qrAutoRefreshSecondsLeft = _qrAutoRefreshIntervalSeconds;
    onTick?.call(_qrAutoRefreshSecondsLeft);
    _qrAutoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted ||
          _selectedMethod != AttendanceMethod.qr ||
          _qrSession == null) {
        _stopQrAutoRefreshTimer();
        return;
      }
      _qrAutoRefreshSecondsLeft = _qrAutoRefreshSecondsLeft - 1;
      if (_qrAutoRefreshSecondsLeft > 0) {
        onTick?.call(_qrAutoRefreshSecondsLeft);
        return;
      }
      if (_isRefreshingQrToken) {
        _qrAutoRefreshSecondsLeft = 1;
        onTick?.call(_qrAutoRefreshSecondsLeft);
        return;
      }

      if (kDebugMode) {
        debugPrint('QR_AUTO_REFRESH_TRIGGERED');
      }
      onRefreshStateChanged?.call(true);
      final ok = await _refreshQrSessionToken(showErrorSnack: false);
      onRefreshStateChanged?.call(false);
      _qrAutoRefreshSecondsLeft = _qrAutoRefreshIntervalSeconds;
      onTick?.call(_qrAutoRefreshSecondsLeft);
      if (!ok && onError != null) {
        if (kDebugMode) {
          debugPrint('QR_AUTO_REFRESH_FAILED error=refresh_failed');
        }
        onError(
          _tr(
            'تعذر التحديث التلقائي لرمز QR. استخدمي زر التحديث يدوياً.',
            'Automatic QR refresh failed. Use manual refresh button.',
          ),
        );
      } else if (ok) {
        if (kDebugMode) {
          debugPrint('QR_AUTO_REFRESH_SUCCESS');
        }
      }
    });
  }

  void _stopQrAutoRefreshTimer() {
    _qrAutoRefreshTimer?.cancel();
    _qrAutoRefreshTimer = null;
  }

  String _buildQrPayload(QrAttendanceSession session) {
    return jsonEncode(<String, dynamic>{
      'sessionId': session.sessionId,
      'sectionId': session.sectionId,
      'tokenId': session.currentTokenId,
      'tokenVersion': session.tokenVersion,
      'expiresAt': session.expiresAt.toUtc().toIso8601String(),
    });
  }

  Future<void> _openOrConfirmNfcForCurrentLecture() async {
    final sectionId = (_lecture.sectionId ?? '').trim();
    if (sectionId.isEmpty) {
      _showMethodSnack(
        _tr(
          'لا يمكن تفعيل NFC لعدم توفر sectionId للمحاضرة.',
          'Cannot enable NFC because sectionId is missing.',
        ),
        error: true,
      );
      return;
    }

    if (_isNfcActiveForLecture) {
      setState(() {
        _methodStatusMessage = _tr(
          'التحضير عبر NFC نشط بالفعل لهذه المحاضرة.',
          'NFC attendance is already active for this lecture.',
        );
      });
      return;
    }

    try {
      await _nfcAttendanceService.openSessionForLecture(
        lecture: _lecture,
        lectureDate: _sessionDate,
      );
      if (!mounted) return;
      setState(() {
        _isNfcActiveForLecture = true;
        _methodStatusMessage = _tr(
          'تم تفعيل التحضير عبر NFC لهذه المحاضرة.',
          'NFC attendance is now active for this lecture.',
        );
      });
    } on NfcAttendanceException catch (e) {
      _showMethodSnack(_mapNfcErrorToArabic(e), error: true);
    } on FirebaseException catch (e) {
      final message = e.code == 'permission-denied'
          ? _tr(
              'تعذر تفعيل NFC: لا توجد صلاحية للوصول إلى Firestore.',
              'Failed to enable NFC: Firestore permission denied.',
            )
          : _tr(
              'تعذر تفعيل NFC لهذه المحاضرة.',
              'Failed to enable NFC for this lecture.',
            );
      _showMethodSnack(message, error: true);
    } catch (_) {
      _showMethodSnack(
        _tr(
          'طريقة التحضير NFC غير متاحة حالياً.',
          'NFC attendance method is currently unavailable.',
        ),
        error: true,
      );
    }
  }

  String _mapNfcErrorToArabic(NfcAttendanceException error) {
    switch (error.code) {
      case NfcAttendanceErrorCode.missingLecturerCard:
        return _tr(
          'NFC غير متاح: لا توجد بطاقة NFC مرتبطة بحسابك.',
          'NFC unavailable: no lecturer card is assigned to your account.',
        );
      case NfcAttendanceErrorCode.invalidInput:
        return _tr(
          'فشل تفعيل NFC بسبب نقص بيانات المحاضرة.',
          'Failed to enable NFC because lecture data is incomplete.',
        );
      case NfcAttendanceErrorCode.outsideLectureWindow:
        return _tr(
          'لا يمكن تفعيل NFC الآن. التفعيل متاح فقط أثناء نافذة وقت المحاضرة.',
          'NFC can only be enabled during the lecture attendance window.',
        );
      default:
        return _tr(
          'تعذر تفعيل NFC لهذه المحاضرة.',
          'Failed to enable NFC for this lecture.',
        );
    }
  }

  void _showMethodSnack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error
            ? const Color(0xFFD32F2F)
            : const Color(0xFF2B9E56),
      ),
    );
  }

  _StudentRow _studentFromRecord(ManualAttendanceRecord record) {
    final uiStatus = _uiStatusFromManual(record.status);
    final fallbackName = record.studentName.trim().isEmpty
        ? record.studentId.toString()
        : record.studentName;
    return _StudentRow(
      id: record.recordId,
      name: fallbackName,
      academicNumber: record.studentId.toString(),
      attendanceTime: record.attendanceTime.trim().isNotEmpty
          ? record.attendanceTime
          : _timeTextForStatus(uiStatus),
      percentage: _percentageForStatus(uiStatus),
      status: uiStatus,
      isOffline: false,
      isSuspended: false,
    );
  }

  _StudentRow _studentFromEnrollment(
    ManualEnrollmentStudent enrollment,
    String sessionId,
  ) {
    return _StudentRow(
      id: '${sessionId}_${enrollment.studentId}',
      name: enrollment.studentName,
      academicNumber: enrollment.studentId.toString(),
      attendanceTime: '--',
      percentage: 0,
      status: AttendanceStatus.pending,
      isOffline: false,
      isSuspended: false,
    );
  }

  AttendanceStatus _uiStatusFromManual(ManualAttendanceStatus status) {
    switch (status) {
      case ManualAttendanceStatus.pending:
        return AttendanceStatus.pending;
      case ManualAttendanceStatus.present:
        return AttendanceStatus.present;
      case ManualAttendanceStatus.absent:
        return AttendanceStatus.absent;
      case ManualAttendanceStatus.excused:
        return AttendanceStatus.excused;
      case ManualAttendanceStatus.late:
        return AttendanceStatus.late;
    }
  }

  ManualAttendanceStatus _manualStatusFromUi(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.pending:
        return ManualAttendanceStatus.pending;
      case AttendanceStatus.present:
        return ManualAttendanceStatus.present;
      case AttendanceStatus.absent:
        return ManualAttendanceStatus.absent;
      case AttendanceStatus.excused:
        return ManualAttendanceStatus.excused;
      case AttendanceStatus.late:
        return ManualAttendanceStatus.late;
    }
  }

  int _percentageForStatus(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.pending:
        return 0;
      case AttendanceStatus.present:
        return 100;
      case AttendanceStatus.late:
        return 90;
      case AttendanceStatus.absent:
      case AttendanceStatus.excused:
        return 0;
    }
  }

  String _timeTextForStatus(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.pending:
        return '--';
      case AttendanceStatus.present:
      case AttendanceStatus.late:
        return _lecture.startTime;
      case AttendanceStatus.absent:
      case AttendanceStatus.excused:
        return '--';
    }
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
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _buildFilterBar(),
                  ),
                  if (_methodStatusMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          _methodStatusMessage!,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF496169),
                          ),
                        ),
                      ),
                    ),
                  if (_selectedMethod == AttendanceMethod.qr)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _buildCompactQrActionButton(),
                      ),
                    ),
                  _buildSyncLegend(),
                  const SizedBox(height: 14),
                  Expanded(child: _buildTableSection()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _buildBottomButtons(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final activityLabel = _lecture.activity == 'عملي'
        ? _tr('عملي', 'Lab')
        : _tr('نظري', 'Theory');
    final sectionLabel = '${_tr('الشعبة', 'Section')} ${_lecture.section}';
    // سطران واضحان: الأول CRN + النوع + الشعبة، الثاني الوقت فقط — بفواصل واضحة
    final line1 = '${_lecture.crn}  ·  $activityLabel  ·  $sectionLabel';
    final line2 = _lectureTimeRange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: const Color(0xFFE8E8E8))),
      ),
      child: Row(
        children: [
          // زر الرجوع: نفس ProfileBackButton (يستخدم BackButtonIcon القياسي ويحترم RTL/LTR).
          ProfileBackButton(onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _lecture.courseName,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF222222),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_effectiveViewOnly)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF4A90E2,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF4A90E2)),
                        ),
                        child: Text(
                          _tr('عرض فقط', 'View only'),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  line1,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedDate != null
                      ? '${_formatDisplayDate(_selectedDate!)}  ·  $line2'
                      : line2,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_exportButtonVisible)
                Tooltip(
                  message:
                      !_exportButtonEnabled &&
                          _hasPendingChanges &&
                          !_effectiveViewOnly
                      ? _tr(
                          'احفظي التعديلات قبل التصدير.',
                          'Save changes before export.',
                        )
                      : _tr(
                          'تصدير حضور هذه الجلسة CSV',
                          'Export this session as CSV',
                        ),
                  child: IconButton(
                    onPressed: _isExporting
                        ? null
                        : _exportButtonEnabled
                        ? _exportSessionCsv
                        : (!_effectiveViewOnly && _hasPendingChanges)
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _tr(
                                    'احفظي تعديلات الحضور قبل التصدير.',
                                    'Save attendance changes before exporting.',
                                  ),
                                ),
                              ),
                            );
                          }
                        : null,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF006571),
                            ),
                          )
                        : Icon(
                            Icons.share_rounded,
                            color: _exportButtonEnabled
                                ? const Color(0xFF006571)
                                : const Color(0xFFB0BEC5),
                          ),
                  ),
                ),
              _buildCompactMethodMenu(),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDisplayDate(DateTime d) {
    final y = d.year, m = d.month, day = d.day;
    if (LecturerLanguageController.isArabic) return '$day/$m/$y';
    return '$day/$m/$y';
  }

  /// سطر توضيحي يظهر عند وجود طلاب مسجّل دخولهم دون اتصال — يوضح معنى رمز المزامنة.
  Widget _buildSyncLegend() {
    if (!_hasPendingSyncStudents) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Icon(Icons.sync_rounded, size: 18, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _tr(
                'الرمز بجانب الحالة = تم التسجيل دون اتصال، سيُحدَّث تلقائياً عند عودة الإنترنت.',
                'Icon next to status = Check-in was offline; will sync automatically when online.',
              ),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      AttendanceStatusFilter.all,
      AttendanceStatusFilter.present,
      AttendanceStatusFilter.excused,
      AttendanceStatusFilter.absent,
      AttendanceStatusFilter.late,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE6E8)),
      ),
      child: Row(
        children: filters.map((filter) {
          final active = _statusFilter == filter;
          final style = _filterStyle(filter);
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _statusFilter = filter),
              child: Container(
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? style.activeBg : const Color(0xFFF2F5F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  style.label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : const Color(0xFF516166),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCompactMethodMenu() {
    return PopupMenuButton<AttendanceMethod>(
      tooltip: _tr('اختيار طريقة التحضير', 'Select attendance method'),
      onSelected: _onSelectMethod,
      itemBuilder: (context) => [
        PopupMenuItem<AttendanceMethod>(
          value: AttendanceMethod.qr,
          child: Text(_tr('التحضير عبر QR', 'QR Code')),
        ),
        PopupMenuItem<AttendanceMethod>(
          value: AttendanceMethod.nfc,
          child: Text(_tr('التحضير عبر NFC', 'NFC')),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F5F6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD5E0E3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _selectedMethod == AttendanceMethod.nfc
                  ? Icons.nfc_rounded
                  : Icons.qr_code_rounded,
              size: 16,
              color: const Color(0xFF50656B),
            ),
            const SizedBox(width: 4),
            Text(
              _selectedMethod == AttendanceMethod.nfc
                  ? 'NFC'
                  : (_selectedMethod == AttendanceMethod.qr
                        ? 'QR'
                        : _tr('الطريقة', 'Method')),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF50656B),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: Color(0xFF50656B),
            ),
          ],
        ),
      ),
    );
  }

  /// عنصر سكرول واحد: CustomScrollView مع هيدر الجدول + قائمة الطلاب كـ Slivers (لا فراغ بين الهيدر وأول صف).
  Widget _buildTableSection() {
    if (_isLoadingAttendance) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF006571)),
      );
    }
    if (_attendanceLoadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _tr(
                  'تعذر تحميل بيانات التحضير.',
                  'Failed to load attendance data.',
                ),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3F3F3F),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _attendanceLoadError!,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Color(0xFF808080),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadManualAttendance,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(_tr('إعادة المحاولة', 'Retry')),
              ),
            ],
          ),
        ),
      );
    }

    return _buildAttendanceTableContainer();
  }

  Widget _buildAttendanceTableContainer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE6E8)),
        ),
        child: _filteredStudents.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _allStudents.isEmpty
                        ? _tr(
                            'لا يوجد طلاب مسجلون في هذه الشعبة حتى الآن.',
                            'No enrolled students found for this section yet.',
                          )
                        : _tr(
                            'لا يوجد طلاب في هذا الفلتر.',
                            'No students in this filter.',
                          ),
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Column(
                children: [
                  _buildStudentsTableHeader(),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _filteredStudents.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFE8EFF1)),
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
                        final statusStyle = _statusStyle(
                          _effectiveStatus(student),
                        );
                        return _buildStudentTableRow(
                          student: student,
                          statusStyle: statusStyle,
                          index: index,
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStudentsTableHeader() {
    return Container(
      color: const Color(0xFFF1F6F7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '#',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4A6066),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              _tr('الطالب', 'Student'),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4A6066),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _tr('الرقم', 'ID'),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4A6066),
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              _tr('الوقت', 'Time'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4A6066),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '%',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4A6066),
              ),
            ),
          ),
          SizedBox(
            width: 112,
            child: Text(
              _tr('الحالة', 'Status'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4A6066),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTableRow({
    required _StudentRow student,
    required _StatusStyle statusStyle,
    required int index,
  }) {
    final timeText = student.attendanceTime.trim().isEmpty
        ? '--'
        : student.attendanceTime.trim();
    final suspended = student.isSuspended ?? false;
    return Container(
      color: suspended
          ? const Color(0xFFFFF5F5)
          : (index.isEven ? Colors.white : const Color(0xFFFBFDFD)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5E6C70),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              student.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF213236),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              student.academicNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                color: Color(0xFF4E6268),
              ),
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              timeText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Color(0xFF4E6268),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              _formatPercentage(student.percentage),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3D555B),
              ),
            ),
          ),
          SizedBox(
            width: 112,
            child: _buildStatusChipCell(student, statusStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactQrActionButton() {
    final canOpen = _qrSession != null && _qrData.isNotEmpty && !_isLoadingQr;
    return OutlinedButton.icon(
      onPressed: _isLoadingQr
          ? null
          : () {
              if (!canOpen) {
                _showMethodSnack(
                  _tr(
                    'جاري تجهيز رمز QR، حاول مرة أخرى بعد لحظات.',
                    'QR is still loading, please try again shortly.',
                  ),
                  error: true,
                );
                return;
              }
              _showQrPopup();
            },
      icon: const Icon(Icons.qr_code_rounded, size: 18),
      label: Text(_tr('عرض رمز التحضير', 'Show QR Code')),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF006571),
        side: const BorderSide(color: Color(0xFFD5E0E3)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _showQrPopup() async {
    if (!mounted || _qrSession == null || _qrData.isEmpty) return;
    bool dialogOpen = true;
    bool timerBound = false;
    String? dialogError;
    int countdown = _qrAutoRefreshSecondsLeft;
    bool popupRefreshing = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: const Color(0xFFFAFDFD),
          surfaceTintColor: Colors.transparent,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              if (!timerBound) {
                timerBound = true;
                _startQrAutoRefreshTimer(
                  onTick: (secondsLeft) {
                    if (!dialogOpen) return;
                    countdown = secondsLeft;
                    setDialogState(() {});
                  },
                  onError: (message) {
                    if (!dialogOpen) return;
                    dialogError = message;
                    setDialogState(() {});
                  },
                  onRefreshStateChanged: (refreshing) {
                    if (!dialogOpen) return;
                    popupRefreshing = refreshing;
                    setDialogState(() {});
                  },
                );
              }
              final expiresText = _qrSession!.expiresAt.toLocal().toString();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _tr('التحضير عبر QR', 'QR Attendance'),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2E33),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'MUHADIR | Umm Al-Qura University',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5A6F76),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tr(
                        'امسحي الرمز من تطبيق الطالب لتسجيل الحضور',
                        'Scan from student app to mark attendance',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: Color(0xFF5A6F76),
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        dialogError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD14A4A),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF006571),
                          width: 1.8,
                        ),
                      ),
                      child: QrImageView(
                        data: _qrData,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_tr('ينتهي', 'Expires')}: $expiresText',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: Color(0xFF5A6F76),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (popupRefreshing)
                      Text(
                        _tr('جاري تحديث الرمز...', 'Refreshing QR code...'),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF006571),
                        ),
                      )
                    else
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: Color(0xFF5A6F76),
                          ),
                          children: [
                            TextSpan(
                              text: _tr(
                                'يتجدد تلقائيًا خلال: ',
                                'Auto refresh in: ',
                              ),
                            ),
                            TextSpan(
                              text: '$countdown',
                              style: const TextStyle(
                                color: Color(0xFF006571),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(text: _tr(' ثانية', 's')),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _isRefreshingQrToken
                                ? null
                                : () async {
                                    dialogError = null;
                                    popupRefreshing = true;
                                    setDialogState(() {});
                                    final ok = await _refreshQrSessionToken(
                                      showErrorSnack: false,
                                    );
                                    if (mounted) {
                                      popupRefreshing = false;
                                      _qrAutoRefreshSecondsLeft =
                                          _qrAutoRefreshIntervalSeconds;
                                      countdown = _qrAutoRefreshSecondsLeft;
                                      if (!ok) {
                                        dialogError = _tr(
                                          'فشل تحديث رمز QR. حاولي مرة أخرى.',
                                          'Failed to refresh QR. Try again.',
                                        );
                                      }
                                      setDialogState(() {});
                                    }
                                  },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(_tr('تحديث QR', 'Refresh QR')),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF006571),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text(_tr('إغلاق', 'Close')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
    dialogOpen = false;
    _stopQrAutoRefreshTimer();
  }

  /// خلية الحالة: عرض ثابت. الطالب المحروم (صفه أحمر) غير قابل لتعديل الحالة؛ رمز Sync لـ Pending sync؛ الضغط = منتقي الحالة.
  Widget _buildStatusChipCell(_StudentRow student, _StatusStyle? statusStyle) {
    final effectiveStyle =
        statusStyle ?? _statusStyle(AttendanceStatus.present);
    final effectiveStatus = _effectiveStatus(student);
    final showSync = student.isOffline;
    final chipLabel = effectiveStyle.chipLabel;
    final statusIcon = _statusIcon(effectiveStatus);
    final isSuspended = student.isSuspended ?? false;
    final VoidCallback onChipTap = _effectiveViewOnly
        ? () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _tr(
                  'عرض فقط — لا يمكن تعديل الحضور.',
                  'View only — attendance cannot be edited.',
                ),
              ),
            ),
          )
        : (isSuspended
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _tr(
                        'لا يمكن تعديل حالة المحروم.',
                        'Suspended status cannot be changed.',
                      ),
                    ),
                  ),
                )
              : () => _showStatusPicker(student));
    return _statusChip(
      chipLabel,
      effectiveStyle.bg,
      effectiveStyle.fg,
      icon: statusIcon,
      showSync: showSync,
      onSyncTap: showSync ? _showPendingSyncSnack : null,
      onChipTap: onChipTap,
    );
  }

  void _showPendingSyncSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _tr(
            'تم تسجيل الحضور دون اتصال. سيُحدَّث السجل تلقائياً عند عودة الإنترنت.',
            'Attendance was recorded offline. The record will update automatically when online.',
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Chip بحجم مناسب وتباعد عن الأعمدة المجاورة (داخل عمود بعرض ثابت).
  Widget _statusChip(
    String label,
    Color bg,
    Color fg, {
    required IconData icon,
    bool showSync = false,
    VoidCallback? onSyncTap,
    required VoidCallback onChipTap,
  }) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showSync && onSyncTap != null)
            Tooltip(
              message: _tr(
                'تسجيل دخول دون اتصال — سيتم التحديث عند المزامنة',
                'Checked in offline — will update when synced',
              ),
              child: GestureDetector(
                onTap: onSyncTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 2),
                  child: Icon(
                    Icons.sync_rounded,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ),
          if (showSync && onSyncTap != null) const SizedBox(width: 4),
          Tooltip(
            message: label,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onChipTap,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Icon(icon, size: 16, color: fg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.pending:
        return Icons.schedule_rounded;
      case AttendanceStatus.present:
        return Icons.check_rounded;
      case AttendanceStatus.absent:
        return Icons.close_rounded;
      case AttendanceStatus.excused:
        return Icons.fact_check_rounded;
      case AttendanceStatus.late:
        return Icons.access_time_filled_rounded;
    }
  }

  /// حفظ = Primary، معاينة الأعذار = Secondary. في وضع العرض فقط لا يظهر زر الحفظ.
  Widget _buildBottomButtons() {
    const height = 48.0;
    const radius = 14.0;
    const gap = 12.0;
    final hasChanges = _hasPendingChanges;
    final canTap = !_isSaving;

    if (_effectiveViewOnly) {
      return SizedBox(
        height: height,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openPreviewExcuses,
            borderRadius: BorderRadius.circular(radius),
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: const Color(0xFFD4E5E8)),
              ),
              child: Text(
                _tr('معاينة الأعذار', 'Preview Excuses'),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF222222),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canTap ? _saveChanges : null,
              borderRadius: BorderRadius.circular(radius),
              child: Container(
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: (hasChanges && canTap)
                      ? const LinearGradient(
                          colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  color: (hasChanges && canTap)
                      ? null
                      : const Color(0xFFE3E8EA),
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: (hasChanges && canTap)
                      ? [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF006571),
                          ),
                        ),
                      )
                    : Text(
                        _tr('حفظ', 'Save'),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: (hasChanges && canTap)
                              ? Colors.white
                              : const Color(0xFF92A2A7),
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: gap),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openPreviewExcuses,
              borderRadius: BorderRadius.circular(radius),
              child: Container(
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: const Color(0xFFD4E5E8)),
                ),
                child: Text(
                  _tr('معاينة الأعذار', 'Preview Excuses'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showStatusPicker(_StudentRow student) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final maxSheetHeight = MediaQuery.of(ctx).size.height * 0.7;
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr('تعديل حالة الطالب', 'Edit student status'),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF213236),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...AttendanceStatus.values.map((status) {
                      final style = _statusStyle(status);
                      final selected = _effectiveStatus(student) == status;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            _setDraftStatus(student.academicNumber, status);
                            Navigator.of(ctx).pop();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: style.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? style.fg
                                    : style.fg.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              style.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.w800,
                                color: style.fg,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  AttendanceStatusFilter _statusToFilter(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.pending:
        return AttendanceStatusFilter.all;
      case AttendanceStatus.present:
        return AttendanceStatusFilter.present;
      case AttendanceStatus.absent:
        return AttendanceStatusFilter.absent;
      case AttendanceStatus.excused:
        return AttendanceStatusFilter.excused;
      case AttendanceStatus.late:
        return AttendanceStatusFilter.late;
    }
  }

  _StatusStyle _statusStyle(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.pending:
        return _StatusStyle(
          label: _tr('بانتظار التحضير', 'Pending attendance'),
          chipLabel: _tr('بانتظار', 'Pending'),
          bg: const Color(0xFFECEFF0),
          fg: const Color(0xFF6F7D82),
          activeBg: const Color(0xFF6F7D82),
        );
      case AttendanceStatus.present:
        return _StatusStyle(
          label: _tr('حاضر', 'Present'),
          chipLabel: _tr('حاضر', 'Present'),
          bg: const Color(0xFFDFF4E5),
          fg: const Color(0xFF2B9E56),
          activeBg: const Color(0xFF2B9E56),
        );
      case AttendanceStatus.absent:
        return _StatusStyle(
          label: _tr('غائب', 'Absent'),
          chipLabel: _tr('غائب', 'Absent'),
          bg: const Color(0xFFFDE1E1),
          fg: const Color(0xFFD14A4A),
          activeBg: const Color(0xFFD14A4A),
        );
      case AttendanceStatus.excused:
        return _StatusStyle(
          label: _tr('غياب بعذر', 'Excused'),
          chipLabel: _tr('بعذر', 'Excused'),
          bg: const Color(0xFFFFF3D6),
          fg: const Color(0xFFC78A1E),
          activeBg: const Color(0xFFC78A1E),
        );
      case AttendanceStatus.late:
        return _StatusStyle(
          label: _tr('تأخر', 'Late'),
          chipLabel: _tr('تأخر', 'Late'),
          bg: const Color(0xFFE3EEFF),
          fg: const Color(0xFF3E73C9),
          activeBg: const Color(0xFF3E73C9),
        );
    }
  }

  _StatusStyle _filterStyle(AttendanceStatusFilter filter) {
    switch (filter) {
      case AttendanceStatusFilter.all:
        return _StatusStyle(
          label: _tr('الكل', 'All'),
          chipLabel: _tr('الكل', 'All'),
          bg: const Color(0xFFECEFF0),
          fg: const Color(0xFF6F7D82),
          activeBg: const Color(0xFF6F7D82),
        );
      case AttendanceStatusFilter.present:
        return _statusStyle(AttendanceStatus.present);
      case AttendanceStatusFilter.absent:
        return _statusStyle(AttendanceStatus.absent);
      case AttendanceStatusFilter.excused:
        return _statusStyle(AttendanceStatus.excused);
      case AttendanceStatusFilter.late:
        return _statusStyle(AttendanceStatus.late);
    }
  }
}

enum AttendanceStatusFilter { all, present, excused, absent, late }

enum AttendanceStatus { pending, present, absent, excused, late }

enum AttendanceMethod { nfc, qr, manual }

class _StudentRow {
  _StudentRow({
    required this.id,
    required this.name,
    required this.academicNumber,
    required this.attendanceTime,
    required this.percentage,
    required this.status,
    this.isOffline = false,
    this.isSuspended = false,
  });

  final String id;
  final String name;
  final String academicNumber;
  String attendanceTime;
  int percentage;
  AttendanceStatus status;
  final bool isOffline;

  /// عندما true يُلوّن صف الطالب بالأحمر فقط — لا توجد حالة "محروم" في الحالات (حاضر/غائب/غياب بعذر/تأخر).
  /// nullable للتوافق مع Hot Reload عند وجود نسخ قديمة من الصفوف.
  final bool? isSuspended;

  // NOTE: This payload does not currently include cumulative absence count
  // or threshold flags, so FR-L22 threshold highlighting cannot be derived
  // safely in this screen without adding a new data source.
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.chipLabel,
    required this.bg,
    required this.fg,
    required this.activeBg,
  });

  final String label;

  /// نص مختصر داخل الـ chip (مثلاً "بعذر")؛ الفلتر يبقى label كامل ("غياب بعذر")
  final String chipLabel;
  final Color bg;
  final Color fg;

  /// لون خلفية الفلتر عند التفعيل (للتباين مع النص الأبيض)
  final Color activeBg;
}
