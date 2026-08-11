import 'dart:async';

import 'package:flutter/material.dart';
import '../auth/token_store.dart';
import '../chat/models/chat_models.dart';
import '../chat/services/web_socket_service.dart';
import '../chat/widgets/chat_widgets.dart';
import '../config/chat_config.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../chat/utils/message_content.dart';
import 'chat_detail_screen.dart';
import 'create_group_dialog.dart';

class ConversationListTab extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;
  final Function(ConversationModel conversation)? onSelectConversation;
  final ConversationModel? selectedConversation;

  const ConversationListTab({
    super.key,
    this.onNavigateTab,
    this.onSelectConversation,
    this.selectedConversation,
  });

  @override
  State<ConversationListTab> createState() => _ConversationListTabState();
}

class _ConversationListTabState extends State<ConversationListTab> {
  final _chatService = ChatService();
  final _authService = AuthService();
  List<ConversationModel> _conversations = [];
  List<ConversationModel> _filteredConversations = [];
  List<UserModel> _userResults = [];
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isSearchingUsers = false;
  int? _startingUserId;
  Timer? _searchDebounce;
  Timer? _refreshTimer;
  final Map<int, ContractWebSocketService> _receiptSockets = {};
  final Map<int, List<StreamSubscription<dynamic>>> _socketSubscriptions = {};
  final Map<int, bool> _liveOnline = {};
  final Map<int, bool> _liveTyping = {};
  final Map<int, Timer> _typingTimeouts = {};
  int _searchRequest = 0;
  final TextEditingController _filterController = TextEditingController();
  int _activeFilterIndex = 0; // 0 = All, 1 = Unread, 2 = Groups

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadConversations(showLoading: false),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _refreshTimer?.cancel();
    for (final subscriptions in _socketSubscriptions.values) {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    }
    for (final timer in _typingTimeouts.values) {
      timer.cancel();
    }
    for (final socket in _receiptSockets.values) {
      unawaited(socket.dispose());
    }
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }
    final profile = _currentUser ?? await _authService.getProfile();
    final list = await _chatService.getConversations();
    list.sort((a, b) {
      final aTime = a.lastMessage?.createdAt ?? a.updatedAt ?? a.createdAt;
      final bTime = b.lastMessage?.createdAt ?? b.updatedAt ?? b.createdAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    if (mounted) {
      setState(() {
        _currentUser = profile;
        _conversations = list;
        _filterConversations(_filterController.text);
        if (showLoading) {
          _isLoading = false;
        }
      });
      _syncReceiptSockets(list);
    }
  }

  void _syncReceiptSockets(List<ConversationModel> conversations) {
    final activeIds = conversations.map((item) => item.id).toSet();
    final removedIds = _receiptSockets.keys
        .where((id) => !activeIds.contains(id))
        .toList();
    for (final id in removedIds) {
      for (final subscription in _socketSubscriptions.remove(id) ?? const []) {
        unawaited(subscription.cancel());
      }
      _typingTimeouts.remove(id)?.cancel();
      _liveOnline.remove(id);
      _liveTyping.remove(id);
      unawaited(_receiptSockets.remove(id)?.dispose());
    }
    for (final conversation in conversations) {
      if (_receiptSockets.containsKey(conversation.id)) continue;
      final socket = ContractWebSocketService(
        conversationId: conversation.id,
        baseUrl: ChatConfig.webSocketBaseUrl,
        production: ChatConfig.production,
        accessTokenProvider: SecureTokenStore().readAccessToken,
      );
      _receiptSockets[conversation.id] = socket;
      _socketSubscriptions[conversation.id] = [
        socket.connectionState.listen(
          (state) => _applyConnectionState(conversation.id, state),
        ),
        socket.listenMessageRead().listen(
          (event) => _applyReadReceipt(conversation.id, event),
        ),
        socket.listenOnline().listen(
          (event) => _applyPresence(conversation, event),
        ),
        socket.listenOffline().listen(
          (event) => _applyPresence(conversation, event),
        ),
        socket.listenTyping().listen(
          (event) => _applyTyping(conversation, event),
        ),
      ];
      unawaited(socket.connect());
    }
  }

  void _applyConnectionState(int conversationId, SocketConnectionState state) {
    if (state != SocketConnectionState.connected || !mounted) return;
    _typingTimeouts.remove(conversationId)?.cancel();
    setState(() {
      _liveOnline.remove(conversationId);
      _liveTyping.remove(conversationId);
    });
  }

  int? _peerIdFor(ConversationModel conversation) {
    final currentUser = _currentUser;
    if (currentUser == null || conversation.type == 'group') return null;
    for (final member in conversation.members) {
      if (member.user.id != currentUser.id) return member.user.id;
    }
    return null;
  }

  void _applyPresence(ConversationModel conversation, PresenceEvent event) {
    if (event.userId != _peerIdFor(conversation) || !mounted) return;
    setState(() {
      _liveOnline[conversation.id] = event.isOnline;
      if (!event.isOnline) {
        _typingTimeouts.remove(conversation.id)?.cancel();
        _liveTyping[conversation.id] = false;
      }
    });
  }

  void _applyTyping(ConversationModel conversation, TypingEvent event) {
    final currentUser = _currentUser;
    final matchesConversation = conversation.type == 'group'
        ? currentUser != null &&
              event.userId != currentUser.id &&
              conversation.members.any(
                (member) => member.user.id == event.userId,
              )
        : event.userId == _peerIdFor(conversation);
    if (!matchesConversation || !mounted) return;
    _typingTimeouts.remove(conversation.id)?.cancel();
    setState(() => _liveTyping[conversation.id] = event.isTyping);
    if (event.isTyping) {
      _typingTimeouts[conversation.id] = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _liveTyping[conversation.id] = false);
      });
    }
  }

  void _applyReadReceipt(int conversationId, ReadEvent event) {
    final index = _conversations.indexWhere(
      (conversation) => conversation.id == conversationId,
    );
    if (index < 0) return;
    final conversation = _conversations[index];
    final currentUser = _currentUser;
    if (currentUser == null) return;
    final updated = applyReadReceiptToConversation(
      conversation,
      messageId: event.messageId,
      currentUserId: currentUser.id,
    );
    if (identical(updated, conversation)) return;
    setState(() {
      _conversations[index] = updated;
      _filterConversations(_filterController.text);
    });
  }

  void _filterConversations(String query) {
    List<ConversationModel> temp = List.from(_conversations);

    if (_activeFilterIndex == 1) {
      temp = temp.where((c) => c.unreadCount > 0).toList();
    }

    if (_activeFilterIndex == 2) {
      temp = temp.where((c) => c.type == 'group').toList();
    }

    if (query.trim().isEmpty) {
      _filteredConversations = temp;
    } else {
      final q = query.toLowerCase().trim();
      _filteredConversations = temp.where((c) {
        final title =
            c.name ??
            (c.members.isNotEmpty ? c.members.first.user.username : '');
        final lastMsg = c.lastMessage == null
            ? ''
            : previewTextForMessage(
                content: c.lastMessage!.content,
                messageType: c.lastMessage!.messageType,
              );
        return title.toLowerCase().contains(q) ||
            lastMsg.toLowerCase().contains(q);
      }).toList();
    }
  }

  void _onSearchChanged(String value) {
    _filterConversations(value);
    final query = value.trim();
    final request = ++_searchRequest;
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      setState(() {
        _userResults = [];
        _isSearchingUsers = false;
      });
      return;
    }
    setState(() => _isSearchingUsers = true);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final users = await _authService.searchUsers(query);
      if (!mounted || request != _searchRequest) return;
      setState(() {
        _userResults = users;
        _isSearchingUsers = false;
      });
    });
  }

  Future<void> _startPrivateChat(UserModel user) async {
    if (_startingUserId != null) return;
    setState(() => _startingUserId = user.id);
    try {
      final conversation = await _chatService.createConversation(
        type: 'private',
        memberIds: [user.id],
      );
      if (!mounted || conversation == null) return;
      await _loadConversations();
      if (mounted) _openChat(conversation);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _startingUserId = null);
    }
  }

  Future<void> _openGroupDialog() async {
    final group = await showDialog<ConversationModel?>(
      context: context,
      builder: (context) => const CreateGroupDialog(),
    );
    if (group != null && mounted) {
      await _loadConversations();
      _openChat(group);
    }
  }

  void _openChat(ConversationModel conversation) {
    if (widget.onSelectConversation != null) {
      widget.onSelectConversation!(conversation);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(conversation: conversation),
        ),
      ).then((_) => _loadConversations());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final leftBg = AppTheme.leftPanelBg(context);
    final border = AppTheme.cardBorder(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);
    final searchBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
          strokeWidth: 2.5,
        ),
      );
    }

    return Column(
      children: [
        // Sleek Search Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: leftBg,
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: searchBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: TextField(
              controller: _filterController,
              onChanged: (val) => _onSearchChanged(val),
              style: TextStyle(color: textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Sohbet veya kişi ara...',
                hintStyle: TextStyle(color: textSecondary, fontSize: 13.5),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: textSecondary,
                  size: 18,
                ),
                suffixIcon: _filterController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: textSecondary,
                        ),
                        onPressed: () {
                          _filterController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: false,
              ),
            ),
          ),
        ),

        // Filter Pills (All / Unread / Groups)
        Container(
          height: 36,
          color: leftBg,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              _buildTechChip('Tümü', 0),
              const SizedBox(width: 6),
              _buildTechChip('Okunmamış', 1),
              const SizedBox(width: 6),
              _buildTechChip('Gruplar', 2),
              const Spacer(),
              IconButton(
                tooltip: 'Yeni grup',
                icon: const Icon(
                  Icons.group_add_rounded,
                  size: 18,
                  color: AppTheme.primary,
                ),
                onPressed: _openGroupDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Sohbetler ve arama sonuçları aynı alan içinde gösterilir.
        Expanded(child: _buildResults(context, border)),
      ],
    );
  }

  Widget _buildResults(BuildContext context, Color border) {
    final hasQuery = _filterController.text.trim().isNotEmpty;
    if (!hasQuery && _conversations.isEmpty) {
      return _buildTechEmptyState(context);
    }
    if (hasQuery && _isSearchingUsers && _filteredConversations.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (hasQuery && _filteredConversations.isEmpty && _userResults.isEmpty) {
      return _buildSearchEmptyState(
        context,
        icon: Icons.search_off_rounded,
        title: 'Sonuç bulunamadı',
        message: 'Farklı bir kullanıcı adı ya da sohbet adı deneyebilirsin.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        for (final conversation in _filteredConversations)
          _SleekConversationTile(
            conversation: widget.selectedConversation?.id == conversation.id
                ? widget.selectedConversation!
                : conversation,
            currentUser: _currentUser,
            liveOnline: _liveOnline[conversation.id],
            liveTyping: _liveTyping[conversation.id] ?? false,
            isSelected: widget.selectedConversation?.id == conversation.id,
            onTap: () => _openChat(conversation),
          ),
        if (hasQuery && _userResults.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Text(
              'Kişiler',
              style: TextStyle(
                color: AppTheme.textSecondary(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final user in _userResults)
            _UserResultTile(
              user: user,
              isStarting: _startingUserId == user.id,
              onTap: () => _startPrivateChat(user),
            ),
        ],
      ],
    );
  }

  Widget _buildTechChip(String label, int index) {
    final isSelected = _activeFilterIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isSelected
        ? AppTheme.primary.withValues(alpha: 0.18)
        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9));
    final textColor = isSelected
        ? AppTheme.primary
        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));
    final border = AppTheme.cardBorder(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilterIndex = index;
          _filterConversations(_filterController.text);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.4)
                : border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTechEmptyState(BuildContext context) {
    final textPrimary = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.forum_outlined, size: 44, color: AppTheme.primary),
            const SizedBox(height: 14),
            Text(
              'Henüz aktif sohbet yok',
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Keşfet sekmesinden kişi bularak yeni bir konuşma başlat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => widget.onNavigateTab?.call(1),
              icon: const Icon(Icons.search_rounded, size: 16),
              label: const Text('Kişileri Keşfet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    final textPrimary = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: AppTheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({
    required this.user,
    required this.isStarting,
    required this.onTap,
  });

  final UserModel user;
  final bool isStarting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: isStarting ? null : onTap,
    leading: CircleAvatar(
      backgroundColor: AppTheme.primary,
      child: Text(
        user.username.isEmpty ? '?' : user.username[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    title: Text(user.username),
    trailing: isStarting
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.chat_bubble_outline_rounded),
  );
}

