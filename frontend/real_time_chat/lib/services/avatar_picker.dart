import 'dart:typed_data';

import 'avatar_picker_stub.dart'
    if (dart.library.html) 'avatar_picker_web.dart' as impl;

class PickedAvatar {
  const PickedAvatar({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

Future<PickedAvatar?> pickAvatarImage() => impl.pickAvatarImage();

bool get avatarPickerSupported => impl.avatarPickerSupported;
