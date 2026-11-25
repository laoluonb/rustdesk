import 'package:flutter/widgets.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/input_model.dart';
import 'package:flutter_hbb/models/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

class _Input implements InputModel {
  @override
  Size? imageWidgetSize;

  @override
  void updateImageWidgetSize(Size size) {
    imageWidgetSize = size;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session implements FFI {
  @override
  final sessionId = UuidValue('00000000-0000-0000-0000-000000000000');

  @override
  final inputModel = _Input();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fit uses the canvas area below the tabs and above the status bar', () {
    final session = _Session();
    final canvas = CanvasModel(WeakReference<FFI>(session));
    for (final viewport in [const Size(1280, 650), const Size(900, 500)]) {
      session.inputModel.updateImageWidgetSize(viewport);
      final size = canvas.getSize();
      expect(size, viewport);
      final fit = ViewStyle(
        style: kRemoteViewStyleAdaptive,
        width: size.width,
        height: size.height,
        displayWidth: 1920,
        displayHeight: 1080,
      );
      expect(1920 * fit.scale, lessThanOrEqualTo(viewport.width));
      expect(1080 * fit.scale, lessThanOrEqualTo(viewport.height));
    }
  });

  test('a named connection shows the alias and its identifying ID', () {
    expect(getDesktopTabLabel('533088447', '办公室电脑'),
        '办公室电脑 · 533088447');
  });
}
