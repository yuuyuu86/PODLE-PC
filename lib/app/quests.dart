import '../games/core/catalog.dart';
import 'records.dart';

/// 今日のクエスト1つ。進み具合は今日の対戦記録から数える。
class Quest {
  const Quest({required this.id, required this.title, required this.goal, required this.reward, required this.count});

  final String id;
  final String title;
  final int goal;
  final int reward;
  final int Function(List<MatchRecord> today) count;

  int progress(List<MatchRecord> today) => count(today).clamp(0, goal);
  bool done(List<MatchRecord> today) => count(today) >= goal;
}

class DailyQuests {
  /// 日付の目印（例: 2026-11-02）
  static String dayKey(DateTime now) => '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  static List<MatchRecord> today(List<MatchRecord> all, DateTime now) =>
      [for (final r in all) if (r.at.year == now.year && r.at.month == now.month && r.at.day == now.day) r];

  /// その日のクエスト3つ（日付で決まるので、同じ日は何度開いても同じ）
  static List<Quest> forDay(DateTime now) {
    final seed = now.year * 400 + now.month * 32 + now.day;
    final game = GameKind.values[seed % GameKind.values.length];
    final plays = 2 + seed % 2;
    return [
      Quest(id: 'play', title: '$plays回 試合をする', goal: plays, reward: 50, count: (t) => t.length),
      Quest(id: 'win', title: '1回 勝つ', goal: 1, reward: 80, count: (t) => t.where((r) => r.won == true).length),
      Quest(id: 'game', title: '${game.title}で 1回 あそぶ', goal: 1, reward: 60, count: (t) => t.where((r) => r.game == game).length),
    ];
  }
}
