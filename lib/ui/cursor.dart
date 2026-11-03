import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'doodle.dart';

enum _Shape { arrow, hand, text }

/// マウスカーソルを落書き風にする。OS のカーソルは隠し、ペンで描いたような矢印・指・Iビームを
/// マウスの位置に描く。下にあるボタンなどが求めるカーソル（クリック・文字入力）に合わせて形を変える。
class DoodleCursor extends StatefulWidget {
  const DoodleCursor({super.key, required this.child});
  final Widget child;

  @override
  State<DoodleCursor> createState() => _DoodleCursorState();
}

class _CursorState {
  const _CursorState(this.pos, this.shape, this.down);
  final Offset? pos;
  final _Shape shape;
  final bool down;
}

class _DoodleCursorState extends State<DoodleCursor> {
  final _state = ValueNotifier(const _CursorState(null, _Shape.arrow, false));
  final _selfKey = GlobalKey();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  /// その位置で、自分以外の一番上の MouseRegion が求めるカーソルを調べる
  _Shape _shapeAt(Offset global) {
    final view = View.of(context);
    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(result, global, view.viewId);
    final self = _selfKey.currentContext?.findRenderObject();
    for (final e in result.path) {
      final t = e.target;
      if (t == self || t is! MouseTrackerAnnotation) continue;
      final c = (t as MouseTrackerAnnotation).cursor;
      if (c == MouseCursor.defer) continue;
      if (c == SystemMouseCursors.click) return _Shape.hand;
      if (c == SystemMouseCursors.text) return _Shape.text;
      return _Shape.arrow;
    }
    return _Shape.arrow;
  }

  void _move(PointerEvent e, {bool? down}) {
    if (e.kind != PointerDeviceKind.mouse) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    _state.value = _CursorState(box.globalToLocal(e.position), _shapeAt(e.position), down ?? _state.value.down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _move(e, down: true),
      onPointerUp: (e) => _move(e, down: false),
      onPointerMove: _move,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          // 一番上で OS のカーソルを隠す（opaque: false なので下の操作はそのまま届く）
          Positioned.fill(
            child: MouseRegion(
              key: _selfKey,
              opaque: false,
              hitTestBehavior: HitTestBehavior.translucent,
              cursor: SystemMouseCursors.none,
              onHover: _move,
              onExit: (_) => _state.value = _CursorState(null, _state.value.shape, false),
            ),
          ),
          IgnorePointer(
            child: ValueListenableBuilder(
              valueListenable: _state,
              builder: (context, s, _) => s.pos == null ? const SizedBox.shrink() : CustomPaint(painter: _CursorPainter(s), size: Size.infinite),
            ),
          ),
        ],
      ),
    );
  }
}

class _CursorPainter extends CustomPainter {
  _CursorPainter(this.s);
  final _CursorState s;

  @override
  void paint(Canvas canvas, Size size) {
    final p = s.pos!;
    canvas.save();
    canvas.translate(p.dx, p.dy);
    if (s.down) canvas.scale(0.88);
    final ink = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = Palette.paper;
    final shadow = Paint()..color = Palette.faint;
    switch (s.shape) {
      case _Shape.arrow:
        final path = Path()
          ..moveTo(0, 0)
          ..lineTo(0.6, 19)
          ..lineTo(5.2, 14.6)
          ..lineTo(9.2, 22.6)
          ..lineTo(12.6, 21)
          ..lineTo(8.8, 13.2)
          ..lineTo(14.8, 12.6)
          ..close();
        canvas.drawPath(path.shift(const Offset(2, 2)), shadow);
        canvas.drawPath(path, fill);
        canvas.drawPath(path, ink);
        // ペンの二度描き
        canvas.drawLine(const Offset(1.4, 2.2), const Offset(1.8, 15), ink..strokeWidth = 1);
      case _Shape.hand:
        // 指さす手（指先が位置）
        canvas.translate(-6, -1);
        final hand = Path()
          ..moveTo(4, 12)
          ..lineTo(4, 2.5)
          ..quadraticBezierTo(6, -0.5, 8, 2.5)
          ..lineTo(8, 10)
          ..quadraticBezierTo(10, 8, 12, 10.5)
          ..quadraticBezierTo(14, 9, 15.6, 11.5)
          ..quadraticBezierTo(17.6, 10.5, 19, 13)
          ..lineTo(19, 19)
          ..quadraticBezierTo(18, 24, 13, 24.5)
          ..lineTo(8.5, 24.5)
          ..quadraticBezierTo(5, 24, 3, 20)
          ..lineTo(0.6, 15.5)
          ..quadraticBezierTo(0.5, 12, 4, 14.5)
          ..close();
        canvas.drawPath(hand.shift(const Offset(2, 2)), shadow);
        canvas.drawPath(hand, fill);
        canvas.drawPath(hand, ink);
        final thin = Paint()
          ..color = Palette.ink
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(12, 10.8), const Offset(12, 15), thin);
        canvas.drawLine(const Offset(15.6, 11.8), const Offset(15.6, 15.5), thin);
        if (s.down) {
          // 押したときの小さな線
          for (var i = 0; i < 3; i++) {
            final a = -math.pi / 2 + (i - 1) * 0.7;
            final o = const Offset(6, -2);
            canvas.drawLine(o + Offset(math.cos(a), math.sin(a)) * 4, o + Offset(math.cos(a), math.sin(a)) * 8, thin);
          }
        }
      case _Shape.text:
        final t = Paint()
          ..color = Palette.ink
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(0.4, -9), const Offset(-0.3, 9), t);
        canvas.drawLine(const Offset(-4, -10), const Offset(4, -9.4), t);
        canvas.drawLine(const Offset(-4, 9.6), const Offset(4, 9), t);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CursorPainter old) => old.s != s;
}
