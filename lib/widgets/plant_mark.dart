import 'package:flutter/material.dart';

import '../data/models/grade_theme.dart';

/// Single visual boundary, replaceable by a cohesive illustrated asset family.
class PlantMark extends StatelessWidget {
  const PlantMark({super.key, required this.stage, this.size = 72});
  final PlantStage stage;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: PlantPainter(stage)),
    ),
  );
}

class PlantPainter extends CustomPainter {
  const PlantPainter(this.stage);
  final PlantStage stage;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final stem = Paint()
      ..color = const Color(0xFF355D43)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final height = 44.0 + stage.index * 5;
    canvas.drawPath(
      Path()
        ..moveTo(50, 87)
        ..quadraticBezierTo(45, 62, 53, 87 - height),
      stem,
    );
    for (var i = 0; i <= stage.index ~/ 2; i++) {
      final y = 66.0 - i * 17;
      canvas.drawPath(
        Path()
          ..moveTo(50, y)
          ..cubicTo(24, y + 2, 18, y - 12, 18, y - 22)
          ..cubicTo(40, y - 23, 49, y - 10, 50, y)
          ..close(),
        Paint()..color = const Color(0xFF779B62),
      );
      canvas.drawPath(
        Path()
          ..moveTo(50, y - 8)
          ..cubicTo(51, y - 25, 65, y - 32, 83, y - 29)
          ..cubicTo(82, y - 12, 68, y - 4, 50, y - 8)
          ..close(),
        Paint()..color = const Color(0xFF355D43),
      );
    }
    if (stage.index >= 3) {
      canvas.drawPath(
        Path()
          ..moveTo(46, 88)
          ..lineTo(48, 40)
          ..lineTo(53, 40)
          ..lineTo(56, 88)
          ..close(),
        Paint()..color = const Color(0xFF866B50),
      );
    }
    if (stage.index >= 4) {
      final canopy = Paint()..color = const Color(0xFF355D43);
      final extent = stage == PlantStage.fullTree ? 34.0 : 25.0;
      canvas.drawCircle(Offset(50, 34), extent, canopy);
      canvas.drawCircle(Offset(34, 45), extent * .7, canopy);
      canvas.drawCircle(
        Offset(68, 45),
        extent * .7,
        Paint()..color = const Color(0xFF779B62),
      );
    }
    canvas.drawOval(
      const Rect.fromLTWH(30, 86, 40, 5),
      Paint()..color = const Color(0xFFD6DCCB),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlantPainter oldDelegate) => oldDelegate.stage != stage;
}
