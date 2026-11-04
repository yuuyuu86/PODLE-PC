import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart' show Colors;

import '../../ui/doodle.dart';
import '../core/common.dart';
import '../core/painting.dart';

/// PODLE! 綱引き: J をリズムよく押して綱を引き、真ん中の旗を自分の側の線まで引き込んだら1点。
/// 連打しすぎると力が入らない（ちょうどいい間隔で押すと JUST!）。
/// Space 長押しでふんばると、相手に引かれにくくなるが、その間は引けず、体力（ふんばり）が減る。
class Tugger {
  Tugger(this.side);

  final int side;

  /// 前に引いてからの時間（リズムの判定用）
  double since = 9;

  /// 引いた直後の姿勢（描画用）
  double pull = 0;
  bool brace = false;

  /// ふんばれる残り（0〜1）
  double stamina = 1;

  /// ゲージを使い切ったあと、少し戻るまでふんばれない
  bool tired = false;

  Map<String, Object?> toJson() => {'s': side, 'p': r2(pull), 'b': brace, 'st': r2(stamina), 'si': r2(math.min(since, 9))};

  static Tugger fromJson(Map<String, Object?> m) => Tugger((m['s'] as num).toInt())
    ..pull = numD(m['p'])
    ..brace = m['b'] == true
    ..stamina = numD(m['st'])
    ..since = numD(m['si']);
}

class TugWorld extends GameWorld {
  List<Tugger> players = [Tugger(0), Tugger(1)];

  /// 旗の位置（真ん中からのずれ。左の選手の側が負）
  double flag = 0;
  double v = 0;

  @override
  Map<String, Object?> toJson() => {'p': [for (final t in players) t.toJson()], 'f': r2(flag), 'v': r2(v)};

  static TugWorld fromJson(Map<String, Object?> m) => TugWorld()
    ..players = [for (final t in m['p'] as List) Tugger.fromJson((t as Map).cast<String, Object?>())]
    ..flag = numD(m['f'])
    ..v = numD(m['v']);
}

class TugRules extends SportRules {
  TugRules._();
  static final instance = TugRules._();

  /// 旗がここまで来たら、引き込んだ側の得点
  static const winLine = 170.0;

  /// 選手が綱を持つ位置（真ん中からの距離）
  static const hold = 250.0;

  /// 1回引いたときの力
  static const impulse = 64.0;

  /// ちょうどいい間隔（JUST!）と、早すぎる間隔
  static const justMin = 0.2, justMax = 0.38, tooFast = 0.15;

  /// 綱のねばり（速さが減る割合 / 秒）
  static const drag = 3.2;

  /// ふんばっていると、相手に引かれる力がこれだけになる
  static const braceHold = 0.3;
  static const braceDrain = 0.55, staminaRegen = 0.3;

  static Timing rhythm(double since) => since < tooFast ? Timing.early : (since >= justMin && since <= justMax ? Timing.just : Timing.normal);

  @override
  int? get winScore => 5;
  @override
  ServeRule get serveRule => ServeRule.none;

  @override
  GameWorld makeWorld() => TugWorld();

  @override
  GameWorld worldFromJson(Map<String, Object?> json) => TugWorld.fromJson(json);

  @override
  void serve(GameWorld world, int? server) {
    final w = world as TugWorld;
    w
      ..flag = 0
      ..v = 0
      ..players = [Tugger(0), Tugger(1)];
  }

  @override
  StepResult? step(GameWorld world, List<PlayerInput> inputs, double dt, List<GameEvent> events, List<int> score) {
    final w = world as TugWorld;
    for (var i = 0; i < 2; i++) {
      final t = w.players[i];
      final inp = inputs[i];
      t.since += dt;
      t.pull = math.max(0, t.pull - dt);
      if (t.stamina <= 0) t.tired = true;
      if (t.tired && t.stamina >= 0.4) t.tired = false;
      t.brace = inp.jump && !t.tired;
      t.stamina = clampD(t.stamina + (t.brace ? -braceDrain : staminaRegen) * dt, 0, 1);
      if (inp.actPressed && !t.brace) {
        final q = rhythm(t.since);
        final o = w.players[1 - i];
        var f = impulse * switch (q) { Timing.just => 1.35, Timing.early => 0.1, _ => 1.0 };
        if (o.brace) f *= braceHold;
        // 左の選手(0)は旗を左（負）へ、右の選手(1)は右（正）へ引く
        w.v += (i == 0 ? -1 : 1) * f;
        t
          ..since = 0
          ..pull = 0.18;
        final hx = Field.center + (i == 0 ? -hold : hold) + w.flag;
        events.add(GameEvent('pull', side: i, x: hx, y: Field.ground - 70, q: q.wire));
      }
    }
    w.v *= math.max(0, 1 - drag * dt);
    w.flag += w.v * dt;
    if (w.flag <= -winLine) return PointResult(0, '引き込んだ');
    if (w.flag >= winLine) return PointResult(1, '引き込んだ');
    return null;
  }
}

