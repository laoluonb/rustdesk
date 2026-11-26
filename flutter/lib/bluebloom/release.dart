import 'dart:convert';

import 'package:http/http.dart' as http;

import 'brand.dart';

List<int> _versionParts(String value) {
  final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:\+\d+)?$').firstMatch(value);
  if (match == null) throw const FormatException('Invalid stable version');
  return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
}

bool isNewerRelease(String candidate, String installed) {
  final next = _versionParts(candidate);
  final current = _versionParts(installed);
  for (var i = 0; i < 3; i++) {
    if (next[i] != current[i]) return next[i] > current[i];
  }
  return false;
}

class ReleaseAsset {
  final String name;
  final Uri url;
  const ReleaseAsset(this.name, this.url);
}

class BlueBloomRelease {
  final String tag;
  final String notes;
  final Uri page;
  final List<ReleaseAsset> assets;
  const BlueBloomRelease(this.tag, this.notes, this.page, this.assets);

  factory BlueBloomRelease.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String;
    _versionParts(tag);
    if (json['draft'] != false ||
        json['prerelease'] != false ||
        json['html_url'] != '$blueBloomReleases/tag/$tag') {
      throw const FormatException('Unexpected release source or channel');
    }
    final assets = <ReleaseAsset>[];
    for (final item in json['assets'] as List) {
      final name = item['name'] as String;
      final url = Uri.parse(item['browser_download_url'] as String);
      if (url.toString() != '$blueBloomReleases/download/$tag/$name' ||
          name.contains('/') ||
          name.contains('\\') ||
          name.contains('%') ||
          url.hasQuery ||
          url.hasFragment ||
          url.userInfo.isNotEmpty) {
        throw const FormatException('Unexpected download source');
      }
      if (RegExp(r'\.(exe|msi|dmg|apk|ipa|deb|rpm|AppImage|flatpak|zst)$')
          .hasMatch(name)) {
        assets.add(ReleaseAsset(name, url));
      }
    }
    if (assets.isEmpty) throw const FormatException('No installation packages');
    return BlueBloomRelease(tag, json['body'] as String? ?? '',
        Uri.parse(json['html_url'] as String), assets);
  }
}

typedef ReleaseRequest = Future<http.Response> Function(Uri url,
    {Map<String, String>? headers});

Future<BlueBloomRelease> fetchBlueBloomRelease(
    {http.Client? client, ReleaseRequest? request}) async {
  final connection = client ?? (request == null ? http.Client() : null);
  try {
    final url = Uri.parse(
        'https://api.github.com/repos/laoluonb/rustdesk/releases/latest');
    const headers = {'Accept': 'application/vnd.github+json'};
    final response = request != null
        ? await request(url, headers: headers)
        : await connection!
            .get(url, headers: headers)
            .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw http.ClientException('Release check HTTP ${response.statusCode}');
    }
    return BlueBloomRelease.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>);
  } finally {
    if (client == null) connection?.close();
  }
}
