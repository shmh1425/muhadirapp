import 'package:flutter/material.dart';

import '../../models/lecturer/lecture_item.dart';
import 'lecturer_language.dart';
import 'lecturer_navigation.dart';
import 'widgets/profile_back_button.dart';

/// Figure 10 – Live Attendance – Current Day & Lecture.
///
/// تعرض قائمة الطلاب المسجلين في المحاضرة الحالية، مع حالة التحضير حسب تسجيل
/// الدخول (QR أو NFC). الحالة تُحدَّث تلقائياً حسب وقت التحضير الفعلي المعروض
/// بجانب اسم كل طالب. إن سجّل الطالب دخوله دون اتصال، تُحدَّث الحالة بعد عودة
/// الاتصال ومزامنة البيانات؛ يظهر أيقونة مزامنة بجانب حقل الحالة للإشارة إلى
/// تحديث قيد الانتظار.
///
/// يُعرض فقط سجلات التحضير الفعلية لليوم الحالي والمحاضرة الحالية. التعديل
/// اللاحق على سجلات سابقة يتم من البروفايل عبر [Attendance Reports].
///
/// لون كل حالة (حاضر، غائب، غياب بعذر، تأخر) يعكس الحالة الفعلية، والمحاضر
/// يمكنه تعديلها يدوياً حسب الملاحظة. أزرار "معاينة الأعذار" و"حفظ" مع شريط
/// تنقل سفلي ثابت للوصول السريع لأقسام التطبيق.
///
/// تُفتح من صفحة "اليوم" عند الضغط على كارد المحاضرة.
class LecturerAttendanceScreen extends StatefulWidget {
  const LecturerAttendanceScreen({
    super.key,
    required this.lecture,
    this.viewOnly = false,
    this.selectedDate,
  });

  final LectureItem lecture;
  /// عند true (من صفحة الكل — يوم أزرق): عرض تقارير الحضور فقط دون تعديل.
  final bool viewOnly;
  /// تاريخ اليوم المعروضة تقاريره (للوضع View Only من التقويم).
  final DateTime? selectedDate;

  @override
  State<LecturerAttendanceScreen> createState() =>
      _LecturerAttendanceScreenState();
}

class _LecturerAttendanceScreenState extends State<LecturerAttendanceScreen> {
  static const Color _primary = Color(0xFF006571);

  // عرض الأعمدة ثابت لتفادي اهتزاز المحاذاة بين الهيدر والصفوف
  static const double _colIdWidth = 88.0;
  static const double _colTimeWidth = 54.0;
  static const double _colStatusWidth = 78.0;
  static const double _colPctWidth = 42.0;
  static const double _cellHPad = 6.0;

  late List<_StudentRow> _students;
  AttendanceStatusFilter _statusFilter = AttendanceStatusFilter.all;
  Map<String, AttendanceStatus> _draftStatuses = {};
  bool _hasPendingChanges = false;
  bool _isSaving = false;

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  LectureItem get _lecture => widget.lecture;
  bool get _viewOnly => widget.viewOnly;
  DateTime? get _selectedDate => widget.selectedDate;

  /// صيغة موحدة لعرض النسبة: "N٪" بدون مسافات أو رموز زيادة.
  String _formatPercentage(int value) => '$value٪';

  /// وقت المحاضرة بصيغة واضحة (24 ساعة، بدون AM/PM)
  String get _lectureTimeRange {
    final slots = _lecture.timeSlots;
    if (slots.isEmpty) return '${_lecture.startTime} - ${_lecture.endTime}';
    if (slots.length == 1) return slots.first;
    return '${slots.first} / ${slots.last}';
  }

  /// طلاب الجلسة الحالية فقط — مبنون من المحاضرة (ديناميكي).
  List<_StudentRow> get _allStudents => _students;

  /// الطلاب بعد تطبيق الفلتر فقط. الفلترة فورية في الذاكرة ولا تعيد تحميل الصفحة.
  List<_StudentRow> get _filteredStudents {
    if (_statusFilter == AttendanceStatusFilter.all) return _allStudents;
    return _allStudents.where((s) {
      final status = _effectiveStatus(s);
      return _statusToFilter(status) == _statusFilter;
    }).toList();
  }

  /// الحالة الفعلية مع توافق Hot Reload: إن كانت الحالة قديمة (مثل suspended المحذوف) نعيد حاضر.
  AttendanceStatus _effectiveStatus(_StudentRow student) {
    final s = _draftStatuses[student.academicNumber] ?? student.status;
    if (AttendanceStatus.values.contains(s)) return s;
    return AttendanceStatus.present;
  }

