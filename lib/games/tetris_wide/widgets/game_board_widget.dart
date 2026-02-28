import 'package:flutter/material.dart';
import '../models/game_board.dart';

class GameBoardWidget extends StatelessWidget {
  final GameBoard gameBoard;

  const GameBoardWidget({super.key, required this.gameBoard});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: GameBoard.cols / GameBoard.rows,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          color: Colors.black,
        ),
        child: CustomPaint(
          painter: BoardPainter(gameBoard),
        ),
      ),
    );
  }
}

class BoardPainter extends CustomPainter {
  final GameBoard gameBoard;

  BoardPainter(this.gameBoard);

  @override
  void paint(Canvas canvas, Size size) {
    double cellWidth = size.width / GameBoard.cols;
    double cellHeight = size.height / GameBoard.rows;

    Paint gridPaint = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = 0.5;

    for (int i = 0; i <= GameBoard.cols; i++) {
      canvas.drawLine(
        Offset(i * cellWidth, 0),
        Offset(i * cellWidth, size.height),
        gridPaint,
      );
    }
    for (int i = 0; i <= GameBoard.rows; i++) {
      canvas.drawLine(
        Offset(0, i * cellHeight),
        Offset(size.width, i * cellHeight),
        gridPaint,
      );
    }

    for (int row = 0; row < GameBoard.rows; row++) {
      for (int col = 0; col < GameBoard.cols; col++) {
        if (gameBoard.board[row][col] != null) {
          _drawCell(
            canvas,
            col * cellWidth,
            row * cellHeight,
            cellWidth,
            cellHeight,
            gameBoard.board[row][col]!,
          );
        }
      }
    }

    if (gameBoard.currentPiece != null && !gameBoard.isGameOver) {
      int ghostY = gameBoard.getGhostY();
      for (var cell in gameBoard.currentPiece!.cells) {
        int row = ghostY + (cell[0] - gameBoard.currentPiece!.y);
        int col = cell[1];
        if (row >= 0 && row < GameBoard.rows && col >= 0 && col < GameBoard.cols) {
          _drawGhostCell(
            canvas,
            col * cellWidth,
            row * cellHeight,
            cellWidth,
            cellHeight,
            gameBoard.currentPiece!.color,
          );
        }
      }
    }

    if (gameBoard.currentPiece != null && !gameBoard.isGameOver) {
      for (var cell in gameBoard.currentPiece!.cells) {
        int row = cell[0];
        int col = cell[1];
        if (row >= 0 && row < GameBoard.rows && col >= 0 && col < GameBoard.cols) {
          _drawCell(
            canvas,
            col * cellWidth,
            row * cellHeight,
            cellWidth,
            cellHeight,
            gameBoard.currentPiece!.color,
          );
        }
      }
    }
  }

  void _drawCell(Canvas canvas, double x, double y, double width, double height, Color color) {
    Paint fillPaint = Paint()..color = color;
    Paint borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(x + 1, y + 1, width - 2, height - 2),
      fillPaint,
    );

    canvas.drawLine(
      Offset(x + 2, y + 2),
      Offset(x + width - 2, y + 2),
      borderPaint,
    );
    canvas.drawLine(
      Offset(x + 2, y + 2),
      Offset(x + 2, y + height - 2),
      borderPaint,
    );

    canvas.drawLine(
      Offset(x + width - 2, y + 2),
      Offset(x + width - 2, y + height - 2),
      shadowPaint,
    );
    canvas.drawLine(
      Offset(x + 2, y + height - 2),
      Offset(x + width - 2, y + height - 2),
      shadowPaint,
    );
  }

  void _drawGhostCell(Canvas canvas, double x, double y, double width, double height, Color color) {
    Paint ghostPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRect(
      Rect.fromLTWH(x + 2, y + 2, width - 4, height - 4),
      ghostPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
