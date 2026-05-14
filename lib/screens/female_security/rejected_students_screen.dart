import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/security_scan_providers.dart';
import '../../services/female_security/security_gate_scan_service.dart';
import 'accepted_screen.dart';
import 'female_security_nav_bar.dart';
import 'security_card_preview_screen.dart';
import 'security_localization.dart';
import 'security_prefs.dart';
import 'security_settings_screen.dart';
import 'widgets/security_date_picker_dialog.dart';

const _kTeal = Color(0xFF27A2A9);
const _kTealDark = Color(0xFF006571);
const _kRed = Color(0xFFD32F2F);
const _kRedDark = Color(0xFFB71C1C);
const _kTextDark = Color(0xFF2D2D2D);
const _kTextMuted = Color(0xFF757575);
const _kGreyIconBg = Color(0xFFE8E8E8);
const _kGreyBorder = Color(0xFFE0E0E0);
const _kDateIconBg = Color(0xFFF5F5F5);
const _kInputFill = Color(0xFFF8F7F7);
const _kCardShadow = Color(0x0D000000);

class RejectedStudentsScreen extends ConsumerStatefulWidget {
  const RejectedStudentsScreen({super.key});

  @override
  ConsumerState<RejectedStudentsScreen> createState() =>
      _RejectedStudentsScreenState();
}

class _RejectedStudentsScreenState extends ConsumerState<RejectedStudentsScreen> {
  final TextEditingController _searchController = TextEditingController();

