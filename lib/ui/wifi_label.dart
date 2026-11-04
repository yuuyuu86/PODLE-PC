import 'package:flutter/material.dart';

import '../app/services.dart';
import '../net/wifi.dart';
import 'doodle.dart';

/// 今つながっている Wi-Fi を小さく出す（2台が同じ Wi-Fi か確かめられるように）
class WifiLabel extends StatefulWidget {
  const WifiLabel({super.key, this.center = false});
  final bool center;

  @override
  State<WifiLabel> createState() => _WifiLabelState();
}

class _WifiLabelState extends State<WifiLabel> {
  WifiInfo? _w;
  WifiInfo get _wifi => _w!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_w == null) {
      _w = Services.of(context).model.wifi;
      _w!.start();
    }
  }

  @override
  void dispose() {
    _w?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _wifi,
      builder: (context, _) {
        final label = _wifi.label;
        if (label == null) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: widget.center ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(_wifi.ssid != null ? Icons.wifi_rounded : Icons.lan_outlined, size: 15, color: Palette.pencil),
            const SizedBox(width: 4),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Palette.pencil))),
          ],
        );
      },
    );
  }
}
