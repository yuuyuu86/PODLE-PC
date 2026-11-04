import 'package:flutter_test/flutter_test.dart';
import 'package:podle_pc/net/wire.dart';

void main() {
  test('実寸が分からなければ、ポイントの小さい方にそろえる', () {
    expect(CourtFit.common(const CourtFit(1.4, null), const CourtFit(1.1, null)), 1.1);
    expect(CourtFit.common(const CourtFit(1.1, null), const CourtFit(1.4, 0.2)), 1.1);
  });

  test('2台とも実寸が分かれば、実寸の小さい方にそろえる', () {
    // 自分: 1ポイント 0.25mm で 1.2 → 0.30mm。相手: 0.2mm で 1.2 → 0.24mm。相手に合わせて 0.24/0.25 = 0.96
    expect(CourtFit.common(const CourtFit(1.2, 0.25), const CourtFit(1.2, 0.2)), closeTo(0.96, 1e-9));
    // 相手の方が大きければ、自分の画面いっぱいのまま
    expect(CourtFit.common(const CourtFit(1.2, 0.2), const CourtFit(1.2, 0.25)), 1.2);
  });

  test('相手が古い版（大きさを送ってこない）なら、自分の画面いっぱい', () {
    expect(CourtFit.common(const CourtFit(1.3, 0.2), null), 1.3);
  });

  test('大きさは部屋の情報に入って届く', () {
    const p = PlayerInfo(present: true, fit: CourtFit(1.25, 0.21));
    final back = PlayerInfo.fromJson(p.toJson());
    expect(back.fit?.k, 1.25);
    expect(back.fit?.mm, 0.21);
    expect(PlayerInfo.fromJson(const PlayerInfo(present: true).toJson()).fit, isNull);
  });
}
