import 'dart:io';

import 'package:flutter/services.dart';

/// 画面の実際の大きさ（1ポイントあたり何ミリか）。分からない環境では null
abstract final class ScreenSize {
  static const _channel = MethodChannel('podle/screen');
  static double? _cached;
  static bool _asked = false;

  static Future<double?> mmPerPoint() async {
    if (_asked) return _cached;
    _asked = true;
    try {
      if (Platform.isMacOS) _cached = await _channel.invokeMethod<double>('mmPerPoint');
    } catch (_) {}
    return _cached;
  }
}
