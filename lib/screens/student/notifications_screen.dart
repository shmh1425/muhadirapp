import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/notifications/student_notification.dart';
import '../../services/student_auth_service.dart';
import '../../services/student_notifications_service.dart';
import '../../shared/widgets/chat_fab.dart';
import '../../features/translation/translation_controller.dart';
import '../../features/translation/widgets/t_text.dart';
import '../../services/excuse/excuse_attendance_merge.dart';
import 'excuse_screen.dart';
import 'pending_detail_screen.dart';
import 'rejection_detail_screen.dart';
import 'components/student_back_chevron_icon.dart';
import 'schedule_screen.dart';
import 'submit_excuse_screen.dart';

/// Visual style bucket for notification cards (Arabic-first UI spec).
enum _NotificationVisualKind {
  absence,
  delay,
  lecture,
  excusePending,
  excuseAccepted,
  excuseRejected,
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final StudentNotificationsService _notificationsService =
      StudentNotificationsService.instance;

  int get _studentId =>
      StudentAuthService.instance.currentStudent?.studentId ?? 0;

  /// One stable stream per screen open. Re-creating [watchCurrentStudentNotifications]
  /// on every [AnimatedBuilder] rebuild resets [StreamBuilder] to `waiting` and
  /// flashes the loading spinner indefinitely.
  Stream<List<StudentNotification>>? _notificationsStream;

  String _selectedCategory = 'الكل';
  final ValueNotifier<Set<String>> _optimisticHiddenIds =
      ValueNotifier<Set<String>>(<String>{});

  String _tr(TranslationController t, String ar, String en) =>
      t.translateToEnglish ? en : ar;

