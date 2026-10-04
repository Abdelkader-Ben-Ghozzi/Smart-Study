// lib/screens/assistant_screen.dart
//
// SmartStudy Assistant — tab index 2 (middle tab).
// Answers ONLY questions about the SmartStudy app itself.
// Uses Claude Sonnet via the Anthropic API with a strict system prompt.
// No external knowledge — only app-scoped help.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../theme/app_colors.dart';

// ── Message model ─────────────────────────────────────────────────────────────
enum _Role { user, assistant }

class _Message {
  final _Role role;
  final String text;
  final DateTime time;

  _Message({required this.role, required this.text, required this.time});
}

// ── System prompt — strictly scoped to SmartStudy ────────────────────────────
const _systemPrompt = '''
You are the SmartStudy Assistant — a helpful guide built into the SmartStudy app.

Your ONLY job is to help users with questions about the SmartStudy app itself.

## What you can help with:
- Account & Auth: creating an account, logging in, logging out, forgot password, OTP verification, remember me
- Profile: editing name/phone/email/avatar, changing password, security settings
- Courses: creating a course (public/private), editing, deleting, adding sources (PDF, DOCX, images)
- AI Tools: generating flashcards, summaries, quiz sets from course sources
- Focus Mode: starting a session, blocking apps, the overlay timer, streaks, permissions needed (overlay + usage stats)
- Stats: understanding the stats screen, activity chart, AI generation counts, focus stats
- Navigation: where to find things in the app (bottom tabs: Home, Courses, Assistant, Focus, Stats/Profile)
- Settings & Permissions: overlay permission, usage stats permission

## App structure (bottom nav tabs):
- Tab 0 — Home: recent decks, subjects, user greeting
- Tab 1 — Courses: list of courses, create/edit/delete, course details with sources and AI tools
- Tab 2 — Assistant: you are here
- Tab 3 — Focus: focus mode switch, session timer, blocked apps, streak
- Tab 4 — Stats / Profile: statistics dashboard + profile screen

## Key app facts:
- Passwords must be 8+ chars, have uppercase, lowercase, and a special char (- * ? @)
- Phone numbers must start with 2, 4, 5, or 9 and be exactly 8 digits
- Forgot password sends OTP to email or phone; OTP expires in 5 minutes, max 10 attempts, max 3 resends
- Courses can be public (visible to others) or private
- AI tools available per course: Flashcards, Summary, Quiz — generated from uploaded sources
- Focus mode requires two Android permissions: "Display over other apps" and "Usage access"
- Focus mode blocks selected apps and shows a countdown bubble on top of all apps
- Abandoning a focus session resets your streak; completing it keeps/grows it
- Sources supported: PDF, DOCX, images

## Rules you MUST follow:
1. ONLY answer questions about SmartStudy. Nothing else.
2. If the user asks about anything unrelated (weather, news, coding help, general knowledge, etc.), politely decline and redirect them to app-related questions.
3. Keep answers concise, friendly, and step-by-step where applicable.
4. Never make up features that don't exist in the app.
5. If you're unsure about a specific detail, say so and suggest where in the app they might find it.
6. Respond in the same language the user writes in (Arabic or French or English).
''';

// ── Quick suggestion chips ────────────────────────────────────────────────────
const _suggestions = [
  'How do I change my password?',
  'How do I create a course?',
  'How do I generate flashcards?',
  'How does focus mode work?',
  'How do I update my profile picture?',
  'What permissions does focus mode need?',
  'How do I reset my streak?',
  'Where can I see my stats?',
];

