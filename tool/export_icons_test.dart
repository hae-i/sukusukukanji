// Reproducible brand assets: flutter test tool/export_icons_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukusukukanji/data/models/grade_theme.dart';
import 'package:sukusukukanji/widgets/plant_mark.dart';

void main() {
  testWidgets('export six growth icons', (tester) async {
    await tester.runAsync(() async {
      for (final stage in PlantStage.values) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 1024, 1024),
          Paint()..color = const Color(0xFFF7F4E8),
        );
        canvas.translate(112, 112);
        PlantPainter(stage).paint(canvas, const Size.square(800));
        final picture = recorder.endRecording();
        final image = await picture.toImage(1024, 1024);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('assets/icons/grade${stage.index + 1}.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      }
    });
  });
}
