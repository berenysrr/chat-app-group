import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import 'chat_detail_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _searchController = TextEditingController();
  final _authService = AuthService();
  final _chatService = ChatService();

  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  int? _startingChatUserId;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    final results = await _authService.searchUsers(query.trim());
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _startChat(UserModel targetUser) async {
    setState(() => _startingChatUserId = targetUser.id);
    try {
      final conversation = await _chatService.createConversation(
        type: 'private',
        memberIds: [targetUser.id],
      );
      if (!mounted) return;
      if (conversation != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(conversation: conversation),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _startingChatUserId = null);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final leftBg = AppTheme.leftPanelBg(context);
    final textPrimary = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);
    final searchBg = isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5);
    final border = AppTheme.cardBorder(context);

    return Column(
      children: [
        // WhatsApp Web Search Bar Section
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: leftBg,
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: searchBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _performSearch,
              style: TextStyle(color: textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Kullanıcı adı veya e-postaya göre ara...',
                hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: textSecondary,
                  size: 18,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: textSecondary,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
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

        // Body
        Expanded(
          child: _isSearching
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    strokeWidth: 2.5,
                  ),
                )
              : _searchController.text.isEmpty
              ? _buildPromptState(context)
              : _searchResults.isEmpty
              ? _buildNoResults(context)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, i) => Divider(
                    height: 1,
                    indent: 72,
                    color: border.withValues(alpha: 0.7),
                  ),
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    final isStarting = _startingChatUserId == user.id;
                    return _WhatsAppUserTile(
                      user: user,
                      isStarting: isStarting,
                      onChat: () => _startChat(user),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPromptState(BuildContext context) {
    final textPrimary = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_add_rounded,
              size: 48,
              color: AppTheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Yeni Kişiler Keşfet',
              style: TextStyle(
                color: textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sohbet başlatmak için kullanıcı adı ya da e-posta ile arama yap.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults(BuildContext context) {
    final textPrimary = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_rounded, size: 48, color: textSecondary),
            const SizedBox(height: 16),
            Text(
              'Kişi bulunamadı',
              style: TextStyle(
                color: textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Aramanı değiştirip tekrar deneyebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhatsAppUserTile extends StatelessWidget {
  final UserModel user;
  final bool isStarting;
  final VoidCallback onChat;

  const _WhatsAppUserTile({
    required this.user,
    required this.isStarting,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final leftBg = AppTheme.leftPanelBg(context);
    final textPrimary = AppTheme.textPrimary(context);

    return InkWell(
      onTap: isStarting ? null : onChat,
      child: Container(
        color: leftBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user.username.isNotEmpty
                      ? user.username[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // Action Button
            IconButton(
              icon: isStarting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                  : const Icon(Icons.chat_rounded, color: AppTheme.primary),
              onPressed: isStarting ? null : onChat,
            ),
          ],
        ),
      ),
    );
  }
}
