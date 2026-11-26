import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../bluebloom/session_presentation.dart';
import '../../common/shared_state.dart';
import '../../models/model.dart';

class SessionStats extends StatelessWidget {
  const SessionStats({Key? key, required this.ffi, required this.peerId})
      : super(key: key);
  final FFI ffi;
  final String peerId;

  static String elapsed(int seconds) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(seconds ~/ 3600)}:${two(seconds ~/ 60 % 60)}:${two(seconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final monitor = ffi.qualityMonitorModel;
    return AnimatedBuilder(
      animation: monitor,
      builder: (_, __) {
        if (!monitor.show) return const SizedBox.shrink();
        return Obx(() {
          final route = ConnectionTypeState.find(peerId);
          if (!route.isValid()) return const SizedBox.shrink();
          final d = monitor.data;
          final rate = d.videoKbps;
          final displays = ffi.ffiModel.pi.getCurDisplays();
          final lines = [
            elapsed(d.elapsedSeconds ?? 0),
            sessionRouteLabel(route.stream_type.value,
                route.direct.value == ConnectionType.strDirect),
            '${d.fps ?? "—"} fps',
            '${rate == null ? "—" : (rate / 1000).toStringAsFixed(1)} Mbps',
            '${d.delay ?? "—"} ms RTT',
            if (displays.length == 1)
              '${displays.first.height}P · ${displays.first.width}×${displays.first.height}',
            if (d.codecFormat != null) d.codecFormat!,
          ];
          return Container(
            constraints: const BoxConstraints(maxWidth: 290),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x6630394a),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Text(lines.join('\n'), style: const TextStyle(
                fontFamily: 'monospace', fontSize: 13, height: 1.5,
                shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                color: Colors.white, decoration: TextDecoration.none)),
          );
        });
      },
    );
  }
}
