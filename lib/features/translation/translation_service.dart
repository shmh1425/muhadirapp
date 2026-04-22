import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';

class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  static final RegExp _arabicRegex = RegExp(r'[\u0600-\u06FF]');

  final Map<String, String> _enCache = <String, String>{};

  bool containsArabic(String text) => _arabicRegex.hasMatch(text);

  /// Translates Arabic -> English. If [text] has no Arabic, returns it unchanged.
  ///
  /// Uses OpenAI Chat Completions (same endpoint used by chatbot feature).
  Future<String> toEnglish(String text) async {
    final raw = text;
    final input = raw.trim();
    if (input.isEmpty) return raw;
    if (!containsArabic(input)) return raw;

    final cached = _enCache[input];
    if (cached != null) return cached;

    final apiKey = ApiConstants.openAiKey.trim();
    if (apiKey.isEmpty ||
        apiKey.toUpperCase().contains('YOUR_KEY_HERE') ||
        !apiKey.startsWith('sk-')) {
      // If key is missing, fail softly (keep original Arabic).
      return raw;
    }

    final prompt = '''
Translate the following Arabic text to English.

Rules:
- If a line is already English, keep it as-is (do NOT translate it again).
- Preserve numbers, IDs, dates, and punctuation exactly.
- Keep the same line breaks.
- Return ONLY the translated text with no extra commentary.

Arabic text:
$input
''';

    http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(ApiConstants.openAiChatEndpoint),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode({
              'model': ApiConstants.openAiModel,
              'temperature': 0.0,
              'max_tokens': 800,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a precise translation engine. Output must be English only.',
                },
                {'role': 'user', 'content': prompt},
              ],
            }),
          )
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      if (kDebugMode) debugPrint('[Translation] request failed: $e');
      return raw;
    }

    if (response.statusCode != 200) {
      if (kDebugMode) {
        debugPrint(
          '[Translation] OpenAI error ${response.statusCode}: ${response.body}',
        );
      }
      return raw;
    }

    try {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = (data['choices'] as List<dynamic>?) ?? const [];
      final first = choices.isNotEmpty ? choices.first : null;
      final message = (first is Map<String, dynamic>) ? first['message'] : null;
      final content =
          (message is Map<String, dynamic>) ? message['content'] : null;
      final out = content?.toString().trim();
      if (out == null || out.isEmpty) return raw;
      _enCache[input] = out;
      return out;
    } catch (e) {
      if (kDebugMode) debugPrint('[Translation] parse failed: $e');
      return raw;
    }
  }
}

