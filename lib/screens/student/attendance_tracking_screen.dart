import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/attendance/manual_attendance_record.dart';
import '../../services/attendance/manual_attendance_service.dart';
import '../../services/student_auth_service.dart';
import 'components/custom_nav_bar_icons.dart';
import 'components/notification_bell.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class AttendanceTrackingScreen extends StatefulWidget {
  const AttendanceTrackingScreen({super.key});

  @override
  State<AttendanceTrackingScreen> createState() =>
      _AttendanceTrackingScreenState();
}

class _AttendanceTrackingScreenState extends State<AttendanceTrackingScreen> {
  static const Color _primaryColor = Color(0xFF006571);
  final ManualAttendanceService _manualAttendanceService =
      ManualAttendanceService.instance;
  StreamSubscription<List<ManualAttendanceRecord>>? _recordsSubscription;

  List<_AttendanceRecord> _records = <_AttendanceRecord>[];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _subscribeAttendance();
  }

  @override
  void dispose() {
    _recordsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _subscribeAttendance() async {
    final student = StudentAuthService.instance.currentStudent;
    if (student == null) {
      setState(() {
        _isLoading = false;
        _loadError = 'سجّل دخولك كطالب لعرض تتبع الحضور.';
      });
      return;
    }

    _recordsSubscription = _manualAttendanceService
        .watchStudentRecords(student.studentId)
        .listen(
          (records) {
            final mapped = records.map(_toAttendanceRecord).toList();
            mapped.sort((a, b) => b.lectureDate.compareTo(a.lectureDate));
            if (!mounted) return;
            setState(() {
              _records = mapped;
              _isLoading = false;
              _loadError = null;
            });
          },
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _loadError = error.toString();
            });
          },
        );
  }

  _AttendanceRecord _toAttendanceRecord(ManualAttendanceRecord record) {
    final status = switch (record.status) {
      ManualAttendanceStatus.present => 'present',
      ManualAttendanceStatus.late => 'late',
      ManualAttendanceStatus.excused => 'excused',
      ManualAttendanceStatus.absent => 'unexcused',
    };
    final sectionText = record.sectionLabel.trim().isEmpty
        ? '-'
        : record.sectionLabel;
    return _AttendanceRecord(
      courseKey: '${record.courseName} • شعبة $sectionText',
      courseName: record.courseName,
      sectionLabel: sectionText,
      lectureDate: DateTime(
        record.lectureDate.year,
        record.lectureDate.month,
        record.lectureDate.day,
      ),
      timeRange: '${record.lectureStartTime}-${record.lectureEndTime}',
      dayName: _arabicDayName(record.lectureDate.weekday),
      status: status,
    );
  }

  String _arabicDayName(int weekday) {
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

  int get _total => _records.length;
  int get _totalAttendance =>
      _records.where((r) => r.status == 'present').length;
  int get _excusedAbsence =>
      _records.where((r) => r.status == 'excused').length;
  int get _unexcusedAbsence =>
      _records.where((r) => r.status == 'unexcused').length;
  int get _tardiness => _records.where((r) => r.status == 'late').length;

  double get _attendancePercentage =>
      _total == 0 ? 0 : (_totalAttendance / _total) * 100;
  double get _excusedPercentage =>
      _total == 0 ? 0 : (_excusedAbsence / _total) * 100;
  double get _unexcusedPercentage =>
      _total == 0 ? 0 : (_unexcusedAbsence / _total) * 100;
  double get _tardinessPercentage =>
      _total == 0 ? 0 : (_tardiness / _total) * 100;

  List<_SessionCardData> get _sessionCards {
    final grouped = <String, List<_AttendanceRecord>>{};
    for (final record in _records) {
      grouped.putIfAbsent(record.courseKey, () => <_AttendanceRecord>[]);
      grouped[record.courseKey]!.add(record);
    }

    final cards = grouped.entries.map((entry) {
      final records = entry.value
        ..sort((a, b) => b.lectureDate.compareTo(a.lectureDate));
      final presentLike = records
          .where((r) => r.status == 'present' || r.status == 'late')
          .length;
      final absentLike = records
          .where((r) => r.status == 'unexcused' || r.status == 'excused')
          .length;
      final latestDate = records.first.lectureDate;
      return _SessionCardData(
        key: entry.key,
        title: records.first.courseName,
        subtitle: 'شعبة ${records.first.sectionLabel}',
        latestDate: latestDate,
        presentCount: presentLike,
        absentCount: absentLike,
        totalCount: records.length,
        records: records,
      );
    }).toList();

    cards.sort((a, b) => b.latestDate.compareTo(a.latestDate));
    return cards;
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: NavBarSettingsArabic(
          selectedIndex: 1,
          onItemTapped: (index) {
            if (index == 0) {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            } else if (index == 2) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            } else if (index == 1) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: _isLoading
                ? Column(
                    children: <Widget>[
                      _buildHeader(context),
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: _primaryColor,
                          ),
                        ),
                      ),
                    ],
                  )
                : _loadError != null
                ? Column(
                    children: <Widget>[
                      _buildHeader(context),
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _loadError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _subscribeAttendance,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : _records.isEmpty
                ? Column(
                    children: <Widget>[
                      _buildHeader(context),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'لا توجد سجلات تحضير حتى الآن',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: <Widget>[
                      _buildHeader(context),
                      const SizedBox(height: 16),
                      _buildAttendanceSummary(),
                      const SizedBox(height: 16),
                      _buildSessionsHeader(),
                      const SizedBox(height: 8),
                      Expanded(child: _buildSessionsList()),
                    ],
                  ),
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
            transform: Matrix4.rotationY(3.14159),
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
        const Expanded(
          child: Text(
            'تتبع الحضور',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _primaryColor,
            ),
          ),
        ),
        NotificationBell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAttendanceSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildLegendItem(
                  color: const Color(0xFF006571),
                  percentage: _attendancePercentage,
                  count: _totalAttendance,
                  label: 'الحضور',
                ),
                const SizedBox(height: 12),
                _buildLegendItem(
                  color: const Color(0xFF2196F3),
                  percentage: _excusedPercentage,
                  count: _excusedAbsence,
                  label: 'الغياب بعذر',
                ),
                const SizedBox(height: 12),
                _buildLegendItem(
                  color: const Color(0xFFFF9800),
                  percentage: _unexcusedPercentage,
                  count: _unexcusedAbsence,
                  label: 'الغياب بدون عذر',
                ),
                const SizedBox(height: 12),
                _buildLegendItem(
                  color: const Color(0xFFFFC107),
                  percentage: _tardinessPercentage,
                  count: _tardiness,
                  label: 'التأخير',
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CustomPaint(
                  size: const Size(120, 120),
                  painter: _DonutChartPainter(
                    attendancePercentage: _attendancePercentage,
                    excusedPercentage: _excusedPercentage,
                    unexcusedPercentage: _unexcusedPercentage,
                    tardinessPercentage: _tardinessPercentage,
                  ),
                ),
                Text(
                  '${_attendancePercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required double percentage,
    required int count,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '${percentage.toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionsHeader() {
    return const Align(
      alignment: Alignment.centerRight,
      child: Text(
        'السشنز',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  Widget _buildSessionsList() {
    final cards = _sessionCards;
    if (cards.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد سشنز',
          style: TextStyle(fontSize: 16, color: Color(0xFF9E9E9E)),
        ),
      );
    }

    return ListView.separated(
      itemCount: cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final card = cards[index];
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _AttendanceSessionDaysScreen(
                  sessionTitle: card.title,
                  sessionSubtitle: card.subtitle,
                  records: card.records,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE3ECEE)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5E7176),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'آخر حضور: ${_formatDate(card.latestDate)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6D7F84),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'حضور ${card.presentCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2EAF5E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'غياب ${card.absentCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE65151),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'الإجمالي ${card.totalCount}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF60757A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_left_rounded,
                  color: Color(0xFF60757A),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AttendanceSessionDaysScreen extends StatelessWidget {
  const _AttendanceSessionDaysScreen({
    required this.sessionTitle,
    required this.sessionSubtitle,
    required this.records,
  });

  final String sessionTitle;
  final String sessionSubtitle;
  final List<_AttendanceRecord> records;

  List<_AttendanceRecord> get _presentDays {
    final list = records
        .where((r) => r.status == 'present' || r.status == 'late')
        .toList();
    list.sort((a, b) => b.lectureDate.compareTo(a.lectureDate));
    return list;
  }

  List<_AttendanceRecord> get _absentDays {
    final list = records
        .where((r) => r.status == 'unexcused' || r.status == 'excused')
        .toList();
    list.sort((a, b) => b.lectureDate.compareTo(a.lectureDate));
    return list;
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF006571),
          title: const Text(
            'تفاصيل الحضور',
            style: TextStyle(
              color: Color(0xFF006571),
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sessionTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sessionSubtitle,
                style: const TextStyle(fontSize: 13, color: Color(0xFF61767B)),
              ),
              const SizedBox(height: 12),
              _sectionTitle(
                'الأيام اللي حضرت فيها',
                _presentDays.length,
                const Color(0xFF2EAF5E),
              ),
              const SizedBox(height: 8),
              _recordsBlock(
                _presentDays,
                isPresent: true,
                formatDate: _formatDate,
              ),
              const SizedBox(height: 14),
              _sectionTitle(
                'الأيام اللي غبت فيها',
                _absentDays.length,
                const Color(0xFFE65151),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _recordsBlock(
                  _absentDays,
                  isPresent: false,
                  formatDate: _formatDate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, int count, Color color) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _recordsBlock(
    List<_AttendanceRecord> list, {
    required bool isPresent,
    required String Function(DateTime) formatDate,
  }) {
    if (list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3ECEE)),
        ),
        child: Text(
          isPresent ? 'لا توجد أيام حضور' : 'لا توجد أيام غياب',
          style: const TextStyle(fontSize: 13, color: Color(0xFF7B8F93)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = list[index];
        final badgeColor = isPresent
            ? const Color(0xFF2EAF5E)
            : const Color(0xFFE65151);
        final statusLabel = switch (item.status) {
          'late' => 'متأخر',
          'excused' => 'غياب بعذر',
          'unexcused' => 'غائب',
          _ => 'حاضر',
        };
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3ECEE)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.dayName} • ${formatDate(item.lectureDate)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF22363B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.timeRange,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF60757A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.attendancePercentage,
    required this.excusedPercentage,
    required this.unexcusedPercentage,
    required this.tardinessPercentage,
  });

  final double attendancePercentage;
  final double excusedPercentage;
  final double unexcusedPercentage;
  final double tardinessPercentage;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 20.0;

    double startAngle = -math.pi / 2;

    final attendanceSweep = (attendancePercentage / 100) * 2 * math.pi;
    final attendancePaint = Paint()
      ..color = const Color(0xFF006571)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      attendanceSweep,
      false,
      attendancePaint,
    );
    startAngle += attendanceSweep;

    final excusedSweep = (excusedPercentage / 100) * 2 * math.pi;
    final excusedPaint = Paint()
      ..color = const Color(0xFF2196F3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      excusedSweep,
      false,
      excusedPaint,
    );
    startAngle += excusedSweep;

    final unexcusedSweep = (unexcusedPercentage / 100) * 2 * math.pi;
    final unexcusedPaint = Paint()
      ..color = const Color(0xFFFF9800)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      unexcusedSweep,
      false,
      unexcusedPaint,
    );
    startAngle += unexcusedSweep;

    final tardinessSweep = (tardinessPercentage / 100) * 2 * math.pi;
    final tardinessPaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      tardinessSweep,
      false,
      tardinessPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return attendancePercentage != oldDelegate.attendancePercentage ||
        excusedPercentage != oldDelegate.excusedPercentage ||
        unexcusedPercentage != oldDelegate.unexcusedPercentage ||
        tardinessPercentage != oldDelegate.tardinessPercentage;
  }
}

class _AttendanceRecord {
  _AttendanceRecord({
    required this.courseKey,
    required this.courseName,
    required this.sectionLabel,
    required this.lectureDate,
    required this.timeRange,
    required this.dayName,
    required this.status,
  });

  final String courseKey;
  final String courseName;
  final String sectionLabel;
  final DateTime lectureDate;
  final String timeRange;
  final String dayName;
  final String status;
}

class _SessionCardData {
  _SessionCardData({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.latestDate,
    required this.presentCount,
    required this.absentCount,
    required this.totalCount,
    required this.records,
  });

  final String key;
  final String title;
  final String subtitle;
  final DateTime latestDate;
  final int presentCount;
  final int absentCount;
  final int totalCount;
  final List<_AttendanceRecord> records;
}
