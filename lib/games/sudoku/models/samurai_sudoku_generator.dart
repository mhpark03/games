import 'dart:math';
import 'logical_solver.dart';

/// 사무라이 스도쿠: 5개의 9x9 보드가 겹쳐진 형태
/// 배치:
///   [0]   [1]      (상단 좌/우)
///     [2]          (중앙)
///   [3]   [4]      (하단 좌/우)
///
/// 겹치는 영역:
/// - 보드 0의 우하단 3x3 = 보드 2의 좌상단 3x3
/// - 보드 1의 좌하단 3x3 = 보드 2의 우상단 3x3
/// - 보드 2의 좌하단 3x3 = 보드 3의 우상단 3x3
/// - 보드 2의 우하단 3x3 = 보드 4의 좌상단 3x3

class SamuraiSudokuGenerator {
  final Random _random = Random();

  /// 5개의 연결된 스도쿠 보드 생성
  /// 생성 순서: B2(중앙) → B0, B1, B3, B4
  List<List<List<int>>> generateSolvedBoards() {
    // 생성 실패 시 재시도 (최대 100회)
    for (int attempt = 0; attempt < 100; attempt++) {
      List<List<List<int>>> boards = List.generate(
        5,
        (_) => List.generate(9, (_) => List.filled(9, 0)),
      );

      // 1. 중앙 보드(B2)를 먼저 생성 - 제약 없이 완전한 보드 생성
      if (!_fillBoard(boards[2])) continue;

      // 2. B0: 우하단을 B2의 좌상단에서 복사 후 나머지 채우기
      if (!_fillBoardFromCenter(boards[0], boards[2], 0)) continue;

      // 3. B1: 좌하단을 B2의 우상단에서 복사 후 나머지 채우기
      if (!_fillBoardFromCenter(boards[1], boards[2], 1)) continue;

      // 4. B3: 우상단을 B2의 좌하단에서 복사 후 나머지 채우기
      if (!_fillBoardFromCenter(boards[3], boards[2], 3)) continue;

      // 5. B4: 좌상단을 B2의 우하단에서 복사 후 나머지 채우기
      if (!_fillBoardFromCenter(boards[4], boards[2], 4)) continue;

      // 모든 보드가 유효한지 검증
      if (_verifyAllBoards(boards)) {
        return boards;
      }
    }

    // 실패 시 빈 보드 반환 (거의 발생하지 않음)
    return List.generate(
      5,
      (_) => List.generate(9, (_) => List.filled(9, 0)),
    );
  }

