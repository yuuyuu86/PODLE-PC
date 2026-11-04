import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'version.dart';

/// 新しい版のお知らせ。起動時に GitHub Releases の最新版を1回だけ確かめる。
/// インストールは利用者がダウンロードページから行う（自動では入れかえない）。
/// オフラインや失敗したときは何も知らせない。
///
/// 強制アップデート: リポジトリの update.json の minVersion より古い版は、新しい版を入れるまで遊べない
/// （[required]）。一度古いと分かった最低版数は保存しておき、オフラインで起動しても止める。
class UpdateChecker extends ChangeNotifier {
  UpdateChecker({this.fetch, this.fetchPolicy, String? savedMinVersion, this.onMinVersion}) : minVersion = savedMinVersion;

  /// 最新版の情報を取ってくる（テストで差しかえる）。(タグ, ページの URL) を返す
  final Future<(String, String)?> Function()? fetch;

  /// update.json を取ってくる（テストで差しかえる）。(最低版数, 利用者へのひとこと) を返す
  final Future<(String, String?)?> Function()? fetchPolicy;

  /// 新しい最低版数を受け取ったとき（保存するため）
  final void Function(String)? onMinVersion;

  /// この版より古いと遊べない（null は制限なし）
  String? minVersion;

  /// 止めるときに出すひとこと（update.json の message）
  String? message;

  /// 新しい版を入れるまで遊べない
  bool get required => minVersion != null && AppVersion.compare(AppVersion.app, minVersion!) < 0;

  /// 自分より新しい版（なければ null）
  String? latest;
  String url = AppVersion.releasesPage;
  bool checking = false;

  /// 確かめた結果（設定画面の「新しい版を確かめる」用）。null はまだ確かめていない
  bool? upToDate;

  Future<void> check() async {
    if (checking) return;
    checking = true;
    notifyListeners();
    try {
      final p = await (fetchPolicy ?? _policyFromGitHub)().catchError((Object _) => null);
      if (p != null) {
        final (min, msg) = p;
        minVersion = min;
        message = msg;
        onMinVersion?.call(min);
      }
      final r = await (fetch ?? _fromGitHub)();
      if (r != null) {
        final (tag, page) = r;
        final newer = AppVersion.compare(tag, AppVersion.app) > 0;
        latest = newer ? tag.replaceFirst(RegExp('^v'), '') : null;
        url = page;
        upToDate = !newer;
      }
    } catch (_) {
      // 失敗は知らせない
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  /// main ブランチの update.json（例: {"minVersion": "1.1.1", "message": "…"}）
  static Future<(String, String?)?> _policyFromGitHub() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.getUrl(Uri.parse('https://raw.githubusercontent.com/${AppVersion.repo}/main/update.json'));
      req.headers.set(HttpHeaders.userAgentHeader, 'PODLE-PC/${AppVersion.app}');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(await res.transform(utf8.decoder).join());
      if (body is! Map || body['minVersion'] is! String) return null;
      final msg = body['message'];
      return (body['minVersion'] as String, msg is String && msg.isNotEmpty ? msg : null);
    } finally {
      client.close(force: true);
    }
  }

  static Future<(String, String)?> _fromGitHub() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.getUrl(Uri.parse('https://api.github.com/repos/${AppVersion.repo}/releases/latest'));
      req.headers
        ..set(HttpHeaders.userAgentHeader, 'PODLE-PC/${AppVersion.app}')
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
      final tag = body['tag_name'];
      if (tag is! String) return null;
      return (tag, body['html_url'] as String? ?? AppVersion.releasesPage);
    } finally {
      client.close(force: true);
    }
  }

  /// ダウンロードページをブラウザで開く
  Future<void> openDownloadPage([String? page]) async {
    try {
      await launchUrl(Uri.parse(page ?? url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
