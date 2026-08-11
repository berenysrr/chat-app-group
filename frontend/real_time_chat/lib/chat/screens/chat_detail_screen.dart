import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../models/chat_models.dart';
import '../services/web_socket_service.dart';
import '../utils/chat_timestamp.dart';
import '../widgets/chat_widgets.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    this.showBackButton = true,
    this.showSenderNames = false,
  });

  final bool showBackButton;
  final bool showSenderNames;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with WidgetsBindingObserver {
  final scrollController = ScrollController();
  late final ChatController _controller;
  int previousCount = 0;
  bool showJumpButton = false;
  ChatMessage? _replyingTo;
  @override
  void initState() {
    super.initState();
    _controller = context.read<ChatController>();
    WidgetsBinding.instance.addObserver(this);
    scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.openConversation();
    });
  }

  void _onScroll() {
    final show = scrollController.hasClients && scrollController.offset > 180;
    if (show != showJumpButton) setState(() => showJumpButton = show);
    if (scrollController.hasClients &&
        scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 120) {
      context.read<ChatController>().loadOlderMessages();
    }
  }

  void _jumpDown() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.setAppForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.closeConversation();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final surface = AppTheme.surface(context);
    final border = AppTheme.cardBorder(context);
    final textPrimary = AppTheme.textPrimary(context);
    if (controller.messages.length > previousCount) {
      previousCount = controller.messages.length;
      if (!showJumpButton) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpDown());
      }
    }
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        toolbarHeight: 72,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        shape: Border(bottom: BorderSide(color: border)),
        titleSpacing: widget.showBackButton ? 0 : 8,
        title: Padding(
          padding: EdgeInsets.only(left: widget.showBackButton ? 0 : 6),
          child: Row(
            children: [
              UserAvatar(
                user: controller.peer,
                online: controller.peerIsOnline,
                radius: 19,
                heroTag: 'avatar-${controller.peer.id}',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.peer.username,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _subtitle(controller),
                        key: ValueKey(
                          '${controller.peerIsTyping}-${controller.peerIsOnline}',
                        ),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: _subtitleColor(context, controller),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reconnect') controller.reconnect();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'reconnect',
                child: Text('Bağlantıyı yenile'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          ConnectionBanner(
            connected: controller.connection == SocketConnectionState.connected,
            reconnecting:
                controller.connection == SocketConnectionState.reconnecting,
          ),
          Expanded(
            child: Stack(
              children: [
                if (controller.messages.isEmpty)
                  _EmptyConversationState(
                    onDiscover: () => Navigator.maybePop(context),
                  )
                else
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(.75, -.65),
                        radius: 1.25,
                        colors: Theme.of(context).brightness == Brightness.dark
                            ? const [Color(0xff172044), AppColors.background]
                            : const [Color(0xfff8fbff), Color(0xffe8eef8)],
                      ),
                    ),
                    child: ListView.builder(
                      controller: scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount:
                          controller.messages.length +
                          (controller.isLoadingHistory ? 1 : 0) +
                          (controller.peerIsTyping ? 1 : 0),
                      itemBuilder: (context, reversedIndex) {
                        if (controller.peerIsTyping && reversedIndex == 0) {
                          return const TypingIndicator();
                        }
                        final offset = controller.peerIsTyping ? 1 : 0;
                        if (controller.isLoadingHistory &&
                            reversedIndex ==
                                controller.messages.length + offset) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final index =
                            controller.messages.length -
                            1 -
                            (reversedIndex - offset);
                        final message = controller.messages[index];
                        final next = index + 1 < controller.messages.length
                            ? controller.messages[index + 1]
                            : null;
                        final showTail =
                            next == null ||
                            next.sender.id != message.sender.id ||
                            next.createdAt
                                    .difference(message.createdAt)
                                    .inMinutes >
                                3;
                        final previous = index > 0
                            ? controller.messages[index - 1]
                            : null;
                        final showDate =
                            previous == null ||
                            !_sameDay(previous.createdAt, message.createdAt);
                        return Column(
                          children: [
                            if (showDate)
                              DateSeparator(date: message.createdAt),
                            MessageBubble(
                              key: ValueKey(message.clientMessageId),
                              message: message,
                              isMine: message.isMine(controller.currentUser.id),
                              senderName: senderNameForMessage(
                                message: message,
                                currentUserId: controller.currentUser.id,
                                showSenderNames: widget.showSenderNames,
                              ),
                              showTail: showTail,
                              onReply: message.id == null
                                  ? null
                                  : () => setState(() => _replyingTo = message),
                              onRetry: message.status == MessageStatus.failed
                                  ? () => controller.retryMessage(
                                      message.clientMessageId,
                                    )
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                if (showJumpButton)
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      onPressed: _jumpDown,
                      child: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              border: Border(top: BorderSide(color: border)),
            ),
            child: MessageInput(
              replyingTo: _replyingTo == null
                  ? null
                  : ReplyMessageInfo.fromMessage(_replyingTo!),
              onCancelReply: () => setState(() => _replyingTo = null),
              onSend: (content, {messageType = 'text'}) {
                final sent = controller.send(
                  content,
                  messageType: messageType,
                  replyTo: _replyingTo,
                );
                if (sent) setState(() => _replyingTo = null);
                return sent;
              },
              onChanged: controller.onInputChanged,
            ),
          ),
          if (controller.errorMessage != null)
            MaterialBanner(
              content: Text(controller.errorMessage!),
              actions: [
                TextButton(
                  onPressed: () => controller.reconnect(),
                  child: const Text('Yeniden bağlan'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String? senderNameForMessage({
  required ChatMessage message,
  required int currentUserId,
  required bool showSenderNames,
}) {
  if (!showSenderNames || message.isMine(currentUserId)) return null;
  return message.senderName;
}

String _subtitle(ChatController controller) {
  if (controller.connection == SocketConnectionState.connecting ||
      controller.connection == SocketConnectionState.reconnecting) {
    return 'Bağlantı kuruluyor…';
  }
  if (controller.peerIsTyping) return 'yazıyor…';
  if (controller.peerIsOnline) return 'çevrimiçi';
  if (controller.peerLastSeen != null) {
    return formatLastSeen(controller.peerLastSeen!);
  }
  return 'çevrimdışı';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

Color _subtitleColor(BuildContext context, ChatController controller) {
  if (controller.connection == SocketConnectionState.connecting ||
      controller.connection == SocketConnectionState.reconnecting) {
    return AppColors.warning;
  }
  if (controller.peerIsTyping) return AppColors.secondary;
  if (controller.peerIsOnline) return AppColors.online;
  return AppTheme.textSecondary(context);
}

class _EmptyConversationState extends StatelessWidget {
  const _EmptyConversationState({required this.onDiscover});

  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Henüz mesaj yok',
              style: TextStyle(
                color: textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk mesajı göndererek sohbeti başlatabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
