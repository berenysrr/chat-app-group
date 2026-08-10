import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../models/chat_models.dart';
import '../services/web_socket_service.dart';
import '../widgets/chat_widgets.dart';
import 'chat_detail_screen.dart';

enum _ChatFilter { all, unread }

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String _query = '';
  _ChatFilter _filter = _ChatFilter.all;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final allPreviews = _previews(controller);
    final unreadConversations = allPreviews
        .where((item) => item.unreadCount > 0)
        .length;
    final previews = allPreviews.where((preview) {
      final queryMatches =
          preview.user.username.toLowerCase().contains(_query) ||
          preview.lastMessage.toLowerCase().contains(_query);
      final filterMatches =
          _filter == _ChatFilter.all || preview.unreadCount > 0;
      return queryMatches && filterMatches;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sohbetler',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              key: const Key('chat-search'),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Ara veya yeni sohbet başlatın',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'Tümü',
                  selected: _filter == _ChatFilter.all,
                  onSelected: () => setState(() => _filter = _ChatFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Okunmamış ($unreadConversations)',
                  selected: _filter == _ChatFilter.unread,
                  onSelected: () =>
                      setState(() => _filter = _ChatFilter.unread),
                ),
              ],
            ),
          ),
          Expanded(
            child: previews.isEmpty
                ? const _EmptyResults()
                : ListView.builder(
                    itemCount: previews.length,
                    itemBuilder: (context, index) {
                      final preview = previews[index];
                      final active =
                          preview.conversationId == controller.conversationId;
                      return _ChatRow(
                        preview: preview,
                        online: active && controller.peerIsOnline,
                        typing: active && controller.peerIsTyping,
                        onTap: active
                            ? () => _openConversation(controller)
                            : null,
                      );
                    },
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

  Future<void> _openConversation(ChatController controller) async {
    controller.openConversation();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ChatDetailScreen()));
    controller.closeConversation();
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
      unreadCount: controller.unreadCount,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    showCheckmark: false,
  );
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.search_off_rounded,
          size: 40,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 8),
        Text(
          'Eşleşen sohbet bulunamadı',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  );
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
                      _UnreadBadge(
                        conversationId: preview.conversationId,
                        count: preview.unreadCount,
                      ),
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
  const _UnreadBadge({required this.conversationId, required this.count});
  final int conversationId;
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('unread-$conversationId'),
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
