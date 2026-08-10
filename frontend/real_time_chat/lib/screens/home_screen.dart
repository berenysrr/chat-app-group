import 'package:flutter/material.dart';
import '../models/conversation_model.dart';
import 'conversation_list_tab.dart';
import 'user_search_screen.dart';
import 'profile_screen.dart';
import 'chat_detail_screen.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // 0 = Chats, 1 = Discover, 2 = Profile
  ConversationModel? _activeConversation;

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  void _toggleTheme() {
    final current = AppTheme.themeModeNotifier.value;
    AppTheme.themeModeNotifier.value =
        current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  void _selectConversation(ConversationModel conversation) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    if (isDesktop) {
      setState(() => _activeConversation = conversation);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(conversation: conversation),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget leftPanelContent;
    switch (_currentIndex) {
      case 0:
        leftPanelContent = ConversationListTab(
          onNavigateTab: _onTabSelected,
          onSelectConversation: _selectConversation,
          selectedConversation: _activeConversation,
        );
        break;
      case 1:
        leftPanelContent = const UserSearchScreen();
        break;
      case 2:
      default:
        leftPanelContent = const ProfileScreen();
        break;
    }

    if (!isDesktop) {
      // 📱 Mobile Layout
      return Scaffold(
        backgroundColor: AppTheme.bg(context),
        appBar: AppBar(
          backgroundColor: AppTheme.surface(context),
          title: const Text(
            'Messages',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _currentIndex == 1 ? Icons.chat_bubble_rounded : Icons.search_rounded,
              ),
              onPressed: () => _onTabSelected(_currentIndex == 1 ? 0 : 1),
            ),
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: AppTheme.primary,
              ),
              onPressed: _toggleTheme,
            ),
          ],
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: [
            ConversationListTab(
              onNavigateTab: _onTabSelected,
              onSelectConversation: _selectConversation,
            ),
            const UserSearchScreen(),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: isDark ? AppTheme.offlineGrey : const Color(0xFF64748B),
          backgroundColor: AppTheme.surface(context),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore_rounded),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      );
    }

    // 💻 Floating Modern Desktop Split-Pane View (macOS / iMessage / Modern Web Style)
    final bg = AppTheme.bg(context);
    final surface = AppTheme.surface(context);
    final border = AppTheme.cardBorder(context);

    return Scaffold(
      backgroundColor: bg,
      body: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.dynamicBackgroundGradient(context),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: border.withValues(alpha: 0.8),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // 1. Sidebar Nav + Conversations List (380px wide)
                Container(
                  width: 380,
                  decoration: BoxDecoration(
                    color: surface,
                    border: Border(
                      right: BorderSide(
                        color: border.withValues(alpha: 0.8),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Modern Sidebar Header
                      _buildModernSidebarHeader(context),

                      // Sidebar Main View Content
                      Expanded(child: leftPanelContent),
                    ],
                  ),
                ),

                // 2. Main Chat / Detail Canvas
                Expanded(
                  child: _activeConversation != null
                      ? ChatDetailScreen(
                          key: ValueKey(_activeConversation!.id),
                          conversation: _activeConversation!,
                        )
                      : _buildModernEmptyState(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Modern Sidebar Header
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildModernSidebarHeader(BuildContext context) {
    final border = AppTheme.cardBorder(context);
    final textPrimary = AppTheme.textPrimary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: border.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Brand Logo + Title
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Messages',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          // Header Quick Actions
          Row(
            children: [
              _buildNavPill(
                context: context,
                index: 0,
                icon: Icons.chat_bubble_rounded,
                tooltip: 'Chats',
              ),
              const SizedBox(width: 4),
              _buildNavPill(
                context: context,
                index: 1,
                icon: Icons.person_add_rounded,
                tooltip: 'Discover',
              ),
              const SizedBox(width: 4),
              _buildNavPill(
                context: context,
                index: 2,
                icon: Icons.person_rounded,
                tooltip: 'Profile',
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: isDark ? 'Light Theme' : 'Dark Theme',
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: AppTheme.primary,
                  size: 20,
                ),
                onPressed: _toggleTheme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavPill({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String tooltip,
  }) {
    final isSelected = _currentIndex == index;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => _onTabSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(
              icon,
              color: isSelected
                  ? AppTheme.primary
                  : AppTheme.textSecondary(context),
              size: 19,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Modern Floating Glass Empty Chat State
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildModernEmptyState(BuildContext context) {
    final textPrimary = AppTheme.textPrimary(context);
    final textSecondary = AppTheme.textSecondary(context);

    return Container(
      color: AppTheme.bg(context),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing Glassmorphic Icon Container
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Your Messages',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  'Select a conversation from the sidebar to view messages, or start a new thread.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 14.5,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Start Chat Button
              GestureDetector(
                onTap: () => _onTabSelected(1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Start a New Conversation',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
