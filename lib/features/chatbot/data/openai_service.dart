import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../models/attendance_context.dart';

/// Timeout for OpenAI API call (seconds).
const int _timeoutSeconds = 60;

const String _systemPrompt = '''
You are MUHADIR, a smart and friendly bilingual academic assistant for a Saudi university app.

Rules:
- Always respond in the same language the student used (Arabic or English)
- Never invent or guess numbers — only use the data provided to you
- Be concise, warm, and clear
- If absence rate > 15%, add ⚠️ warning
- If absence rate > 25%, add 🚫 deprivation alert
- Format responses clearly with emojis and line breaks

When showing attendance for a course, always use this format:

Arabic format:
مادة: [اسم المادة]
──────────────────
📚 إجمالي المحاضرات: X
❌ غياب بدون عذر: X
✅ غياب بعذر: X
📊 نسبة الغياب: X%
[⚠️ or 🚫 or ✅] الحالة: [رسالة مناسبة]
📌 متبقي قبل الحرمان: X محاضرة

English format:
Course: [Course Name]
──────────────────────
📚 Total Lectures: X
❌ Unexcused Absences: X
✅ Excused Absences: X
📊 Absence Rate: X%
[⚠️ or 🚫 or ✅] Status: [appropriate message]
📌 Remaining Before Deprivation: X lectures
''';

/// Calls OpenAI Chat Completions API with attendance context.
class OpenAIService {
  OpenAIService._();
  static final OpenAIService instance = OpenAIService._();

  String get _apiKey => ApiConstants.openAiKey.trim();
  final String _endpoint = ApiConstants.openAiChatEndpoint;
  final String _model = ApiConstants.openAiModel;
  final int _maxTokens = ApiConstants.openAiMaxTokens;

  /// Returns the assistant reply or throws ChatbotException on error.
  Future<String> chat({
    required String userMessage,
    required String contextData,
    String? studentName,
  }) async {
    try {
      return await _chatImpl(
        userMessage: userMessage,
        contextData: contextData,
        studentName: studentName,
      );
    } catch (e) {
      if (e is ChatbotException) rethrow;
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('Failed host lookup') || msg.contains('Connection') || msg.contains('connection')) {
        throw ChatbotException('لا يوجد اتصال بالإنترنت. تحقق من الشبكة أو جرّب شبكة أخرى.');
      }
      if (msg.contains('TimeoutException') || msg.contains('timeout')) {
        throw ChatbotException('انتهت مهلة الاتصال. جرّب مرة أخرى.');
      }
      if (msg.contains('HandshakeException') || msg.contains('TlsException') || msg.contains('Certificate')) {
        throw ChatbotException('خطأ أمان الاتصال (TLS). جرّب شبكة أخرى أو تحديث الجهاز.');
      }
      throw ChatbotException('خطأ: ${msg.length > 120 ? msg.substring(0, 120) + '...' : msg}');
    }
  }

  Future<String> _chatImpl({
    required String userMessage,
    required String contextData,
    String? studentName,
  }) async {
    final key = _apiKey;
    if (key.isEmpty || key.toUpperCase().contains('YOUR_KEY_HERE') || !key.startsWith('sk-')) {
      throw ChatbotException('المفتاح غير مضبوط. تأكد من وضع OpenAI API key في lib/core/constants/api_constants.dart ثم أعد تشغيل التطبيق (لا Hot Reload).');
    }

    final contextBlock = '''
Current student: ${studentName ?? 'Unknown'}
Attendance data (use ONLY these numbers):
$contextData
''';

    final body = <String, dynamic>{
      'model': _model,
      'max_tokens': _maxTokens,
      'messages': [
        <String, String>{'role': 'system', 'content': _systemPrompt + '\n\n' + contextBlock},
        <String, String>{'role': 'user', 'content': userMessage},
      ],
    };

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: _timeoutSeconds));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') || msg.contains('Failed host lookup') || msg.contains('Connection')) {
        throw ChatbotException('لا يوجد اتصال بالإنترنت. تحقق من الشبكة.');
      }
      if (msg.contains('TimeoutException') || msg.contains('timeout')) {
        throw ChatbotException('انتهت مهلة الاتصال. جرّب مرة أخرى.');
      }
      throw ChatbotException('اتصال: $msg');
    }

    if (response.statusCode != 200) {
      String errMsg = response.body;
      try {
        final map = jsonDecode(response.body) as Map<String, dynamic>?;
        final error = map?['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message']?.toString();
          if (message != null && message.isNotEmpty) errMsg = message;
        }
      } catch (_) {}
      if (response.statusCode == 401) {
        throw ChatbotException('مفتاح API غير صحيح أو منتهي. تحقق من المفتاح في api_constants.dart');
      }
      if (response.statusCode == 429) {
        throw ChatbotException('تجاوز حد الاستخدام أو انتهى الرصيد. تحقق من حساب OpenAI.');
      }
      throw ChatbotException('خطأ من الخادم ($errMsg)');
    }

    Map<String, dynamic> map;
    try {
      map = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw ChatbotException('رد غير صحيح من الخادم. جرّب لاحقاً.');
    }

    final choices = map['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw ChatbotException('لم يرد الخادم برد صحيح. جرّب مرة أخرى.');
    }

    final first = choices.first;
    if (first is! Map<String, dynamic>) throw ChatbotException('صيغة الرد خاطئة.');
    final messageMap = first['message'];
    if (messageMap is! Map<String, dynamic>) throw ChatbotException('لم يرد الخادم بنص.');
    final content = messageMap['content'];
    if (content == null) throw ChatbotException('لم يرد الخادم بنص.');
    return content.toString().trim();
  }
}

class ChatbotException implements Exception {
  ChatbotException(this.message);
  final String message;
  @override
  String toString() => message;
}
