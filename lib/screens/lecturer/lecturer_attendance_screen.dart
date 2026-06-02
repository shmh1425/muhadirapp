import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/attendance/bluetooth_attendance_session.dart';
import '../../models/attendance/manual_attendance_record.dart';
import '../../models/attendance/manual_attendance_session.dart';
import '../../models/external_student.dart';
import '../../models/attendance/nfc_attendance_session.dart';
import '../../models/attendance/qr_attendance_session.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../services/attendance/attendance_session_export_service.dart';
import '../../widgets/lecturer/attendance_export_format_picker.dart';
import '../../services/attendance/bluetooth_attendance_service.dart';
import '../../services/attendance/bluetooth_ble_service.dart';
import '../../features/attendance/attendance_entry_point.dart';
import '../../features/attendance/state/attendance_operation_ui_state.dart';
import '../../features/attendance/state/attendance_state_event.dart';
import '../../features/attendance/state/attendance_state_service.dart';
import '../../features/attendance/state/attendance_sync_event_router.dart';
import '../../services/attendance/lecturer_attendance_session_ui_cache.dart';
import '../../services/attendance/manual_attendance_offline_service.dart';
import '../../services/attendance/manual_attendance_service.dart';
import '../../services/attendance/nfc_attendance_service.dart';
import '../../services/attendance/qr_attendance_service.dart';
import '../../services/attendance/attendance_student_card_calculator.dart';
import '../../services/attendance/student_section_absence_service.dart';
import '../../repositories/lecturer_catalog_repository.dart';
import '../../services/lecturer_auth_service.dart';
import '../../services/lecturer/lecture_repository.dart';
import '../../services/lecturer/calendar_sync_service.dart';
import '../../utils/lecturer_attendance_eligibility.dart';
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
  static const List<AttendanceStatusFilter> _filterMenuOrder = [
    AttendanceStatusFilter.all,
    AttendanceStatusFilter.present,
    AttendanceStatusFilter.absent,
    AttendanceStatusFilter.excused,
    AttendanceStatusFilter.late,
  ];

  final ManualAttendanceService _manualAttendanceService =
      ManualAttendanceService.instance;
  final LectureRepository _calendarRepository = LectureRepository();
  final NfcAttendanceService _nfcAttendanceService =
      NfcAttendanceService.instance;
  final QrAttendanceService _qrAttendanceService = QrAttendanceService.instance;
  final BluetoothAttendanceService _bluetoothAttendanceService =
      BluetoothAttendanceService.instance;
  final BluetoothBleService _bluetoothBleService = BluetoothBleService.instance;
  StreamSubscription<List<ManualAttendanceRecord>>? _recordsSubscription;
  StreamSubscription<void>? _calendarSyncSub;
  StreamSubscription<List<NfcAttendanceSession>>? _nfcSessionsSubscription;
  StreamSubscription<AttendanceStateEvent>? _attendanceStateEventsSub;

  String? _sessionId;
  List<_StudentRow> _students = <_StudentRow>[];
  AttendanceStatusFilter _statusFilter = AttendanceStatusFilter.all;
  Map<String, AttendanceStatus> _draftStatuses = {};
  bool _hasPendingChanges = false;
  bool _isSaving = false;
  bool _isExporting = false;
  bool _isLoadingAttendance = true;
  String? _attendanceLoadError;
  LecturerAttendanceEligibilityResult? _attendanceStartEligibilityResult;
  bool _isCheckingAttendanceStartEligibility = false;
  DateTime? _calendarReferenceDate;
  bool _isSyncRefreshing = false;
  AttendanceMethod _selectedMethod = AttendanceMethod.manual;
  bool _isProcessingMethodAction = false;
  bool _isNfcActiveForLecture = false;
  String? _methodStatusMessage;
  bool _syncCompletionSnackArmed = false;
  QrAttendanceSession? _qrSession;
  String _qrData = '';
  bool _isLoadingQr = false;
  bool _isRefreshingQrToken = false;
  BluetoothAttendanceSession? _bluetoothSession;
  bool _isLoadingBluetooth = false;
  bool _isClosingBluetoothSession = false;
  bool _isStartingBluetoothBroadcast = false;
  bool _isStoppingBluetoothBroadcast = false;
  BluetoothBroadcastState _bluetoothBroadcastState =
      BluetoothBroadcastState.idle;
  String? _bluetoothBroadcastMessage;
  bool _isUsingRosterFallback = false;
  bool _sessionExistsForEditing = false;
  Map<int, ExternalStudent> _studentProfiles = {};

  /// Overall section absence metrics per student (same logic as student attendance tracking).
  Map<int, StudentSectionAbsenceMetrics> _absenceMetricsByStudentId =
      <int, StudentSectionAbsenceMetrics>{};

  static const Color _deprivedRowBackground = Color(0xFFFFEBEE);
  static const Color _deprivedRowAccent = Color(0xFFC62828);
  Timer? _qrAutoRefreshTimer;
  Timer? _bluetoothTokenTimer;
  Timer? _pendingFinalizeTimer;
  static const int _qrAutoRefreshIntervalSeconds = 30;
  int _qrAutoRefreshSecondsLeft = _qrAutoRefreshIntervalSeconds;
  String? _autoActivatedQrSessionId;

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  String get _displayCourseTitle {
    final sectionId = (_lecture.sectionId ?? '').trim();
    final lecturerId =
        LecturerAuthService.instance.currentLecturer?.lecturerId.trim() ?? '';
    if (sectionId.isNotEmpty && lecturerId.isNotEmpty) {
      final catalog = LecturerCatalogRepository.instance.getCachedCatalog(
        lecturerId,
      );
      if (catalog != null) {
        for (final row in catalog.rows) {
          if (row.sectionId.trim() == sectionId) {
            return row
                .toLectureItem(isArabic: LecturerLanguageController.isArabic)
                .courseName;
          }
        }
      }
    }
    return _lecture.courseName;
  }

  LectureItem get _lecture => widget.lecture;
  bool get _viewOnly => widget.viewOnly;
  DateTime? get _selectedDate => widget.selectedDate;
  String? get _providedSessionId => widget.sessionId;
  bool get _effectiveViewOnly => _viewOnly;
  bool get _canStartAttendanceNow =>
      !_effectiveViewOnly &&
      !_isCheckingAttendanceStartEligibility &&
      (_attendanceStartEligibilityResult?.canTakeAttendance ?? false);
  bool get _canEditAttendanceNow =>
      !_effectiveViewOnly &&
      (_sessionExistsForEditing || _canStartAttendanceNow);

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

  /// هل يوجد طلاب بحالة مزامنة نشطة (pending / syncing / failed)؟
  bool get _hasPendingSyncStudents => _students.any(
    (s) =>
        s.uiSyncState == AttendanceUIState.pending ||
        s.uiSyncState == AttendanceUIState.syncing ||
        s.uiSyncState == AttendanceUIState.failed ||
        s.isOffline,
  );

  Map<int, ManualAttendanceStatus> _firestoreStatusMap() {
    final map = <int, ManualAttendanceStatus>{};
    for (final s in _students) {
      final id = int.tryParse(s.academicNumber);
      if (id == null) continue;
      map[id] = _manualStatusFromUi(s.status);
    }
    return map;
  }

  void _attachAttendanceUiSyncListener(String sessionId) {
    _attendanceStateEventsSub?.cancel();
    AttendanceSyncEventRouter.instance.attachSession(
      sessionId: sessionId,
      firestoreMapBuilder: () async => _firestoreStatusMap(),
    );
    _attendanceStateEventsSub = AttendanceStateService
        .instance
        .attendanceStateEvents
        .listen(_onAttendanceStateEvent);
  }

  void _onAttendanceStateEvent(AttendanceStateEvent event) {
    if (!mounted) return;
    final sessionId = _sessionId?.trim() ?? '';
    if (sessionId.isEmpty) return;
    _patchStudentUiState(
      studentId: event.studentId,
      uiSyncState: event.model.state,
    );
  }

  void _patchStudentUiState({
    required String studentId,
    required AttendanceUIState uiSyncState,
  }) {
    final hadPendingSyncBefore = _hasPendingSyncStudents;
    final showSync =
        uiSyncState == AttendanceUIState.pending ||
        uiSyncState == AttendanceUIState.syncing ||
        uiSyncState == AttendanceUIState.failed;
    setState(() {
      _students = _students.map((s) {
        if (s.academicNumber != studentId) return s;
        if (showSync == s.isOffline && uiSyncState == s.uiSyncState) return s;
        return _StudentRow(
          id: s.id,
          name: s.name,
          academicNumber: s.academicNumber,
          attendanceTime: s.attendanceTime,
          percentage: s.percentage,
          status: s.status,
          isOffline: showSync,
          uiSyncState: uiSyncState,
          isSuspended: s.isSuspended,
          isAcademicallyDeprived: s.isAcademicallyDeprived,
        );
      }).toList();
    });
    _maybeShowSyncCompletedSnack(
      hadPendingSyncBefore: hadPendingSyncBefore,
      hasPendingSyncAfter: _hasPendingSyncStudents,
    );
    _persistSessionCache(_sessionId?.trim() ?? '');
  }

  /// Sync all rows from service (e.g. after Firestore stream refresh).
  void _applyPendingSyncFlagsFromQueue() {
    final sessionId = _sessionId?.trim() ?? '';
    if (sessionId.isEmpty || !mounted) return;
    final hadPendingSyncBefore = _hasPendingSyncStudents;
    setState(() {
      _students = _students.map((s) {
        final model = AttendanceStateService.instance.stateFor(
          sessionId: sessionId,
          studentId: s.academicNumber,
        );
        final uiSyncState = model?.state ?? AttendanceUIState.idle;
        final showSync =
            uiSyncState == AttendanceUIState.pending ||
            uiSyncState == AttendanceUIState.syncing ||
            uiSyncState == AttendanceUIState.failed;
        if (showSync == s.isOffline && uiSyncState == s.uiSyncState) return s;
        return _StudentRow(
          id: s.id,
          name: s.name,
          academicNumber: s.academicNumber,
          attendanceTime: s.attendanceTime,
          percentage: s.percentage,
          status: s.status,
          isOffline: showSync,
          uiSyncState: uiSyncState,
          isSuspended: s.isSuspended,
          isAcademicallyDeprived: s.isAcademicallyDeprived,
        );
      }).toList();
    });
    _maybeShowSyncCompletedSnack(
      hadPendingSyncBefore: hadPendingSyncBefore,
      hasPendingSyncAfter: _hasPendingSyncStudents,
    );
    _persistSessionCache(sessionId);
  }

  void _maybeShowSyncCompletedSnack({
    required bool hadPendingSyncBefore,
    required bool hasPendingSyncAfter,
  }) {
    if (!mounted) return;

    // Arm once we have any pending/syncing/failed rows, then show exactly once
    // when all of them are cleared for the current session.
    if (hasPendingSyncAfter) {
      _syncCompletionSnackArmed = true;
      return;
    }

    if (hadPendingSyncBefore &&
        !hasPendingSyncAfter &&
        _syncCompletionSnackArmed) {
      _syncCompletionSnackArmed = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'تمت مزامنة التحضير بنجاح.',
              'Attendance sync completed successfully.',
            ),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF2B9E56),
        ),
      );
    }
  }

  void _persistSessionCache(String sessionId) {
    final key = sessionId.trim();
    if (key.isEmpty || _students.isEmpty) return;
    LecturerAttendanceSessionUiCache.instance.put(
      sessionId: key,
      students: _students.map(_snapshotFromRow).toList(),
      rosterFallback: _isUsingRosterFallback,
    );
  }

  LecturerCachedStudentRow _snapshotFromRow(_StudentRow row) {
    return LecturerCachedStudentRow(
      id: row.id,
      name: row.name,
      academicNumber: row.academicNumber,
      attendanceTime: row.attendanceTime,
      percentage: row.percentage,
      statusName: row.status.name,
      isOffline: row.isOffline,
      uiSyncStateName: row.uiSyncState.name,
      isAcademicallyDeprived: row.isAcademicallyDeprived,
      isSuspended: row.isSuspended,
    );
  }

  _StudentRow _rowFromSnapshot(LecturerCachedStudentRow cached) {
    final status = AttendanceStatus.values.firstWhere(
      (s) => s.name == cached.statusName,
      orElse: () => AttendanceStatus.pending,
    );
    final uiSyncState = AttendanceUIState.values.firstWhere(
      (s) => s.name == cached.uiSyncStateName,
      orElse: () => AttendanceUIState.idle,
    );
    return _applyAbsenceMetricsToRow(
      _StudentRow(
        id: cached.id,
        name: cached.name,
        academicNumber: cached.academicNumber,
        attendanceTime: cached.attendanceTime,
        percentage: cached.percentage,
        status: status,
        isOffline: cached.isOffline,
        uiSyncState: uiSyncState,
        isSuspended: cached.isSuspended,
        isAcademicallyDeprived: cached.isAcademicallyDeprived,
      ),
    );
  }

  ({
    String sessionId,
    String sectionId,
    DateTime targetDate,
    bool hasProvidedSession,
  })
  _resolveSessionContext() {
    final sectionId = (_lecture.sectionId ?? '').trim();
    final targetDate = _sessionDate;
    final providedSessionId = _providedSessionId?.trim() ?? '';
    final sessionId = providedSessionId.isNotEmpty
        ? providedSessionId
        : ManualAttendanceService.buildSessionId(
            sectionId: sectionId,
            sessionDate: targetDate,
            lectureStartTime: _lecture.startTime,
          );
    return (
      sessionId: sessionId,
      sectionId: sectionId,
      targetDate: targetDate,
      hasProvidedSession: providedSessionId.isNotEmpty,
    );
  }

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
    if (!_sessionExistsForEditing && !_canStartAttendanceNow) {
      final latest = await _refreshAttendanceStartEligibility();
      if (latest == null || !latest.canTakeAttendance) {
        if (!mounted) return;
        _showMethodSnack(_editBlockedMessage(latest), error: true);
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final updates = <int, ManualAttendanceStatus>{};
      for (final entry in _draftStatuses.entries) {
        final studentId = int.tryParse(entry.key);
        if (studentId == null) continue;
        updates[studentId] = _manualStatusFromUi(entry.value);
      }
      final preparedSessionId = _sessionExistsForEditing
          ? sessionId
          : await _manualAttendanceService.prepareSessionForLecture(
              lecture: _lecture,
              sessionDate: _sessionDate,
            );
      if (mounted) {
        _sessionId = preparedSessionId;
        _sessionExistsForEditing = true;
      }

      await AttendanceEntryPoint.submitManualBatch(
        sessionId: preparedSessionId,
        courseId: _lecture.crn.trim(),
        updates: updates,
      );

      if (!mounted) return;

      setState(() {
        for (final s in _students) {
          final updated = _draftStatuses[s.academicNumber];
          if (updated != null) {
            s.status = updated;
            s.attendanceTime = _timeTextForStatus(updated);
          }
        }
        _draftStatuses = {};
        _hasPendingChanges = false;
      });
      _applyPendingSyncFlagsFromQueue();
      _persistSessionCache(preparedSessionId);
      if (!mounted) return;
      unawaited(
        ManualAttendanceOfflineService.instance
            .triggerBackgroundSyncIfPossible(),
      );
      unawaited(_refreshSectionAbsencePercents());

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
    } on LecturerAttendanceBlockedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editBlockedMessage(e.result)),
          backgroundColor: const Color(0xFFD32F2F),
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

  Future<void> _exportSession() async {
    if (!_exportButtonEnabled) {
      if (!_effectiveViewOnly && _hasPendingChanges) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _tr(
                'يرجى حفظ تعديلات الحضور قبل التصدير.',
                'Save attendance changes before exporting.',
              ),
            ),
          ),
        );
      }
      return;
    }
    final sid = _sessionId!;
    final format = await showAttendanceExportFormatPicker(context);
    if (format == null || !mounted) return;

    setState(() => _isExporting = true);
    try {
      await AttendanceSessionExportService.instance.exportSessionAndShare(
        sid,
        format: format,
        isArabic: LecturerLanguageController.isArabic,
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
    LecturerLanguageController.notifier.addListener(_onLanguageChanged);
    _calendarSyncSub = CalendarSyncService.instance.watchChanges().listen(
      (_) => _handleRealtimeCalendarChange(),
    );
    _bootstrapAttendance();
  }

  void _onLanguageChanged() {
    if (!mounted || _students.isEmpty) return;
    setState(() {
      _students = _students
          .map(
            (row) => row.copyWith(
              name: _localizedStudentName(
                int.tryParse(row.academicNumber) ?? 0,
                row.name,
              ),
            ),
          )
          .toList();
    });
  }

  @override
  void dispose() {
    LecturerLanguageController.notifier.removeListener(_onLanguageChanged);
    _recordsSubscription?.cancel();
    _calendarSyncSub?.cancel();
    _nfcSessionsSubscription?.cancel();
    _stopQrAutoRefreshTimer();
    _stopBluetoothTokenTimer();
    _pendingFinalizeTimer?.cancel();
    _attendanceStateEventsSub?.cancel();
    // Keep [LecturerAttendanceSessionUiCache] so re-entry shows students immediately.
    AttendanceSyncEventRouter.instance.detach();
    _bluetoothBleService.stopAdvertisingSession();
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
    final ctx = _resolveSessionContext();
    if (ctx.sectionId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoadingAttendance = false;
        _attendanceLoadError = _tr(
          'لا يوجد معرف سكشن لهذه المحاضرة.',
          'Section id is missing for this lecture.',
        );
      });
      return;
    }

    final cached = LecturerAttendanceSessionUiCache.instance.snapshotFor(
      ctx.sessionId,
    );
    final restoredFromCache = cached != null && cached.students.isNotEmpty;
    ManualAttendanceSession? existingSession;
    try {
      existingSession = await _manualAttendanceService.getSessionById(
        ctx.sessionId,
      );
    } catch (_) {
      existingSession = null;
    }
    final sessionExistsForEditing = existingSession != null;

    if (restoredFromCache) {
      if (!mounted) return;
      setState(() {
        _sessionId = ctx.sessionId;
        _sessionExistsForEditing = sessionExistsForEditing;
        _attendanceStartEligibilityResult = null;
        _students = cached.students.map(_rowFromSnapshot).toList();
        _isUsingRosterFallback = cached.rosterFallback;
        _isLoadingAttendance = false;
        _attendanceLoadError = null;
      });
      _applyPendingSyncFlagsFromQueue();
      unawaited(_refreshSectionAbsencePercents());
    } else {
      setState(() {
        _attendanceStartEligibilityResult = null;
        _sessionExistsForEditing = sessionExistsForEditing;
        _isLoadingAttendance = true;
        _attendanceLoadError = null;
      });
    }
    unawaited(_refreshAttendanceStartEligibility(showReportOnlyNote: true));

    try {
      if (!mounted) return;
      if (!restoredFromCache) {
        unawaited(_refreshSectionAbsencePercents());
      }
      _attachSessionStream(ctx.sessionId);
      _refreshNfcStatusFromSessionId();
      await _maybeAutoActivateQrForScheduledLecture(ctx.sessionId);
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
    _attachAttendanceUiSyncListener(sessionId);
    _startPendingFinalizeTimer(sessionId);
    _recordsSubscription = _manualAttendanceService
        .watchSessionRecords(sessionId)
        .listen(
          (records) {
            if (!mounted) return;
            if (records.isNotEmpty) {
              setState(() {
                _sessionExistsForEditing = true;
                _students = records.map(_studentFromRecord).toList();
                if (_isUsingRosterFallback) {
                  _methodStatusMessage = null;
                }
                _isUsingRosterFallback = false;
                _isLoadingAttendance = false;
                _attendanceLoadError = null;
              });
              _persistSessionCache(sessionId);
              unawaited(
                _refreshStudentProfiles(records.map((r) => r.studentId)),
              );
              unawaited(_refreshSectionAbsencePercents());
              _applyPendingSyncFlagsFromQueue();
              return;
            }
            if (_students.isNotEmpty) {
              setState(() {
                _isLoadingAttendance = false;
                _attendanceLoadError = null;
              });
              unawaited(_loadFallbackRosterForSection(sessionId));
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

  void _startPendingFinalizeTimer(String sessionId) {
    _pendingFinalizeTimer?.cancel();
    unawaited(
      _manualAttendanceService.finalizeSessionPendingAsAbsent(sessionId),
    );
    _pendingFinalizeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final current = _sessionId?.trim() ?? '';
      if (current.isEmpty || current != sessionId) return;
      unawaited(
        _manualAttendanceService.finalizeSessionPendingAsAbsent(current),
      );
    });
  }

  Future<void> _loadFallbackRosterForSection(String sessionId) async {
    final sectionId = (_lecture.sectionId ?? '').trim();
    if (sectionId.isEmpty) return;
    if (_shouldSuppressRosterFallbackForEndedLecture) {
      if (!mounted || _sessionId != sessionId) return;
      setState(() {
        if (_students.isEmpty) {
          _sessionExistsForEditing = false;
          _isUsingRosterFallback = false;
          _methodStatusMessage = _tr(
            'لا توجد بيانات تحضير مسجلة لهذه المحاضرة.',
            'No attendance data is recorded for this lecture.',
          );
        }
      });
      return;
    }
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
        unawaited(_refreshStudentProfiles(roster.map((s) => s.studentId)));
        unawaited(_refreshSectionAbsencePercents());
        _isUsingRosterFallback = true;
        _methodStatusMessage = _tr(
          'تم عرض قائمة الطلاب من تسجيلات الشعبة (عرض فقط).',
          'Showing enrolled roster for preview mode.',
        );
      });
      _persistSessionCache(sessionId);
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

  Future<LecturerAttendanceEligibilityResult> _attendanceStartEligibility() {
    return _manualAttendanceService.checkAttendanceStartEligibility(
      lecture: _lecture,
      sessionDate: _sessionDate,
    );
  }

  Future<LecturerAttendanceEligibilityResult?>
  _refreshAttendanceStartEligibility({bool showReportOnlyNote = false}) async {
    if (_effectiveViewOnly) return null;
    if (mounted) {
      setState(() => _isCheckingAttendanceStartEligibility = true);
    }
    try {
      final result = await _attendanceStartEligibility();
      if (!mounted) return result;
      setState(() {
        _attendanceStartEligibilityResult = result;
        _isCheckingAttendanceStartEligibility = false;
        if (showReportOnlyNote && !result.canTakeAttendance) {
          _methodStatusMessage = _reportOnlyMessage(result);
        }
      });
      return result;
    } catch (_) {
      if (mounted) {
        setState(() => _isCheckingAttendanceStartEligibility = false);
      }
      return null;
    }
  }

  String _eligibilityMessage(LecturerAttendanceEligibilityResult result) {
    return LecturerLanguageController.isArabic
        ? result.messageAr
        : result.messageEn;
  }

  String _editBlockedMessage(LecturerAttendanceEligibilityResult? result) {
    if (result?.reason == LecturerAttendanceBlockReason.afterEnd) {
      return _tr(
        'انتهى وقت المحاضرة ولا يمكن تعديل التحضير.',
        'The lecture time has ended and attendance cannot be edited.',
      );
    }
    if (result == null) {
      return _tr(
        'جاري التحقق من صلاحية تعديل التحضير.',
        'Checking whether attendance can be edited.',
      );
    }
    return _eligibilityMessage(result);
  }

  String _reportOnlyMessage(LecturerAttendanceEligibilityResult result) {
    if (result.reason == LecturerAttendanceBlockReason.afterEnd) {
      return _tr(
        'انتهى وقت المحاضرة. يمكنك عرض تقرير التحضير فقط.',
        'The lecture time has ended. You can view the attendance report only.',
      );
    }
    return _eligibilityMessage(result);
  }

  void _showEditBlockedSnack() {
    _showMethodSnack(
      _editBlockedMessage(_attendanceStartEligibilityResult),
      error: true,
    );
  }

  void _showAttendanceBlockedSnack(LecturerAttendanceEligibilityResult result) {
    _showMethodSnack(_eligibilityMessage(result), error: true);
  }

  bool get _shouldSuppressRosterFallbackForEndedLecture {
    final sessionDay = DateTime(
      _sessionDate.year,
      _sessionDate.month,
      _sessionDate.day,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (sessionDay.isBefore(today)) return true;
    final result = LecturerAttendanceEligibility.evaluateForTimes(
      lectureDate: sessionDay,
      lectureStartTime: _lecture.startTime,
      lectureEndTime: _lecture.endTime,
      now: now,
      lectureStatus: null,
    );
    return result.reason == LecturerAttendanceBlockReason.afterEnd;
  }

  String get _emptyAttendanceTableMessage {
    if (_shouldSuppressRosterFallbackForEndedLecture) {
      return _tr(
        'لا توجد بيانات تحضير مسجلة لهذه المحاضرة.',
        'No attendance data is recorded for this lecture.',
      );
    }
    return _tr(
      'لا يوجد طلاب مسجلون في هذه الشعبة حتى الآن.',
      'No enrolled students found for this section yet.',
    );
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
    if (method != AttendanceMethod.bluetooth) {
      _stopBluetoothTokenTimer();
    }

    if (!mounted) return;
    setState(() {
      final blockedMessage =
          _attendanceStartEligibilityResult != null &&
              !_attendanceStartEligibilityResult!.canTakeAttendance
          ? _reportOnlyMessage(_attendanceStartEligibilityResult!)
          : null;
      _methodStatusMessage =
          blockedMessage ??
          switch (method) {
            AttendanceMethod.manual => _tr(
              'اضغط حفظ/تعديل الحضور لتفعيل التحضير اليدوي.',
              'Save or edit attendance to activate manual attendance.',
            ),
            AttendanceMethod.qr =>
              (_qrSession != null && _qrData.isNotEmpty)
                  ? _tr(
                      'جلسة QR جاهزة. يمكنك عرض رمز التحضير.',
                      'QR session is ready. You can show the attendance code.',
                    )
                  : _tr(
                      'اضغط زر "تفعيل التحضير عبر QR" لفتح الجلسة.',
                      'Tap "Activate QR attendance" to open the session.',
                    ),
            AttendanceMethod.nfc =>
              _isNfcActiveForLecture
                  ? _tr(
                      'التحضير عبر NFC نشط لهذه المحاضرة.',
                      'NFC attendance is active for this lecture.',
                    )
                  : _tr(
                      'اضغط زر "تفعيل NFC" لفتح الجلسة.',
                      'Tap "Enable NFC" to open the session.',
                    ),
            AttendanceMethod.bluetooth =>
              (_bluetoothSession != null)
                  ? _tr(
                      'جلسة البلوتوث جاهزة. يمكنك بدء البث.',
                      'Bluetooth session is ready. You can start broadcasting.',
                    )
                  : _tr(
                      'اضغط زر "فتح جلسة البلوتوث" قبل بدء البث.',
                      'Tap "Start Bluetooth Session" before broadcasting.',
                    ),
          };
      _isProcessingMethodAction = false;
    });
  }

  Widget _buildCompactNfcActionButton() {
    final isBusy = _isProcessingMethodAction;
    final isActive = _isNfcActiveForLecture;
    final canStart = _canStartAttendanceNow;
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton.icon(
        onPressed: isBusy || isActive || !canStart
            ? null
            : _openOrConfirmNfcForCurrentLecture,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF006571),
          disabledBackgroundColor: isActive
              ? const Color(0xFFB9D8D8)
              : const Color(0xFFE3E8EA),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(isActive ? Icons.check_circle_rounded : Icons.nfc_rounded),
        label: Text(
          isActive
              ? _tr('NFC مفعل', 'NFC Enabled')
              : _tr('تفعيل NFC', 'Enable NFC'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Future<void> _maybeAutoActivateQrForScheduledLecture(String sessionId) async {
    // Important: opening QR must be explicit by lecturer action.
    // Auto-activation previously opened attendance sessions implicitly.
    if (_effectiveViewOnly) return;
    if (_autoActivatedQrSessionId == sessionId) return;
    _autoActivatedQrSessionId = sessionId;
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
    } on LecturerAttendanceBlockedException catch (e) {
      _showAttendanceBlockedSnack(e.result);
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
            'فشل تحديث رمز QR. يرجى التأكد من الاتصال ثم المحاولة مجدداً.',
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
            'تعذر التحديث التلقائي لرمز QR. يرجى استخدام زر التحديث يدوياً.',
            'Automatic QR refresh failed. Please use the manual refresh button.',
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

  Future<void> _openOrConfirmBluetoothForCurrentLecture() async {
    final sectionId = (_lecture.sectionId ?? '').trim();
    if (sectionId.isEmpty) {
      _showMethodSnack(
        _tr(
          'لا يمكن فتح جلسة البلوتوث لعدم توفر sectionId للمحاضرة.',
          'Cannot start Bluetooth because sectionId is missing.',
        ),
        error: true,
      );
      return;
    }

    setState(() => _isLoadingBluetooth = true);
    try {
      final session = await _bluetoothAttendanceService
          .createOrGetSessionForLecture(
            lecture: _lecture,
            lectureDate: _sessionDate,
          );
      if (!mounted) return;
      setState(() {
        _bluetoothSession = session;
        _bluetoothBroadcastState = BluetoothBroadcastState.idle;
        _bluetoothBroadcastMessage ??= _tr(
          'اضغط على «بدء البث» لإرسال إشارة البلوتوث.',
          'Tap Start Broadcasting to send the Bluetooth signal.',
        );
        _methodStatusMessage = _tr(
          'جلسة البلوتوث نشطة لهذه المحاضرة.',
          'Bluetooth session active for this lecture.',
        );
      });
      _startBluetoothTokenTimer();
    } on LecturerAttendanceBlockedException catch (e) {
      _showAttendanceBlockedSnack(e.result);
    } on BluetoothAttendanceException catch (e) {
      _showMethodSnack(_mapBluetoothError(e), error: true);
    } on FirebaseException catch (e) {
      final message = e.code == 'permission-denied'
          ? _tr(
              'تعذر فتح جلسة البلوتوث: لا توجد صلاحية للوصول إلى Firestore.',
              'Failed to start Bluetooth session: Firestore permission denied.',
            )
          : _tr(
              'تعذر فتح جلسة البلوتوث لهذه المحاضرة.',
              'Failed to start Bluetooth session for this lecture.',
            );
      _showMethodSnack(message, error: true);
    } catch (_) {
      _showMethodSnack(
        _tr(
          'طريقة التحضير عبر البلوتوث غير متاحة حالياً.',
          'Bluetooth attendance is currently unavailable.',
        ),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _isLoadingBluetooth = false);
    }
  }

  Future<void> _closeBluetoothSession() async {
    final session = _bluetoothSession;
    if (_isClosingBluetoothSession || session == null) return;

    setState(() => _isClosingBluetoothSession = true);
    try {
      await _stopBluetoothBroadcast();
      await _bluetoothAttendanceService.closeSession(session.sessionId);
      if (!mounted) return;
      _stopBluetoothTokenTimer();
      setState(() {
        _bluetoothSession = null;
        _bluetoothBroadcastState = BluetoothBroadcastState.idle;
        _bluetoothBroadcastMessage = null;
        _methodStatusMessage = _tr(
          'تم إغلاق جلسة البلوتوث.',
          'Bluetooth session closed.',
        );
      });
    } on FirebaseException catch (e) {
      final message = e.code == 'permission-denied'
          ? _tr(
              'تعذر إغلاق جلسة البلوتوث: لا توجد صلاحية للوصول إلى Firestore.',
              'Failed to close Bluetooth session: Firestore permission denied.',
            )
          : _tr(
              'تعذر إغلاق جلسة البلوتوث.',
              'Failed to close Bluetooth session.',
            );
      _showMethodSnack(message, error: true);
    } catch (_) {
      _showMethodSnack(
        _tr('تعذر إغلاق جلسة البلوتوث.', 'Failed to close Bluetooth session.'),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _isClosingBluetoothSession = false);
    }
  }

  Future<void> _startBluetoothBroadcast({bool showSnack = true}) async {
    final session = _bluetoothSession;
    if (session == null ||
        _isStartingBluetoothBroadcast ||
        _isStoppingBluetoothBroadcast ||
        _bluetoothBroadcastState == BluetoothBroadcastState.broadcasting) {
      return;
    }

    setState(() {
      _isStartingBluetoothBroadcast = true;
      _bluetoothBroadcastState = BluetoothBroadcastState.requestingPermission;
      _bluetoothBroadcastMessage = _tr(
        'جاري التحقق من صلاحيات البلوتوث...',
        'Checking Bluetooth permissions...',
      );
    });

    try {
      final result = await _bluetoothBleService.startAdvertisingSession(
        session,
      );
      if (!mounted) return;
      setState(() {
        _isStartingBluetoothBroadcast = false;
        _bluetoothBroadcastState = result.state;
        _bluetoothBroadcastMessage = _localizedBluetoothHardwareMessage(
          result.message,
          broadcasting: true,
        );
      });
      if (showSnack && !result.isBroadcasting) {
        _showMethodSnack(
          _bluetoothBroadcastMessage ?? result.message,
          error: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isStartingBluetoothBroadcast = false;
        _bluetoothBroadcastState = BluetoothBroadcastState.error;
        _bluetoothBroadcastMessage = _tr(
          'تعذر بدء البث',
          'Failed to start broadcast',
        );
      });
      if (showSnack) {
        _showMethodSnack(_bluetoothBroadcastMessage!, error: true);
      }
    }
  }

  Future<void> _stopBluetoothBroadcast() async {
    if (_isStoppingBluetoothBroadcast || _isStartingBluetoothBroadcast) return;
    setState(() => _isStoppingBluetoothBroadcast = true);
    try {
      await _bluetoothBleService.stopAdvertisingSession();
      if (!mounted) return;
      setState(() {
        _bluetoothBroadcastState = BluetoothBroadcastState.idle;
        _bluetoothBroadcastMessage = _tr('تم إيقاف البث', 'Broadcast stopped');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bluetoothBroadcastMessage = _tr(
          'تعذر إيقاف البث',
          'Failed to stop broadcast',
        );
      });
      _showMethodSnack(_bluetoothBroadcastMessage!, error: true);
    } finally {
      if (mounted) {
        setState(() => _isStoppingBluetoothBroadcast = false);
      } else {
        _isStoppingBluetoothBroadcast = false;
      }
    }
  }

  String _bluetoothBroadcastStatusLabel() {
    if (_isStartingBluetoothBroadcast ||
        _bluetoothBroadcastState ==
            BluetoothBroadcastState.requestingPermission) {
      return _tr('جاري بدء البث...', 'Starting broadcast...');
    }
    if (_isStoppingBluetoothBroadcast) {
      return _tr('جاري إيقاف البث...', 'Stopping broadcast...');
    }
    if (_bluetoothBroadcastMessage != null &&
        _bluetoothBroadcastMessage!.trim().isNotEmpty) {
      return _bluetoothBroadcastMessage!;
    }
    if (_bluetoothBroadcastState == BluetoothBroadcastState.broadcasting) {
      return _tr(
        'يتم بث إشارة البلوتوث الآن',
        'Bluetooth signal is broadcasting now',
      );
    }
    return _tr('جلسة البلوتوث غير نشطة', 'Bluetooth session inactive');
  }

  String _localizedBluetoothHardwareMessage(
    String message, {
    required bool broadcasting,
  }) {
    final lower = message.toLowerCase();
    if (lower.contains('web')) {
      return broadcasting
          ? _tr(
              'بث البلوتوث غير مدعوم على الويب في هذه المرحلة.',
              'Bluetooth broadcasting is not supported on web in this phase.',
            )
          : _tr(
              'مسح البلوتوث يتطلب جهازًا محمولًا مدعومًا.',
              'Bluetooth scanning requires a supported mobile device.',
            );
    }
    if (lower.contains('not supported')) {
      return broadcasting
          ? _tr(
              'بث البلوتوث غير مدعوم على هذا الجهاز في هذه المرحلة.',
              'Bluetooth broadcasting is not supported on this device in this phase.',
            )
          : _tr(
              'البلوتوث غير مدعوم على هذا الجهاز.',
              'Bluetooth is not supported on this device.',
            );
    }
    if (lower.contains('permission')) {
      return _tr(
        'يحتاج التطبيق إلى صلاحية البلوتوث للمتابعة.',
        'Bluetooth permission is required to continue.',
      );
    }
    if (lower.contains('turned off')) {
      return _tr('البلوتوث غير مفعّل.', 'Bluetooth is turned off.');
    }
    if (lower.contains('still getting ready') ||
        lower.contains('unable to start bluetooth broadcast')) {
      return _tr(
        'تعذر بدء بث البلوتوث. يرجى التأكد من تشغيل البلوتوث ثم المحاولة مرة أخرى.',
        'Unable to start Bluetooth broadcast. Make sure Bluetooth is on and try again.',
      );
    }
    if (lower.contains('active')) {
      return _tr('بث البلوتوث نشط الآن.', 'Bluetooth broadcast is active.');
    }
    return message;
  }

  void _startBluetoothTokenTimer() {
    _stopBluetoothTokenTimer();
    _bluetoothTokenTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted ||
          _selectedMethod != AttendanceMethod.bluetooth ||
          _bluetoothSession == null) {
        _stopBluetoothTokenTimer();
        return;
      }

      final sessionWindowLeft = _secondsUntilBluetoothSessionWindowClose();
      if (sessionWindowLeft <= 0) {
        unawaited(_closeBluetoothSession());
      }
    });
  }

  void _stopBluetoothTokenTimer() {
    _bluetoothTokenTimer?.cancel();
    _bluetoothTokenTimer = null;
  }

  int _secondsUntilBluetoothSessionWindowClose() {
    final session = _bluetoothSession;
    if (session == null) {
      return BluetoothAttendanceService.manualSessionOpenWindow.inSeconds;
    }
    final openedAt = session.openedAt ?? session.sessionOpenedAt;
    if (openedAt == null) {
      return BluetoothAttendanceService.manualSessionOpenWindow.inSeconds;
    }
    final closeAt = openedAt.add(
      BluetoothAttendanceService.manualSessionOpenWindow,
    );
    final remaining = closeAt.difference(DateTime.now()).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  String _mapBluetoothError(BluetoothAttendanceException error) {
    switch (error.code) {
      case BluetoothAttendanceErrorCode.missingLecturerSession:
        return _tr(
          'انتهت جلسة المحاضر. يرجى تسجيل الدخول من جديد.',
          'Lecturer session expired. Please log in again.',
        );
      case BluetoothAttendanceErrorCode.invalidInput:
        return _tr(
          'فشل فتح جلسة البلوتوث بسبب نقص بيانات المحاضرة.',
          'Failed to start Bluetooth because lecture data is incomplete.',
        );
      case BluetoothAttendanceErrorCode.sessionNotFound:
        return _tr(
          'تعذر العثور على جلسة البلوتوث.',
          'Bluetooth session was not found.',
        );
      case BluetoothAttendanceErrorCode.sessionClosed:
        return _tr('جلسة البلوتوث مغلقة', 'Bluetooth session is closed');
      case BluetoothAttendanceErrorCode.sessionExpired:
      case BluetoothAttendanceErrorCode.attendanceWindowClosed:
      case BluetoothAttendanceErrorCode.tokenMismatch:
        return _tr('انتهت صلاحية جلسة البلوتوث.', 'Bluetooth session expired.');
      case BluetoothAttendanceErrorCode.weakSignal:
      case BluetoothAttendanceErrorCode.studentNotEnrolled:
      case BluetoothAttendanceErrorCode.alreadyMarked:
      case BluetoothAttendanceErrorCode.unknown:
        return _tr(
          'تعذر فتح جلسة البلوتوث لهذه المحاضرة.',
          'Failed to start Bluetooth session for this lecture.',
        );
    }
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
    } on LecturerAttendanceBlockedException catch (e) {
      _showAttendanceBlockedSnack(e.result);
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

  String _localizedStudentName(int studentId, String snapshotName) {
    final profile = _studentProfiles[studentId];
    if (profile != null) {
      return profile.displayNameFor(LecturerLanguageController.isArabic);
    }
    final trimmed = snapshotName.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return studentId > 0 ? '$studentId' : _tr('غير متوفر', 'N/A');
  }

  StudentSectionAbsenceMetrics? _metricsForStudent(int studentId) =>
      _absenceMetricsByStudentId[studentId];

  int _overallAbsencePercentForStudent(int studentId) =>
      _metricsForStudent(studentId)?.displayPercentFloor ?? 0;

  bool _isAcademicallyDeprivedForStudent(int studentId) =>
      _metricsForStudent(studentId)?.isAcademicallyDeprived ?? false;

  /// Semester-wide absence % for this section (not the current lecture status).
  Future<void> _refreshSectionAbsencePercents() async {
    final sectionId = (_lecture.sectionId ?? '').trim();
    if (sectionId.isEmpty) return;
    final courseCode = _lecture.crn.trim();
    try {
      final map = await StudentSectionAbsenceService.instance
          .loadAbsenceMetricsByStudentId(
            sectionId: sectionId,
            courseCode: courseCode,
          );
      if (!mounted) return;
      setState(() {
        _absenceMetricsByStudentId = map;
        _students = _students
            .map((row) => _applyAbsenceMetricsToRow(row))
            .toList();
      });
    } catch (_) {
      // Keep previous percentages if the section query fails.
    }
  }

  _StudentRow _applyAbsenceMetricsToRow(_StudentRow row) {
    final studentId = int.tryParse(row.academicNumber) ?? 0;
    return row.copyWith(
      percentage: _overallAbsencePercentForStudent(studentId),
      isAcademicallyDeprived: _isAcademicallyDeprivedForStudent(studentId),
    );
  }

  Future<void> _refreshStudentProfiles(Iterable<int> studentIds) async {
    final ids = studentIds.where((id) => id > 0).toSet();
    if (ids.isEmpty) return;
    try {
      final profiles = await _manualAttendanceService.fetchStudentProfilesByIds(
        ids,
      );
      if (!mounted) return;
      setState(() {
        _studentProfiles = profiles;
        _students = _students
            .map(
              (row) => row.copyWith(
                name: _localizedStudentName(
                  int.tryParse(row.academicNumber) ?? 0,
                  row.name,
                ),
              ),
            )
            .toList();
      });
    } catch (_) {
      // Keep snapshot names if profile lookup fails.
    }
  }

  _StudentRow _studentFromRecord(ManualAttendanceRecord record) {
    final uiStatus = _uiStatusFromManual(record.status);
    final fallbackName = _localizedStudentName(
      record.studentId,
      record.studentName,
    );
    return _applyAbsenceMetricsToRow(
      _StudentRow(
        id: record.recordId,
        name: fallbackName,
        academicNumber: record.studentId.toString(),
        attendanceTime: record.attendanceTime.trim().isNotEmpty
            ? record.attendanceTime
            : _timeTextForStatus(uiStatus),
        percentage: 0,
        status: uiStatus,
        isOffline: false,
        isSuspended: false,
      ),
    );
  }

  _StudentRow _studentFromEnrollment(
    ManualEnrollmentStudent enrollment,
    String sessionId,
  ) {
    return _applyAbsenceMetricsToRow(
      _StudentRow(
        id: '${sessionId}_${enrollment.studentId}',
        name: _localizedStudentName(
          enrollment.studentId,
          enrollment.studentName,
        ),
        academicNumber: enrollment.studentId.toString(),
        attendanceTime: '--',
        percentage: 0,
        status: AttendanceStatus.pending,
        isOffline: false,
        isSuspended: false,
      ),
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
        final theme = Theme.of(context);
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                              child: _buildCompactQrActionButton(),
                            ),
                          if (_selectedMethod == AttendanceMethod.nfc)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                              child: _buildCompactNfcActionButton(),
                            ),
                          if (_selectedMethod == AttendanceMethod.bluetooth)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                              child: _buildBluetoothSessionPanel(),
                            ),
                          _buildSyncLegend(),
                          const SizedBox(height: 14),
                          _buildTableSection(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                            child: _buildBottomButtons(),
                          ),
                        ],
                      ),
                    ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activity = _lecture.activity.trim().toLowerCase();
    final isPractical = activity == 'عملي' || activity == 'lab';
    final activityLabel = isPractical
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
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          // زر الرجوع: نفس ProfileBackButton ويحترم RTL/LTR.
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
                        _displayCourseTitle,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
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
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
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
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
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
                          'يرجى حفظ التعديلات قبل التصدير.',
                          'Save changes before export.',
                        )
                      : _tr(
                          'تصدير حضور هذه الجلسة',
                          'Export this session attendance',
                        ),
                  child: IconButton(
                    onPressed: _isExporting
                        ? null
                        : _exportButtonEnabled
                        ? _exportSession
                        : (!_effectiveViewOnly && _hasPendingChanges)
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _tr(
                                    'يرجى حفظ تعديلات الحضور قبل التصدير.',
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final selectedStyle = _filterStyle(_statusFilter);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? scheme.outlineVariant.withValues(alpha: 0.45)
              : const Color(0xFFDCE6E8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.filter_alt_rounded,
                  size: 18,
                  color: selectedStyle.fg,
                ),
                const SizedBox(width: 8),
                Text(
                  _tr('الفلتر:', 'Filter:'),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: selectedStyle.bg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selectedStyle.fg.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      selectedStyle.chipLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: selectedStyle.fg,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<AttendanceStatusFilter>(
            tooltip: _tr('تغيير الفلتر', 'Change filter'),
            initialValue: _statusFilter,
            color: scheme.surface,
            surfaceTintColor: Colors.transparent,
            onSelected: (filter) => setState(() => _statusFilter = filter),
            itemBuilder: (context) => _filterMenuOrder.map((filter) {
              final style = _filterStyle(filter);
              return PopupMenuItem<AttendanceStatusFilter>(
                value: filter,
                child: Row(
                  children: [
                    Icon(
                      _statusFilter == filter
                          ? Icons.check_rounded
                          : Icons.circle_outlined,
                      size: 18,
                      color: _statusFilter == filter
                          ? style.fg
                          : const Color(0xFF8AA0A6),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        style.label,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark
                    ? scheme.surfaceContainerHighest
                    : const Color(0xFFF2F7F8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? scheme.outlineVariant.withValues(alpha: 0.45)
                      : const Color(0xFFD5E0E3),
                ),
              ),
              child: const Icon(
                Icons.tune_rounded,
                size: 20,
                color: Color(0xFF006571),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForAttendanceMethod(AttendanceMethod method) {
    switch (method) {
      case AttendanceMethod.nfc:
        return Icons.nfc_rounded;
      case AttendanceMethod.bluetooth:
        return Icons.bluetooth_rounded;
      case AttendanceMethod.qr:
        return Icons.qr_code_rounded;
      case AttendanceMethod.manual:
        return Icons.touch_app_rounded;
    }
  }

  String? _shortLabelForAttendanceMethod(AttendanceMethod method) {
    switch (method) {
      case AttendanceMethod.nfc:
        return 'NFC';
      case AttendanceMethod.qr:
        return 'QR';
      case AttendanceMethod.bluetooth:
        return _tr('بلوتوث', 'Bluetooth');
      case AttendanceMethod.manual:
        return null;
    }
  }

  Widget _buildMethodMenuItem({
    required AttendanceMethod method,
    required String label,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedMethod == method;
    return Row(
      children: [
        Icon(
          _iconForAttendanceMethod(method),
          size: 20,
          color: const Color(0xFF006571),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ),
        if (selected)
          const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: Color(0xFF006571),
          ),
      ],
    );
  }

  Widget _buildCompactMethodMenu() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    if (_effectiveViewOnly) {
      final short = _shortLabelForAttendanceMethod(_selectedMethod);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? scheme.surfaceContainerHighest
              : const Color(0xFFF2F5F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? scheme.outlineVariant.withValues(alpha: 0.45)
                : const Color(0xFFB0BEC5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconForAttendanceMethod(_selectedMethod),
              size: 18,
              color: const Color(0xFF455A64),
            ),
            const SizedBox(width: 6),
            Text(
              short ?? _tr('يدوي', 'Manual'),
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF37474F),
              ),
            ),
          ],
        ),
      );
    }

    final selectedShort = _shortLabelForAttendanceMethod(_selectedMethod);
    final isQrSelected = _selectedMethod == AttendanceMethod.qr;
    final label = selectedShort == null
        ? _tr('طريقة التحضير', 'Attendance method')
        : '${_tr('طريقة التحضير', 'Attendance method')} · $selectedShort';
    final accentColor = isQrSelected ? Colors.white : _primary;

    return PopupMenuButton<AttendanceMethod>(
      tooltip: _tr('اختيار طريقة التحضير', 'Select attendance method'),
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: _onSelectMethod,
      itemBuilder: (context) => [
        PopupMenuItem<AttendanceMethod>(
          value: AttendanceMethod.qr,
          child: _buildMethodMenuItem(
            method: AttendanceMethod.qr,
            label: _tr('التحضير عبر QR', 'QR Code'),
          ),
        ),
        PopupMenuItem<AttendanceMethod>(
          value: AttendanceMethod.nfc,
          child: _buildMethodMenuItem(
            method: AttendanceMethod.nfc,
            label: _tr('التحضير عبر NFC', 'NFC'),
          ),
        ),
        PopupMenuItem<AttendanceMethod>(
          value: AttendanceMethod.bluetooth,
          child: _buildMethodMenuItem(
            method: AttendanceMethod.bluetooth,
            label: _tr('التحضير عبر البلوتوث', 'Bluetooth Attendance'),
          ),
        ),
      ],
      child: Container(
        constraints: const BoxConstraints(maxWidth: 176),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          gradient: isQrSelected
              ? const LinearGradient(
                  colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: isQrSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isQrSelected ? null : Border.all(color: _primary, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: isQrSelected ? 0.18 : 0.12),
              blurRadius: isQrSelected ? 12 : 8,
              offset: Offset(0, isQrSelected ? 5 : 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconForAttendanceMethod(_selectedMethod),
              size: 18,
              color: accentColor,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: accentColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothSessionPanel() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final session = _bluetoothSession;
    final hasSession = session != null;
    final isBroadcasting =
        _bluetoothBroadcastState == BluetoothBroadcastState.broadcasting;
    final busy =
        _isLoadingBluetooth ||
        _isStartingBluetoothBroadcast ||
        _isStoppingBluetoothBroadcast ||
        _bluetoothBroadcastState ==
            BluetoothBroadcastState.requestingPermission;
    final canStart = _canStartAttendanceNow;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? scheme.outlineVariant.withValues(alpha: 0.45)
              : const Color(0xFFDCE8EA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isBroadcasting
                      ? const Color(0xFFE5F4F6)
                      : const Color(0xFFF1F6F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isBroadcasting
                      ? Icons.bluetooth_connected_rounded
                      : Icons.bluetooth_rounded,
                  color: const Color(0xFF006571),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBroadcasting
                          ? _tr(
                              'يتم بث إشارة البلوتوث الآن',
                              'Bluetooth signal is broadcasting now',
                            )
                          : !hasSession
                          ? _tr(
                              'جلسة البلوتوث غير مفتوحة',
                              'Bluetooth session is not open',
                            )
                          : _tr(
                              'جلسة البلوتوث غير نشطة',
                              'Bluetooth session inactive',
                            ),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _bluetoothBroadcastStatusLabel(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF006571),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: busy || (!isBroadcasting && !canStart)
                ? null
                : (!hasSession
                      ? _openOrConfirmBluetoothForCurrentLecture
                      : (isBroadcasting
                            ? _stopBluetoothBroadcast
                            : () => _startBluetoothBroadcast())),
            style: FilledButton.styleFrom(
              backgroundColor: isBroadcasting
                  ? const Color(0xFFD14A4A)
                  : const Color(0xFF006571),
              disabledBackgroundColor: const Color(0xFFB9C9CC),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    !hasSession
                        ? Icons.bluetooth_rounded
                        : isBroadcasting
                        ? Icons.bluetooth_disabled_rounded
                        : Icons.bluetooth_searching_rounded,
                    size: 18,
                  ),
            label: Text(
              !hasSession
                  ? _tr('فتح جلسة البلوتوث', 'Start Bluetooth Session')
                  : isBroadcasting
                  ? _tr('إيقاف البث', 'Stop Broadcast')
                  : _tr('بدء البث', 'Start Broadcast'),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// عنصر سكرول واحد: CustomScrollView مع هيدر الجدول + قائمة الطلاب كـ Slivers (لا فراغ بين الهيدر وأول صف).
  Widget _buildTableSection() {
    if (_isLoadingAttendance) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF006571)),
        ),
      );
    }
    if (_attendanceLoadError != null) {
      return SizedBox(
        height: 260,
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
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _attendanceLoadError!,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _resolveStudentsTableLayout(constraints.maxWidth);
          final tableWidth = layout.totalWidth;
          final needsHorizontalScroll = tableWidth > constraints.maxWidth + 0.5;

          Widget tableBody = _filteredStudents.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _allStudents.isEmpty
                          ? _emptyAttendanceTableMessage
                          : _tr(
                              'لا يوجد طلاب في هذا الفلتر.',
                              'No students in this filter.',
                            ),
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStudentsTableHeader(layout),
                    for (
                      var index = 0;
                      index < _filteredStudents.length;
                      index++
                    ) ...[
                      if (index > 0)
                        const Divider(height: 1, color: Color(0xFFE8EFF1)),
                      _buildStudentTableRow(
                        student: _filteredStudents[index],
                        statusStyle: _statusStyle(
                          _effectiveStatus(_filteredStudents[index]),
                        ),
                        index: index,
                        layout: layout,
                      ),
                    ],
                  ],
                );

          if (needsHorizontalScroll) {
            tableBody = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: tableWidth, child: tableBody),
            );
          }

          return Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.45)
                    : const Color(0xFFDDE6E8),
              ),
            ),
            child: tableBody,
          );
        },
      ),
    );
  }

  Widget _buildStudentsTableHeader(_StudentsTableLayout layout) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? scheme.surfaceContainerHighest : const Color(0xFFF1F6F7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: SizedBox(
        width: layout.contentWidth,
        child: Row(
          children: [
            SizedBox(
              width: layout.indexWidth,
              child: Text(
                '#',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(width: layout.columnGap),
            SizedBox(
              width: layout.studentWidth,
              child: Text(
                _tr('الطالب', 'Student'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(width: layout.columnGap),
            SizedBox(
              width: layout.idWidth,
              child: Text(
                _tr('الرقم', 'ID'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(width: layout.columnGap),
            SizedBox(
              width: layout.timeWidth,
              child: Text(
                _tr('الوقت', 'Time'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(width: layout.columnGap),
            SizedBox(
              width: layout.percentageWidth,
              child: Text(
                '%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(width: layout.columnGap),
            SizedBox(
              width: layout.statusWidth,
              child: Text(
                _tr('الحالة', 'Status'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentTableRow({
    required _StudentRow student,
    required _StatusStyle statusStyle,
    required int index,
    required _StudentsTableLayout layout,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeText = student.attendanceTime.trim().isEmpty
        ? '--'
        : student.attendanceTime.trim();
    final deprived = student.isAcademicallyDeprived;
    final suspended = student.isSuspended ?? false;
    final rowBackground = deprived || suspended
        ? _deprivedRowBackground
        : isDark
        ? (index.isEven ? scheme.surface : scheme.surfaceContainerHighest)
        : (index.isEven ? Colors.white : const Color(0xFFFBFDFD));
    return Container(
      color: rowBackground,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SizedBox(
        width: layout.contentWidth,
        child: Row(
          children: [
            SizedBox(
              width: layout.indexWidth,
              child: Text(
                '${index + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(width: layout.columnGap),
            SizedBox(
              width: layout.studentWidth,
              child: Text(
                student.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
            SizedBox(width: layout.columnGap),
            SizedBox(
              width: layout.idWidth,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  student.academicNumber,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            SizedBox(width: layout.columnGap),
            SizedBox(
              width: layout.timeWidth,
              child: Directionality(
                textDirection: TextDirection.ltr,
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
            ),
            SizedBox(width: layout.columnGap),
            SizedBox(
              width: layout.percentageWidth,
              child: Text(
                _formatPercentage(student.percentage),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: deprived
                      ? _deprivedRowAccent
                      : const Color(0xFF3D555B),
                ),
              ),
            ),
            SizedBox(width: layout.columnGap),
            SizedBox(
              width: layout.statusWidth,
              child: ClipRect(
                child: Align(
                  alignment: AlignmentDirectional.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _buildStatusChipCell(student, statusStyle),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _StudentsTableLayout _resolveStudentsTableLayout(double containerWidth) {
    const rowHorizontalPadding = 20.0;
    const layoutSlackPx = 2.0;
    const gapsCount = 5;
    final availableContentWidth =
        (containerWidth - rowHorizontalPadding - layoutSlackPx).clamp(
          0.0,
          double.infinity,
        );
    final isTight = availableContentWidth < 325;
    final columnGap = isTight ? 3.0 : 4.0;
    final indexWidth = isTight ? 22.0 : 24.0;
    final timeWidth = isTight ? 40.0 : 44.0;
    final percentageWidth = isTight ? 28.0 : 30.0;
    final statusWidth = isTight ? 64.0 : 70.0;
    final fixedNonText =
        indexWidth +
        timeWidth +
        percentageWidth +
        statusWidth +
        (columnGap * gapsCount);
    final availableForText = (availableContentWidth - fixedNonText).clamp(
      0.0,
      double.infinity,
    );
    final minStudentWidth = isTight ? 78.0 : 90.0;
    final minIdWidth = isTight ? 54.0 : 62.0;
    final textTotalMin = minStudentWidth + minIdWidth;
    final textTotal = availableForText < textTotalMin
        ? textTotalMin
        : availableForText;
    var studentWidth = (textTotal * 0.62).clamp(minStudentWidth, 190.0);
    var idWidth = (textTotal - studentWidth).clamp(minIdWidth, 120.0);
    var contentWidth =
        indexWidth +
        studentWidth +
        idWidth +
        timeWidth +
        percentageWidth +
        statusWidth +
        (columnGap * gapsCount);
    if (contentWidth > availableContentWidth) {
      var excess = contentWidth - availableContentWidth;
      final idShrinkable = (idWidth - minIdWidth).clamp(0.0, excess);
      idWidth -= idShrinkable;
      excess -= idShrinkable;
      if (excess > 0) {
        studentWidth = (studentWidth - excess).clamp(
          minStudentWidth,
          studentWidth,
        );
      }
      contentWidth =
          indexWidth +
          studentWidth +
          idWidth +
          timeWidth +
          percentageWidth +
          statusWidth +
          (columnGap * gapsCount);
    }
    return _StudentsTableLayout(
      columnGap: columnGap,
      indexWidth: indexWidth,
      studentWidth: studentWidth,
      idWidth: idWidth,
      timeWidth: timeWidth,
      percentageWidth: percentageWidth,
      statusWidth: statusWidth,
      contentWidth: contentWidth,
      totalWidth: contentWidth + rowHorizontalPadding,
    );
  }

  Widget _buildCompactQrActionButton() {
    final hasReadyQr = _qrSession != null && _qrData.isNotEmpty;
    final isBusy = _isLoadingQr || _isProcessingMethodAction;
    final canStart = _canStartAttendanceNow;
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isBusy || !canStart
              ? null
              : () async {
                  if (!hasReadyQr) {
                    await _loadQrForCurrentLecture();
                    if (!mounted) return;
                    if (_qrSession == null || _qrData.isEmpty) return;
                  }
                  await _showQrPopup();
                },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: isBusy || !canStart
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
              color: isBusy || !canStart ? const Color(0xFFE3E8EA) : null,
              borderRadius: BorderRadius.circular(14),
              boxShadow: isBusy || !canStart
                  ? null
                  : [
                      BoxShadow(
                        color: _primary.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_rounded,
                  size: 20,
                  color: isBusy || !canStart
                      ? const Color(0xFF92A2A7)
                      : Colors.white,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    hasReadyQr
                        ? _tr('عرض رمز التحضير', 'Show Attendance Code')
                        : _tr('تفعيل التحضير عبر QR', 'Activate QR attendance'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isBusy || !canStart
                          ? const Color(0xFF92A2A7)
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    bool showNumberCode = false;
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
                        'يمكن للطالب مسح الرمز من التطبيق لتسجيل الحضور',
                        'Students can scan the code in the app to mark attendance',
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
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F5F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD9E5E8)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                showNumberCode = false;
                                setDialogState(() {});
                              },
                              child: Container(
                                margin: const EdgeInsets.all(3),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: showNumberCode
                                      ? Colors.transparent
                                      : const Color(0xFF006571),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _tr('رمز QR', 'QR Code'),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: showNumberCode
                                        ? const Color(0xFF4F656B)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                showNumberCode = true;
                                setDialogState(() {});
                              },
                              child: Container(
                                margin: const EdgeInsets.all(3),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: showNumberCode
                                      ? const Color(0xFF006571)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _tr('الرمز الرقمي', 'Number Code'),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: showNumberCode
                                        ? Colors.white
                                        : const Color(0xFF4F656B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: showNumberCode ? 260 : null,
                      padding: EdgeInsets.all(showNumberCode ? 16 : 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF006571),
                          width: 1.8,
                        ),
                      ),
                      child: showNumberCode
                          ? Column(
                              children: [
                                Text(
                                  _tr('رمز الحضور', 'Attendance Code'),
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF465A5F),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    _qrSession!.numericCode.isNotEmpty
                                        ? _qrSession!.numericCode
                                        : '------',
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 7,
                                      color: Color(0xFF00474F),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                QrImageView(
                                  data: _qrData,
                                  size: 220,
                                  backgroundColor: Colors.white,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _tr('رمز الحضور', 'Attendance Code'),
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF5A6F76),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    _qrSession!.numericCode.isNotEmpty
                                        ? _qrSession!.numericCode
                                        : '------',
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 4,
                                      color: Color(0xFF00474F),
                                    ),
                                  ),
                                ),
                              ],
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
                                'سيتم تحديث الرمز خلال ',
                                'Code refreshes in ',
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
                                          'فشل تحديث رمز QR. يرجى المحاولة مرة أخرى.',
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
    final showSync =
        student.isOffline ||
        student.uiSyncState == AttendanceUIState.pending ||
        student.uiSyncState == AttendanceUIState.syncing ||
        student.uiSyncState == AttendanceUIState.failed;
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
        : (!_canEditAttendanceNow
              ? _showEditBlockedSnack
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
                    : () => _showStatusPicker(student)));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: _statusChip(
            chipLabel,
            effectiveStyle.bg,
            effectiveStyle.fg,
            icon: statusIcon,
            showSync: showSync,
            onSyncTap: showSync ? _showPendingSyncSnack : null,
            onChipTap: onChipTap,
          ),
        ),
      ],
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
    final canSave = !_isSaving && _canEditAttendanceNow;

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
              onTap: _isSaving
                  ? null
                  : (!_canEditAttendanceNow && hasChanges)
                  ? _showEditBlockedSnack
                  : _saveChanges,
              borderRadius: BorderRadius.circular(radius),
              child: Container(
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: (hasChanges && canSave)
                      ? const LinearGradient(
                          colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  color: (hasChanges && canSave)
                      ? null
                      : const Color(0xFFE3E8EA),
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: (hasChanges && canSave)
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
                          color: (hasChanges && canSave)
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
                    ..._lecturerManualSelectableStatuses.map((status) {
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

/// Statuses the lecturer may set manually; [AttendanceStatus.pending] is system-only.
const List<AttendanceStatus> _lecturerManualSelectableStatuses =
    <AttendanceStatus>[
      AttendanceStatus.present,
      AttendanceStatus.absent,
      AttendanceStatus.excused,
      AttendanceStatus.late,
    ];

enum AttendanceMethod { nfc, qr, bluetooth, manual }

class _StudentRow {
  _StudentRow({
    required this.id,
    required this.name,
    required this.academicNumber,
    required this.attendanceTime,
    required this.percentage,
    required this.status,
    this.isOffline = false,
    this.uiSyncState = AttendanceUIState.idle,
    this.isSuspended = false,
    this.isAcademicallyDeprived = false,
  });

  final String id;
  final String name;
  final String academicNumber;
  String attendanceTime;
  int percentage;
  AttendanceStatus status;
  final bool isOffline;
  final AttendanceUIState uiSyncState;
  final bool? isSuspended;

  /// From [AttendanceStudentCardCalculator.isAcademicallyDeprived] (semester-wide).
  bool isAcademicallyDeprived;

  _StudentRow copyWith({
    String? name,
    int? percentage,
    bool? isAcademicallyDeprived,
  }) {
    return _StudentRow(
      id: id,
      name: name ?? this.name,
      academicNumber: academicNumber,
      attendanceTime: attendanceTime,
      percentage: percentage ?? this.percentage,
      status: status,
      isOffline: isOffline,
      uiSyncState: uiSyncState,
      isSuspended: isSuspended,
      isAcademicallyDeprived:
          isAcademicallyDeprived ?? this.isAcademicallyDeprived,
    );
  }
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

class _StudentsTableLayout {
  const _StudentsTableLayout({
    required this.columnGap,
    required this.indexWidth,
    required this.studentWidth,
    required this.idWidth,
    required this.timeWidth,
    required this.percentageWidth,
    required this.statusWidth,
    required this.contentWidth,
    required this.totalWidth,
  });

  final double columnGap;
  final double indexWidth;
  final double studentWidth;
  final double idWidth;
  final double timeWidth;
  final double percentageWidth;
  final double statusWidth;

  /// Sum of column widths + gaps (excludes row horizontal padding).
  final double contentWidth;
  final double totalWidth;
}
