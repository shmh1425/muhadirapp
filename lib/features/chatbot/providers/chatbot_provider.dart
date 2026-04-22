import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/chatbot_repository.dart';
import '../data/openai_service.dart';
import '../models/chat_message.dart';
import '../models/attendance_context.dart';
import '../../../services/student_auth_service.dart';

class ChatbotProvider extends ChangeNotifier {
  ChatbotProvider._();
  static final ChatbotProvider instance = ChatbotProvider._();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _lastError;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  static const String _errorGeneric =
      'عذراً، حدث خطأ. تحقق من اتصالك وحاول مجدداً 🔄';

  bool _isAbsenceQuickQuery(String text) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return false;
    // Arabic quick queries
    if (t.contains('كم غيابي') || t == 'غيابي' || t == 'كم الغياب' || t == 'كم غياب') {
      return true;
    }
    // English quick queries
    if (t.contains('how many absences') || t == 'absences' || t == 'my absences') {
      return true;
    }
    return false;
  }

  String _formatAbsenceQuickReply({
    required String userMessage,
    required String studentName,
    required List<CourseAttendanceSummary> courses,
  }) {
    final t = userMessage.trim().toLowerCase();

    CourseAttendanceSummary? pickCourseByMention() {
      for (final c in courses) {
        final name = c.displayName.toLowerCase();
        if (name.isNotEmpty && t.contains(name)) return c;
      }
      return null;
    }

    String oneCourse(CourseAttendanceSummary c) {
      // Keep the old template but remove "إجمالي المحاضرات".
      // absentCount = unexcused, excusedCount = excused.
      final totalAbs = c.absentCount + c.excusedCount;
      final pct = c.absenceRate.isFinite ? c.absenceRate : 0.0;
      final pctText = pct.toStringAsFixed(1);

      final statusEmoji = c.isDeprivation
          ? '🚫'
          : (c.isWarning ? '⚠️' : '🟢');
      final statusText = c.isDeprivation
          ? 'أنت قريب/داخل الحرمان — انتبه جدًا.'
          : (c.isWarning ? 'لديك نسبة غياب مرتفعة، كن حذرًا!' : 'وضعك سليم حاليًا');

      final courseEmoji = () {
        final idx = courses.indexOf(c);
        switch (idx) {
          case 0:
            return '📘';
          case 1:
            return '📗';
          case 2:
            return '📙';
          default:
            return '📕';
        }
      }();

      return '$courseEmoji ${c.displayName}\n'
          '- الغياب: $totalAbs\n'
          '- بدون عذر: ${c.absentCount}\n'
          '- بعذر: ${c.excusedCount}\n'
          '- نسبة الغياب: $pctText%\n'
          '- المتبقي قبل الحرمان: ${c.remainingBeforeDeprivation} محاضرات\n'
          '$statusEmoji الحالة: $statusText';
    }

    if (courses.isEmpty) {
      return 'ما عندي بيانات غياب كافية حالياً.';
    }

    final mentioned = pickCourseByMention();
    if (mentioned != null) {
      return oneCourse(mentioned);
    }

    String shortName(String raw) {
      final s = raw.trim();
      if (s.isEmpty) return '';
      final parts = s.split(RegExp(r'\s+')).where((p) => p.trim().isNotEmpty).toList();
      return parts.isEmpty ? '' : parts.first.trim();
    }

    bool containsLatin(String s) => RegExp(r'[A-Za-z]').hasMatch(s);

    final fallbackArName = shortName(StudentAuthService.instance.currentStudent?.nameAr ?? '');
    final pickedName = shortName(studentName);
    final displayName = (pickedName.isEmpty || containsLatin(pickedName)) ? fallbackArName : pickedName;

    final greetName = displayName.isEmpty ? '' : ' $displayName';
    final lines = <String>['هلًا$greetName!'];
    for (final c in courses) {
      lines.add(oneCourse(c));
      lines.add(''); // blank line
    }
    // remove trailing blank
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    // Overall summary: one concise line like the old behavior.
    final warnings = courses.where((c) => c.isWarning && !c.isDeprivation).toList();
    final deprivations = courses.where((c) => c.isDeprivation).toList();

    String overall;
    if (deprivations.isNotEmpty) {
      final name = deprivations.first.displayName;
      overall = '📊 وضعك العام: لديك خطر حرمان في $name 🚫';
    } else if (warnings.isNotEmpty) {
      final name = warnings.first.displayName;
      overall = '📊 وضعك العام: انتبه للغياب في $name ⚠️';
    } else {
      overall = '📊 وضعك العام: وضعك ممتاز حاليًا 🟢';
    }

    return [...lines, '', overall].join('\n');
  }

  String _userFriendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
      return 'لا يوجد اتصال بالإنترنت. تحقق من الشبكة.';
    }
    if (msg.contains('TimeoutException') || msg.contains('timeout')) {
      return 'انتهت مهلة الاتصال. جرّب مرة أخرى.';
    }
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'لا توجد صلاحية للوصول للبيانات. تواصل مع الإدارة.';
      }
      return 'خطأ في قاعدة البيانات: ${e.message ?? e.code}';
    }
    if (msg.contains('OPENAI') || msg.contains('401') || msg.contains('429')) {
      return msg;
    }
    if (msg.length > 120) return 'خطأ: ${msg.substring(0, 120)}...';
    return 'خطأ: $msg';
  }

  Future<void> sendMessage(String userMessage) async {
    final text = userMessage.trim();
    if (text.isEmpty) return;

    _lastError = null;
    _messages.add(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    _isLoading = true;
    notifyListeners();

    try {
      // جلب بيانات الحضور — إذا فشل (صلاحيات/شبكة) نكمل بدونها حتى يرد البوت على التحية وأي سؤال
      String attendanceString = '';
      AttendanceContext? attendanceContextObj;
      try {
        final context = await ChatbotRepository.instance.getAttendanceContext();
        attendanceContextObj = context;
        attendanceString = context?.rawContextString ?? '';
      } catch (e, st) {
        if (kDebugMode) debugPrint('ChatbotRepository error (attendance): $e\n$st');
        attendanceString = '''
[ملاحظة للمساعد: بيانات الحضور من قاعدة البيانات غير متوفرة حالياً (مشكلة صلاحيات أو اتصال).
عند التحية أو الأسئلة العامة رد بشكل طبيعي وودي.
عند السؤال عن الغياب أو الحرمان أو الحضور قل بأدب: "لا أستطيع عرض بيانات الحضور حالياً. يرجى التواصل مع الإدارة لتفعيل الصلاحيات." ثم قدّم مساعدة أخرى إن أمكن.]
''';
      }

      // Build history for memory (exclude current message)
      final history = _messages
          .sublist(0, _messages.length - 1)
          .map((m) => <String, String>{
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              })
          .toList();

      // For "كم غيابي؟" style questions, respond deterministically and concise
      // without going through the LLM prompt formatting.
      if (_isAbsenceQuickQuery(text) && attendanceContextObj != null) {
        final reply = _formatAbsenceQuickReply(
          userMessage: text,
          studentName: attendanceContextObj!.studentName,
          courses: attendanceContextObj!.courses,
        );
        _messages.add(ChatMessage(
          id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
          text: reply,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        return;
      }

      final reply = await OpenAIService.instance.sendMessage(
        userMessage: text,
        attendanceContext: attendanceString,
        chatHistory: history,
      );

      _messages.add(ChatMessage(
        id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
        text: reply,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    } on ChatbotException catch (e) {
      _messages.add(ChatMessage(
        id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
        text: e.message,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _lastError = e.message;
    } catch (e, st) {
      if (kDebugMode) debugPrint('Chatbot error: $e\n$st');
      final friendly = _userFriendlyError(e);
      _messages.add(ChatMessage(
        id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
        text: friendly,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _lastError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _messages.clear();
    _lastError = null;
    _isLoading = false;
    notifyListeners();
  }
}
