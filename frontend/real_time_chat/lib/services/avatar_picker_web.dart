// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'avatar_picker.dart';

const bool avatarPickerSupported = true;

Future<PickedAvatar?> pickAvatarImage() async {
  final input = html.FileUploadInputElement()..accept = 'image/*';
  final change = Completer<html.File?>();
  input.onChange.listen((_) {
    change.complete(input.files?.isNotEmpty == true ? input.files!.first : null);
  });
  input.click();

  final file = await change.future;
  if (file == null) return null;

  final reader = html.FileReader();
  final loaded = Completer<void>();
  reader.onLoad.listen((_) => loaded.complete());
  reader.readAsArrayBuffer(file);
  await loaded.future;

  final result = reader.result;
  if (result is! ByteBuffer) return null;
  return PickedAvatar(
    bytes: Uint8List.view(result),
    fileName: file.name,
    mimeType: file.type.isEmpty ? 'image/png' : file.type,
  );
}
