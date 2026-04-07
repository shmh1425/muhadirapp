import 'package:flutter/material.dart';

import '../../services/female_security/security_gate_scan_service.dart';
import 'female_security_nav_bar.dart';
import 'rejected_students_screen.dart';
import 'security_card_preview_screen.dart';
import 'security_prefs.dart';
import 'security_settings_screen.dart';
import 'widgets/security_date_picker_dialog.dart';
import 'widgets/security_verify_student_dialog.dart';

const _kTealLight = Color(0xFF27A2A9);
const _kTealDark = Color(0xFF006571);
const _kTextDark = Color(0xFF2D2D2D);
const _kTextMuted = Color(0xFF757575);
const _kGreyFill = Color(0xFFF0F0F0);
const _kGreyIconBg = Color(0xFFE8E8E8);
const _kGreyBorder = Color(0xFFE0E0E0);
const _kDateIconBg = Color(0xFFF5F5F5);

class AcceptedScreen extends StatefulWidget {
  const AcceptedScreen({super.key});

  @override
  State<AcceptedScreen> createState() => _AcceptedScreenState();
}

class _AcceptedScreenState extends State<AcceptedScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FemaleSecurityGateScanService _service =
      FemaleSecurityGateScanService.instance;

  int _selectedNavIndex = 0;
  bool _dateUpdated = true;
  bool _isSubmittingScan = false;
  DateTime _selectedDate = DateTime.now();
  String? _lastAcceptedErrorLog;

  @override
  void initState() {
    super.initState();
    loadSecurityGatePreferences();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return scans;
    return scans
        .where((scan) {
          return scan.studentName.toLowerCase().contains(query) ||
              scan.universityId.contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _startScanFlow() async {
    final universityId = await _openStudentLookupDialog();
    if (!mounted || universityId == null || universityId.trim().isEmpty) {
      return;
    }

    setState(() => _isSubmittingScan = true);
    try {
      await loadSecurityGatePreferences();
      final student = await _service.findStudentByUniversityId(universityId);
      if (!mounted) return;
      if (student == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لم يتم العثور على الطالبة في external_students'),
          ),
        );
        return;
      }

      final reasons = await _service.getActiveRejectionReasons();
      if (!mounted) return;

      final now = DateTime.now();
      final decision = await SecurityVerifyStudentDialog.show(
        context,
        result: StudentGateScanResult(
          fullName: student.fullName,
          universityId: student.universityId,
          major: student.major,
          scanTime: now.toString().split(' ').last.split('.').first,
          photoUrl: student.photoUrl,
        ),
        rejectionReasons: reasons,
      );

      if (!mounted || decision == null) return;

      await _service.recordGateScanDecision(
        student: student,
        gate: currentSecurityGateOption,
        decision: decision,
      );
      if (!mounted) return;

      final message = decision.isApproved
          ? 'تم تسجيل الدخول في قائمة المقبولين'
          : 'تم تسجيل الرفض في قائمة المرفوضين';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر إكمال عملية التحقق: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmittingScan = false);
      }
    }
  }

  Future<String?> _openStudentLookupDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'إدخال الرقم الجامعي',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: 'مثال: 444000018',
            hintStyle: TextStyle(fontFamily: 'Cairo'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('متابعة', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final formattedDate = _getFormattedDate(_selectedDate);

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
                      stream: _service.getAcceptedScans(
                        gateId: gateId,
                        date: _selectedDate,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasError && snapshot.error != null) {
                          _logAcceptedQueryError(
                            error: snapshot.error!,
                            stackTrace: snapshot.stackTrace,
                            gateId: gateId,
                          );
                        }
                        final scans = _filterScans(snapshot.data ?? const []);
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          children: [
                            HeaderSection(
                              onRefresh: _onRefresh,
                              onPickDate: _openDatePicker,
                              formattedDate: formattedDate,
                              isDateActive: _dateUpdated,
                            ),
                            const SizedBox(height: 20),
                            ActionButton(
                              isLoading: _isSubmittingScan,
                              onTap: _startScanFlow,
                            ),
                            const SizedBox(height: 18),
                            SearchBar(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 16),
                            if (snapshot.hasError)
                              const _SecurityStateMessage(
                                message:
                                    'تعذر تحميل سجلات المقبولين من student_gate_scans',
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
                              const _SecurityStateMessage(
                                message:
                                    'لا توجد سجلات مقبولة لهذا اليوم والبوابة',
                              )
                            else
                              _AcceptedDataTable(scans: scans),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, color: _kTealLight, size: 26),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              style: IconButton.styleFrom(foregroundColor: _kTealLight),
            ),
            const Text(
              'المقبولين',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _kTealLight,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: selectedCampusName,
              builder: (context, campus, _) => Text(
                'الموقع: $campus',
                style: const TextStyle(
                  fontSize: 14,
                  color: _kTealLight,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 6),
            ValueListenableBuilder<int>(
              valueListenable: selectedGate,
              builder: (context, gate, _) => RichText(
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
                        color: _kTealLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            DateRow(
              formattedDate: formattedDate,
              isActive: isDateActive,
              onTap: onPickDate,
            ),
          ],
        ),
      ],
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
            const SizedBox(width: 8),
            Text(
              'التاريخ: $formattedDate',
              style: const TextStyle(
                fontSize: 14,
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

class ActionButton extends StatelessWidget {
  const ActionButton({super.key, required this.onTap, this.isLoading = false});

  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kTealLight, _kTealDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: _kTealLight.withValues(alpha: 0.3),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _kTealLight.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(25),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'جاهز للمسح',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Cairo',
                    ),
                  ),
          ),
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
      height: 48,
      decoration: BoxDecoration(
        color: _kGreyFill,
        borderRadius: BorderRadius.circular(25.0),
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
            minHeight: 48,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}

class _AcceptedDataTable extends StatelessWidget {
  const _AcceptedDataTable({required this.scans});

  final List<SecurityGateScanRecord> scans;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(_kTealLight),
          headingTextStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'Cairo',
          ),
          dataTextStyle: const TextStyle(
            fontSize: 13,
            color: _kTextDark,
            fontFamily: 'Cairo',
          ),
          columnSpacing: 12,
          horizontalMargin: 16,
          columns: const [
            DataColumn(label: Text('اسم الطالب/ة')),
            DataColumn(label: Text('الرقم الجامعي')),
            DataColumn(label: Text('الوقت')),
            DataColumn(label: Text('معاينة البطاقة')),
          ],
          rows: scans.asMap().entries.map((entry) {
            final index = entry.key;
            final scan = entry.value;
            return DataRow(
              color: WidgetStateProperty.all(
                index % 2 == 1 ? const Color(0xFFFAFAFA) : Colors.white,
              ),
              cells: [
                DataCell(
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      scan.studentName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _kTextDark,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
                DataCell(Text(scan.universityId)),
                DataCell(Text(scan.formattedTime)),
                DataCell(
                  Center(
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
                          width: 34,
                          height: 34,
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
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SecurityStateMessage extends StatelessWidget {
  const _SecurityStateMessage({required this.message});

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
