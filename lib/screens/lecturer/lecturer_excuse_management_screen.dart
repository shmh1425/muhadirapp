import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/attendance/manual_attendance_record.dart';
import '../../models/external_student.dart';
import '../../models/excuse/excuse_request.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../services/attendance/manual_attendance_service.dart';
import '../../services/excuse/excuse_service.dart';
import '../../widgets/lecturer/excuse_attachment_preview.dart';
import '../../widgets/lecturer/excuse_rejection_reason_dialog.dart';
import 'lecturer_language.dart';
import 'widgets/directional_navigation_icon.dart';
import 'widgets/modern_popup_dialog.dart';
import 'widgets/profile_back_button.dart';

/// شاشة إدارة الأعذار (Figure 11 – Excuse Management).
/// تُفتح من صفحة التحضير عند الضغط على "معاينة الأعذار".
/// مرتبطة بجلسة التحضير الحالية عبر [sessionId].
class LecturerExcuseManagementScreen extends StatefulWidget {
  const LecturerExcuseManagementScreen({
    super.key,
    required this.lecture,
    required this.sessionId,
    required this.sessionDate,
  });

  final LectureItem lecture;
  final String sessionId;
  final DateTime sessionDate;

  @override
  State<LecturerExcuseManagementScreen> createState() =>
      _LecturerExcuseManagementScreenState();
}

