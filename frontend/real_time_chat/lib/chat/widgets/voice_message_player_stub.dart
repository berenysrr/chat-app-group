import 'package:flutter/material.dart';

class VoiceMessagePlayer extends StatelessWidget {
  const VoiceMessagePlayer({
    super.key,
    required this.dataUrl,
    required this.isMine,
  });

  final String dataUrl;
  final bool isMine;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.play_circle_fill_rounded,
        color: isMine ? Colors.white : Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: 10),
      Text(
        'Sesli mesaj',
        style: TextStyle(
          color: isMine
              ? Colors.white
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}