class _SleekConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final UserModel? currentUser;
  final bool isSelected;
  final bool? liveOnline;
  final bool liveTyping;
  final VoidCallback onTap;

  const _SleekConversationTile({
    required this.conversation,
    required this.currentUser,
    this.liveOnline,
    this.liveTyping = false,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tileBg = isSelected
        ? AppTheme.primary.withValues(alpha: 0.15)
        : AppTheme.leftPanelBg(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);

    final isGroup = conversation.type == 'group';
    final peerMember = _resolvePeerMember();
    final previewUser = peerMember?.user;
    final title =
        conversation.name ??
        (peerMember?.user.username ??
            previewUser?.username ??
            'Sohbet #${conversation.id}');
    final lastMsg = liveTyping
        ? 'yazıyor…'
        : conversation.lastMessage == null
        ? 'Henüz mesaj yok'
        : previewTextForMessage(
            content: conversation.lastMessage!.content,
            messageType: conversation.lastMessage!.messageType,
          );
    final latestActivityAt =
        conversation.lastMessage?.createdAt ??
        conversation.updatedAt ??
        conversation.createdAt;
    final timeStr = latestActivityAt != null
        ? '${latestActivityAt.hour.toString().padLeft(2, '0')}:${latestActivityAt.minute.toString().padLeft(2, '0')}'
        : '';
    final isLastMessageMine =
        currentUser != null &&
        conversation.lastMessage?.sender?.id == currentUser!.id;
    final effectiveUnreadCount = isSelected ? 0 : conversation.unreadCount;
    final lastMessageStatus = (conversation.lastMessage?.readCount ?? 0) > 0
        ? MessageStatus.read
        : MessageStatus.delivered;
    final presenceColor =
        (liveOnline ?? peerMember?.user.isOnline ?? previewUser?.isOnline) ==
            true
        ? AppTheme.onlineGreen
        : AppTheme.offlineRed;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: tileBg,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: isGroup
                        ? AppTheme.accentGradient
                        : AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: isGroup
                        ? const Icon(
                            Icons.group_rounded,
                            color: Colors.white,
                            size: 22,
                          )
                        : Text(
                            title.isNotEmpty ? title[0].toUpperCase() : 'C',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                  ),
                ),
                if (!isGroup)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: presenceColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.leftPanelBg(context),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? AppTheme.primary : textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          if (isLastMessageMine) ...[
                            const SizedBox(width: 3),
                            MessageStatusIcon(status: lastMessageStatus),
                          ] else if (effectiveUnreadCount > 0) ...[
                            const SizedBox(width: 5),
                            _UnreadCountBadge(count: effectiveUnreadCount),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lastMsg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  ConversationMemberModel? _resolvePeerMember() {
    if (conversation.type == 'group' || conversation.members.isEmpty) {
      return null;
    }

    if (currentUser != null) {
      for (final member in conversation.members) {
        if (member.user.id != currentUser!.id) return member;
      }
      for (final member in conversation.members) {
        if (member.user.username != currentUser!.username) return member;
      }
    }

    return conversation.members.length > 1
        ? conversation.members[1]
        : conversation.members.first;
  }
}

class _UnreadCountBadge extends StatelessWidget {
  const _UnreadCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
