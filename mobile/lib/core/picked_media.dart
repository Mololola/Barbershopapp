import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

// A photo or video from image_picker is a file on disk on the phone, but a
// blob: URL in the browser — these keep previews and uploads the same on both.

ImageProvider pickedImage(XFile file) => kIsWeb ? NetworkImage(file.path) : FileImage(File(file.path));

VideoPlayerController pickedVideoController(XFile file) =>
    kIsWeb ? VideoPlayerController.networkUrl(Uri.parse(file.path)) : VideoPlayerController.file(File(file.path));

/// ".jpg", ".mp4"… taken from the file's name: in the browser its path is a
/// blob: URL with no extension at all.
String extensionOf(XFile file) {
  final dot = file.name.lastIndexOf('.');
  return dot == -1 ? '.jpg' : file.name.substring(dot).toLowerCase();
}