  int _selectedNavIndex = 1;
  bool _dateUpdated = true;
  OverlayEntry? _popupOverlay;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    loadSecurityGatePreferences();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _popupOverlay?.remove();
    super.dispose();
  }

  String _getFormattedDate(DateTime date) {
    return SecurityLocalization.formattedDate(date);
  }

  void _onRefresh() {
    setState(() {
      _dateUpdated = true;
      _selectedDate = DateTime.now();
    });
    loadSecurityGatePreferences();
  }

  Future<void> _openDatePicker() async {
    final picked = await showDialog<DateTime>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (_) => SecurityDatePickerDialog(initialDate: _selectedDate),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateUpdated = true;
      });
    }
  }

  List<SecurityGateScanRecord> _filterScans(
    List<SecurityGateScanRecord> scans,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return scans;
    return scans
        .where((scan) {
          return scan.studentName.toLowerCase().contains(query) ||
              scan.universityId.contains(query);
        })
        .toList(growable: false);
  }

  void _showReasonPopup(
    BuildContext context,
    RenderBox iconBox,
    String reason,
  ) {
    _popupOverlay?.remove();
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

    _popupOverlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          GestureDetector(
            onTap: _dismissPopup,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            top: position.dy - popupHeight - 8,
            left: left,
            child: Material(
              color: Colors.transparent,
              child: _ReasonPopup(reason: reason, onClose: _dismissPopup),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_popupOverlay!);
  }

  void _dismissPopup() {
    _popupOverlay?.remove();
    _popupOverlay = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SecurityLocalization.controller,
      builder: (context, _) => Directionality(
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
                      final day = DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day,
                      );
                      final streamKey = GateScanKey(gateId: gateId, date: day);
                      final async = ref.watch(
                        securityRejectedScansStreamProvider(streamKey),
                      );
                      return async.when(
                        data: (records) {
                          final scans = _filterScans(records);
                          return ListView(
                            padding:
                                const EdgeInsets.fromLTRB(24, 18, 24, 8),
                            children: [
                              _RejectedHeader(
                                onRefresh: _onRefresh,
                                onPickDate: _openDatePicker,
                                formattedDate:
                                    _getFormattedDate(_selectedDate),
                                isDateActive: _dateUpdated,
                              ),
                              const SizedBox(height: 12),
                              const _StatusBadge(),
                              const SizedBox(height: 12),
                              _RejectedSearchBar(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 12),
                              if (scans.isEmpty)
                                _CompactStateCard(
                                  message: SecurityLocalization
                                      .noRejectedStudents,
                                  icon: Icons.person_off_outlined,
                                )
                              else
                                _RejectedList(
                                  scans: scans,
                                  onInfoTap: _showReasonPopup,
                                ),
                            ],
                          );
                        },
                        error: (_, __) => ListView(
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                          children: [
                            _RejectedHeader(
                              onRefresh: _onRefresh,
                              onPickDate: _openDatePicker,
                              formattedDate:
                                  _getFormattedDate(_selectedDate),
                              isDateActive: _dateUpdated,
                            ),
                            const SizedBox(height: 12),
                            const _StatusBadge(),
                            const SizedBox(height: 12),
                            _RejectedSearchBar(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            _CompactStateCard(
                              message:
                                  SecurityLocalization.rejectedLoadError,
                              icon: Icons.error_outline_rounded,
                            ),
                          ],
                        ),
                        loading: () => ListView(
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                          children: [
                            _RejectedHeader(
                              onRefresh: _onRefresh,
                              onPickDate: _openDatePicker,
                              formattedDate:
                                  _getFormattedDate(_selectedDate),
                              isDateActive: _dateUpdated,
                            ),
                            const SizedBox(height: 12),
                            const _StatusBadge(),
                            const SizedBox(height: 12),
                            _RejectedSearchBar(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            const _CompactLoadingCard(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                FemaleSecurityNavBar(
                  selectedIndex: _selectedNavIndex,
                  onItemTapped: (index) {
                    setState(() => _selectedNavIndex = index);

                    if (index == 0) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const AcceptedScreen(),
                        ),
                      );
                    } else if (index == 3) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SecuritySettingsScreen(),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RejectedHeader extends StatelessWidget {
  const _RejectedHeader({
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
          SecurityLocalization.rejectedStudents,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: _kTeal,
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
    final iconColor = isActive ? _kTeal : _kTextMuted;

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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kRed, _kRedDark],
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: _kRed.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          SecurityLocalization.rejectedStatus,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Cairo',
          ),
        ),
      ),
    );
  }
}

class _RejectedSearchBar extends StatelessWidget {
  const _RejectedSearchBar({required this.controller, required this.onChanged});

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

class _RejectedList extends StatelessWidget {
  const _RejectedList({required this.scans, required this.onInfoTap});

  final List<SecurityGateScanRecord> scans;
  final void Function(BuildContext context, RenderBox iconBox, String reason)
  onInfoTap;

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
          const _RejectedTableHeader(),
          ...List.generate(scans.length, (i) {
            return _RejectedRow(
              entry: scans[i],
              isLast: i == scans.length - 1,
              isAlternate: i % 2 == 1,
              onInfoTap: onInfoTap,
            );
          }),
        ],
      ),
    );
  }
}

class _RejectedTableHeader extends StatelessWidget {
  const _RejectedTableHeader();

  @override
  Widget build(BuildContext context) {
    const iconColW = 40.0;

    Text headerText(String t, {double size = 12}) => Text(
      t,
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
          colors: [_kTeal, _kTealDark],
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

class _RejectedRow extends StatefulWidget {
  const _RejectedRow({
    required this.entry,
    required this.isLast,
    required this.isAlternate,
    required this.onInfoTap,
  });

  final SecurityGateScanRecord entry;
  final bool isLast;
  final bool isAlternate;
  final void Function(BuildContext context, RenderBox iconBox, String reason)
  onInfoTap;

  @override
  State<_RejectedRow> createState() => _RejectedRowState();
}

class _RejectedRowState extends State<_RejectedRow> {
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
              widget.entry.studentName,
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
                widget.entry.universityId,
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
                widget.entry.formattedTime,
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
                      MaterialPageRoute(
                        builder: (_) => SecurityCardPreviewScreen(
                          isAccepted: false,
                          student: widget.entry.toStudentCardInfo(),
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
                      widget.onInfoTap(
                        context,
                        box,
                        widget.entry.rejectionReasonText.isNotEmpty
                            ? widget.entry.rejectionReasonText
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
