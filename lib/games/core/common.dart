import 'dart:math' as math;

/// 全タイトル共通の座標系。論理座標は 960x540、y は下向きが正、ground は地面の高さ。
abstract final class Field {
  static const width = 960.0;
  static const height = 540.0;
  static const ground = 470.0;
  static const center = width / 2;
}

double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

double approach(double v, double target, double delta) => v < target ? math.min(v + delta, target) : math.max(v - delta, target);

/// 左側(0)のプレイヤーは右(+1)を、右側(1)は左(-1)を向く
double facing(int side) => side == 0 ? 1 : -1;

/// 小数第2位までに丸める（送る量を減らす）
double r2(double v) => (v * 100).roundToDouble() / 100;

double numD(Object? v) => (v as num?)?.toDouble() ?? 0;

/// 1フレーム分の入力。押した瞬間（jumpPressed / actPressed）は押下回数の差から作る。
class PlayerInput {
  const PlayerInput({
    this.left = false,
    this.right = false,
    this.jump = false,
    this.act = false,
    this.jumpPressed = false,
    this.actPressed = false,
    this.stamp,
  });

  /// このフレームで送ったスタンプ（[Stamp] の番号）
  final int? stamp;

  final bool left;
  final bool right;
  final bool jump;
  final bool act;
  final bool jumpPressed;
  final bool actPressed;

  double get axis => (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0);

  static const none = PlayerInput();

  PlayerInput copyWith({bool? jump, bool? jumpPressed}) => PlayerInput(
        left: left,
        right: right,
        jump: jump ?? this.jump,
        act: act,
        jumpPressed: jumpPressed ?? this.jumpPressed,
        actPressed: actPressed,
        stamp: stamp,
      );
}

/// キーボードの状態。押しっぱなしは状態、連打は通算の押下回数で表すので、通信の間隔に関係なく取りこぼさない。
class KeyState {
  const KeyState({this.l = false, this.r = false, this.j = false, this.a = false, this.jc = 0, this.ac = 0, this.st = 0, this.sc = 0});

  /// 最後に押したスタンプの番号と、スタンプを押した通算の回数（回数が増えたら送ったとみなす）
  final int st;
  final int sc;

  final bool l;
  final bool r;
  final bool j;
  final bool a;
  final int jc;
  final int ac;

  Map<String, Object> toJson() => {'l': l, 'r': r, 'j': j, 'a': a, 'jc': jc, 'ac': ac, if (sc != 0) 'st': st, if (sc != 0) 'sc': sc};