  static const Color _bg = Color(0xFFF7F9FB);
  static const Color _brand = Color(0xFF0F766E);
  static const Color _brandAccent = Color(0xFF14B8A6);
  static const Color _mutedTab = Color(0xFF94A3B8);
  /// Matches other student headers (جدول، حضور، أعذار).
  static const Color _headerPrimary = Color(0xFF006571);
  static const Color _deleteAllRed = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    final id = StudentAuthService.instance.currentStudent?.studentId ?? 0;
    if (id > 0) {
      _notificationsStream =
          _notificationsService.watchCurrentStudentNotifications(id);
    }
  }

  @override
  void dispose() {
    _optimisticHiddenIds.dispose();
    super.dispose();
  }

  String _deleteFailureMessage(TranslationController t, Object error) {
    final en = t.translateToEnglish;
    if (error is FirebaseException) {
      final code = error.code.trim().toLowerCase();
      switch (code) {
        case 'permission-denied':
          return en
              ? 'Delete failed (permission denied). Possible causes: you are not signed in as the correct student, Firestore rules block this action, or the record belongs to another student.'
              : 'فشل الحذف (ليس لديك صلاحية). أسباب محتملة: لم تسجّل دخولك كطالب صحيح، أو قواعد Firestore تمنع العملية، أو أن السجل لا يخص هذا الطالب.';
        case 'not-found':
          return en
              ? 'Delete failed (not found). The notification may have already been deleted or the data is out of sync.'
              : 'فشل الحذف (غير موجود). ربما تم حذف الإشعار مسبقًا أو البيانات غير متزامنة.';
        case 'unavailable':
        case 'deadline-exceeded':
          return en
              ? 'Delete failed (network/service unavailable). Check your internet connection and try again.'
              : 'فشل الحذف (مشكلة شبكة/الخدمة غير متاحة). تأكد من الاتصال بالإنترنت ثم حاول مرة أخرى.';
        case 'failed-precondition':
        case 'aborted':
          return en
              ? 'Delete failed due to a temporary conflict. Try again in a moment.'
              : 'فشل الحذف بسبب تعارض مؤقت. حاول مرة أخرى بعد قليل.';
        default:
          final msg = (error.message ?? '').trim();
          return en
              ? 'Delete failed ($code). ${msg.isEmpty ? 'Please try again.' : msg}'
              : 'فشل الحذف ($code). ${msg.isEmpty ? 'حاول مرة أخرى.' : msg}';
      }
    }
    return en
        ? 'Delete failed. Please try again.'
        : 'تعذر حذف الإشعار. حاول مرة أخرى.';
  }

  String _relativeTime(TranslationController t, DateTime at) {
    final now = DateTime.now();
    var diff = now.difference(at);
    if (diff.isNegative) diff = Duration.zero;
    final en = t.translateToEnglish;

    if (diff.inSeconds < 45) {
      return en ? 'Just now' : 'الآن';
    }
    final m = diff.inMinutes;
    if (m < 1) {
      return en ? 'Just now' : 'الآن';
    }
    if (m < 60) {
      if (en) {
        return m == 1 ? '1 minute ago' : '$m minutes ago';
      }
      if (m == 1) return 'قبل دقيقة';
      if (m == 2) return 'قبل دقيقتين';
      if (m <= 10) return 'قبل $m دقائق';
      return 'قبل $m دقيقة';
    }
    final h = diff.inHours;
    if (h < 24) {
      if (en) {
        return h == 1 ? '1 hour ago' : '$h hours ago';
      }
      if (h == 1) return 'قبل ساعة';
      if (h == 2) return 'قبل ساعتين';
      if (h <= 10) return 'قبل $h ساعات';
      return 'قبل $h ساعة';
    }
    final d = diff.inDays;
    if (en) {
      return d == 1 ? 'Yesterday' : (d < 7 ? '$d days ago' : '${d ~/ 7} weeks ago');
    }
    if (d == 1) return 'أمس';
    if (d == 2) return 'قبل يومين';
    if (d < 7) return 'قبل $d أيام';
    if (d < 30) return 'قبل ${d ~/ 7} أسابيع';
    if (en) return '${d ~/ 30} months ago';
    return 'قبل ${d ~/ 30} شهرًا تقريبًا';
  }

  _NotificationVisualKind _visualKind(StudentNotification n) {
    switch (n.category) {
      case StudentNotificationCategory.attendance:
        return _NotificationVisualKind.absence;
      case StudentNotificationCategory.excuses:
        final s = n.excuseStatus.trim().toLowerCase();
        if (s == 'accepted') return _NotificationVisualKind.excuseAccepted;
        if (s == 'rejected') return _NotificationVisualKind.excuseRejected;
        return _NotificationVisualKind.excusePending;
      case StudentNotificationCategory.lectures:
        if (n.actionType.trim().toLowerCase() == 'delay') {
          return _NotificationVisualKind.delay;
        }
        return _NotificationVisualKind.lecture;
    }
  }

  @override
  Widget build(BuildContext context) {
    final translation = TranslationController.instance;
    return AnimatedBuilder(
      animation: translation,
      builder: (context, _) {
        return Directionality(
          textDirection: translation.textDirection,
          child: Scaffold(
            backgroundColor: _bg,
            floatingActionButton: const ChatFAB(),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context, translation),
                    if (_studentId > 0) _buildTabs(translation),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                        children: _buildNotificationContent(translation),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, TranslationController t) {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: StudentBackChevronIcon(
              color: _headerPrimary,
              size: 16,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TText(
                _tr(t, 'التنبيهات', 'Notifications'),
                textAlign: TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _headerPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(TranslationController t) {
    Widget tab(String value, String ar, String en) {
      final isActive = _selectedCategory == value;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _selectedCategory = value),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TText(
                  _tr(t, ar, en),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive ? _brand : _mutedTab,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: isActive
                        ? const LinearGradient(
                            colors: <Color>[_brand, _brandAccent],
                          )
                        : null,
                    color: isActive ? null : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
            child: Row(
              children: [
                tab('الكل', 'الكل', 'All'),
                tab('المحاضرات', 'المحاضرات', 'Classes'),
                tab('الحضور', 'الحضور', 'Attendance'),
                tab('الأعذار', 'الأعذار', 'Excuses'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, end: 8, bottom: 10),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _confirmDeleteAll,
                style: TextButton.styleFrom(
                  foregroundColor: _deleteAllRed,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: TText(
                  _tr(t, 'حذف الكل', 'Delete all'),
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _deleteAllRed,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNotificationContent(TranslationController t) {
    if (_studentId <= 0) {
      return <Widget>[
        _EmptyNotificationsMessage(
          message: _tr(t, 'سجّل دخولك كطالب لعرض التنبيهات.', 'Sign in as a student to view notifications.'),
        ),
      ];
    }

    _notificationsStream ??=
        _notificationsService.watchCurrentStudentNotifications(_studentId);

    return <Widget>[
      StreamBuilder<List<StudentNotification>>(
        initialData: const <StudentNotification>[],
        stream: _notificationsStream!,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _EmptyNotificationsMessage(
              message: _tr(t, 'تعذر تحميل التنبيهات حالياً.', 'Could not load notifications.'),
            );
          }

          final all = snapshot.data ?? const <StudentNotification>[];
          return ValueListenableBuilder<Set<String>>(
            valueListenable: _optimisticHiddenIds,
            builder: (context, optimisticHidden, _) {
              final filtered = _sortedNotificationsForDisplay(
                _filteredNotifications(all)
                    .where(
                      (n) =>
                          !optimisticHidden.contains(n.id) &&
                          !optimisticHidden.contains(n.rawId),
                    )
                    .toList(),
              );

              if (filtered.isEmpty) {
                return _EmptyNotificationsMessage(
                  message: _tr(t, 'لا يوجد تنبيهات', 'No notifications'),
                );
              }

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: Column(
                  key: ValueKey<String>('${_selectedCategory}_${filtered.length}'),
                  children: filtered
                      .map(
                        (n) => _NotificationCard(
                          notification: n,
                          visualKind: _visualKind(n),
                          relativeTime: _relativeTime(t, n.createdAt),
                          onOpen: () => _openDetails(n),
                          onSwipeDelete: () => _confirmAndDeleteNotification(n),
                          tr: _tr,
                        ),
                      )
                      .toList(),
                ),
              );
            },
          );
        },
      ),
    ];
  }

  /// Unread first; within each group, newest first.
  List<StudentNotification> _sortedNotificationsForDisplay(List<StudentNotification> items) {
    final copy = List<StudentNotification>.from(items);
    copy.sort((StudentNotification a, StudentNotification b) {
      if (a.isRead != b.isRead) {
        return a.isRead ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return copy;
  }

  List<StudentNotification> _filteredNotifications(List<StudentNotification> all) {
    if (_selectedCategory == 'الكل') return all;
    return all.where((n) {
      switch (_selectedCategory) {
        case 'الحضور':
          return n.category == StudentNotificationCategory.attendance;
        case 'المحاضرات':
          return n.category == StudentNotificationCategory.lectures;
        case 'الأعذار':
          return n.category == StudentNotificationCategory.excuses;
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _openDetails(StudentNotification notification) async {
    try {
      await _notificationsService.markAsRead(
        studentId: _studentId,
        notification: notification,
      );
    } on FirebaseException catch (_) {
    } catch (_) {}

    if (!mounted) return;
    await _navigateForNotification(notification);
  }

  String _timeRangeFor(StudentNotification n) {
    final start = n.lectureStartTime.trim();
    final end = n.lectureEndTime.trim();
    if (start.isNotEmpty && end.isNotEmpty) return '$start-$end';
    return '—';
  }

  String _dateTextFor(StudentNotification n) {
    final t = TranslationController.instance;
    final d = n.lectureDate ?? n.createdAt;
    return t.translateToEnglish
        ? ExcuseAttendanceMerge.formatEnglishLectureDate(d)
        : ExcuseAttendanceMerge.formatArabicLectureDate(d);
  }

  Future<void> _navigateForNotification(StudentNotification n) async {
    if (!mounted) return;
    final t = TranslationController.instance;

    if (n.category == StudentNotificationCategory.attendance) {
      final sectionId = n.sectionId.trim();
      final sessionId = n.sessionId.trim();
      final lectureDate = n.lectureDate;
      if (sectionId.isNotEmpty && sessionId.isNotEmpty && lectureDate != null) {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => SubmitExcuseScreen(
              course: n.courseName.isEmpty ? null : n.courseName,
              dateText: _dateTextFor(n),
              timeRange: _timeRangeFor(n),
              sectionId: sectionId,
              lectureDate: lectureDate,
              sessionId: sessionId,
              attendanceRecordId: n.attendanceRecordId.isNotEmpty
                  ? n.attendanceRecordId
                  : n.rawId,
            ),
          ),
        );
      }
      return;
    }

    if (n.category == StudentNotificationCategory.lectures) {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const ScheduleScreen()),
      );
      return;
    }

    final status = n.excuseStatus.trim().toLowerCase();
    if (status == 'pending') {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PendingDetailScreen(
            studentId: _studentId,
            attendanceRecordId: n.attendanceRecordId,
            course: n.courseName.isEmpty ? (t.translateToEnglish ? 'Course' : 'المقرر') : n.courseName,
            dateText: _dateTextFor(n),
            timeRange: _timeRangeFor(n),
          ),
        ),
      );
      return;
    }

    if (status == 'rejected') {
      final sectionId = n.sectionId.trim();
      final sessionId = n.sessionId.trim();
      final lectureDate = n.lectureDate;
      if (sectionId.isNotEmpty && sessionId.isNotEmpty && lectureDate != null) {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => RejectionDetailScreen(
              course: n.courseName.isEmpty ? (t.translateToEnglish ? 'Course' : 'المادة') : n.courseName,
              dateText: _dateTextFor(n),
              timeRange: _timeRangeFor(n),
              reason: n.rejectionReason.isNotEmpty
                  ? n.rejectionReason
                  : (t.translateToEnglish ? 'Your excuse was not accepted.' : 'تم رفض العذر.'),
              sectionId: sectionId,
              lectureDate: lectureDate,
              sessionId: sessionId,
              attendanceRecordId: n.attendanceRecordId,
              attachmentUrl: n.attachmentUrl,
              attachmentName: n.attachmentName,
            ),
          ),
        );
      } else {
        Navigator.push<void>(
          context,
          MaterialPageRoute<void>(builder: (_) => const ExcuseScreen()),
        );
      }
      return;
    }

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const ExcuseScreen()),
    );
  }

  /// Shown after swipe threshold; returns whether [Dismissible] should remove the tile.
  Future<bool> _confirmAndDeleteNotification(StudentNotification notification) async {
    final t = TranslationController.instance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: t.textDirection,
        child: AlertDialog(
          title: Text(_tr(t, 'حذف الإشعار', 'Delete notification')),
          content: Text(
            _tr(t, 'هل أنت متأكد من حذف هذا الإشعار؟', 'Are you sure you want to delete this notification?'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(_tr(t, 'إلغاء', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(_tr(t, 'موافق', 'OK')),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return false;
    if (confirmed != true) return false;
    return _deleteNotification(notification);
  }

  /// Returns `true` if the notification was removed from the server (or hidden) successfully.
  Future<bool> _deleteNotification(StudentNotification notification) async {
    final t = TranslationController.instance;
    try {
      await _notificationsService.deleteNotification(
        studentId: _studentId,
        notification: notification,
      );
      if (!mounted) return false;
      final next = Set<String>.of(_optimisticHiddenIds.value)
        ..add(notification.id)
        ..add(notification.rawId);
      _optimisticHiddenIds.value = next;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr(t, 'تم حذف الإشعار.', 'Notification deleted.')),
          duration: const Duration(seconds: 2),
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_deleteFailureMessage(t, e)),
        ),
      );
      return false;
    }
  }

  void _confirmDeleteAll() {
    final t = TranslationController.instance;
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: t.textDirection,
        child: AlertDialog(
          title: Text(_tr(t, 'حذف كل الإشعارات', 'Delete all notifications')),
          content: Text(_tr(t, 'سيتم حذف جميع الإشعارات من القائمة. هل تريد المتابعة؟', 'This will remove all notifications from the list. Continue?')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(_tr(t, 'إلغاء', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () {
                Navigator.of(ctx).pop();
                _deleteAll();
              },
              child: Text(_tr(t, 'حذف الكل', 'Delete all')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAll() async {
    final t = TranslationController.instance;
    try {
      final all = await _notificationsService
          .watchCurrentStudentNotifications(_studentId)
          .first;
      final filtered = _filteredNotifications(all);
      await _notificationsService.deleteAllForStudent(
        studentId: _studentId,
        visibleNotifications: filtered,
      );
      if (!mounted) return;
      final next = Set<String>.of(_optimisticHiddenIds.value);
      for (final n in filtered) {
        next.add(n.id);
        next.add(n.rawId);
      }
      _optimisticHiddenIds.value = next;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr(t, 'تم حذف جميع الإشعارات.', 'All notifications have been deleted.')),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_deleteFailureMessage(t, e)),
        ),
      );
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.visualKind,
    required this.relativeTime,
    required this.onOpen,
    required this.onSwipeDelete,
    required this.tr,
  });

  final StudentNotification notification;
  final _NotificationVisualKind visualKind;
  final String relativeTime;
  final VoidCallback onOpen;
  /// After swipe threshold: parent shows confirm dialog, then deletes if user accepts.
  final Future<bool> Function() onSwipeDelete;
  final String Function(TranslationController t, String ar, String en) tr;

  String _typeTitle(TranslationController t) {
    switch (visualKind) {
      case _NotificationVisualKind.absence:
        return tr(t, 'إشعار غياب', 'Absence alert');
      case _NotificationVisualKind.delay:
        return tr(t, 'تأخير المحاضرة', 'Lecture delay');
      case _NotificationVisualKind.lecture:
        return tr(t, 'تحديث محاضرة', 'Lecture update');
      case _NotificationVisualKind.excusePending:
      case _NotificationVisualKind.excuseAccepted:
      case _NotificationVisualKind.excuseRejected:
        return tr(t, 'إشعار عذر', 'Excuse notice');
    }
  }

  (Color icon, Color stripe, IconData iconData) _style() {
    switch (visualKind) {
      case _NotificationVisualKind.absence:
        return (
          const Color(0xFFDC2626),
          const Color(0xFFFEE2E2),
          Icons.warning_amber_rounded,
        );
      case _NotificationVisualKind.delay:
      case _NotificationVisualKind.excusePending:
        return (
          const Color(0xFFF59E0B),
          const Color(0xFFFEF3C7),
          Icons.notifications_active_outlined,
        );
      case _NotificationVisualKind.excuseAccepted:
        return (
          const Color(0xFF10B981),
          const Color(0xFFD1FAE5),
          Icons.notifications_active_outlined,
        );
      case _NotificationVisualKind.excuseRejected:
        return (
          const Color(0xFFDC2626),
          const Color(0xFFFEE2E2),
          Icons.notifications_active_outlined,
        );
      case _NotificationVisualKind.lecture:
        return (
          const Color(0xFF10B981),
          const Color(0xFFD1FAE5),
          Icons.calendar_month_rounded,
        );
    }
  }

  /// Read: keep pastel stripe. Unread: richer stripe toward accent (clearer than title weight alone).
  static const double _unreadStripeAccentMix = 0.72;

  Color _stripeEdgeColor(Color pastelStripe, Color accent, bool unread) {
    if (!unread) return pastelStripe;
    return Color.lerp(pastelStripe, accent, _unreadStripeAccentMix)!;
  }

  @override
  Widget build(BuildContext context) {
    final t = TranslationController.instance;
    final message = t.translateToEnglish ? notification.messageEn : notification.messageAr;
    final desc = message.trim().isEmpty
        ? (t.translateToEnglish ? notification.titleEn : notification.titleAr)
        : message;
    final unread = !notification.isRead;
    final (iconColor, stripePastel, iconData) = _style();
    final stripeColor = _stripeEdgeColor(stripePastel, iconColor, unread);

    final Widget cardFace = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: stripeColor),
                Expanded(
                  child: InkWell(
                    onTap: onOpen,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TText(
                            _typeTitle(t),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                              fontSize: 15,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TText(
                            desc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13.5,
                              height: 1.35,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TText(
                            relativeTime,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12, start: 2),
                  child: Center(
                    child: Icon(iconData, color: iconColor, size: 26),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey<String>('student_notif_${notification.id}'),
        direction: DismissDirection.endToStart,
        dismissThresholds: const <DismissDirection, double>{
          DismissDirection.endToStart: 0.5,
        },
        confirmDismiss: (_) async => onSwipeDelete(),
        background: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerEnd,
              end: AlignmentDirectional.centerStart,
              colors: <Color>[
                const Color(0xFFDC2626).withValues(alpha: 0.95),
                const Color(0xFFDC2626).withValues(alpha: 0.35),
              ],
            ),
          ),
        ),
        child: cardFace,
      ),
    );
  }
}

class _EmptyNotificationsMessage extends StatelessWidget {
  const _EmptyNotificationsMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return SizedBox(
      height: (h * 0.45).clamp(220.0, 420.0),
      child: Center(
        child: TText(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 15,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
