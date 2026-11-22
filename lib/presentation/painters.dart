import 'dart:math';

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../domain/arkanoid_engine.dart';
import '../domain/fuseball_engine.dart';
import '../domain/models.dart';

/// Перевод между пикселями экрана и логическими координатами мира.
class WorldTransform {
  const WorldTransform(this.scale, this.dx, this.dy);

  factory WorldTransform.fit(Size s) {
    final sc = min(s.width / kWorldW, s.height / kWorldH);
    return WorldTransform(
      sc,
      (s.width - kWorldW * sc) / 2,
      (s.height - kWorldH * sc) / 2,
    );
  }

  final double scale;
  final double dx;
  final double dy;

  double toWorldX(double px) => scale > 0 ? (px - dx) / scale : kWorldW / 2;
}

void _drawLabel(Canvas c, String s, Offset center, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

void _beginWorld(Canvas canvas, Size size) {
  final t = WorldTransform.fit(size);
  canvas.translate(t.dx, t.dy);
  canvas.scale(t.scale);
  final world = Rect.fromLTWH(0, 0, kWorldW, kWorldH);
  canvas.clipRect(world);
  canvas.drawRect(world, Paint()..color = AppColors.field);
}

void _drawBall(Canvas canvas, double x, double y, double r, {bool glow = true}) {
  if (glow) {
    canvas.drawCircle(
      Offset(x, y),
      r + 3,
      Paint()
        ..color = AppColors.accent.withAlpha(90)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }
  canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.white);
}

void _drawPaddle(Canvas canvas, Rect rect, Color color) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(7)),
    Paint()..color = color,
  );
}

class ArkanoidPainter extends CustomPainter {
  ArkanoidPainter(this.engine) : super(repaint: engine);
  final ArkanoidEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    _beginWorld(canvas, size);

    for (final b in engine.bricks) {
      final color = switch (b.type) {
        BrickType.normal => AppColors.brickRows[b.row % AppColors.brickRows.length],
        BrickType.silver => AppColors.silver,
        BrickType.gold => AppColors.gold,
      };
      final rr = RRect.fromRectAndRadius(b.rect, const Radius.circular(3));
      canvas.drawRRect(rr, Paint()..color = color);
      if (b.type != BrickType.normal) {
        canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white.withAlpha(200),
        );
        // «заклёпки» показывают, сколько ударов осталось
        final pip = Paint()..color = AppColors.bg;
        for (var i = 0; i < b.hp; i++) {
          final cx = b.rect.center.dx + (i - (b.hp - 1) / 2) * 8;
          canvas.drawCircle(Offset(cx, b.rect.center.dy), 2.2, pip);
        }
      }
    }

    for (final u in engine.powerUps) {
      final color = switch (u.type) {
        PowerUpType.wide => AppColors.accent,
        PowerUpType.multi => AppColors.accent2,
        PowerUpType.fast => AppColors.gold,
      };
      final label = switch (u.type) {
        PowerUpType.wide => '↔',
        PowerUpType.multi => '×3',
        PowerUpType.fast => '»',
      };
      canvas.drawRRect(
        RRect.fromRectAndRadius(u.rect, const Radius.circular(8)),
        Paint()..color = color,
      );
      _drawLabel(canvas, label, u.rect.center, 14, AppColors.bg);
    }

    _drawPaddle(
      canvas,
      engine.paddleRect,
      engine.wideTimer > 0 ? AppColors.gold : AppColors.accent,
    );
    final glow = engine.balls.length <= 10; // при сотне мячей свечение отключаем
    for (final b in engine.balls) {
      _drawBall(canvas, b.x, b.y, b.radius, glow: glow);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ArkanoidPainter old) => old.engine != engine;
}

class FuseballPainter extends CustomPainter {
  FuseballPainter(this.engine) : super(repaint: engine);
  final FuseballEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    _beginWorld(canvas, size);

    final rr = RRect.fromRectAndRadius(engine.brick, const Radius.circular(5));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = AppColors.gold.withAlpha(120)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(rr, Paint()..color = AppColors.gold);

    _drawPaddle(canvas, engine.paddleRect, AppColors.accent);
    _drawBall(canvas, engine.ballX, engine.ballY, FuseballEngine.ballRadius);
    canvas.restore();
  }

  @override
  bool shouldRepaint(FuseballPainter old) => old.engine != engine;
}
