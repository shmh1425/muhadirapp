import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/chatbot_repository.dart';
import '../data/openai_service.dart';
import '../models/chat_message.dart';
import '../models/attendance_context.dart';
import '../../../services/student_auth_service.dart';

/// في تقرير الغياب السريع: **1 ساعة = جلسة واحدة** (بدون اشتقاق من المخطط ÷ عدد الجلسات).
double _avgSessionHours(CourseAttendanceSummary _) {
  return 1.0;
}

/// أقصى استخدام نسبي للحدود (بدون عذر / بعذر / إجمالي) — يحدد مستوى الخطر.
double _maxRiskUtilization(
  CourseAttendanceSummary c,
  int maxUnexcusedPercent,
  int deprivationPercent,
) {
  final ru = maxUnexcusedPercent > 0
      ? c.unexcusedAbsenceRate / maxUnexcusedPercent
      : 0.0;
  final re =
      deprivationPercent > 0 ? c.excusedAbsenceRate / deprivationPercent : 0.0;
  final rt =
      deprivationPercent > 0 ? c.absenceRate / deprivationPercent : 0.0;
  var m = 0.0;
  for (final x in <double>[ru, re, rt]) {
    if (x.isFinite && x > m) m = x;
  }
  return m.clamp(0.0, 99.0);
}

String _riskEmoji(double u) {
  if (u >= 1.0) return '🔴';
  if (u >= 0.8) return '🟠';
  if (u >= 0.5) return '🟡';
  return '🟢';
}

String _riskLabelAr(double u) {
  if (u >= 1.0) return 'تجاوز الحد';
  if (u >= 0.8) return 'خطر مرتفع';
  if (u >= 0.5) return 'تنبيه مبكر';
  return 'آمن';
}

String _absenceSessionsLine(int sessions, double hours) {
  final h = hours.toStringAsFixed(1);
  if (sessions <= 0) {
    return '• الغياب: — ($h ساعة)';
  }
  final sessWord = sessions == 1
      ? 'جلسة واحدة'
      : sessions == 2
          ? '2 جلسة'
          : '$sessions جلسات';
  return '• الغياب: $sessWord ($h ساعة)';
}

String _remainingLineCompact(String label, double remHours, double avgH) {
  final h = remHours.toStringAsFixed(1);
  if (!avgH.isFinite || avgH <= 0) {
    return '• $label: $h س (—)';
  }
  final n = remHours / avgH;
  if (n < 1.0) {
    return '• $label: 0 س';
  }
  // بدون تقريب لأعلى: الجلسات = جزء صحيح من الساعات (مثلاً 13.5 س → 13 جلسة).
  final sessions = n.floor().clamp(1, 9999);
  if (sessions == 1) {
    return '• $label: $h س ≈ جلسة واحدة';
  }
  return '• $label: $h س ≈ $sessions جلسات';
}

int _affordableSessionsFloor(double remHours, double avgSessionHours) {
  if (!remHours.isFinite || remHours <= 0) return 0;
  if (!avgSessionHours.isFinite || avgSessionHours <= 0) return 0;
  return (remHours / avgSessionHours).floor();
}

String _hoursAmountDisplay(double v) {
  if (!v.isFinite || v <= 0) return '0';
  final r = v.round();
  if ((v - r).abs() < 0.05) return r.toString();
  return v.toStringAsFixed(1);
}

String _hourNounArForForecast(double hoursAmount) {
  if (!hoursAmount.isFinite || hoursAmount <= 0) return 'ساعة';
  final parsed = double.tryParse(_hoursAmountDisplay(hoursAmount));
  final n = parsed ?? hoursAmount;
  return (n - 1.0).abs() < 0.05 ? 'ساعة' : 'ساعات';
}

