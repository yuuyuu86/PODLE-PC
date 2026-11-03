import '../games/core/catalog.dart';
import 'records.dart';

/// クエストの難しさ。ほうびのコインは難しさに比例する
enum QuestLevel {
  easy('かんたん', 1),
  normal('ふつう', 2),
  hard('むずかしい', 4);

  const QuestLevel(this.label, this.stars);
  final String label;
  final int stars;

  /// 1つ星あたりのコイン
  static const coinPerStar = 20;
  int get reward => stars * coinPerStar;
}

/// 今日のクエスト1つ。進み具合は今日の対戦記録から数える。
class Quest {
  const Quest({required this.id, required this.title, required this.goal, required this.level, required this.count});

  final String id;
  final String title;
  final int goal;
  final QuestLevel level;
  final int Function(List<MatchRecord> today) count;

  int get reward => level.reward;
  int progress(List<MatchRecord> today) => count(today).clamp(0, goal);
  bool done(List<MatchRecord> today) => count(today) >= goal;
}

class DailyQuests {
  /// 3つ全部を受け取ると、もう1回もらえるおまけ
  static const bonusId = 'all';
  static const bonus = 60;

  /// 1日で最大もらえるコイン（かんたん20 + ふつう40 + むずかしい80 + おまけ60 = 200）
  static int get maxPerDay => QuestLevel.values.fold(0, (s, l) => s + l.reward) + bonus;

  /// 日付の目印（例: 2026-11-02）
  static String dayKey(DateTime now) => '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  static List<MatchRecord> today(List<MatchRecord> all, DateTime now) =>
      [for (final r in all) if (r.at.year == now.year && r.at.month == now.month && r.at.day == now.day) r];

  /// 次にクエストが入れかわるまで（夜中の0時）
  static Duration untilReset(DateTime now) => DateTime(now.year, now.month, now.day + 1).difference(now);

  /// 連続で勝った一番長い数
  static int _streak(List<MatchRecord> t) {
    final list = [...t]..sort((a, b) => a.at.compareTo(b.at));
    var best = 0, cur = 0;
    for (final r in list) {
      cur = r.won == true ? cur + 1 : 0;
      if (cur > best) best = cur;
    }
    return best;
  }

  /// その日のクエスト（かんたん・ふつう・むずかしい 1つずつ）。日付で決まるので、同じ日は何度開いても同じ
  static List<Quest> forDay(DateTime now) {
    final seed = now.year * 400 + now.month * 32 + now.day;
    final g1 = GameKind.values[seed % GameKind.values.length];
    final g2 = GameKind.values[(seed + 2) % GameKind.values.length];
    final easy = [
      Quest(id: 'play', title: '1回 試合をする', goal: 1, level: QuestLevel.easy, count: (t) => t.length),
      Quest(id: 'game', title: '${g1.title}で 1回 あそぶ', goal: 1, level: QuestLevel.easy, count: (t) => t.where((r) => r.game == g1).length),
    ];
    final normal = [
      Quest(id: 'win', title: '1回 勝つ', goal: 1, level: QuestLevel.normal, count: (t) => t.where((r) => r.won == true).length),
      Quest(id: 'play3', title: '3回 試合をする', goal: 3, level: QuestLevel.normal, count: (t) => t.length),
      Quest(id: 'kinds', title: 'ちがう競技を 2つ あそぶ', goal: 2, level: QuestLevel.normal, count: (t) => t.map((r) => r.game).toSet().length),
    ];
    final hard = [
      Quest(id: 'win3', title: '3回 勝つ', goal: 3, level: QuestLevel.hard, count: (t) => t.where((r) => r.won == true).length),
      Quest(id: 'streak', title: '2連勝する', goal: 2, level: QuestLevel.hard, count: _streak),
      Quest(id: 'gwin', title: '${g2.title}で 2回 勝つ', goal: 2, level: QuestLevel.hard, count: (t) => t.where((r) => r.game == g2 && r.won == true).length),
      Quest(id: 'big', title: '3点差以上で 勝つ', goal: 1, level: QuestLevel.hard, count: (t) => t.where((r) => r.won == true && r.myScore - r.opponentScore >= 3).length),
    ];
    return [easy[seed % easy.length], normal[(seed ~/ 2) % normal.length], hard[(seed ~/ 3) % hard.length]];
  }

  /// 今日、受け取れる（達成して、まだ受け取っていない）ものがあるか
  static bool hasClaimable(List<MatchRecord> all, Set<String> claimed, DateTime now) {
    final today = DailyQuests.today(all, now);
    final qs = forDay(now);
    if (qs.any((q) => q.done(today) && !claimed.contains(q.id))) return true;
    return qs.every((q) => claimed.contains(q.id)) && !claimed.contains(bonusId);
  }
}
