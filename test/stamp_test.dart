import 'package:flutter_test/flutter_test.dart';
import 'package:pong_pc/games/core/catalog.dart';
import 'package:pong_pc/games/core/common.dart';
import 'package:pong_pc/games/core/match.dart';

void main() {
  test('スタンプは押した回数が増えたときだけ届き、通信で往復できる', () {
    final t = PressTracker()..baseline(const KeyState());
    const k = KeyState(st: 2, sc: 1);
    final back = KeyState.fromJson(k.toJson());
    expect(back, k);
    expect(t.input(back, connected: true).stamp, 2);
    expect(t.input(back, connected: true).stamp, isNull);
  });

  test('試合の開始前でも送れて、続けて送ると少し間をあける', () {
    final e = MatchEngine(GameKind.volley, firstServer: 0);
    final events = <GameEvent>[];
    for (var i = 0; i < 90; i++) {
      e.step([const PlayerInput(stamp: 0), PlayerInput.none], 1 / 60);
      events.addAll(e.state.events.where((x) => x.type == 'stamp'));
    }
    expect(e.state.phase, MatchPhase.intro);
    expect(events.length, 2); // 0 と 60 フレーム目
    expect(Stamp.byName(events.first.q), Stamp.nice);
    expect(events.first.side, 0);
  });

  test('スタンプの名前はタイミングの名前と重ならない（音や表示を取り違えない）', () {
    for (final s in Stamp.values) {
      expect(Timing.values.map((t) => t.name), isNot(contains(s.name)));
    }
  });
}
