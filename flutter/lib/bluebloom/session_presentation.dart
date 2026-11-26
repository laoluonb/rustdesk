String sessionRouteLabel(String transport, bool direct) {
  final lan = direct && transport.endsWith('/LAN');
  var protocol = transport.replaceAll('/LAN', '');
  if (protocol == 'Relay') protocol = 'TCP';
  if (protocol == 'IPv6') protocol = 'UDP/IPv6';
  if (protocol.isEmpty) protocol = '—';
  return '$protocol ${!direct ? "Relay" : lan ? "LAN" : "P2P"}';
}

const blueBloomFpsPresets = [30, 60, 90, 120];
const blueBloomBitratePresets = [8000, 14000, 30000];
const blueBloomBitrateOption = 'bluebloom-bitrate-kbps';

int? parseTargetBitrate(String text) {
  final mbps = double.tryParse(text.trim());
  if (mbps == null || !mbps.isFinite || mbps < 0.5 || mbps > 100) return null;
  return (mbps * 1000).round();
}
