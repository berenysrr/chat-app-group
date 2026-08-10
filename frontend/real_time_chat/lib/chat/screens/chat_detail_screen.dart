import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../services/web_socket_service.dart';
import '../widgets/chat_widgets.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({super.key});
  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final scrollController = ScrollController();
  int previousCount = 0;
  bool showJumpButton = false;
  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final show = scrollController.hasClients && scrollController.offset > 180;
    if (show != showJumpButton) setState(() => showJumpButton = show);
  }

  void _jumpDown() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    if (controller.messages.length > previousCount) {
      previousCount = controller.messages.length;
      if (!showJumpButton) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpDown());
      }
    }
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(
              user: controller.peer,
              online: controller.peerIsOnline,
              radius: 19,
              heroTag: 'avatar-${controller.peer.id}',
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.peer.username,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _subtitle(controller),
                      key: ValueKey(
                        '${controller.peerIsTyping}-${controller.peerIsOnline}',
                      ),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.videocam_outlined),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.call_outlined)),
        ],
      ),
      body: Column(
        children: [
          ConnectionBanner(
            connected: controller.connection == SocketConnectionState.connected,
            reconnecting:
                controller.connection == SocketConnectionState.reconnecting,
          ),
          Expanded(
            child: Stack(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xff101916)
                        : const Color(0xffeef4f0),
                  ),
                  child: ListView.builder(
                    controller: scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount:
                        controller.messages.length +
                        (controller.peerIsTyping ? 1 : 0),
                    itemBuilder: (context, reversedIndex) {
                      if (controller.peerIsTyping && reversedIndex == 0) {
                        return const TypingIndicator();
                      }
                      final offset = controller.peerIsTyping ? 1 : 0;
                      final index =
                          controller.messages.length -
                          1 -
                          (reversedIndex - offset);
                      final message = controller.messages[index];
                      final next = index + 1 < controller.messages.length
                          ? controller.messages[index + 1]
                          : null;
                      final showTail =
                          next == null ||
                          next.sender.id != message.sender.id ||
                          next.createdAt
                                  .difference(message.createdAt)
                                  .inMinutes >
                              3;
                      final previous = index > 0
                          ? controller.messages[index - 1]
                          : null;
                      final showDate =
                          previous == null ||
                          !_sameDay(previous.createdAt, message.createdAt);
                      return Column(
                        children: [
                          if (showDate) DateSeparator(date: message.createdAt),
                          MessageBubble(
                            key: ValueKey(message.clientMessageId),
                            message: message,
                            isMine: message.isMine(controller.currentUser.id),
                            showTail: showTail,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (showJumpButton)
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      onPressed: _jumpDown,
                      child: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ),
              ],
            ),
          ),
          MessageInput(
            onSend: controller.send,
            onChanged: controller.onInputChanged,
          ),
        ],
      ),
    );
  }
}

String _subtitle(ChatController controller) {
  if (controller.peerIsTyping) return 'yazıyor…';
  if (controller.peerIsOnline) return 'çevrimiçi';
  if (controller.peerLastSeen != null) {
    return 'son görülme ${controller.peerLastSeen!.hour.toString().padLeft(2, '0')}:${controller.peerLastSeen!.minute.toString().padLeft(2, '0')}';
  }
  return 'çevrimdışı';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