class TugPainter extends SportPainter {
  const TugPainter();

  @override
  void paintCourt(Canvas c) {
    const G = Field.ground;
    Sketch.strokeTwice(c, (s) => Sketch.line(const Offset(0, G), const Offset(Field.width, G), seed: s), Sketch.pen(3), seed: 11);
    hatchRect(c, const Rect.fromLTWH(0, G + 4, Field.width, Field.height - G - 4), gap: 14);
    // 真ん中の線と、引き込んだら勝ちの線
    ink(c, Sketch.line(const Offset(Field.center, G - 4), const Offset(Field.center, G + 26), seed: 3), 3);
    for (final s in const [-1.0, 1.0]) {
      final x = Field.center + s * TugRules.winLine;
      ink(c, Sketch.line(Offset(x, G - 6), Offset(x, G + 26), seed: x.toInt()), 5);
      drawText(c, 'ここまで引いたら1点', Offset(x, G + 42), size: 14, color: Palette.pencil);
    }
  }

  @override
  void paint(Canvas c, GameWorld world, PaintInfo info) {
    final w = world as TugWorld;
    const ropeY = Field.ground - 62;
    final xs = [for (var i = 0; i < 2; i++) Field.center + (i == 0 ? -TugRules.hold : TugRules.hold) + w.flag];
    // 綱（少したわむ）と、真ん中の旗
    ink(c, Path()
      ..moveTo(xs[0] - 70, ropeY + 4)
      ..quadraticBezierTo(Field.center + w.flag, ropeY + 10, xs[1] + 70, ropeY + 4), 4.5);
    final fx = Field.center + w.flag;
    ink(c, Sketch.line(Offset(fx, ropeY + 6), Offset(fx, ropeY - 60), seed: 4), 3);
    final flag = [Offset(fx, ropeY - 60), Offset(fx + 34, ropeY - 50), Offset(fx, ropeY - 40)];
    c.drawPath(Path()..addPolygon(flag, true), Sketch.fill(Colors.white));
    ink(c, Sketch.polygon(flag, seed: 5, wobble: 0.5), 2.4);
    for (var s = 0; s < 2; s++) {
      final t = w.players[s];
      final own = s == info.you;
      final dir = facing(s);
      final pulling = t.pull > 0;
      // 綱を前の手で持ち、引くと体ごと後ろへ倒れる。ふんばると腰を落とす
      final pose = Pose(
        lean: pulling ? -0.45 : (t.brace ? -0.3 : -0.18),
        armF: 1.45,
        armB: 1.3,
        armLenF: 34,
        armLenB: 28,
        legF: t.brace ? 0.7 : 0.45,
        legB: -0.35,
        kneeF: t.brace ? 0.8 : 0.3,
        kneeB: -0.1,
      );
      final seed = s * 100 + (info.time * 6).floor() % 3;
      Figure.draw(c, x: xs[s], y: Field.ground, dir: dir, own: own, seed: seed, pose: pose, label: info.labels ? (own ? 'あなた' : 'あいて') : null, avatar: info.avatarOf(s));
      if (t.brace) drawText(c, 'ふんばり', Offset(xs[s], Field.ground + 18), size: 15);
      // ふんばりの残り
      final bar = Rect.fromLTWH(xs[s] - 30, Field.ground + 30, 60, 7);
      c.drawRect(Rect.fromLTWH(bar.left, bar.top, bar.width * t.stamina, bar.height), Sketch.fill(t.stamina < 0.25 ? Palette.pencil : Palette.ink));
      ink(c, Sketch.rect(bar, seed: s, wobble: 0.3), 1.4);
      // リズムの目安: 前に引いてから、ちょうどいい間隔のあいだ輪を出す
      if (own && info.labels && t.since <= TugRules.justMax + 0.3) {
        final ok = t.since >= TugRules.justMin && t.since <= TugRules.justMax;
        final k = math.min(1.0, t.since / TugRules.justMin);
        c.drawPath(Sketch.circle(Offset(xs[s] - dir * 70, Field.ground - 200), 8 + k * 10, seed: 9, wobble: 0.08), Sketch.pen(ok ? 3.4 : 1.6, color: ok ? Palette.ink : Palette.pencil));
        if (ok) drawText(c, 'いま！', Offset(xs[s] - dir * 70, Field.ground - 232), size: 16);
      }
    }
  }
}
