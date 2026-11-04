import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_model.dart';
import '../app/feedback.dart';
import '../app/keyboard.dart';
import '../app/changelog.dart';
import '../app/version.dart';
import '../app/services.dart';
import '../games/core/catalog.dart';
import '../ui/doodle.dart';
import '../ui/logo.dart';
import '../ui/widgets.dart';
import 'profile.dart';
import 'root.dart';

/// あそびかた。「はじめかた」と競技ごとのタブに分ける（スマホ版と同じ）。
class HowToScreen extends StatefulWidget {
  const HowToScreen({super.key});

  @override
  State<HowToScreen> createState() => _HowToScreenState();
}

class _HowToScreenState extends State<HowToScreen> {
  int _tab = 0;

  static const _steps = [
    '2台のPC（Mac / Windows どちらでも）を同じWi-Fiにつなぎ、両方で PODLE! を開きます。サーバーの準備は要りません。',
    '遊びたいゲームを選び、片方が「部屋を作る」。部屋を作った人が左、参加した人が右の選手です。',
    'または、画面に出た4文字の部屋コードを伝えて、相手が「コードで参加」。',
    '2人とも「準備OK」を押すと、操作説明のあと試合開始。各自のキーボードで操作します。',
  ];

  @override
  Widget build(BuildContext context) {
    final model = Services.of(context).model;
    return DoodleScaffold(
      title: 'あそびかた',
      onBack: () => model.go(Screen.home),
      child: PageBody(
        children: [
          DoodleTabs(labels: ['はじめかた', for (final g in GameKind.values) g.title], selected: _tab, seed: 150, onChanged: (i) => setState(() => _tab = i)),
          const SizedBox(height: 20),
          if (_tab > 0)
            _GameRules(game: GameKind.values[_tab - 1])
          else ...[
            const DoodleHeading('はじめかた', size: 21),
            const SizedBox(height: 10),
            for (final (i, s) in _steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${i + 1}. $s', style: const TextStyle(fontSize: 17, height: 1.45)),
              ),
            const SizedBox(height: 6),
            const Text('2台を横に並べるとコートがつながります。左の選手のPCにはコートの左半分、右の選手のPCには右半分が映ります。自分の選手は太い線と、墨で塗った「あなた」の名札、相手は点線の名札「あいて」で見分けられます。', style: TextStyle(fontSize: 16, height: 1.45)),
            const SizedBox(height: 6),
            const Text('通信が切れたら試合は自動で止まり、つながり直すと同じところから続きます。', style: TextStyle(fontSize: 16, height: 1.45)),
          ],
        ],
      ),
    );
  }
}

/// 競技ごとのタブの中身: 特徴・ルール・操作
class _GameRules extends StatelessWidget {
  const _GameRules({required this.game});
  final GameKind game;

  @override
  Widget build(BuildContext context) {
    return DoodleBox(
      seed: 71 + game.index,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DoodleHeading('PODLE! ${game.title}', size: 21),
          const SizedBox(height: 8),
          Text(game.summary, style: const TextStyle(fontSize: 17, height: 1.45)),
          const SizedBox(height: 6),
          Text(game.ruleText, style: const TextStyle(fontSize: 16, color: Palette.pencil)),
          const SizedBox(height: 14),
          const DoodleHeading('タイミング（JUST!）', size: 18),
          const SizedBox(height: 6),
          Text(_timingText(game), style: const TextStyle(fontSize: 16, height: 1.45)),
          const SizedBox(height: 14),
          const DoodleHeading('そうさ（2台とも同じキー）', size: 18),
          const SizedBox(height: 8),
          ControlsList(controls: game.controls, size: 16),
        ],
      ),
    );
  }
}

