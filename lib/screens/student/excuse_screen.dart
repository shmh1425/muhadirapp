import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'components/notification_bell.dart';
import 'rejection_detail_screen.dart';
import 'submit_excuse_screen.dart';
import 'notifications_screen.dart';
import '../../models/attendance/manual_attendance_record.dart';
import '../../models/excuse/excuse_request.dart';
import '../../services/attendance/manual_attendance_service.dart';
import '../../services/excuse/excuse_service.dart';
import '../../services/student_auth_service.dart';

class ExcuseScreen extends StatefulWidget {
  const ExcuseScreen({super.key});

  @override
  State<ExcuseScreen> createState() => _ExcuseScreenState();
}

class _ExcuseScreenState extends State<ExcuseScreen> {
  static const Color _primaryColor = Color(0xFF006571);
  static const Color _tabBackground = Color(0xFFF5F5F5);

  final ManualAttendanceService _attendance = ManualAttendanceService.instance;
  final ExcuseService _excuses = ExcuseService.instance;

  final List<String> _filters = <String>[
    'الكل',
    'قيد الانتظار',
    'تم القبول',
    'تم الرفض',
    'رفع عذر',
    'مغلق',
  ];

  String? _selectedCourse;
  String _selectedFilter = 'الكل';

  Future<List<String>> _fetchStudentCourses(int studentId) async {
    if (studentId <= 0) return <String>[];
    final enrollSnap = await FirebaseFirestore.instance
        .collection('student_section_enrollments')
        .where('studentId', isEqualTo: studentId)
        .get();

    final sectionIds = enrollSnap.docs
        .map((d) => (d.data()['sectionId'] ?? '').toString())
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();
    if (sectionIds.isEmpty) return <String>[];

    final sectionsRef = FirebaseFirestore.instance.collection('sections');
    final coursesRef = FirebaseFirestore.instance.collection('courses');
    final names = <String>{};
    for (final sectionId in sectionIds) {
      final sectionSnap = await sectionsRef.doc(sectionId).get();
      if (!sectionSnap.exists) continue;
      final data = sectionSnap.data() ?? <String, dynamic>{};
      final code = (data['courseCode'] ?? '').toString().trim();
      String ar = (data['courseName_Ar'] ?? '').toString().trim();
      if (ar.isEmpty && code.isNotEmpty) {
        final courseSnap = await coursesRef.doc(code).get();
        if (courseSnap.exists) {
          final courseData = courseSnap.data() ?? <String, dynamic>{};
          ar = (courseData['courseName_Ar'] ?? '').toString().trim();
        }
      }
      final name = ar.isNotEmpty ? ar : code;
      if (name.trim().isNotEmpty) names.add(name.trim());
    }
    final list = names.toList()..sort();
    return list;
  }

  List<_ExcuseItem> _mapRecordsToExcuseItems(
    List<ManualAttendanceRecord> records,
    Map<String, String> sectionIdToCourseNameAr,
  ) {
    final items = <_ExcuseItem>[];
    for (final r in records) {
      if (r.status != ManualAttendanceStatus.absent &&
          r.status != ManualAttendanceStatus.excused) {
        continue;
      }
      final isClosed =
          r.status == ManualAttendanceStatus.absent && _isClosedForDate(r.lectureDate);
      final status = isClosed
          ? 'مغلق'
          : (r.status == ManualAttendanceStatus.excused ? 'تم القبول' : 'معلقة');
      final sectionId = r.sectionId.trim();
      final courseNameAr = sectionId.isEmpty ? '' : (sectionIdToCourseNameAr[sectionId] ?? '');
      final courseName = courseNameAr.trim().isNotEmpty
          ? courseNameAr.trim()
          : (r.courseName.trim().isEmpty ? '—' : r.courseName.trim());
      items.add(_ExcuseItem(
        course: courseName,
        timeRange:
            '${_formatHHmm(r.lectureStartTime)}-${_formatHHmm(r.lectureEndTime)}',
        dateText: _formatArabicDate(r.lectureDate),
        status: status,
        rawDate: r.lectureDate,
        sectionId: sectionId,
        rawStartTime: r.lectureStartTime,
      ));
    }
    items.sort((a, b) => b.rawDate.compareTo(a.rawDate));
    return items;
  }

