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

  Widget _buildCell(int row, int col) {
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
        child: value != 0
            ? Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(1),
                    child: Text(
                      value.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: fixed ? FontWeight.bold : FontWeight.normal,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              )
            : notes.isNotEmpty
                ? _buildNotesGrid(notes)
                : const SizedBox.expand(),
      ),
    );
  }

  Widget _buildNotesGrid(Set<int> notes) {
    // 미니 보드에서는 메모를 간단하게 표시
    return LayoutBuilder(
      builder: (context, constraints) {
        double cellSize = constraints.maxWidth / 3;
        double fontSize = (cellSize * 0.6).clamp(4.0, 8.0);

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
      },
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
