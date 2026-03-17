import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/chatbot_repository.dart';
import '../data/openai_service.dart';
import '../models/chat_message.dart';

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
      try {
        final context = await ChatbotRepository.instance.getAttendanceContext();
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
