import 'dart:convert';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/generated_bridge.dart';
import 'package:flutter_hbb/models/ab_model.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _Cloud extends Fake implements RustdeskImpl {
  final peers = <String, Map<String, dynamic>>{};
  final responses = <String, String>{};
  bool rejectWrite = false;

  @override
  String mainGetLocalOption({required String key, dynamic hint}) =>
      key == kOptionEnableFlutterHttpOnRust ? 'Y' : 'old-local-alias';
  @override
  String getLocalFlutterOption({required String k, dynamic hint}) => '';
  @override
  String mainGetBuildinOption({required String key, dynamic hint}) => '';
  @override
  bool isDisableAb({dynamic hint}) => false;
  @override
  bool isDisableAccount({dynamic hint}) => false;
  @override
  bool isDisableGroupPanel({dynamic hint}) => false;
  @override
  String mainGetPeerOptionSync(
          {required String id, required String key, dynamic hint}) =>
      'old-local-alias';
  @override
  Future<String> mainGetApiServer({dynamic hint}) async => 'https://example.com';
  @override
  String translate(
          {required String name, required String locale, dynamic hint}) => name;
  @override
  Future<void> mainSaveAb({required String json, dynamic hint}) async {}

  @override
  Future<void> mainHttpRequest({required String url, required String method,
      String? body, required String header, dynamic hint}) async {
    final path = Uri.parse(url).path;
    dynamic result;
    if (path == '/api/ab/peers') {
      expect(Uri.parse(url).queryParameters['ab'], 'personal');
      result = {'total': peers.length, 'data': peers.values.toList()};
    } else if (path == '/api/ab/tags/personal') {
      result = [];
    } else if (path == '/api/ab/peer/add/personal') {
      expect(method, 'post');
      final p = jsonDecode(body!);
      if (!rejectWrite) {
        expect(p.containsKey('password'), false);
        expect(p.containsKey('hash'), false);
        peers[p['id']] = Map<String, dynamic>.from(p);
      }
      result = rejectWrite ? {'error': 'write rejected'} : null;
    } else if (path == '/api/ab/peer/update/personal') {
      expect(method, 'put');
      final p = jsonDecode(body!);
      if (!rejectWrite) peers[p['id']]!['alias'] = p['alias'];
      result = rejectWrite ? {'error': 'write rejected'} : null;
    } else {
      fail('Unexpected request: $method $path');
    }
    responses[url] = jsonEncode({
      'body': result == null ? '' : jsonEncode(result),
      'status_code': 200, 'headers': {'content-type': 'application/json; charset=utf-8'},
    });
  }

  @override
  Future<String?> mainGetHttpStatus({required String url, dynamic hint}) async =>
      responses[url];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cloud = _Cloud();
  setUpAll(() async {
    isTest = true;
    platformFFI.setBindingForTesting(cloud);
    await initGlobalFFI();
  });

  void newDevice() {
    final model = gFFI.abModel;
    model.addressbooks.clear();
    model.listInitialized = true;
    model.addressbooks['My address book'] = Ab(
        AbProfile('personal', 'My address book', 'owner', null, 0, null), true);
    gFFI.groupModel.peers.value = [Peer.fromJson({'id': '533088447'})];
  }

  test('device rename is saved to the personal account and read on another device', () async {
    newDevice();
    expect(await gFFI.abModel.changeDeviceAlias(
        gFFI.groupModel.peers.first, '幻14'), true);
    expect(cloud.peers['533088447']!['alias'], '幻14');
    newDevice();
    await gFFI.abModel.pullDeviceAliases();
    gFFI.groupModel.refreshLocalAliases();
    expect(gFFI.groupModel.peers.first.alias, '幻14');
  });

  test('clearing a cloud alias does not resurrect an old local alias', () async {
    newDevice();
    cloud.peers['533088447'] = {'id': '533088447', 'alias': '幻14'};
    expect(await gFFI.abModel.changeDeviceAlias(
        gFFI.groupModel.peers.first, ''), true);
    newDevice();
    await gFFI.abModel.pullDeviceAliases();
    gFFI.groupModel.refreshLocalAliases();
    expect(gFFI.groupModel.peers.first.alias, '');
  });

  test('monitor model exposes the remote display name and resolution', () {
    final display = gFFI.ffiModel.evtToDisplay({
      'name': r'\\.\DISPLAY1', 'friendly_name': 'TL140BDXP01-0',
      'width': 2560, 'height': 1440,
    });
    expect(display.monitorDescription, 'TL140BDXP01-0 · 2560×1440');
    display.friendlyName = '';
    expect(display.monitorDescription, r'\\.\DISPLAY1 · 2560×1440');
    final legacy = gFFI.ffiModel.evtToDisplay({'width': 1920, 'height': 1080});
    expect(legacy.monitorDescription, '1920×1080');
  });

  test('display name changes are visible even with unchanged geometry', () {
    final first = Display()..friendlyName = 'Internal';
    final second = Display()..friendlyName = 'External';
    expect(first == second, false);
  });

  test('failed upload cannot report a successful rename', () async {
    newDevice();
    cloud.peers.clear();
    cloud.rejectWrite = true;
    expect(await gFFI.abModel.changeDeviceAlias(
        gFFI.groupModel.peers.first, 'not-saved'), false);
    expect(cloud.peers, isEmpty);
    cloud.rejectWrite = false;
  });
}
