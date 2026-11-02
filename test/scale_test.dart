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
  test('拡大率: 基準より大きい画面だけ、最大2倍まで', () {
    expect(UiScale.of(const Size(1000, 700)), 1);
    expect(UiScale.of(const Size(2560, 1600)), 2);
    expect(UiScale.of(const Size(1920, 1080)), closeTo(1.35, 0.01));
    expect(UiScale.of(const Size(6000, 4000)), 2);
  });

  for (final size in const [Size(1920, 1080), Size(2560, 1600), Size(1000, 640)]) {
    testWidgets('大きさ ${size.width.toInt()}x${size.height.toInt()} で、どの画面もはみ出さない', (tester) async {
      SharedPreferences.setMockInitialValues({'playerName': 'ゆうた', 'avatar': '1.0.2.0', 'registered': true});
      final settings = await AppSettings.load();
      final model = AppModel(settings: settings, feedback: GameFeedback(settings), updates: UpdateChecker(fetchPolicy: () async => null, fetch: () async => null));
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(PongApp(settings: settings, feedback: model.feedback, model: model, splash: false));
      for (final s in [Screen.home, Screen.quests, Screen.shop, Screen.locker, Screen.settings, Screen.records, Screen.howto]) {
        model.go(s);
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull, reason: '$s');
      }
      model.sessionRoom(const RoomInfo(code: 'KQTE', game: GameKind.boxing, phase: RoomPhase.match, you: 0, players: [
        PlayerInfo(present: true, name: 'ゆうた', avatar: '1.0.2.0', connected: true),
        PlayerInfo(present: true, name: 'はなこ', avatar: '2.1.4.0', connected: true),
      ]));
      model.sessionState((MatchEngine(GameKind.boxing)..step(const [PlayerInput.none, PlayerInput.none], 1 / 60)).state);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: 'match');
      model.keyboard.dispose();
    });
  }
}
