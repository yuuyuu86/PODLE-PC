import 'package:flutter_test/flutter_test.dart';
import 'package:podle_pc/net/wifi.dart';

void main() {
  test('netsh の出力から SSID を取り出す（BSSID ではない）', () {
    const out = '''
    名前                   : Wi-Fi
    SSID                   : おうちのWi-Fi
    BSSID                  : aa:bb:cc:dd:ee:ff
''';
    expect(WifiInfo.parseNetsh(out), 'おうちのWi-Fi');
    expect(WifiInfo.parseNetsh('    BSSID : aa'), isNull);
  });

  test('名前が分かれば名前、分からなければネットワークの番号を出す', () async {
    final a = WifiInfo(ssid: () async => 'home', subnet: () async => '192.168.1.x');
    await a.refresh();
    expect(a.label, 'Wi-Fi: home');
    final b = WifiInfo(ssid: () async => null, subnet: () async => '192.168.1.x');
    await b.refresh();
    expect(b.label, 'ネットワーク: 192.168.1.x');
    final c = WifiInfo(ssid: () async => throw Exception(), subnet: () async => null);
    await c.refresh();
    expect(c.label, isNull);
  });
}
