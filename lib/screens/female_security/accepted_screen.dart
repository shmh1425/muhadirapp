import 'package:flutter/material.dart';
import 'female_security_nav_bar.dart';
import 'rejected_students_screen.dart';

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

  String _getFormattedDate() {
    final now = DateTime.now();
    const days = [
      'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء',
      'الخميس', 'الجمعة', 'السبت',
    ];
    final dayName = days[now.weekday % 7];
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    final y = now.year;
    return '$dayName $d-$m-$y';
  }

  void _onRefresh() {
    setState(() {
      _dateUpdated = true;
    });
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
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  children: [
                    HeaderSection(
                      onRefresh: _onRefresh,
                      formattedDate: _getFormattedDate(),
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
                    _AcceptedList(students: _filteredStudents),
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

// ─────────────────────────────────────────────────────────────────────────────
// HeaderSection
// ─────────────────────────────────────────────────────────────────────────────

class HeaderSection extends StatelessWidget {
  const HeaderSection({
    super.key,
    required this.onRefresh,
    required this.formattedDate,
    this.isDateActive = true,
  });

  final VoidCallback onRefresh;
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
              style: IconButton.styleFrom(
                foregroundColor: _kTealLight,
              ),
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
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: _kTextDark,
                  fontFamily: 'Cairo',
                ),
                children: [
                  TextSpan(text: 'بوابة رقم '),
                  TextSpan(
                    text: '3',
                    style: TextStyle(
                      color: _kTealLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            DateRow(
              formattedDate: formattedDate,
              isActive: isDateActive,
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
  });

  final String formattedDate;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final iconColor = isActive ? _kTealLight : _kTextMuted;
    return Row(
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
      height: 44,
      decoration: BoxDecoration(
        color: _kGreyFill,
        borderRadius: BorderRadius.circular(14),
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
          prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 44),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AcceptedList
// ─────────────────────────────────────────────────────────────────────────────

class _AcceptedList extends StatelessWidget {
  const _AcceptedList({required this.students});

  final List<_StudentEntry> students;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const TableHeader(),
        ...List.generate(students.length, (i) {
          return RowItem(
            student: students[i],
            isLast: i == students.length - 1,
            isAlternate: i % 2 == 1,
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TableHeader
// ─────────────────────────────────────────────────────────────────────────────

class TableHeader extends StatelessWidget {
  const TableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: const BoxDecoration(
        color: _kTealLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Center(
              child: Text(
                'معاينة البطاقة',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'الوقت',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'الرقم الجامعي',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'اسم الطالبة',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RowItem
// ─────────────────────────────────────────────────────────────────────────────

class RowItem extends StatelessWidget {
  const RowItem({
    super.key,
    required this.student,
    required this.isLast,
    this.isAlternate = false,
  });

  final _StudentEntry student;
  final bool isLast;
  final bool isAlternate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isAlternate ? const Color(0xFFFAFAFA) : Colors.white,
        border: Border(
          bottom: BorderSide(color: _kGreyBorder, width: 0.6),
        ),
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(12))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Center(
              child: Material(
                color: _kGreyIconBg,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () {},
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                    child: Center(
                      child: Icon(Icons.visibility_outlined, size: 17, color: _kTextMuted),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                student.time,
                style: const TextStyle(
                  fontSize: 13,
                  color: _kTextDark,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                student.universityId,
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
            child: Text(
              student.name,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                color: _kTextDark,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
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
