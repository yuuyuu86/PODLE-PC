import '../badminton/badminton.dart';
import '../boxing/boxing.dart';
import '../fencing/fencing.dart';
import '../sumo/sumo.dart';
import '../tug/tug.dart';
import '../volley/volley.dart';
import 'common.dart';
import 'painting.dart';

class GameControl {
  const GameControl(this.key, this.label);
  final String key;
  final String label;
}

/// 収録タイトル。新しいゲームを足すときは値を1つ増やし、ルール・描画・説明を返す。
enum GameKind {
  volley(
    title: 'バレー',
    tagline: 'ジャンプとタイミングのラリー',
    summary: '高いネットを挟んで打ち合う。自分のコートで3回まで触れるので、トスを上げて跳んでスパイク！ 相手のスパイクはネット際のブロックで止められるが、フェイントには弱い。',
    ruleText: '先に5点で勝ち。得点ごとにサーブ交代。',
    controls: [
      GameControl('A / D', '左右に移動'),
      GameControl('Space', 'ジャンプ'),
      GameControl('J', '打つ（ジャンプ中の高い打点でスパイク）'),
      GameControl('後ろ + J', '真上にトス（ジャンプ中ならフェイント）'),
      GameControl('ジャンプ中 Space', 'ネット際でブロック'),
    ],
  ),
  badminton(
    title: 'バドミントン',
    tagline: '失速するシャトルの落下点を読む',
    summary: 'シャトルは速く飛び出して急に失速する。入力の向きでクリアとドロップを打ち分け、高い打点ならスマッシュ。踏み込みステップで落下点に追いつこう（連発すると固まる）。',
    ruleText: '先に5点で勝ち。1人1回で返す。得点した側がサーブ。',
    controls: [
      GameControl('A / D', '左右に移動'),
      GameControl('Space', 'ジャンプ'),
      GameControl('J', '打つ（前+J ドロップ / 後ろ+J クリア）'),
      GameControl('ジャンプ中 J', '高い打点でスマッシュ'),
      GameControl('A A / D D', 'すばやく2回で踏み込みステップ'),
    ],
  ),
  fencing(
    title: 'フェンシング',
    tagline: '間合いと突きのタイミング',
    summary: '中央線を挟んで構え、前後に間合いを測る。突きは踏み込んで届くが、パリィされると隙だらけ。J をためると遠くまで届くが、構えが見えて読まれやすく、外すと長く固まる。',
    ruleText: '先に5点で勝ち。同時の突きは相打ち。後ろの端から出ると相手の得点。',
    controls: [
      GameControl('A / D', '前後に移動'),
      GameControl('J', '突き（踏み込む）'),
      GameControl('J 長押し→離す', 'ため突き（遠くまで届く）'),
      GameControl('Space', 'パリィ（短い受け流し）'),
    ],
  ),
  boxing(
    title: 'ボクシング',
    tagline: '移動・ガード・パンチの読み合い',
    summary: 'リングで向かい合う。ガードで受け止め、相手の振りかぶりにパンチを合わせればカウンター。前+J で踏み込み、後ろ+J で下がりながら打てる。',
    ruleText: '体力0でKO。60秒たったら有効打が多い方の勝ち。',
    controls: [
      GameControl('A / D', '左右に移動'),
      GameControl('J', 'パンチ'),
      GameControl('前 + J', '踏み込みパンチ（外すと隙）'),
      GameControl('後ろ + J', '下がりながらパンチ（弱い）'),
      GameControl('Space 長押し', 'ガード'),
    ],
  ),
  tug(
    title: '綱引き',
    tagline: 'リズムで引く、ふんばって耐える',
    summary: '1本の綱が2台の画面をまたぐ。J をリズムよく押して引き、真ん中の旗を自分の側の線まで引き込んだら1点。連打しすぎると力が入らない。Space でふんばると引かれにくいが、その間は引けない。',
    ruleText: '先に5点で勝ち。',
    controls: [
      GameControl('J', '引く（ちょうどいい間隔で JUST!）'),
      GameControl('Space 長押し', 'ふんばる（ゲージが減る）'),
    ],
  ),
  sumo(
    title: 'すもう',
    tagline: '押す・つっぱる・はたくの読み合い',
    summary: '土俵で押し合い、相手を外へ出したら1点。つっぱりは強いが、ふんばられると効かない。前に出てくる相手ははたきでつんのめらせられるが、ふんばっている相手には空振りで隙だらけ。',
    ruleText: '先に5点で勝ち。土俵の外に出たら負け。',
    controls: [
      GameControl('A / D', '歩く（前へ歩くと押す）'),
      GameControl('J', 'つっぱり'),
      GameControl('後ろ + J', 'はたき（出てくる相手に）'),
      GameControl('Space 長押し', 'ふんばる'),
    ],
  );

  const GameKind({required this.title, required this.tagline, required this.summary, required this.ruleText, required this.controls});

  final String title;
  final String tagline;
  final String summary;
  final String ruleText;
  final List<GameControl> controls;

  SportRules get rules => switch (this) {
        volley => VolleyRules.instance,
        badminton => BadmintonRules.instance,
        fencing => FencingRules.instance,
        boxing => BoxingRules.instance,
        tug => TugRules.instance,
        sumo => SumoRules.instance,
      };

  SportPainter get painter => switch (this) {
        volley => const VolleyPainter(),
        badminton => const BadmintonPainter(),
        fencing => const FencingPainter(),
        boxing => const BoxingPainter(),
        tug => const TugPainter(),
        sumo => const SumoPainter(),
      };

  /// あとから足した競技（古い版の相手とは遊べない）
  bool get newer => this == tug || this == sumo;

  /// 2台を並べたとき、コートを半分ずつ映すか（いまは全競技。2台の画面がつながって1つのコートになる）
  bool get splitCourt => true;

  /// 部屋を作るときに選べるルール。ボクシングは試合時間（秒）、ほかは何点先取か。
  List<int> get ruleChoices => this == boxing ? const [30, 60, 90] : const [3, 5, 7, 11];

  /// 何も選ばないときのルール（これまでと同じ）
  int get defaultRule => this == boxing ? 60 : 5;

  /// 選んだルールに合わせた説明
  String ruleTextFor(int rule) => ruleText.replaceFirst(this == boxing ? '60秒' : '先に5点', this == boxing ? '$rule秒' : '先に$rule点');

  String ruleLabel(int rule) => this == boxing ? '$rule秒' : '$rule点先取';

  /// 結果やスコアの単位（ボクシングは有効打の数）
  String? get scoreUnit => this == boxing ? '有効打' : null;
}
