import 'package:flutter/material.dart';
import '../models/conversation_model.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
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
  List<ConversationModel> _conversations = [];
  List<ConversationModel> _filteredConversations = [];
  bool _isLoading = true;
  final TextEditingController _filterController = TextEditingController();
  int _activeFilterIndex = 0; // 0 = All, 1 = Unread, 2 = Groups

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    final list = await _chatService.getConversations();
    if (mounted) {
      setState(() {
        _conversations = list;
        _filterConversations(_filterController.text);
        _isLoading = false;
      });
    }
  }

  void _filterConversations(String query) {
    List<ConversationModel> temp = List.from(_conversations);

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
        final lastMsg = c.lastMessage?.content ?? '';
        return title.toLowerCase().contains(q) ||
            lastMsg.toLowerCase().contains(q);
      }).toList();
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
              onChanged: (val) => setState(() => _filterConversations(val)),
              style: TextStyle(color: textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Search threads or users...',
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
                          setState(() => _filterConversations(''));
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
              _buildTechChip('All', 0),
              const SizedBox(width: 6),
              _buildTechChip('Unread', 1),
              const SizedBox(width: 6),
              _buildTechChip('Groups', 2),
              const Spacer(),
              IconButton(
                tooltip: 'New Group',
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

        // Threads List
        Expanded(
          child: _conversations.isEmpty
              ? _buildTechEmptyState(context)
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: _filteredConversations.length,
                  separatorBuilder: (context, i) => Divider(
                    height: 1,
                    indent: 70,
                    color: border.withValues(alpha: 0.5),
                  ),
                  itemBuilder: (context, index) {
                    final item = _filteredConversations[index];
                    final isSelected =
                        widget.selectedConversation?.id == item.id;
                    return _SleekConversationTile(
                      conversation: item,
                      isSelected: isSelected,
                      onTap: () => _openChat(item),
                    );
                  },
                ),
        ),
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
              'No active threads',
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start a conversation by finding users in Discover.',
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
              label: const Text('Discover People'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SleekConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final bool isSelected;
  final VoidCallback onTap;

  const _SleekConversationTile({
    required this.conversation,
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
    final title =
        conversation.name ??
        (conversation.members.isNotEmpty
            ? conversation.members.first.user.username
            : 'Chat #${conversation.id}');
    final lastMsg = conversation.lastMessage?.content ?? 'No messages yet';
    final timeStr = conversation.updatedAt != null
        ? '${conversation.updatedAt!.hour.toString().padLeft(2, '0')}:${conversation.updatedAt!.minute.toString().padLeft(2, '0')}'
        : '';

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
                        color: AppTheme.onlineGreen,
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
                      Text(
                        timeStr,
                        style: TextStyle(color: textSecondary, fontSize: 11),
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
}