  static KeyState fromJson(Map<String, Object?> m) => KeyState(
        l: m['l'] == true,
        r: m['r'] == true,
        j: m['j'] == true,
        a: m['a'] == true,
        jc: (m['jc'] as num?)?.toInt() ?? 0,
        ac: (m['ac'] as num?)?.toInt() ?? 0,
        st: (m['st'] as num?)?.toInt() ?? 0,
        sc: (m['sc'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is KeyState && other.l == l && other.r == r && other.j == j && other.a == a && other.jc == jc && other.ac == ac && other.st == st && other.sc == sc;

  @override
  int get hashCode => Object.hash(l, r, j, a, jc, ac, st, sc);
}

/// 押下回数の差分から「押した瞬間」を取り出す。試合開始・再接続後の最初の状態を基準にする。
class PressTracker {
  (int, int, int)? _seen;

  void reset() => _seen = null;

  void baseline(KeyState k) => _seen ??= (k.jc, k.ac, k.sc);

  PlayerInput input(KeyState k, {required bool connected}) {
    if (!connected) {
      if (_seen != null) _seen = (k.jc, k.ac, k.sc);
      return PlayerInput.none;
    }
    final s = _seen;
    if (s == null) return PlayerInput(left: k.l, right: k.r, jump: k.j, act: k.a);
    _seen = (k.jc, k.ac, k.sc);
    return PlayerInput(
      left: k.l,
      right: k.r,
      jump: k.j,
      act: k.a,
      jumpPressed: k.jc != s.$1,
      actPressed: k.ac != s.$2,
      stamp: k.sc != s.$3 ? k.st : null,
    );
  }
}

/// 試合中に送れるスタンプ（数字キーの 1〜4）
enum Stamp {
  nice('ナイス！'),
  oshii('おしい！'),
  more('まだまだ！'),
  sorry('ごめん！');

  const Stamp(this.text);
  final String text;

  static Stamp? byName(String? n) => n == null ? null : values.asNameMap()[n];

  static Stamp? of(int? i) => i == null || i < 0 || i >= values.length ? null : values[i];
}

/// 試合中の出来事（効果音・演出用）
class GameEvent {
  const GameEvent(this.type, {this.side, this.x, this.y, this.q});

  final String type;

  /// 当てたタイミング（[Timing] の名前。'just' / 'early' / 'late' / 'close'）。null はふつう
  final String? q;
  final int? side;
  final double? x;
  final double? y;

  Map<String, Object?> toJson() => {
        't': type,
        if (side != null) 's': side,
        if (x != null) 'x': r2(x!),
        if (y != null) 'y': r2(y!),
        if (q != null) 'q': q,
      };

  static GameEvent fromJson(Map<String, Object?> m) =>
      GameEvent(m['t'] as String, side: (m['s'] as num?)?.toInt(), x: (m['x'] as num?)?.toDouble(), y: (m['y'] as num?)?.toDouble(), q: m['q'] as String?);
}

/// 攻撃を当てたタイミングの出来。ジャストは強く、早すぎ・遅すぎ・近すぎは弱くなる
enum Timing {
  just('JUST!'),
  normal(''),
  early('はやい'),
  late('おそい'),
  close('ちかい');

  const Timing(this.label);
  final String label;

  bool get weak => this == early || this == late || this == close;

  /// 送るときの名前（ふつうは送らない）
  String? get wire => this == normal ? null : name;

  static Timing of(String? q) => q == null ? normal : (values.asNameMap()[q] ?? normal);
}

sealed class StepResult {}

/// side: 得点した側（null は相打ちなど得点なし）
class PointResult extends StepResult {
  PointResult(this.side, this.reason, {this.landX});
  final int? side;
  final String reason;
  final double? landX;
}

/// winner: 勝者（-1 は引き分け）
class EndResult extends StepResult {
  EndResult(this.winner, this.reason);
  final int winner;
  final String reason;
}

enum ServeRule {
  /// 得点ごとにサーブ交代
  alternate,

  /// 得点した側がサーブ
  winner,
  none,
}

/// 試合中の世界の状態。部屋を作ったPC（ホスト）が計算して、そのまま相手に送る。
abstract class GameWorld {
  Map<String, Object?> toJson();
}

abstract class SportRules {
  int? get winScore;
  ServeRule get serveRule;
  GameWorld makeWorld();
  GameWorld worldFromJson(Map<String, Object?> json);
  void serve(GameWorld world, int? server);
  StepResult? step(GameWorld world, List<PlayerInput> inputs, double dt, List<GameEvent> events, List<int> score);
}

// ---------------------------------------------------------------------------
// 横移動＋ジャンプする選手（バレー・バドミントン）

class RunnerParams {
  const RunnerParams({
    required this.speed,
    required this.accel,
    required this.airAccel,
    required this.jumpV,
    required this.gravity,
    required this.swingTime,
    required this.swingCooldown,
    this.minX = 0,
    this.maxX = Field.width,
  });

  final double speed;
  final double accel;
  final double airAccel;
  final double jumpV;
  final double gravity;
  final double swingTime;
  final double swingCooldown;
  final double minX;
  final double maxX;

  RunnerParams within(double minX, double maxX) => RunnerParams(
        speed: speed,
        accel: accel,
        airAccel: airAccel,
        jumpV: jumpV,
        gravity: gravity,
        swingTime: swingTime,
        swingCooldown: swingCooldown,
        minX: minX,
        maxX: maxX,
      );
}

class Runner {
  Runner(this.side, this.x);

  final int side;
  double x;
  double y = Field.ground;
  double vx = 0;
  double vy = 0;
  bool onGround = true;
  double jumpBuf = 0;
  double actBuf = 0;
  double swing = 0;
  bool swingHit = false;
  double cd = 0;

  /// 振らずにボールが届く範囲にあった時間（遅すぎの判定用）
  double reachClock = 0;

  /// 振り始めたとき、ボールがすでに届く範囲にあった時間
  double lateBy = 0;

  /// 1フレーム進める。振り始めたら true。
  bool step(PlayerInput inp, double dt, RunnerParams o) {
    final accel = onGround ? o.accel : o.airAccel;
    vx = approach(vx, inp.axis * o.speed, accel * dt);

    jumpBuf = inp.jumpPressed ? 0.12 : math.max(0, jumpBuf - dt);
    if (onGround && (jumpBuf > 0 || inp.jump)) {
      vy = -o.jumpV;
      onGround = false;
      jumpBuf = 0;
    }
    vy += o.gravity * dt;
    x += vx * dt;
    y += vy * dt;
    if (y >= Field.ground) {
      y = Field.ground;
      vy = 0;
      onGround = true;
    }
    if (x < o.minX) {
      x = o.minX;
      vx = 0;
    }
    if (x > o.maxX) {
      x = o.maxX;
      vx = 0;
    }

    // 振り（J）: 押した瞬間だけ受け付け、少しの先行入力を許す
    actBuf = inp.actPressed ? 0.1 : math.max(0, actBuf - dt);
    cd = math.max(0, cd - dt);
    swing = math.max(0, swing - dt);
    if (actBuf > 0 && cd <= 0) {
      swing = o.swingTime;
      cd = o.swingCooldown;
      swingHit = false;
      actBuf = 0;
      return true;
    }
    return false;
  }

  /// 描画に必要な分だけ送る
  Map<String, Object?> toJson() => {'s': side, 'x': r2(x), 'y': r2(y), 'vx': r2(vx), 'g': onGround, 'w': r2(swing)};

  static Runner fromJson(Map<String, Object?> m) => Runner((m['s'] as num).toInt(), numD(m['x']))
    ..y = numD(m['y'])
    ..vx = numD(m['vx'])
    ..onGround = m['g'] == true
    ..swing = numD(m['w']);
}

class Ball {
  Ball(this.r);

  final double r;
  double x = 0;
  double y = 0;
  double vx = 0;
  double vy = 0;

  Map<String, Object?> toJson() => {'x': r2(x), 'y': r2(y), 'vx': r2(vx), 'vy': r2(vy), 'r': r};

  static Ball fromJson(Map<String, Object?> m) => Ball(numD(m['r']))
    ..x = numD(m['x'])
    ..y = numD(m['y'])
    ..vx = numD(m['vx'])
    ..vy = numD(m['vy']);
}

class Net {
  const Net({required this.top, required this.bounce, this.x = Field.center, this.w = 8});

  final double x;
  final double w;
  final double top;
  final double bounce;
}

/// 網（縦長の長方形）とボールの衝突。当たったら true。
bool collideNet(Ball ball, Net net) {
  final left = net.x - net.w / 2;
  final right = net.x + net.w / 2;
  final nx0 = clampD(ball.x, left, right);
  final ny0 = clampD(ball.y, net.top, Field.ground);
  final dx = ball.x - nx0;
  final dy = ball.y - ny0;
  final d2 = dx * dx + dy * dy;
  if (d2 >= ball.r * ball.r) return false;
  if (dx == 0 && dy == 0) {
    // 中心が網の中に入り込んだら来た方向へ押し戻す
    ball.x = ball.vx > 0 ? left - ball.r : right + ball.r;
    ball.vx = -ball.vx * net.bounce;
    return true;
  }
  final d = math.max(math.sqrt(d2), 0.0001);
  final nx = dx / d;
  final ny = dy / d;
  ball.x = nx0 + nx * ball.r;
  ball.y = ny0 + ny * ball.r;
  final vn = ball.vx * nx + ball.vy * ny;
  if (vn < 0) {
    ball.vx -= (1 + net.bounce) * vn * nx;
    ball.vy -= (1 + net.bounce) * vn * ny;
  }
  return true;
}
