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
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 3),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = constraints.maxWidth / 9;
            return CustomPaint(
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
                          double rightPadding = (col == 2 || col == 5) ? 2 : 1;
                          double bottomPadding = (row == 2 || row == 5) ? 2 : 1;
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
            );
          },
        ),
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
