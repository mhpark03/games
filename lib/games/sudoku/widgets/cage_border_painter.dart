import 'dart:math';
import 'package:flutter/material.dart';
import '../models/killer_cage.dart';

class CageBorderPainter extends CustomPainter {
  final List<KillerCage> cages;
  final double? cellSize;

  CageBorderPainter({required this.cages, this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    final cSize = cellSize ?? size.width / 9;
    final inset = cSize * 0.06; // 셀 안쪽 여백

    final paint = Paint()
      ..color = const Color(0xFF5B9BD5) // 진한 파란색
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Build lookup map for cage IDs
    Map<String, int> cellToCage = {};
    for (var cage in cages) {
      for (var cell in cage.cells) {
        cellToCage['${cell[0]}_${cell[1]}'] = cage.cageId;
      }
    }

    // Draw borders for each cell
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        String cellKey = '${row}_$col';
        int? currentCageId = cellToCage[cellKey];
        if (currentCageId == null) continue;

        double x = col * cSize;
        double y = row * cSize;

        // 각 방향의 이웃이 같은 케이지인지 확인
        bool topSame = row > 0 && cellToCage['${row - 1}_$col'] == currentCageId;
        bool bottomSame = row < 8 && cellToCage['${row + 1}_$col'] == currentCageId;
        bool leftSame = col > 0 && cellToCage['${row}_${col - 1}'] == currentCageId;
        bool rightSame = col < 8 && cellToCage['${row}_${col + 1}'] == currentCageId;

        // 대각선 이웃 확인 (코너 처리용)
        bool topLeftSame = row > 0 && col > 0 && cellToCage['${row - 1}_${col - 1}'] == currentCageId;
        bool topRightSame = row > 0 && col < 8 && cellToCage['${row - 1}_${col + 1}'] == currentCageId;
        bool bottomLeftSame = row < 8 && col > 0 && cellToCage['${row + 1}_${col - 1}'] == currentCageId;
        bool bottomRightSame = row < 8 && col < 8 && cellToCage['${row + 1}_${col + 1}'] == currentCageId;

        // 상단 경계
        if (!topSame) {
          double startX = x + (leftSame ? 0 : inset);
          double endX = x + cSize - (rightSame ? 0 : inset);
          _drawDashedLine(
            canvas,
            Offset(startX, y + inset),
            Offset(endX, y + inset),
            paint,
          );
        }

        // 하단 경계
        if (!bottomSame) {
          double startX = x + (leftSame ? 0 : inset);
          double endX = x + cSize - (rightSame ? 0 : inset);
          _drawDashedLine(
            canvas,
            Offset(startX, y + cSize - inset),
            Offset(endX, y + cSize - inset),
            paint,
          );
        }

        // 좌측 경계
        if (!leftSame) {
          double startY = y + (topSame ? 0 : inset);
          double endY = y + cSize - (bottomSame ? 0 : inset);
          _drawDashedLine(
            canvas,
            Offset(x + inset, startY),
            Offset(x + inset, endY),
            paint,
          );
        }

        // 우측 경계
        if (!rightSame) {
          double startY = y + (topSame ? 0 : inset);
          double endY = y + cSize - (bottomSame ? 0 : inset);
          _drawDashedLine(
            canvas,
            Offset(x + cSize - inset, startY),
            Offset(x + cSize - inset, endY),
            paint,
          );
        }

        // 내부 코너 처리 (ㄱ자 모양 케이지 등)
        // 좌상단 내부 코너
        if (topSame && leftSame && !topLeftSame) {
          _drawDashedLine(
            canvas,
            Offset(x, y + inset),
            Offset(x + inset, y + inset),
            paint,
          );
          _drawDashedLine(
            canvas,
            Offset(x + inset, y),
            Offset(x + inset, y + inset),
            paint,
          );
        }

        // 우상단 내부 코너
        if (topSame && rightSame && !topRightSame) {
          _drawDashedLine(
            canvas,
            Offset(x + cSize - inset, y + inset),
            Offset(x + cSize, y + inset),
            paint,
          );
          _drawDashedLine(
            canvas,
            Offset(x + cSize - inset, y),
            Offset(x + cSize - inset, y + inset),
            paint,
          );
        }

        // 좌하단 내부 코너
        if (bottomSame && leftSame && !bottomLeftSame) {
          _drawDashedLine(
            canvas,
            Offset(x, y + cSize - inset),
            Offset(x + inset, y + cSize - inset),
            paint,
          );
          _drawDashedLine(
            canvas,
            Offset(x + inset, y + cSize - inset),
            Offset(x + inset, y + cSize),
            paint,
          );
        }

        // 우하단 내부 코너
        if (bottomSame && rightSame && !bottomRightSame) {
          _drawDashedLine(
            canvas,
            Offset(x + cSize - inset, y + cSize - inset),
            Offset(x + cSize, y + cSize - inset),
            paint,
          );
          _drawDashedLine(
            canvas,
            Offset(x + cSize - inset, y + cSize - inset),
            Offset(x + cSize - inset, y + cSize),
            paint,
          );
        }
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLength = 5.0;
    const gapLength = 3.0;

    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final distance = (dx * dx + dy * dy);
    if (distance == 0) return;

    final len = distance > 0 ? sqrt(distance) : distance;
    if (len == 0) return;

    final unitX = dx / len;
    final unitY = dy / len;

    double drawn = 0;
    bool isDash = true;

    while (drawn < len) {
      if (isDash) {
        final dashEnd = (drawn + dashLength).clamp(0.0, len);
        canvas.drawLine(
          Offset(start.dx + unitX * drawn, start.dy + unitY * drawn),
          Offset(start.dx + unitX * dashEnd, start.dy + unitY * dashEnd),
          paint,
        );
        drawn = dashEnd;
      } else {
        drawn += gapLength;
      }
      isDash = !isDash;
    }
  }

  @override
  bool shouldRepaint(covariant CageBorderPainter oldDelegate) {
    return oldDelegate.cages != cages || oldDelegate.cellSize != cellSize;
  }
}
