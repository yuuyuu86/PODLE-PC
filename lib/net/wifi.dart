import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 今つながっているネットワークの表示。
/// Wi-Fi の名前が分かればそれを、分からなければ（位置情報の許可がない・有線など）このPCのネットワークの番号を出す。
class WifiInfo extends ChangeNotifier {
  WifiInfo({Future<String?> Function()? ssid, Future<String?> Function()? subnet}) : _ssidFn = ssid ?? _ssid, _subnetFn = subnet ?? _subnet;

  final Future<String?> Function() _ssidFn;
  final Future<String?> Function() _subnetFn;

  String? ssid;
  String? subnet;
  Timer? _timer;
  int _users = 0;

  /// 表示: 「Wi-Fi: おうち」/「ネットワーク: 192.168.1.x」/ null
  String? get label => ssid != null ? 'Wi-Fi: $ssid' : (subnet != null ? 'ネットワーク: $subnet' : null);

  /// 画面に出ている間だけ、ときどき読み直す（つなぎ替えや、許可を出したあとに反映する）
  void start() {
    if (_users++ == 0) {
      refresh();
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    }
  }

  void stop() {
    if (--_users <= 0) {
      _users = 0;
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> refresh() async {
    String? a, b;
    try {
      a = await _ssidFn();
    } catch (_) {}
    try {
      b = await _subnetFn();
    } catch (_) {}
    if (a != null && a.trim().isEmpty) a = null;
    if (a != ssid || b != subnet) {
      ssid = a;
      subnet = b;
      notifyListeners();
    }
  }

  static const _channel = MethodChannel('podle/wifi');

  static Future<String?> _ssid() async {
    if (kIsWeb) return null;
    if (Platform.isMacOS) return await _channel.invokeMethod<String>('ssid');
    if (Platform.isWindows) {
      final r = await Process.run('netsh', ['wlan', 'show', 'interfaces']);
      if (r.exitCode != 0) return null;
      return parseNetsh('${r.stdout}');
    }
    return null;
  }

  /// netsh の出力から SSID（BSSID ではない）を取り出す
  static String? parseNetsh(String out) {
    for (final line in out.split('\n')) {
      final m = RegExp(r'^\s*SSID\s*:\s*(.+?)\s*$').firstMatch(line);
      if (m != null) return m[1];
    }
    return null;
  }

  /// プライベートアドレスの先頭3つ（例: 192.168.1.x）
  static Future<String?> _subnet() async {
    for (final ni in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
      for (final a in ni.addresses) {
        final p = a.address.split('.');
        final n0 = int.tryParse(p[0]) ?? 0, n1 = int.tryParse(p[1]) ?? 0;
        final private = n0 == 10 || (n0 == 172 && n1 >= 16 && n1 < 32) || (n0 == 192 && n1 == 168);
        if (private) return '${p[0]}.${p[1]}.${p[2]}.x';
      }
    }
    return null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
