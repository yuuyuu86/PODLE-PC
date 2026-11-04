import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart' show Colors;

import '../../ui/doodle.dart';
import '../core/common.dart';
import '../core/painting.dart';

/// PODLE! すもう: 押し合って、相手を土俵の外へ出したら1点。
/// - 前へ歩くと押す。J でつっぱり（強く押し返す）。
/// - Space 長押しでふんばり（つっぱりも押しも効きにくい。動けない）。
/// - 後ろ + J ではたき: 前に出てくる相手をつんのめらせる。ふんばっている相手には空振りで隙。
enum SumoState { idle, thrust, recover, slap, stagger }

class Rikishi {
  Rikishi(this.side) : x = Field.center + (side == 0 ? -90 : 90);

  final int side;
  double x;
  double vx = 0;
  SumoState state = SumoState.idle;
  double timer = 0;
  bool brace = false;
  bool pushing = false;
  bool hit = false;
  double actBuf = 0;

  Map<String, Object?> toJson() => {'s': side, 'x': r2(x), 'st': state.name, 'k': r2(timer), 'b': brace, 'pu': pushing};

  static Rikishi fromJson(Map<String, Object?> m) => Rikishi((m['s'] as num).toInt())
    ..x = numD(m['x'])
    ..state = SumoState.values.byName(m['st'] as String)
    ..timer = numD(m['k'])
    ..brace = m['b'] == true
    ..pushing = m['pu'] == true;
}

class SumoWorld extends GameWorld {
  List<Rikishi> players = [Rikishi(0), Rikishi(1)];

  @override
  Map<String, Object?> toJson() => {'p': [for (final r in players) r.toJson()]};

  static SumoWorld fromJson(Map<String, Object?> m) => SumoWorld()..players = [for (final r in m['p'] as List) Rikishi.fromJson((r as Map).cast<String, Object?>())];
}

class SumoRules extends SportRules {
  SumoRules._();
  static final instance = SumoRules._();

  /// 土俵（この外に足が出たら負け）
  static const ringMin = 190.0;
  static const ringMax = 770.0;

  /// 体と体がくっつく距離
  static const contact = 62.0;
  static const reach = 96.0;

  static const walk = 170.0;
  static const pushPower = 1.0;

  /// つっぱりで相手を押し出す速さ（ふんばられると小さく）
  static const thrustKick = 520.0;
  static const braceResist = 0.3;

  static const tThrust = 0.14, tRecover = 0.26, tSlap = 0.22, tSlapMiss = 0.6, tStagger = 0.65;

  @override
  int? get winScore => 5;
  @override
  ServeRule get serveRule => ServeRule.none;

  @override
  GameWorld makeWorld() => SumoWorld();

  @override
  GameWorld worldFromJson(Map<String, Object?> json) => SumoWorld.fromJson(json);

  @override
  void serve(GameWorld world, int? server) => (world as SumoWorld).players = [Rikishi(0), Rikishi(1)];

  @override
  StepResult? step(GameWorld world, List<PlayerInput> inputs, double dt, List<GameEvent> events, List<int> score) {
    final w = world as SumoWorld;
    for (var i = 0; i < 2; i++) {
      final r = w.players[i];
      final inp = inputs[i];
      final dir = facing(i);
      r.actBuf = inp.actPressed ? 0.12 : math.max(0, r.actBuf - dt);
      r.timer = math.max(0, r.timer - dt);
      final free = r.state == SumoState.idle;
      r.brace = free && inp.jump;
      final fwd = inp.axis * dir;
      r.pushing = free && !r.brace && fwd > 0;
      if (free && !r.brace && r.actBuf > 0) {
        r
          ..state = fwd < 0 ? SumoState.slap : SumoState.thrust
          ..timer = fwd < 0 ? tSlap : tThrust
          ..hit = false
          ..actBuf = 0;
        events.add(GameEvent(fwd < 0 ? 'slap' : 'thrust', side: i));
      } else if (!free && r.timer <= 0) {
        if (r.state == SumoState.thrust) {
          r
            ..state = SumoState.recover
            ..timer = tRecover;
        } else {
          r.state = SumoState.idle;
        }
      }
      // 歩く: ふんばり中は動けない。つんのめっている間は前へ流れる
      final target = r.state == SumoState.stagger ? dir * 120 : (free && !r.brace ? inp.axis * walk : 0.0);
      r.vx = approach(r.vx, target, 1600 * dt);
      if (r.state == SumoState.slap) r.vx = -dir * 160;
    }

    final a = w.players[0], b = w.players[1];
    // 技の判定
    for (var i = 0; i < 2; i++) {
      final r = w.players[i], o = w.players[1 - i];
      if (r.hit || (b.x - a.x) > reach) continue;
      final dir = facing(i);
      if (r.state == SumoState.thrust && r.timer < tThrust * 0.6) {
        r.hit = true;
        final k = o.brace ? braceResist : 1.0;
        o.vx = dir * thrustKick * k;
        if (o.state != SumoState.stagger) o.state = SumoState.idle;
        // ふんばられたら、押した側が少しはね返る
        if (o.brace) r.vx = -dir * 140;
        events.add(GameEvent('thrust', side: i, x: (a.x + b.x) / 2, y: Field.ground - 80, q: o.brace ? Timing.close.wire : null, n: o.brace ? null : 'つっぱり！'));
      } else if (r.state == SumoState.slap && r.timer < tSlap * 0.7) {
        r.hit = true;
        // 前に出てくる相手（押している・つっぱり中）だけ、つんのめる
        final coming = o.pushing || o.state == SumoState.thrust;
        if (coming && !o.brace) {
          o
            ..state = SumoState.stagger
            ..timer = tStagger;
          events.add(GameEvent('slap', side: i, x: (a.x + b.x) / 2, y: Field.ground - 70, n: 'はたき！'));
        } else {
          r
            ..state = SumoState.stagger
            ..timer = tSlapMiss;
          events.add(GameEvent('whiff', side: i, x: r.x + dir * 40, y: Field.ground - 90, n: 'すき！'));
        }
      }
    }

    // 押し合い: くっついているときは、押す力の差で2人いっしょに動く
    var na = a.x + a.vx * dt, nb = b.x + b.vx * dt;
    if (nb - na < contact) {
      double force(Rikishi r) => r.pushing ? pushPower : 0.3;
      final fa = force(a), fb = force(b);
      // くっついている間は、歩く速さではなく押す力の差だけで動く
      final mid = (a.x + b.x) / 2;
      // 押している側へ動く速さは力の差に比例。押される側がふんばっていると、ほとんど動かない
      var shift = (fa - fb) / (fa + fb) * 110 * dt;
      if ((shift > 0 && b.brace) || (shift < 0 && a.brace)) shift *= 0.15;
      na = mid - contact / 2 + shift;
      nb = mid + contact / 2 + shift;
      if (a.vx > 0) a.vx = a.vx * 0.5;
      if (b.vx < 0) b.vx = b.vx * 0.5;
    }
    a.x = na;
    b.x = nb;

    if (a.x < ringMin) {
      events.add(GameEvent('out', side: 0, x: a.x, y: Field.ground - 40));
      return PointResult(1, b.state == SumoState.stagger ? 'はたき込み' : '押し出し', landX: a.x);
    }
    if (b.x > ringMax) {
      events.add(GameEvent('out', side: 1, x: b.x, y: Field.ground - 40));
      return PointResult(0, a.state == SumoState.stagger ? 'はたき込み' : '押し出し', landX: b.x);
    }
    // つんのめって前へ出すぎ、相手の後ろの土俵から出ることもある（相手を越えられないので実際は押し出し）
    return null;
  }
}

