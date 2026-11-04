import 'package:flutter_test/flutter_test.dart';
import 'package:podle_pc/games/boxing/boxing.dart';
import 'package:podle_pc/games/core/common.dart';
import 'package:podle_pc/games/fencing/fencing.dart';
import 'package:podle_pc/games/rally/rally.dart';
import 'package:podle_pc/games/volley/volley.dart';

/// バレーで、選手の打点にボールを置いて振ったときの打球
GameEvent? hitVolley({required double waitBefore, required double swingBefore}) {
  final rules = VolleyRules.instance;
  final w = rules.makeWorld();
  rules.serve(w, 0);
  w.serving = false;
  final p = w.players[0]..cd = 0;
  w.players[1].cd = 0;
  const dt = 1 / 120;
  void put(bool inReach) {
    w.ball
      ..x = inReach ? p.x + 8 : p.x + 400
      ..y = p.y - 78
      ..vx = 0
      ..vy = 0;
  }

  final events = <GameEvent>[];
  final score = [0, 0];
  const idle = [PlayerInput.none, PlayerInput.none];
  // 先に振る（早すぎ）: ボールが遠いうちに振ってから、届く位置へ
  if (swingBefore > 0) {
    put(false);
    rules.step(w, [const PlayerInput(actPressed: true), PlayerInput.none], dt, events, score);
    for (var t = dt; t < swingBefore; t += dt) {
      put(false);
      rules.step(w, idle, dt, events, score);
    }
    put(true);
    rules.step(w, idle, dt, events, score);
  } else {
    // ボールが届いてから waitBefore 秒たって振る（遅すぎ）
    for (var t = 0.0; t < waitBefore; t += dt) {
      put(true);
      rules.step(w, idle, dt, events, score);
    }
    put(true);
    rules.step(w, [const PlayerInput(actPressed: true), PlayerInput.none], dt, events, score);
  }
  return events.where((e) => e.side == 0 && e.x != null).firstOrNull;
}

void main() {
  test('ボールが来た瞬間に振るとジャストで、速く飛ぶ', () {
    final e = hitVolley(waitBefore: 0, swingBefore: 0);
    expect(e, isNotNull);
    expect(Timing.of(e!.q), Timing.just);
  });

  test('ボールが来てから遅れて振ると「おそい」', () {
    final e = hitVolley(waitBefore: 0.12, swingBefore: 0);
    expect(Timing.of(e!.q), Timing.late);
  });

  test('早く振りすぎて振り終わりに当たると「はやい」', () {
    final e = hitVolley(waitBefore: 0, swingBefore: 0.15);
    expect(Timing.of(e!.q), Timing.early);
  });

  test('ジャストは強く、弱い当たりは遅い打球になる', () {
    const s = Shot(500, 300, 'spike');
    expect(RallyRules.adjust(s, Timing.just).vx, greaterThan(500));
    expect(RallyRules.adjust(s, Timing.just).vy, 300);
    expect(RallyRules.adjust(s, Timing.late).vx, lessThan(500));
    expect(RallyRules.adjust(s, Timing.normal).vx, 500);
  });

  test('ボクシング: 拳の先で当てるとジャスト、近すぎると弱い', () {
    expect(BoxingRules.timing(BoxingRules.reach), Timing.just);
    expect(BoxingRules.timing(50), Timing.close);
    expect(BoxingRules.timing(70), Timing.normal);
  });

  test('フェンシング: 突きが届く直前のパリィはジャスト、早すぎは弱い', () {
    expect(FencingRules.parryTiming(0.03), Timing.just);
    expect(FencingRules.parryTiming(0.2), Timing.early);
    expect(FencingRules.lungeTiming(FencingRules.tExtend * 0.9), Timing.just);
    expect(FencingRules.lungeTiming(0.01), Timing.close);
  });

  test('タイミングは通信で往復できる（ふつうは送らない）', () {
    const e = GameEvent('spike', side: 0, x: 1, y: 2, q: 'just');
    expect(GameEvent.fromJson(e.toJson()).q, 'just');
    expect(const GameEvent('bump').toJson().containsKey('q'), isFalse);
    expect(Timing.of('知らない'), Timing.normal);
  });

  test('フェンシング: ジャストのパリィで長く固まっても、ピストの外まで下がらない', () {
    final rules = FencingRules.instance;
    final w = rules.makeWorld() as FencingWorld;
    rules.serve(w, null);
    // 右の選手がピストの端の近くで突き、左の選手がぎりぎりでパリィ
    w.players[1].x = FencingRules.pisteMax - 80;
    w.players[0].x = w.players[1].x - FencingRules.arm - 20;
    const dt = 1 / 120;
    final events = <GameEvent>[];
    final score = [0, 0];
    var t = 0;
    var parried = false;
    for (; t < 240; t++) {
      final p1 = PlayerInput(actPressed: t == 0);
      // 突きが届く少し前にパリィ
      final p0 = PlayerInput(jumpPressed: t == 2);
      final r = rules.step(w, [p0, p1], dt, events, score);
      parried |= events.any((e) => e.type == 'parry' && e.q == 'just');
      if (r != null) fail('点が入った: ${(r as dynamic).reason}');
    }
    expect(parried, isTrue);
  });

  test('振り直しを待つ間にボールが来ても、待った分は「おそい」に数えない', () {
    final rules = VolleyRules.instance;
    final w = rules.makeWorld();
    rules.serve(w, 0);
    w.serving = false;
    final p = w.players[0]..cd = 0.3;
    p.reachClock = 0;
    for (var i = 0; i < 30; i++) {
      w.ball
        ..x = p.x + 8
        ..y = p.y - 78
        ..vx = 0
        ..vy = 0;
      rules.step(w, const [PlayerInput.none, PlayerInput.none], 1 / 120, [], [0, 0]);
    }
    expect(p.reachClock, 0);
  });
}
