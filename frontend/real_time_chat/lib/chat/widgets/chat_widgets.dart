import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_models.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.online = false,
    this.radius = 24,
    this.heroTag,
  });
  final ChatUser user;
  final bool online;
  final double radius;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundImage: user.avatar == null
              ? null
              : NetworkImage(user.avatar!),
          child: user.avatar == null
              ? Text(
                  user.username.characters.first.toUpperCase(),
                  style: TextStyle(
                    fontSize: radius * .72,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xff35c46a),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
    return heroTag == null ? avatar : Hero(tag: heroTag!, child: avatar);
  }
}

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({
    super.key,
    required this.connected,
    required this.reconnecting,
  });
  final bool connected;
  final bool reconnecting;
  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 200),
    child: connected
        ? const SizedBox.shrink()
        : Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Text(
              reconnecting ? 'Bağlantı yeniden kuruluyor…' : 'Bağlantı yok',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
  );
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.showTail,
  });
  final ChatMessage message;
  final bool isMine;
  final bool showTail;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = Radius.circular(showTail ? 5 : 18);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .78,
        ),
        margin: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 2,
          bottom: showTail ? 8 : 1,
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 9, 6),
        decoration: BoxDecoration(
          color: isMine
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMine ? const Radius.circular(18) : radius,
            bottomRight: isMine ? radius : const Radius.circular(18),
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 9, bottom: 2),
              child: Text(
                message.content,
                style: const TextStyle(fontSize: 15.5, height: 1.3),
              ),
            ),
            Text(
              _time(message.createdAt),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (isMine)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: _StatusIcon(status: message.status),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final MessageStatus status;
  @override
  Widget build(BuildContext context) {
    final read = status == MessageStatus.read;
    final icon = switch (status) {
      MessageStatus.pending => Icons.schedule_rounded,
      MessageStatus.sent => Icons.check_rounded,
      MessageStatus.failed => Icons.error_outline_rounded,
      _ => Icons.done_all_rounded,
    };
    return Icon(
      icon,
      size: 15,
      color: read
          ? Colors.blueAccent
          : Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> {
  int active = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 220), (_) {
      if (mounted) setState(() => active = (active + 1) % 3);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6,
            height: index == active ? 10 : 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ),
  );
}

class MessageInput extends StatefulWidget {
  const MessageInput({
    super.key,
    required this.onSend,
    required this.onChanged,
  });
  final ValueChanged<String> onSend;
  final ValueChanged<String> onChanged;
  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final controller = TextEditingController();
  bool hasText = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void send() {
    if (!hasText) return;
    widget.onSend(controller.text);
    controller.clear();
    widget.onChanged('');
    setState(() => hasText = false);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) {
                widget.onChanged(value);
                setState(() => hasText = value.trim().isNotEmpty);
              },
              onSubmitted: (_) => send(),
              decoration: InputDecoration(
                hintText: 'Mesaj yaz…',
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedScale(
            scale: hasText ? 1.0 : .94,
            duration: const Duration(milliseconds: 180),
            child: IconButton.filled(
              onPressed: hasText ? send : null,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  hasText ? Icons.send_rounded : Icons.mic_rounded,
                  key: ValueKey(hasText),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final label = target == today
        ? 'Bugün'
        : target == today.subtract(const Duration(days: 1))
        ? 'Dün'
        : '${date.day}.${date.month}.${date.year}';
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelMedium),
      ),
    );
  }
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
