import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../models/chat_models.dart';
import '../services/web_socket_service.dart';
import '../widgets/chat_widgets.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final previews = _previews(controller);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sohbetler',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search_rounded)),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded),
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
            child: ListView.builder(
              itemCount: previews.length,
              itemBuilder: (context, index) => _ChatRow(
                preview: previews[index],
                online: index == 0 && controller.peerIsOnline,
                typing: index == 0 && controller.peerIsTyping,
                onTap: index == 0
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ChatDetailScreen(),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.chat_rounded),
      ),
    );
  }

  List<ChatPreview> _previews(ChatController controller) => [
    ChatPreview(
      conversationId: controller.conversationId,
      user: controller.peer,
      lastMessage: controller.messages.isEmpty
          ? ''
          : controller.messages.last.content,
      updatedAt: controller.messages.isEmpty
          ? DateTime.now()
          : controller.messages.last.createdAt,
      unreadCount: 2,
    ),
    ChatPreview(
      conversationId: 4,
      user: const ChatUser(id: 3, username: 'Mert'),
      lastMessage: 'Dosyaları gruba bıraktım.',
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    ChatPreview(
      conversationId: 5,
      user: const ChatUser(id: 4, username: 'Deniz'),
      lastMessage: 'Yarın görüşürüz 👋',
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.preview,
    required this.online,
    required this.typing,
    this.onTap,
  });
  final ChatPreview preview;
  final bool online;
  final bool typing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          UserAvatar(
            user: preview.user,
            online: online,
            heroTag: onTap == null ? null : 'avatar-${preview.user.id}',
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        preview.user.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      _previewTime(preview.updatedAt),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        typing ? 'yazıyor…' : preview.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: typing
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (preview.unreadCount > 0)
                      _UnreadBadge(count: preview.unreadCount),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 8),
    constraints: const BoxConstraints(minWidth: 21, minHeight: 21),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      shape: BoxShape.circle,
    ),
    child: Text(
      '$count',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    ),
  );
}

String _previewTime(DateTime value) {
  final now = DateTime.now();
  return now.difference(value).inDays == 0
      ? '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}'
      : '${value.day}.${value.month}';
}
