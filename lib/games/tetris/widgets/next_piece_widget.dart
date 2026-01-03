import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/piece.dart';

class NextPieceWidget extends StatelessWidget {
  final Piece? piece;

  const NextPieceWidget({super.key, required this.piece});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 2),
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'games.tetris.next'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 80,
            height: 80,
            child: piece != null
                ? CustomPaint(
                    painter: PiecePainter(piece!),
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}

class PiecePainter extends CustomPainter {
  final Piece piece;

  PiecePainter(this.piece);

  @override
  void paint(Canvas canvas, Size size) {
    List<List<int>> shape = piece.shape;
    double cellSize = size.width / 4;

    double offsetX = (4 - shape[0].length) * cellSize / 2;
    double offsetY = (4 - shape.length) * cellSize / 2;

    for (int row = 0; row < shape.length; row++) {
      for (int col = 0; col < shape[row].length; col++) {
        if (shape[row][col] == 1) {
          _drawCell(
            canvas,
            offsetX + col * cellSize,
            offsetY + row * cellSize,
            cellSize,
            piece.color,
          );
        }
      }
    }
  }

  void _drawCell(Canvas canvas, double x, double y, double size, Color color) {
    Paint fillPaint = Paint()..color = color;
    Paint borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(x + 1, y + 1, size - 2, size - 2),
      fillPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(x + 1, y + 1, size - 2, size - 2),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
