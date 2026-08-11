// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

final _dataAvailableEvents = html.EventStreamProvider<html.Event>(
  'dataavailable',
);
final _stopEvents = html.EventStreamProvider<html.Event>('stop');

class RecordedVoiceMessage {
  const RecordedVoiceMessage({required this.dataUrl, required this.mimeType});

  final String dataUrl;
  final String mimeType;
}

abstract class VoiceMessageRecorder {
  Future<void> start();
  Future<RecordedVoiceMessage?> stop();
  Future<void> cancel();
}

const bool voiceMessageRecordingSupported = true;

Future<VoiceMessageRecorder?> createVoiceMessageRecorder() async =>
    _WebVoiceMessageRecorder.create();

class _WebVoiceMessageRecorder implements VoiceMessageRecorder {
  _WebVoiceMessageRecorder._(this._stream, this._recorder, this._mimeType) {
    _dataAvailableEvents.forTarget(_recorder).listen((event) {
      final blob = (event as dynamic).data as html.Blob?;
      if (blob != null && blob.size > 0) _chunks.add(blob);
    });
  }

  final html.MediaStream _stream;
  final html.MediaRecorder _recorder;
  final String _mimeType;
  final List<html.Blob> _chunks = [];
  Completer<RecordedVoiceMessage?>? _stopCompleter;
  bool _started = false;

  static Future<_WebVoiceMessageRecorder> create() async {
    final devices = html.window.navigator.mediaDevices;
    if (devices == null) {
      throw StateError('Tarayıcı mikrofon erişimini desteklemiyor.');
    }
    final stream = await devices.getUserMedia({'audio': true});
    final mimeType = _selectMimeType();
    final recorder = mimeType == null
        ? html.MediaRecorder(stream)
        : html.MediaRecorder(stream, <String, dynamic>{'mimeType': mimeType});
    return _WebVoiceMessageRecorder._(
      stream,
      recorder,
      mimeType ?? 'audio/webm',
    );
  }

  static String? _selectMimeType() {
    for (final mimeType in const [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
    ]) {
      try {
        if (html.MediaRecorder.isTypeSupported(mimeType)) return mimeType;
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _recorder.start();
  }

  @override
  Future<RecordedVoiceMessage?> stop() async {
    if (!_started) return null;
    _stopCompleter ??= Completer<RecordedVoiceMessage?>();

    late StreamSubscription<html.Event> stopSub;
    stopSub = _stopEvents.forTarget(_recorder).listen((_) async {
      await stopSub.cancel();
      try {
        final blob = html.Blob(_chunks, _mimeType);
        final reader = html.FileReader();
        final loaded = Completer<void>();
        reader.onLoadEnd.listen((_) => loaded.complete());
        reader.readAsDataUrl(blob);
        await loaded.future;
        final result = reader.result;
        if (result is! String || result.isEmpty) {
          _stopCompleter?.complete(null);
        } else {
          _stopCompleter?.complete(
            RecordedVoiceMessage(dataUrl: result, mimeType: _mimeType),
          );
        }
      } finally {
        _disposeStream();
      }
    });

    _recorder.stop();
    final result = await _stopCompleter!.future;
    _stopCompleter = null;
    _started = false;
    return result;
  }

  @override
  Future<void> cancel() async {
    if (_started && _recorder.state != 'inactive') {
      _recorder.stop();
    }
    _disposeStream();
    _started = false;
    _stopCompleter?.complete(null);
    _stopCompleter = null;
  }

  void _disposeStream() {
    for (final track in _stream.getTracks()) {
      track.stop();
    }
  }
}
