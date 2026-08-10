import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../models/chat_models.dart';
import '../services/mock_web_socket_service.dart';
import '../services/web_socket_service.dart';
import '../utils/chat_timestamp.dart';
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
  final Map<int, ChatController> _demoControllers = {};
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final root = context.read<ChatController>();
    final now = DateTime.now();
    _addDemo(
      root,
      const ChatUser(id: 3, username: 'Mert'),
      4,
      'Dosyaları gruba bıraktım.',
      now.subtract(const Duration(hours: 2)),
      unread: 1,
    );
    _addDemo(
      root,
      const ChatUser(id: 4, username: 'Deniz'),
      5,
      'Yarın görüşürüz 👋',
      now.subtract(const Duration(days: 1)),
      sentByMe: true,
    );
  }

  void _addDemo(
    ChatController root,
    ChatUser peer,
    int conversationId,
    String content,
    DateTime createdAt, {
    int unread = 0,
    bool sentByMe = false,
  }) {
    final controller = ChatController(
      socket: MockWebSocketService(
        conversationId: conversationId,
        currentUserId: root.currentUser.id,
        peerId: peer.id,
        peerUsername: peer.username,
        presenceSchedule: peer.id == 3
            ? const [
                MockPresenceStep(delay: Duration(seconds: 1), isOnline: true),
                MockPresenceStep(delay: Duration(seconds: 4), isOnline: false),
              ]
            : const [],
      ),
      currentUser: root.currentUser,
      peer: peer,
      conversationId: conversationId,
      initialMessages: [
        ChatMessage(
          id: conversationId * 10,
          clientMessageId: 'seed-$conversationId',
          conversationId: conversationId,
          sender: sentByMe ? root.currentUser : peer,
          content: content,
          createdAt: createdAt,
          status: sentByMe ? MessageStatus.read : MessageStatus.delivered,
        ),
      ],
      initialUnreadCount: unread,
    );
    controller.addListener(_onDemoChanged);
    _demoControllers[conversationId] = controller;
    controller.initialize();
  }

  void _onDemoChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in _demoControllers.values) {
      controller.removeListener(_onDemoChanged);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    final controllers = [controller, ..._demoControllers.values];
    final allPreviews = controllers.map(_previewFor).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
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
                      final rowController = controllers.firstWhere(
                        (item) => item.conversationId == preview.conversationId,
                      );
                      return _ChatRow(
                        preview: preview,
                        online: rowController.peerIsOnline,
                        typing: rowController.peerIsTyping,
                        onTap: () => _openConversation(rowController),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const _ContactPickerPlaceholder(),
          ),
        ),
        child: const Icon(Icons.chat_rounded),
      ),
    );
  }

  Future<void> _openConversation(ChatController controller) async {
    controller.openConversation();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: controller,
          child: const ChatDetailScreen(),
        ),
      ),
    );
    controller.closeConversation();
  }

  ChatPreview _previewFor(ChatController controller) {
    final message = controller.messages.last;
    return ChatPreview(
      conversationId: controller.conversationId,
      user: controller.peer,
      lastMessage: message.content,
      updatedAt: message.createdAt,
      unreadCount: controller.unreadCount,
      lastMessageIsMine: message.isMine(controller.currentUser.id),
      lastMessageStatus: message.status,
    );
  }
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

class _ContactPickerPlaceholder extends StatelessWidget {
  const _ContactPickerPlaceholder();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yeni sohbet')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Kişi seçme ekranı, kişiler API’si bağlandığında burada gösterilecek.',
          textAlign: TextAlign.center,
        ),
      ),
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
    key: ValueKey('conversation-${preview.conversationId}'),
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
  return formatChatTimestamp(value);
}
