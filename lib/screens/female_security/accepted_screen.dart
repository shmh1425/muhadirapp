import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/security_scan_providers.dart';
import '../../services/female_security/security_gate_scan_service.dart';
import 'female_security_nav_bar.dart';
import 'rejected_students_screen.dart';
import 'security_card_preview_screen.dart';
import 'security_localization.dart';
import 'security_prefs.dart';
import 'security_settings_screen.dart';
import 'widgets/security_date_picker_dialog.dart';

const _kTealLight = Color(0xFF27A2A9);
const _kTealDark = Color(0xFF006571);
const _kTextDark = Color(0xFF2D2D2D);
const _kTextMuted = Color(0xFF757575);
const _kGreyIconBg = Color(0xFFE8E8E8);
const _kGreyBorder = Color(0xFFE0E0E0);
const _kDateIconBg = Color(0xFFF5F5F5);
const _kInputFill = Color(0xFFF8F7F7);
const _kCardShadow = Color(0x0D000000);

class AcceptedScreen extends ConsumerStatefulWidget {
  const AcceptedScreen({super.key});

  @override
  ConsumerState<AcceptedScreen> createState() => _AcceptedScreenState();
}

class _AcceptedScreenState extends ConsumerState<AcceptedScreen> {
  final TextEditingController _searchController = TextEditingController();

  int _selectedNavIndex = 0;
  bool _dateUpdated = true;
  DateTime _selectedDate = DateTime.now();
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
    _loadSecurityGatePreferencesSafely();
  }

  Future<void> _loadSecurityGatePreferencesSafely() async {
    try {
      await loadSecurityGatePreferences();
    } catch (error, stackTrace) {
      debugPrint('[AcceptedScreen] loadSecurityGatePreferences failed: $error');
      debugPrintStack(
        label: '[AcceptedScreen] loadSecurityGatePreferences stackTrace',
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

  List<SecurityGateScanRecord> _filterScans(
    List<SecurityGateScanRecord> scans,
  ) {
    final uniqueAcceptedScans = <SecurityGateScanRecord>[];
    final seenStudentIds = <int>{};
    for (final scan in scans) {
      if (seenStudentIds.add(scan.studentId)) {
        uniqueAcceptedScans.add(scan);
      }
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return uniqueAcceptedScans;
    return uniqueAcceptedScans
        .where(
          (scan) =>
              scan.studentName.toLowerCase().contains(query) ||
              scan.universityId.contains(query),
        )
        .toList(growable: false);
  }

  void _logAcceptedQueryError({
    required Object error,
    required StackTrace? stackTrace,
    required String gateId,
  }) {
    final message =
        '[AcceptedScreen] student_gate_scans query failed. '
        'gateId=$gateId, '
        'scanDateKey=${formatScanDateKey(_selectedDate)}, '
        'status=accepted, '
        'error=$error';

    if (_lastAcceptedErrorLog == message) return;
    _lastAcceptedErrorLog = message;
    debugPrint(message);
    if (stackTrace != null) {
      debugPrintStack(
        label: '[AcceptedScreen] student_gate_scans stackTrace',
        stackTrace: stackTrace,
      );
    }
  }

  void _logAcceptedQueryValues(String gateId) {
    final message =
        '[AcceptedScreen] using accepted query. '
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
        final formattedDate = _getFormattedDate(_selectedDate);

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
                        final streamKey = GateScanKey(gateId: gateId, date: day);
                        final async = ref.watch(
                          securityAcceptedScansStreamProvider(streamKey),
                        );
                        return async.when(
                          data: (records) {
                            final scans = _filterScans(records);
                            return ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 18, 24, 8),
                              children: [
                                HeaderSection(
                                  onRefresh: _onRefresh,
                                  onPickDate: _openDatePicker,
                                  formattedDate: formattedDate,
                                  isDateActive: _dateUpdated,
                                ),
                                const SizedBox(height: 12),
                                const _AcceptedStatusBanner(),
                                const SizedBox(height: 12),
                                SearchBar(
                                  controller: _searchController,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 12),
                                if (scans.isEmpty)
                                  _CompactStateCard(
                                    message: SecurityLocalization
                                        .noAcceptedStudents,
                                    icon: Icons.how_to_reg_outlined,
                                  )
                                else
                                  _AcceptedTable(scans: scans),
                              ],
                            );
                          },
                          error: (e, st) {
                            _logAcceptedQueryError(
                              error: e,
                              stackTrace: st,
                              gateId: gateId,
                            );
                            return ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 18, 24, 8),
                              children: [
                                HeaderSection(
                                  onRefresh: _onRefresh,
                                  onPickDate: _openDatePicker,
                                  formattedDate: formattedDate,
                                  isDateActive: _dateUpdated,
                                ),
                                const SizedBox(height: 12),
                                const _AcceptedStatusBanner(),
                                const SizedBox(height: 12),
                                SearchBar(
                                  controller: _searchController,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 12),
                                _CompactStateCard(
                                  message:
                                      SecurityLocalization.acceptedLoadError,
                                  icon: Icons.error_outline_rounded,
                                ),
                              ],
                            );
                          },
                          loading: () => ListView(
                            padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                            children: [
                              HeaderSection(
                                onRefresh: _onRefresh,
                                onPickDate: _openDatePicker,
                                formattedDate: formattedDate,
                                isDateActive: _dateUpdated,
                              ),
                              const SizedBox(height: 12),
                              const _AcceptedStatusBanner(),
                              const SizedBox(height: 12),
                              SearchBar(
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

                      if (index == 1) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const RejectedStudentsScreen(),
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
        );
      },
    );
  }
}

