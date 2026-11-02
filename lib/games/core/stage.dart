import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/doodle.dart';
import 'common.dart';
import 'painting.dart';

/// 試合の背景の飾り。試合ごとにホストがランダムに選び、MatchState で相手にも送る。
/// 選手やボールが見やすいよう、うすい鉛筆の色で、コートの奥（地面より上）にだけ描く。
enum Stage {
  sunny('はれ'),
  night('よぞら'),
  beach('うみべ'),
  town('まちなか'),
  mountain('やまのうえ'),
  arena('かんきゃくせき');

  const Stage(this.label);
  final String label;

  static Stage of(int? i) => i == null || i < 0 || i >= values.length ? sunny : values[i];
}

abstract final class StagePainter {
  static final _soft = Palette.pencil.withValues(alpha: 0.45);
  static final _faint = Palette.pencil.withValues(alpha: 0.28);

  static void paint(Canvas c, Stage stage, double time) {
    switch (stage) {
      case Stage.sunny:
        _sun(c, const Offset(120, 90));
        _clouds(c, time);
        _birds(c, time, 3);
      case Stage.night:
        _stars(c, time);
        _moon(c, const Offset(820, 85));
      case Stage.beach:
        _sun(c, const Offset(800, 300), r: 46, rays: false);
        _waves(c, time);
        _palm(c, 70, flip: false);
        _palm(c, 890, flip: true);
        _birds(c, time, 2);
      case Stage.town:
        _buildings(c);
        _clouds(c, time, count: 2);
      case Stage.mountain:
        _mountains(c);
        _bunting(c, time);
      case Stage.arena:
        _crowd(c, time);
        _bunting(c, time, y: 40);
    }
  }

  static Paint _pen(double w, [Color? color]) => Sketch.pen(w, color: color ?? _soft);

  static void _sun(Canvas c, Offset at, {double r = 34, bool rays = true}) {
    c.drawPath(Sketch.circle(at, r, seed: 61), _pen(2.4));
    if (!rays) return;
    for (var i = 0; i < 10; i++) {
      final a = i / 10 * math.pi * 2;
      final d = Offset(math.cos(a), math.sin(a));
      c.drawPath(Sketch.line(at + d * (r + 10), at + d * (r + 24), seed: 62 + i, wobble: 0.6), _pen(2));
    }
  }

  static void _cloud(Canvas c, Offset at, double s, int seed) {
    final path = Path();
    for (final (dx, dy, r) in const [(-1.0, 0.2, 0.7), (-0.3, -0.25, 0.9), (0.5, 0.0, 0.75), (1.1, 0.3, 0.5)]) {
      path.addOval(Rect.fromCircle(center: at + Offset(dx * s, dy * s), radius: r * s));
    }
    c.drawPath(path, Sketch.fill(Palette.paper.withValues(alpha: 0.7)));
    for (final (dx, dy, r) in const [(-1.0, 0.2, 0.7), (-0.3, -0.25, 0.9), (0.5, 0.0, 0.75), (1.1, 0.3, 0.5)]) {
      c.drawPath(Sketch.circle(at + Offset(dx * s, dy * s), r * s, seed: seed + (dx * 10).toInt()), _pen(1.8, _faint));
    }
  }

  static void _clouds(Canvas c, double time, {int count = 3}) {
    for (var i = 0; i < count; i++) {
      final speed = 8.0 + i * 4;
      final x = (i * 360 + 200 + time * speed) % (Field.width + 300) - 150;
      _cloud(c, Offset(x, 70.0 + i * 55), 34 - i * 4, 70 + i * 7);
    }
  }

  static void _birds(Canvas c, double time, int n) {
    for (var i = 0; i < n; i++) {
      final x = (i * 230 + time * (30 + i * 6)) % (Field.width + 200) - 100;
      final y = 150 + i * 28 + math.sin(time * 1.5 + i) * 8;
      final flap = math.sin(time * 8 + i * 2) * 5;
      c.drawPath(
        Path()
          ..moveTo(x - 12, y - flap)
          ..quadraticBezierTo(x - 6, y - 6, x, y)
          ..quadraticBezierTo(x + 6, y - 6, x + 12, y - flap),
        _pen(2),
      );
    }
  }

  static void _stars(Canvas c, double time) {
    final r = math.Random(5);
    for (var i = 0; i < 34; i++) {
      final at = Offset(r.nextDouble() * Field.width, 20 + r.nextDouble() * 260);
      final tw = 0.5 + 0.5 * math.sin(time * (1.5 + r.nextDouble() * 2) + i);
      final s = 3 + tw * 3;
      final p = _pen(1.6, Palette.pencil.withValues(alpha: 0.2 + tw * 0.35));
      c
        ..drawLine(at - Offset(s, 0), at + Offset(s, 0), p)
        ..drawLine(at - Offset(0, s), at + Offset(0, s), p);
    }
  }