// ── Screen ────────────────────────────────────────────────────────────────────
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen>
    with SingleTickerProviderStateMixin {
  final List<_Message> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _focus = FocusNode();
  bool _loading = false;
  late AnimationController _typingCtrl;

  @override
  void initState() {
    super.initState();
    _typingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    _typingCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;

    _ctrl.clear();
    setState(() {
      _messages.add(
        _Message(role: _Role.user, text: trimmed, time: DateTime.now()),
      );
      _loading = true;
    });
    _scrollToBottom();

    try {
      // Build conversation history for the API
      final apiMessages = _messages
          .where((m) => m.role == _Role.user || m.role == _Role.assistant)
          .map(
            (m) => {
              'role': m.role == _Role.user ? 'user' : 'assistant',
              'content': m.text,
            },
          )
          .toList();

      final String apiKey =
          '';
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'system_instruction': {
            'parts': {'text': _systemPrompt},
          },

          'contents': apiMessages
              .map(
                (msg) => {
                  'role': msg['role'] == 'assistant' ? 'model' : 'user',
                  'parts': [
                    {'text': msg['content']},
                  ],
                },
              )
              .toList(),
          'generationConfig': {'maxOutputTokens': 1000, 'temperature': 0.7},
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final String reply =
            data['candidates'][0]['content']['parts'][0]['text'];

        setState(() {
          _messages.add(
            _Message(role: _Role.assistant, text: reply, time: DateTime.now()),
          );
          _loading = false;
        });
      } else {
        _showError('API Error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Request Exception:$e');
    }
    _scrollToBottom();
  }

  void _showError(String msg) {
    setState(() {
      _messages.add(
        _Message(role: _Role.assistant, text: msg, time: DateTime.now()),
      );
      _loading = false;
    });
  }

  void _clearChat() {
    setState(() => _messages.clear());
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isEmpty = _messages.isEmpty;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────────────
            _AppBar(colors: c, onClear: _messages.isEmpty ? null : _clearChat),

            // ── Chat area ────────────────────────────────────────────────
            Expanded(
              child: isEmpty
                  ? _EmptyState(colors: c, onSuggestion: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      itemCount: _messages.length + (_loading ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == _messages.length && _loading) {
                          return _TypingBubble(colors: c, ctrl: _typingCtrl);
                        }
                        final msg = _messages[i];
                        return _ChatBubble(message: msg, colors: c);
                      },
                    ),
            ),

            // ── Suggestion chips (only when chat is empty) ───────────────
            if (isEmpty) const SizedBox.shrink(),

            // ── Input bar ────────────────────────────────────────────────
            _InputBar(
              ctrl: _ctrl,
              focus: _focus,
              loading: _loading,
              colors: c,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final AppColorScheme colors;
  final VoidCallback? onClear;

  const _AppBar({required this.colors, this.onClear});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: c.borderDefault, width: 0.5)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: c.primary.withOpacity(0.4), width: 1.5),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: c.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SmartStudy Assistant',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'App help & guidance',
                  style: TextStyle(color: c.subtitle, fontSize: 11),
                ),
              ],
            ),
          ),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.fieldBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: c.borderDefault),
                ),
                child: Icon(
                  Icons.refresh_rounded,
                  color: c.iconDefault,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Empty state with suggestion chips ────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final AppColorScheme colors;
  final void Function(String) onSuggestion;

  const _EmptyState({required this.colors, required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: c.primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: c.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hey! I\'m your SmartStudy guide',
                            style: TextStyle(
                              color: c.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'I can help you with:',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _CapabilityRow(
                  icon: Icons.person_rounded,
                  label: 'Account & profile',
                  colors: c,
                ),
                const SizedBox(height: 6),
                _CapabilityRow(
                  icon: Icons.book_rounded,
                  label: 'Courses & sources',
                  colors: c,
                ),
                const SizedBox(height: 6),
                _CapabilityRow(
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI tools (flashcards, quiz, summary)',
                  colors: c,
                ),
                const SizedBox(height: 6),
                _CapabilityRow(
                  icon: Icons.timer_rounded,
                  label: 'Focus mode & streaks',
                  colors: c,
                ),
                const SizedBox(height: 6),
                _CapabilityRow(
                  icon: Icons.bar_chart_rounded,
                  label: 'Stats & navigation',
                  colors: c,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'QUICK QUESTIONS',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.0,
              color: c.subtitle,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Suggestion chips in a wrap
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((s) {
              return GestureDetector(
                onTap: () => onSuggestion(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.borderDefault),
                  ),
                  child: Text(
                    s,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColorScheme colors;

  const _CapabilityRow({
    required this.icon,
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Row(
      children: [
        Icon(icon, size: 14, color: c.primary),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary)),
      ],
    );
  }
}

// ── Chat bubble ───────────────────────────────────────────────────────────────
class _ChatBubble extends StatelessWidget {
  final _Message message;
  final AppColorScheme colors;

  const _ChatBubble({required this.message, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final isUser = message.role == _Role.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: c.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: c.primary,
                size: 14,
              ),
            ),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: message.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Copied to clipboard'),
                    backgroundColor: c.primary,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                    margin: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isUser ? c.primary : c.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                  border: isUser ? null : Border.all(color: c.borderDefault),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormattedText(
                      text: message.text,
                      color: isUser ? Colors.white : c.text,
                      secondaryColor: isUser ? Colors.white70 : c.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fmtTime(message.time),
                      style: TextStyle(
                        fontSize: 9,
                        color: isUser ? Colors.white54 : c.subtitle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Formatted text — handles bold (**text**) and numbered lists ───────────────
class _FormattedText extends StatelessWidget {
  final String text;
  final Color color;
  final Color secondaryColor;

  const _FormattedText({
    required this.text,
    required this.color,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.asMap().entries.map((e) {
        final line = e.value;
        return Padding(
          padding: EdgeInsets.only(bottom: e.key < lines.length - 1 ? 4 : 0),
          child: _buildLine(line),
        );
      }).toList(),
    );
  }

  Widget _buildLine(String line) {
    // Strip markdown heading #
    if (line.startsWith('## ') || line.startsWith('# ')) {
      final text = line.replaceFirst(RegExp(r'^#+\s'), '');
      return Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    // Bullet points
    if (line.startsWith('- ') || line.startsWith('• ')) {
      final content = line.substring(2);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: color, fontSize: 13)),
          Expanded(child: _buildRichLine(content, color)),
        ],
      );
    }

    // Numbered list
    final numMatch = RegExp(r'^(\d+)\.\s(.+)').firstMatch(line);
    if (numMatch != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${numMatch.group(1)}. ',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(child: _buildRichLine(numMatch.group(2)!, color)),
        ],
      );
    }

    if (line.trim().isEmpty) return const SizedBox(height: 4);

    return _buildRichLine(line, color);
  }

  Widget _buildRichLine(String line, Color textColor) {
    // Parse **bold** segments
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;

    for (final match in regex.allMatches(line)) {
      if (match.start > last) {
        spans.add(
          TextSpan(
            text: line.substring(last, match.start),
            style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      );
      last = match.end;
    }

    if (last < line.length) {
      spans.add(
        TextSpan(
          text: line.substring(last),
          style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────
class _TypingBubble extends StatelessWidget {
  final AppColorScheme colors;
  final AnimationController ctrl;

  const _TypingBubble({required this.colors, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: c.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, color: c.primary, size: 14),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: c.borderDefault),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: ctrl,
                  builder: (_, __) {
                    final delay = i * 0.3;
                    final val = ((ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
                    final opacity = (val < 0.5 ? val * 2 : (1 - val) * 2).clamp(
                      0.3,
                      1.0,
                    );
                    return Container(
                      margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: c.primary.withOpacity(opacity),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool loading;
  final AppColorScheme colors;
  final void Function(String) onSend;

  const _InputBar({
    required this.ctrl,
    required this.focus,
    required this.loading,
    required this.colors,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.borderDefault, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: c.fieldBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.borderDefault),
              ),
              child: TextField(
                controller: ctrl,
                focusNode: focus,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: loading ? null : onSend,
                style: TextStyle(fontSize: 14, color: c.text),
                decoration: InputDecoration(
                  hintText: 'Ask about SmartStudy...',
                  hintStyle: TextStyle(fontSize: 14, color: c.hint),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: loading ? null : () => onSend(ctrl.text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: loading ? c.primary.withOpacity(0.4) : c.primary,
                shape: BoxShape.circle,
              ),
              child: loading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
