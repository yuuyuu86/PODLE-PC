import 'package:flutter/material.dart';

import '../app/app_model.dart';
import '../app/quests.dart';
import '../app/services.dart';
import '../avatar/avatar.dart';
import '../avatar/avatar_editor.dart';
import '../avatar/avatar_painter.dart';
import '../ui/doodle.dart';
import '../ui/widgets.dart';
import 'root.dart';

/// 持っているコインの表示
class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, this.fontSize = 20});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context).settings;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Semantics(
        label: 'コイン ${s.coins}まい',
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.monetization_on_outlined, size: fontSize + 4, color: Palette.ink),
          const SizedBox(width: 4),
          Text('${s.coins}', style: TextStyle(fontSize: fontSize, color: Palette.ink)),
        ]),
      ),
    );
  }
}

/// 今日のクエスト。達成したら「受け取る」でコインがもらえる
class QuestScreen extends StatelessWidget {
  const QuestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    return DoodleScaffold(
      title: '今日のクエスト',
      onBack: () => s.model.go(Screen.home),
      actions: const [CoinBadge(), SizedBox(width: 16)],
      child: ListenableBuilder(
        listenable: s.settings,
        builder: (context, _) {
          final now = DateTime.now();
          final day = DailyQuests.dayKey(now);
          final today = DailyQuests.today(s.settings.records, now);
          final claimed = s.settings.claimedQuests(day);
          final locked = s.settings.questsLocked(day);
          return PageBody(maxWidth: 760, children: [
            const Text('試合をしてクエストを達成すると、コインがもらえます。\nクエストは毎日かわります。', style: TextStyle(fontSize: 17, height: 1.5)),
            if (locked) ...[
              const SizedBox(height: 12),
              const StatusLine(state: StatusKind.bad, text: '保存データが書きかえられていたため、今日のクエストは受け取れません。あしたからまた受け取れます。'),
            ],
            const SizedBox(height: 20),
            for (final (i, q) in DailyQuests.forDay(now).indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DoodleBox(
                  seed: 300 + i,
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(q.title, style: const TextStyle(fontSize: 21)),
                        const SizedBox(height: 4),
                        Text('${q.progress(today)} / ${q.goal}　・　ほうび ${q.reward}コイン', style: const TextStyle(fontSize: 15, color: Palette.pencil)),
                      ]),
                    ),
                    SizedBox(
                      width: 150,
                      child: claimed.contains(q.id)
                          ? const Text('受け取りずみ', textAlign: TextAlign.center, style: TextStyle(fontSize: 17, color: Palette.pencil))
                          : DoodleButton(
                              label: '受け取る',
                              primary: q.done(today) && !locked,
                              fontSize: 17,
                              seed: 310 + i,
                              onPressed: q.done(today) && !locked
                                  ? () {
                                      // 画面を開いたまま日付が変わったら、きのうのクエストは受け取らない
                                      final at = DateTime.now();
                                      if (DailyQuests.dayKey(at) == day) s.settings.claimQuest(day, q.id, q.reward);
                                      (context as Element).markNeedsBuild();
                                    }
                                  : null,
                            ),
                    ),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

/// コスチュームを買う
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    return DoodleScaffold(
      title: 'ショップ',
      onBack: () => s.model.go(Screen.home),
      actions: const [CoinBadge(), SizedBox(width: 16)],
      child: ListenableBuilder(
        listenable: s.settings,
        builder: (context, _) {
          final items = [
            for (final e in Avatar.prices.entries)
              for (final i in e.value.keys) (e.key, i),
          ];
          return PageBody(maxWidth: 960, children: [
            const Text('買ったコスチュームは「ロッカー」で着られます。', style: TextStyle(fontSize: 17)),
            const SizedBox(height: 18),
            Wrap(spacing: 18, runSpacing: 18, children: [
              for (final (n, (part, i)) in items.indexed)
                SizedBox(
                  width: 210,
                  child: DoodleBox(
                    seed: 320 + n,
                    child: Column(children: [
                      AvatarView(avatar: s.settings.avatar.withChoice(part, i), size: 120, bust: true),
                      const SizedBox(height: 6),
                      Text(part.options[i], style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 8),
                      if (s.settings.owns(part, i))
                        const SizedBox(height: 44, child: Center(child: Text('持っている', style: TextStyle(fontSize: 17, color: Palette.pencil))))
                      else
                        DoodleButton(
                          label: '${Avatar.price(part, i)}コイン',
                          icon: Icons.monetization_on_outlined,
                          fontSize: 17,
                          seed: 340 + n,
                          primary: s.settings.coins >= Avatar.price(part, i),
                          onPressed: s.settings.coins >= Avatar.price(part, i) ? () => s.settings.buy(part, i) : null,
                        ),
                    ]),
                  ),
                ),
            ]),
          ]);
        },
      ),
    );
  }
}

/// 持っているコスチュームで着せ替える
class LockerScreen extends StatelessWidget {
  const LockerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    return DoodleScaffold(
      title: 'ロッカー',
      onBack: () => s.model.go(Screen.home),
      actions: const [CoinBadge(), SizedBox(width: 16)],
      child: ListenableBuilder(
        listenable: s.settings,
        builder: (context, _) => PageBody(maxWidth: 1040, children: [
          LayoutBuilder(
            builder: (context, c) => AvatarEditor(
              value: s.settings.avatar,
              onChanged: (a) => s.settings.avatar = a,
              owns: s.settings.owns,
              horizontal: c.maxWidth >= 760 && MediaQuery.textScalerOf(context).scale(1) <= 1.3,
            ),
          ),
          const SizedBox(height: 14),
          const Text('新しいコスチュームはショップで買えます。', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Palette.pencil)),
        ]),
      ),
    );
  }
}
