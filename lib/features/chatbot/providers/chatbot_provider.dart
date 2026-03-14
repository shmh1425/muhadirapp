import 'package:flutter/foundation.dart';

import '../data/chatbot_repository.dart';
import '../data/openai_service.dart';
import '../models/attendance_context.dart';
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

  static const String _errorFirestore =
      'عذراً، لم أتمكن من جلب بياناتك. حاول مجدداً';
  static const String _errorOpenAI =
      'عذراً، حدث خطأ في الاتصال. تحقق من اتصالك';
  static const String _errorNoEnrollments =
      'لا يوجد تسجيل في مواد لهذا الفصل';

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
    notifyListeners();

    _isLoading = true;
    notifyListeners();

    try {
      AttendanceContext? context;
      try {
        context = await ChatbotRepository.instance.getAttendanceContext();
      } catch (e) {
        _appendBotMessage(_errorFirestore);
        _isLoading = false;
        notifyListeners();
        return;
      }

      if (context == null || context.courses.isEmpty) {
        _appendBotMessage(_errorNoEnrollments);
        _isLoading = false;
        notifyListeners();
        return;
      }

      final reply = await OpenAIService.instance.chat(
        userMessage: text,
        contextData: context.rawContextString,
        studentName: context.studentName,
      );

      _appendBotMessage(reply);
    } catch (e) {
      final String message = e is ChatbotException
          ? e.message
          : '$_errorOpenAI\n(التفاصيل: ${e.toString()})';
      _appendBotMessage(message);
      _lastError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _appendBotMessage(String text) {
    _messages.add(ChatMessage(
      id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  void clearChat() {
    _messages.clear();
    _lastError = null;
    _isLoading = false;
    notifyListeners();
  }
}
