import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/security_scan_providers.dart';
import '../../services/female_security/security_gate_scan_service.dart';
import 'female_security_nav_bar.dart';
import 'security_card_preview_screen.dart';
import 'security_localization.dart';
import 'security_nfc_verification_screen.dart';
import 'security_prefs.dart';
import 'security_settings_screen.dart';
import 'widgets/security_date_picker_dialog.dart';

enum SecurityRecordsStatus { accepted, rejected }

const _kTealLight = Color(0xFF27A2A9);
const _kTealDark = Color(0xFF006571);
const _kRed = Color(0xFFD32F2F);
const _kTextDark = Color(0xFF2D2D2D);
const _kTextMuted = Color(0xFF757575);
const _kGreyIconBg = Color(0xFFE8E8E8);
const _kGreyBorder = Color(0xFFE0E0E0);
const _kDateIconBg = Color(0xFFF5F5F5);
const _kInputFill = Color(0xFFF8F7F7);
const _kCardShadow = Color(0x0D000000);

class SecurityRecordsScreen extends ConsumerStatefulWidget {
  const SecurityRecordsScreen({
    super.key,
    this.initialStatus = SecurityRecordsStatus.accepted,
  });

  final SecurityRecordsStatus initialStatus;

  @override
  ConsumerState<SecurityRecordsScreen> createState() =>
      _SecurityRecordsScreenState();
}

class _SecurityRecordsScreenState extends ConsumerState<SecurityRecordsScreen> {
  final TextEditingController _searchController = TextEditingController();

  late SecurityRecordsStatus _status = widget.initialStatus;
  bool _dateUpdated = true;
  DateTime _selectedDate = DateTime.now();
  OverlayEntry? _reasonOverlay;
  String? _lastAcceptedErrorLog;
  String? _lastAcceptedQueryLog;

  @override
  void initState() {
    super.initState();
    _loadSecurityGatePreferencesSafely();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _reasonOverlay?.remove();
    super.dispose();
  }

  bool get _showingAccepted => _status == SecurityRecordsStatus.accepted;

  void _onRefresh() {
    setState(() {
      _dateUpdated = true;
      _selectedDate = DateTime.now();
    });
    _loadSecurityGatePreferencesSafely();
  }

