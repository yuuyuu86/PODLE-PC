import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_model.dart';
import 'app/feedback.dart';
import 'app/services.dart';
import 'app/settings.dart';
import 'screens/root.dart';
import 'ui/cursor.dart';
import 'ui/doodle.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 設定 → ライセンス に、同梱フォント（Yusei Magic, SIL OFL 1.1）のライセンスも出す
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Yusei Magic'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  final settings = await AppSettings.load();
  final feedback = GameFeedback(settings);
  await feedback.init();
  final model = AppModel(settings: settings, feedback: feedback);
  await model.start();
  unawaited(model.updates.check());
  runApp(PongApp(settings: settings, feedback: feedback, model: model));
}

/// テーマはスマホ版 PONG! と同じ（紙・墨・手書き文字）
class PongApp extends StatelessWidget {
  const PongApp({super.key, required this.settings, required this.feedback, required this.model, this.splash = true});

  final AppSettings settings;
  final GameFeedback feedback;
  final AppModel model;

  /// 起動時にロゴのスプラッシュを流すか（テストでは切る）
  final bool splash;

  @override
  Widget build(BuildContext context) {
    final text = ThemeData.light().textTheme.apply(fontFamily: kFontFamily, bodyColor: Palette.ink, displayColor: Palette.ink);
    return Services(
      settings: settings,
      feedback: feedback,
      model: model,
      child: MaterialApp(
        title: 'PONG!',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: kFontFamily,
          scaffoldBackgroundColor: Palette.paper,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Palette.ink,
            primary: Palette.ink,
            onPrimary: Palette.paper,
            surface: Palette.paper,
            onSurface: Palette.ink,
          ),
          textTheme: text.copyWith(
            titleLarge: text.titleLarge?.copyWith(fontSize: 24),
            bodyLarge: text.bodyLarge?.copyWith(fontSize: 18),
            bodyMedium: text.bodyMedium?.copyWith(fontSize: 16),
          ),
          textSelectionTheme: const TextSelectionThemeData(cursorColor: Palette.ink),
          sliderTheme: const SliderThemeData(activeTrackColor: Palette.ink, thumbColor: Palette.ink, inactiveTrackColor: Palette.faint),
        ),
        builder: (context, child) => DoodleCursor(child: UiScale(child: child!)),
        home: RootScreen(splash: splash),
      ),
    );
  }
}

/// 画面（ウィンドウ）が大きいときは、文字・ボタン・コートなど画面全体を同じ割合で大きくする。
/// 1280x800 を基準に、それより大きければ最大 2 倍まで拡大する（小さい画面ではそのまま）。
class UiScale extends StatelessWidget {
  const UiScale({super.key, required this.child});
  final Widget child;

  static const base = Size(1280, 800);

  static double of(Size size) => math.min(size.width / base.width, size.height / base.height).clamp(1.0, 2.0);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final k = of(mq.size);
    if (k <= 1.01) return child;
    return FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: mq.size.width / k,
        height: mq.size.height / k,
        child: MediaQuery(
          data: mq.copyWith(size: mq.size / k, padding: mq.padding / k, viewPadding: mq.viewPadding / k, viewInsets: mq.viewInsets / k),
          child: child,
        ),
      ),
    );
  }
}