  void _setDraftStatus(String academicNumber, AttendanceStatus status) {
    setState(() {
      _draftStatuses[academicNumber] = status;
      _hasPendingChanges = true;
    });
  }

  /// هل يوجد طلاب حالتهم Pending Sync (Offline)؟
  bool get _hasPendingSyncStudents =>
      _students.any((s) => s.isOffline);

  /// حفظ التعديلات للجلسة الحالية فقط (مربوط بـ CRN + تاريخ اليوم).
  /// التعديل على أيام سابقة من [Attendance Reports].
  Future<void> _saveChanges() async {
    if (!_hasPendingChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('لا توجد تغييرات للحفظ.', 'No changes to save.')),
        ),
      );
      return;
    }
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      // محاكاة طلب حفظ (لاحقاً: API بمفتاح lectureId/CRN + تاريخ اليوم فقط)
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;

      setState(() {
        for (final s in _students) {
          final updated = _draftStatuses[s.academicNumber];
          if (updated != null) s.status = updated;
        }
        _draftStatuses = {};
        _hasPendingChanges = false; // تصفير حالة التغييرات فعلياً حتى يظهر الزر غير نشط بعد الحفظ
      });

      final hasPendingSync = _hasPendingSyncStudents;
      final successMessage = hasPendingSync
          ? _tr(
              'تم الحفظ بنجاح. يوجد سجلات بانتظار المزامنة.',
              'Saved successfully. Some records are pending sync.',
            )
          : _tr('تم الحفظ بنجاح.', 'Saved successfully.');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF2B9E56),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr('فشل الحفظ. حاول مرة أخرى.', 'Save failed. Please try again.')),
          backgroundColor: const Color(0xFFD32F2F),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _openPreviewExcuses() async {
    final saved = await LecturerNavigation.goToExcuseManagement(
        context, widget.lecture);
    if (saved == true && mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _students = _buildStudentsForLecture(_lecture);
  }

  /// بناء قائمة الطلاب المسجلين في هذه المحاضرة فقط (ديناميكي حسب المحاضرة). حد أدنى 30 طالب، أسماء متنوعة (طويلة/قصيرة) لاختبار overflow.
  List<_StudentRow> _buildStudentsForLecture(LectureItem lecture) {
    const names = [
      'غلا القرني',
      'أحمد علي',
      'محمد سامي',
      'عبدالله خالد',
      'ريم فهد',
      'نورة سالم',
      'سارة عبدالعزيز',
      'لينا عادل',
      'فاطمة حسن',
      'خالد العمري',
      'مريم الشهري',
      'عمر الزهراني',
      'هند القحطاني',
      'يوسف المالكي',
      'داليا الحربي',
      'رائد العتيبي',
      'لمى الغامدي',
      'سعد الدوسري',
      'جواهر الشمري',
      'بدر العنزي',
      'منى البقمي',
      'نايف الراجحي',
      'هناء السعيد',
      'وليد النمر',
      'رنا الحارثي',
      'فيصل الحازمي',
      'أسماء الزهراني',
      'تركي المطيري',
      'شيماء العلي',
      'مازن الشهري',
      'لطيفة الغامدي',
      'عبدالرحمن القحطاني',
      'عائشة محمد العتيبي',
      'ناصر',
      'فهد عبدالعزيز الحربي',
      'هيا',
    ];
    const statuses = AttendanceStatus.values;
    const pctPool = [0, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100];
    final list = <_StudentRow>[];
    for (int i = 0; i < names.length; i++) {
      final status = statuses[i % statuses.length];
      final hasTime = status != AttendanceStatus.absent && status != AttendanceStatus.excused;
      list.add(_StudentRow(
        id: '${lecture.crn}-$i',
        name: names[i],
        academicNumber: '444${(100000 + i).toString().padLeft(6, '0')}',
        attendanceTime: hasTime ? lecture.startTime : '--',
        percentage: pctPool[i % pctPool.length],
        status: status,
        isOffline: (i == 1 || i == 8 || i == 14) && status == AttendanceStatus.present,
        isSuspended: i == 2 || i == 7,
      ));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, _, __) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FBFB),
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _buildFilterBar(),
                  ),
                  _buildSyncLegend(),
                  const SizedBox(height: 14),
                  Expanded(child: _buildTableSection()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _buildBottomButtons(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final activityLabel = _lecture.activity == 'عملي'
        ? _tr('عملي', 'Lab')
        : _tr('نظري', 'Theory');
    final sectionLabel = '${_tr('الشعبة', 'Section')} ${_lecture.section}';
    // سطران واضحان: الأول CRN + النوع + الشعبة، الثاني الوقت فقط — بفواصل واضحة
    final line1 = '${_lecture.crn}  ·  $activityLabel  ·  $sectionLabel';
    final line2 = _lectureTimeRange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE8E8E8)),
        ),
      ),
      child: Row(
        children: [
          // زر الرجوع: نفس ProfileBackButton (يستخدم BackButtonIcon القياسي ويحترم RTL/LTR).
          ProfileBackButton(onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _lecture.courseName,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF222222),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_viewOnly)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A90E2).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF4A90E2)),
                        ),
                        child: Text(
                          _tr('عرض فقط', 'View only'),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  line1,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedDate != null
                      ? '${_formatDisplayDate(_selectedDate!)}  ·  $line2'
                      : line2,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDisplayDate(DateTime d) {
    final y = d.year, m = d.month, day = d.day;
    if (LecturerLanguageController.isArabic) return '$day/$m/$y';
    return '$day/$m/$y';
  }

  /// سطر توضيحي يظهر عند وجود طلاب مسجّل دخولهم دون اتصال — يوضح معنى رمز المزامنة.
  Widget _buildSyncLegend() {
    if (!_hasPendingSyncStudents) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Icon(Icons.sync_rounded, size: 18, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _tr(
                'الرمز بجانب الحالة = تم التسجيل دون اتصال، سيُحدَّث تلقائياً عند عودة الإنترنت.',
                'Icon next to status = Check-in was offline; will sync automatically when online.',
              ),
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      AttendanceStatusFilter.all,
      AttendanceStatusFilter.present,
      AttendanceStatusFilter.excused,
      AttendanceStatusFilter.absent,
      AttendanceStatusFilter.late,
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE6E8)),
      ),
      child: Row(
        children: filters.map((filter) {
          final active = _statusFilter == filter;
          final style = _filterStyle(filter);
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _statusFilter = filter),
              child: Container(
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? style.activeBg : const Color(0xFFF2F5F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  style.label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : const Color(0xFF516166),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// عنصر سكرول واحد: CustomScrollView مع هيدر الجدول + قائمة الطلاب كـ Slivers (لا فراغ بين الهيدر وأول صف).
  Widget _buildTableSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE6E8)),
        ),
        child: _filteredStudents.isEmpty
            ? Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  _buildTableHeader(),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _tr('لا يوجد طلاب في هذا الفلتر.', 'No students in this filter.'),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: Color(0xFF666666),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildTableHeader()),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final student = _filteredStudents[index];
                        final statusStyle = _statusStyle(_effectiveStatus(student));
                        final row = _buildTableRow(student, statusStyle, index.isEven);
                        if (index == 0) return row;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Divider(height: 1, color: Color(0xFFEAEFF0)),
                            row,
                          ],
                        );
                      },
                      childCount: _filteredStudents.length,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _cellHPad, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F6F7),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(13),
          topRight: Radius.circular(13),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(_tr('اسم الطالب/ة', 'Student Name'), style: _tableHeaderStyle, textAlign: TextAlign.start),
            ),
          ),
          SizedBox(width: _colIdWidth, child: Center(child: Text(_tr('الرقم الجامعي', 'ID'), style: _tableHeaderStyle, textAlign: TextAlign.center))),
          SizedBox(width: _colTimeWidth, child: Center(child: Text(_tr('وقت التحضير', 'Time'), style: _tableHeaderStyle, textAlign: TextAlign.center))),
          SizedBox(width: _colStatusWidth, child: Center(child: Text(_tr('الحالة', 'Status'), style: _tableHeaderStyle, textAlign: TextAlign.center))),
          SizedBox(width: _colPctWidth, child: Center(child: Text(_tr('النسبة', '%'), style: _tableHeaderStyle, textAlign: TextAlign.center))),
        ],
      ),
    );
  }

  Widget _buildTableRow(_StudentRow student, _StatusStyle statusStyle, bool isEven) {
    final timeText = student.attendanceTime.trim().isEmpty ? '--' : student.attendanceTime.trim();
    final suspended = student.isSuspended ?? false;
    final baseBg = suspended ? const Color(0xFFFFEBEE) : (isEven ? Colors.white : const Color(0xFFFCFEFE));
    return Container(
      color: baseBg,
      padding: EdgeInsets.symmetric(horizontal: _cellHPad, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                student.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF213236),
                ),
                textAlign: TextAlign.start,
              ),
            ),
          ),
          SizedBox(
            width: _colIdWidth,
            child: Center(
              child: Text(
                student.academicNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: Color(0xFF55666B),
                ),
              ),
            ),
          ),
          SizedBox(
            width: _colTimeWidth,
            child: Center(
              child: Text(
                timeText,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: Color(0xFF465A5F),
                ),
              ),
            ),
          ),
          SizedBox(
            width: _colStatusWidth,
            child: Center(child: _buildStatusChipCell(student, statusStyle)),
          ),
          SizedBox(
            width: _colPctWidth,
            child: Center(
              child: Text(
                _formatPercentage(student.percentage),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF41575D),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// خلية الحالة: عرض ثابت. الطالب المحروم (صفه أحمر) غير قابل لتعديل الحالة؛ رمز Sync لـ Pending sync؛ الضغط = منتقي الحالة.
  Widget _buildStatusChipCell(_StudentRow student, _StatusStyle? statusStyle) {
    final effectiveStyle = statusStyle ?? _statusStyle(AttendanceStatus.present);
    final showSync = student.isOffline;
    final chipLabel = effectiveStyle.chipLabel;
    final isSuspended = student.isSuspended ?? false;
    final VoidCallback onChipTap = _viewOnly
        ? () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_tr('عرض فقط — لا يمكن تعديل الحضور.', 'View only — attendance cannot be edited.')),
              ),
            )
        : (isSuspended
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_tr('لا يمكن تعديل حالة المحروم.', 'Suspended status cannot be changed.')),
                  ),
                )
            : () => _showStatusPicker(student));
    return _statusChip(
      chipLabel,
      effectiveStyle.bg,
      effectiveStyle.fg,
      showSync: showSync,
      onSyncTap: showSync ? _showPendingSyncSnack : null,
      onChipTap: onChipTap,
    );
  }

  void _showPendingSyncSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_tr('تم تسجيل الحضور دون اتصال. سيُحدَّث السجل تلقائياً عند عودة الإنترنت.', 'Attendance was recorded offline. The record will update automatically when online.')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Chip بحجم مناسب وتباعد عن الأعمدة المجاورة (داخل عمود بعرض ثابت).
  Widget _statusChip(String label, Color bg, Color fg, {bool showSync = false, VoidCallback? onSyncTap, required VoidCallback onChipTap}) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showSync && onSyncTap != null)
            Tooltip(
              message: _tr('تسجيل دخول دون اتصال — سيتم التحديث عند المزامنة', 'Checked in offline — will update when synced'),
              child: GestureDetector(
                onTap: onSyncTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 2),
                  child: Icon(Icons.sync_rounded, size: 16, color: Colors.orange.shade700),
                ),
              ),
            ),
          if (showSync && onSyncTap != null) const SizedBox(width: 4),
          Flexible(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onChipTap,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// حفظ = Primary، معاينة الأعذار = Secondary. في وضع العرض فقط لا يظهر زر الحفظ.
  Widget _buildBottomButtons() {
    const height = 48.0;
    const radius = 14.0;
    const gap = 12.0;
    final hasChanges = _hasPendingChanges;
    final canTap = !_isSaving;

    if (_viewOnly) {
      return SizedBox(
        height: height,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openPreviewExcuses,
            borderRadius: BorderRadius.circular(radius),
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: const Color(0xFFD4E5E8)),
              ),
              child: Text(
                _tr('معاينة الأعذار', 'Preview Excuses'),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF222222),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canTap ? _saveChanges : null,
              borderRadius: BorderRadius.circular(radius),
              child: Container(
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: (hasChanges && canTap)
                      ? const LinearGradient(
                          colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  color: (hasChanges && canTap) ? null : const Color(0xFFE3E8EA),
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: (hasChanges && canTap)
                      ? [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF006571)),
                        ),
                      )
                    : Text(
                        _tr('حفظ', 'Save'),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: (hasChanges && canTap) ? Colors.white : const Color(0xFF92A2A7),
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: gap),
        Expanded(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openPreviewExcuses,
              borderRadius: BorderRadius.circular(radius),
              child: Container(
                height: height,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: const Color(0xFFD4E5E8)),
                ),
                child: Text(
                  _tr('معاينة الأعذار', 'Preview Excuses'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showStatusPicker(_StudentRow student) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr('تعديل حالة الطالب', 'Edit student status'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  student.name,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF213236),
                  ),
                ),
                const SizedBox(height: 12),
                ...AttendanceStatus.values.map((status) {
                  final style = _statusStyle(status);
                  final selected = _effectiveStatus(student) == status;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _setDraftStatus(student.academicNumber, status);
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: style.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? style.fg
                                : style.fg.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          style.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                            color: style.fg,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  AttendanceStatusFilter _statusToFilter(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return AttendanceStatusFilter.present;
      case AttendanceStatus.absent:
        return AttendanceStatusFilter.absent;
      case AttendanceStatus.excused:
        return AttendanceStatusFilter.excused;
      case AttendanceStatus.late:
        return AttendanceStatusFilter.late;
    }
  }

  _StatusStyle _statusStyle(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return _StatusStyle(
          label: _tr('حاضر', 'Present'),
          chipLabel: _tr('حاضر', 'Present'),
          bg: const Color(0xFFDFF4E5),
          fg: const Color(0xFF2B9E56),
          activeBg: const Color(0xFF2B9E56),
        );
      case AttendanceStatus.absent:
        return _StatusStyle(
          label: _tr('غائب', 'Absent'),
          chipLabel: _tr('غائب', 'Absent'),
          bg: const Color(0xFFFDE1E1),
          fg: const Color(0xFFD14A4A),
          activeBg: const Color(0xFFD14A4A),
        );
      case AttendanceStatus.excused:
        return _StatusStyle(
          label: _tr('غياب بعذر', 'Excused'),
          chipLabel: _tr('بعذر', 'Excused'),
          bg: const Color(0xFFFFF3D6),
          fg: const Color(0xFFC78A1E),
          activeBg: const Color(0xFFC78A1E),
        );
      case AttendanceStatus.late:
        return _StatusStyle(
          label: _tr('تأخر', 'Late'),
          chipLabel: _tr('تأخر', 'Late'),
          bg: const Color(0xFFE3EEFF),
          fg: const Color(0xFF3E73C9),
          activeBg: const Color(0xFF3E73C9),
        );
    }
  }

  _StatusStyle _filterStyle(AttendanceStatusFilter filter) {
    switch (filter) {
      case AttendanceStatusFilter.all:
        return _StatusStyle(
          label: _tr('الكل', 'All'),
          chipLabel: _tr('الكل', 'All'),
          bg: const Color(0xFFECEFF0),
          fg: const Color(0xFF6F7D82),
          activeBg: const Color(0xFF6F7D82),
        );
      case AttendanceStatusFilter.present:
        return _statusStyle(AttendanceStatus.present);
      case AttendanceStatusFilter.absent:
        return _statusStyle(AttendanceStatus.absent);
      case AttendanceStatusFilter.excused:
        return _statusStyle(AttendanceStatus.excused);
      case AttendanceStatusFilter.late:
        return _statusStyle(AttendanceStatus.late);
    }
  }
}

