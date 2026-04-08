import 'package:flutter/material.dart';

import '../../services/female_security/security_gate_scan_service.dart';
import 'accepted_screen.dart';
import 'female_security_nav_bar.dart';
import 'security_card_preview_screen.dart';
import 'security_prefs.dart';
import 'security_settings_screen.dart';
import 'widgets/security_date_picker_dialog.dart';

const _kTeal = Color(0xFF27A2A9);
const _kRed = Color(0xFFC00000);
const _kTextDark = Color(0xFF2D2D2D);
const _kTextMuted = Color(0xFF757575);
const _kGreyFill = Color(0xFFF0F0F0);
const _kGreyIconBg = Color(0xFFE8E8E8);
const _kGreyBorder = Color(0xFFE0E0E0);
const _kDateIconBg = Color(0xFFF5F5F5);

class RejectedStudentsScreen extends StatefulWidget {
  const RejectedStudentsScreen({super.key});

  @override
  State<RejectedStudentsScreen> createState() => _RejectedStudentsScreenState();
}

class _RejectedStudentsScreenState extends State<RejectedStudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FemaleSecurityGateScanService _service =
      FemaleSecurityGateScanService.instance;

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
    const days = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    final dayName = days[date.weekday % 7];
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year;
    return '$dayName $d-$m-$y';
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: selectedGateId,
                  builder: (context, gateId, _) {
                    return StreamBuilder<List<SecurityGateScanRecord>>(
                      stream: _service.getRejectedScans(
                        gateId: gateId,
                        date: _selectedDate,
                      ),
                      builder: (context, snapshot) {
                        final scans = _filterScans(snapshot.data ?? const []);
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          children: [
                            _RejectedHeader(
                              onRefresh: _onRefresh,
                              onPickDate: _openDatePicker,
                              formattedDate: _getFormattedDate(_selectedDate),
                              isDateActive: _dateUpdated,
                            ),
                            const SizedBox(height: 20),
                            const _StatusBadge(),
                            const SizedBox(height: 18),
                            _RejectedSearchBar(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            if (snapshot.hasError)
                              const _StateMessage(
                                message:
                                    'تعذر تحميل سجلات المرفوضين من student_gate_scans',
                              )
                            else if (snapshot.connectionState ==
                                    ConnectionState.waiting &&
                                !snapshot.hasData)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (scans.isEmpty)
                              const _StateMessage(
                                message:
                                    'لا توجد سجلات مرفوضة لهذا اليوم والبوابة',
                              )
                            else
                              _RejectedList(
                                scans: scans,
                                onInfoTap: _showReasonPopup,
                              ),
                          ],
                        );
                      },
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
                      MaterialPageRoute(builder: (_) => const AcceptedScreen()),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, color: _kTextMuted, size: 26),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ),
            const Text(
              'المرفوضين',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _kTeal,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: selectedCampusName,
                builder: (context, campus, _) => Text(
                  'الموقع: $campus',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _kTextDark,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              ValueListenableBuilder<int>(
                valueListenable: selectedGate,
                builder: (context, gate, _) => RichText(
                  textAlign: TextAlign.right,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: _kTextDark,
                      fontFamily: 'Cairo',
                    ),
                    children: [
                      const TextSpan(text: 'بوابة رقم '),
                      TextSpan(
                        text: '$gate',
                        style: const TextStyle(
                          color: _kTeal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _DateRow(
                formattedDate: formattedDate,
                isActive: isDateActive,
                onTap: onPickDate,
              ),
            ],
          ),
        ),
      ],
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'التاريخ: $formattedDate',
          style: const TextStyle(
            fontSize: 14,
            color: _kTextDark,
            fontFamily: 'Cairo',
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _kDateIconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: iconColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _kRed,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Center(
        child: Text(
          'مرفوض',
          style: TextStyle(
            fontSize: 22,
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
      height: 44,
      decoration: BoxDecoration(
        color: _kGreyFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _kGreyBorder.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'بحث بالإسم أو الرقم الجامعي',
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
            minHeight: 44,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
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
    return Column(
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: const BoxDecoration(
        color: _kTeal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerRight,
              child: headerText('اسم الطالب/ة'),
            ),
          ),
          Expanded(flex: 3, child: Center(child: headerText('الرقم الجامعي'))),
          Expanded(flex: 2, child: Center(child: headerText('الوقت'))),
          SizedBox(
            width: iconColW,
            child: Center(child: headerText('معاينة', size: 10)),
          ),
          SizedBox(
            width: iconColW,
            child: Center(child: headerText('السبب', size: 10)),
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
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
                    width: 32,
                    height: 32,
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
                            : 'لا يوجد سبب مسجل',
                      );
                    }
                  },
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: Text(
                        'i',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _kTextMuted,
                          fontFamily: 'Cairo',
                        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
          const SizedBox(width: 10),
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

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: _kGreyFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _kTextMuted, fontFamily: 'Cairo'),
        ),
      ),
    );
  }
}
