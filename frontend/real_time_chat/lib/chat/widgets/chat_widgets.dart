import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/chat_models.dart';
import '../utils/message_content.dart';
import 'voice_message_player.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../services/voice_message_recorder.dart';

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
    this.senderName,
    this.onRetry,
    this.onReply,
  });
  final ChatMessage message;
  final bool isMine;
  final bool showTail;
  final String? senderName;
  final VoidCallback? onRetry;
  final VoidCallback? onReply;
  @override
  Widget build(BuildContext context) {
    final bubbleColor = AppTheme.card(context);
    final borderColor = AppTheme.cardBorder(context);
    final incomingText = AppTheme.textPrimary(context);
    final secondaryText = AppTheme.textSecondary(context);
    final radius = Radius.circular(showTail ? 5 : 18);
    final gifMessage = parseGifMessage(message.content);
    final audioMessage = isAudioMessage(
      messageType: message.messageType,
      content: message.content,
    );
    final visibleSenderName = senderName?.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: message.status == MessageStatus.failed ? onRetry : null,
          onLongPress: onReply,
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
                color: isMine ? null : bubbleColor,
                gradient: isMine ? AppColors.primaryGradient : null,
                border: isMine ? null : Border.all(color: borderColor),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMine ? const Radius.circular(18) : radius,
                  bottomRight: isMine ? radius : const Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (visibleSenderName?.isNotEmpty == true) ...[
                    Text(
                      visibleSenderName!,
                      key: const Key('group-message-sender-name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: AppTheme.primaryLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (message.replyTo != null)
                    ReplyQuotePreview(reply: message.replyTo!, isMine: isMine),
                  if (message.replyTo != null) const SizedBox(height: 7),
                  audioMessage
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              VoiceMessagePlayer(
                                dataUrl: message.content,
                                isMine: isMine,
                              ),
                              const SizedBox(height: 8),
                              _MessageMeta(
                                isMine: isMine,
                                createdAt: message.createdAt,
                                status: message.status,
                                secondaryText: secondaryText,
                              ),
                            ],
                          ),
                        )
                      : gifMessage == null
                      ? Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.end,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                right: 9,
                                bottom: 2,
                              ),
                              child: Text(
                                message.content,
                                style: TextStyle(
                                  fontSize: 15.5,
                                  height: 1.3,
                                  color: isMine
                                      ? AppColors.textPrimary
                                      : incomingText,
                                ),
                              ),
                            ),
                            _MessageMeta(
                              isMine: isMine,
                              createdAt: message.createdAt,
                              status: message.status,
                              secondaryText: secondaryText,
                            ),
                          ],
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: AspectRatio(
                                  aspectRatio: 1.2,
                                  child: Image.network(
                                    gifMessage.url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      color: bubbleColor,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        gifMessage.label,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: incomingText,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                gifMessage.label,
                                style: TextStyle(
                                  color: isMine
                                      ? AppColors.textPrimary.withValues(
                                          alpha: .92,
                                        )
                                      : incomingText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              _MessageMeta(
                                isMine: isMine,
                                createdAt: message.createdAt,
                                status: message.status,
                                secondaryText: secondaryText,
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String replyPreviewText(ReplyMessageInfo reply) => previewTextForMessage(
  content: reply.content,
  messageType: reply.messageType,
);

class ReplyQuotePreview extends StatelessWidget {
  const ReplyQuotePreview({
    super.key,
    required this.reply,
    this.isMine = false,
  });

  final ReplyMessageInfo reply;
  final bool isMine;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
    decoration: BoxDecoration(
      color: (isMine ? Colors.white : AppTheme.primary).withValues(alpha: .12),
      borderRadius: BorderRadius.circular(10),
      border: const Border(left: BorderSide(color: AppTheme.primary, width: 3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          reply.senderName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isMine ? AppColors.textPrimary : AppTheme.primaryLight,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          replyPreviewText(reply),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isMine
                ? AppColors.textPrimary.withValues(alpha: .82)
                : AppTheme.textSecondary(context),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _MessageMeta extends StatelessWidget {
  const _MessageMeta({
    required this.isMine,
    required this.createdAt,
    required this.status,
    required this.secondaryText,
  });

  final bool isMine;
  final DateTime createdAt;
  final MessageStatus status;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        _time(createdAt),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isMine
              ? AppColors.textPrimary.withValues(alpha: .72)
              : secondaryText,
        ),
      ),
      if (isMine)
        Padding(
          padding: const EdgeInsets.only(left: 3),
          child: MessageStatusIcon(status: status),
        ),
    ],
  );
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
      color: read ? AppColors.accentBlue : AppColors.textSecondary,
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
        color: AppTheme.card(context),
        border: Border.all(color: AppTheme.cardBorder(context)),
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
              color: AppTheme.textSecondary(context),
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
    this.replyingTo,
    this.onCancelReply,
  });
  final bool Function(String, {String messageType}) onSend;
  final ValueChanged<String> onChanged;
  final ReplyMessageInfo? replyingTo;
  final VoidCallback? onCancelReply;
  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  VoiceMessageRecorder? _recorder;
  Timer? _recordingTimer;
  bool hasText = false;
  bool _isRecording = false;
  bool _isSendingVoice = false;
  Duration _recordingDuration = Duration.zero;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    unawaited(_recorder?.cancel() ?? Future<void>.value());
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void send() {
    if (!hasText || _isRecording || _isSendingVoice) return;
    final sent = widget.onSend(controller.text, messageType: 'text');
    if (!sent) return;
    controller.clear();
    widget.onChanged('');
    setState(() => hasText = false);
  }

  void _syncInputState() {
    final value = controller.text;
    widget.onChanged(value);
    setState(() => hasText = value.trim().isNotEmpty);
  }

  void _insertText(String value) {
    final selection = controller.selection;
    final text = controller.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final newText = text.replaceRange(start, end, value);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + value.length),
    );
    _syncInputState();
    focusNode.requestFocus();
  }

  void _sendGif(_GifPreset gif) {
    widget.onSend(
      encodeGifMessage(GifMessageContent(label: gif.label, url: gif.url)),
      messageType: 'text',
    );
    focusNode.requestFocus();
  }

  void _showMessage(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  String _recordingClock(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _startVoiceRecording() async {
    if (_isRecording || _isSendingVoice) return;
    if (!voiceMessageRecordingSupported) {
      _showMessage('Bu tarayıcıda ses kaydı desteklenmiyor.');
      return;
    }
    try {
      final recorder = await createVoiceMessageRecorder();
      if (recorder == null) {
        _showMessage('Ses kaydı başlatılamadı.');
        return;
      }
      await recorder.start();
      _recordingTimer?.cancel();
      _recordingDuration = Duration.zero;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordingDuration += const Duration(seconds: 1));
        if (_recordingDuration >= const Duration(minutes: 1)) {
          unawaited(_finishVoiceRecording());
        }
      });
      HapticFeedback.selectionClick();
      setState(() {
        _recorder = recorder;
        _isRecording = true;
      });
    } on Object catch (error) {
      _showMessage('Mikrofon açılamadı: $error');
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    await _recorder?.cancel();
    if (!mounted) return;
    setState(() {
      _recorder = null;
      _isRecording = false;
      _isSendingVoice = false;
      _recordingDuration = Duration.zero;
    });
  }

  Future<void> _finishVoiceRecording() async {
    if (!_isRecording || _isSendingVoice) return;
    final recorder = _recorder;
    if (recorder == null) return;
    _recordingTimer?.cancel();
    setState(() => _isSendingVoice = true);
    try {
      final recorded = await recorder.stop();
      if (!mounted) return;
      final payload = recorded?.dataUrl.trim() ?? '';
      if (payload.isEmpty) {
        _showMessage('Sesli mesaj kaydedilemedi.');
        setState(() {
          _recorder = null;
          _isRecording = false;
          _isSendingVoice = false;
          _recordingDuration = Duration.zero;
        });
        return;
      }
      final sent = widget.onSend(payload, messageType: 'audio');
      if (!sent) _showMessage('Sesli mesaj gönderilemedi.');
    } on Object catch (error) {
      if (mounted) _showMessage('Sesli mesaj gönderilemedi: $error');
    } finally {
      if (mounted) {
        setState(() {
          _recorder = null;
          _isRecording = false;
          _isSendingVoice = false;
          _recordingDuration = Duration.zero;
        });
        focusNode.requestFocus();
      }
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      await _finishVoiceRecording();
      return;
    }
    await _startVoiceRecording();
  }

  Future<void> _openEmojiPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hızlı emojiler',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _emojiPresets.map((emoji) {
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.pop(context);
                    _insertText('$emoji ');
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.headerBg(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGifPicker() async {
    final searchController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final query = searchController.text.trim().toLowerCase();
          final gifs = _gifPresets
              .where(
                (gif) =>
                    query.isEmpty || gif.label.toLowerCase().contains(query),
              )
              .toList();
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GIF seç',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hızlı tepki için bir GIF seç ya da filtrele.',
                  style: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: searchController,
                  onChanged: (_) => setModalState(() {}),
                  decoration: InputDecoration(
                    hintText: 'GIF ara...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppTheme.headerBg(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppTheme.cardBorder(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppTheme.cardBorder(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: gifs.isEmpty
                      ? Center(
                          child: Text(
                            'Bu aramaya uygun GIF bulunamadı.',
                            style: TextStyle(
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                        )
                      : GridView.builder(
                          itemCount: gifs.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.45,
                              ),
                          itemBuilder: (context, index) {
                            final gif = gifs[index];
                            return InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                Navigator.pop(context);
                                _sendGif(gif);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.headerBg(context),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppTheme.cardBorder(context),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      gif.preview,
                                      style: const TextStyle(fontSize: 28),
                                    ),
                                    Text(
                                      gif.label,
                                      style: TextStyle(
                                        color: AppTheme.textPrimary(context),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
    searchController.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.replyingTo != null)
            Container(
              key: const Key('reply-input-preview'),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              decoration: BoxDecoration(
                color: AppTheme.headerBg(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder(context)),
              ),
              child: Row(
                children: [
                  Expanded(child: ReplyQuotePreview(reply: widget.replyingTo!)),
                  IconButton(
                    key: const Key('cancel-reply'),
                    tooltip: 'Yanıtı iptal et',
                    onPressed: widget.onCancelReply,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          if (_isRecording)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.headerBg(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.cardBorder(context)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mic_rounded, color: AppColors.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ses kaydı alınıyor • ${_recordingClock(_recordingDuration)}',
                      style: TextStyle(
                        color: AppTheme.textPrimary(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _cancelVoiceRecording,
                    child: const Text('İptal'),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Focus(
                  onKeyEvent: (_, event) {
                    if (_isRecording || _isSendingVoice) {
                      return KeyEventResult.ignored;
                    }
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    if (event.logicalKey != LogicalKeyboardKey.enter) {
                      return KeyEventResult.ignored;
                    }
                    if (HardwareKeyboard.instance.isShiftPressed) {
                      return KeyEventResult.ignored;
                    }
                    send();
                    return KeyEventResult.handled;
                  },
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 1,
                    readOnly: _isRecording || _isSendingVoice,
                    textInputAction: TextInputAction.send,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.text,
                    onChanged: (value) {
                      widget.onChanged(value);
                      setState(() => hasText = value.trim().isNotEmpty);
                    },
                    onSubmitted: (_) => send(),
                    decoration: InputDecoration(
                      hintText: _isRecording
                          ? 'Kaydı bitirmek için mikrofon düğmesine tekrar dokun…'
                          : 'Mesaj yaz…',
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.input
                          : AppTheme.headerBg(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: BorderSide(
                          color: AppTheme.cardBorder(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: BorderSide(
                          color: AppTheme.cardBorder(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: const BorderSide(color: AppTheme.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _InputActionButton(
                icon: Icons.emoji_emotions_outlined,
                onTap: _openEmojiPicker,
              ),
              const SizedBox(width: 8),
              _InputActionButton(label: 'GIF', onTap: _openGifPicker),
              const SizedBox(width: 8),
              AnimatedScale(
                scale: _isRecording ? 1.03 : 1.0,
                duration: const Duration(milliseconds: 180),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _isRecording
                        ? const LinearGradient(
                            colors: [Color(0xFFF87171), Color(0xFFEF4444)],
                          )
                        : AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    tooltip: hasText
                        ? 'Gönder'
                        : _isRecording
                        ? 'Kaydı bitir ve gönder'
                        : 'Sesli mesaj kaydet',
                    onPressed: _isSendingVoice
                        ? null
                        : (hasText ? send : _toggleVoiceRecording),
                    color: Colors.white,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: _isSendingVoice
                          ? const SizedBox.square(
                              key: ValueKey('voice-loading'),
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Icon(
                              hasText
                                  ? Icons.send_rounded
                                  : (_isRecording
                                        ? Icons.stop_rounded
                                        : Icons.mic_rounded),
                              key: ValueKey(
                                '$hasText-$_isRecording-$_isSendingVoice',
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _InputActionButton extends StatelessWidget {
  const _InputActionButton({this.icon, this.label, required this.onTap});

  final IconData? icon;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.headerBg(context),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: label == null ? 42 : 52,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cardBorder(context)),
        ),
        child: label != null
            ? Text(
                label!,
                style: TextStyle(
                  color: AppTheme.textPrimary(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              )
            : Icon(icon, color: AppTheme.textSecondary(context), size: 20),
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
          color: AppTheme.card(context),
          border: Border.all(color: AppTheme.cardBorder(context)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }
}

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class _GifPreset {
  const _GifPreset({
    required this.label,
    required this.url,
    required this.preview,
  });

  final String label;
  final String url;
  final String preview;
}

const _emojiPresets = [
  '😀',
  '😂',
  '😍',
  '🔥',
  '👏',
  '🥳',
  '🤝',
  '🙌',
  '💜',
  '😎',
];

const _gifPresets = [
  _GifPreset(
    label: 'Kutlama',
    preview: '🥳',
    url: 'https://media.giphy.com/media/3KC2jD2QcBOSc/giphy.gif',
  ),
  _GifPreset(
    label: 'Selam',
    preview: '👋',
    url: 'https://media.giphy.com/media/xT9IgG50Fb7Mi0prBC/giphy.gif',
  ),
  _GifPreset(
    label: 'Onay',
    preview: '✅',
    url: 'https://media.giphy.com/media/111ebonMs90YLu/giphy.gif',
  ),
  _GifPreset(
    label: 'Şaşkın',
    preview: '😮',
    url: 'https://media.giphy.com/media/l3q2K5jinAlChoCLS/giphy.gif',
  ),
];