const TextStyle _tableHeaderStyle = TextStyle(
  fontFamily: 'Cairo',
  fontSize: 11,
  fontWeight: FontWeight.w800,
  color: Color(0xFF41575D),
);

enum AttendanceStatusFilter { all, present, excused, absent, late }

enum AttendanceStatus { present, absent, excused, late }

class _StudentRow {
  _StudentRow({
    required this.id,
    required this.name,
    required this.academicNumber,
    required this.attendanceTime,
    required this.percentage,
    required this.status,
    this.isOffline = false,
    this.isSuspended = false,
  });

  final String id;
  final String name;
  final String academicNumber;
  final String attendanceTime;
  final int percentage;
  AttendanceStatus status;
  final bool isOffline;
  /// عندما true يُلوّن صف الطالب بالأحمر فقط — لا توجد حالة "محروم" في الحالات (حاضر/غائب/غياب بعذر/تأخر).
  /// nullable للتوافق مع Hot Reload عند وجود نسخ قديمة من الصفوف.
  final bool? isSuspended;
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.chipLabel,
    required this.bg,
    required this.fg,
    required this.activeBg,
  });

  final String label;
  /// نص مختصر داخل الـ chip (مثلاً "بعذر")؛ الفلتر يبقى label كامل ("غياب بعذر")
  final String chipLabel;
  final Color bg;
  final Color fg;
  /// لون خلفية الفلتر عند التفعيل (للتباين مع النص الأبيض)
  final Color activeBg;
}
