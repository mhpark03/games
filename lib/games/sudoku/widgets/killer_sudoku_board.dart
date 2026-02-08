import 'package:flutter/material.dart';
import '../models/killer_game_state.dart';
import 'killer_sudoku_cell.dart';
import 'cage_border_painter.dart';

class KillerSudokuBoard extends StatelessWidget {
  final KillerGameState gameState;
  final Function(int row, int col) onCellTap;
  final bool isQuickInputMode;
  final int? quickInputNumber;

  const KillerSudokuBoard({
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = constraints.maxWidth / 9;
          final borderWidth = (cellSize * 0.04).clamp(2.0, 4.0);
          final boxGap = (cellSize * 0.03).clamp(1.5, 3.0);
          final cellGap = (cellSize * 0.015).clamp(0.5, 1.5);

          return Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: borderWidth),
            ),
            child: CustomPaint(
              foregroundPainter: CageBorderPainter(
                cages: gameState.cages,
                cellSize: cellSize,
              ),
              child: Container(
                color: Colors.grey.shade800,
                child: Column(
                  children: List.generate(9, (row) {
                    return Expanded(
                      child: Row(
                        children: List.generate(9, (col) {
                          double rightPadding = (col == 2 || col == 5) ? boxGap : cellGap;
                          double bottomPadding = (row == 2 || row == 5) ? boxGap : cellGap;
                          if (col == 8) rightPadding = 0;
                          if (row == 8) bottomPadding = 0;

                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                right: rightPadding,
                                bottom: bottomPadding,
                              ),
                              child: _buildCell(row, col),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    final cage = gameState.getCageForCell(row, col);
    final showSum = cage != null &&
        cage.sumDisplayCell[0] == row &&
        cage.sumDisplayCell[1] == col;

    return KillerSudokuCell(
        value: gameState.currentBoard[row][col],
        isFixed: gameState.isFixed[row][col],
        isSelected: gameState.isSelected(row, col),
        isHighlighted: !isQuickInputMode &&
            (gameState.isSameRowOrCol(row, col) ||
                gameState.isSameBox(row, col) ||
                gameState.isSameCage(row, col)),
        isSameValue: !isQuickInputMode && gameState.isSameValue(row, col),
        hasError: gameState.hasError(row, col),
        notes: gameState.notes[row][col],
        onTap: () => onCellTap(row, col),
        cageSum: showSum ? cage.targetSum : null,
        hasCageError: cage != null && gameState.hasCageError(cage),
        isQuickInputHighlight: isQuickInputMode &&
            quickInputNumber != null &&
            gameState.currentBoard[row][col] != 0 &&
            gameState.currentBoard[row][col] == quickInputNumber,
        isQuickInputNoteHighlight: _shouldHighlightNote(row, col),
    );
  }

  bool _shouldHighlightNote(int row, int col) {
    if (gameState.currentBoard[row][col] != 0) return false;
    if (gameState.notes[row][col].isEmpty) return false;

    if (isQuickInputMode) {
      if (quickInputNumber == null) return false;
      return gameState.notes[row][col].contains(quickInputNumber);
    } else {
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
