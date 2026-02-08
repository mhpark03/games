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

    // 3. Create puzzle by removing cells (with solvability check)
    List<List<int>> puzzle = _createPuzzle(solution, cages, difficulty);

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

  // ========== Logic Solver ==========

  /// Build cage lookup map: "row_col" -> cage
  Map<String, KillerCage> _buildCageLookup(List<KillerCage> cages) {
    Map<String, KillerCage> lookup = {};
    for (var cage in cages) {
      for (var cell in cage.cells) {
        lookup['${cell[0]}_${cell[1]}'] = cage;
      }
    }
    return lookup;
  }

  /// Initialize candidates for all empty cells
  List<List<Set<int>>> _initCandidates(
    List<List<int>> board,
    List<KillerCage> cages,
    Map<String, KillerCage> cageLookup,
  ) {
    List<List<Set<int>>> candidates = List.generate(
      9, (_) => List.generate(9, (_) => <int>{}),
    );

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] == 0) {
          for (int num = 1; num <= 9; num++) {
            if (_isValidForSolver(board, r, c, num, cageLookup)) {
              candidates[r][c].add(num);
            }
          }
        }
      }
    }
    return candidates;
  }

  /// Check if num is valid at (row, col) considering Sudoku + cage rules
  bool _isValidForSolver(
    List<List<int>> board,
    int row,
    int col,
    int num,
    Map<String, KillerCage> cageLookup,
  ) {
    // Standard Sudoku check
    for (int i = 0; i < 9; i++) {
      if (board[row][i] == num) return false;
    }
    for (int i = 0; i < 9; i++) {
      if (board[i][col] == num) return false;
    }
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (board[boxRow + i][boxCol + j] == num) return false;
      }
    }

    // Cage duplicate check
    var cage = cageLookup['${row}_$col'];
    if (cage != null) {
      for (var cell in cage.cells) {
        if (cell[0] != row || cell[1] != col) {
          if (board[cell[0]][cell[1]] == num) return false;
        }
      }
    }
    return true;
  }

  /// Remove num from candidates of all peers (row, col, box, cage)
  void _eliminateFromPeers(
    int row,
    int col,
    int num,
    List<List<Set<int>>> candidates,
    Map<String, KillerCage> cageLookup,
  ) {
    // Same row
    for (int c = 0; c < 9; c++) {
      candidates[row][c].remove(num);
    }
    // Same column
    for (int r = 0; r < 9; r++) {
      candidates[r][col].remove(num);
    }
    // Same box
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int r = boxRow; r < boxRow + 3; r++) {
      for (int c = boxCol; c < boxCol + 3; c++) {
        candidates[r][c].remove(num);
      }
    }
    // Same cage
    var cage = cageLookup['${row}_$col'];
    if (cage != null) {
      for (var cell in cage.cells) {
        candidates[cell[0]][cell[1]].remove(num);
      }
    }
  }

  /// Place a value on the board and update candidates
  void _placeValue(
    List<List<int>> board,
    int row,
    int col,
    int num,
    List<List<Set<int>>> candidates,
    Map<String, KillerCage> cageLookup,
  ) {
    board[row][col] = num;
    candidates[row][col].clear();
    _eliminateFromPeers(row, col, num, candidates, cageLookup);
  }

  /// Try to solve the puzzle using logic only
  /// Returns true if solved completely
  bool _solveWithLogic(
    List<List<int>> board,
    List<KillerCage> cages,
    Map<String, KillerCage> cageLookup,
    List<List<Set<int>>> candidates,
  ) {
    bool progress = true;
    while (progress) {
      progress = false;

      // 1. Naked singles: cell with exactly one candidate
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (board[r][c] == 0 && candidates[r][c].length == 1) {
            _placeValue(
                board, r, c, candidates[r][c].first, candidates, cageLookup);
            progress = true;
          } else if (board[r][c] == 0 && candidates[r][c].isEmpty) {
            return false; // Invalid state
          }
        }
      }

      // 2. Hidden singles in rows
      for (int r = 0; r < 9; r++) {
        for (int num = 1; num <= 9; num++) {
          List<int> cols = [];
          for (int c = 0; c < 9; c++) {
            if (board[r][c] == 0 && candidates[r][c].contains(num)) {
              cols.add(c);
            }
          }
          if (cols.length == 1) {
            _placeValue(board, r, cols[0], num, candidates, cageLookup);
            progress = true;
          }
        }
      }

      // 3. Hidden singles in columns
      for (int c = 0; c < 9; c++) {
        for (int num = 1; num <= 9; num++) {
          List<int> rows = [];
          for (int r = 0; r < 9; r++) {
            if (board[r][c] == 0 && candidates[r][c].contains(num)) {
              rows.add(r);
            }
          }
          if (rows.length == 1) {
            _placeValue(board, rows[0], c, num, candidates, cageLookup);
            progress = true;
          }
        }
      }

      // 4. Hidden singles in 3x3 boxes
      for (int boxR = 0; boxR < 3; boxR++) {
        for (int boxC = 0; boxC < 3; boxC++) {
          for (int num = 1; num <= 9; num++) {
            List<List<int>> positions = [];
            for (int r = boxR * 3; r < boxR * 3 + 3; r++) {
              for (int c = boxC * 3; c < boxC * 3 + 3; c++) {
                if (board[r][c] == 0 && candidates[r][c].contains(num)) {
                  positions.add([r, c]);
                }
              }
            }
            if (positions.length == 1) {
              _placeValue(board, positions[0][0], positions[0][1], num,
                  candidates, cageLookup);
              progress = true;
            }
          }
        }
      }

      // 5. Hidden singles in cages
      for (var cage in cages) {
        for (int num = 1; num <= 9; num++) {
          List<List<int>> positions = [];
          for (var cell in cage.cells) {
            if (board[cell[0]][cell[1]] == 0 &&
                candidates[cell[0]][cell[1]].contains(num)) {
              positions.add(cell);
            }
          }
          if (positions.length == 1) {
            _placeValue(board, positions[0][0], positions[0][1], num,
                candidates, cageLookup);
            progress = true;
          }
        }
      }

      // 6. Cage: last empty cell → value is determined
      for (var cage in cages) {
        List<List<int>> emptyCells = [];
        int filledSum = 0;
        for (var cell in cage.cells) {
          if (board[cell[0]][cell[1]] == 0) {
            emptyCells.add(cell);
          } else {
            filledSum += board[cell[0]][cell[1]];
          }
        }
        if (emptyCells.length == 1) {
          int remaining = cage.targetSum - filledSum;
          if (remaining >= 1 &&
              remaining <= 9 &&
              candidates[emptyCells[0][0]][emptyCells[0][1]]
                  .contains(remaining)) {
            _placeValue(board, emptyCells[0][0], emptyCells[0][1], remaining,
                candidates, cageLookup);
            progress = true;
          }
        }
      }

      // 7. Cage sum combination constraint
      for (var cage in cages) {
        List<List<int>> emptyCells = [];
        int filledSum = 0;
        Set<int> filledValues = {};
        for (var cell in cage.cells) {
          if (board[cell[0]][cell[1]] == 0) {
            emptyCells.add(cell);
          } else {
            filledSum += board[cell[0]][cell[1]];
            filledValues.add(board[cell[0]][cell[1]]);
          }
        }
        if (emptyCells.isEmpty || emptyCells.length > 5) continue;

        int remainingSum = cage.targetSum - filledSum;

        // Collect each cell's current candidates
        List<Set<int>> cellCandidates = emptyCells
            .map((cell) => Set<int>.from(candidates[cell[0]][cell[1]]))
            .toList();

        // Find all valid value sets for empty cells
        List<Set<int>> validPerCell =
            List.generate(emptyCells.length, (_) => <int>{});
        _findValidCombos(cellCandidates, filledValues, remainingSum, 0, [],
            validPerCell);

        // Eliminate candidates not in any valid combination
        for (int i = 0; i < emptyCells.length; i++) {
          Set<int> toRemove = {};
          for (int val in candidates[emptyCells[i][0]][emptyCells[i][1]]) {
            if (!validPerCell[i].contains(val)) {
              toRemove.add(val);
            }
          }
          if (toRemove.isNotEmpty) {
            candidates[emptyCells[i][0]][emptyCells[i][1]].removeAll(toRemove);
            progress = true;
          }
        }
      }
    }

    // Check if solved
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] == 0) return false;
      }
    }
    return true;
  }

  /// Recursively find valid combinations for cage empty cells
  void _findValidCombos(
    List<Set<int>> cellCandidates,
    Set<int> usedValues,
    int remainingSum,
    int index,
    List<int> current,
    List<Set<int>> validPerCell,
  ) {
    if (index == cellCandidates.length) {
      if (remainingSum == 0) {
        // Valid combination found
        for (int i = 0; i < current.length; i++) {
          validPerCell[i].add(current[i]);
        }
      }
      return;
    }

    for (int val in cellCandidates[index]) {
      if (usedValues.contains(val)) continue;
      if (val > remainingSum) continue;

      usedValues.add(val);
      current.add(val);
      _findValidCombos(cellCandidates, usedValues, remainingSum - val,
          index + 1, current, validPerCell);
      current.removeLast();
      usedValues.remove(val);
    }
  }

  /// Check if puzzle can be solved with logic alone
  bool _canSolveLogically(List<List<int>> puzzle, List<KillerCage> cages) {
    List<List<int>> board = puzzle.map((r) => List<int>.from(r)).toList();
    Map<String, KillerCage> cageLookup = _buildCageLookup(cages);
    List<List<Set<int>>> candidates =
        _initCandidates(board, cages, cageLookup);
    return _solveWithLogic(board, cages, cageLookup, candidates);
  }

  /// Count solutions using backtracking (stops at 2)
  int _countSolutions(
    List<List<int>> board,
    List<KillerCage> cages,
    Map<String, KillerCage> cageLookup,
    int limit,
  ) {
    // Find first empty cell
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] == 0) {
          int count = 0;
          for (int num = 1; num <= 9; num++) {
            if (!_isValidForSolver(board, r, c, num, cageLookup)) continue;

            // Check cage sum constraint
            var cage = cageLookup['${r}_$c'];
            if (cage != null) {
              int currentSum = num;
              int emptyCells = 0;
              for (var cell in cage.cells) {
                if (cell[0] == r && cell[1] == c) continue;
                if (board[cell[0]][cell[1]] == 0) {
                  emptyCells++;
                } else {
                  currentSum += board[cell[0]][cell[1]];
                }
              }
              // If sum already exceeded, skip
              if (currentSum > cage.targetSum) continue;
              // If no empty cells left, sum must match
              if (emptyCells == 0 && currentSum != cage.targetSum) continue;
            }

            board[r][c] = num;
            count += _countSolutions(board, cages, cageLookup, limit - count);
            board[r][c] = 0;

            if (count >= limit) return count;
          }
          return count;
        }
      }
    }
    return 1; // All cells filled = one solution
  }

  /// Check if puzzle has a unique solution
  bool _hasUniqueSolution(List<List<int>> puzzle, List<KillerCage> cages) {
    List<List<int>> board = puzzle.map((r) => List<int>.from(r)).toList();
    Map<String, KillerCage> cageLookup = _buildCageLookup(cages);
    return _countSolutions(board, cages, cageLookup, 2) == 1;
  }

  /// Create puzzle by removing cells with solvability verification
  List<List<int>> _createPuzzle(
      List<List<int>> solution, List<KillerCage> cages,
      KillerDifficulty difficulty) {
    List<List<int>> puzzle = solution.map((r) => List<int>.from(r)).toList();

    int targetRemove;
    switch (difficulty) {
      case KillerDifficulty.easy:
        targetRemove = 40;
        break;
      case KillerDifficulty.medium:
        targetRemove = 50;
        break;
      case KillerDifficulty.hard:
        targetRemove = 55;
        break;
    }

    // Shuffle positions
    List<int> positions = List.generate(81, (i) => i)..shuffle(_random);
    int removed = 0;

    for (int pos in positions) {
      if (removed >= targetRemove) break;

      int row = pos ~/ 9;
      int col = pos % 9;
      if (puzzle[row][col] == 0) continue;

      int backup = puzzle[row][col];
      puzzle[row][col] = 0;

      // Check: unique solution + logically solvable
      if (_hasUniqueSolution(puzzle, cages) &&
          _canSolveLogically(puzzle, cages)) {
        removed++;
      } else {
        puzzle[row][col] = backup; // Restore
      }
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
