import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common.dart';
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
          final relay = route.relayServer.value;
          final lines = [
            elapsed(d.elapsedSeconds ?? 0),
            getConnectionText(route.secure.value == ConnectionType.strSecure,
                route.direct.value == ConnectionType.strDirect, route.stream_type.value),
            if (relay.isNotEmpty) '${translate("Relay Server")}: $relay',
            '${d.fps ?? "—"} fps',
            '${translate("Bitrate")}: ${rate == null ? "—" : (rate / 1000).toStringAsFixed(2)} Mbps',
            'RTT: ${d.delay ?? "—"} ms',
            if (displays.length == 1)
              '${displays.first.width} × ${displays.first.height}',
            if (d.codecFormat != null) d.codecFormat!,
          ];
          return Container(
            constraints: const BoxConstraints(maxWidth: 290),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xc4262b35),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(lines.join('\n'), style: const TextStyle(
                fontFamily: 'monospace', fontSize: 12, height: 1.4,
                color: Colors.white, decoration: TextDecoration.none)),
          );
        });
      },
    );
  }
}
