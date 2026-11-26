import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../lib/bluebloom/release.dart';

Map<String, dynamic> releaseJson() => {
      'tag_name': 'v1.5.8',
      'html_url': 'https://github.com/laoluonb/rustdesk/releases/tag/v1.5.8',
      'draft': false,
      'prerelease': false,
      'body': '更新说明',
      'assets': [
        {
          'name': 'rustdesk-1.5.8-x86_64.exe',
          'browser_download_url':
              'https://github.com/laoluonb/rustdesk/releases/download/v1.5.8/rustdesk-1.5.8-x86_64.exe',
        }
      ],
    };

void main() {
  test('only newer stable versions are offered, without string ordering', () {
    expect(isNewerRelease('v1.5.10', '1.5.9+74'), isTrue);
    expect(isNewerRelease('v1.5.7', '1.5.7'), isFalse);
    expect(isNewerRelease('v1.5.6', '1.5.7'), isFalse);
    expect(() => isNewerRelease('v1.5.8-beta', '1.5.7'), throwsFormatException);
  });

  test('checks the fork and preserves notes and package links', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(),
          'https://api.github.com/repos/laoluonb/rustdesk/releases/latest');
      return http.Response(jsonEncode(releaseJson()), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final release = await fetchBlueBloomRelease(request: client.get);
    expect(release.tag, 'v1.5.8');
    expect(release.notes, '更新说明');
    expect(release.assets.single.name, 'rustdesk-1.5.8-x86_64.exe');
    client.close();
  });

  test('rejects another repository, preview releases and HTTP errors',
      () async {
    expect(
        () => BlueBloomRelease.fromJson(releaseJson()
          ..['html_url'] =
              'https://github.com/rustdesk/rustdesk/releases/tag/v1.5.8'),
        throwsFormatException);
    expect(
        () => BlueBloomRelease.fromJson(releaseJson()..['prerelease'] = true),
        throwsFormatException);
    final invalid = releaseJson();
    (invalid['assets'] as List).first['browser_download_url'] =
        'https://example.com/client.exe';
    expect(() => BlueBloomRelease.fromJson(invalid), throwsFormatException);
    final client = MockClient((_) async => http.Response('rate limited', 403));
    await expectLater(fetchBlueBloomRelease(client: client),
        throwsA(isA<http.ClientException>()));
    client.close();
  });
}
