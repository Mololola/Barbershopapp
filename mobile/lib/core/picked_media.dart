import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' show decodeJpgExif, injectJpgExif;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

// A photo or video from image_picker is a file on disk on the phone, but a
// blob: URL in the browser — these keep previews and uploads the same on both.

ImageProvider pickedImage(XFile file) => kIsWeb ? NetworkImage(file.path) : FileImage(File(file.path));

VideoPlayerController pickedVideoController(XFile file) =>
    kIsWeb ? VideoPlayerController.networkUrl(Uri.parse(file.path)) : VideoPlayerController.file(File(file.path));

/// A picked file's bytes for upload, without the GPS position a phone saves
/// in a photo: uploads are public, and on Android image_picker copies the
/// position onto the resized photo. The rest of the metadata is kept (the
/// photo's orientation is in it). Anything but a JPEG passes through as is.
Future<Uint8List> uploadBytes(XFile file) async {
  final bytes = await file.readAsBytes();
  final exif = decodeJpgExif(bytes);
  if (exif == null || exif.imageIfd.sub.directories.remove('gps') == null) return bytes;
  final stripped = injectJpgExif(bytes, exif);
  if (stripped == null) throw StateError('Could not remove the location from this photo');
  return stripped;
}

/// ".jpg", ".mp4"… taken from the file's name: in the browser its path is a
/// blob: URL with no extension at all.
String extensionOf(XFile file) {
  final dot = file.name.lastIndexOf('.');
  return dot == -1 ? '.jpg' : file.name.substring(dot).toLowerCase();
}
