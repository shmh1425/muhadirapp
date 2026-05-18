import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/lecturer/lecture_item.dart';
import '../../providers/lecturer_catalog_providers.dart';
import 'lecturer_language.dart';
import 'widgets/directional_navigation_icon.dart';
import 'widgets/modern_popup_dialog.dart';
import 'widgets/profile_back_button.dart';

class LecturerMyLecturesScreen extends ConsumerStatefulWidget {
  const LecturerMyLecturesScreen({super.key});

  @override
  ConsumerState<LecturerMyLecturesScreen> createState() =>
      _LecturerMyLecturesScreenState();
}

class _LecturerMyLecturesScreenState
    extends ConsumerState<LecturerMyLecturesScreen> {
  static const Color _primaryColor = Color(0xFF006571);

  final List<int> _dayOrder = const [7, 1, 2, 3, 4];

  String _tr(String ar, String en) => LecturerLanguageController.tr(ar, en);

  String _displayDayNameFromArabic(String day) {
    return LecturerLanguageController.dayNameFromArabic(day);
  }

  String _displayDayName(int weekday) {
    return _displayDayNameFromArabic(_dayName(weekday));
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(lecturerUnifiedCatalogProvider);
    return ValueListenableBuilder<LecturerLanguage>(
      valueListenable: LecturerLanguageController.notifier,
      builder: (context, lang, __) {
        final isArabic = lang == LecturerLanguage.arabic;
        final allLectures = catalogAsync.maybeWhen(
          data: (c) => c.toLectureItems(isArabic: isArabic),
          orElse: () => <LectureItem>[],
        );
        final loading = catalogAsync.isLoading && allLectures.isEmpty;
        final err = catalogAsync.hasError && allLectures.isEmpty;
        return Directionality(
          textDirection: LecturerLanguageController.direction(),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FBFB),
            body: SafeArea(
              child: loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(
                          color: Color(0xFF006571),
                        ),
                      ),
                    )
                  : err
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _tr(
                                'حدث خطأ في تحميل المحاضرات',
                                'Failed to load lectures',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () => ref.invalidate(
                                lecturerUnifiedCatalogProvider,
                              ),
                              icon: const Icon(Icons.refresh),
                              label: Text(_tr('إعادة المحاولة', 'Retry')),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 6),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: ProfileBackButton(onTap: _goBack),
                          ),
                          const SizedBox(height: 12),
                          _buildModernHeaderCard(),
                          const SizedBox(height: 12),
                          Expanded(child: _buildLectureCardsList(allLectures)),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B8793), Color(0xFF005B66)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr('محاضراتي', 'My Lectures'),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _tr(
                    'عرض بطاقات حديث ومنظّم حسب الأيام',
                    'Modern card-based view organized by day',
                  ),
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLectureCardsList(List<LectureItem> allLectures) {
    final sorted = [...allLectures]
      ..sort((a, b) {
        final dayCompare = _dayOrder
            .indexOf(a.dayOfWeek)
            .compareTo(_dayOrder.indexOf(b.dayOfWeek));
        if (dayCompare != 0) return dayCompare;
        return _normalizeHour(
          a.startTime,
        ).compareTo(_normalizeHour(b.startTime));
      });

    if (sorted.isEmpty) {
      return Center(
        child: Text(
          _tr('لا توجد محاضرات حالياً', 'No lectures available'),
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            color: Color(0xFF607278),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final grouped = <int, List<LectureItem>>{
      for (final day in _dayOrder) day: <LectureItem>[],
    };
    for (final lecture in sorted) {
      if (grouped.containsKey(lecture.dayOfWeek)) {
        grouped[lecture.dayOfWeek]!.add(lecture);
      }
    }

    return RefreshIndicator(
      color: _primaryColor,
      onRefresh: () async {
        ref.invalidate(lecturerUnifiedCatalogProvider);
        await ref.read(lecturerUnifiedCatalogProvider.future);
      },
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        children: [
          for (final day in _dayOrder)
            if ((grouped[day] ?? []).isNotEmpty)
              _buildDayCardsSection(day: day, lectures: grouped[day]!),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildDayCardsSection({
    required int day,
    required List<LectureItem> lectures,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFDDE9EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 5,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _displayDayName(day),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF32484D),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F4F5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${lectures.length}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...lectures.map(
              (lecture) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildLectureCard(lecture),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLectureCard(LectureItem lecture) {
    final activity = lecture.activity.trim().toLowerCase();
    final isPractical = activity == 'عملي' || activity == 'lab';
    final accentStart = isPractical ? const Color(0xFF2A9DA7) : _primaryColor;
    final accentEnd = isPractical
        ? const Color(0xFF167B83)
        : const Color(0xFF0D5C66);
    final timeLabel =
        '${_displayHour(_normalizeHour(lecture.startTime))} - ${_displayHour(_normalizeHour(lecture.endTime))}';
    final subtitle = '${_displayDayName(lecture.dayOfWeek)} • $timeLabel';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showLectureDialog(lecture),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCE7E9)),
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentStart, accentEnd],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            lecture.courseName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              color: Color(0xFF17363D),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        LecturerDirectionalForwardIcon(
                          size: 14,
                          color: _primaryColor.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Color(0xFF6C8288),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _buildInfoPill(
                          icon: Icons.account_tree_outlined,
                          label:
                              '${_tr('الشعبة', 'Section')} ${lecture.section}',
                        ),
                        _buildInfoPill(
                          icon: Icons.meeting_room_outlined,
                          label: lecture.hall,
                        ),
                        _buildInfoPill(
                          icon: Icons.school_outlined,
                          label: lecture.activity,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDCE7E9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _primaryColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: Color(0xFF24484F),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _showLectureDialog(LectureItem lecture) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: LecturerLanguageController.direction(),
        child: ModernPopupSheet(
          accentColor: _primaryColor,
          title: _tr('تفاصيل المحاضرة', 'Lecture Details'),
          onClose: () => Navigator.of(ctx).pop(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow(_tr('المقرر', 'Course'), lecture.courseName),
              _detailRow('CRN', lecture.crn),
              _detailRow(_tr('الشعبة', 'Section'), lecture.section),
              _detailRow(_tr('القاعة', 'Hall'), lecture.hall),
              if (lecture.location != null &&
                  lecture.location!.trim().isNotEmpty)
                _detailRow(_tr('الموقع', 'Location'), lecture.location!.trim()),
              _detailRow(
                _tr('النوع', 'Type'),
                _activityLabel(lecture.activity),
              ),
              _detailRow(
                _tr('اليوم', 'Day'),
                _displayDayName(lecture.dayOfWeek),
              ),
              _detailRow(
                _tr('الوقت', 'Time'),
                '${_displayHour(_normalizeHour(lecture.startTime))} – ${_displayHour(_normalizeHour(lecture.endTime))}',
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF27A2A9), Color(0xFF006571)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      _tr('إغلاق', 'Close'),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3ECEE)),
        ),
        child: Text(
          '$label: $value',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  int _normalizeHour(String time) {
    final int raw = int.tryParse(time.split(':').first) ?? 0;
    if (raw < 8) return raw + 12;
    return raw;
  }

  String _displayHour(int hour) {
    final int hour12 = hour > 12 ? hour - 12 : hour;
    final String suffix = hour >= 12 ? 'PM' : 'AM';
    return '${hour12.toString().padLeft(2, '0')}:00 $suffix';
  }

  String _dayName(int weekday) {
    return LecturerLanguageController.dayNameFromWeekday(weekday);
  }

  String _activityLabel(String activity) {
    switch (activity.trim().toLowerCase()) {
      case 'عملي':
      case 'lab':
        return _tr('عملي', 'Lab');
      case 'نظري':
      case 'theory':
        return _tr('نظري', 'Theory');
      default:
        return activity;
    }
  }
}
