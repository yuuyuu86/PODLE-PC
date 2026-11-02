import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pong_pc/app/app_model.dart';
import 'package:pong_pc/app/feedback.dart';
import 'package:pong_pc/app/settings.dart';
import 'package:pong_pc/app/updates.dart';
import 'package:pong_pc/games/core/catalog.dart';
import 'package:pong_pc/games/core/common.dart';
import 'package:pong_pc/games/core/match.dart';
import 'package:pong_pc/main.dart';
import 'package:pong_pc/net/wire.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('得点の表示は、次のプレーと次の試合の開始前には消える', (tester) async {
    SharedPreferences.setMockInitialValues({'playerName': 'ゆうた', 'avatar': '1.0.2.0', 'registered': true});
    final settings = await AppSettings.load();
    final model = AppModel(settings: settings, feedback: GameFeedback(settings), updates: UpdateChecker(fetchPolicy: () async => null, fetch: () async => null));
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(PongApp(settings: settings, feedback: model.feedback, model: model, splash: false));
    const players = [
      PlayerInfo(present: true, name: 'ゆうた', avatar: '1.0.2.0', connected: true),
      PlayerInfo(present: true, name: 'はなこ', avatar: '2.1.4.0', connected: true),
    ];
    model.sessionRoom(const RoomInfo(code: 'KQTE', game: GameKind.volley, phase: RoomPhase.match, you: 0, players: players));
    await tester.pump(const Duration(milliseconds: 500));
    final e = MatchEngine(GameKind.volley, firstServer: 0);
    const none = [PlayerInput.none, PlayerInput.none];
    var sawPoint = false;
    for (var t = 0; t < 60 * 20 && e.state.score.every((s) => s == 0) || e.state.phase == MatchPhase.point; t++) {
      e.step(none, 1 / 60);
      model.sessionState(e.state);
      await tester.pump(const Duration(milliseconds: 16));
      if (e.state.phase == MatchPhase.point) sawPoint |= find.textContaining('の得点').evaluate().isNotEmpty;
    }
    expect(sawPoint, isTrue);
    expect(e.state.phase, MatchPhase.play);
    expect(find.text('PONG! バレー'), findsOneWidget, reason: '開始前の説明はプレー中に残らない（上のスコア欄の1つだけ）');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('の得点'), findsNothing, reason: 'プレー再開後');
    // 次の試合（もう一度）
    final e2 = MatchEngine(GameKind.volley, firstServer: 0)..step(none, 1 / 60);
    model.sessionRoom(const RoomInfo(code: 'KQTE', game: GameKind.volley, phase: RoomPhase.match, you: 0, players: players));
    model.sessionState(e2.state);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('の得点'), findsNothing, reason: '次の試合の開始前');
  });

  testWidgets('「試合を抜けますか？」を開いたまま試合が終わったら、確認は閉じる', (tester) async {
    SharedPreferences.setMockInitialValues({'playerName': 'ゆうた', 'avatar': '1.0.2.0', 'registered': true});
    final settings = await AppSettings.load();
    final model = AppModel(settings: settings, feedback: GameFeedback(settings), updates: UpdateChecker(fetchPolicy: () async => null, fetch: () async => null));
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(PongApp(settings: settings, feedback: model.feedback, model: model, splash: false));
    const players = [
      PlayerInfo(present: true, name: 'ゆうた', avatar: '1.0.2.0', connected: true),
      PlayerInfo(present: true, name: 'はなこ', avatar: '2.1.4.0', connected: true),
    ];
    model.sessionRoom(const RoomInfo(code: 'KQTE', game: GameKind.volley, phase: RoomPhase.match, you: 0, players: players));
    model.sessionState((MatchEngine(GameKind.volley)..step(const [PlayerInput.none, PlayerInput.none], 1 / 60)).state);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('退出する'), findsOneWidget);
    model.sessionRoom(const RoomInfo(code: 'KQTE', game: GameKind.volley, phase: RoomPhase.result, you: 0, players: players));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3)).catchError((_) => 0);
    expect(model.screen, Screen.result);
    expect(find.text('退出する'), findsNothing);
    model.keyboard.dispose();
  });
}
