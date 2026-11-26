import 'package:flutter_test/flutter_test.dart';
import '../lib/bluebloom/session_presentation.dart';

void main() {
  test('FPS choices follow each remote display instead of stopping at 120', () {
    for (final hz in [60.0, 144.0, 165.0, 240.0, 360.0]) {
      final limit = displayFpsLimit(hz);
      final choices = blueBloomFpsPresets(limit);
      expect(choices.last, hz.round());
      expect(choices.every((value) => value <= hz), isTrue);
    }
    expect(displayFpsLimit(119.88), 120);
    expect(displayFpsLimit(0), 120);
  });
  test('connection overlay distinguishes verified LAN, P2P and relay', () {
    expect(sessionRouteLabel('UDP/LAN', true), 'UDP LAN');
    expect(sessionRouteLabel('TCP/LAN', true), 'TCP LAN');
    expect(sessionRouteLabel('UDP', true), 'UDP P2P');
    expect(sessionRouteLabel('TCP', true), 'TCP P2P');
    expect(sessionRouteLabel('Relay', false), 'TCP Relay');
    expect(sessionRouteLabel('WebSocket', false), 'WebSocket Relay');
    expect(sessionRouteLabel('WebRTC', false), 'WebRTC Relay');
    expect(sessionRouteLabel('IPv6', true), 'UDP/IPv6 P2P');
    expect(sessionRouteLabel('UDP/IPv6/LAN', true), 'UDP/IPv6 LAN');
    expect(sessionRouteLabel('TCP/LAN', false), 'TCP Relay');
  });
  test('custom bitrate accepts Mbps and rejects unsafe or unsupported values',
      () {
    expect(parseTargetBitrate('14'), 14000);
    expect(parseTargetBitrate('0.5'), 500);
    expect(parseTargetBitrate('100'), 100000);
    for (final value in ['0', '-8', 'NaN', 'Infinity', '101', 'abc']) {
      expect(parseTargetBitrate(value), isNull);
    }
  });
}