  static void _moon(Canvas c, Offset at) {
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: at, radius: 38)),
      Path()..addOval(Rect.fromCircle(center: at + const Offset(16, -10), radius: 32)),
    );
    c.drawPath(moon, _pen(2.4));
  }

  static void _waves(Canvas c, double time) {
    for (var row = 0; row < 3; row++) {
      final y = 330.0 + row * 34;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= Field.width; x += 12) {
        path.lineTo(x, y + math.sin(x / 40 + time * (1.2 + row * 0.3) + row) * 5);
      }
      c.drawPath(path, _pen(1.8, row == 0 ? _soft : _faint));
    }
  }

  static void _palm(Canvas c, double x, {required bool flip}) {
    final d = flip ? -1.0 : 1.0;
    final top = Offset(x + d * 30, 250);
    c.drawPath(
      Path()
        ..moveTo(x, Field.ground)
        ..quadraticBezierTo(x + d * 4, 360, top.dx, top.dy),
      _pen(4),
    );
    for (final a in [-2.6, -2.0, -1.2, -0.5, 0.1]) {
      final aa = flip ? math.pi - a : a;
      final end = top + Offset(math.cos(aa), math.sin(aa)) * 70;
      c.drawPath(
        Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(top.dx + math.cos(aa) * 40, top.dy + math.sin(aa) * 40 - 18, end.dx, end.dy),
        _pen(2.6),
      );
    }
  }

  static void _buildings(Canvas c) {
    final r = math.Random(9);
    var x = -10.0;
    var i = 0;
    while (x < Field.width) {
      final w = 60 + r.nextDouble() * 60;
      final h = 120 + r.nextDouble() * 170;
      final rect = Rect.fromLTWH(x, Field.ground - h, w - 8, h);
      c.drawPath(Sketch.rect(rect, seed: 80 + i, wobble: 0.8), _pen(2));
      // 窓
      for (var wy = rect.top + 16; wy < Field.ground - 30; wy += 30) {
        for (var wx = rect.left + 10; wx < rect.right - 14; wx += 22) {
          if (r.nextDouble() < 0.35) continue;
          c.drawRect(Rect.fromLTWH(wx, wy, 10, 14), Sketch.fill(_faint));
        }
      }
      x += w;
      i++;
    }
  }

  static void _mountains(Canvas c) {
    for (final (pts, seed, color) in [
      ([const Offset(-40, Field.ground), const Offset(180, 200), const Offset(330, 330), const Offset(470, 170), const Offset(700, Field.ground)], 90, _faint),
      ([const Offset(380, Field.ground), const Offset(640, 230), const Offset(780, 300), const Offset(900, 210), const Offset(1020, Field.ground)], 91, _soft),
    ]) {
      c.drawPath(Sketch.polygon(pts, seed: seed), _pen(2.2, color));
    }
    // 雪
    for (final peak in const [Offset(180, 200), Offset(470, 170), Offset(640, 230), Offset(900, 210)]) {
      c.drawPath(
        Path()
          ..moveTo(peak.dx - 26, peak.dy + 30)
          ..lineTo(peak.dx - 10, peak.dy + 22)
          ..lineTo(peak.dx, peak.dy + 32)
          ..lineTo(peak.dx + 12, peak.dy + 22)
          ..lineTo(peak.dx + 26, peak.dy + 30),
        _pen(1.6, _faint),
      );
    }
  }

  static void _bunting(Canvas c, double time, {double y = 60}) {
    final path = Path()..moveTo(0, y);
    for (var x = 0.0; x <= Field.width; x += 20) {
      path.lineTo(x, y + math.sin(x / Field.width * math.pi) * 40);
    }
    c.drawPath(path, _pen(1.6));
    for (var x = 30.0; x < Field.width; x += 60) {
      final top = y + math.sin(x / Field.width * math.pi) * 40;
      final sway = math.sin(time * 2 + x / 50) * 3;
      final flag = Path()
        ..moveTo(x - 12, top)
        ..lineTo(x + 12, top)
        ..lineTo(x + sway, top + 24)
        ..close();
      c.drawPath(flag, Sketch.fill(((x ~/ 60) % 2 == 0 ? _soft : _faint)));
    }
  }

  static void _crowd(Canvas c, double time) {
    // 3段の客席に、丸い頭の観客がゆれる
    for (var row = 0; row < 3; row++) {
      final y = 150.0 + row * 70;
      c.drawPath(Sketch.line(Offset(0, y + 34), Offset(Field.width, y + 34), seed: 100 + row), _pen(2, _faint));
      for (var x = 20.0 + row * 18; x < Field.width; x += 44) {
        final bob = math.sin(time * 4 + x * 0.3 + row) * 3;
        final cheer = math.sin(time * 1.3 + x * 0.11) > 0.85;
        final head = Offset(x, y + bob);
        c.drawPath(Sketch.circle(head, 11, seed: (x + row).toInt()), _pen(1.8, row == 2 ? _soft : _faint));
        c.drawLine(head + const Offset(0, 11), head + const Offset(0, 30), _pen(1.8, _faint));
        if (cheer) {
          c
            ..drawLine(head + const Offset(0, 16), head + const Offset(-10, 0), _pen(1.6, _faint))
            ..drawLine(head + const Offset(0, 16), head + const Offset(10, 0), _pen(1.6, _faint));
        }
      }
    }
  }

  /// 試合前に、ステージの名前を地面の下に出す（2台で半分ずつ映すので、左右それぞれの側に）
  static void label(Canvas c, Stage stage) {
    for (final x in const [Field.center / 2, Field.center * 1.5]) {
      drawText(c, 'ステージ: ${stage.label}', Offset(x, Field.ground + 40), size: 18, color: Palette.pencil);
    }
  }
}
