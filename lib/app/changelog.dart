/// CHANGELOG.md（パッチノート）を、版ごとに読みやすい形に分ける。
class ChangelogEntry {
  ChangelogEntry(this.version, this.date);
  final String version;
  final String date;
  final sections = <(String, List<String>)>[];
  final intro = <String>[];
}

List<ChangelogEntry> parseChangelog(String text) {
  final out = <ChangelogEntry>[];
  String plain(String s) => s.replaceAll('**', '').replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1]!).trim();
  for (final line in text.split('\n')) {
    final h = RegExp(r'^## ([^\s（(]+)\s*[（(]?([^）)]*)[）)]?').firstMatch(line);
    if (h != null) {
      out.add(ChangelogEntry(h[1]!, h[2]!.trim()));
    } else if (out.isEmpty) {
      continue;
    } else if (line.startsWith('### ')) {
      out.last.sections.add((plain(line.substring(4)), []));
    } else if (line.startsWith('- ')) {
      if (out.last.sections.isEmpty) out.last.sections.add(('', []));
      out.last.sections.last.$2.add(plain(line.substring(2)));
    } else if (line.trim().isNotEmpty && out.last.sections.isEmpty) {
      out.last.intro.add(plain(line));
    }
  }
  return out;
}
