import 'package:flutter_test/flutter_test.dart';
import 'package:podle_pc/games/badminton/badminton.dart';
import 'package:podle_pc/games/boxing/boxing.dart';
import 'package:podle_pc/games/core/common.dart';
import 'package:podle_pc/games/fencing/fencing.dart';
import 'package:podle_pc/games/rally/rally.dart';
import 'package:podle_pc/games/sumo/sumo.dart';
import 'package:podle_pc/games/tug/tug.dart';
import 'package:podle_pc/games/volley/volley.dart';

const dt = 1 / 60;
const idle = PlayerInput.none;

/// サーブを終えてラリー中にする
RallyWorld rally(RallyRules rules) {
  final w = rules.makeWorld();
  rules.serve(w, 0);
  w.serving = false;
  return w;
}

void main() {
  group('バレー: ブロック', () {
    final rules = VolleyRules.instance;

    /// 右の選手(1)がネット際で跳び、左(0)のスパイクがネット際を通る
    (RallyWorld, List<GameEvent>) setup({required bool block, bool far = false}) {
      final w = rally(rules);
      final events = <GameEvent>[];
      final p = w.players[1]..x = Field.center + (far ? 200 : 40);
      p.advance(const PlayerInput(jump: true, jumpPressed: true), dt, rules.cfg.runner);
      for (var i = 0; i < 8; i++) {
        rules.step(w, [idle, idle], dt, events, [0, 0]);
      }
      if (block) rules.step(w, [idle, const PlayerInput(jumpPressed: true)], dt, events, [0, 0]);
      w
        ..lastHitter = 0
        ..lastShot = 'spike'
        ..ball.x = Field.center - 30
        ..ball.y = VolleyRules.netTop - 30
        ..ball.vx = 700
        ..ball.vy = 60;
      for (var i = 0; i < 6; i++) {
        rules.step(w, [idle, idle], dt, events, [0, 0]);
      }
      return (w, events);
    }

    test('ネット際で跳んで Space をもう一度押すと、スパイクを相手のコートへはね返す', () {
      final (w, events) = setup(block: true);
      expect(events.any((e) => e.type == 'vblock' && e.n == 'ブロック！'), isTrue);
      expect(w.ball.vx, lessThan(0));
      expect(w.ball.x, lessThan(Field.center));
      expect(w.touches, [0, 0], reason: 'ブロックはタッチ数に数えない');
    });

    test('ブロックしないとスパイクは通る', () {
      final (w, events) = setup(block: false);
      expect(events.any((e) => e.type == 'vblock'), isFalse);
      expect(w.ball.x, greaterThan(Field.center));
    });

    test('ネットから遠いと腕を伸ばさない', () {
      final (_, events) = setup(block: true, far: true);
      expect(events.any((e) => e.type == 'blockup'), isFalse);
    });

    test('ブロックしたあと着地するまでは打てない（タイミングを外すと無防備）', () {
      final (w, _) = setup(block: true);
      expect(w.players[1].cd, greaterThan(0.3));
    });

    test('フェイントはブロックでは止められない', () {
      final (w, events) = setup(block: true);
      events.clear();
      w.players[1]
        ..block = Moves.blockTime
        ..blockUsed = true;
      w
        ..lastHitter = 0
        ..lastShot = 'feint'
        ..ball.x = Field.center - 30
        ..ball.y = VolleyRules.netTop - 30
        ..ball.vx = 300
        ..ball.vy = -300;
      for (var i = 0; i < 10; i++) {
        rules.step(w, [idle, idle], dt, events, [0, 0]);
      }
      expect(events.any((e) => e.type == 'vblock'), isFalse);
    });
  });

  group('バドミントン: 踏み込みステップ', () {
    final rules = BadmintonRules.instance;

    double run(List<PlayerInput> seq, RallyWorld w, List<GameEvent> ev) {
      final x0 = w.players[1].x;
      for (final inp in seq) {
        rules.step(w, [idle, inp], dt, ev, [0, 0]);
      }
      return w.players[1].x - x0;
    }

    const r = PlayerInput(right: true);
    test('同じ方向キーを素早く2回で、ふつうに歩くより遠くへ動く', () {
      final w = rally(rules)..players[1].x = Field.center + 200;
      final ev = <GameEvent>[];
      final dashed = run([r, idle, idle, r, ...List.filled(8, r)], w, ev);
      expect(ev.any((e) => e.type == 'step'), isTrue);
      final w2 = rally(rules)..players[1].x = Field.center + 200;
      final walked = run([r, r, r, r, ...List.filled(8, r)], w2, []);
      expect(dashed, greaterThan(walked + 20));
    });

    test('ステップのあとは少し固まり、すぐには連発できない', () {
      final w = rally(rules)..players[1].x = Field.center + 150;
      final ev = <GameEvent>[];
      run([r, idle, r, ...List.filled(8, idle)], w, ev);
      expect(w.players[1].stiff + w.players[1].stepCd, greaterThan(0));
      run([r, idle, r, idle], w, ev);
      expect(ev.where((e) => e.type == 'step').length, 1);
    });

    test('ゆっくり2回押してもステップしない', () {
      final w = rally(rules)..players[1].x = Field.center + 150;
      final ev = <GameEvent>[];
      run([r, ...List.filled(30, idle), r], w, ev);
      expect(ev.any((e) => e.type == 'step'), isFalse);
    });
  });

  group('フェンシング: ため突き', () {
    final rules = FencingRules.instance;

    /// 右の選手に向けて、左の選手が [hold] フレーム J を押し続けて離す
    (FencingWorld, List<GameEvent>) lunge(int hold, {double gap = 250, bool parry = false}) {
      final w = rules.makeWorld() as FencingWorld;
      w.players[0].x = Field.center - gap / 2;
      w.players[1].x = Field.center + gap / 2;
      final ev = <GameEvent>[];
      for (var t = 0; t < hold + 50; t++) {
        final a = t < hold ? PlayerInput(act: true, actPressed: t == 0) : idle;
        final o = parry && t == hold ? const PlayerInput(jump: true, jumpPressed: true) : idle;
        if (rules.step(w, [a, o], dt, ev, [0, 0]) != null) break;
      }
      return (w, ev);
    }

    test('ためずに突くと、遠い相手には届かない', () {
      final (_, ev) = lunge(2);
      expect(ev.any((e) => e.type == 'touche'), isFalse);
    });

    test('ためて離すと、遠い相手にも届く', () {
      final (_, ev) = lunge(40);
      expect(ev.any((e) => e.type == 'charge'), isTrue);
      expect(ev.any((e) => e.type == 'touche' && e.n == 'ため突き！'), isTrue);
    });

    test('ため突きを外すと、ふつうより長く固まる', () {
      final (w, ev) = lunge(40, gap: 480);
      expect(ev.any((e) => e.type == 'whiff'), isTrue);
      final w2 = lunge(2, gap: 480).$1;
      expect(w.players[0].state, FencerState.recover);
      expect(w2.players[0].state, isNot(FencerState.recover));
    });

    test('ため突きはパリィで受け流せる', () {
      final (_, ev) = lunge(40, parry: true);
      expect(ev.any((e) => e.type == 'parry'), isTrue);
      expect(ev.any((e) => e.type == 'touche'), isFalse);
    });
  });

  group('ボクシング: 前後に動きながらパンチ', () {
    final rules = BoxingRules.instance;

    (BoxingWorld, List<GameEvent>) punch(double axis, {double gap = 150}) {
      final w = rules.makeWorld() as BoxingWorld;
      w.players[0].x = Field.center - gap / 2;
      w.players[1].x = Field.center + gap / 2;
      final ev = <GameEvent>[];
      final score = [0, 0];
      for (var t = 0; t < 30; t++) {
        final a = PlayerInput(left: axis < 0 && t < 2, right: axis > 0 && t < 2, act: t == 0, actPressed: t == 0);
        rules.step(w, [a, idle], dt, ev, score);
      }
      return (w, ev);
    }

    test('前+J は踏み込んで、その場のパンチが届かない距離にも当たる', () {
      const gap = BoxingRules.reach + BoxingRules.bodyHalf + 30;
      expect(punch(0, gap: gap).$2.any((e) => e.type == 'punch'), isFalse);
      final (_, ev) = punch(1, gap: gap);
      expect(ev.any((e) => e.type == 'punch' && e.n == 'ふみこみ'), isTrue);
    });

    test('前+J を外すと隙ができる', () {
      final (_, ev) = punch(1, gap: 400);
      expect(ev.any((e) => e.type == 'whiff'), isTrue);
    });

    test('後ろ+J は下がりながら打ち、ダメージは小さい', () {
      final (w0, _) = punch(0, gap: 110);
      final (w1, ev) = punch(-1, gap: 110);
      expect(ev.any((e) => e.n == 'さがりうち'), isTrue);
      expect(w1.players[1].hp, greaterThan(w0.players[1].hp));
      expect(w1.players[0].x, lessThan(w0.players[0].x));
    });
  });

  test('技の名前は通信で届く', () {
    const e = GameEvent('touche', x: 1, y: 2, n: 'ため突き！');
    expect(GameEvent.fromJson(e.toJson()).n, 'ため突き！');
  });

  group('綱引き', () {
    final rules = TugRules.instance;

    /// 左の選手が [gap] フレームおきに J を押す
    double pull(int gap, {bool oppBrace = false, int frames = 60}) {
      final w = rules.makeWorld() as TugWorld;
      for (var t = 0; t < frames; t++) {
        rules.step(w, [PlayerInput(act: t % gap == 0, actPressed: t % gap == 0), PlayerInput(jump: oppBrace)], dt, [], [0, 0]);
      }
      return -w.flag;
    }

    test('ちょうどいい間隔で引くと、連打より強く引ける', () {
      expect(pull(18), greaterThan(pull(4)));
    });

    test('相手がふんばると、引ける量が減る', () {
      expect(pull(18, oppBrace: true), lessThan(pull(18) * 0.5));
    });

    test('ふんばりはゲージがなくなると続かない', () {
      final w = rules.makeWorld() as TugWorld;
      for (var t = 0; t < 150; t++) {
        rules.step(w, [idle, const PlayerInput(jump: true)], dt, [], [0, 0]);
      }
      expect(w.players[1].brace, isFalse);
    });

    test('旗を自分の側の線まで引き込むと得点', () {
      final w = rules.makeWorld() as TugWorld;
      StepResult? r;
      for (var t = 0; t < 600 && r == null; t++) {
        r = rules.step(w, [PlayerInput(actPressed: t % 18 == 0), idle], dt, [], [0, 0]);
      }
      expect(r, isA<PointResult>().having((p) => p.side, 'side', 0));
    });
  });

  group('すもう', () {
    final rules = SumoRules.instance;

    SumoWorld close() {
      final w = rules.makeWorld() as SumoWorld;
      w.players[0].x = Field.center - 31;
      w.players[1].x = Field.center + 31;
      return w;
    }

    double after(SumoWorld w, PlayerInput a, PlayerInput b, List<GameEvent> ev, {int frames = 40}) {
      final x0 = w.players[1].x;
      for (var t = 0; t < frames; t++) {
        rules.step(w, [t == 0 ? a : PlayerInput(right: a.right, left: a.left), t == 0 ? b : PlayerInput(jump: b.jump, right: b.right, left: b.left)], dt, ev, [0, 0]);
      }
      return w.players[1].x - x0;
    }

    test('つっぱりで相手を押し返す。ふんばられると効きにくい', () {
      final ev = <GameEvent>[];
      final hard = after(close(), const PlayerInput(act: true, actPressed: true), idle, ev);
      expect(ev.any((e) => e.n == 'つっぱり！'), isTrue);
      final soft = after(close(), const PlayerInput(act: true, actPressed: true), const PlayerInput(jump: true), []);
      expect(hard, greaterThan(soft * 2));
    });

    test('前へ歩くと押せる。ふんばる相手はほとんど動かない', () {
      final push = after(close(), const PlayerInput(right: true), idle, [], frames: 60);
      final braced = after(close(), const PlayerInput(right: true), const PlayerInput(jump: true), [], frames: 60);
      expect(push, greaterThan(20));
      expect(braced, lessThan(push * 0.3));
    });

    test('はたきは前に出てくる相手をつんのめらせ、ふんばる相手には空振りで隙', () {
      final ev = <GameEvent>[];
      final w = close();
      after(w, const PlayerInput(left: true, act: true, actPressed: true), const PlayerInput(left: true), ev, frames: 20);
      expect(ev.any((e) => e.n == 'はたき！'), isTrue);
      expect(w.players[1].state, SumoState.stagger);
      final ev2 = <GameEvent>[];
      final w2 = close();
      after(w2, const PlayerInput(left: true, act: true, actPressed: true), const PlayerInput(jump: true), ev2, frames: 20);
      expect(ev2.any((e) => e.type == 'whiff'), isTrue);
      expect(w2.players[0].state, SumoState.stagger);
    });

    test('土俵の外に出たら相手の得点', () {
      final w = rules.makeWorld() as SumoWorld;
      w.players[1].x = SumoRules.ringMax - 2;
      StepResult? r;
      for (var t = 0; t < 30 && r == null; t++) {
        r = rules.step(w, [idle, const PlayerInput(right: true)], dt, [], [0, 0]);
      }
      expect(r, isA<PointResult>().having((p) => p.side, 'side', 0));
    });
  });
}
