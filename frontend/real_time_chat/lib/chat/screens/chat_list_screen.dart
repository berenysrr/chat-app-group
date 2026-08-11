import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../models/chat_models.dart';
import '../services/mock_web_socket_service.dart';
import '../services/chat_repository.dart';
import '../services/web_socket_service.dart';
import '../utils/message_content.dart';
import '../utils/chat_timestamp.dart';
import '../widgets/chat_widgets.dart';
import '../../theme/app_colors.dart';
import 'chat_detail_screen.dart';

enum _ChatFilter { all, unread }

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({
    super.key,
    required this.showDemoConversations,
    this.additionalControllers = const [],
    this.repository,
    this.currentUserId,
    this.onConversationsChanged,
  });
  final bool showDemoConversations;
  final List<ChatController> additionalControllers;
  final ChatRepository? repository;
  final int? currentUserId;
  final VoidCallback? onConversationsChanged;
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String _query = '';
  _ChatFilter _filter = _ChatFilter.all;
  final Map<int, ChatController> _demoControllers = {};
  bool _initialized = false;
  ChatController? _selectedController;

  void _listenToExternalControllers(Iterable<ChatController> controllers) {
    for (final controller in controllers) {
      controller.addListener(_onExternalChanged);
    }
  }

  void _unlistenFromExternalControllers(Iterable<ChatController> controllers) {
    for (final controller in controllers) {
      controller.removeListener(_onExternalChanged);
    }
  }

  void _onExternalChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _listenToExternalControllers(widget.additionalControllers);
    if (!widget.showDemoConversations) return;
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

  @override
  void didUpdateWidget(covariant ChatListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameControllers(
      oldWidget.additionalControllers,
      widget.additionalControllers,
    )) {
      _unlistenFromExternalControllers(oldWidget.additionalControllers);
      _listenToExternalControllers(widget.additionalControllers);
      _selectedController?.closeConversation();
      _selectedController = null;
    }
  }

  bool _sameControllers(List<ChatController> a, List<ChatController> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (!identical(a[index], b[index])) return false;
    }
    return true;
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
    _unlistenFromExternalControllers(widget.additionalControllers);
    _selectedController?.closeConversation();
    for (final controller in _demoControllers.values) {
      controller.removeListener(_onDemoChanged);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final controller = context.watch<ChatController>();
    final controllers = [
      controller,
      ...widget.additionalControllers,
      ..._demoControllers.values,
    ];
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

    final listPane = Scaffold(
      backgroundColor: AppColors.sidebar,
      appBar: AppBar(
        backgroundColor: AppColors.sidebar,
        toolbarHeight: 72,
        titleSpacing: 20,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 14, bottom: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        title: const Text(
          'Sohbetler',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -.6,
          ),
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
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
            child: TextField(
              key: const Key('chat-search'),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Ara veya yeni sohbet başlatın',
                prefixIcon: const Icon(Icons.search_rounded),
                prefixIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                filled: true,
                fillColor: AppColors.input,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
          SizedBox(
            height: 48,
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
                    padding: const EdgeInsets.only(top: 4, bottom: 92),
                    itemCount: previews.length,
                    itemBuilder: (context, index) {
                      final preview = previews[index];
                      final rowController = controllers.firstWhere(
                        (item) => item.conversationId == preview.conversationId,
                      );
                      return _ChatRow(
                        preview: preview,
                        selected:
                            isWide && _selectedController == rowController,
                        enableHero: !isWide,
                        online: rowController.peerIsOnline,
                        typing: rowController.peerIsTyping,
                        onTap: () => _openConversation(
                          rowController,
                          showInline: isWide,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Yeni sohbet',
        onPressed: () async {
          if (widget.repository == null || widget.currentUserId == null) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _ContactPickerPlaceholder(),
              ),
            );
            return;
          }
          final created = await Navigator.of(context).push<Conversation>(
            MaterialPageRoute<Conversation>(
              builder: (_) => ContactPickerScreen(
                repository: widget.repository!,
                currentUserId: widget.currentUserId!,
              ),
            ),
          );
          if (created != null) widget.onConversationsChanged?.call();
        },
        child: const Icon(Icons.chat_rounded),
      ),
    );
    if (!isWide) return listPane;
    final sidebarWidth = (MediaQuery.sizeOf(context).width * .3)
        .clamp(320.0, 420.0)
        .toDouble();
    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: sidebarWidth, child: listPane),
          const VerticalDivider(width: 1),
          Expanded(
            child: _selectedController == null
                ? const _DesktopEmptyState()
                : ChangeNotifierProvider.value(
                    value: _selectedController!,
                    child: const ChatDetailScreen(showBackButton: false),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openConversation(
    ChatController controller, {
    required bool showInline,
  }) async {
    if (showInline) {
      if (_selectedController != controller) {
        _selectedController?.closeConversation();
        controller.openConversation();
        setState(() => _selectedController = controller);
      }
      return;
    }
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
    final message = controller.messages.lastOrNull;
    return ChatPreview(
      conversationId: controller.conversationId,
      user: controller.peer,
      lastMessage: message == null
          ? 'Henüz mesaj yok'
          : previewTextForMessage(
              content: message.content,
              messageType: message.messageType,
            ),
      updatedAt: controller.lastActivityAt,
      unreadCount: controller.unreadCount,
      lastMessageIsMine: message?.isMine(controller.currentUser.id) ?? false,
      lastMessageStatus: message?.status ?? MessageStatus.delivered,
    );
  }
}

class ContactPickerScreen extends StatefulWidget {
  const ContactPickerScreen({
    super.key,
    required this.repository,
    required this.currentUserId,
  });
  final ChatRepository repository;
  final int currentUserId;

  @override
  State<ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<ContactPickerScreen> {
  Timer? _debounce;
  int _requestSerial = 0;
  List<ChatUser> _users = const [];
  bool _loading = false;
  int? _creatingUserId;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    final query = value.trim();
    final serial = ++_requestSerial;
    if (query.isEmpty) {
      setState(() {
        _users = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final users = await widget.repository.searchUsers(query);
        if (!mounted || serial != _requestSerial) return;
        setState(() {
          _users = users
              .where((user) => user.id != widget.currentUserId)
              .toList();
          _loading = false;
        });
      } on Object catch (error) {
        if (!mounted || serial != _requestSerial) return;
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    });
  }

  Future<void> _create(ChatUser user) async {
    if (_creatingUserId != null) return;
    setState(() => _creatingUserId = user.id);
    try {
      final conversation = await widget.repository.createPrivateConversation(
        user.id,
      );
      if (mounted) Navigator.of(context).pop(conversation);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _creatingUserId = null;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yeni sohbet')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            autofocus: true,
            onChanged: _search,
            decoration: const InputDecoration(
              hintText: 'Kullanıcı ara',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        Expanded(
          child: _users.isEmpty && !_loading
              ? const Center(
                  child: Text('Aramak için bir kullanıcı adı yazın.'),
                )
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return ListTile(
                      leading: UserAvatar(user: user, online: user.isOnline),
                      title: Text(user.username),
                      trailing: _creatingUserId == user.id
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () => _create(user),
                    );
                  },
                ),
        ),
      ],
    ),
  );
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
    labelStyle: TextStyle(
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      color: selected
          ? Theme.of(context).colorScheme.onPrimaryContainer
          : Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    backgroundColor: Theme.of(context).colorScheme.surface,
    selectedColor: Theme.of(context).colorScheme.primaryContainer,
    side: BorderSide(
      color: selected
          ? Colors.transparent
          : Theme.of(context).colorScheme.outlineVariant,
    ),
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
  );
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.search_off_rounded,
            size: 34,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Eşleşen sohbet bulunamadı',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Farklı bir ad veya mesaj aramayı deneyin.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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

class _DesktopEmptyState extends StatelessWidget {
  const _DesktopEmptyState();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(.1, -.2),
        radius: 1.1,
        colors: [Color(0xff19234a), AppColors.background],
      ),
    ),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: .25),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Mesajların',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Mesajları görüntülemek için soldan bir sohbet seçin veya yeni bir sohbet başlatın.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.preview,
    required this.selected,
    required this.enableHero,
    required this.online,
    required this.typing,
    this.onTap,
  });
  final ChatPreview preview;
  final bool selected;
  final bool enableHero;
  final bool online;
  final bool typing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    child: Material(
      color: selected
          ? AppColors.primary.withValues(alpha: .16)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('conversation-${preview.conversationId}'),
        onTap: onTap,
        hoverColor: AppColors.accentBlue.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              UserAvatar(
                user: preview.user,
                online: online,
                radius: 27,
                heroTag: enableHero && onTap != null
                    ? 'avatar-${preview.user.id}'
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview.user.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: preview.unreadCount > 0
                            ? FontWeight.w800
                            : FontWeight.w700,
                        fontSize: 16.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      typing ? 'yazıyor…' : preview.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: preview.unreadCount > 0
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: typing
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 68,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _previewTime(preview.updatedAt),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: preview.unreadCount > 0
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: preview.unreadCount > 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (preview.unreadCount > 0)
                      _UnreadBadge(
                        conversationId: preview.conversationId,
                        count: preview.unreadCount,
                      )
                    else if (preview.lastMessageIsMine &&
                        preview.lastMessageStatus == MessageStatus.read)
                      const Icon(
                        Icons.done_all_rounded,
                        size: 16,
                        color: AppColors.online,
                      )
                    else
                      const SizedBox(height: 21),
                  ],
                ),
              ),
            ],
          ),
        ),
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
