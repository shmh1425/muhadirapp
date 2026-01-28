import 'package:flutter/material.dart';

import 'components/notification_bell.dart';
import 'rejection_detail_screen.dart';
import 'submit_excuse_screen.dart';
import 'notifications_screen.dart';

class ExcuseScreen extends StatefulWidget {
  const ExcuseScreen({super.key});

  @override
  State<ExcuseScreen> createState() => _ExcuseScreenState();
}

class _ExcuseScreenState extends State<ExcuseScreen> {
  static const Color _primaryColor = Color(0xFF006571);
  static const Color _tabBackground = Color(0xFFF5F5F5);

  final List<String> _courses = <String>[
    'جودة البرمجيات',
    'بحوث عمليات',
    'هندسة البيانات',
  ];

  final List<String> _filters = <String>[
    'الكل',
    'قيد الانتظار',
    'تم القبول',
    'تم الرفض',
    'رفع عذر',
    'مغلق',
  ];

  String _selectedCourse = 'جودة البرمجيات';
  String _selectedFilter = 'الكل';

  late final List<_ExcuseItem> _items;

  @override
  void initState() {
    super.initState();
    _items = <_ExcuseItem>[
      const _ExcuseItem(
        course: 'جودة البرمجيات',
        timeRange: '08:50-08:00',
        dateText: 'الأربعاء, 14 مايو',
        status: 'معلقة',
      ),
      const _ExcuseItem(
        course: 'جودة البرمجيات',
        timeRange: '08:50-08:00',
        dateText: 'الأحد, 11 مايو',
        status: 'قيد الانتظار',
      ),
      const _ExcuseItem(
        course: 'جودة البرمجيات',
        timeRange: '08:50-08:00',
        dateText: 'الأربعاء, 7 مايو',
        status: 'تم القبول',
      ),
      const _ExcuseItem(
        course: 'جودة البرمجيات',
        timeRange: '08:50-08:00',
        dateText: 'الأحد, 4 مايو',
        status: 'تم الرفض',
      ),
      const _ExcuseItem(
        course: 'جودة البرمجيات',
        timeRange: '08:50-08:00',
        dateText: 'الأحد, 4 مايو',
        status: 'مغلق',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final List<_ExcuseItem> visibleItems = _items.where((item) {
      final bool matchCourse = item.course == _selectedCourse;
      final String filterStatus = _selectedFilter == 'رفع عذر' ? 'معلقة' : _selectedFilter;
      final bool matchFilter =
          _selectedFilter == 'الكل' || item.status == filterStatus;
      return matchCourse && matchFilter;
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: <Widget>[
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildCourseTabs(),
              const SizedBox(height: 12),
              _buildStatusFilters(),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _selectedCourse,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...visibleItems
                  .map((item) => _ExcuseCard(
                        item: item,
                      ))
                  .toList(),
            ],
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
          onPressed: () => Navigator.pop(context),
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

  Widget _buildCourseTabs() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _tabBackground,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: _courses.map((String course) {
          final bool isActive = course == _selectedCourse;
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
            color: Colors.black.withOpacity(0.04),
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
  });

  final String course;
  final String timeRange;
  final String dateText;
  final String status;
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
      barrierColor: Colors.black.withOpacity(0.5),
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Row(
                    children: <Widget>[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            item.timeRange,
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
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                                      reason: 'السبب: العذر غير مقبول - يُشترط تقديم عذر صحي رسمي.',
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