  /// 중앙 보드(B2)를 기준으로 코너 보드 생성
  bool _fillBoardFromCenter(
      List<List<int>> board, List<List<int>> centerBoard, int boardIndex) {
    if (boardIndex == 0) {
      // B0: 우하단 3x3을 B2의 좌상단 3x3에서 복사
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          board[6 + i][6 + j] = centerBoard[i][j];
        }
      }
    } else if (boardIndex == 1) {
      // B1: 좌하단 3x3을 B2의 우상단 3x3에서 복사
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          board[6 + i][j] = centerBoard[i][6 + j];
        }
      }
    } else if (boardIndex == 3) {
      // B3: 우상단 3x3을 B2의 좌하단 3x3에서 복사
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          board[i][6 + j] = centerBoard[6 + i][j];
        }
      }
    } else if (boardIndex == 4) {
      // B4: 좌상단 3x3을 B2의 우하단 3x3에서 복사
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          board[i][j] = centerBoard[6 + i][6 + j];
        }
      }
    }

    return _fillBoardPartial(board);
  }

  /// 모든 보드가 완전하고 유효한지 검증
  bool _verifyAllBoards(List<List<List<int>>> boards) {
    for (int b = 0; b < 5; b++) {
      for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
          int value = boards[b][row][col];
          if (value == 0) return false; // 빈 셀이 있으면 실패
          if (value < 1 || value > 9) return false; // 유효하지 않은 값
        }
      }

      // 각 행에 1-9가 모두 있는지 확인
      for (int row = 0; row < 9; row++) {
        Set<int> rowNums = {};
        for (int col = 0; col < 9; col++) {
          rowNums.add(boards[b][row][col]);
        }
        if (rowNums.length != 9) return false; // 행에 중복이 있거나 누락
      }

      // 각 열에 1-9가 모두 있는지 확인
      for (int col = 0; col < 9; col++) {
        Set<int> colNums = {};
        for (int row = 0; row < 9; row++) {
          colNums.add(boards[b][row][col]);
        }
        if (colNums.length != 9) return false; // 열에 중복이 있거나 누락
      }

      // 각 3x3 박스에 1-9가 모두 있는지 확인
      for (int boxRow = 0; boxRow < 3; boxRow++) {
        for (int boxCol = 0; boxCol < 3; boxCol++) {
          Set<int> boxNums = {};
          for (int r = 0; r < 3; r++) {
            for (int c = 0; c < 3; c++) {
              boxNums.add(boards[b][boxRow * 3 + r][boxCol * 3 + c]);
            }
          }
          if (boxNums.length != 9) return false; // 박스에 중복이 있거나 누락
        }
      }
    }

    // 겹치는 영역 일관성 검증
    // 보드 0 우하단 == 보드 2 좌상단
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (boards[0][6 + i][6 + j] != boards[2][i][j]) return false;
      }
    }
    // 보드 1 좌하단 == 보드 2 우상단
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (boards[1][6 + i][j] != boards[2][i][6 + j]) return false;
      }
    }
    // 보드 2 좌하단 == 보드 3 우상단
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (boards[2][6 + i][j] != boards[3][i][6 + j]) return false;
      }
    }
    // 보드 2 우하단 == 보드 4 좌상단
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        if (boards[2][6 + i][6 + j] != boards[4][i][j]) return false;
      }
    }

    return true;
  }

  /// 퍼즐 생성 - 논리적으로 풀 수 있는 퍼즐 보장
  List<List<List<int>>> generatePuzzles(
      List<List<List<int>>> solvedBoards, int difficulty) {
    // 최대 재시도 횟수 증가
    for (int attempt = 0; attempt < 10; attempt++) {
      List<List<List<int>>>? puzzle =
          _tryGenerateLogicalPuzzle(solvedBoards, difficulty);
      if (puzzle != null) {
        return puzzle;
      }
    }

    // 논리 풀이 가능한 퍼즐 생성 실패 시 폴백 (더 쉬운 난이도로 변경: 0.7 -> 0.5)
    return _generateSimplePuzzle(solvedBoards, (difficulty * 0.5).round());
  }

  /// 논리적으로 풀 수 있는 퍼즐 생성 시도
  List<List<List<int>>>? _tryGenerateLogicalPuzzle(
      List<List<List<int>>> solvedBoards, int difficulty) {
    // 솔루션 복사 - 시작은 모든 셀이 노출된 상태
    List<List<List<int>>> puzzles = solvedBoards
        .map((board) => board.map((row) => List<int>.from(row)).toList())
        .toList();

    // 난이도를 비율로 변환
    double hidePercentage = difficulty.clamp(0, 81) / 81.0;
    int totalGridCells = 21 * 21;
    int cellsToHide = (totalGridCells * hidePercentage).round();

    // 21x21 그리드의 유효한 위치들 (빈 영역 제외)
    List<int> validPositions = [];
    for (int gridRow = 0; gridRow < 21; gridRow++) {
      for (int gridCol = 0; gridCol < 21; gridCol++) {
        List<List<int>> mappings = _mapGridToBoards(gridRow, gridCol);
        if (mappings.isNotEmpty) {
          validPositions.add(gridRow * 21 + gridCol);
        }
      }
    }
    validPositions.shuffle(_random);

    int hidden = 0;
    int skipped = 0;

    for (int pos in validPositions) {
      if (hidden >= cellsToHide) break;

      // 너무 많이 스킵하면 이 시도 포기 (60 -> 100으로 증가)
      if (skipped > 100) return null;

      int gridRow = pos ~/ 21;
      int gridCol = pos % 21;

      List<List<int>> mappings = _mapGridToBoards(gridRow, gridCol);
      if (mappings.isEmpty) continue;

      // 이미 숨겨진 셀인지 확인
      bool alreadyHidden = false;
      for (var mapping in mappings) {
        if (puzzles[mapping[0]][mapping[1]][mapping[2]] == 0) {
          alreadyHidden = true;
          break;
        }
      }
      if (alreadyHidden) continue;

      // 임시로 셀 숨기기
      List<int> backups = [];
      for (var mapping in mappings) {
        backups.add(puzzles[mapping[0]][mapping[1]][mapping[2]]);
        puzzles[mapping[0]][mapping[1]][mapping[2]] = 0;
      }

      // 논리적으로 풀 수 있는지 확인
      if (LogicalSolver.canSolveSamuraiLogically(puzzles)) {
        hidden++;
      } else {
        // 풀 수 없으면 복원
        for (int i = 0; i < mappings.length; i++) {
          puzzles[mappings[i][0]][mappings[i][1]][mappings[i][2]] = backups[i];
        }
        skipped++;
      }
    }

    // 목표의 70% 이상 숨겼으면 성공
    if (hidden >= cellsToHide * 0.7) {
      return puzzles;
    }

    return null;
  }

  /// 간단한 퍼즐 생성 (폴백용)
  List<List<List<int>>> _generateSimplePuzzle(
      List<List<List<int>>> solvedBoards, int difficulty) {
    List<List<List<int>>> puzzles = solvedBoards
        .map((board) => board.map((row) => List<int>.from(row)).toList())
        .toList();

    double revealPercentage = (81 - difficulty.clamp(0, 81)) / 81.0;
    int totalGridCells = 21 * 21;
    int cellsToReveal = (totalGridCells * revealPercentage).round();

    // 모든 보드의 모든 셀을 0으로 초기화
    for (int b = 0; b < 5; b++) {
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          puzzles[b][r][c] = 0;
        }
      }
    }

    // 중앙 보드의 비겹침 영역에 최소 셀 보장
    Set<int> preRevealedPositions = {};

    int minCellsPerCenterBox;
    if (difficulty >= 70) {
      minCellsPerCenterBox = 1;
    } else if (difficulty >= 60) {
      minCellsPerCenterBox = 2;
    } else if (difficulty >= 45) {
      minCellsPerCenterBox = 3;
    } else {
      minCellsPerCenterBox = 4;
    }

    if (minCellsPerCenterBox > 0) {
      List<List<int>> centerOnlyBoxes = [
        [6, 9], [9, 6], [9, 9], [9, 12], [12, 9],
      ];

      for (var box in centerOnlyBoxes) {
        int startRow = box[0];
        int startCol = box[1];

        List<int> boxPositions = [];
        for (int r = 0; r < 3; r++) {
          for (int c = 0; c < 3; c++) {
            boxPositions.add((startRow + r) * 21 + (startCol + c));
          }
        }
        boxPositions.shuffle(_random);

        for (int i = 0; i < minCellsPerCenterBox && i < boxPositions.length; i++) {
          int pos = boxPositions[i];
          preRevealedPositions.add(pos);

          int gridRow = pos ~/ 21;
          int gridCol = pos % 21;
          int boardRow = gridRow - 6;
          int boardCol = gridCol - 6;
          puzzles[2][boardRow][boardCol] = solvedBoards[2][boardRow][boardCol];
        }
      }
    }

    List<int> allPositions = [];
    for (int i = 0; i < totalGridCells; i++) {
      if (!preRevealedPositions.contains(i)) {
        allPositions.add(i);
      }
    }
    allPositions.shuffle(_random);

    int remainingToReveal = cellsToReveal - preRevealedPositions.length;

    for (int i = 0; i < remainingToReveal && i < allPositions.length; i++) {
      int pos = allPositions[i];
      int gridRow = pos ~/ 21;
      int gridCol = pos % 21;

      List<List<int>> mappings = _mapGridToBoards(gridRow, gridCol);

      for (var mapping in mappings) {
        puzzles[mapping[0]][mapping[1]][mapping[2]] =
            solvedBoards[mapping[0]][mapping[1]][mapping[2]];
      }
    }

    return puzzles;
  }

  /// 21x21 그리드 위치를 보드 위치로 매핑
  /// 빈 영역이면 빈 리스트 반환
  /// 겹치는 영역이면 여러 보드 위치 반환
  List<List<int>> _mapGridToBoards(int gridRow, int gridCol) {
    List<List<int>> result = [];

    // 보드 0: 그리드 (0-8, 0-8) -> 보드0 (0-8, 0-8)
    if (gridRow >= 0 && gridRow < 9 && gridCol >= 0 && gridCol < 9) {
      result.add([0, gridRow, gridCol]);
    }

    // 보드 1: 그리드 (0-8, 12-20) -> 보드1 (0-8, 0-8)
    if (gridRow >= 0 && gridRow < 9 && gridCol >= 12 && gridCol < 21) {
      result.add([1, gridRow, gridCol - 12]);
    }

    // 보드 2: 그리드 (6-14, 6-14) -> 보드2 (0-8, 0-8)
    if (gridRow >= 6 && gridRow < 15 && gridCol >= 6 && gridCol < 15) {
      result.add([2, gridRow - 6, gridCol - 6]);
    }

    // 보드 3: 그리드 (12-20, 0-8) -> 보드3 (0-8, 0-8)
    if (gridRow >= 12 && gridRow < 21 && gridCol >= 0 && gridCol < 9) {
      result.add([3, gridRow - 12, gridCol]);
    }

    // 보드 4: 그리드 (12-20, 12-20) -> 보드4 (0-8, 0-8)
    if (gridRow >= 12 && gridRow < 21 && gridCol >= 12 && gridCol < 21) {
      result.add([4, gridRow - 12, gridCol - 12]);
    }

    return result;
  }

  bool _fillBoard(List<List<int>> board) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0) {
          List<int> numbers = List.generate(9, (i) => i + 1)..shuffle(_random);
          for (int num in numbers) {
            if (_isValidInBoard(board, row, col, num)) {
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

  bool _fillBoardPartial(List<List<int>> board) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0) {
          List<int> numbers = List.generate(9, (i) => i + 1)..shuffle(_random);
          for (int num in numbers) {
            if (_isValidInBoard(board, row, col, num)) {
              board[row][col] = num;
              if (_fillBoardPartial(board)) {
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

  bool _isValidInBoard(List<List<int>> board, int row, int col, int num) {
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

  /// 특정 보드에서 입력이 유효한지 검사
  static bool isValidMove(List<List<int>> board, int row, int col, int num) {
    if (num == 0) return true;

    for (int i = 0; i < 9; i++) {
      if (i != col && board[row][i] == num) return false;
    }

    for (int i = 0; i < 9; i++) {
      if (i != row && board[i][col] == num) return false;
    }

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

  /// 모든 보드가 완성되었는지 검사 (solutions와 비교)
  static bool areAllBoardsComplete(
      List<List<List<int>>> boards, List<List<List<int>>> solutions) {
    for (int b = 0; b < 5; b++) {
      for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
          if (boards[b][row][col] != solutions[b][row][col]) {
            return false;
          }
        }
      }
    }
    return true;
  }
}
