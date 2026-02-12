import 'package:flutter/material.dart';
import 'female_security_nav_bar.dart';

class AcceptedScreen extends StatefulWidget {
  const AcceptedScreen({super.key});

  @override
  State<AcceptedScreen> createState() => _AcceptedScreenState();
}

class _AcceptedScreenState extends State<AcceptedScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedNavIndex = 0;

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
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
    ];
    final dayName = days[now.weekday % 7];
    return '$dayName ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    _buildReadyForScanButton(),
                    const SizedBox(height: 14),
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildDataTable(),
                  ],
                ),
              ),
              FemaleSecurityNavBar(
                selectedIndex: _selectedNavIndex,
                onItemTapped: (index) {
                  setState(() {
                    _selectedNavIndex = index;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'المقبولين',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF27A2A9),
                  fontFamily: 'Cairo',
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: IconButton(
                onPressed: () {
                  setState(() {});
                },
                icon: const Icon(
                  Icons.refresh,
                  color: Color(0xFF27A2A9),
                  size: 26,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'الموقع: الزاهر',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF27A2A9),
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontFamily: 'Cairo',
                  ),
                  children: [
                    TextSpan(text: 'بوابة رقم '),
                    TextSpan(
                      text: '3',
                      style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'التاريخ: ${_getFormattedDate()}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadyForScanButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF5BC4C9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(12),
            child: const Center(
              child: Text(
                'جاهز للمسح',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'بحث بالإسم أو الرقم الجامعي',
          hintStyle: const TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 14,
            fontFamily: 'Cairo',
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF9E9E9E),
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    final students = _filteredStudents;
    return Column(
      children: [
        _buildTableHeader(),
        ...students.asMap().entries.map((entry) {
          return _buildTableRow(entry.value, entry.key);
        }),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF27A2A9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Center(
              child: Text(
                'معاينة البطاقة',
                style: const TextStyle(
                  fontSize: 11,
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
                  fontSize: 12,
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
                'الرقم الجامعي',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(_StudentEntry student, int index) {
    final isEven = index % 2 == 0;
    final isLast = index == _filteredStudents.length - 1;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF8F8F8),
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(8))
            : null,
        border: Border(
          left: BorderSide(color: Colors.grey.shade200),
          right: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Center(
              child: Material(
                color: const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: Colors.black54,
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
                  fontSize: 12,
                  color: Colors.black87,
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
                  fontSize: 12,
                  color: Colors.black87,
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
                fontSize: 13,
                color: Colors.black87,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentEntry {
  final String name;
  final String universityId;
  final String time;

  _StudentEntry(this.name, this.universityId, this.time);
}
