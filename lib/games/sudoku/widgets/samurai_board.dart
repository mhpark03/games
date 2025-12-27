import 'package:flutter/material.dart';
import '../models/samurai_game_state.dart';
import 'mini_sudoku_board.dart';

class SamuraiBoard extends StatelessWidget {
  final SamuraiGameState gameState;
  final Function(int board, int row, int col) onCellTap;
  final Function(int board) onBoardSelect;

  const SamuraiBoard({
    super.key,
    required this.gameState,
    required this.onCellTap,
    required this.onBoardSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 21x21 그리드 (각 보드 9x9, 겹치는 부분 3x3씩)
        // 실제 배치: 가로 21칸, 세로 21칸
        double cellSize = constraints.maxWidth / 21;
        double boardSize = cellSize * 9;

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxWidth, // 정사각형
          child: Stack(
            children: [
              // 배경 (빈 공간을 회색으로)
              Container(color: Colors.grey.shade300),

              // 보드 0: 좌상단 (0,0)
              Positioned(
                left: 0,
                top: 0,
                child: _buildBoard(0, boardSize),
              ),

              // 보드 1: 우상단 (12,0)
              Positioned(
                left: cellSize * 12,
                top: 0,
                child: _buildBoard(1, boardSize),
              ),

              // 보드 2: 중앙 (6,6)
              Positioned(
                left: cellSize * 6,
                top: cellSize * 6,
                child: _buildBoard(2, boardSize),
              ),

              // 보드 3: 좌하단 (0,12)
              Positioned(
                left: 0,
                top: cellSize * 12,
                child: _buildBoard(3, boardSize),
              ),

              // 보드 4: 우하단 (12,12)
              Positioned(
                left: cellSize * 12,
                top: cellSize * 12,
                child: _buildBoard(4, boardSize),
              ),

              // 보드 번호 표시
              ..._buildBoardLabels(cellSize),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBoard(int boardIndex, double size) {
    bool isSelected = gameState.selectedBoard == boardIndex;

    return GestureDetector(
      onTap: () => onBoardSelect(boardIndex),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.black,
            width: isSelected ? 3 : 2,
          ),
        ),
        child: MiniSudokuBoard(
          board: gameState.currentBoards[boardIndex],
          isFixed: gameState.isFixed[boardIndex],
          boardIndex: boardIndex,
          gameState: gameState,
          onCellTap: (row, col) => onCellTap(boardIndex, row, col),
          isActiveBoard: isSelected,
        ),
      ),
    );
  }

  List<Widget> _buildBoardLabels(double cellSize) {
    final positions = [
      Offset(cellSize * 4.5, cellSize * 0.3), // 보드 0
      Offset(cellSize * 16.5, cellSize * 0.3), // 보드 1
      Offset(cellSize * 10.5, cellSize * 6.3), // 보드 2
      Offset(cellSize * 4.5, cellSize * 12.3), // 보드 3
      Offset(cellSize * 16.5, cellSize * 12.3), // 보드 4
    ];

    return List.generate(5, (index) {
      bool isSelected = gameState.selectedBoard == index;
      return Positioned(
        left: positions[index].dx - 12,
        top: positions[index].dy - 12,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.blue.shade200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    });
  }
}
