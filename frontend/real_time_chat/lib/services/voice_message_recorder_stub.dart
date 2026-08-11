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

const bool voiceMessageRecordingSupported = false;

Future<VoiceMessageRecorder?> createVoiceMessageRecorder() async => null;
