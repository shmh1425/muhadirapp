import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../providers/chatbot_provider.dart';

class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({super.key});

  static const Color _primaryColor = Color(0xFF006571);
  static const Color _botBubbleColor = Color(0xFFE8E8E8);
  static const Color _userBubbleColor = Color(0xFF006571);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: ChatbotProvider.instance,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(3.14159),
                child: const Icon(Icons.arrow_back_ios_new, color: _primaryColor),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ChatbotAvatar(size: 36),
                const SizedBox(width: 10),
                const Text(
                  'MUHADIR AI',
                  style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Expanded(
                child: Consumer<ChatbotProvider>(
                  builder: (context, provider, _) {
                    if (provider.messages.isEmpty) {
                      return _EmptyState(
                        onSuggestionTap: provider.sendMessage,
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      reverse: true,
                      itemCount: provider.messages.length +
                          (provider.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (provider.isLoading && index == 0) {
                          return _TypingIndicator();
                        }
                        final msgIndex = provider.isLoading
                            ? provider.messages.length - index
                            : provider.messages.length - 1 - index;
                        final message = provider.messages[msgIndex];
                        return _MessageBubble(message: message);
                      },
                    );
                  },
                ),
              ),
              _InputBar(
                onSend: (text) {
                  ChatbotProvider.instance.sendMessage(text);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggestionTap});

  final void Function(String) onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            'مساعدك الذكي',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'مرحباً! كيف أقدر أساعدك اليوم؟',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _SuggestionChip(
                label: 'سلام 👋',
                onTap: () => onSuggestionTap('سلام 👋'),
              ),
              _SuggestionChip(
                label: 'كم غيابي؟',
                onTap: () => onSuggestionTap('كم غيابي؟'),
              ),
              _SuggestionChip(
                label: 'هل أنا بخطر من الحرمان؟',
                onTap: () => onSuggestionTap('هل أنا بخطر من الحرمان؟'),
              ),
              _SuggestionChip(
                label: 'ملخص كل موادي',
                onTap: () => onSuggestionTap('ملخص كل موادي'),
              ),
              _SuggestionChip(
                label: 'نصيحة للدراسة',
                onTap: () => onSuggestionTap('نصيحة للدراسة'),
              ),
              _SuggestionChip(
                label: 'Hello 👋',
                onTap: () => onSuggestionTap('Hello 👋'),
              ),
              _SuggestionChip(
                label: 'How many absences do I have?',
                onTap: () => onSuggestionTap('How many absences do I have?'),
              ),
              _SuggestionChip(
                label: 'Am I at risk of deprivation?',
                onTap: () => onSuggestionTap('Am I at risk of deprivation?'),
              ),
              _SuggestionChip(
                label: 'Summary of all my courses',
                onTap: () => onSuggestionTap('Summary of all my courses'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: ChatbotScreen._primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: ChatbotScreen._primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: ChatbotScreen._primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _BotAvatar(),
          if (!isUser) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? ChatbotScreen._userBubbleColor
                        : ChatbotScreen._botBubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: SelectableText(
                    message.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isUser ? Colors.white : Colors.black87,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser) const SizedBox(width: 36),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    final hour = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final ampm = t.hour >= 12 ? 'م' : 'ص';
    final min = t.minute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }
}

/// الهوية البصرية: دائرة تيل + فقاعة + روبوت (صورة بخلفية شفافة).
class _ChatbotAvatar extends StatelessWidget {
  const _ChatbotAvatar({this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/chatbot_icon.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => CircleAvatar(
          backgroundColor: ChatbotScreen._primaryColor,
          child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: size * 0.55),
        ),
      ),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _ChatbotAvatar(size: 36);
  }
}

class _TypingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _BotAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ChatbotScreen._botBubbleColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final value = ((_controller.value - delay) % 1.0).clamp(0.0, 1.0);
            final scale = 0.6 + 0.4 * (0.5 + 0.5 * (value < 0.5 ? value * 2 : 2 - value * 2));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _InputBar extends StatefulWidget {
  const _InputBar({required this.onSend});

  final void Function(String) onSend;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: Colors.grey[600],
              size: 28,
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'اكتب رسالتك...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: ChatbotScreen._primaryColor,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: _send,
              borderRadius: BorderRadius.circular(24),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