  List<_ExcuseItem> _mergeRequestsIntoItems({
    required List<_ExcuseItem> baseItems,
    required List<ExcuseRequest> requests,
  }) {
    if (requests.isEmpty) return baseItems;

    String key(DateTime d, String start, String sectionId) {
      final dd = DateTime(d.year, d.month, d.day);
      return '${dd.toIso8601String()}|${start.trim()}|${sectionId.trim()}';
    }

    final reqMap = <String, ExcuseRequest>{};
    for (final r in requests) {
      final k = key(r.lectureDate, r.lectureStartTime, r.sectionId);
      reqMap[k] = r;
    }

    final updated = <_ExcuseItem>[];
    for (final item in baseItems) {
      final k = key(item.rawDate, item.rawStartTime, item.sectionId);
      final req = reqMap[k];
      if (req == null) {
        updated.add(item);
        continue;
      }
      final status = switch (req.status) {
        ExcuseRequestStatus.pending => 'قيد الانتظار',
        ExcuseRequestStatus.accepted => 'تم القبول',
        ExcuseRequestStatus.rejected => 'تم الرفض',
        ExcuseRequestStatus.expired => 'منتهي',
      };
      updated.add(item.copyWith(
        course: req.courseNameAr.trim().isNotEmpty ? req.courseNameAr.trim() : item.course,
        status: status,
        rejectionReason: req.rejectionReason,
      ));
    }
    return updated;
  }

