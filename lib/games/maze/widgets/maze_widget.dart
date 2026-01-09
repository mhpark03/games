import 'package:flutter/material.dart';
import '../models/maze.dart';

class MazeWidget extends StatefulWidget {
  final Maze maze;
  final void Function(Position direction)? onMove;

  const MazeWidget({super.key, required this.maze, this.onMove});

  @override
  State<MazeWidget> createState() => _MazeWidgetState();
}

class _MazeWidgetState extends State<MazeWidget> {
  Offset? _dragStart;
  bool _isDraggingPlayer = false;
  Size? _widgetSize;
  static const double _dragThreshold = 15.0;

  bool _isOnPlayer(Offset position) {
    if (_widgetSize == null) return false;

    final cellWidth = _widgetSize!.width / widget.maze.cols;
    final cellHeight = _widgetSize!.height / widget.maze.rows;

    final col = (position.dx / cellWidth).floor();
    final row = (position.dy / cellHeight).floor();

    final playerPos = widget.maze.playerPos;
    return row == playerPos.row && col == playerPos.col;
  }

  void _handlePanStart(DragStartDetails details) {
    if (_isOnPlayer(details.localPosition)) {
      _isDraggingPlayer = true;
      _dragStart = details.localPosition;
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDraggingPlayer || _dragStart == null || widget.onMove == null) return;

    final delta = details.localPosition - _dragStart!;

    if (delta.distance < _dragThreshold) return;

    // 드래그 방향 결정
    Position? direction;
    if (delta.dx.abs() > delta.dy.abs()) {
      // 수평 이동
      direction = delta.dx > 0
          ? const Position(0, 1)  // 오른쪽
          : const Position(0, -1); // 왼쪽
    } else {
      // 수직 이동
      direction = delta.dy > 0
          ? const Position(1, 0)  // 아래
          : const Position(-1, 0); // 위
    }

    widget.onMove!(direction);
    _dragStart = details.localPosition; // 연속 이동을 위해 시작점 갱신
  }

  void _handlePanEnd(DragEndDetails details) {
    _dragStart = null;
    _isDraggingPlayer = false;
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.maze.cols / widget.maze.rows,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _widgetSize = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onPanStart: _handlePanStart,
            onPanUpdate: _handlePanUpdate,
            onPanEnd: _handlePanEnd,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF6B5B95), width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CustomPaint(
                  painter: MazePainter(maze: widget.maze),
                  size: Size.infinite,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MazePainter extends CustomPainter {
  final Maze maze;

  MazePainter({required this.maze});

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / maze.cols;
    final cellHeight = size.height / maze.rows;

    // 배경을 흰색으로 채우기
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    for (int row = 0; row < maze.rows; row++) {
      for (int col = 0; col < maze.cols; col++) {
        final cellType = maze.getCell(row, col);
        final rect = Rect.fromLTWH(
          col * cellWidth,
          row * cellHeight,
          cellWidth,
          cellHeight,
        );
        final pos = Position(row, col);
        final isVisited = maze.visitedPath.contains(pos);

        final paint = Paint();

        switch (cellType) {
          case CellType.wall:
            // 벽: 보라색
            paint.color = const Color(0xFF6B5B95);
            canvas.drawRect(rect, paint);
            break;
          case CellType.path:
            // 지나온 길 표시
            if (isVisited) {
              paint.color = const Color(0xFFE8D5F2);  // 연한 보라색
              canvas.drawRect(rect, paint);
            }
            break;
          case CellType.start:
            // 지나온 길이면 배경 색칠
            if (isVisited) {
              paint.color = const Color(0xFFE8D5F2);
              canvas.drawRect(rect, paint);
            }
            // 시작점 마커
            final startPaint = Paint()..color = const Color(0xFF6B5B95);
            canvas.drawCircle(
              Offset(col * cellWidth + cellWidth / 2, row * cellHeight + cellHeight / 2),
              cellWidth * 0.35,
              startPaint,
            );
            break;
          case CellType.end:
            // 도착점 마커
            final endPaint = Paint()..color = const Color(0xFFFFD700);
            canvas.drawCircle(
              Offset(col * cellWidth + cellWidth / 2, row * cellHeight + cellHeight / 2),
              cellWidth * 0.4,
              endPaint,
            );
            break;
          case CellType.player:
            // 플레이어
            final playerPaint = Paint()..color = const Color(0xFFE94560);  // 빨간색으로 구분
            canvas.drawCircle(
              Offset(col * cellWidth + cellWidth / 2, row * cellHeight + cellHeight / 2),
              cellWidth * 0.35,
              playerPaint,
            );
            break;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant MazePainter oldDelegate) {
    return true;
  }
}
