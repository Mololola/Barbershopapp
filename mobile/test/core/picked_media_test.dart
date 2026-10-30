import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mobile/core/picked_media.dart';

void main() {
  test('a photo is uploaded without its GPS position, keeping its orientation', () async {
    final jpeg = img.encodeJpg(img.Image(width: 8, height: 8));
    final exif = img.ExifData();
    exif.imageIfd['Orientation'] = 6;
    exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(40, 1);
    final withGps = img.injectJpgExif(jpeg, exif)!;
    expect(img.decodeJpgExif(withGps)!.imageIfd.sub.directories, contains('gps'));

    final uploaded = img.decodeJpgExif(await uploadBytes(XFile.fromData(withGps)))!;

    expect(uploaded.imageIfd.sub.directories, isNot(contains('gps')));
    expect(uploaded.imageIfd['Orientation']?.toInt(), 6);
  });

  test('anything but a JPEG passes through unchanged', () async {
    final png = img.encodePng(img.Image(width: 4, height: 4));

    expect(await uploadBytes(XFile.fromData(png)), png);
  });
}
