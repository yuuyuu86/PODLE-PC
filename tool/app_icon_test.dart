// アプリアイコンの PNG / ICO を作り直す: flutter test tool/app_icon_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:podle_pc/ui/doodle.dart';
import 'package:podle_pc/ui/logo.dart';

Future<Uint8List> render(int px, {bool fullBleed = false}) async {
  final rec = ui.PictureRecorder();
  AppIconPainter(fullBleed: fullBleed).paint(Canvas(rec), Size(px.toDouble(), px.toDouble()));
  final image = await rec.endRecording().toImage(px, px);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// PNG をそのまま入れた ICO（Vista 以降で読める）
Uint8List ico(List<(int, Uint8List)> images) {
  final head = BytesBuilder();
  final body = BytesBuilder();
  final h = ByteData(6)
    ..setUint16(2, 1, Endian.little)
    ..setUint16(4, images.length, Endian.little);
  head.add(h.buffer.asUint8List());
  var offset = 6 + 16 * images.length;
  for (final (px, png) in images) {
    final e = ByteData(16)
      ..setUint8(0, px >= 256 ? 0 : px)
      ..setUint8(1, px >= 256 ? 0 : px)
      ..setUint16(4, 1, Endian.little)
      ..setUint16(6, 32, Endian.little)
      ..setUint32(8, png.length, Endian.little)
      ..setUint32(12, offset, Endian.little);
    head.add(e.buffer.asUint8List());
    body.add(png);
    offset += png.length;
  }
  return (head..add(body.takeBytes())).takeBytes();
}

void main() {
  test('アプリアイコンを書き出す', () async {
    // アイコンの「P」はアプリのフォントで書く
    await (FontLoader(kFontFamily)..addFont(Future.value(ByteData.sublistView(File('assets/fonts/YuseiMagic-Regular.ttf').readAsBytesSync())))).load();
    const mac = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
    final win = <(int, Uint8List)>[];
    for (final px in const [16, 32, 48, 64, 128, 256, 512, 1024]) {
      final png = await render(px);
      if (px != 48) File('$mac/app_icon_$px.png').writeAsBytesSync(png);
      if (const [16, 32, 48, 64, 256].contains(px)) win.add((px, png));
    }
    File('windows/runner/resources/app_icon.ico').writeAsBytesSync(ico(win));

    // スマホ版（PODLE-Smartphone）にも同じアイコンを書き出す: PHONE_APP=/path/to/app flutter test tool/app_icon_test.dart
    final phone = Platform.environment['PHONE_APP'];
    if (phone == null) return;
    const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    for (final (name, px) in const [
      ('20x20@1x', 20), ('20x20@2x', 40), ('20x20@3x', 60), ('29x29@1x', 29), ('29x29@2x', 58), ('29x29@3x', 87),
      ('40x40@1x', 40), ('40x40@2x', 80), ('40x40@3x', 120), ('60x60@2x', 120), ('60x60@3x', 180),
      ('76x76@1x', 76), ('76x76@2x', 152), ('83.5x83.5@2x', 167), ('1024x1024@1x', 1024),
    ]) {
      File('$phone/$ios/Icon-App-$name.png').writeAsBytesSync(await render(px, fullBleed: true));
    }
    for (final (dir, px) in const [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]) {
      File('$phone/android/app/src/main/res/mipmap-$dir/ic_launcher.png').writeAsBytesSync(await render(px));
    }
  });
}
