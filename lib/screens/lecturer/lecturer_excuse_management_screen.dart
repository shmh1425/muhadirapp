import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/attendance/manual_attendance_record.dart';
import '../../models/excuse/excuse_request.dart';
import '../../models/lecturer/lecture_item.dart';
import '../../services/attendance/manual_attendance_service.dart';
import '../../services/excuse/excuse_service.dart';
import 'lecturer_language.dart';
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
  bool _seenExcuseSnapshot = false;
  bool _seenRecordsSnapshot = false;
  String? _streamError;

  final Map<String, ExcuseStatus> _staged = {};
  final Map<String, String> _stagedRejectReason = {};

  bool _isSaving = false;
  ExcuseStatusFilter _statusFilter = ExcuseStatusFilter.all;

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  String _translateRejectReason(String reason) {
    if (reason.isEmpty) return reason;
    switch (reason) {
      case 'لم يرفق المستند خلال المدة':
        return _tr('لم يرفق المستند خلال المدة', 'Document was not attached within the period');
      case 'ليس عذراً صحيحاً موثوقاً':
        return _tr('ليس عذراً صحيحاً موثوقاً', 'Not a valid or reliable excuse');
      case 'تاريخ الغياب غير متوافق':
        return _tr('تاريخ الغياب غير متوافق', 'Absence date does not match');
      case 'سبب آخر':
        return _tr('سبب آخر', 'Other reason');
      default:
        return reason;
    }
  }

  LectureItem get _lecture => widget.lecture;

  String get _lectureTimeRange {
    final slots = _lecture.timeSlots;
    if (slots.isEmpty) return '${_lecture.startTime} - ${_lecture.endTime}';
    if (slots.length == 1) return slots.first;
    return '${slots.first} / ${slots.last}';
  }

  String get _lectureDayName {
    const days = ['', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    const daysEn = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final i = _lecture.dayOfWeek.clamp(1, 7);
    return LecturerLanguageController.isArabic ? days[i] : daysEn[i];
  }

  bool get _hasPendingDecisions => _staged.isNotEmpty;

  bool get _initialLoading =>
      (!_seenExcuseSnapshot || !_seenRecordsSnapshot) && _streamError == null;

  Map<int, String> get _nameByStudentId {
    final m = <int, String>{};
    for (final r in _records) {
      m[r.studentId] = r.studentName.trim().isNotEmpty ? r.studentName : '${r.studentId}';
    }
    return m;
  }

  List<ExcuseRequest> get _sectionScopedExcuses {
    final want = (_lecture.sectionId ?? '').trim();
    if (want.isEmpty) return List<ExcuseRequest>.from(_excuses);
    return _excuses.where((e) => e.sectionId.trim() == want).toList();
  }

  bool _isPastReviewDeadline(ExcuseRequest r) {
    final d = r.reviewDeadlineAt;
    if (d == null) return false;
    return DateTime.now().isAfter(d);
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
      final nm = (e.studentName?.trim().isNotEmpty ?? false)
          ? e.studentName!.trim()
          : (names[e.studentId] ?? '${e.studentId}');
      rows.add(_ExcuseViewRow(request: e, displayName: nm, academicId: '${e.studentId}'));
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
    for (final e in _sectionScopedExcuses) {
      if (e.status != ExcuseRequestStatus.pending) {
        _staged.remove(e.id);
        _stagedRejectReason.remove(e.id);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _excuseSub = _excuseService
        .watchSessionExcuseRequests(widget.sessionId)
        .listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _excuses = list;
          _seenExcuseSnapshot = true;
          _streamError = null;
          _pruneStaged();
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _streamError = e.toString();
          _seenExcuseSnapshot = true;
        });
      },
    );
    _recordsSub = _manualAttendanceService.watchSessionRecords(widget.sessionId).listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _records = list;
          _seenRecordsSnapshot = true;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _streamError = e.toString();
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
    final r = row.request;
    if (!_canReview(r)) {
      _showDetailSheet(row);
      return;
    }
    final staged = _staged[r.id];
    if (staged == null) {
      _showAcceptRejectSheet(row);
    } else {
      _showDetailSheet(row);
    }
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
        );
      },
    );
  }

  static const int _rejectOptionNotValid = 0;
  static const int _rejectOptionDateMismatch = 1;
  static const int _rejectOptionOther = 2;

  Future<void> _showRejectReasonDialog(
    BuildContext sheetContext,
    _ExcuseViewRow row,
  ) async {
    final item = row.request;
    final reasonController = TextEditingController();
    int? selectedOption = _rejectOptionNotValid;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                          _tr('سبب الرفض', 'Rejection reason'),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF213236),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildRejectOption(
                          setDialogState,
                          selected: selectedOption == _rejectOptionNotValid,
                          label: _tr('ليس عذراً صحيحاً موثوقاً', 'Not a valid or reliable excuse'),
                          onTap: () => setDialogState(() => selectedOption = _rejectOptionNotValid),
                        ),
                        const SizedBox(height: 8),
                        _buildRejectOption(
                          setDialogState,
                          selected: selectedOption == _rejectOptionDateMismatch,
                          label: _tr('تاريخ الغياب غير متوافق', 'Absence date does not match'),
                          onTap: () => setDialogState(() => selectedOption = _rejectOptionDateMismatch),
                        ),
                        const SizedBox(height: 8),
                        _buildRejectOption(
                          setDialogState,
                          selected: selectedOption == _rejectOptionOther,
                          label: _tr('سبب آخر', 'Other reason'),
                          onTap: () => setDialogState(() => selectedOption = _rejectOptionOther),
                        ),
                        if (selectedOption == _rejectOptionOther) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: reasonController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: _tr('اكتب سبب الرفض', 'Write the rejection reason'),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _primary, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: Material(
                            color: _primary,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () {
                                String reason;
                                if (selectedOption == _rejectOptionNotValid) {
                                  reason = _tr('ليس عذراً صحيحاً موثوقاً', 'Not a valid or reliable excuse');
                                } else if (selectedOption == _rejectOptionDateMismatch) {
                                  reason = _tr('تاريخ الغياب غير متوافق', 'Absence date does not match');
                                } else {
                                  reason = reasonController.text.trim().isEmpty
                                      ? _tr('سبب آخر', 'Other reason')
                                      : reasonController.text.trim();
                                }
                                setState(() {
                                  _staged[item.id] = ExcuseStatus.rejected;
                                  _stagedRejectReason[item.id] = reason;
                                });
                                Navigator.of(ctx).pop();
                                Navigator.of(sheetContext).pop();
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Center(
                                child: Text(
                                  _tr('تأكيد الرفض', 'Confirm'),
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
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text(
                              _tr('إلغاء', 'Cancel'),
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRejectOption(
    void Function(void Function()) setDialogState, {
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? _primary.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _primary : const Color(0xFFE2E8F0),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off_outlined,
                size: 22,
                color: selected ? _primary : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? const Color(0xFF213236) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(_ExcuseViewRow row) {
    final item = row.request;
    final eff = _effectiveStatus(item);
    final rejectShown = eff == ExcuseStatus.rejected
        ? (_stagedRejectReason[item.id] ?? item.rejectionReason ?? '')
        : '';

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
                    if ((item.attachmentUrl ?? '').trim().isNotEmpty) ...[
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
                      SelectableText(
                        item.attachmentUrl!.trim(),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: Color(0xFF006571),
                        ),
                      ),
                    ],
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
                        _tr('انتهت مهلة المراجعة.', 'Review deadline has passed.'),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    if (eff == ExcuseStatus.rejected && rejectShown.isNotEmpty) ...[
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
                  ],
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
          content: Text(_tr('لا توجد قرارات جديدة للحفظ.', 'No new decisions to save.')),
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
      if (req.status != ExcuseRequestStatus.pending) continue;
      if (_isPastReviewDeadline(req)) continue;

      final ui = entry.value;
      if (ui == ExcuseStatus.accepted) {
        decisions.add(
          LecturerExcuseDecision(
            excuseRequestId: req.id,
            studentId: req.studentId,
            newStatus: ExcuseRequestStatus.accepted,
          ),
        );
      } else if (ui == ExcuseStatus.rejected) {
        decisions.add(
          LecturerExcuseDecision(
            excuseRequestId: req.id,
            studentId: req.studentId,
            newStatus: ExcuseRequestStatus.rejected,
            rejectionReason: _stagedRejectReason[req.id],
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
          content: Text(_tr('تم حفظ قرارات الأعذار بنجاح.', 'Excuse decisions saved successfully.')),
          backgroundColor: const Color(0xFF2B9E56),
          duration: const Duration(seconds: 2),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('فشل الحفظ. حاول مرة أخرى.', 'Save failed. Please try again.')),
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
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _buildFilterBar(),
                  ),
                  const SizedBox(height: 14),
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
    final activityLabel = _lecture.activity == 'عملي'
        ? _tr('عملي', 'Lab')
        : _tr('نظري', 'Theory');
    final sectionLabel = '${_tr('الشعبة', 'Section')} ${_lecture.section}';
    final sessionDay = widget.sessionDate;
    final dateStr =
        '${sessionDay.year}-${sessionDay.month.toString().padLeft(2, '0')}-${sessionDay.day.toString().padLeft(2, '0')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE8E8E8)),
        ),
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
                    color: Color(0xFF222222),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ProfileBackButton(onTap: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _lecture.courseName,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF213236),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            '$_lectureDayName  ·  $activityLabel  ·  $sectionLabel',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '$_lectureTimeRange  ·  ${_tr('تاريخ الجلسة', 'Session date')} $dateStr',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  static const double _colIdWidth = 110.0;
  static const double _colStatusWidth = 120.0;
  static const double _cellHPad = 14.0;
  static const double _colGap = 10.0;

  static const TextStyle _tableHeaderStyle = TextStyle(
    fontFamily: 'Cairo',
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: Color(0xFF41575D),
  );

  Widget _buildFilterBar() {
    final filters = [
      ExcuseStatusFilter.all,
      ExcuseStatusFilter.pending,
      ExcuseStatusFilter.accepted,
      ExcuseStatusFilter.rejected,
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
    if (_streamError != null) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTableHeaderRow(),
            list.isEmpty
                ? Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _tr('لا يوجد طلاب في هذا الفلتر.', 'No students in this filter.'),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                : Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEAEFF0)),
                      itemBuilder: (context, index) {
                        return _buildExcuseRow(list[index], index.isEven);
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeaderRow() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _cellHPad, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F6F7),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(13),
          topRight: Radius.circular(13),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(_tr('اسم الطالب/ة', 'Student Name'), style: _tableHeaderStyle, textAlign: TextAlign.start),
            ),
          ),
          SizedBox(width: _colGap),
          SizedBox(width: _colIdWidth, child: Center(child: Text(_tr('الرقم الجامعي', 'ID'), style: _tableHeaderStyle, textAlign: TextAlign.center))),
          SizedBox(width: _colGap),
          SizedBox(width: _colStatusWidth, child: Center(child: Text(_tr('حالة العذر', 'Excuse Status'), style: _tableHeaderStyle, textAlign: TextAlign.center))),
        ],
      ),
    );
  }

  Widget _buildExcuseRow(_ExcuseViewRow row, bool isEven) {
    final eff = _effectiveStatus(row.request);
    final baseBg = Colors.white;
    final rowBg = isEven ? baseBg : const Color(0xFFFCFEFE);
    return Material(
      color: rowBg,
      child: InkWell(
        onTap: () => _onViewRow(row),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: _cellHPad, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
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
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
              SizedBox(width: _colGap),
              SizedBox(
                width: _colIdWidth,
                child: Center(
                  child: Text(
                    row.academicId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: Color(0xFF55666B),
                    ),
                  ),
                ),
              ),
              SizedBox(width: _colGap),
              SizedBox(
                width: _colStatusWidth,
                child: Center(child: _buildStatusChip(eff)),
              ),
            ],
          ),
        ),
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
              border: enabled ? null : Border.all(color: const Color(0xFFCBD5E1), width: 1),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF006571)),
                    ),
                  )
                : Text(
                    _tr('حفظ', 'Save'),
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
