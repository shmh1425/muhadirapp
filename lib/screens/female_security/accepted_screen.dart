import 'package:flutter/material.dart';
import 'female_security_nav_bar.dart';
import 'rejected_students_screen.dart';
import 'widgets/security_date_picker_dialog.dart';
import 'models/student_card_info.dart';
import 'security_card_preview_screen.dart';
import 'security_settings_screen.dart';
import 'security_prefs.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kTealLight = Color(0xFF27A2A9);
const _kTealDark = Color(0xFF006571);
const _kTextDark = Color(0xFF2D2D2D);
const _kTextMuted = Color(0xFF757575);
const _kGreyFill = Color(0xFFF0F0F0);
const _kGreyIconBg = Color(0xFFE8E8E8);
const _kGreyBorder = Color(0xFFE0E0E0);
const _kDateIconBg = Color(0xFFF5F5F5);

// ─────────────────────────────────────────────────────────────────────────────
// AcceptedScreen
// ─────────────────────────────────────────────────────────────────────────────

class AcceptedScreen extends StatefulWidget {
  const AcceptedScreen({super.key});

  @override
  State<AcceptedScreen> createState() => _AcceptedScreenState();
}

class _AcceptedScreenState extends State<AcceptedScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedNavIndex = 0;
  bool _dateUpdated = true;

  // date shown in header (temporary preview)
  DateTime _selectedDate = DateTime.now();

  final List<_StudentEntry> _students = [
    _StudentEntry('نورة الحارثي', '444000000', '09:15:22'),
    _StudentEntry('غلا القرني', '444000001', '09:15:00'),
    _StudentEntry('وضوح الترجمي', '444000002', '09:14:56'),
    _StudentEntry('لمياء الشريف', '444000003', '09:14:48'),
    _StudentEntry('سارة العمري', '444000004', '09:14:32'),
    _StudentEntry('فاطمة الزهراني', '444000005', '09:14:18'),
    _StudentEntry('هند المطيري', '444000006', '09:14:02'),
    _StudentEntry('مريم القحطاني', '444000007', '09:13:45'),
    _StudentEntry('رنا الشهري', '444000008', '09:13:30'),
    _StudentEntry('أسماء الحربي', '444000009', '09:13:15'),
    _StudentEntry('سلمى العتيبي', '444000010', '09:13:00'),
    _StudentEntry('ريم الدوسري', '444000011', '09:12:48'),
  ];

  List<_StudentEntry> get _filteredStudents {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _students;
    return _students.where((s) {
      return s.name.toLowerCase().contains(query) ||
          s.universityId.contains(query);
    }).toList();
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
      debugPrint('Selected date: $selected');
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  children: [
                    HeaderSection(
                      onRefresh: _onRefresh,
                      onPickDate: _openDatePicker,
                      formattedDate: formattedDate,
                      isDateActive: _dateUpdated,
                    ),
                    const SizedBox(height: 20),
                    const ActionButton(),
                    const SizedBox(height: 18),
                    SearchBar(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    _AcceptedDataTable(students: _filteredStudents),
                  ],
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
                  // index == 0: already on accepted
                  // index == 2: later (notifications/announcements)
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HeaderSection
// ─────────────────────────────────────────────────────────────────────────────

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
            const Text(
              'الموقع: الزاهر',
              style: TextStyle(
                fontSize: 14,
                color: _kTealLight,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w500,
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

// ─────────────────────────────────────────────────────────────────────────────
// DateRow
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// ActionButton (جاهز للمسح)
// ─────────────────────────────────────────────────────────────────────────────

class ActionButton extends StatelessWidget {
  const ActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kTealLight, _kTealDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _kTealLight.withOpacity(0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: _kTealLight.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(25),
          child: const Center(
            child: Text(
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

// ─────────────────────────────────────────────────────────────────────────────
// SearchBar
// ─────────────────────────────────────────────────────────────────────────────

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
        border: Border.all(color: _kGreyBorder.withOpacity(0.5), width: 0.5),
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

// ─────────────────────────────────────────────────────────────────────────────
// _AcceptedDataTable
// ─────────────────────────────────────────────────────────────────────────────

class _AcceptedDataTable extends StatelessWidget {
  const _AcceptedDataTable({required this.students});

  final List<_StudentEntry> students;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
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
          DataColumn(label: Text('اسم الطالب/ة'), numeric: false),
          DataColumn(label: Text('الرقم الجامعي'), numeric: false),
          DataColumn(label: Text('الوقت'), numeric: false),
          DataColumn(label: Text('معاينة البطاقة'), numeric: false),
        ],
        rows: students.asMap().entries.map((entry) {
          final index = entry.key;
          final student = entry.value;
          return DataRow(
            color: WidgetStateProperty.all(
              index % 2 == 1 ? const Color(0xFFFAFAFA) : Colors.white,
            ),
            cells: [
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    student.name,
                    style: const TextStyle(
                      fontSize: 14,
                      color: _kTextDark,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ),
              DataCell(Text(student.universityId)),
              DataCell(Text(student.time)),
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
                              student: StudentCardInfo(
                                fullName: student.name,
                                universityId: student.universityId,
                                entryTime: student.time,
                                dayLabel: 'اليوم: الإثنين',
                                dateLabel: 'التاريخ: 2025-06-26',
                                attendanceStatus: 'منتظم',
                                college: 'كلية الحاسبات',
                                major: 'هندسة البرمجيات',
                                degree: 'بكالوريوس',
                                nationality: 'سعودية',
                                extraId: '1125241000',
                                gateLabel: gateLabelWithLocation(selectedGate.value),
                              ),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StudentEntry
// ─────────────────────────────────────────────────────────────────────────────

class _StudentEntry {
  final String name;
  final String universityId;
  final String time;

  _StudentEntry(this.name, this.universityId, this.time);
}
