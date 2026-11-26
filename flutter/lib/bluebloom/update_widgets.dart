import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common.dart';
import '../utils/http_service.dart' as app_http;
import 'release.dart';

final blueBloomUpdate = ValueNotifier<BlueBloomRelease?>(null);
Future<BlueBloomRelease>? _pendingCheck;

Future<BlueBloomRelease> _fetchRelease() =>
    _pendingCheck ??= fetchBlueBloomRelease(request: app_http.get)
        .whenComplete(() => _pendingCheck = null);

Future<void> checkBlueBloomUpdateOnStartup() async {
  try {
    final release = await _fetchRelease();
    blueBloomUpdate.value =
        isNewerRelease(release.tag, version) ? release : null;
  } catch (error) {
    debugPrint('BlueBloom update check: $error');
  }
}

Future<void> _openUpdateLink(BuildContext context, Uri url) async {
  try {
    if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  } catch (error) {
    debugPrint('BlueBloom update link: $error');
  }
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(const SnackBar(content: Text('无法打开浏览器，请稍后重试。')));
  }
}

void showBlueBloomUpdate(BuildContext context, BlueBloomRelease release) {
  final assets = release.assets.where((asset) {
    final name = asset.name;
    if (isWindows) return name.endsWith('.exe') || name.endsWith('.msi');
    if (isMacOS) return name.endsWith('.dmg');
    if (isAndroid) return name.endsWith('.apk');
    if (isIOS) return name.endsWith('.ipa');
    return RegExp(r'\.(deb|rpm|AppImage|flatpak|zst)$').hasMatch(name);
  }).toList();
  showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: Text('蓝花远控 ${release.tag}'),
            content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('当前版本：$version'),
                        const SizedBox(height: 12),
                        SelectableText(release.notes.isEmpty
                            ? '此版本未提供更新说明。'
                            : release.notes),
                        const Divider(height: 28),
                        const Text('选择安装包，在浏览器中下载后安装：'),
                        if (isIOS) const Text('iOS IPA 需要自行签名后安装。'),
                        if (assets.isEmpty) const Text('此版本没有当前平台的安装包。'),
                        for (final asset in assets)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.download_outlined),
                            title: Text(asset.name),
                            onTap: () => _openUpdateLink(context, asset.url),
                          ),
                      ]),
                )),
            actions: [
              TextButton(
                  onPressed: () => _openUpdateLink(context, release.page),
                  child: const Text('查看发布页')),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭')),
            ],
          ));
}

class BlueBloomUpdateButton extends StatefulWidget {
  const BlueBloomUpdateButton({super.key});
  @override
  State<BlueBloomUpdateButton> createState() => _BlueBloomUpdateButtonState();
}

class _BlueBloomUpdateButtonState extends State<BlueBloomUpdateButton> {
  bool _busy = false;
  String _status = '';

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _status = '';
    });
    try {
      final release = await _fetchRelease();
      if (!mounted) return;
      if (isNewerRelease(release.tag, version)) {
        blueBloomUpdate.value = release;
        showBlueBloomUpdate(context, release);
        _status = '发现新版本 ${release.tag}';
      } else {
        blueBloomUpdate.value = null;
        _status = '当前已是最新版本（$version）';
      }
    } catch (error) {
      debugPrint('BlueBloom manual update check: $error');
      if (mounted) _status = '检查失败，请检查网络连接后重试。';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _check,
            icon: const Icon(Icons.system_update_alt),
            label: Text(_busy ? '正在检查…' : '检查更新'),
          ),
          if (_status.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 6), child: Text(_status)),
        ],
      );
}

class BlueBloomUpdateNotice extends StatelessWidget {
  const BlueBloomUpdateNotice({super.key});
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<BlueBloomRelease?>(
        valueListenable: blueBloomUpdate,
        builder: (context, release, _) => release == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.system_update_alt),
                  label: Text('新版本 ${release.tag} · 查看更新'),
                  onPressed: () => showBlueBloomUpdate(context, release),
                )),
      );
}
