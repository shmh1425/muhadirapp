import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class ApiConstants {
  static String get openAiKey =>
      dotenv.env['OPENAI_KEY']?.trim() ?? '';

  static const String openAiChatEndpoint =
      'https://api.openai.com/v1/chat/completions';

  static const String openAiModel = 'gpt-4o';

  static const int openAiMaxTokens = 1000;
}
