import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/token_store.dart';
import '../../config/chat_config.dart';
import '../../network/api_client.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_models.dart';
import '../services/chat_repository.dart';
import '../services/web_socket_service.dart';
import 'chat_list_screen.dart';

class RealChatHome extends StatefulWidget {
  const RealChatHome({super.key, required this.tokens});
  final TokenStore tokens;

  @override
  State<RealChatHome> createState() => _RealChatHomeState();
}

class _RealChatHomeState extends State<RealChatHome> {
  late final AuthenticatedApiClient _client;
  late final ChatRepository _repository;
  List<ChatController> _controllers = const [];
  ChatUser? _currentUser;
  Object? _error;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _client = AuthenticatedApiClient(
      baseUrl: ChatConfig.restBaseUrl,
      tokens: widget.tokens,
    );
    _repository = ChatRepository(_client);
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final currentUser = await _repository.currentUser();
      final conversations = await _repository.conversations();
      final controllers = conversations
          .map((item) => _controllerFor(item, currentUser))
          .toList();
      if (!mounted || generation != _generation) {
        for (final controller in controllers) {
          controller.dispose();
        }
        return;
      }
      final previousControllers = _controllers;
      setState(() {
        _currentUser = currentUser;
        _controllers = controllers;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _disposeControllerList(previousControllers);
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  ChatController _controllerFor(
    Conversation conversation,
    ChatUser currentUser,
  ) {
    final peer =
        conversation.peerFor(currentUser.id) ??
        ChatUser(
          id: -conversation.id,
          username: conversation.name?.trim().isNotEmpty == true
              ? conversation.name!
              : 'Sohbet #${conversation.id}',
        );
    final socket = ContractWebSocketService(
      conversationId: conversation.id,
      baseUrl: ChatConfig.webSocketBaseUrl,
      production: ChatConfig.production,
      accessTokenProvider: widget.tokens.readAccessToken,
      onInvalidToken: _client.refreshAccessToken,
    );
    return ChatController(
      socket: socket,
      currentUser: currentUser,
      peer: peer,
      conversationId: conversation.id,
      repository: _repository,
      initialUpdatedAt: conversation.updatedAt,
      initialMessages: conversation.lastMessage == null
          ? null
          : [conversation.lastMessage!],
    )..initialize();
  }

  void _disposeControllers() {
    _disposeControllerList(_controllers);
  }

  void _disposeControllerList(Iterable<ChatController> controllers) {
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _generation++;
    _disposeControllers();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 54),
                const SizedBox(height: 16),
                Text(
                  'Sohbetler yüklenemedi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('$_error', textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Yeniden dene'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_controllers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sohbetler')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.forum_outlined, size: 58),
              const SizedBox(height: 16),
              const Text('Henüz bir sohbetiniz yok.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final created = await Navigator.of(context)
                      .push<Conversation>(
                        MaterialPageRoute<Conversation>(
                          builder: (_) => ContactPickerScreen(
                            repository: _repository,
                            currentUserId: _currentUser!.id,
                          ),
                        ),
                      );
                  if (created != null) _load();
                },
                icon: const Icon(Icons.add_comment_rounded),
                label: const Text('Yeni sohbet'),
              ),
            ],
          ),
        ),
      );
    }
    return ChangeNotifierProvider.value(
      value: _controllers.first,
      child: ChatListScreen(
        showDemoConversations: false,
        additionalControllers: _controllers.skip(1).toList(),
        repository: _repository,
        currentUserId: _currentUser!.id,
        onConversationsChanged: _load,
      ),
    );
  }
}
