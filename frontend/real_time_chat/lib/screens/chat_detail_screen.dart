import 'dart:async';
import 'package:flutter/material.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_theme.dart';

class ChatDetailScreen extends StatefulWidget {
  final ConversationModel conversation;
  final UserModel? currentLoggedInUser;

  const ChatDetailScreen({
    super.key,
    required this.conversation,
    this.currentLoggedInUser,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatService _chatService = ChatService();
  final WebSocketService _wsService = WebSocketService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<MessageModel> _messages = [];
  bool _isLoading = true;
  UserModel? _currentUser;

  StreamSubscription<WebSocketEvent>? _wsSubscription;
  Timer? _typingTimer;
  String? _typingUsername;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    _currentUser = widget.currentLoggedInUser ?? await _authService.getProfile();
    await _loadHistory();
    await _connectWs();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await _chatService.getMessages(widget.conversation.id);
    if (mounted) {
      setState(() {
        _messages = history;
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _connectWs() async {
    await _wsService.connect(widget.conversation.id);
    _wsSubscription = _wsService.events.listen((event) {
      if (!mounted) return;
      switch (event.type) {
        case 'message.new':
          final msg = MessageModel.fromJson(event.data);
          setState(() => _messages.add(msg));
          _scrollToBottom();
          break;
        case 'typing.start':
          final username = event.data['username'] as String? ?? 'Someone';
          final userId = event.data['user_id'];
          if (_currentUser != null && userId != _currentUser!.id) {
            setState(() => _typingUsername = username);
            _resetTypingTimer();
          }
          break;
        case 'typing.stop':
          setState(() => _typingUsername = null);
          break;
      }
    });
  }

  void _resetTypingTimer() {
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _typingUsername = null);
    });
  }

  void _onTextChanged(String text) {
    if (text.trim().isNotEmpty) {
      _wsService.startTyping();
    } else {
      _wsService.stopTyping();
    }
  }

  void _handleSendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    _wsService.stopTyping();
    if (_wsService.isConnected) {
      _wsService.sendMessage(text);
    } else if (_currentUser != null) {
      final localMsg = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch,
        conversationId: widget.conversation.id,
        sender: _currentUser!,
        content: text,
        createdAt: DateTime.now(),
      );
      setState(() => _messages.add(localMsg));
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _wsService.disconnect();
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _getChatTitle() {
    if (widget.conversation.name != null &&
        widget.conversation.name!.isNotEmpty) {
      return widget.conversation.name!;
    }
    if (_currentUser != null) {
      final otherMember = widget.conversation.members.firstWhere(
        (m) => m.user.id != _currentUser!.id,
        orElse: () => widget.conversation.members.isNotEmpty
            ? widget.conversation.members.first
            : ConversationMemberModel(
                id: 0,
                user: UserModel(id: 0, username: 'Chat', email: ''),
                role: 'member',
              ),
      );
      return otherMember.user.username;
    }
    return 'Chat #${widget.conversation.id}';
  }

  @override
  Widget build(BuildContext context) {
    final title = _getChatTitle();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = AppTheme.headerBg(context);
    final chatBg = AppTheme.bg(context);
    final border = AppTheme.cardBorder(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);
    final iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: chatBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          color: headerBg,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SafeArea(
            child: Row(
              children: [
                if (Navigator.canPop(context))
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: iconColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      title.isNotEmpty ? title[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _typingUsername != null
                            ? '$_typingUsername is typing...'
                            : (widget.conversation.type == 'group'
                                ? '${widget.conversation.members.length} members'
                                : '● Online'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _typingUsername != null
                              ? AppTheme.primary
                              : AppTheme.onlineGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        color: chatBg,
        child: Column(
          children: [
            // Messages
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppTheme.primary),
                        strokeWidth: 2.5,
                      ),
                    )
                  : _messages.isEmpty
                      ? Center(
                          child: Text(
                            'No messages in this thread yet.\nType below to start chatting.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = _currentUser != null &&
                                msg.sender.id == _currentUser!.id;
                            return _buildTechBubble(context, msg, isMe);
                          },
                        ),
            ),

            // Input Bar
            Container(
              color: headerBg,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          onChanged: _onTextChanged,
                          onSubmitted: (_) => _handleSendMessage(),
                          maxLines: null,
                          style: TextStyle(color: textPrimary, fontSize: 14.5),
                          decoration: InputDecoration(
                            hintText: 'Write a message...',
                            hintStyle: TextStyle(
                              color: textSecondary,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            filled: false,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _handleSendMessage,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechBubble(BuildContext context, MessageModel msg, bool isMe) {
    final surface = AppTheme.surface(context);
    final border = AppTheme.cardBorder(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);

    final timeStr =
        '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 8,
          left: isMe ? 80 : 0,
          right: isMe ? 0 : 80,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 14),
          ),
          border: isMe ? null : Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg.content,
              style: TextStyle(
                color: isMe ? Colors.white : textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : textSecondary,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.done_all_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
