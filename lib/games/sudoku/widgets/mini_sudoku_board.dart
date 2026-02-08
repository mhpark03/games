import 'package:flutter/material.dart';
import '../models/samurai_game_state.dart';

class MiniSudokuBoard extends StatelessWidget {
  final List<List<int>> board;
  final List<List<bool>> isFixed;
  final int boardIndex;
  final SamuraiGameState gameState;
  final Function(int row, int col) onCellTap;
  final bool isActiveBoard;

  const MiniSudokuBoard({
    super.key,
    required this.board,
    required this.isFixed,
    required this.boardIndex,
    required this.gameState,
    required this.onCellTap,
    required this.isActiveBoard,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(9, (row) {
        return Expanded(
          child: Row(
            children: List.generate(9, (col) {
              return Expanded(
                child: _buildCell(row, col),
              );
            }),
          ),
        );
      }),
    );
  }

  /// 보드 3, 4에서 보드 2와 겹치는 영역인지 확인
  /// 이 영역은 투명하게 처리하여 보드 2의 값이 보이도록 함
  bool _shouldBeTransparent(int row, int col) {
    // 보드 3의 우상단 3x3 (보드 2의 좌하단과 겹침)
    if (boardIndex == 3 && row < 3 && col >= 6) return true;
    // 보드 4의 좌상단 3x3 (보드 2의 우하단과 겹침)
    if (boardIndex == 4 && row < 3 && col < 3) return true;
    return false;
  }

  Widget _buildCell(int row, int col) {
    // 보드 3, 4의 겹치는 영역은 투명하게 처리
    if (_shouldBeTransparent(row, col)) {
      return const SizedBox.expand();
    }

    int value = board[row][col];
    bool fixed = isFixed[row][col];
    bool isSelected = gameState.isSelectedCell(boardIndex, row, col);
    bool isHighlighted = isActiveBoard &&
        (gameState.isSameRowOrCol(boardIndex, row, col) ||
            gameState.isSameBox(boardIndex, row, col));
    bool isSameValue = gameState.isSameValue(boardIndex, row, col);
    bool hasError = gameState.hasError(boardIndex, row, col);
    bool isOverlap = gameState.isOverlapRegion(boardIndex, row, col);
    Set<int> notes = gameState.notes[boardIndex][row][col];
    bool isNoteHighlight = _shouldHighlightNote(row, col);

    Color backgroundColor;
    if (isSelected) {
      backgroundColor = Colors.blue.shade300;
    } else if (isNoteHighlight) {
      // 선택된 셀의 숫자가 메모에 포함된 경우
      backgroundColor = Colors.green.shade100;
    } else if (isSameValue && value != 0) {
      backgroundColor = Colors.blue.shade100;
    } else if (isHighlighted) {
      backgroundColor = Colors.blue.shade50;
    } else if (isOverlap) {
      backgroundColor = Colors.yellow.shade50;
    } else {
      backgroundColor = Colors.white;
    }

    Color textColor;
    if (hasError) {
      textColor = Colors.red;
    } else if (fixed) {
      textColor = Colors.black;
    } else {
      textColor = Colors.blue.shade700;
    }

    // 3x3 박스 테두리 계산
    bool rightBorder = (col + 1) % 3 == 0 && col != 8;
    bool bottomBorder = (row + 1) % 3 == 0 && row != 8;

    return GestureDetector(
      onTap: () => onCellTap(row, col),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            right: BorderSide(
              color: rightBorder ? Colors.black : Colors.grey.shade300,
              width: rightBorder ? 1.5 : 0.5,
            ),
            bottom: BorderSide(
              color: bottomBorder ? Colors.black : Colors.grey.shade300,
              width: bottomBorder ? 1.5 : 0.5,
            ),
            left: BorderSide(color: Colors.grey.shade300, width: 0.5),
            top: BorderSide(color: Colors.grey.shade300, width: 0.5),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = constraints.maxWidth < constraints.maxHeight
                ? constraints.maxWidth
                : constraints.maxHeight;

            if (value != 0) {
              final valueFontSize = (cellSize * 0.55).clamp(10.0, 32.0);
              return Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: Text(
                      value.toString(),
                      style: TextStyle(
                        fontSize: valueFontSize,
                        fontWeight: fixed ? FontWeight.bold : FontWeight.normal,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              );
            } else if (notes.isNotEmpty) {
              return _buildNotesGrid(notes, cellSize);
            } else {
              return const SizedBox.expand();
            }
          },
        ),
      ),
    );
  }

  Widget _buildNotesGrid(Set<int> notes, double cellSize) {
    // 미니 보드에서는 메모를 간단하게 표시
    final fontSize = (cellSize / 3 * 0.6).clamp(4.0, 14.0);

    return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (row) {
            return Expanded(
              child: Row(
                children: List.generate(3, (col) {
                  int num = row * 3 + col + 1;
                  bool hasNote = notes.contains(num);
                  return Expanded(
                    child: Center(
                      child: Text(
                        hasNote ? num.toString() : '',
                        style: TextStyle(
                          fontSize: fontSize,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        );
  }

  /// 메모 하이라이트 여부 판단 (선택된 셀의 숫자가 메모에 포함된 경우)
  bool _shouldHighlightNote(int row, int col) {
    // 현재 셀에 값이 있으면 하이라이트 안함
    if (board[row][col] != 0) return false;

    // 메모가 없으면 하이라이트 안함
    Set<int> notes = gameState.notes[boardIndex][row][col];
    if (notes.isEmpty) return false;

    // 선택된 셀이 없으면 하이라이트 안함
    if (gameState.selectedRow == null || gameState.selectedCol == null) {
      return false;
    }

    // 선택된 셀의 값 가져오기
    int selectedValue = gameState
        .currentBoards[gameState.selectedBoard][gameState.selectedRow!]
            [gameState.selectedCol!];
    if (selectedValue == 0) return false;

    return notes.contains(selectedValue);
  }
}
