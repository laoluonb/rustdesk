import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../common.dart';
import '../../models/platform_model.dart';

/// Home-screen appearance. Connection windows keep their own theme and layout.
class HomeWallpaper extends StatefulWidget {
  const HomeWallpaper({Key? key, required this.child}) : super(key: key);
  final Widget child;

  @override
  State<HomeWallpaper> createState() => _HomeWallpaperState();
}

class _HomeWallpaperState extends State<HomeWallpaper> {
  static const option = 'laoluowl-home-background';
  static const ycy = 'https://t.alcy.cc/ycy';
  late String mode;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    mode = bind.mainGetLocalOption(key: option);
  }

  Future<void> choose(String next) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (next == 'file') {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        );
        final path = picked?.files.single.path;
        if (path == null) return;
        final dir = await getApplicationSupportDirectory();
        await dir.create(recursive: true);
        final a = '${dir.path}/laoluowl-wallpaper-a';
        final b = '${dir.path}/laoluowl-wallpaper-b';
        next = mode == a ? b : a;
        await File(path).copy(next);
        await FileImage(File(next)).evict();
      }
      await bind.mainSetLocalOption(key: option, value: next);
      if (mounted) setState(() => mode = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(translate('Failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xff192535) : const Color(0xffeffaff);
    final ink = dark ? const Color(0xffbfd5ff) : const Color(0xff365d96);
    final local = mode.isNotEmpty && mode != 'plain' && mode != 'ycy';
    final preferred = bind.mainGetLocalOption(key: 'lang');
    final language = preferred.isEmpty ? localeName.toString() : preferred;
    final zh = language.startsWith('zh') || language == 'cn' || language == 'tw';
    String label(String cn, String en) => zh ? cn : en;
    Widget fallback(BuildContext _, Object error, StackTrace? trace) =>
        const SizedBox.shrink();
    return ColoredBox(
      color: base,
      child: Stack(fit: StackFit.expand, children: [
        if (mode != 'plain')
          ExcludeSemantics(child: local
              ? Image.file(File(mode), key: ValueKey(mode), fit: BoxFit.cover,
                  errorBuilder: fallback)
              : Image.network(ycy, fit: BoxFit.cover, errorBuilder: fallback)),
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base.withOpacity(.94), base.withOpacity(.72)],
        ))),
        Column(children: [
          SizedBox(height: 46, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(Icons.auto_awesome_outlined, color: ink, size: 17),
              const SizedBox(width: 8),
              Expanded(child: Text('Hi, Friend!',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Georgia', fontSize: 21,
                    fontWeight: FontWeight.w600, color: ink))),
              PopupMenuButton<String>(
                enabled: !busy,
                tooltip: label('更换首页背景', 'Change home background'),
                icon: Icon(Icons.wallpaper_outlined, color: ink, size: 21),
                onSelected: choose,
                itemBuilder: (_) => [
                  CheckedPopupMenuItem(value: 'ycy', checked: !local && mode != 'plain',
                      child: Text(label('随机插画 · YCY', 'Random illustration · YCY'))),
                  CheckedPopupMenuItem(value: 'plain', checked: mode == 'plain',
                      child: Text(label('冰蓝纯色', 'Ice blue'))),
                  if (!isWeb)
                    CheckedPopupMenuItem(value: 'file', checked: local,
                        child: Text(label('选择本机图片…', 'Choose a local image…'))),
                ],
              ),
            ]),
          )),
          Expanded(child: widget.child),
        ]),
      ]),
    );
  }
}
