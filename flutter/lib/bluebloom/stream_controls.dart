import '../common.dart';
import '../models/platform_model.dart';
import '../models/model.dart';
import 'package:flutter/material.dart';
import 'session_presentation.dart';

Future<void> useCustomStreamQuality(FFI ffi) async {
  if (await bind.sessionGetImageQuality(sessionId: ffi.sessionId) != 'custom') {
    final saved =
        await bind.sessionGetCustomImageQuality(sessionId: ffi.sessionId);
    await bind.sessionSetCustomImageQuality(
        sessionId: ffi.sessionId,
        value: saved != null && saved.isNotEmpty ? saved.first : 50);
    // Non-custom modes run at 30 fps; persist that limit when entering custom mode.
    await bind.sessionSetCustomFps(sessionId: ffi.sessionId, fps: 30);
  }
}

Future<void> setTargetBitrate(FFI ffi, int kbps) async {
  if (kbps > 0) await useCustomStreamQuality(ffi);
  await bind.sessionPeerOption(
      sessionId: ffi.sessionId,
      name: blueBloomBitrateOption,
      value: kbps.toString());
}

void showTargetBitrateDialog(FFI ffi, int current) {
  var text = current > 0 ? (current / 1000).toString() : '8';
  String? error;
  var saving = false;
  ffi.dialogManager.show((setState, close, context) {
    Future<void> submit() async {
      if (saving) return;
      final value = parseTargetBitrate(text);
      if (value == null) {
        setState(() => error = '请输入 0.5–100 Mbps');
        return;
      }
      setState(() => saving = true);
      try {
        await setTargetBitrate(ffi, value);
        close();
      } catch (e) {
        setState(() {
          saving = false;
          error = '设置失败，请重试';
        });
      }
    }

    return CustomAlertDialog(
      title: const Text('目标码率'),
      content: SizedBox(
          width: 330,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
                initialValue: text,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: '码率', suffixText: 'Mbps', errorText: error),
                onChanged: (value) => text = value,
                onFieldSubmitted: (_) => submit()),
            const SizedBox(height: 12),
            const Text('手动设置编码目标，选择自动恢复自适应。实际码率随画面变化并受硬件限制；多屏为每屏目标，多人观看采用较低目标。'),
          ])),
      actions: [
        dialogButton('Cancel',
            onPressed: saving ? null : close, isOutline: true),
        dialogButton('OK', onPressed: saving ? null : submit)
      ],
      onCancel: saving ? null : close,
      onSubmit: saving ? null : submit,
    );
  });
}
