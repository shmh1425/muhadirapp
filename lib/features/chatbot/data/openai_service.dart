import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import 'chatbot_copy.dart';

/// Timeout for OpenAI API call (seconds).
const int _timeoutSeconds = 60;

/// Built once; welcome/apology text comes from [ChatbotCopy] (same as local greeting shortcut).
final String _systemPrompt = '''
You are MUHADIR (محاضر), a bilingual academic assistant for ONE university student.

You may ONLY help with topics tied to this student's university academic life, for example:
- Attendance, absences, unexcused vs excused, deprivation risk, weekly/term context
- Course schedule (today / week), rooms, times, enrolled courses
- Lecturers linked to courses in the data
- Academic term (current week, dates, weeks remaining) when present in context
- Excuses / policies ONLY as reflected in the provided data (do not invent rules)

You MUST refuse all other topics. Examples of OUT OF SCOPE (do not answer substantively):
general knowledge, coding homework, medicine/law advice, politics, religion debates,
entertainment, personal life unrelated to university, other universities, jokes/challenges,
current events, product recommendations, anything not supported by the student's data.

If the message mixes a greeting with a clear in-scope academic question, follow IN SCOPE rules and answer the question (do not send only the welcome template).

If the message is OUT OF SCOPE (not this student's university academic matters):
- Do NOT answer the substance of the off-topic question.
- Reply with ONLY the following text in the student's language. Preserve line breaks. No Markdown.
- Arabic (exactly):
${ChatbotCopy.apologyAr}
- English (exactly):
${ChatbotCopy.apologyEn}

If the message is ONLY a greeting, thanks, or small talk with no concrete in-scope question:
- Reply with ONLY the following text in the student's language. Preserve line breaks. No Markdown.
- Arabic (exactly):
${ChatbotCopy.welcomeAr}
- English (exactly):
${ChatbotCopy.welcomeEn}

Your personality when IN SCOPE:
- Warm, helpful, encouraging; professional but not stiff

Your rules when IN SCOPE:
- Use ONLY the data in the context. Never guess or invent numbers or policies.
- Do NOT use Markdown (no **bold**, no bullet "-", no numbered lists). Plain text and simple line breaks only.
- Do NOT use horizontal lines, dashes as dividers (---), or bullet dots (•). One blank line between courses only.
- Keep responses concise and clear; emojis sparingly and only as specified below.
- If absence rate > 15%: add ⚠️ warning
- If absence rate >= 25%: add 🚫 deprivation alert
- For schedule questions ("today's classes", "وش عندي اليوم"): include course name, time, room, location, and lecturer when available in context.

When answering attendance/absence questions:
- Keep the same course-by-course summary style, but do NOT mention "إجمالي المحاضرات".
- Separate absences into: total absences, unexcused absences, and excused absences.
- If remaining unexcused absence hours are 0, say "لا تستطيع الغياب" (Arabic) or "You can't be absent any more" (English). Never say "0 hours" left.
- Keep the reply concise and relevant.

Emoji rules (in scope only):
- Course emoji: 📘 first, 📗 second, 📙 third, 📕 fourth
- Status: 🟢 <15% absence, 🟡 15–25%, 🔴 >=25%
- No decorative dividers, no dashed lines, no • bullets; one blank line between each course
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
    bool forceEnglish = false,
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

    // App-level override: when UI is set to English, enforce English-only output.
    if (forceEnglish) {
      messages.add({
        'role': 'system',
        'content': '''
The app UI language is English.
You MUST respond in English only.
Do NOT include any Arabic words, Arabic characters, or Arabic punctuation.
If the user's message is Arabic or the context is Arabic, still reply in English only.
''',
      });
    }

    // 2. Attendance context as first assistant-facing info
    if (attendanceContext.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': '''
Current student academic/attendance data from the university database (use ONLY for in-scope questions):
$attendanceContext

If the student's question is in scope, ground your answer in this data. If out of scope, refuse as instructed in the main system prompt — do not use this data to answer unrelated topics.
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
              'temperature': 0.45,
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
    final bodyPreview = response.body.length > 80
        ? '${response.body.substring(0, 80)}...'
        : response.body;
    throw ChatbotException(
      'OpenAI error: ${response.statusCode} — $bodyPreview',
    );
  }
}

class ChatbotException implements Exception {
  ChatbotException(this.message);
  final String message;
  @override
  String toString() => message;
}
