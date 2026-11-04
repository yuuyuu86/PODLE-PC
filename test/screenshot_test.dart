// 画面を PNG に書き出して見た目を確認する（任意）。
// SNAPSHOT_DIR=/path/to/dir flutter test test/screenshot_test.dart のときだけ動く。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podle_pc/avatar/avatar.dart';
import 'package:podle_pc/app/app_model.dart';
import 'package:podle_pc/app/records.dart';
import 'package:podle_pc/app/updates.dart';
import 'package:podle_pc/app/feedback.dart';
import 'package:podle_pc/app/settings.dart';
import 'package:podle_pc/games/core/catalog.dart';
import 'package:podle_pc/games/core/common.dart';
import 'package:podle_pc/games/core/match.dart';
import 'package:podle_pc/main.dart';
import 'package:podle_pc/screens/info.dart';
import 'package:podle_pc/net/wire.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFont(String family, String path) async {
  final data = File(path).readAsBytesSync();
  await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(data)))).load();
}

void main() {
  final dir = Platform.environment['SNAPSHOT_DIR'];

  testWidgets('画面を書き出す', (tester) async {
    await tester.runAsync(() async {
      await _loadFont('YuseiMagic', 'assets/fonts/YuseiMagic-Regular.ttf');
      final root = Platform.environment['FLUTTER_ROOT'] ?? '';
      final icons = '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
      if (File(icons).existsSync()) await _loadFont('MaterialIcons', icons);
    });
    SharedPreferences.setMockInitialValues({'playerName': 'ゆうた', 'avatar': '1.0.2.0', 'registered': true});
    final settings = await AppSettings.load();
    final model = AppModel(settings: settings, feedback: GameFeedback(settings), updates: UpdateChecker(fetchPolicy: () async => null, fetch: () async => ('v9.0.0', 'https://example.com')));
    await model.updates.check();
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: PongApp(settings: settings, feedback: model.feedback, model: model, splash: false)));

    ui.Image? last;
    Future<void> shot(String name) async {
      // 書き出す画像に、状態を切りかえたときのお知らせを写さない
      model.toast = null;
      // 画面の切り替え（クロスフェード）が終わるまで進める
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await boundary.toImage();
        last = img;
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }

    await shot('01-home');
    model.go(Screen.create);
    await shot('02-create');
    model.go(Screen.join);
    await shot('02-join');
    model.go(Screen.nearby);
    await shot('02-nearby');
    model.go(Screen.howto);
    await shot('04-howto');
    var info = const RoomInfo(code: 'KQTE', game: GameKind.volley, phase: RoomPhase.lobby, you: 0, players: [
      PlayerInfo(present: true, name: 'ゆうた', avatar: '1.0.2.0', connected: true),
      PlayerInfo.empty,
    ]);
    model.sessionRoom(info);
    await shot('03-room');
    model.sessionRoom(const RoomInfo(code: 'KQTE', game: GameKind.volley, phase: RoomPhase.lobby, you: 0, players: [
      PlayerInfo(present: true, name: 'ゆうた', avatar: '1.0.2.0', connected: true, ready: true),
      PlayerInfo(present: true, name: 'はなこ', avatar: '2.1.4.0', connected: true),
    ]));
    await shot('03-room-ready');
    for (final (i, game) in GameKind.values.indexed) {
      final e = MatchEngine(game, firstServer: 0)..state.stage = i;
      info = RoomInfo(code: 'KQTE', game: game, phase: RoomPhase.match, you: 0, players: [
        info.players[0],
        const PlayerInfo(present: true, name: 'はなこ', avatar: '2.1.4.0', connected: true),
      ]);
      for (var t = 0; t < MatchEngine.introTime * 60 + 40; t++) {
        e.step([
          PlayerInput(right: t % 90 < 50, actPressed: t == 260, jump: game != GameKind.boxing && t == 255),
          PlayerInput(left: t % 70 < 30, actPressed: t == 275, jump: game == GameKind.boxing && t > 250),
        ], 1 / 60);
      }
      // 左の選手のPCと右の選手のPCを書き出し、横に並べた1枚も作る（コートがつながるかを見る）
      final halves = <ui.Image>[];
      for (final you in [0, 1]) {
        info = RoomInfo(code: 'KQTE', game: game, phase: RoomPhase.match, you: you, players: [
          // 左右どちらの画面でも、左の選手はゆうた、右の選手ははなこ（同じ試合を2台から見る）
          const PlayerInfo(present: true, name: 'ゆうた', avatar: '1.0.2.0', connected: true),
          const PlayerInfo(present: true, name: 'はなこ', avatar: '2.1.4.0', connected: true),
        ]);
        model.sessionRoom(info);
        model.sessionState(e.state);
        await shot('1$i-match-${game.name}-${you == 0 ? 'left' : 'right'}');
        halves.add(last!);
      }
      await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        Canvas(rec)
          ..drawImage(halves[0], Offset.zero, Paint())
          ..drawImage(halves[1], Offset(halves[0].width.toDouble(), 0), Paint());
        final pair = await rec.endRecording().toImage(halves[0].width * 2, halves[0].height);
        final png = await pair.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/1$i-match-${game.name}-pair.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
    info = RoomInfo(code: 'KQTE', game: GameKind.volley, phase: RoomPhase.match, you: 0, players: [
      const PlayerInfo(present: true, name: 'ゆうた', avatar: '1.0.2.0', connected: true),
      const PlayerInfo(present: true, name: 'はなこ', avatar: '2.1.4.0', connected: true),
    ]);
    model.sessionRoom(info);
    final intro = MatchEngine(GameKind.volley)
      ..state.stage = 4
      ..step(const [PlayerInput.none, PlayerInput.none], 1 / 60);
    model.sessionState(intro.state);
    await shot('19-intro');
    // 半分表示の右の選手: 開始前の案内はコートの外側に出る
    model.sessionRoom(RoomInfo(code: 'KQTE', game: GameKind.volley, phase: RoomPhase.match, you: 1, players: info.players));
    model.sessionState((MatchEngine(GameKind.volley)
          ..state.stage = 5
          ..step(const [PlayerInput.none, PlayerInput.none], 1 / 60)).state);
    await shot('19-intro-split-right');
    model.sessionRoom(info);
    final over = MatchEngine(GameKind.volley, firstServer: 0);
    var serve = true;
    while (over.state.phase != MatchPhase.over) {
      over.step([PlayerInput(actPressed: over.state.phase == MatchPhase.play && serve), PlayerInput.none], 1 / 60);
      serve = !serve;
    }
    model.sessionState(over.state);
    model.sessionRoom(RoomInfo(code: 'KQTE', game: GameKind.volley, phase: RoomPhase.result, you: 0, players: [
      info.players[0],
      const PlayerInfo(present: true, name: 'はなこ', avatar: '2.1.4.0', connected: true, rematch: true),
    ]));
    await shot('20-result');
    model.go(Screen.settings);
    await shot('21-settings');
    showChangelog(tester.element(find.text('ライセンス')));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await shot('22-changelog');
    Navigator.of(tester.element(find.text('とじる'))).pop();
    for (final (i, won) in [true, false, true].indexed) {
      settings.addRecord(MatchRecord(at: DateTime(2026, 10, 30, 12, i), game: GameKind.values[i], rule: GameKind.values[i].defaultRule, opponent: 'はなこ', opponentAvatar: '2.1.4.0', myScore: won ? 5 : 2, opponentScore: won ? 3 : 5, won: won));
    }
    model.go(Screen.records);
    await shot('23-records');
    settings.addRecord(MatchRecord(at: DateTime.now(), game: GameKind.volley, rule: 5, opponent: 'はなこ', opponentAvatar: '2.1.4.0', myScore: 5, opponentScore: 1, won: true));
    settings.addCoins(320);
    model.go(Screen.quests);
    await shot('25-quests');
    settings.buy(AvatarPart.top, 7);
    model.go(Screen.shop);
    await shot('26-shop');
    model.go(Screen.locker);
    await shot('27-locker');
    model.go(Screen.home);
    await shot('28-home-coins');
    // 強制アップデートの画面（最低版数より古い）
    model.updates
      ..minVersion = '9.0.0'
      ..message = '試合のルールが変わったため、古い版とは遊べなくなりました。';
    settings.volume = 0.6; // 画面を作り直させる
    await shot('24-update-required');
    model.updates.minVersion = null;
    await tester.pump(const Duration(seconds: 4));
    model.keyboard.dispose();
  }, skip: dir == null);
}
