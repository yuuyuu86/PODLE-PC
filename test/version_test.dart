import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:podle_pc/app/settings.dart';
import 'package:podle_pc/app/updates.dart';
import 'package:podle_pc/app/version.dart';
import 'package:podle_pc/net/discovery.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> waitUntil(String label, bool Function() cond) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('待ちきれませんでした: $label');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('アプリの版は pubspec.yaml と同じ', () {
    final m = RegExp(r'^version:\s*([^+\s]+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(AppVersion.app, m!.group(1));
  });

  test('版の比べ方', () {
    expect(AppVersion.compare('1.10.0', '1.9.3'), greaterThan(0));
    expect(AppVersion.compare('v1.1.0', '1.1.0'), 0);
    expect(AppVersion.compare('1.1.0+5', '1.1.0'), 0);
    expect(AppVersion.compare('1.0.9', '1.1'), lessThan(0));
  });

  test('新しい版のお知らせ: 新しいときだけ知らせ、失敗しても何も出さない', () async {
    final newer = UpdateChecker(fetchPolicy: () async => null, fetch: () async => ('v9.0.0', 'https://example.com/r'));
    await newer.check();
    expect((newer.latest, newer.url, newer.upToDate), ('9.0.0', 'https://example.com/r', false));
    final same = UpdateChecker(fetchPolicy: () async => null, fetch: () async => ('v${AppVersion.app}', 'x'));
    await same.check();
    expect((same.latest, same.upToDate), (null, true));
    final broken = UpdateChecker(fetchPolicy: () async => null, fetch: () async => throw const SocketException('offline'));
    await broken.check();
    expect((broken.latest, broken.upToDate, broken.checking), (null, null, false));
  });

  test('強制アップデート: 最低版数より古いと遊べず、オフラインでも覚えている', () async {
    String? saved;
    final old = UpdateChecker(fetchPolicy: () async => ('99.0.0', 'ルールが変わりました'), fetch: () async => null, onMinVersion: (v) => saved = v);
    await old.check();
    expect((old.required, old.message, saved), (true, 'ルールが変わりました', '99.0.0'));
    // オフラインで起動: 保存した最低版数で止める
    final offline = UpdateChecker(fetchPolicy: () async => throw const SocketException('offline'), fetch: () async => null, savedMinVersion: saved);
    await offline.check();
    expect(offline.required, isTrue);
    // 最低版数が今の版以下なら止めない（下げれば解除できる）
    final ok = UpdateChecker(fetchPolicy: () async => (AppVersion.app, null), fetch: () async => null, savedMinVersion: '99.0.0');
    await ok.check();
    expect(ok.required, isFalse);
  });

  test('配布する update.json の最低版数は、いまの版以下（自分自身を止めない）', () {
    final m = jsonDecode(File('update.json').readAsStringSync()) as Map;
    expect(AppVersion.compare(m['minVersion'] as String, AppVersion.app), lessThanOrEqualTo(0));
  });

  test('保存データの版: 古いデータを読み込むと、いまの版として記録する', () async {
    SharedPreferences.setMockInitialValues({'playerName': 'ゆうた'});
    final s = await AppSettings.load();
    expect(s.savedDataVersion, AppSettings.dataVersion);
    expect(s.playerName, 'ゆうた');
  });

  test('近くのPC: 版を知らせない古い版は通信できる版、通信の版や仕組みが違う版は「版がちがう」', () async {
    final d = Discovery(udpPort: 47611, interval: const Duration(milliseconds: 200), loopbackOnly: true);
    await d.start(name: 'わたし', avatar: '', tcpPort: 1, fingerprint: 'a' * 64);
    final sock = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    void send(Map<String, Object?> m) => sock.send(utf8.encode(jsonEncode(m)), InternetAddress.loopbackIPv4, 47611);
    final fp = 'b' * 64;
    send({'m': 'pong-pc/2', 'id': 'old', 'name': '古い', 'state': 'host', 'code': 'ABCD', 'port': 2, 'fp': fp});
    send({'m': 'pong-pc/2', 'id': 'next', 'name': '未来', 'state': 'idle', 'port': 3, 'fp': fp, 'v': '9.0.0', 'pv': AppVersion.protocol + 1});
    send({'m': 'pong-pc/1', 'id': 'tls', 'name': '暗号化前', 'state': 'idle', 'port': 4});
    await waitUntil('3台', () => d.peers.length == 3);
    Peer by(String n) => d.peers.firstWhere((p) => p.name == n);
    expect((by('古い').compatible, by('古い').versionLabel), (true, '1.1.0 より前'));
    expect((by('未来').compatible, by('未来').version), (false, '9.0.0'));
    expect(by('暗号化前').compatible, isFalse);
    expect(d.peerWithCode('ABCD')?.name, '古い');
    sock.close();
    d.dispose();
  });
}