  bool _isClosedForDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(d).inDays >= 3;
  }

  String _arabicWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'الاثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.thursday:
        return 'الخميس';
      case DateTime.friday:
        return 'الجمعة';
      case DateTime.saturday:
        return 'السبت';
      case DateTime.sunday:
      default:
        return 'الأحد';
    }
  }

  String _arabicMonth(int month) {
    const months = <int, String>{
      1: 'يناير',
      2: 'فبراير',
      3: 'مارس',
      4: 'أبريل',
      5: 'مايو',
      6: 'يونيو',
      7: 'يوليو',
      8: 'أغسطس',
      9: 'سبتمبر',
      10: 'أكتوبر',
      11: 'نوفمبر',
      12: 'ديسمبر',
    };
    return months[month] ?? month.toString();
  }

  String _formatArabicDate(DateTime date) {
    return '${_arabicWeekday(date.weekday)}, ${date.day} ${_arabicMonth(date.month)}';
  }

  String _formatHHmm(String time) {
    final t = time.trim();
    if (t.isEmpty) return '—';
    final parts = t.split(':');
    if (parts.length != 2) return t;
    final hh = parts[0].trim().padLeft(2, '0');
    final mm = parts[1].trim().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<Map<String, String>> _fetchCourseNameArForSectionIds(
    Set<String> sectionIds,
  ) async {
    final cleaned = sectionIds.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
    if (cleaned.isEmpty) return <String, String>{};
    final sectionsRef = FirebaseFirestore.instance.collection('sections');
    final coursesRef = FirebaseFirestore.instance.collection('courses');
    final map = <String, String>{};
    for (final id in cleaned) {
      final snap = await sectionsRef.doc(id).get();
      if (!snap.exists) continue;
      final data = snap.data() ?? <String, dynamic>{};
      final code = (data['courseCode'] ?? '').toString().trim();
      String ar = (data['courseName_Ar'] ?? '').toString().trim();
      if (ar.isEmpty && code.isNotEmpty) {
        final courseSnap = await coursesRef.doc(code).get();
        if (courseSnap.exists) {
          final courseData = courseSnap.data() ?? <String, dynamic>{};
          ar = (courseData['courseName_Ar'] ?? '').toString().trim();
        }
      }
      if (ar.isNotEmpty) map[id] = ar;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final student = StudentAuthService.instance.currentStudent;
    if (student == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'سجّل دخولك لعرض الأعذار المرتبطة بجدولك.',
                      style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: FutureBuilder<List<String>>(
            future: _fetchStudentCourses(student.studentId),
            builder: (context, courseSnap) {
              final courses = courseSnap.data ?? <String>[];
              if (_selectedCourse == null && courses.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() => _selectedCourse = courses.first);
                });
              }
              final selectedCourse =
                  _selectedCourse ?? (courses.isNotEmpty ? courses.first : null);

              return StreamBuilder<List<ManualAttendanceRecord>>(
                stream: _attendance.watchStudentRecords(student.studentId),
                builder: (context, recordsSnap) {
                  final records = recordsSnap.data ?? <ManualAttendanceRecord>[];
                  final sectionIds = records.map((r) => r.sectionId).toSet();
                  return FutureBuilder<Map<String, String>>(
                    future: _fetchCourseNameArForSectionIds(sectionIds),
                    builder: (context, namesSnap) {
                      final sectionIdToNameAr = namesSnap.data ?? <String, String>{};
                      final baseItems = _mapRecordsToExcuseItems(records, sectionIdToNameAr);
                      return StreamBuilder<List<ExcuseRequest>>(
                        stream: _excuses.watchStudentRequests(student.studentId),
                        builder: (context, reqSnap) {
                          final merged = _mergeRequestsIntoItems(
                            baseItems: baseItems,
                            requests: reqSnap.data ?? <ExcuseRequest>[],
                          );
                          final List<_ExcuseItem> visibleItems = merged.where((item) {
                            final bool matchCourse =
                                selectedCourse == null || item.course == selectedCourse;
                            final String filterStatus =
                                _selectedFilter == 'رفع عذر' ? 'معلقة' : _selectedFilter;
                            final bool matchFilter =
                                _selectedFilter == 'الكل' || item.status == filterStatus;
                            return matchCourse && matchFilter;
                          }).toList();

                          return ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            children: <Widget>[
                              _buildHeader(context),
                              const SizedBox(height: 16),
                              _buildCourseTabs(courses),
                              const SizedBox(height: 12),
                              _buildStatusFilters(),
                              const SizedBox(height: 24),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  selectedCourse ?? '',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...visibleItems.map((item) => _ExcuseCard(item: item)),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          icon: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(3.14159), // عكس السهم ليشير لليسار
            child: const Icon(
              Icons.arrow_back_ios,
              color: _primaryColor,
              size: 16,
            ),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 6),
        const Text(
          'إدارة الأعذار',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        const Spacer(),
        NotificationBell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCourseTabs(List<String> courses) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _tabBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: courses.map((String course) {
          final bool isActive = course == (_selectedCourse ?? courses.first);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _GradientTabChip(
                label: course,
                isActive: isActive,
                onTap: () {
                  setState(() {
                    _selectedCourse = course;
                  });
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getFilterColor(String filter) {
    switch (filter) {
      case 'الكل':
        return const Color(0xFFE0E0E0);
      case 'رفع عذر':
        return const Color(0xFFBDBDBD); // أفتح
      case 'تم القبول':
        return const Color(0xFF81C784); // أفتح
      case 'تم الرفض':
        return const Color(0xFFE57373); // أفتح
      case 'قيد الانتظار':
        return const Color(0xFFFFE082); // أفتح
      case 'مغلق':
        return const Color(0xFF757575);
      default:
        return const Color(0xFFE0E0E0);
    }
  }

  Widget _buildStatusFilters() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _filters.map((String filter) {
            final bool isSelected = filter == _selectedFilter;
            final Color filterColor = _getFilterColor(filter);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedFilter = 'الكل';
                    } else {
                      _selectedFilter = filter;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? filterColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        filter,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected
                              ? (filter == 'الكل' ? Colors.black87 : Colors.white)
                              : Colors.black87,
                        ),
                      ),
                      if (!isSelected && filter != 'الكل') ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: filterColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _GradientTabChip extends StatelessWidget {
  const _GradientTabChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: isActive
              ? const LinearGradient(
                  colors: <Color>[
                    Color(0xFF27A2A9),
                    Color(0xFF006571),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: isActive ? null : Colors.white,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF444444),
          ),
        ),
      ),
    );
  }
}

class _ExcuseItem {
  const _ExcuseItem({
    required this.course,
    required this.timeRange,
    required this.dateText,
    required this.status,
    required this.rawDate,
    required this.sectionId,
    required this.rawStartTime,
    this.rejectionReason,
  });

  final String course;
  final String timeRange;
  final String dateText;
  final String status;
  final DateTime rawDate;
  final String sectionId;
  final String rawStartTime;
  final String? rejectionReason;

  _ExcuseItem copyWith({
    String? course,
    String? status,
    String? rejectionReason,
  }) {
    return _ExcuseItem(
      course: course ?? this.course,
      timeRange: timeRange,
      dateText: dateText,
      status: status ?? this.status,
      rawDate: rawDate,
      sectionId: sectionId,
      rawStartTime: rawStartTime,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

class _ExcuseCard extends StatelessWidget {
  const _ExcuseCard({
    required this.item,
  });

  final _ExcuseItem item;

  Color get _statusColor {
    switch (item.status) {
      case 'قيد الانتظار':
        return const Color(0xFFFFE082); // أفتح من #FFC107
      case 'تم القبول':
        return const Color(0xFF81C784); // أفتح من #2E7D32
      case 'تم الرفض':
        return const Color(0xFFE57373); // أفتح من #C62828
      case 'مغلق':
        return const Color(0xFF757575);
      case 'معلقة':
      default:
        return const Color(0xFFBDBDBD); // أفتح من #9E9E9E
    }
  }

  bool get _shouldShowArrow {
    return item.status == 'معلقة' || item.status == 'تم الرفض';
  }

  void _showClosedInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade400,
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  const Text(
                    'ملاحظة: الفترة الزمنية لتقديم العذر لهذه المحاضرة مغلقة لانتهائها، ولا يمكن تعديل أو إضافة أعذار جديدة.',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isClosed = item.status == 'مغلق';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'أولى-ثانية',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.dateText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
              const Spacer(),
              IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      constraints: const BoxConstraints(minWidth: 80),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.status == 'معلقة' ? 'رفع عذر' : item.status,
                        style: TextStyle(
                          fontSize: item.status == 'معلقة' ? 13 : 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_shouldShowArrow) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          GestureDetector(
                            onTap: () {
                              if (item.status == 'تم الرفض') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RejectionDetailScreen(
                                      course: item.course,
                                      dateText: item.dateText,
                                      timeRange: item.timeRange,
                                      reason: item.rejectionReason?.trim().isNotEmpty == true
                                          ? item.rejectionReason!.trim()
                                          : 'السبب: العذر غير مقبول - يُشترط تقديم عذر صحي رسمي.',
                                    ),
                                  ),
                                );
                              } else if (item.status == 'معلقة') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SubmitExcuseScreen(
                                      course: item.course,
                                      dateText: item.dateText,
                                      timeRange: item.timeRange,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              width: 28,
                              height: 24,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: const Color(0xFFE0E0E0),
                              ),
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.rotationY(3.14159),
                                child: const Icon(
                                  Icons.arrow_back_ios,
                                  size: 14,
                                  color: Color(0xFF616161),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (isClosed) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: <Widget>[
                          GestureDetector(
                            onTap: () => _showClosedInfoDialog(context),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.shade400,
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Color(0xFF616161),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

