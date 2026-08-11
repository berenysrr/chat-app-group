import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/token_store.dart';
import '../chat/controllers/chat_controller.dart';
import '../chat/models/chat_models.dart';
import '../chat/screens/chat_detail_screen.dart' as contract_chat;
import '../chat/services/chat_repository.dart';
import '../chat/services/web_socket_service.dart';
import '../config/chat_config.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart';
import '../network/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Eski ana arayüzün sohbet ayrıntı sayfası.
/// Görsel akışı korurken mesajlaşma için tek, contract uyumlu WebSocket
/// uygulamasını kullanır.
class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.conversation,
    this.currentLoggedInUser,
    this.showBackButton = true,
    this.onConversationChanged,
  });

  final ConversationModel conversation;
  final UserModel? currentLoggedInUser;
  final bool showBackButton;
  final ValueChanged<ConversationModel>? onConversationChanged;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  late final AuthenticatedApiClient _client;
  late final ChatRepository _repository;
  ChatController? _controller;
  UserModel? _currentProfile;
  Object? _error;
  bool _snapshotQueued = false;

  @override
  void initState() {
    super.initState();
    _client = AuthenticatedApiClient(
      baseUrl: ChatConfig.restBaseUrl,
      tokens: SecureTokenStore(),
    );
    _repository = ChatRepository(_client);
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _error = null);
    try {
      final profile =
          widget.currentLoggedInUser ?? await AuthService().getProfile();
      if (profile == null) {
        throw const FormatException('Oturum bilgisi alınamadı.');
      }
      _currentProfile = profile;
      final currentUser = ChatUser(
        id: profile.id,
        username: profile.username,
        email: profile.email,
        avatar: profile.avatar,
        isOnline: profile.isOnline,
        lastSeen: profile.lastSeen,
      );
      final peer = _peerFor(currentUser);
      final socket = ContractWebSocketService(
        conversationId: widget.conversation.id,
        baseUrl: ChatConfig.webSocketBaseUrl,
        production: ChatConfig.production,
        accessTokenProvider: SecureTokenStore().readAccessToken,
        onInvalidToken: _client.refreshAccessToken,
      );
      final controller = ChatController(
        socket: socket,
        currentUser: currentUser,
        peer: peer,
        conversationId: widget.conversation.id,
        repository: _repository,
        initialUnreadCount: widget.conversation.unreadCount,
        initialUpdatedAt: widget.conversation.updatedAt,
      );
      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.addListener(_emitConversationSnapshot);
      _controller?.dispose();
      setState(() => _controller = controller);
      _emitConversationSnapshot();
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _emitConversationSnapshot() {
    if (_snapshotQueued) return;
    _snapshotQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snapshotQueued = false;
      if (!mounted) return;

      final callback = widget.onConversationChanged;
      final controller = _controller;
      final profile = _currentProfile;
      if (callback == null || controller == null || profile == null) return;

      final lastMessage = controller.messages.isEmpty
          ? null
          : LastMessageModel(
              id: controller.messages.last.id ?? 0,
              content: controller.messages.last.content,
              messageType: controller.messages.last.messageType,
              sender: UserModel(
                id: controller.messages.last.sender.id,
                username: controller.messages.last.sender.username,
                email: controller.messages.last.sender.email ?? '',
                avatar: controller.messages.last.sender.avatar,
                isOnline: controller.messages.last.sender.isOnline,
                lastSeen: controller.messages.last.sender.lastSeen,
              ),
              createdAt: controller.messages.last.createdAt,
              readCount:
                  controller.messages.last.sender.id == profile.id &&
                      controller.messages.last.status == MessageStatus.read
                  ? 1
                  : 0,
              isReadByMe: controller.messages.last.sender.id != profile.id,
            );

      final members = widget.conversation.members.map((member) {
        if (member.user.id == controller.peer.id) {
          return ConversationMemberModel(
            id: member.id,
            role: member.role,
            user: UserModel(
              id: controller.peer.id,
              username: controller.peer.username,
              email: controller.peer.email ?? member.user.email,
              avatar: controller.peer.avatar ?? member.user.avatar,
              isOnline: controller.peerIsOnline,
              lastSeen: controller.peerLastSeen,
            ),
          );
        }
        if (member.user.id == profile.id) {
          return ConversationMemberModel(
            id: member.id,
            role: member.role,
            user: UserModel(
              id: profile.id,
              username: profile.username,
              email: profile.email,
              avatar: profile.avatar,
              isOnline: profile.isOnline,
              lastSeen: profile.lastSeen,
            ),
          );
        }
        return member;
      }).toList();

      callback(
        ConversationModel(
          id: widget.conversation.id,
          type: widget.conversation.type,
          name: widget.conversation.name,
          createdBy: widget.conversation.createdBy,
          members: members,
          lastMessage: lastMessage ?? widget.conversation.lastMessage,
          unreadCount: 0,
          createdAt: widget.conversation.createdAt,
          updatedAt: controller.lastActivityAt,
        ),
      );
    });
  }

  ChatUser _peerFor(ChatUser currentUser) {
    if (widget.conversation.type == 'group') {
      return ChatUser(
        id: -widget.conversation.id,
        username: widget.conversation.name?.trim().isNotEmpty == true
            ? widget.conversation.name!
            : 'Grup sohbeti',
      );
    }
    final member = widget.conversation.members
        .cast<ConversationMemberModel?>()
        .firstWhere(
          (item) => item?.user.id != currentUser.id,
          orElse: () => null,
        );
    if (member == null) {
      return ChatUser(id: -widget.conversation.id, username: 'Sohbet');
    }
    return ChatUser(
      id: member.user.id,
      username: member.user.username,
      email: member.user.email,
      avatar: member.user.avatar,
      isOnline: member.user.isOnline,
      lastSeen: member.user.lastSeen,
    );
  }

  @override
  void dispose() {
    _controller?.removeListener(_emitConversationSnapshot);
    _controller?.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) {
      return ChangeNotifierProvider.value(
        value: controller,
        child: contract_chat.ChatDetailScreen(
          showBackButton: widget.showBackButton,
          showSenderNames: widget.conversation.type == 'group',
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppTheme.bg(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Sohbet açılamadı',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('$_error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _initialize,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Yeniden dene'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
