import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_models.dart';
import '../../theme/app_colors.dart';

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
    final avatarColor = _avatarColors[user.id.abs() % _avatarColors.length];
    final initials = _initials(user.username);
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(avatarColor, Colors.white, .2)!, avatarColor],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: radius * .68,
            fontWeight: FontWeight.w700,
            color: _foregroundFor(avatarColor),
          ),
        ),
      ),
    );
    final avatar = Stack(
      clipBehavior: Clip.none,
      children: [
        Semantics(
          image: true,
          label: '${user.username} profil resmi',
          child: SizedBox.square(
            key: ValueKey('avatar-${user.id}'),
            dimension: radius * 2,
            child: user.avatar == null || user.avatar!.trim().isEmpty
                ? fallback
                : ClipOval(
                    child: Image.network(
                      user.avatar!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                    ),
                  ),
          ),
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 1,
            child: Container(
              key: ValueKey('online-${user.id}'),
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: AppColors.online,
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

const _avatarColors = <Color>[
  Color(0xff7c9cf5),
  Color(0xff58b88a),
  Color(0xff38b7b0),
  Color(0xff9b7bd3),
  Color(0xffdf7fa5),
  Color(0xffe59a62),
  Color(0xff5977b9),
  Color(0xff69bfa5),
];

String _initials(String username) {
  final parts = username
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

Color _foregroundFor(Color background) => background.computeLuminance() > .48
    ? const Color(0xff183047)
    : Colors.white;

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
            color: reconnecting
                ? AppColors.warning.withValues(alpha: .14)
                : AppColors.error.withValues(alpha: .14),
            child: Text(
              reconnecting ? 'Bağlantı yeniden kuruluyor…' : 'Bağlantı yok',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: reconnecting ? AppColors.warning : AppColors.error,
                fontWeight: FontWeight.w600,
              ),
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
    this.onRetry,
  });
  final ChatMessage message;
  final bool isMine;
  final bool showTail;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(showTail ? 5 : 18);
    return GestureDetector(
      onTap: message.status == MessageStatus.failed ? onRetry : null,
      child: Align(
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
            color: isMine ? null : AppColors.card,
            gradient: isMine ? AppColors.primaryGradient : null,
            border: isMine ? null : Border.all(color: AppColors.border),
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
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.3,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                _time(message.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isMine
                      ? AppColors.textPrimary.withValues(alpha: .72)
                      : AppColors.textMuted,
                ),
              ),
              if (isMine)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: MessageStatusIcon(status: message.status),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageStatusIcon extends StatelessWidget {
  const MessageStatusIcon({super.key, required this.status});
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
      color: read ? const Color(0xff8fc5ff) : AppColors.textSecondary,
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
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
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
              color: AppColors.textSecondary,
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
  final bool Function(String) onSend;
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
    final sent = widget.onSend(controller.text);
    if (!sent) return;
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
                fillColor: AppColors.input,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: const BorderSide(color: AppColors.border),
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
            child: AnimatedOpacity(
              opacity: hasText ? 1 : .45,
              duration: const Duration(milliseconds: 180),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: hasText ? send : null,
                  color: Colors.white,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      hasText ? Icons.send_rounded : Icons.mic_rounded,
                      key: ValueKey(hasText),
                    ),
                  ),
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
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
