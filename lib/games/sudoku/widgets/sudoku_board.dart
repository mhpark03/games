import 'package:flutter/material.dart';
import '../models/game_state.dart';
import 'sudoku_cell.dart';

class SudokuBoard extends StatelessWidget {
  final GameState gameState;
  final Function(int row, int col) onCellTap;
  final bool isQuickInputMode;
  final int? quickInputNumber;

  const SudokuBoard({
    super.key,
    required this.gameState,
    required this.onCellTap,
    this.isQuickInputMode = false,
    this.quickInputNumber,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Column(
          children: List.generate(9, (row) {
            return Expanded(
              child: Row(
                children: List.generate(9, (col) {
                  return Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: (col + 1) % 3 == 0 && col != 8
                                ? Colors.black
                                : Colors.transparent,
                            width: 2,
                          ),
                          bottom: BorderSide(
                            color: (row + 1) % 3 == 0 && row != 8
                                ? Colors.black
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: SudokuCell(
                        value: gameState.currentBoard[row][col],
                        isFixed: gameState.isFixed[row][col],
                        isSelected: gameState.isSelected(row, col),
                        isHighlighted: !isQuickInputMode &&
                            (gameState.isSameRowOrCol(row, col) ||
                                gameState.isSameBox(row, col)),
                        isSameValue: !isQuickInputMode &&
                            gameState.isSameValue(row, col),
                        hasError: gameState.hasError(row, col),
                        notes: gameState.notes[row][col],
                        onTap: () => onCellTap(row, col),
                        isQuickInputHighlight: isQuickInputMode &&
                            quickInputNumber != null &&
                            gameState.currentBoard[row][col] != 0 &&
                            gameState.currentBoard[row][col] ==
                                quickInputNumber,
                        isQuickInputNoteHighlight: _shouldHighlightNote(row, col),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// 메모 하이라이트 여부 판단
  /// 빠른 입력 모드: quickInputNumber가 메모에 포함된 경우
  /// 일반 모드: 선택된 셀의 숫자가 메모에 포함된 경우
  bool _shouldHighlightNote(int row, int col) {
    // 현재 셀에 값이 있으면 하이라이트 안함
    if (gameState.currentBoard[row][col] != 0) return false;

    // 메모가 없으면 하이라이트 안함
    if (gameState.notes[row][col].isEmpty) return false;

    if (isQuickInputMode) {
      // 빠른 입력 모드
      if (quickInputNumber == null) return false;
      return gameState.notes[row][col].contains(quickInputNumber);
    } else {
      // 일반 모드: 선택된 셀의 숫자가 메모에 포함된 경우
      if (gameState.selectedRow == null || gameState.selectedCol == null) {
        return false;
      }
      int selectedValue = gameState
          .currentBoard[gameState.selectedRow!][gameState.selectedCol!];
      if (selectedValue == 0) return false;
      return gameState.notes[row][col].contains(selectedValue);
    }
  }
}
