import 'dart:math' as math;

import 'dart:convert';

import 'package:basic_utils/basic_utils.dart' show KeyParameter, Mac;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../avatar/avatar.dart';
import 'keyboard.dart';
import 'records.dart';

/// このPCに保存する設定（スマホ版 AppSettings と同じ形）。
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async => AppSettings._(await SharedPreferences.getInstance())
    .._migrate()
    .._verify();

  /// 保存データの形の版。保存する形を変えたら 1 上げ、[_migrate] に古い形からの読み替えを足す。
  /// （1.1.0 より前は版を持っていないので 0 とみなす。0 → 1 で変わった形はない）
  static const dataVersion = 1;

  int get savedDataVersion => _prefs.getInt('dataVersion') ?? 0;

  /// 古い版で保存したデータを、いまの形に読み替える。新しい版で保存したデータ（版が大きい）はそのまま使う。
  void _migrate() {
    final from = savedDataVersion;
    if (from >= dataVersion) return;
    // 例: if (from < 2) { 'records' の形を変える … }
    _prefs.setInt('dataVersion', dataVersion);
  }

  static const maxNameLength = 12;

  String get playerName {
    final saved = _prefs.getString('playerName');
    if (saved != null && saved.isNotEmpty) return saved;
    final name = suggestName();
    _prefs.setString('playerName', name);
    return name;
  }

  set playerName(String v) => _set(() => _prefs.setString('playerName', v.trim()));

  /// 棒人間の見た目（[Avatar.encode] の文字列）
  Avatar get avatar {
    final raw = _prefs.getString('avatar');
    if (raw != null) return Avatar.decode(raw);
    final a = Avatar.random();
    _prefs.setString('avatar', a.encode());
    return a;
  }

  set avatar(Avatar v) => _set(() => _prefs.setString('avatar', v.encode()));

  /// 初回起動時のプレイヤー登録を済ませたか（スマホ版と同じ）
  bool get registered => _prefs.getBool('registered') ?? false;

  void completeRegistration(String name, Avatar avatar) {
    _prefs.setString('playerName', name.trim());
    _prefs.setString('avatar', avatar.encode());
    _set(() => _prefs.setBool('registered', true));
  }

  /// 名前に問題があれば利用者向けの説明を返す。
  static String? validateName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return '名前を入れてください';
    if (name.characters.length > maxNameLength) return '名前は$maxNameLength文字までです';
    return null;
  }

  static const _nameIdeas = ['スパイク', 'スマッシュ', 'ラリー', 'エース', 'ボレー', 'ジャブ', 'パリィ', 'ロブ', 'サーブ', 'トス'];

  /// 「おまかせ」で使う名前の候補
  static String suggestName([math.Random? rnd]) {
    final r = rnd ?? math.Random();
    return '${_nameIdeas[r.nextInt(_nameIdeas.length)]}${r.nextInt(90) + 10}';
  }

  /// 強制アップデートの最低版数（最後に確かめたもの。オフラインで起動しても止めるため）
  String? get requiredVersion => _prefs.getString('requiredVersion');
  set requiredVersion(String? v) => v == null ? _prefs.remove('requiredVersion') : _prefs.setString('requiredVersion', v);

  /// 「あとで」を押した新しい版（同じ版のお知らせは出さない）
  String? get dismissedUpdate => _prefs.getString('dismissedUpdate');
  set dismissedUpdate(String? v) => _set(() => v == null ? _prefs.remove('dismissedUpdate') : _prefs.setString('dismissedUpdate', v));

  bool get soundOn => _prefs.getBool('soundOn') ?? true;
  set soundOn(bool v) => _set(() => _prefs.setBool('soundOn', v));

  double get volume => _prefs.getDouble('volume') ?? 0.7;
  set volume(double v) => _set(() => _prefs.setDouble('volume', v));

  /// キーの割り当て（'物理キーの番号|表示名'）
  KeyBindings get keys {
    final keys = <GameAction, PhysicalKeyboardKey>{};
    final labels = <GameAction, String>{};
    for (final a in GameAction.values) {
      final raw = _prefs.getString('key_${a.name}')?.split('|');
      final usage = raw == null ? null : int.tryParse(raw[0]);
      if (usage == null || raw!.length < 2) continue;
      keys[a] = PhysicalKeyboardKey(usage);
      labels[a] = raw.sublist(1).join('|');
    }
    return KeyBindings(keys, labels);
  }

  /// [action] に [key] を割り当てる。ほかの操作が同じキーを使っていたら、入れ替える。
  void bindKey(GameAction action, PhysicalKeyboardKey key, String label) {
    final now = keys;
    for (final other in GameAction.values) {
      if (other != action && now[other] == key) {
        _prefs.setString('key_${other.name}', '${now[action].usbHidUsage}|${now.label(action)}');
      }
    }
    _set(() => _prefs.setString('key_${action.name}', '${key.usbHidUsage}|$label'));
  }

  void resetKeys() {
    for (final a in GameAction.values) {
      _prefs.remove('key_${a.name}');
    }
    notifyListeners();
  }

  /// 対戦結果の記録（新しい順、最大 [maxRecords] 件）
  static const maxRecords = 200;
  List<MatchRecord> get records => MatchRecord.decodeList(_prefs.getString('records'));

  void addRecord(MatchRecord r) {
    final list = [r, ...records].take(maxRecords).toList();
    _prefs.setString('records', MatchRecord.encodeList(list));
    _sign();
    notifyListeners();
  }

  /// コイン（今日のクエストでもらい、ショップで使う）
  int get coins => _prefs.getInt('coins') ?? 0;
  void addCoins(int n) {
    _prefs.setInt('coins', coins + n);
    _sign();
    notifyListeners();
  }

  /// ショップで買ったパーツ（"top.6" の形）
  Set<String> get _owned => (_prefs.getStringList('owned') ?? const []).toSet();

  bool owns(AvatarPart part, int index) => Avatar.price(part, index) == 0 || _owned.contains('${part.name}.$index');

  /// 買えたら true（コインが足りない・もう持っているときは false）
  bool buy(AvatarPart part, int index) {
    final price = Avatar.price(part, index);
    if (owns(part, index) || coins < price) return false;
    _prefs.setInt('coins', coins - price);
    _prefs.setStringList('owned', [..._owned, '${part.name}.$index']);
    _sign();
    notifyListeners();
    return true;
  }

  /// 今日のクエストで受け取りずみのもの（日付が変わったら空になる）
  Set<String> claimedQuests(String day) => _prefs.getString('questDay') == day ? (_prefs.getStringList('questClaimed') ?? const []).toSet() : {};

  void claimQuest(String day, String id, int reward) {
    final done = claimedQuests(day);
    if (done.contains(id) || questsLocked(day)) return;
    _prefs.setString('questDay', day);
    _prefs.setInt('coins', coins + reward);
    _prefs.setStringList('questClaimed', [...done, id]);
    _sign();
    notifyListeners();
  }

  void clearRecords() {
    _prefs.remove('records');
    _sign();
    notifyListeners();
  }

  // ---- 書き換えの見張り ----
  // コイン・買ったもの・受け取ったクエスト・対戦記録に、アプリだけが作れるしるし（HMAC-SHA256）を付けて保存する。
  // 保存ファイルを直接書きかえるとしるしが合わなくなるので、コインと買ったものを消し、その日のクエストを受け取れなくする。
  // アプリを解析されれば破れるが、ファイルを開いて数字を変えるだけの書き換えは防げる。

  /// 書き換えが見つかった日（この日のクエストは受け取れない）
  bool questsLocked(String day) => _prefs.getString('questLocked') == day;

  /// 起動時に書き換えが見つかった（画面で知らせる用）
  bool tampered = false;

  static final _seed = [0x50, 0x4f, 0x4e, 0x47, 0x21, 0x2d, 0x63, 0x6f, 0x69, 0x6e, 0x2d, 0x6b, 0x33, 0x79, 0x2d, 0x37, 0x61, 0x39, 0x66];

  String get _installId {
    final v = _prefs.getString('installId');
    if (v != null && v.isNotEmpty) return v;
    final r = math.Random.secure();
    final id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    _prefs.setString('installId', id);
    return id;
  }

  String _signature() {
    final body = [
      '${_prefs.getInt('coins') ?? 0}',
      ([...(_prefs.getStringList('owned') ?? const <String>[])]..sort()).join(','),
      _prefs.getString('questDay') ?? '',
      ([...(_prefs.getStringList('questClaimed') ?? const <String>[])]..sort()).join(','),
      _prefs.getString('questLocked') ?? '',
      _prefs.getString('records') ?? '',
    ].join('\n');
    final mac = Mac('SHA-256/HMAC')..init(KeyParameter(Uint8List.fromList([..._seed, ...utf8.encode(_installId)])));
    final out = mac.process(Uint8List.fromList(utf8.encode(body)));
    return out.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _sign() => _prefs.setString('sig', _signature());

  bool get _hasEconomy =>
      (_prefs.getInt('coins') ?? 0) != 0 || (_prefs.getStringList('owned') ?? const []).isNotEmpty || (_prefs.getStringList('questClaimed') ?? const []).isNotEmpty;

  void _verify() {
    final sig = _prefs.getString('sig');
    if (sig == _signature()) return;
    // しるしのない古い版のデータ（コインがまだない）は、そのまま認めてしるしを付ける。
    // 記録だけはあり得るが、書きかえられていないとは言えないので、今日のクエストは受け取れなくする。
    if (sig == null && !_hasEconomy) {
      if (_prefs.getString('records') != null) _lockToday();
      _sign();
      return;
    }
    tampered = true;
    _prefs.remove('coins');
    _prefs.remove('owned');
    _prefs.remove('questClaimed');
    _lockToday();
    // 着ている買いものは、最初から使えるものに戻す
    final a = avatar;
    var fixed = a;
    for (final p in AvatarPart.values) {
      if (Avatar.price(p, a[p]) != 0) fixed = fixed.withChoice(p, 0);
    }
    if (fixed != a) _prefs.setString('avatar', fixed.encode());
    _sign();
  }

  void _lockToday() {
    final now = DateTime.now();
    _prefs.setString('questLocked', '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');
  }

  void _set(Future<bool> Function() write) {
    write();
    notifyListeners();
  }
}
