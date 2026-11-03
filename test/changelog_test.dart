import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pong_pc/app/changelog.dart';
import 'package:pong_pc/app/version.dart';

void main() {
  test('CHANGELOG.md を版ごとに読める（いまの版が先頭）', () {
    final e = parseChangelog(File('CHANGELOG.md').readAsStringSync());
    expect(e.first.version, AppVersion.app);
    expect(e.first.date, isNotEmpty);
    expect(e.first.sections.expand((s) => s.$2), isNotEmpty);
    expect(e.map((x) => x.version), contains('1.1.0'));
    expect(e.expand((x) => x.sections.expand((s) => s.$2)).any((t) => t.contains('**')), isFalse);
  });
}
