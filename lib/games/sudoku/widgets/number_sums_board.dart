import 'package:flutter/material.dart';
import '../models/number_sums_game_state.dart';
import 'number_sums_cell.dart';

class NumberSumsBoard extends StatelessWidget {
  final NumberSumsGameState gameState;
  final Function(int row, int col) onCellTap;
  final int? errorRow;
  final int? errorCol;

  const NumberSumsBoard({
    super.key,
    required this.gameState,
    required this.onCellTap,
    this.errorRow,
    this.errorCol,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          border: Border.all(color: const Color(0xFF4A4A4A), width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Column(
            children: List.generate(gameState.gridSize, (row) {
              return Expanded(
                child: Row(
                  children: List.generate(gameState.gridSize, (col) {
                    return Expanded(
                      child: _buildCell(row, col),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    // (0, 0) = 코너 셀 (투명하게)
    if (row == 0 && col == 0) {
      return const NumberSumsCornerCell();
    }

    // 첫 번째 행 (열 합계 표시) - 전체 합 + 선택한 합
    if (row == 0 && col > 0) {
      final isComplete = gameState.isColComplete(col);
      return NumberSumsSumCell(
        totalSum: isComplete ? 0 : gameState.colSums[col],
        selectedSum: gameState.getCurrentColSum(col),
        isComplete: isComplete,
      );
    }

    // 첫 번째 열 (행 합계 표시) - 전체 합 + 선택한 합
    if (col == 0 && row > 0) {
      final isComplete = gameState.isRowComplete(row);
      return NumberSumsSumCell(
        totalSum: isComplete ? 0 : gameState.rowSums[row],
        selectedSum: gameState.getCurrentRowSum(row),
        isComplete: isComplete,
      );
    }

    // 입력 셀
    final value = gameState.currentBoard[row][col];
    final isError = errorRow == row && errorCol == col;
    final blockColor = gameState.getBlockColor(row, col);
    final blockId = gameState.getBlockId(row, col);
    final isFirstCell = gameState.isBlockFirstCell(row, col);
    // 블록 합은 전체 합 표시 (블록 완료시 숨김)
    int? blockSum;
    if (isFirstCell && blockId >= 0) {
      final isBlockDone = gameState.isBlockComplete(blockId);
      blockSum = isBlockDone ? null : gameState.blockSums[blockId];
    }

    return NumberSumsInputCell(
      value: value,
      isSelected: gameState.isSelected(row, col),
      isEmpty: value == 0,
      isMarkedCorrect: gameState.isMarkedCorrect(row, col),
      isError: isError,
      blockColor: blockColor,
      blockSum: blockSum,
      onTap: () => onCellTap(row, col),
    );
  }
}
