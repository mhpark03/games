import 'dart:math';
import 'logical_solver.dart';

class SudokuGenerator {
  final Random _random = Random();

  /// 완성된 스도쿠 보드 생성
  List<List<int>> generateSolvedBoard() {
    List<List<int>> board = List.generate(9, (_) => List.filled(9, 0));
    _fillBoard(board);
    return board;
  }

  /// 퍼즐 생성 (difficulty: 빈 칸 개수) - 논리적으로 풀 수 있는 퍼즐 보장
  List<List<int>> generatePuzzle(List<List<int>> solvedBoard, int difficulty) {
    int cellsToRemove = difficulty.clamp(20, 70);

    // 최대 재시도 횟수
    for (int attempt = 0; attempt < 10; attempt++) {
      List<List<int>>? puzzle =
          _tryGenerateLogicalPuzzle(solvedBoard, cellsToRemove);
      if (puzzle != null) {
        return puzzle;
      }
    }

    // 논리 풀이 가능한 퍼즐 생성 실패 시 폴백
    // 더 적은 셀을 제거하여 쉬운 퍼즐 생성
    return _generateSimplePuzzle(solvedBoard, (cellsToRemove * 0.7).round());
  }

  /// 논리적으로 풀 수 있는 퍼즐 생성 시도
  List<List<int>>? _tryGenerateLogicalPuzzle(
      List<List<int>> solvedBoard, int targetEmpty) {
    List<List<int>> puzzle =
        solvedBoard.map((row) => List<int>.from(row)).toList();

    // 모든 셀 위치 수집 및 섞기
    List<int> allPositions = [];
    for (int i = 0; i < 81; i++) {
      allPositions.add(i);
    }
    allPositions.shuffle(_random);

    int removed = 0;
    int skipped = 0;

    for (int pos in allPositions) {
      if (removed >= targetEmpty) break;

      // 너무 많이 스킵하면 이 시도 포기
      if (skipped > 40) return null;

      int row = pos ~/ 9;
      int col = pos % 9;

      if (puzzle[row][col] == 0) continue;

      // 셀 값을 임시로 제거
      int backup = puzzle[row][col];
      puzzle[row][col] = 0;

      // 유일해 + 논리적으로 풀 수 있는지 확인
      if (_hasUniqueSolution(puzzle) &&
          LogicalSolver.canSolveLogically(puzzle)) {
        removed++;
      } else {
        // 풀 수 없으면 복원
        puzzle[row][col] = backup;
        skipped++;
      }
    }

    // 목표의 80% 이상 제거했으면 성공
    if (removed >= targetEmpty * 0.8) {
      return puzzle;
    }

    return null;
  }

  /// 유일해 검증: 백트래킹으로 해가 2개 이상인지 확인
  bool _hasUniqueSolution(List<List<int>> puzzle) {
    List<List<int>> board = puzzle.map((r) => List<int>.from(r)).toList();
    return _countSolutions(board, 2) == 1;
  }

  int _countSolutions(List<List<int>> board, int limit) {
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (board[r][c] == 0) {
          int count = 0;
          for (int num = 1; num <= 9; num++) {
            if (_isValidForSolver(board, r, c, num)) {
              board[r][c] = num;
              count += _countSolutions(board, limit - count);
              board[r][c] = 0;
              if (count >= limit) return count;
            }
          }
          return count;
        }
      }
    }
    return 1;
  }

  bool _isValidForSolver(List<List<int>> board, int row, int col, int num) {
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
    return true;
  }

  /// 간단한 퍼즐 생성 (폴백용) - 박스별 균등 분포
  List<List<int>> _generateSimplePuzzle(
      List<List<int>> solvedBoard, int cellsToRemove) {
    List<List<int>> puzzle =
        solvedBoard.map((row) => List<int>.from(row)).toList();

    // 각 3x3 박스당 제거할 셀 수 계산
    int cellsPerBox = cellsToRemove ~/ 9;
    int extraCells = cellsToRemove % 9;

    // 난이도에 따른 최소 유지 셀 수
    int minCellsToKeep;
    if (cellsToRemove >= 70) {
      minCellsToKeep = 1;
    } else if (cellsToRemove >= 60) {
      minCellsToKeep = 2;
    } else if (cellsToRemove >= 45) {
      minCellsToKeep = 4;
    } else {
      minCellsToKeep = 5;
    }
    int maxRemovePerBox = 9 - minCellsToKeep;

    List<int> boxOrder = List.generate(9, (i) => i)..shuffle(_random);

    for (int boxIdx = 0; boxIdx < 9; boxIdx++) {
      int boxNum = boxOrder[boxIdx];
      int boxStartRow = (boxNum ~/ 3) * 3;
      int boxStartCol = (boxNum % 3) * 3;

      List<int> boxPositions = [];
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          boxPositions.add((boxStartRow + r) * 9 + (boxStartCol + c));
        }
      }
      boxPositions.shuffle(_random);

      int toRemoveInBox = cellsPerBox + (boxIdx < extraCells ? 1 : 0);
      toRemoveInBox = toRemoveInBox.clamp(0, maxRemovePerBox);

      for (int i = 0; i < toRemoveInBox && i < boxPositions.length; i++) {
        int pos = boxPositions[i];
        int row = pos ~/ 9;
        int col = pos % 9;
        puzzle[row][col] = 0;
      }
    }

    return puzzle;
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
    // 행 검사
    for (int i = 0; i < 9; i++) {
      if (board[row][i] == num) return false;
    }

    // 열 검사
    for (int i = 0; i < 9; i++) {
      if (board[i][col] == num) return false;
    }

    // 3x3 박스 검사
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (board[boxRow + i][boxCol + j] == num) return false;
      }
    }

    return true;
  }

  /// 현재 입력이 유효한지 검사
  static bool isValidMove(List<List<int>> board, int row, int col, int num) {
    if (num == 0) return true;

    // 행 검사
    for (int i = 0; i < 9; i++) {
      if (i != col && board[row][i] == num) return false;
    }

    // 열 검사
    for (int i = 0; i < 9; i++) {
      if (i != row && board[i][col] == num) return false;
    }

    // 3x3 박스 검사
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

  /// 보드가 완성되었는지 검사 (solution과 비교)
  static bool isBoardComplete(List<List<int>> board, List<List<int>> solution) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] != solution[row][col]) {
          return false;
        }
      }
    }
    return true;
  }
}
