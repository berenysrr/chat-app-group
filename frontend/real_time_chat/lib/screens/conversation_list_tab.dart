import 'package:flutter/material.dart';
import '../models/conversation_model.dart';
import '../services/chat_service.dart';

class ConversationListTab extends StatefulWidget {
  final Function(int tabIndex)? onNavigateTab;
  const ConversationListTab({super.key, this.onNavigateTab});

  @override
  State<ConversationListTab> createState() => _ConversationListTabState();
}

class _ConversationListTabState extends State<ConversationListTab> {
  final _chatService = ChatService();
  List<ConversationModel> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    final list = await _chatService.getConversations();
    if (mounted) {
      setState(() {
        _conversations = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search users to start a conversation',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(1);
                }
              },
              icon: const Icon(Icons.search),
              label: const Text('Find Users'),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _conversations.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final item = _conversations[index];
          final title = item.name ?? (item.members.isNotEmpty ? item.members.first.user.username : 'Chat #${item.id}');
          final lastMsg = item.lastMessage?.content ?? 'No messages yet';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                title.isNotEmpty ? title[0].toUpperCase() : 'C',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              lastMsg,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: item.updatedAt != null
                ? Text(
                    '${item.updatedAt!.hour.toString().padLeft(2, '0')}:${item.updatedAt!.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  )
                : null,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Selected Conversation #${item.id}')),
              );
            },
          );
        },
      ),
    );
  }
}
