// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';

class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({
    super.key,
    required this.dataUrl,
    required this.isMine,
  });

  final String dataUrl;
  final bool isMine;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  late final html.AudioElement _audio;
  StreamSubscription<html.Event>? _metadataSub;
  StreamSubscription<html.Event>? _timeSub;
  StreamSubscription<html.Event>? _endedSub;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audio = html.AudioElement()
      ..src = widget.dataUrl
      ..preload = 'metadata';
    _metadataSub = _audio.onLoadedMetadata.listen((_) {
      final seconds = _audio.duration;
      if (seconds.isFinite) {
        setState(
          () => _duration = Duration(milliseconds: (seconds * 1000).round()),
        );
      }
    });
    _timeSub = _audio.onTimeUpdate.listen((_) {
      final seconds = _audio.currentTime;
      if (seconds.isFinite) {
        setState(
          () => _position = Duration(milliseconds: (seconds * 1000).round()),
        );
      }
    });
    _endedSub = _audio.onEnded.listen((_) {
      setState(() {
        _playing = false;
        _position = Duration.zero;
      });
      _audio.currentTime = 0;
    });
  }

  @override
  void dispose() {
    _metadataSub?.cancel();
    _timeSub?.cancel();
    _endedSub?.cancel();
    _audio.pause();
    _audio.src = '';
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      _audio.pause();
      setState(() => _playing = false);
      return;
    }
    await _audio.play();
    if (mounted) setState(() => _playing = true);
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _duration.inMilliseconds;
    final progress = totalMs == 0
        ? 0.0
        : (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final iconColor = widget.isMine
        ? Colors.white
        : Theme.of(context).colorScheme.primary;
    final textColor = widget.isMine
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      width: 220,
      child: Row(
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isMine
                    ? Colors.white.withValues(alpha: .18)
                    : Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: iconColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sesli mesaj',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: widget.isMine
                        ? Colors.white.withValues(alpha: .18)
                        : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: .12),
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _format(_duration == Duration.zero ? _position : _duration),
            style: TextStyle(
              color: textColor.withValues(alpha: .82),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _format(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