class _LecturerExcuseManagementScreenState
    extends State<LecturerExcuseManagementScreen> {
  static const Color _primary = Color(0xFF006571);

  final ManualAttendanceService _manualAttendanceService =
      ManualAttendanceService.instance;
  final ExcuseService _excuseService = ExcuseService.instance;

  StreamSubscription<List<ExcuseRequest>>? _excuseSub;
  StreamSubscription<List<ManualAttendanceRecord>>? _recordsSub;

  List<ExcuseRequest> _excuses = const [];
  List<ManualAttendanceRecord> _records = const [];
  Map<int, ExternalStudent> _studentProfiles = {};
  bool _seenExcuseSnapshot = false;
  bool _seenRecordsSnapshot = false;
  String? _excuseStreamError;

  final Map<String, ExcuseStatus> _staged = {};
  final Map<String, String> _stagedRejectReason = {};

  bool _isSaving = false;
  ExcuseStatusFilter _statusFilter = ExcuseStatusFilter.all;

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  String _translateRejectReason(String reason) {
    if (reason.isEmpty) return reason;
    switch (reason) {
      case 'لم يرفق المستند خلال المدة':
        return _tr(
          'لم يرفق المستند خلال المدة',
          'Document was not attached within the period',
        );
      case 'ليس عذراً صحيحاً موثوقاً':
        return _tr(
          'ليس عذراً صحيحاً موثوقاً',
          'Not a valid or reliable excuse',
        );
      case 'تاريخ الغياب غير متوافق':
        return _tr('تاريخ الغياب غير متوافق', 'Absence date does not match');
      case 'سبب آخر':
        return _tr('سبب آخر', 'Other reason');
      default:
        return reason;
    }
  }

  bool _isValidAttachmentUrl(String raw) {
    return ExcuseAttachmentPreview.isValidAttachmentUrl(raw);
  }

  Future<void> _showAttachmentPreviewDialog({
    required String attachmentName,
    required String attachmentUrl,
  }) async {
    await ExcuseAttachmentPreview.showAttachmentPreviewDialog(
      context: context,
      attachmentName: attachmentName,
      attachmentUrl: attachmentUrl,
      tr: _tr,
      textDirection: LecturerLanguageController.direction(),
      primaryColor: _primary,
      logTag: '[LecturerExcuseManagement]',
    );
  }

  LectureItem get _lecture => widget.lecture;

  String _excuseLectureDateLabel(ExcuseRequest item) {
    final d = item.lectureDate;
    if (d.year == 2000 && d.month == 1 && d.day == 1) {
      return _tr('—', '—');
    }
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _excuseTimeRangeLabel(ExcuseRequest item) {
    final a = item.lectureStartTime.trim();
    final b = item.lectureEndTime.trim();
    if (a.isEmpty && b.isEmpty) return _tr('—', '—');
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a - $b';
  }

  String _excuseCourseName(ExcuseRequest item) {
    return LecturerLanguageController.localizedCourseName(
      <String, dynamic>{
        'courseNameAr': item.courseNameAr,
        'courseNameEn': item.courseNameEn,
      },
      fallback: _lecture.courseName,
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

  Future<void> _refreshStudentProfiles() async {
    final ids = <int>{
      ..._records.map((r) => r.studentId),
      ..._sectionScopedExcuses.map((e) => e.studentId),
    }.where((id) => id > 0).toSet();
    if (ids.isEmpty) return;
    try {
      final profiles =
          await _manualAttendanceService.fetchStudentProfilesByIds(ids);
      if (!mounted) return;
      setState(() => _studentProfiles = profiles);
    } catch (_) {
      // Keep snapshot names on lookup failure.
    }
  }

  String get _lectureTimeRange {
    final slots = _lecture.timeSlots;
    if (slots.isEmpty) return '${_lecture.startTime} - ${_lecture.endTime}';
    if (slots.length == 1) return slots.first;
    return '${slots.first} / ${slots.last}';
  }

  String get _lectureDayName {
    return LecturerLanguageController.dayNameFromWeekday(_lecture.dayOfWeek);
  }

  bool get _hasPendingDecisions => _staged.isNotEmpty;

  bool get _initialLoading => !_seenExcuseSnapshot || !_seenRecordsSnapshot;

  Map<int, String> get _nameByStudentId {
    final m = <int, String>{};
    for (final r in _records) {
      m[r.studentId] = _localizedStudentName(
        r.studentId,
        r.studentName,
      );
    }
    for (final entry in _studentProfiles.entries) {
      m[entry.key] = entry.value.displayNameFor(
        LecturerLanguageController.isArabic,
      );
    }
    return m;
  }

  List<ExcuseRequest> get _sectionScopedExcuses {
    final want = (_lecture.sectionId ?? '').trim();
    if (want.isEmpty) return List<ExcuseRequest>.from(_excuses);
    return _excuses
        .where((e) => e.sectionId.trim() == want || e.sectionId.trim().isEmpty)
        .toList();
  }

  // Product decision: keep excuse review editable for all weeks without time lock.
  bool _isPastReviewDeadline(ExcuseRequest r) {
    return false;
  }

  ExcuseStatus _baseUiStatus(ExcuseRequest r) {
    if (r.status == ExcuseRequestStatus.pending && _isPastReviewDeadline(r)) {
      return ExcuseStatus.expired;
    }
    switch (r.status) {
      case ExcuseRequestStatus.pending:
        return ExcuseStatus.pending;
      case ExcuseRequestStatus.accepted:
        return ExcuseStatus.accepted;
      case ExcuseRequestStatus.rejected:
        return ExcuseStatus.rejected;
      case ExcuseRequestStatus.expired:
        return ExcuseStatus.expired;
    }
  }

  ExcuseStatus _effectiveStatus(ExcuseRequest r) {
    return _staged[r.id] ?? _baseUiStatus(r);
  }

  bool _canReview(ExcuseRequest r) {
    if (r.status != ExcuseRequestStatus.pending) return false;
    if (_isPastReviewDeadline(r)) return false;
    return true;
  }

  List<_ExcuseViewRow> get _viewRows {
    final names = _nameByStudentId;
    final rows = <_ExcuseViewRow>[];
    for (final e in _sectionScopedExcuses) {
      final snapshot = (e.studentName?.trim().isNotEmpty ?? false)
          ? e.studentName!.trim()
          : '';
      final nm = names[e.studentId] ??
          _localizedStudentName(e.studentId, snapshot);
      rows.add(
        _ExcuseViewRow(
          request: e,
          displayName: nm,
          academicId: e.studentId > 0
              ? '${e.studentId}'
              : _tr('غير متوفر', 'N/A'),
        ),
      );
    }
    return rows;
  }

  List<_ExcuseViewRow> get _filteredRows {
    final list = _viewRows;
    if (_statusFilter == ExcuseStatusFilter.all) return list;
    final want = _filterToStatus(_statusFilter);
    return list.where((r) => _effectiveStatus(r.request) == want).toList();
  }

  ExcuseStatus _filterToStatus(ExcuseStatusFilter f) {
    switch (f) {
      case ExcuseStatusFilter.all:
        return ExcuseStatus.pending;
      case ExcuseStatusFilter.pending:
        return ExcuseStatus.pending;
      case ExcuseStatusFilter.accepted:
        return ExcuseStatus.accepted;
      case ExcuseStatusFilter.rejected:
        return ExcuseStatus.rejected;
    }
  }

  void _pruneStaged() {
    final validIds = _sectionScopedExcuses.map((e) => e.id).toSet();
    _staged.removeWhere((id, _) => !validIds.contains(id));
    _stagedRejectReason.removeWhere((id, _) => !validIds.contains(id));
  }

  @override
  void initState() {
    super.initState();
    _excuseSub = _excuseService
        .watchExcuseRequestsForAttendanceSession(
          sessionId: widget.sessionId,
          sectionId: _lecture.sectionId,
          sessionDay: widget.sessionDate,
          lectureStartTime: _lecture.startTime,
        )
        .listen(
          (list) {
            if (!mounted) return;
            setState(() {
              _excuses = list;
              _seenExcuseSnapshot = true;
              _excuseStreamError = null;
              _pruneStaged();
            });
            unawaited(_refreshStudentProfiles());
          },
          onError: (Object e) {
            debugPrint('[LecturerExcuseManagement] excuse stream failed: $e');
            if (!mounted) return;
            setState(() {
              _excuseStreamError = e.toString();
              _seenExcuseSnapshot = true;
            });
          },
        );
    _recordsSub = _manualAttendanceService
        .watchSessionRecords(widget.sessionId)
        .listen(
          (list) {
            if (!mounted) return;
            setState(() {
              _records = list;
              _seenRecordsSnapshot = true;
            });
            unawaited(_refreshStudentProfiles());
          },
          onError: (Object e) {
            debugPrint('[LecturerExcuseManagement] records stream failed: $e');
            if (!mounted) return;
            setState(() {
              _seenRecordsSnapshot = true;
            });
          },
        );
  }

  @override
  void dispose() {
    _excuseSub?.cancel();
    _recordsSub?.cancel();
    super.dispose();
  }

  void _onViewRow(_ExcuseViewRow row) {
    _showDetailSheet(row);
  }

  Future<void> _showAcceptRejectSheet(_ExcuseViewRow row) async {
    final item = row.request;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _tr('قرار العذر', 'Excuse decision'),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF213236),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      row.displayName,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if ((item.reasonText ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        item.reasonText!.trim(),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Color(0xFF334155),
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (_isValidAttachmentUrl(
                      (item.attachmentUrl ?? '').trim(),
                    )) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () async {
                            final attachmentName = (item.attachmentName ?? '')
                                .trim();
                            final attachmentUrl = (item.attachmentUrl ?? '')
                                .trim();
                            await _showAttachmentPreviewDialog(
                              attachmentName: attachmentName,
                              attachmentUrl: attachmentUrl,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primary,
                            side: const BorderSide(color: Color(0xFF006571)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _tr('معاينة العذر', 'Preview attachment'),
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: Material(
                        color: const Color(0xFF0D7D3E),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _staged[item.id] = ExcuseStatus.accepted;
                              _stagedRejectReason.remove(item.id);
                            });
                            Navigator.of(ctx).pop();
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Center(
                            child: Text(
                              _tr('قبول العذر', 'Accept'),
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => _showRejectReasonDialog(ctx, row),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFB91C1C),
                          side: const BorderSide(color: Color(0xFFB91C1C)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _tr('رفض العذر', 'Reject'),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _confirmDecisionChange() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: ModernPopupDialog(
            accentColor: _primary,
            title: Text(
              _tr('تعديل القرار', 'Change decision'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF213236),
              ),
            ),
            actions: [
              ModernPopupActionButton(
                label: _tr('إلغاء', 'Cancel'),
                onTap: () => Navigator.of(ctx).pop(false),
                isPrimary: false,
              ),
              ModernPopupActionButton(
                label: _tr('متابعة', 'Continue'),
                onTap: () => Navigator.of(ctx).pop(true),
                isPrimary: true,
                primaryColor: _primary,
              ),
            ],
            child: Text(
              _tr(
                'هل أنت متأكد من تعديل قرار العذر؟',
                'Are you sure you want to change the excuse decision?',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF475569),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showRejectReasonDialog(
    BuildContext sheetContext,
    _ExcuseViewRow row,
  ) async {
    final item = row.request;
    final reason = await showExcuseRejectionReasonDialog(
      context: context,
      tr: _tr,
      textDirection: LecturerLanguageController.direction(),
      primaryColor: _primary,
    );
    if (!mounted || reason == null) return;
    setState(() {
      _staged[item.id] = ExcuseStatus.rejected;
      _stagedRejectReason[item.id] = reason;
    });
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
  }

  void _showDetailSheet(_ExcuseViewRow row) {
    final item = row.request;
    final eff = _effectiveStatus(item);
    final rejectShown = eff == ExcuseStatus.rejected
        ? (_stagedRejectReason[item.id] ?? item.rejectionReason ?? '')
        : '';
    final attachmentName = (item.attachmentName ?? '').trim();
    final attachmentUrl = (item.attachmentUrl ?? '').trim();
    final hasAttachment = attachmentUrl.isNotEmpty;
    final validAttachmentUrl = _isValidAttachmentUrl(attachmentUrl);
    debugPrint(
      '[LecturerExcuseManagement] detail sheet excuseId=${item.id} '
      'hasAttachment=$hasAttachment attachmentName="$attachmentName" '
      'attachmentUrl="$attachmentUrl" validUrl=$validAttachmentUrl',
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: SafeArea(
              top: false,
              child: ModernPopupSheet(
                accentColor: _primary,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        row.displayName,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF213236),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        row.academicId,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _tr('المقرر', 'Course'),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _excuseCourseName(item),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _tr('الشعبة', 'Section'),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.sectionId.trim().isNotEmpty
                            ? item.sectionId.trim()
                            : '${_tr('الشعبة', 'Section')} ${_lecture.section}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _tr('تاريخ المحاضرة', 'Lecture date'),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _excuseLectureDateLabel(item),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _tr('وقت المحاضرة', 'Lecture time'),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _excuseTimeRangeLabel(item),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          color: Color(0xFF334155),
                        ),
                      ),
                      if ((item.attachmentName ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _tr('اسم المرفق', 'Attachment name'),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.attachmentName!.trim(),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                      if ((item.reasonText ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          _tr('نص العذر', 'Excuse text'),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.reasonText!.trim(),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            color: Color(0xFF334155),
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        _tr('مرفق', 'Attachment'),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (!hasAttachment || !validAttachmentUrl)
                        Text(
                          _tr(
                            'لم يتم إرفاق أي مرفق.',
                            'No attachment was provided.',
                          ),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        )
                      else
                        InkWell(
                          onTap: () async {
                            debugPrint(
                              '[LecturerExcuseManagement] attachment widget tapped for excuseId=${item.id}',
                            );
                            await _showAttachmentPreviewDialog(
                              attachmentName: attachmentName,
                              attachmentUrl: attachmentUrl,
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              attachmentName.isNotEmpty
                                  ? attachmentName
                                  : _tr('فتح المرفق', 'Open attachment'),
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                color: Color(0xFF006571),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        _statusFullLabel(eff),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _statusColor(eff),
                        ),
                      ),
                      if (item.status == ExcuseRequestStatus.pending &&
                          _isPastReviewDeadline(item)) ...[
                        const SizedBox(height: 8),
                        Text(
                          _tr(
                            'انتهت مهلة المراجعة.',
                            'Review deadline has passed.',
                          ),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                      if (eff == ExcuseStatus.rejected &&
                          rejectShown.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          _translateRejectReason(rejectShown),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_canReview(item))
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await Future<void>.delayed(
                                const Duration(milliseconds: 80),
                              );
                              if (!mounted) return;
                              await _showAcceptRejectSheet(row);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primary,
                              side: const BorderSide(color: Color(0xFF006571)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _tr('اتخاذ القرار', 'Take decision'),
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      else if (item.status == ExcuseRequestStatus.accepted ||
                          item.status == ExcuseRequestStatus.rejected)
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await Future<void>.delayed(
                                const Duration(milliseconds: 80),
                              );
                              if (!mounted) return;
                              final ok = await _confirmDecisionChange();
                              if (ok != true || !mounted) return;
                              await _showAcceptRejectSheet(row);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primary,
                              side: const BorderSide(color: Color(0xFF006571)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _tr('تعديل القرار', 'Change decision'),
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _statusChipLabel(ExcuseStatus s) {
    switch (s) {
      case ExcuseStatus.pending:
        return _tr('قيد المراجعة', 'Pending');
      case ExcuseStatus.accepted:
        return _tr('مقبول', 'Accepted');
      case ExcuseStatus.rejected:
        return _tr('مرفوض', 'Rejected');
      case ExcuseStatus.expired:
        return _tr('منتهي', 'Closed');
    }
  }

  String _statusFullLabel(ExcuseStatus s) {
    switch (s) {
      case ExcuseStatus.pending:
        return _tr('قيد المراجعة', 'Pending review');
      case ExcuseStatus.accepted:
        return _tr('غائب بعذر', 'Absent with excuse');
      case ExcuseStatus.rejected:
        return _tr('عذر مرفوض', 'Excuse rejected');
      case ExcuseStatus.expired:
        return _tr('غير قابل للإجراء', 'No longer actionable');
    }
  }

  Color _statusChipFg(ExcuseStatus s) {
    switch (s) {
      case ExcuseStatus.pending:
        return const Color(0xFFB45309);
      case ExcuseStatus.accepted:
        return const Color(0xFF0D7D3E);
      case ExcuseStatus.rejected:
        return const Color(0xFFB91C1C);
      case ExcuseStatus.expired:
        return const Color(0xFF64748B);
    }
  }

  Color _statusChipBg(ExcuseStatus s) {
    switch (s) {
      case ExcuseStatus.pending:
        return const Color(0xFFFFF7ED);
      case ExcuseStatus.accepted:
        return const Color(0xFFF0FDF4);
      case ExcuseStatus.rejected:
        return const Color(0xFFFEF2F2);
      case ExcuseStatus.expired:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _statusColor(ExcuseStatus s) {
    switch (s) {
      case ExcuseStatus.pending:
        return const Color(0xFFB45309);
      case ExcuseStatus.accepted:
        return const Color(0xFF0D7D3E);
      case ExcuseStatus.rejected:
        return const Color(0xFFB91C1C);
      case ExcuseStatus.expired:
        return const Color(0xFF64748B);
    }
  }

  Future<void> _saveDecisions() async {
    if (!_hasPendingDecisions) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('لا توجد قرارات جديدة للحفظ.', 'No new decisions to save.'),
          ),
        ),
      );
      return;
    }
    if (_isSaving) return;

    final decisions = <LecturerExcuseDecision>[];
    for (final entry in _staged.entries) {
      ExcuseRequest? req;
      for (final e in _sectionScopedExcuses) {
        if (e.id == entry.key) {
          req = e;
          break;
        }
      }
      if (req == null) continue;
      if (_isPastReviewDeadline(req)) continue;

      final ui = entry.value;
      if (ui == ExcuseStatus.accepted) {
        decisions.add(
          LecturerExcuseDecision(
            excuseRequestId: req.id,
            studentId: req.studentId,
            oldStatus: req.status,
            newStatus: ExcuseRequestStatus.accepted,
            attendanceRecordId: req.attendanceRecordId,
            notificationSessionId: req.sessionId ?? widget.sessionId,
            courseNameAr: req.courseNameAr,
            courseNameEn: req.courseNameEn,
            sectionId: req.sectionId,
          ),
        );
      } else if (ui == ExcuseStatus.rejected) {
        decisions.add(
          LecturerExcuseDecision(
            excuseRequestId: req.id,
            studentId: req.studentId,
            oldStatus: req.status,
            newStatus: ExcuseRequestStatus.rejected,
            rejectionReason: _stagedRejectReason[req.id],
            attendanceRecordId: req.attendanceRecordId,
            notificationSessionId: req.sessionId ?? widget.sessionId,
            courseNameAr: req.courseNameAr,
            courseNameEn: req.courseNameEn,
            sectionId: req.sectionId,
          ),
        );
      }
    }

    if (decisions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('لا توجد قرارات صالحة للحفظ.', 'No valid decisions to save.'),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _excuseService.applyLecturerDecisions(
        sessionId: widget.sessionId,
        decisions: decisions,
      );
      if (!mounted) return;
      setState(() {
        _staged.clear();
        _stagedRejectReason.clear();
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              'تم حفظ قرارات الأعذار بنجاح.',
              'Excuse decisions saved successfully.',
            ),
          ),
          backgroundColor: const Color(0xFF2B9E56),
          duration: const Duration(seconds: 2),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseException catch (e, st) {
      debugPrint('[LecturerExcuseManagement] save failed: $e\n$st');
      if (mounted) setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('فشل الحفظ. حاول مرة أخرى.', 'Save failed. Please try again.'),
          ),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
    } catch (e, st) {
      debugPrint('[LecturerExcuseManagement] save failed: $e\n$st');
      if (mounted) setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr('فشل الحفظ. حاول مرة أخرى.', 'Save failed. Please try again.'),
          ),
          backgroundColor: const Color(0xFFD32F2F),
        ),
      );
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
            backgroundColor: const Color(0xFFF8FAFC),
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _buildFilters(),
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: _buildTableSection()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: _buildSaveButton(),
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
    final activity = _lecture.activity.trim().toLowerCase();
    final isPractical = activity == 'عملي' || activity == 'lab';
    final activityLabel = isPractical
        ? _tr('عملي', 'Lab')
        : _tr('نظري', 'Theory');
    final sectionLabel = '${_tr('الشعبة', 'Section')} ${_lecture.section}';
    final sessionDay = widget.sessionDate;
    final dateStr =
        '${sessionDay.year}-${sessionDay.month.toString().padLeft(2, '0')}-${sessionDay.day.toString().padLeft(2, '0')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: const Color(0xFFE7EEF0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              Center(
                child: Text(
                  _tr('معاينة الأعذار', 'View Excuses'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF24383D),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ProfileBackButton(onTap: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B8793), Color(0xFF005B66)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _lecture.courseName,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$_lectureDayName · $activityLabel · $sectionLabel',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$_lectureTimeRange · ${_tr('تاريخ الجلسة', 'Session date')} $dateStr',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.84),
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildFilterSectionTitle({
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

  Widget _buildFilters() {
    final filters = [
      ExcuseStatusFilter.all,
      ExcuseStatusFilter.pending,
      ExcuseStatusFilter.accepted,
      ExcuseStatusFilter.rejected,
    ];
    final total = _sectionScopedExcuses.length;
    final visible = _filteredRows.length;
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
                const Icon(
                  Icons.filter_alt_rounded,
                  color: Colors.white,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Text(
                  _tr('فلترة الأعذار', 'Excuse Filters'),
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
          _buildFilterSectionTitle(
            icon: Icons.rule_rounded,
            title: _tr('حالة العذر', 'Excuse status'),
            hint: _tr('اختر حالة الطلبات', 'Select request status'),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F9FA),
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
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 32,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? style.activeBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: style.activeBg.withValues(alpha: 0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        style.label,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: active
                              ? Colors.white
                              : const Color(0xFF516166),
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
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0ECEE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.list_alt_rounded,
                  size: 17,
                  color: Color(0xFF5A757C),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _tr(
                      'المعروض: $visible من $total طلب',
                      'Showing: $visible of $total requests',
                    ),
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11.6,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5A757C),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _ExcuseFilterStyle _filterStyle(ExcuseStatusFilter f) {
    switch (f) {
      case ExcuseStatusFilter.all:
        return _ExcuseFilterStyle(
          label: _tr('الكل', 'All'),
          activeBg: const Color(0xFF6F7D82),
        );
      case ExcuseStatusFilter.pending:
        return _ExcuseFilterStyle(
          label: _tr('قيد المراجعة', 'Pending'),
          activeBg: const Color(0xFFB45309),
        );
      case ExcuseStatusFilter.accepted:
        return _ExcuseFilterStyle(
          label: _tr('مقبول', 'Accepted'),
          activeBg: const Color(0xFF0D7D3E),
        );
      case ExcuseStatusFilter.rejected:
        return _ExcuseFilterStyle(
          label: _tr('مرفوض', 'Rejected'),
          activeBg: const Color(0xFFB91C1C),
        );
    }
  }

  Widget _buildTableSection() {
    if (_initialLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    final hasAnyExcuses = _sectionScopedExcuses.isNotEmpty;
    final blockingExcuseError =
        _excuseStreamError != null &&
        !hasAnyExcuses &&
        _seenExcuseSnapshot &&
        _seenRecordsSnapshot;
    if (blockingExcuseError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _tr(
              'تعذر تحميل الأعذار. تحقق من الاتصال والصلاحيات.',
              'Could not load excuses. Check connection and permissions.',
            ),
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Color(0xFFB91C1C),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final list = _filteredRows;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE6E8)),
        ),
        child: list.isEmpty
            ? ListView(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                children: [
                  _buildEmptyFilterPlaceholder(),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildExcuseTableHeader(),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        color: Color(0xFFE8EFF1),
                      ),
                      itemBuilder: (context, index) {
                        return _buildExcuseTableRow(list[index], index);
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  static const TextStyle _excuseTableHeaderStyle = TextStyle(
    fontFamily: 'Cairo',
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: Color(0xFF4A6066),
  );

  Widget _buildExcuseTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F6F7),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(13),
          topRight: Radius.circular(13),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 28,
            child: Text(
              '#',
              textAlign: TextAlign.center,
              style: _excuseTableHeaderStyle,
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              _tr('الطالب', 'Student'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _excuseTableHeaderStyle,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _tr('الرقم', 'ID'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _excuseTableHeaderStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _tr('الحالة', 'Status'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _excuseTableHeaderStyle,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              _tr('عرض', 'View'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _excuseTableHeaderStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExcuseTableRow(_ExcuseViewRow row, int index) {
    final eff = _effectiveStatus(row.request);

    return Material(
      color: index.isEven ? Colors.white : const Color(0xFFFCFEFE),
      child: InkWell(
        onTap: () => _onViewRow(row),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5E6C70),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  row.displayName,
                  maxLines: 2,
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
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    row.academicId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Color(0xFF55666B),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _buildStatusChip(eff),
                  ),
                ),
              ),
              const SizedBox(
                width: 44,
                child: Center(
                  child: LecturerDirectionalForwardIcon(
                    size: 22,
                    color: Color(0xFF006571),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFilterPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0ECEE)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: _primary,
              size: 21,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _tr(
              'لا يوجد طلاب في هذا الفلتر.',
              'No students in this filter.',
            ),
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Color(0xFF455D63),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _tr(
              'يمكن تجربة تغيير حالة العذر أو إعادة ضبط الفلتر.',
              'Try changing the excuse status or reset the filter.',
            ),
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Color(0xFF7A9097),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ExcuseStatus status) {
    final fg = _statusChipFg(status);
    final bg = _statusChipBg(status);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.24)),
      ),
      alignment: Alignment.center,
      child: Text(
        _statusChipLabel(status),
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSaveButton() {
    final enabled = _hasPendingDecisions && !_isSaving;
    final label = _isSaving
        ? _tr('جارٍ الحفظ...', 'Saving...')
        : enabled
        ? _tr('حفظ ${_staged.length} قرار', 'Save ${_staged.length} decisions')
        : _tr('لا توجد قرارات للحفظ', 'No decisions to save');
    return Container(
      width: double.infinity,
      height: 52,
      decoration: enabled
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? _saveDecisions : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: enabled
                  ? const LinearGradient(
                      colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : null,
              color: enabled ? null : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(14),
              border: enabled
                  ? null
                  : Border.all(color: const Color(0xFFCBD5E1), width: 1),
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
                    label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: enabled ? Colors.white : const Color(0xFF94A3B8),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

enum ExcuseStatus { pending, accepted, rejected, expired }

enum ExcuseStatusFilter { all, pending, accepted, rejected }

class _ExcuseFilterStyle {
  const _ExcuseFilterStyle({required this.label, required this.activeBg});
  final String label;
  final Color activeBg;
}

class _ExcuseViewRow {
  _ExcuseViewRow({
    required this.request,
    required this.displayName,
    required this.academicId,
  });

  final ExcuseRequest request;
  final String displayName;
  final String academicId;
}