/// 攻撃のタイミング判定の説明（JUST! / はやい / おそい / ちかい）
String _timingText(GameKind game) => switch (game) {
  GameKind.boxing => '相手にぎりぎり届く距離でパンチを当てると「JUST!」で、ダメージが大きくなります。近づきすぎて打つと「ちかい」で、ダメージが小さくなります。',
  GameKind.fencing => '相手の突きが届く直前にパリィすると「JUST!」で、相手が長く止まります。早すぎると「はやい」で、止まる時間が短くなります。突きは相手との距離がちょうどいいと「JUST!」です。',
  GameKind.tug => 'ちょうどいい間隔（自分の後ろの輪が太くなって「いま！」と出るとき）で引くと「JUST!」で、強く引けます。連打しすぎると「はやい」で、ほとんど力が入りません。',
  GameKind.sumo => 'ふんばっている相手につっぱると「ちかい」で、ほとんど押せません。前に出てくる相手には、はたきが決まります。',
  _ => 'ボールが来る直前に打つと「JUST!」で、速い球を返せます。早すぎ（「はやい」）・遅すぎ（「おそい」）だと、弱い球になります。音と文字で分かります。',
};

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final s = Services.of(context);
    return DoodleScaffold(
      title: '設定',
      onBack: () => s.model.go(Screen.home),
      child: PageBody(
        maxWidth: 680,
        children: [
          const DoodleBox(seed: 81, child: NameSetting()),
          const SizedBox(height: 18),
          DoodleBox(
            seed: 82,
            child: ListenableBuilder(
              listenable: s.settings,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DoodleHeading('効果音', size: 21),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 170,
                        child: DoodleButton(
                          label: s.settings.soundOn ? '音 ON' : '音 OFF',
                          icon: s.settings.soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                          primary: s.settings.soundOn,
                          seed: 83,
                          fontSize: 18,
                          onPressed: () => s.settings.soundOn = !s.settings.soundOn,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text('音量', style: TextStyle(fontSize: 18)),
                      SizedBox(
                        width: 260,
                        child: Slider(value: s.settings.volume, onChanged: (v) => s.settings.volume = v, onChangeEnd: (_) => s.feedback.play(Sound.hit)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const _KeySettings(),
          const SizedBox(height: 22),
          ListenableBuilder(
            listenable: s.model.updates,
            builder: (context, _) {
              final u = s.model.updates;
              final status = u.checking
                  ? '確かめています…'
                  : u.latest != null
                  ? '新しい版 ${u.latest} があります'
                  : u.upToDate == true
                  ? 'いまの版が最新です'
                  : '';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DoodleBox(
                    seed: 91,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () => showChangelog(context),
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(text: 'PODLE! ${AppVersion.app}', style: const TextStyle(fontSize: 21)),
                                        const TextSpan(
                                          text: '  更新内容を見る ›',
                                          style: TextStyle(fontSize: 15, color: Palette.pencil, decoration: TextDecoration.underline),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const Text('© 2026 dev.yuta', style: TextStyle(fontSize: 14, color: Palette.pencil)),
                              if (status.isNotEmpty) Text(status, style: const TextStyle(fontSize: 15, color: Palette.pencil)),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: u.latest != null
                              ? DoodleButton(label: 'ダウンロード', icon: Icons.download_rounded, primary: true, fontSize: 17, seed: 92, onPressed: () => u.openDownloadPage())
                              : DoodleButton(label: '新しい版を確かめる', fontSize: 16, seed: 93, onPressed: u.checking ? null : u.check),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 200,
                        child: DoodleButton(label: '更新内容', icon: Icons.history_rounded, fontSize: 16, seed: 95, onPressed: () => showChangelog(context)),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 200,
                        child: DoodleButton(
                          label: 'ライセンス',
                          icon: Icons.description_outlined,
                          fontSize: 16,
                          seed: 94,
                          onPressed: () =>
                              showLicensePage(context: context, applicationName: 'PODLE!', applicationVersion: AppVersion.app, applicationLegalese: '© 2026 dev.yuta. All rights reserved.'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// キーの割り当て。「変更」を押してから、使いたいキーを押す。
class _KeySettings extends StatefulWidget {
  const _KeySettings();

  @override
  State<_KeySettings> createState() => _KeySettingsState();
}

class _KeySettingsState extends State<_KeySettings> {
  GameAction? _waiting;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _start(GameAction a) {
    setState(() => _waiting = a);
    _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final a = _waiting;
    if (a == null || e is! KeyDownEvent) return a == null ? KeyEventResult.ignored : KeyEventResult.handled;
    // Esc はやめる。Tab や修飾キーは画面の操作やショートカットに使うので割り当てない
    if (e.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _waiting = null);
      return KeyEventResult.handled;
    }
    final reserved = {
      LogicalKeyboardKey.tab,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.capsLock,
    };
    if (reserved.contains(e.logicalKey)) return KeyEventResult.handled;
    Services.of(context).settings.bindKey(a, e.physicalKey, KeyBindings.nameOf(e));
    Services.of(context).feedback.play(Sound.tap);
    setState(() => _waiting = null);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Services.of(context).settings;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: DoodleBox(
        seed: 84,
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            final keys = settings.keys;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DoodleHeading('キーの割り当て', size: 21),
                const SizedBox(height: 6),
                const Text('「変更」を押してから、使いたいキーを押してください（Esc でやめる）。自分のPCだけに効きます。', style: TextStyle(fontSize: 15, color: Palette.pencil)),
                const SizedBox(height: 10),
                for (final (i, a) in GameAction.values.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(width: 240, child: Text(a.label, style: const TextStyle(fontSize: 18))),
                        Expanded(
                          child: _waiting == a ? const Text('キーを押してください…', style: TextStyle(fontSize: 18)) : Align(alignment: Alignment.centerLeft, child: Keycap(keys.label(a), size: 17)),
                        ),
                        SizedBox(
                          width: 130,
                          child: DoodleButton(label: _waiting == a ? 'やめる' : '変更', fontSize: 17, seed: 85 + i, onPressed: () => _waiting == a ? setState(() => _waiting = null) : _start(a)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 200,
                    child: DoodleButton(label: '元に戻す', icon: Icons.restart_alt_rounded, fontSize: 17, seed: 90, onPressed: keys.isStandard ? null : settings.resetKeys),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 設定の版番号から開く、版ごとの更新内容（CHANGELOG.md を同梱して読む）。
/// ライセンス一覧と同じく、左に版の一覧、右に選んだ版の変更内容を出す。
Future<void> showChangelog(BuildContext context) async {
  final text = await rootBundle.loadString('CHANGELOG.md');
  if (!context.mounted) return;
  final entries = parseChangelog(text);
  await showDialog<void>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 900, maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
        child: DoodleBox(shadow: true, padding: const EdgeInsets.all(22), child: _Changelog(entries: entries)),
      ),
    ),
  );
}

class _Changelog extends StatefulWidget {
  const _Changelog({required this.entries});
  final List<ChangelogEntry> entries;

  @override
  State<_Changelog> createState() => _ChangelogState();
}

class _ChangelogState extends State<_Changelog> {
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    final e = entries.isEmpty ? null : entries[_sel];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DoodleHeading('更新内容', size: 26),
        const SizedBox(height: 12),
        Flexible(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左: 版の一覧
              SizedBox(
                width: 210,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (i, v) in entries.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => setState(() => _sel = i),
                            child: CustomPaint(
                              painter: SketchBorderPainter(seed: 120 + i, dashed: i != _sel, fillColor: i == _sel ? Palette.ink : Palette.paper, strokeWidth: 2),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(v.version + (v.version == AppVersion.app ? '  いまの版' : ''), style: TextStyle(fontSize: 20, color: i == _sel ? Palette.paper : Palette.ink)),
                                    if (v.date.isNotEmpty) Text(v.date, style: TextStyle(fontSize: 13, color: i == _sel ? Palette.paperShade : Palette.pencil)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              // 右: 選んだ版の変更内容
              Expanded(
                child: e == null
                    ? const SizedBox()
                    : ListView(
                        key: ValueKey(_sel),
                        shrinkWrap: true,
                        children: [
                          Text('PODLE! ${e.version}', style: const TextStyle(fontSize: 24)),
                          if (e.date.isNotEmpty) Text(e.date, style: const TextStyle(fontSize: 14, color: Palette.pencil)),
                          for (final t in e.intro) Padding(padding: const EdgeInsets.only(top: 8), child: Text(t, style: const TextStyle(fontSize: 16, height: 1.4))),
                          for (final (title, items) in e.sections) ...[
                            if (title.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12, bottom: 2), child: DoodleHeading(title, size: 18)),
                            for (final it in items)
                              Padding(
                                padding: const EdgeInsets.only(left: 6, top: 4),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('・', style: TextStyle(fontSize: 16, height: 1.4)),
                                  Expanded(child: Text(it, style: const TextStyle(fontSize: 16, height: 1.4))),
                                ]),
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Align(alignment: Alignment.centerRight, child: SizedBox(width: 160, child: DoodleButton(label: 'とじる', fontSize: 18, seed: 7, onPressed: () => Navigator.pop(context)))),
      ],
    );
  }
}