class SumoPainter extends SportPainter {
  const SumoPainter();

  @override
  void paintCourt(Canvas c) {
    const G = Field.ground;
    // 土俵: 盛り土の台と、俵の線
    final mound = Path()
      ..moveTo(SumoRules.ringMin - 90, Field.height)
      ..lineTo(SumoRules.ringMin - 40, G)
      ..lineTo(SumoRules.ringMax + 40, G)
      ..lineTo(SumoRules.ringMax + 90, Field.height)
      ..close();
    c.drawPath(mound, Sketch.fill(Colors.white));
    Sketch.hatch(c, mound, const Rect.fromLTWH(0, G, Field.width, Field.height - G), gap: 12, width: 1, color: Palette.faint, seed: 3);
    ink(c, mound, 3);
    for (final x in const [SumoRules.ringMin, SumoRules.ringMax]) {
      final tawara = Rect.fromCenter(center: Offset(x, G - 4), width: 22, height: 10);
      c.drawRRect(RRect.fromRectAndRadius(tawara, const Radius.circular(5)), Sketch.fill(Palette.ink));
      drawText(c, 'ここから出たら負け', Offset(x, G + 24), size: 13, color: Palette.pencil);
    }
    // 仕切り線
    for (final s in const [-1.0, 1.0]) {
      ink(c, Sketch.line(Offset(Field.center + s * 30, G + 2), Offset(Field.center + s * 30, G + 14), seed: s.toInt() + 5), 3);
    }
  }

  @override
  void paint(Canvas c, GameWorld world, PaintInfo info) {
    final w = world as SumoWorld;
    for (var s = 0; s < 2; s++) {
      final r = w.players[s];
      final own = s == info.you;
      final dir = facing(s);
      final pose = Pose(lean: 0.35, armF: 1.5, armB: 1.3, armLenF: 30, armLenB: 26, legF: 0.55, legB: -0.5, kneeF: 0.6, kneeB: -0.2, headR: 14, scale: 1.12);
      switch (r.state) {
        case SumoState.thrust:
          pose
            ..armF = 1.6
            ..armLenF = 48
            ..lean = 0.45;
        case SumoState.slap:
          pose
            ..armF = 2.6
            ..armB = 2.4
            ..lean = -0.1;
        case SumoState.stagger:
          pose
            ..lean = 0.8
            ..armF = 0.6
            ..armB = 0.3;
        default:
      }
      if (r.brace) {
        pose
          ..lean = 0.2
          ..legF = 0.9
          ..legB = -0.85
          ..kneeF = 1.0
          ..kneeB = -0.4;
      }
      final seed = s * 100 + (info.time * 6).floor() % 3;
      final j = Figure.draw(c, x: r.x, y: Field.ground, dir: dir, own: own, seed: seed, pose: pose, label: info.labels ? (own ? 'あなた' : 'あいて') : null, avatar: info.avatarOf(s));
      // まわし（腰の黒い帯）
      final hip = Offset(r.x, Field.ground - 40 * 1.12);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: hip, width: 30, height: 12), const Radius.circular(4)), Sketch.fill(Palette.ink));
      if (r.brace) drawText(c, 'ふんばり', Offset(r.x, Field.ground + 44), size: 15);
      if (r.state == SumoState.stagger) drawText(c, '＊ ＊', Offset(j.head.dx, j.head.dy - 30), size: 18);
    }
  }
}