String _forecastUnexcusedHoursSentence(double remUnex) {
  final amt = _hoursAmountDisplay(remUnex);
  final noun = _hourNounArForForecast(remUnex);
  return 'يمكنك غياب $amt $noun بدون عذر تقريبًا';
}

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
    required AttendanceContext context,
  }) {
    final courses = context.courses;
    final studentName = context.studentName;
    final maxU = context.maxUnexcusedPercent;
    final dep = context.deprivationPercent;
    final t = userMessage.trim().toLowerCase();

    CourseAttendanceSummary? pickCourseByMention() {
      for (final c in courses) {
        final name = c.displayName.toLowerCase();
        if (name.isNotEmpty && t.contains(name)) return c;
      }
      return null;
    }

    String courseEmojiFor(CourseAttendanceSummary c) {
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
    }

    String oneCourse(CourseAttendanceSummary c) {
      final totalPct = c.absenceRate.isFinite ? c.absenceRate : 0.0;
      final excPct = c.excusedAbsenceRate.isFinite ? c.excusedAbsenceRate : 0.0;
      final unexPct = c.unexcusedAbsenceRate.isFinite ? c.unexcusedAbsenceRate : 0.0;

      final util = _maxRiskUtilization(c, maxU, dep);
      final rEmoji = _riskEmoji(util);
      final rLabel = _riskLabelAr(util);

      final absH = c.absenceHours.isFinite ? c.absenceHours : 0.0;
      final remUnex = c.remainingHoursUnexcusedBeforeLimit.isFinite
          ? c.remainingHoursUnexcusedBeforeLimit
          : 0.0;
      final remExc = c.remainingHoursExcusedBeforeLimit.isFinite
          ? c.remainingHoursExcusedBeforeLimit
          : 0.0;
      final remTotal =
          c.remainingHoursBeforeDeprivation.isFinite ? c.remainingHoursBeforeDeprivation : 0.0;

      final avgH = _avgSessionHours(c);
      final absenceSessions = c.absentCount + c.excusedCount;
      final uRatio = maxU > 0 ? unexPct / maxU : 0.0;

      final canUnexFloor =
          avgH > 0 ? _affordableSessionsFloor(remUnex, avgH) : 0;
      final strictWarn = remUnex <= 0 ||
          (remUnex > 0 && avgH > 0 && canUnexFloor <= 0) ||
          (uRatio >= 0.8 && remUnex > 0);

      final String forecastTail;
      if (strictWarn) {
        forecastTail = '\n\n⚠️ أي غياب بدون عذر = تجاوز الحد مباشرة';
      } else if (avgH <= 0) {
        forecastTail =
            '\n\n📍 لا يمكن تقدير الجلسات المتبقية بدون معرفة متوسط طول الجلسة.';
      } else {
        final can = canUnexFloor;
        if (can <= 0) {
          forecastTail = '\n\n📍 يمكنك غياب أقل من ساعة بدون عذر تقريبًا';
        } else {
          forecastTail = '\n\n📍 ${_forecastUnexcusedHoursSentence(remUnex)}';
        }
      }

      return '${courseEmojiFor(c)} ${c.displayName}\n\n'
          '• بدون عذر: ${unexPct.toStringAsFixed(1)}% من أصل $maxU%\n'
          '• بعذر: ${excPct.toStringAsFixed(1)}% من أصل $dep%\n'
          '• الإجمالي: ${totalPct.toStringAsFixed(1)}% من أصل $dep%\n'
          '${_absenceSessionsLine(absenceSessions, absH)}\n\n'
          '$rEmoji $rLabel\n'
          'المتبقي:\n'
          '${_remainingLineCompact('بدون عذر', remUnex, avgH)}\n'
          '${_remainingLineCompact('بعذر', remExc, avgH)}\n'
          '${_remainingLineCompact('حتى الحد الإجمالي', remTotal, avgH)}'
          '$forecastTail';
    }

    if (courses.isEmpty) {
      return 'ما عندي بيانات غياب كافية حالياً.';
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

    final greet = displayName.trim().isEmpty
        ? 'هلًا! 👋'
        : 'هلًا ${displayName.trim()}! 👋';
    final header = <String>[greet, '📊 تقرير الغياب', ''];

    final mentioned = pickCourseByMention();
    if (mentioned != null) {
      return [...header, oneCourse(mentioned)].join('\n');
    }

    final parts = <String>[...header];
    for (var i = 0; i < courses.length; i++) {
      if (i > 0) {
        parts.add('');
      }
      parts.add(oneCourse(courses[i]));
    }
    return parts.join('\n');
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
          context: attendanceContextObj!,
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
