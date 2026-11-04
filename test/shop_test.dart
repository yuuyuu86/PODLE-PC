import 'package:flutter_test/flutter_test.dart';
import 'package:podle_pc/app/quests.dart';
import 'package:podle_pc/app/records.dart';
import 'package:podle_pc/app/settings.dart';
import 'package:podle_pc/avatar/avatar.dart';
import 'package:podle_pc/games/core/catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

MatchRecord rec(DateTime at, {bool? won = true, GameKind game = GameKind.volley}) =>
    MatchRecord(at: at, game: game, rule: 5, opponent: 'a', opponentAvatar: '', myScore: 5, opponentScore: 1, won: won);

void main() {
  late AppSettings s;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    s = await AppSettings.load();
  });

  test('コインが足りないと買えず、足りれば1回だけ買える', () {
    expect(s.owns(AvatarPart.top, 6), isFalse);
    expect(s.buy(AvatarPart.top, 6), isFalse);
    s.addCoins(1050);
    expect(s.buy(AvatarPart.top, 6), isTrue);
    expect(s.coins, 50);
    expect(s.owns(AvatarPart.top, 6), isTrue);
    expect(s.buy(AvatarPart.top, 6), isFalse);
    expect(s.coins, 50);
  });

  test('最初から使えるパーツは買わなくても持っている', () {
    for (final p in AvatarPart.values) {
      expect(s.owns(p, 0), isTrue);
    }
  });

  test('おまかせは持っているパーツだけから選ぶ', () {
    for (var i = 0; i < 200; i++) {
      final a = Avatar.random();
      for (final p in AvatarPart.values) {
        expect(Avatar.price(p, a[p]), 0);
      }
    }
  });

  test('クエストは同じ日に1回だけ受け取れ、日が変わると受け取り直せる', () {
    s.claimQuest('2026-11-02', 'win', 80);
    s.claimQuest('2026-11-02', 'win', 80);
    expect(s.coins, 80);
    expect(s.claimedQuests('2026-11-02'), {'win'});
    expect(s.claimedQuests('2026-11-03'), isEmpty);
    s.claimQuest('2026-11-03', 'win', 80);
    expect(s.coins, 160);
  });

  test('クエストの進み具合は今日の記録だけで数える', () {
    final now = DateTime(2026, 11, 2, 15);
    final all = [rec(now), rec(now, won: false), rec(DateTime(2026, 11, 1, 23))];
    final today = DailyQuests.today(all, now);
    expect(today.length, 2);
    final win = Quest(id: 'win', title: '', goal: 1, level: QuestLevel.normal, count: (t) => t.where((r) => r.won == true).length);
    expect(win.done(today), isTrue);
    final play = Quest(id: 'play', title: '', goal: 3, level: QuestLevel.normal, count: (t) => t.length);
    expect(play.progress(today), 2);
  });

  test('クエストは毎日 かんたん・ふつう・むずかしい が1つずつで、ほうびは難しさに比例する', () {
    for (var d = 0; d < 60; d++) {
      final qs = DailyQuests.forDay(DateTime(2026, 11, 1).add(Duration(days: d)));
      expect(qs.map((q) => q.level), QuestLevel.values);
      expect(qs.map((q) => q.id).toSet().length, 3);
      for (final q in qs) {
        expect(q.reward, q.level.stars * QuestLevel.coinPerStar);
      }
    }
    expect(DailyQuests.maxPerDay, 200);
  });

  test('3つ全部受け取ると、おまけを受け取れる', () {
    final now = DateTime.now();
    final day = DailyQuests.dayKey(now);
    final qs = DailyQuests.forDay(now);
    expect(DailyQuests.hasClaimable(const [], s.claimedQuests(day), now), isFalse);
    for (final q in qs) {
      s.claimQuest(day, q.id, q.reward);
    }
    expect(DailyQuests.hasClaimable(const [], s.claimedQuests(day), now), isTrue);
    s.claimQuest(day, DailyQuests.bonusId, DailyQuests.bonus);
    expect(s.coins, DailyQuests.maxPerDay);
    expect(DailyQuests.hasClaimable(const [], s.claimedQuests(day), now), isFalse);
  });

  test('値段は、1日の最大コインで 2日〜1週間ほどかかる', () {
    for (final e in Avatar.prices.values) {
      for (final p in e.values) {
        expect(p / DailyQuests.maxPerDay, inInclusiveRange(1.5, 7.0));
      }
    }
  });

  test('値段のついたパーツはすべて実在する', () {
    for (final e in Avatar.prices.entries) {
      for (final i in e.value.keys) {
        expect(i, lessThan(e.key.options.length));
      }
    }
  });

  test('ふつうに増えたコインは、次に起動しても残る', () async {
    s.addCoins(350);
    s.buy(AvatarPart.face, 6);
    final again = await AppSettings.load();
    expect(again.tampered, isFalse);
    expect(again.coins, 0);
    expect(again.owns(AvatarPart.face, 6), isTrue);
  });

  test('保存データのコインを書きかえると、コインと買ったものが消える', () async {
    s.addCoins(1400);
    s.buy(AvatarPart.top, 11);
    s.avatar = s.avatar.withChoice(AvatarPart.top, 11);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', 99999);
    final again = await AppSettings.load();
    expect(again.tampered, isTrue);
    expect(again.coins, 0);
    expect(again.owns(AvatarPart.top, 11), isFalse);
    expect(again.avatar[AvatarPart.top], 0);
    final today = DailyQuests.dayKey(DateTime.now());
    expect(again.questsLocked(today), isTrue);
    again.claimQuest(today, 'win', 80);
    expect(again.coins, 0);
    // 直したあとは、またふつうに使える
    expect((await AppSettings.load()).tampered, isFalse);
  });

  test('対戦記録を書き足すと、書き換えとして扱う', () async {
    s.addCoins(10);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('records', MatchRecord.encodeList([rec(DateTime.now()), rec(DateTime.now())]));
    expect((await AppSettings.load()).tampered, isTrue);
  });

  test('しるしを消しても、コインがあれば書き換えとして扱う', () async {
    s.addCoins(10);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sig');
    expect((await AppSettings.load()).tampered, isTrue);
  });

  test('しるしのない古い版のデータは、そのまま使える', () async {
    SharedPreferences.setMockInitialValues({'records': MatchRecord.encodeList([rec(DateTime(2026, 10, 1))])});
    final old = await AppSettings.load();
    expect(old.tampered, isFalse);
    expect(old.records.length, 1);
    expect((await AppSettings.load()).tampered, isFalse);
  });
}