  Future<void> _loadSecurityGatePreferencesSafely() async {
    try {
      await loadSecurityGatePreferences();
    } catch (error, stackTrace) {
      debugPrint(
        '[SecurityRecordsScreen] load gate preferences failed: $error',
      );
      debugPrintStack(
        label: '[SecurityRecordsScreen] load gate preferences stackTrace',
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _openDatePicker() async {
    final selected = await showDialog<DateTime>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (_) => SecurityDatePickerDialog(initialDate: _selectedDate),
    );

    if (selected != null) {
      setState(() {
        _selectedDate = selected;
        _dateUpdated = true;
      });
    }
  }

  void _openSecurityNfcVerification() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const SecurityNfcVerificationScreen(),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SecuritySettingsScreen()),
    );
  }

  List<SecurityGateScanRecord> _filterScans(
    List<SecurityGateScanRecord> scans,
  ) {
    final source = _showingAccepted ? _uniqueAcceptedScans(scans) : scans;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return source;
    return source
        .where(
          (scan) =>
              scan.studentName.toLowerCase().contains(query) ||
              scan.universityId.contains(query),
        )
        .toList(growable: false);
  }

  List<SecurityGateScanRecord> _uniqueAcceptedScans(
    List<SecurityGateScanRecord> scans,
  ) {
    final uniqueScans = <SecurityGateScanRecord>[];
    final seenStudentIds = <int>{};
    for (final scan in scans) {
      if (seenStudentIds.add(scan.studentId)) {
        uniqueScans.add(scan);
      }
    }
    return uniqueScans;
  }

  void _showReasonPopup(
    BuildContext context,
    RenderBox iconBox,
    String reason,
  ) {
    _reasonOverlay?.remove();
    final overlay = Overlay.of(context);
    final position = iconBox.localToGlobal(Offset.zero);
    final size = iconBox.size;
    final screenWidth = MediaQuery.of(context).size.width;
    const popupWidth = 220.0;
    const popupHeight = 56.0;
    final iconCenterX = position.dx + size.width / 2;
    final left = (iconCenterX - popupWidth / 2).clamp(
      12.0,
      screenWidth - popupWidth - 12,
    );

    _reasonOverlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          GestureDetector(
            onTap: _dismissReasonPopup,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            top: position.dy - popupHeight - 8,
            left: left,
            child: Material(
              color: Colors.transparent,
              child: _ReasonPopup(reason: reason, onClose: _dismissReasonPopup),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_reasonOverlay!);
  }

  void _dismissReasonPopup() {
    _reasonOverlay?.remove();
    _reasonOverlay = null;
    if (mounted) setState(() {});
  }

  void _logAcceptedQueryError({
    required Object error,
    required StackTrace? stackTrace,
    required String gateId,
  }) {
    final message =
        '[SecurityRecordsScreen] accepted student_gate_scans query failed. '
        'gateId=$gateId, '
        'scanDateKey=${formatScanDateKey(_selectedDate)}, '
        'status=accepted, '
        'error=$error';

    if (_lastAcceptedErrorLog == message) return;
    _lastAcceptedErrorLog = message;
    debugPrint(message);
    if (stackTrace != null) {
      debugPrintStack(
        label: '[SecurityRecordsScreen] accepted scans stackTrace',
        stackTrace: stackTrace,
      );
    }
  }

  void _logAcceptedQueryValues(String gateId) {
    if (!_showingAccepted) return;
    final message =
        '[SecurityRecordsScreen] using accepted query. '
        'collection=student_gate_scans, status=accepted, '
        'gateId=$gateId, '
        'scanDateKey=${formatScanDateKey(_selectedDate)}';
    if (_lastAcceptedQueryLog == message) return;
    _lastAcceptedQueryLog = message;
    debugPrint(message);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SecurityLocalization.controller,
      builder: (context, _) {
        final formattedDate = SecurityLocalization.formattedDate(_selectedDate);

        return Directionality(
          textDirection: SecurityLocalization.direction,
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<String>(
                      valueListenable: selectedGateId,
                      builder: (context, gateId, _) {
                        _logAcceptedQueryValues(gateId);
                        final day = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                        );
                        final streamKey = GateScanKey(
                          gateId: gateId,
                          date: day,
                        );
                        final async = _showingAccepted
                            ? ref.watch(
                                securityAcceptedScansStreamProvider(streamKey),
                              )
                            : ref.watch(
                                securityRejectedScansStreamProvider(streamKey),
                              );

                        return async.when(
                          data: (records) => _buildRecordsList(
                            records: _filterScans(records),
                            formattedDate: formattedDate,
                          ),
                          error: (error, stackTrace) {
                            if (_showingAccepted) {
                              _logAcceptedQueryError(
                                error: error,
                                stackTrace: stackTrace,
                                gateId: gateId,
                              );
                            }
                            return _buildRecordsList(
                              records: const [],
                              formattedDate: formattedDate,
                              error: true,
                            );
                          },
                          loading: () => _buildRecordsList(
                            records: const [],
                            formattedDate: formattedDate,
                            loading: true,
                          ),
                        );
                      },
                    ),
                  ),
                  FemaleSecurityNavBar(
                    selectedIndex: 0,
                    onItemTapped: (index) {
                      if (index == 1) {
                        _openSecurityNfcVerification();
                      } else if (index == 2) {
                        _openSettings();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecordsList({
    required List<SecurityGateScanRecord> records,
    required String formattedDate,
    bool loading = false,
    bool error = false,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      children: [
        _RecordsHeader(
          onRefresh: _onRefresh,
          onPickDate: _openDatePicker,
          formattedDate: formattedDate,
          isDateActive: _dateUpdated,
        ),
        const SizedBox(height: 12),
        _StatusSelector(
          status: _status,
          onChanged: (value) {
            if (value == _status) return;
            setState(() {
              _status = value;
              _reasonOverlay?.remove();
              _reasonOverlay = null;
            });
          },
        ),
        const SizedBox(height: 12),
        _RecordsSearchBar(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        if (loading)
          const _CompactLoadingCard()
        else if (error)
          _CompactStateCard(
            message: _showingAccepted
                ? SecurityLocalization.acceptedLoadError
                : SecurityLocalization.rejectedLoadError,
            icon: Icons.error_outline_rounded,
          )
        else if (records.isEmpty)
          _CompactStateCard(
            message: _showingAccepted
                ? SecurityLocalization.noAcceptedStudents
                : SecurityLocalization.noRejectedStudents,
            icon: _showingAccepted
                ? Icons.how_to_reg_outlined
                : Icons.person_off_outlined,
          )
        else
          _RecordsTable(
            records: records,
            status: _status,
            onReasonTap: _showReasonPopup,
          ),
      ],
    );
  }
}

class _RecordsHeader extends StatelessWidget {
  const _RecordsHeader({
    required this.onRefresh,
    required this.onPickDate,
    required this.formattedDate,
    this.isDateActive = true,
  });

  final VoidCallback onRefresh;
  final VoidCallback onPickDate;
  final String formattedDate;
  final bool isDateActive;

  @override
  Widget build(BuildContext context) {
    final infoTextAlign = SecurityLocalization.isEnglish
        ? TextAlign.left
        : TextAlign.right;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          SecurityLocalization.records,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: _kTealLight,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          textDirection: TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Material(
              color: _kInputFill,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onRefresh,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Center(
                    child: Icon(
                      Icons.refresh_rounded,
                      color: _kTextMuted,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Directionality(
                textDirection: SecurityLocalization.direction,
                child: Column(
                  crossAxisAlignment: SecurityLocalization.isEnglish
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: selectedCampusName,
                      builder: (context, campus, _) => Text(
                        '${SecurityLocalization.location}: '
                        '${SecurityLocalization.campusName(campus)}',
                        textAlign: infoTextAlign,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _kTextDark,
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: SecurityLocalization.direction,
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: selectedGate,
                          builder: (context, gate, _) => Text(
                            '${SecurityLocalization.gate} $gate',
                            textAlign: infoTextAlign,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kTextDark,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _DateRow(
                          formattedDate: formattedDate,
                          isActive: isDateActive,
                          onTap: onPickDate,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({required this.status, required this.onChanged});

  final SecurityRecordsStatus status;
  final ValueChanged<SecurityRecordsStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _kInputFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGreyBorder.withValues(alpha: 0.75)),
      ),
      child: Row(
        children: [
          _SegmentButton(
            label: SecurityLocalization.acceptedRecords,
            selected: status == SecurityRecordsStatus.accepted,
            selectedColor: _kTealLight,
            onTap: () => onChanged(SecurityRecordsStatus.accepted),
          ),
          const SizedBox(width: 6),
          _SegmentButton(
            label: SecurityLocalization.rejectedRecords,
            selected: status == SecurityRecordsStatus.rejected,
            selectedColor: _kRed,
            onTap: () => onChanged(SecurityRecordsStatus.rejected),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? selectedColor : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : _kTextMuted,
              fontFamily: 'Cairo',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.formattedDate,
    this.isActive = true,
    this.onTap,
  });

  final String formattedDate;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? _kTealLight : _kTextMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _kDateIconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${SecurityLocalization.date}: $formattedDate',
              style: const TextStyle(
                fontSize: 12,
                color: _kTextDark,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordsSearchBar extends StatelessWidget {
  const _RecordsSearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: _kInputFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGreyBorder.withValues(alpha: 0.75)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textDirection: SecurityLocalization.direction,
        textAlign: SecurityLocalization.isEnglish
            ? TextAlign.left
            : TextAlign.right,
        decoration: InputDecoration(
          hintText: SecurityLocalization.searchHint,
          hintStyle: const TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 14,
            fontFamily: 'Cairo',
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 14),
            child: Icon(Icons.search, color: Color(0xFF9E9E9E), size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 42,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
        ),
      ),
    );
  }
}

class _CompactStateCard extends StatelessWidget {
  const _CompactStateCard({required this.message, required this.icon});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _kInputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGreyBorder.withValues(alpha: 0.7)),
        boxShadow: const [
          BoxShadow(color: _kCardShadow, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: _kTextMuted),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kTextMuted,
              fontSize: 13,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactLoadingCard extends StatelessWidget {
  const _CompactLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: _kInputFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kGreyBorder.withValues(alpha: 0.7)),
        boxShadow: const [
          BoxShadow(color: _kCardShadow, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _RecordsTable extends StatelessWidget {
  const _RecordsTable({
    required this.records,
    required this.status,
    required this.onReasonTap,
  });

  final List<SecurityGateScanRecord> records;
  final SecurityRecordsStatus status;
  final void Function(BuildContext context, RenderBox iconBox, String reason)
  onReasonTap;

  bool get _accepted => status == SecurityRecordsStatus.accepted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _kGreyBorder),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: _kCardShadow, blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _RecordsTableHeader(showReason: !_accepted),
          ...List.generate(records.length, (index) {
            return _RecordsTableRow(
              record: records[index],
              accepted: _accepted,
              isLast: index == records.length - 1,
              isAlternate: index % 2 == 1,
              onReasonTap: onReasonTap,
            );
          }),
        ],
      ),
    );
  }
}

class _RecordsTableHeader extends StatelessWidget {
  const _RecordsTableHeader({required this.showReason});

  final bool showReason;

  @override
  Widget build(BuildContext context) {
    const iconColW = 40.0;

    Text headerText(String text, {double size = 12}) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        fontFamily: 'Cairo',
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_kTealLight, _kTealDark],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Align(
              alignment: SecurityLocalization.isEnglish
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: headerText(SecurityLocalization.studentName),
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(child: headerText(SecurityLocalization.universityId)),
          ),
          Expanded(
            flex: 2,
            child: Center(child: headerText(SecurityLocalization.scanTime)),
          ),
          SizedBox(
            width: iconColW,
            child: Center(
              child: headerText(SecurityLocalization.preview, size: 10),
            ),
          ),
          if (showReason)
            SizedBox(
              width: iconColW,
              child: Center(
                child: headerText(SecurityLocalization.reason, size: 10),
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordsTableRow extends StatefulWidget {
  const _RecordsTableRow({
    required this.record,
    required this.accepted,
    required this.isLast,
    required this.isAlternate,
    required this.onReasonTap,
  });

  final SecurityGateScanRecord record;
  final bool accepted;
  final bool isLast;
  final bool isAlternate;
  final void Function(BuildContext context, RenderBox iconBox, String reason)
  onReasonTap;

  @override
  State<_RecordsTableRow> createState() => _RecordsTableRowState();
}

class _RecordsTableRowState extends State<_RecordsTableRow> {
  final GlobalKey _infoKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    const iconColW = 40.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: widget.isAlternate ? const Color(0xFFFAFAFA) : Colors.white,
        border: Border(bottom: BorderSide(color: _kGreyBorder, width: 0.6)),
        borderRadius: widget.isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              widget.record.studentName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: SecurityLocalization.isEnglish
                  ? TextAlign.left
                  : TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: _kTextDark,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: Text(
                widget.record.universityId,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kTextDark,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                widget.record.formattedTime,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kTextDark,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          SizedBox(
            width: iconColW,
            child: Center(
              child: Material(
                color: _kGreyIconBg,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SecurityCardPreviewScreen(
                          isAccepted: widget.accepted,
                          student: widget.record.toStudentCardInfo(),
                        ),
                      ),
                    );
                  },
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 30,
                    height: 30,
                    child: Center(
                      child: Icon(
                        Icons.visibility_outlined,
                        size: 17,
                        color: _kTextMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!widget.accepted)
            SizedBox(
              width: iconColW,
              child: Center(
                child: Material(
                  key: _infoKey,
                  color: _kGreyIconBg,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () {
                      final box =
                          _infoKey.currentContext?.findRenderObject()
                              as RenderBox?;
                      if (box != null && box.hasSize) {
                        widget.onReasonTap(
                          context,
                          box,
                          widget.record.rejectionReasonText.isNotEmpty
                              ? widget.record.rejectionReasonText
                              : SecurityLocalization.noReasonRecorded,
                        );
                      }
                    },
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 30,
                      height: 30,
                      child: Center(
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 17,
                          color: _kTextMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReasonPopup extends StatelessWidget {
  const _ReasonPopup({required this.reason, required this.onClose});

  final String reason;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: _kGreyBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 17, color: _kRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(
                fontSize: 13,
                color: _kTextDark,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(12),
            child: const Icon(Icons.close, size: 18, color: _kTextMuted),
          ),
        ],
      ),
    );
  }
}
