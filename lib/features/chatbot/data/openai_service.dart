import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';

/// Timeout for OpenAI API call (seconds).
const int _timeoutSeconds = 60;

const String _systemPrompt = r'''
You are MUHADIR (محاضر), a smart bilingual academic assistant.

You have access to the student's complete academic data including:
- Personal profile (name, university ID, major)
- Current semester info (which week we are in, how many weeks left)
- Full course schedule (today's classes, all enrolled courses)
- Lecturer information for each course
- Complete attendance records

Your personality:
- Warm, helpful, and encouraging
- Professional but not stiff
- Like a helpful senior student who knows everything about the university

Your rules:
- Always respond in the SAME language the student used
  (Arabic → reply Arabic, English → reply English)
- Use ONLY the data provided to you in the context. Never guess or invent numbers.
- Answer ANY student question using this data (profile, schedule, lecturers, term, attendance).
- Do NOT use Markdown formatting at all (no **bold**, no bullet \"-\", no numbered lists). Write plain text sentences and simple line breaks فقط.
- For greetings: respond warmly and offer help
- Keep responses concise and clear
- Use emojis naturally (not excessively)
- If absence rate > 15%: add ⚠️ warning
- If absence rate >= 25%: add 🚫 deprivation alert
- For schedule questions (\"today's classes\", \"وش عندي اليوم\"): always include course name, time, room, location, and lecturer.

Response style rules:
- Use a professional, warm, and academic tone
- Minimize emojis — use ONE only when truly needed, never more
- Do not use decorative dividers like ──────────
- Write attendance summaries in clean structured text, not decorated boxes
- Sound like an official academic advisor, not a chatbot
- Keep responses concise and direct
- For attendance data use this clean format:

Arabic format:
[اسم المادة]
إجمالي المحاضرات: X | الغياب: X | بعذر: X
نسبة الغياب: X% — متبقي قبل الحرمان: X محاضرات
الحالة: [جملة واحدة واضحة]

English format:
[Course Name]
Total: X lectures | Absences: X | Excused: X
Absence Rate: X% — Remaining: X lectures
Status: [one clear sentence]

- If multiple courses, separate them with a single blank line
- End with one short sentence summarizing the overall status
- No excessive praise or filler phrases like "استمر على هذا المنوال"
''';

/// Calls OpenAI Chat Completions API (GPT-4o) with system prompt, attendance context, and chat history.
class OpenAIService {
  OpenAIService._();
  static final OpenAIService instance = OpenAIService._();

  String get _apiKey => ApiConstants.openAiKey.trim();

  /// Sends a message to OpenAI with attendance context and conversation history.
  /// Returns the assistant reply or throws on error.
  Future<String> sendMessage({
    required String userMessage,
    required String attendanceContext,
    required List<Map<String, String>> chatHistory,
  }) async {
    if (_apiKey.isEmpty ||
        _apiKey.toUpperCase().contains('YOUR_KEY_HERE') ||
        !_apiKey.startsWith('sk-')) {
      throw ChatbotException(
        'مفتاح OpenAI غير مضبوط. انسخ .env.example إلى .env وضع مفتاحك في OPENAI_KEY ثم أعد تشغيل التطبيق (Stop ثم Run وليس Hot Reload).',
      );
    }

    final List<Map<String, dynamic>> messages = [];

    // 1. System prompt (personality + rules)
    messages.add({'role': 'system', 'content': _systemPrompt});

    // 2. Attendance context as first assistant-facing info
    if (attendanceContext.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': '''
Current student attendance data from the university database:
$attendanceContext

Use this data when answering attendance-related questions.
For other questions, respond naturally without mentioning this data.
'''
      });
    }

    // 3. Chat history (last 10 messages for memory)
    final recentHistory = chatHistory.length > 10
        ? chatHistory.sublist(chatHistory.length - 10)
        : chatHistory;
    messages.addAll(recentHistory.map((m) => {
          'role': m['role']!,
          'content': m['content']!,
        }));

    // 4. Current user message
    messages.add({'role': 'user', 'content': userMessage});

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(ApiConstants.openAiChatEndpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'model': ApiConstants.openAiModel,
              'max_tokens': ApiConstants.openAiMaxTokens,
              'temperature': 0.7,
              'messages': messages,
            }),
          )
          .timeout(const Duration(seconds: _timeoutSeconds));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('SocketException') ||
          msg.contains('Failed host lookup') ||
          msg.contains('Connection')) {
        throw ChatbotException(
          'لا يوجد اتصال بالإنترنت. تحقق من الشبكة أو جرّب شبكة أخرى.',
        );
      }
      if (msg.contains('TimeoutException') || msg.contains('timeout')) {
        throw ChatbotException('انتهت مهلة الاتصال. جرّب مرة أخرى.');
      }
      rethrow;
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw ChatbotException('لم يرد الخادم برد صحيح. جرّب مرة أخرى.');
      }
      final first = choices.first;
      if (first is! Map<String, dynamic>) {
        throw ChatbotException('صيغة الرد خاطئة.');
      }
      final messageMap = first['message'];
      if (messageMap is! Map<String, dynamic>) {
        throw ChatbotException('لم يرد الخادم بنص.');
      }
      final content = messageMap['content']?.toString().trim();
      if (content == null || content.isEmpty) {
        throw ChatbotException('لم يرد الخادم بنص.');
      }
      return content;
    }

    if (response.statusCode == 401) {
      throw ChatbotException(
        'مفتاح API غير صحيح أو منتهي. تحقق من المفتاح في api_constants.dart',
      );
    }
    if (response.statusCode == 429) {
      throw ChatbotException(
        'تجاوز حد الاستخدام أو انتهى الرصيد. تحقق من حساب OpenAI.',
      );
    }
    throw ChatbotException(
      'OpenAI error: ${response.statusCode} — ${response.body.length > 80 ? response.body.substring(0, 80) + '...' : response.body}',
    );
  }
}

class ChatbotException implements Exception {
  ChatbotException(this.message);
  final String message;
  @override
  String toString() => message;
}