class HeaderSection extends StatelessWidget {
  const HeaderSection({
    super.key,
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
          SecurityLocalization.acceptedStudents,
          textAlign: TextAlign.center,
          style: TextStyle(
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
                        DateRow(
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

class _AcceptedStatusBanner extends StatelessWidget {
  const _AcceptedStatusBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kTealLight, _kTealDark],
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: _kTealLight.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          SecurityLocalization.acceptedBannerStatus,
          style: const TextStyle(
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

class _AcceptedTableHeader extends StatelessWidget {
  const _AcceptedTableHeader();

  @override
  Widget build(BuildContext context) {
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
            width: 46,
            child: Center(
              child: headerText(SecurityLocalization.preview, size: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class DateRow extends StatelessWidget {
  const DateRow({
    super.key,
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

class SearchBar extends StatelessWidget {
  const SearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

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

class _AcceptedTable extends StatelessWidget {
  const _AcceptedTable({required this.scans});

  final List<SecurityGateScanRecord> scans;

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
          const _AcceptedTableHeader(),
          ...List.generate(scans.length, (index) {
            final scan = scans[index];
            return _AcceptedTableRow(
              scan: scan,
              isLast: index == scans.length - 1,
              isAlternate: index % 2 == 1,
            );
          }),
        ],
      ),
    );
  }
}

class _AcceptedTableRow extends StatelessWidget {
  const _AcceptedTableRow({
    required this.scan,
    required this.isLast,
    required this.isAlternate,
  });

  final SecurityGateScanRecord scan;
  final bool isLast;
  final bool isAlternate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: isAlternate ? const Color(0xFFFAFAFA) : Colors.white,
        border: Border(bottom: BorderSide(color: _kGreyBorder, width: 0.6)),
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              scan.studentName,
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
                scan.universityId,
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
                scan.formattedTime,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kTextDark,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          SizedBox(
            width: 46,
            child: Center(
              child: Material(
                color: _kGreyIconBg,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SecurityCardPreviewScreen(
                          isAccepted: true,
                          student: scan.toStudentCardInfo(),
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
                        size: 16,
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
