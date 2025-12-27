import 'dart:math';
import 'killer_cage.dart';

enum KillerDifficulty { easy, medium, hard }

class KillerSudokuGenerator {
  final Random _random = Random();

  /// Generate a complete Killer Sudoku puzzle
  Map<String, dynamic> generatePuzzle(KillerDifficulty difficulty) {
    // 1. Generate a valid solved board
    List<List<int>> solution = _generateSolvedBoard();

    // 2. Generate cages based on difficulty
    List<KillerCage> cages = _generateCages(solution, difficulty);

    // 3. Create puzzle by removing cells
    List<List<int>> puzzle = _createPuzzle(solution, difficulty);

    return {
      'solution': solution,
      'puzzle': puzzle,
      'cages': cages,
    };
  }

  /// Generate a solved Sudoku board
  List<List<int>> _generateSolvedBoard() {
    List<List<int>> board = List.generate(9, (_) => List.filled(9, 0));
    _fillBoard(board);
    return board;
  }

  bool _fillBoard(List<List<int>> board) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0) {
          List<int> numbers = List.generate(9, (i) => i + 1)..shuffle(_random);
          for (int num in numbers) {
            if (_isValid(board, row, col, num)) {
              board[row][col] = num;
              if (_fillBoard(board)) {
                return true;
              }
              board[row][col] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  bool _isValid(List<List<int>> board, int row, int col, int num) {
    // Row check
    for (int i = 0; i < 9; i++) {
      if (board[row][i] == num) return false;
    }
    // Column check
    for (int i = 0; i < 9; i++) {
      if (board[i][col] == num) return false;
    }
    // 3x3 box check
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (board[boxRow + i][boxCol + j] == num) return false;
      }
    }
    return true;
  }

  /// Generate cages covering all 81 cells
  List<KillerCage> _generateCages(
      List<List<int>> solution, KillerDifficulty difficulty) {
    List<KillerCage> cages = [];
    Set<String> usedCells = {};
    int cageId = 0;

    // Cage size ranges by difficulty
    int minSize, maxSize;
    switch (difficulty) {
      case KillerDifficulty.easy:
        minSize = 2;
        maxSize = 3;
        break;
      case KillerDifficulty.medium:
        minSize = 2;
        maxSize = 4;
        break;
      case KillerDifficulty.hard:
        minSize = 2;
        maxSize = 5;
        break;
    }

    // Iterate through all cells
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        String cellKey = '${row}_$col';
        if (usedCells.contains(cellKey)) continue;

        // Start a new cage
        List<List<int>> cageCells = [
          [row, col]
        ];
        usedCells.add(cellKey);

        // Determine target cage size
        int targetSize = minSize + _random.nextInt(maxSize - minSize + 1);

        // Grow cage by adding adjacent cells
        while (cageCells.length < targetSize) {
          List<List<int>> candidates =
              _getAdjacentUnusedCells(cageCells, usedCells, solution);

          if (candidates.isEmpty) break;

          // Pick random adjacent cell
          var newCell = candidates[_random.nextInt(candidates.length)];
          cageCells.add(newCell);
          usedCells.add('${newCell[0]}_${newCell[1]}');
        }

        // Calculate target sum
        int targetSum = 0;
        for (var cell in cageCells) {
          targetSum += solution[cell[0]][cell[1]];
        }

        cages.add(KillerCage(
          cells: cageCells,
          targetSum: targetSum,
          cageId: cageId++,
        ));
      }
    }

    return cages;
  }

  /// Get adjacent cells that are not yet used
  List<List<int>> _getAdjacentUnusedCells(
    List<List<int>> currentCells,
    Set<String> usedCells,
    List<List<int>> solution,
  ) {
    List<List<int>> candidates = [];
    Set<String> checked = {};

    // Collect values already in the cage
    Set<int> cageValues = {};
    for (var cell in currentCells) {
      cageValues.add(solution[cell[0]][cell[1]]);
    }

    for (var cell in currentCells) {
      int r = cell[0], c = cell[1];

      // Check 4-directional neighbors
      List<List<int>> neighbors = [
        [r - 1, c],
        [r + 1, c],
        [r, c - 1],
        [r, c + 1]
      ];

      for (var n in neighbors) {
        if (n[0] < 0 || n[0] >= 9 || n[1] < 0 || n[1] >= 9) continue;
        String key = '${n[0]}_${n[1]}';
        if (usedCells.contains(key) || checked.contains(key)) continue;

        checked.add(key);

        // Verify no duplicate value would be in cage
        int newValue = solution[n[0]][n[1]];
        if (!cageValues.contains(newValue)) {
          candidates.add(n);
        }
      }
    }

    return candidates;
  }

  /// Create puzzle by removing cells based on difficulty
  List<List<int>> _createPuzzle(
      List<List<int>> solution, KillerDifficulty difficulty) {
    List<List<int>> puzzle = solution.map((r) => List<int>.from(r)).toList();

    int cellsToRemove;
    switch (difficulty) {
      case KillerDifficulty.easy:
        cellsToRemove = 40;
        break;
      case KillerDifficulty.medium:
        cellsToRemove = 50;
        break;
      case KillerDifficulty.hard:
        cellsToRemove = 58;
        break;
    }

    // Shuffle positions and remove cells
    List<int> positions = List.generate(81, (i) => i)..shuffle(_random);
    int removed = 0;

    for (int pos in positions) {
      if (removed >= cellsToRemove) break;

      int row = pos ~/ 9;
      int col = pos % 9;

      if (puzzle[row][col] == 0) continue;

      puzzle[row][col] = 0;
      removed++;
    }

    return puzzle;
  }

  /// Check if a move is valid (standard Sudoku rules)
  static bool isValidMove(List<List<int>> board, int row, int col, int num) {
    if (num == 0) return true;

    // Row check
    for (int i = 0; i < 9; i++) {
      if (i != col && board[row][i] == num) return false;
    }

    // Column check
    for (int i = 0; i < 9; i++) {
      if (i != row && board[i][col] == num) return false;
    }

    // 3x3 box check
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if ((boxRow + i != row || boxCol + j != col) &&
            board[boxRow + i][boxCol + j] == num) {
          return false;
        }
      }
    }

    return true;
  }

  /// Check if the board is complete
  static bool isBoardComplete(List<List<int>> board) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0) return false;
        if (!isValidMove(board, row, col, board[row][col])) return false;
      }
    }
    return true;
  }
}
