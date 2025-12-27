/// 논리적 풀이 기법만으로 스도쿠를 풀 수 있는지 검증하는 솔버
/// 추측(guessing/backtracking) 없이 풀 수 있는 퍼즐인지 확인
class LogicalSolver {
  /// 퍼즐이 논리적 기법만으로 풀 수 있는지 확인
  /// 반환: 풀 수 있으면 true, 추측이 필요하면 false
  static bool canSolveLogically(List<List<int>> puzzle) {
    // 퍼즐 복사
    List<List<int>> board = puzzle.map((row) => List<int>.from(row)).toList();

    // 각 셀의 후보 숫자 초기화
    List<List<Set<int>>> candidates = List.generate(
      9,
      (_) => List.generate(9, (_) => <int>{}),
    );

    // 초기 후보 계산
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0) {
          candidates[row][col] = _getCandidates(board, row, col);
        }
      }
    }

    // 반복적으로 논리 기법 적용
    bool progress = true;
    while (progress) {
      progress = false;

      // 1. Naked Singles (유일 후보)
      for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
          if (board[row][col] == 0 && candidates[row][col].length == 1) {
            int value = candidates[row][col].first;
            board[row][col] = value;
            candidates[row][col].clear();
            _eliminateFromPeers(candidates, row, col, value);
            progress = true;
          }
        }
      }

      // 2. Hidden Singles (숨은 유일 후보)
      // 행에서 Hidden Singles
      for (int row = 0; row < 9; row++) {
        for (int num = 1; num <= 9; num++) {
          List<int> positions = [];
          for (int col = 0; col < 9; col++) {
            if (board[row][col] == 0 && candidates[row][col].contains(num)) {
              positions.add(col);
            }
          }
          if (positions.length == 1) {
            int col = positions[0];
            board[row][col] = num;
            candidates[row][col].clear();
            _eliminateFromPeers(candidates, row, col, num);
            progress = true;
          }
        }
      }

      // 열에서 Hidden Singles
      for (int col = 0; col < 9; col++) {
        for (int num = 1; num <= 9; num++) {
          List<int> positions = [];
          for (int row = 0; row < 9; row++) {
            if (board[row][col] == 0 && candidates[row][col].contains(num)) {
              positions.add(row);
            }
          }
          if (positions.length == 1) {
            int row = positions[0];
            board[row][col] = num;
            candidates[row][col].clear();
            _eliminateFromPeers(candidates, row, col, num);
            progress = true;
          }
        }
      }

      // 박스에서 Hidden Singles
      for (int boxRow = 0; boxRow < 3; boxRow++) {
        for (int boxCol = 0; boxCol < 3; boxCol++) {
          for (int num = 1; num <= 9; num++) {
            List<List<int>> positions = [];
            for (int r = 0; r < 3; r++) {
              for (int c = 0; c < 3; c++) {
                int row = boxRow * 3 + r;
                int col = boxCol * 3 + c;
                if (board[row][col] == 0 && candidates[row][col].contains(num)) {
                  positions.add([row, col]);
                }
              }
            }
            if (positions.length == 1) {
              int row = positions[0][0];
              int col = positions[0][1];
              board[row][col] = num;
              candidates[row][col].clear();
              _eliminateFromPeers(candidates, row, col, num);
              progress = true;
            }
          }
        }
      }

      // 3. Pointing Pairs (박스-라인 축소)
      if (_applyPointingPairs(board, candidates)) {
        progress = true;
      }

      // 4. Box-Line Reduction
      if (_applyBoxLineReduction(board, candidates)) {
        progress = true;
      }

      // 5. Naked Pairs
      if (_applyNakedPairs(board, candidates)) {
        progress = true;
      }

      // 모순 검사: 빈 셀인데 후보가 없으면 풀 수 없음
      for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
          if (board[row][col] == 0 && candidates[row][col].isEmpty) {
            return false;
          }
        }
      }
    }

    // 모든 셀이 채워졌는지 확인
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0) {
          return false; // 아직 빈 셀이 있으면 추측이 필요함
        }
      }
    }

    return true;
  }

  /// 셀에 가능한 후보 숫자 계산
  static Set<int> _getCandidates(List<List<int>> board, int row, int col) {
    Set<int> candidates = {1, 2, 3, 4, 5, 6, 7, 8, 9};

    // 같은 행에서 제거
    for (int c = 0; c < 9; c++) {
      candidates.remove(board[row][c]);
    }

    // 같은 열에서 제거
    for (int r = 0; r < 9; r++) {
      candidates.remove(board[r][col]);
    }

    // 같은 박스에서 제거
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        candidates.remove(board[boxRow + r][boxCol + c]);
      }
    }

    return candidates;
  }

  /// 관련 셀들에서 후보 제거
  static void _eliminateFromPeers(
      List<List<Set<int>>> candidates, int row, int col, int value) {
    // 같은 행
    for (int c = 0; c < 9; c++) {
      candidates[row][c].remove(value);
    }

    // 같은 열
    for (int r = 0; r < 9; r++) {
      candidates[r][col].remove(value);
    }

    // 같은 박스
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        candidates[boxRow + r][boxCol + c].remove(value);
      }
    }
  }

  /// Pointing Pairs: 박스 내에서 특정 숫자가 한 행/열에만 있으면
  /// 그 행/열의 다른 박스에서 해당 숫자 제거
  static bool _applyPointingPairs(
      List<List<int>> board, List<List<Set<int>>> candidates) {
    bool changed = false;

    for (int boxRow = 0; boxRow < 3; boxRow++) {
      for (int boxCol = 0; boxCol < 3; boxCol++) {
        for (int num = 1; num <= 9; num++) {
          // 해당 박스에서 이 숫자가 가능한 위치 수집
          Set<int> rows = {};
          Set<int> cols = {};
          for (int r = 0; r < 3; r++) {
            for (int c = 0; c < 3; c++) {
              int row = boxRow * 3 + r;
              int col = boxCol * 3 + c;
              if (board[row][col] == 0 && candidates[row][col].contains(num)) {
                rows.add(row);
                cols.add(col);
              }
            }
          }

          // 한 행에만 있으면 그 행의 다른 박스에서 제거
          if (rows.length == 1) {
            int row = rows.first;
            for (int c = 0; c < 9; c++) {
              if (c ~/ 3 != boxCol) {
                if (candidates[row][c].remove(num)) {
                  changed = true;
                }
              }
            }
          }

          // 한 열에만 있으면 그 열의 다른 박스에서 제거
          if (cols.length == 1) {
            int col = cols.first;
            for (int r = 0; r < 9; r++) {
              if (r ~/ 3 != boxRow) {
                if (candidates[r][col].remove(num)) {
                  changed = true;
                }
              }
            }
          }
        }
      }
    }

    return changed;
  }

  /// Box-Line Reduction: 행/열에서 특정 숫자가 한 박스에만 있으면
  /// 그 박스의 다른 셀에서 해당 숫자 제거
  static bool _applyBoxLineReduction(
      List<List<int>> board, List<List<Set<int>>> candidates) {
    bool changed = false;

    // 행 검사
    for (int row = 0; row < 9; row++) {
      for (int num = 1; num <= 9; num++) {
        Set<int> boxes = {};
        List<int> positions = [];
        for (int col = 0; col < 9; col++) {
          if (board[row][col] == 0 && candidates[row][col].contains(num)) {
            boxes.add(col ~/ 3);
            positions.add(col);
          }
        }

        // 한 박스에만 있으면 그 박스의 다른 행에서 제거
        if (boxes.length == 1 && positions.isNotEmpty) {
          int boxCol = boxes.first;
          int boxRow = row ~/ 3;
          for (int r = boxRow * 3; r < boxRow * 3 + 3; r++) {
            if (r != row) {
              for (int c = boxCol * 3; c < boxCol * 3 + 3; c++) {
                if (candidates[r][c].remove(num)) {
                  changed = true;
                }
              }
            }
          }
        }
      }
    }

    // 열 검사
    for (int col = 0; col < 9; col++) {
      for (int num = 1; num <= 9; num++) {
        Set<int> boxes = {};
        List<int> positions = [];
        for (int row = 0; row < 9; row++) {
          if (board[row][col] == 0 && candidates[row][col].contains(num)) {
            boxes.add(row ~/ 3);
            positions.add(row);
          }
        }

        // 한 박스에만 있으면 그 박스의 다른 열에서 제거
        if (boxes.length == 1 && positions.isNotEmpty) {
          int boxRow = boxes.first;
          int boxCol = col ~/ 3;
          for (int c = boxCol * 3; c < boxCol * 3 + 3; c++) {
            if (c != col) {
              for (int r = boxRow * 3; r < boxRow * 3 + 3; r++) {
                if (candidates[r][c].remove(num)) {
                  changed = true;
                }
              }
            }
          }
        }
      }
    }

    return changed;
  }

  /// Naked Pairs: 같은 유닛에서 두 셀이 같은 두 후보만 가지면
  /// 그 유닛의 다른 셀에서 해당 숫자들 제거
  static bool _applyNakedPairs(
      List<List<int>> board, List<List<Set<int>>> candidates) {
    bool changed = false;

    // 행에서 Naked Pairs
    for (int row = 0; row < 9; row++) {
      List<int> pairCells = [];
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0 && candidates[row][col].length == 2) {
          pairCells.add(col);
        }
      }

      for (int i = 0; i < pairCells.length; i++) {
        for (int j = i + 1; j < pairCells.length; j++) {
          int col1 = pairCells[i];
          int col2 = pairCells[j];
          if (candidates[row][col1].containsAll(candidates[row][col2]) &&
              candidates[row][col2].containsAll(candidates[row][col1])) {
            // Naked Pair 발견
            Set<int> pair = candidates[row][col1];
            for (int c = 0; c < 9; c++) {
              if (c != col1 && c != col2 && board[row][c] == 0) {
                for (int num in pair) {
                  if (candidates[row][c].remove(num)) {
                    changed = true;
                  }
                }
              }
            }
          }
        }
      }
    }

    // 열에서 Naked Pairs
    for (int col = 0; col < 9; col++) {
      List<int> pairCells = [];
      for (int row = 0; row < 9; row++) {
        if (board[row][col] == 0 && candidates[row][col].length == 2) {
          pairCells.add(row);
        }
      }

      for (int i = 0; i < pairCells.length; i++) {
        for (int j = i + 1; j < pairCells.length; j++) {
          int row1 = pairCells[i];
          int row2 = pairCells[j];
          if (candidates[row1][col].containsAll(candidates[row2][col]) &&
              candidates[row2][col].containsAll(candidates[row1][col])) {
            Set<int> pair = candidates[row1][col];
            for (int r = 0; r < 9; r++) {
              if (r != row1 && r != row2 && board[r][col] == 0) {
                for (int num in pair) {
                  if (candidates[r][col].remove(num)) {
                    changed = true;
                  }
                }
              }
            }
          }
        }
      }
    }

    // 박스에서 Naked Pairs
    for (int boxRow = 0; boxRow < 3; boxRow++) {
      for (int boxCol = 0; boxCol < 3; boxCol++) {
        List<List<int>> pairCells = [];
        for (int r = 0; r < 3; r++) {
          for (int c = 0; c < 3; c++) {
            int row = boxRow * 3 + r;
            int col = boxCol * 3 + c;
            if (board[row][col] == 0 && candidates[row][col].length == 2) {
              pairCells.add([row, col]);
            }
          }
        }

        for (int i = 0; i < pairCells.length; i++) {
          for (int j = i + 1; j < pairCells.length; j++) {
            int row1 = pairCells[i][0], col1 = pairCells[i][1];
            int row2 = pairCells[j][0], col2 = pairCells[j][1];
            if (candidates[row1][col1].containsAll(candidates[row2][col2]) &&
                candidates[row2][col2].containsAll(candidates[row1][col1])) {
              Set<int> pair = candidates[row1][col1];
              for (int r = 0; r < 3; r++) {
                for (int c = 0; c < 3; c++) {
                  int row = boxRow * 3 + r;
                  int col = boxCol * 3 + c;
                  if ((row != row1 || col != col1) &&
                      (row != row2 || col != col2) &&
                      board[row][col] == 0) {
                    for (int num in pair) {
                      if (candidates[row][col].remove(num)) {
                        changed = true;
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    return changed;
  }

  /// 사무라이 스도쿠 퍼즐이 논리적으로 풀 수 있는지 확인
  /// 5개의 겹치는 보드를 함께 고려하여 검증
  static bool canSolveSamuraiLogically(List<List<List<int>>> puzzles) {
    // 5개 보드 복사
    List<List<List<int>>> boards = puzzles
        .map((board) => board.map((row) => List<int>.from(row)).toList())
        .toList();

    // 각 보드의 후보 숫자
    List<List<List<Set<int>>>> allCandidates = List.generate(
      5,
      (_) => List.generate(9, (_) => List.generate(9, (_) => <int>{})),
    );

    // 초기 후보 계산 (겹치는 영역 고려)
    for (int b = 0; b < 5; b++) {
      for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
          if (boards[b][row][col] == 0) {
            allCandidates[b][row][col] =
                _getSamuraiCandidates(boards, b, row, col);
          }
        }
      }
    }

    // 반복적으로 논리 기법 적용
    bool progress = true;
    while (progress) {
      progress = false;

      for (int b = 0; b < 5; b++) {
        // 1. Naked Singles
        for (int row = 0; row < 9; row++) {
          for (int col = 0; col < 9; col++) {
            if (boards[b][row][col] == 0 &&
                allCandidates[b][row][col].length == 1) {
              int value = allCandidates[b][row][col].first;
              _placeSamuraiValue(boards, allCandidates, b, row, col, value);
              progress = true;
            }
          }
        }

        // 2. Hidden Singles - 행
        for (int row = 0; row < 9; row++) {
          for (int num = 1; num <= 9; num++) {
            List<int> positions = [];
            for (int col = 0; col < 9; col++) {
              if (boards[b][row][col] == 0 &&
                  allCandidates[b][row][col].contains(num)) {
                positions.add(col);
              }
            }
            if (positions.length == 1) {
              int col = positions[0];
              _placeSamuraiValue(boards, allCandidates, b, row, col, num);
              progress = true;
            }
          }
        }

        // 2. Hidden Singles - 열
        for (int col = 0; col < 9; col++) {
          for (int num = 1; num <= 9; num++) {
            List<int> positions = [];
            for (int row = 0; row < 9; row++) {
              if (boards[b][row][col] == 0 &&
                  allCandidates[b][row][col].contains(num)) {
                positions.add(row);
              }
            }
            if (positions.length == 1) {
              int row = positions[0];
              _placeSamuraiValue(boards, allCandidates, b, row, col, num);
              progress = true;
            }
          }
        }

        // 2. Hidden Singles - 박스
        for (int boxRow = 0; boxRow < 3; boxRow++) {
          for (int boxCol = 0; boxCol < 3; boxCol++) {
            for (int num = 1; num <= 9; num++) {
              List<List<int>> positions = [];
              for (int r = 0; r < 3; r++) {
                for (int c = 0; c < 3; c++) {
                  int row = boxRow * 3 + r;
                  int col = boxCol * 3 + c;
                  if (boards[b][row][col] == 0 &&
                      allCandidates[b][row][col].contains(num)) {
                    positions.add([row, col]);
                  }
                }
              }
              if (positions.length == 1) {
                int row = positions[0][0];
                int col = positions[0][1];
                _placeSamuraiValue(boards, allCandidates, b, row, col, num);
                progress = true;
              }
            }
          }
        }
      }

      // 3. Pointing Pairs (각 보드별로 적용)
      for (int b = 0; b < 5; b++) {
        if (_applySamuraiPointingPairs(boards[b], allCandidates[b])) {
          progress = true;
        }
      }

      // 4. Box-Line Reduction (각 보드별로 적용)
      for (int b = 0; b < 5; b++) {
        if (_applySamuraiBoxLineReduction(boards[b], allCandidates[b])) {
          progress = true;
        }
      }

      // 5. Naked Pairs (각 보드별로 적용)
      for (int b = 0; b < 5; b++) {
        if (_applySamuraiNakedPairs(boards[b], allCandidates[b])) {
          progress = true;
        }
      }

      // 6. Hidden Pairs (각 보드별로 적용)
      for (int b = 0; b < 5; b++) {
        if (_applySamuraiHiddenPairs(boards[b], allCandidates[b])) {
          progress = true;
        }
      }

      // 7. Naked Triples (각 보드별로 적용)
      for (int b = 0; b < 5; b++) {
        if (_applySamuraiNakedTriples(boards[b], allCandidates[b])) {
          progress = true;
        }
      }

      // 8. X-Wing (각 보드별로 적용)
      for (int b = 0; b < 5; b++) {
        if (_applySamuraiXWing(boards[b], allCandidates[b])) {
          progress = true;
        }
      }

      // 9. Swordfish (각 보드별로 적용)
      for (int b = 0; b < 5; b++) {
        if (_applySamuraiSwordfish(boards[b], allCandidates[b])) {
          progress = true;
        }
      }

      // 모순 검사
      for (int b = 0; b < 5; b++) {
        for (int row = 0; row < 9; row++) {
          for (int col = 0; col < 9; col++) {
            if (boards[b][row][col] == 0 &&
                allCandidates[b][row][col].isEmpty) {
              return false;
            }
          }
        }
      }
    }

    // 모든 셀이 채워졌는지 확인
    for (int b = 0; b < 5; b++) {
      for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
          if (boards[b][row][col] == 0) {
            return false;
          }
        }
      }
    }

    return true;
  }

  /// 사무라이 스도쿠에서 셀의 후보 계산 (겹치는 영역 고려)
  static Set<int> _getSamuraiCandidates(
      List<List<List<int>>> boards, int boardIdx, int row, int col) {
    Set<int> candidates = {1, 2, 3, 4, 5, 6, 7, 8, 9};

    // 현재 보드의 행/열/박스에서 제거
    for (int c = 0; c < 9; c++) {
      candidates.remove(boards[boardIdx][row][c]);
    }
    for (int r = 0; r < 9; r++) {
      candidates.remove(boards[boardIdx][r][col]);
    }
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        candidates.remove(boards[boardIdx][boxRow + r][boxCol + c]);
      }
    }

    // 겹치는 영역이면 다른 보드의 제약도 고려
    var overlap = _getOverlappingBoard(boardIdx, row, col);
    if (overlap != null) {
      int otherBoard = overlap[0];
      int otherRow = overlap[1];
      int otherCol = overlap[2];

      // 다른 보드의 행/열/박스에서도 제거
      for (int c = 0; c < 9; c++) {
        candidates.remove(boards[otherBoard][otherRow][c]);
      }
      for (int r = 0; r < 9; r++) {
        candidates.remove(boards[otherBoard][r][otherCol]);
      }
      int otherBoxRow = (otherRow ~/ 3) * 3;
      int otherBoxCol = (otherCol ~/ 3) * 3;
      for (int r = 0; r < 3; r++) {
        for (int c = 0; c < 3; c++) {
          candidates.remove(boards[otherBoard][otherBoxRow + r][otherBoxCol + c]);
        }
      }
    }

    return candidates;
  }

  /// 겹치는 보드와 좌표 반환 (없으면 null)
  static List<int>? _getOverlappingBoard(int boardIdx, int row, int col) {
    // 보드 0 우하단 (6-8, 6-8) <-> 보드 2 좌상단 (0-2, 0-2)
    if (boardIdx == 0 && row >= 6 && col >= 6) {
      return [2, row - 6, col - 6];
    }
    if (boardIdx == 2 && row <= 2 && col <= 2) {
      return [0, row + 6, col + 6];
    }

    // 보드 1 좌하단 (6-8, 0-2) <-> 보드 2 우상단 (0-2, 6-8)
    if (boardIdx == 1 && row >= 6 && col <= 2) {
      return [2, row - 6, col + 6];
    }
    if (boardIdx == 2 && row <= 2 && col >= 6) {
      return [1, row + 6, col - 6];
    }

    // 보드 2 좌하단 (6-8, 0-2) <-> 보드 3 우상단 (0-2, 6-8)
    if (boardIdx == 2 && row >= 6 && col <= 2) {
      return [3, row - 6, col + 6];
    }
    if (boardIdx == 3 && row <= 2 && col >= 6) {
      return [2, row + 6, col - 6];
    }

    // 보드 2 우하단 (6-8, 6-8) <-> 보드 4 좌상단 (0-2, 0-2)
    if (boardIdx == 2 && row >= 6 && col >= 6) {
      return [4, row - 6, col - 6];
    }
    if (boardIdx == 4 && row <= 2 && col <= 2) {
      return [2, row + 6, col + 6];
    }

    return null;
  }

  /// 사무라이 스도쿠에서 값 배치 (겹치는 영역 동기화)
  static void _placeSamuraiValue(
      List<List<List<int>>> boards,
      List<List<List<Set<int>>>> allCandidates,
      int boardIdx,
      int row,
      int col,
      int value) {
    // 현재 보드에 값 배치
    boards[boardIdx][row][col] = value;
    allCandidates[boardIdx][row][col].clear();

    // 현재 보드의 peers에서 후보 제거
    _eliminateSamuraiFromPeers(allCandidates[boardIdx], row, col, value);

    // 겹치는 영역이면 다른 보드도 업데이트
    var overlap = _getOverlappingBoard(boardIdx, row, col);
    if (overlap != null) {
      int otherBoard = overlap[0];
      int otherRow = overlap[1];
      int otherCol = overlap[2];

      boards[otherBoard][otherRow][otherCol] = value;
      allCandidates[otherBoard][otherRow][otherCol].clear();
      _eliminateSamuraiFromPeers(
          allCandidates[otherBoard], otherRow, otherCol, value);
    }
  }

  /// 사무라이 스도쿠에서 peers 후보 제거
  static void _eliminateSamuraiFromPeers(
      List<List<Set<int>>> candidates, int row, int col, int value) {
    for (int c = 0; c < 9; c++) {
      candidates[row][c].remove(value);
    }
    for (int r = 0; r < 9; r++) {
      candidates[r][col].remove(value);
    }
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        candidates[boxRow + r][boxCol + c].remove(value);
      }
    }
  }

  /// 사무라이 스도쿠용 Pointing Pairs
  static bool _applySamuraiPointingPairs(
      List<List<int>> board, List<List<Set<int>>> candidates) {
    bool changed = false;

    for (int boxRow = 0; boxRow < 3; boxRow++) {
      for (int boxCol = 0; boxCol < 3; boxCol++) {
        for (int num = 1; num <= 9; num++) {
          Set<int> rows = {};
          Set<int> cols = {};
          for (int r = 0; r < 3; r++) {
            for (int c = 0; c < 3; c++) {
              int row = boxRow * 3 + r;
              int col = boxCol * 3 + c;
              if (board[row][col] == 0 && candidates[row][col].contains(num)) {
                rows.add(row);
                cols.add(col);
              }
            }
          }

          if (rows.length == 1) {
            int row = rows.first;
            for (int c = 0; c < 9; c++) {
              if (c ~/ 3 != boxCol) {
                if (candidates[row][c].remove(num)) {
                  changed = true;
                }
              }
            }
          }

          if (cols.length == 1) {
            int col = cols.first;
            for (int r = 0; r < 9; r++) {
              if (r ~/ 3 != boxRow) {
                if (candidates[r][col].remove(num)) {
                  changed = true;
                }
              }
            }
          }
        }
      }
    }

    return changed;
  }

  /// 사무라이 스도쿠용 Box-Line Reduction
  static bool _applySamuraiBoxLineReduction(
      List<List<int>> board, List<List<Set<int>>> candidates) {
    bool changed = false;

    // 행 검사
    for (int row = 0; row < 9; row++) {
      for (int num = 1; num <= 9; num++) {
        Set<int> boxes = {};
        List<int> positions = [];
        for (int col = 0; col < 9; col++) {
          if (board[row][col] == 0 && candidates[row][col].contains(num)) {
            boxes.add(col ~/ 3);
            positions.add(col);
          }
        }

        if (boxes.length == 1 && positions.isNotEmpty) {
          int boxCol = boxes.first;
          int boxRow = row ~/ 3;
          for (int r = boxRow * 3; r < boxRow * 3 + 3; r++) {
            if (r != row) {
              for (int c = boxCol * 3; c < boxCol * 3 + 3; c++) {
                if (candidates[r][c].remove(num)) {
                  changed = true;
                }
              }
            }
          }
        }
      }
    }

    // 열 검사
    for (int col = 0; col < 9; col++) {
      for (int num = 1; num <= 9; num++) {
        Set<int> boxes = {};
        List<int> positions = [];
        for (int row = 0; row < 9; row++) {
          if (board[row][col] == 0 && candidates[row][col].contains(num)) {
            boxes.add(row ~/ 3);
            positions.add(row);
          }
        }

        if (boxes.length == 1 && positions.isNotEmpty) {
          int boxRow = boxes.first;
          int boxCol = col ~/ 3;
          for (int c = boxCol * 3; c < boxCol * 3 + 3; c++) {
            if (c != col) {
              for (int r = boxRow * 3; r < boxRow * 3 + 3; r++) {
                if (candidates[r][c].remove(num)) {
                  changed = true;
                }
              }
            }
          }
        }
      }
    }

    return changed;
  }

  /// 사무라이 스도쿠용 Naked Pairs
  static bool _applySamuraiNakedPairs(
      List<List<int>> board, List<List<Set<int>>> candidates) {
    bool changed = false;

    // 행에서 Naked Pairs
    for (int row = 0; row < 9; row++) {
      List<int> pairCells = [];
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0 && candidates[row][col].length == 2) {
          pairCells.add(col);
        }
      }

      for (int i = 0; i < pairCells.length; i++) {
        for (int j = i + 1; j < pairCells.length; j++) {
          int col1 = pairCells[i];
          int col2 = pairCells[j];
          if (candidates[row][col1].containsAll(candidates[row][col2]) &&
              candidates[row][col2].containsAll(candidates[row][col1])) {
            Set<int> pair = candidates[row][col1];
            for (int c = 0; c < 9; c++) {
              if (c != col1 && c != col2 && board[row][c] == 0) {
                for (int num in pair) {
                  if (candidates[row][c].remove(num)) {
                    changed = true;
                  }
                }
              }
            }
          }
        }
      }
    }

    // 열에서 Naked Pairs
    for (int col = 0; col < 9; col++) {
      List<int> pairCells = [];
      for (int row = 0; row < 9; row++) {
        if (board[row][col] == 0 && candidates[row][col].length == 2) {
          pairCells.add(row);
        }
      }

      for (int i = 0; i < pairCells.length; i++) {
        for (int j = i + 1; j < pairCells.length; j++) {
          int row1 = pairCells[i];
          int row2 = pairCells[j];
          if (candidates[row1][col].containsAll(candidates[row2][col]) &&
              candidates[row2][col].containsAll(candidates[row1][col])) {
            Set<int> pair = candidates[row1][col];
            for (int r = 0; r < 9; r++) {
              if (r != row1 && r != row2 && board[r][col] == 0) {
                for (int num in pair) {
                  if (candidates[r][col].remove(num)) {
                    changed = true;
                  }
                }
              }
            }
          }
        }
      }
    }

    // 박스에서 Naked Pairs
    for (int boxRow = 0; boxRow < 3; boxRow++) {
      for (int boxCol = 0; boxCol < 3; boxCol++) {
        List<List<int>> pairCells = [];
        for (int r = 0; r < 3; r++) {
          for (int c = 0; c < 3; c++) {
            int row = boxRow * 3 + r;
            int col = boxCol * 3 + c;
            if (board[row][col] == 0 && candidates[row][col].length == 2) {
              pairCells.add([row, col]);
            }
          }
        }

        for (int i = 0; i < pairCells.length; i++) {
          for (int j = i + 1; j < pairCells.length; j++) {
            int row1 = pairCells[i][0], col1 = pairCells[i][1];
            int row2 = pairCells[j][0], col2 = pairCells[j][1];
            if (candidates[row1][col1].containsAll(candidates[row2][col2]) &&
                candidates[row2][col2].containsAll(candidates[row1][col1])) {
              Set<int> pair = candidates[row1][col1];
              for (int r = 0; r < 3; r++) {
                for (int c = 0; c < 3; c++) {
                  int row = boxRow * 3 + r;
                  int col = boxCol * 3 + c;
                  if ((row != row1 || col != col1) &&
                      (row != row2 || col != col2) &&
                      board[row][col] == 0) {
                    for (int num in pair) {
                      if (candidates[row][col].remove(num)) {
                        changed = true;
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    return changed;
  }

  /// 사무라이 스도쿠용 Hidden Pairs
  static bool _applySamuraiHiddenPairs(
      List<List<int>> board, List<List<Set<int>>> candidates) {
    bool changed = false;

    // 행에서 Hidden Pairs
    for (int row = 0; row < 9; row++) {
      for (int num1 = 1; num1 <= 8; num1++) {
        for (int num2 = num1 + 1; num2 <= 9; num2++) {
          List<int> positions = [];
          for (int col = 0; col < 9; col++) {
            if (board[row][col] == 0 &&
                (candidates[row][col].contains(num1) ||
                    candidates[row][col].contains(num2))) {
              if (candidates[row][col].contains(num1) &&
                  candidates[row][col].contains(num2)) {
                positions.add(col);
              } else {
                positions.clear();
                break;
              }
            }
          }
          if (positions.length == 2) {
            for (int col in positions) {
              if (candidates[row][col].length > 2) {
                candidates[row][col] = {num1, num2};
                changed = true;
              }
            }
          }
        }
      }
    }

    // 열에서 Hidden Pairs
    for (int col = 0; col < 9; col++) {
      for (int num1 = 1; num1 <= 8; num1++) {
        for (int num2 = num1 + 1; num2 <= 9; num2++) {
          List<int> positions = [];
          for (int row = 0; row < 9; row++) {
            if (board[row][col] == 0 &&
                (candidates[row][col].contains(num1) ||
                    candidates[row][col].contains(num2))) {
              if (candidates[row][col].contains(num1) &&
                  candidates[row][col].contains(num2)) {
                positions.add(row);
              } else {
                positions.clear();
                break;
              }
            }
          }
          if (positions.length == 2) {
            for (int row in positions) {
              if (candidates[row][col].length > 2) {
                candidates[row][col] = {num1, num2};
                changed = true;
              }
            }
          }
        }
      }
    }

    // 박스에서 Hidden Pairs
    for (int boxRow = 0; boxRow < 3; boxRow++) {
      for (int boxCol = 0; boxCol < 3; boxCol++) {
        for (int num1 = 1; num1 <= 8; num1++) {
          for (int num2 = num1 + 1; num2 <= 9; num2++) {
            List<List<int>> positions = [];
            bool valid = true;
            for (int r = 0; r < 3 && valid; r++) {
              for (int c = 0; c < 3 && valid; c++) {
                int row = boxRow * 3 + r;
                int col = boxCol * 3 + c;
                if (board[row][col] == 0 &&
                    (candidates[row][col].contains(num1) ||
                        candidates[row][col].contains(num2))) {
                  if (candidates[row][col].contains(num1) &&
                      candidates[row][col].contains(num2)) {
                    positions.add([row, col]);
                  } else {
                    valid = false;
                  }
                }
              }
            }
            if (valid && positions.length == 2) {
              for (var pos in positions) {
                if (candidates[pos[0]][pos[1]].length > 2) {
                  candidates[pos[0]][pos[1]] = {num1, num2};
                  changed = true;
                }
              }
            }
          }
        }
      }
    }

    return changed;
  }

  /// 사무라이 스도쿠용 Naked Triples
  static bool _applySamuraiNakedTriples(
      List<List<int>> board, List<List<Set<int>>> candidates) {
    bool changed = false;

    // 행에서 Naked Triples
    for (int row = 0; row < 9; row++) {
      List<int> tripleCells = [];
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0 &&
            candidates[row][col].length >= 2 &&
            candidates[row][col].length <= 3) {
          tripleCells.add(col);
        }
      }

      for (int i = 0; i < tripleCells.length; i++) {
        for (int j = i + 1; j < tripleCells.length; j++) {
          for (int k = j + 1; k < tripleCells.length; k++) {
            int col1 = tripleCells[i];
            int col2 = tripleCells[j];
            int col3 = tripleCells[k];
            Set<int> union = {...candidates[row][col1], ...candidates[row][col2], ...candidates[row][col3]};
            if (union.length == 3) {
              for (int c = 0; c < 9; c++) {
                if (c != col1 && c != col2 && c != col3 && board[row][c] == 0) {
                  for (int num in union) {
                    if (candidates[row][c].remove(num)) {
                      changed = true;
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // 열에서 Naked Triples
    for (int col = 0; col < 9; col++) {
      List<int> tripleCells = [];
      for (int row = 0; row < 9; row++) {
        if (board[row][col] == 0 &&
            candidates[row][col].length >= 2 &&
            candidates[row][col].length <= 3) {
          tripleCells.add(row);
        }
      }

      for (int i = 0; i < tripleCells.length; i++) {
        for (int j = i + 1; j < tripleCells.length; j++) {
          for (int k = j + 1; k < tripleCells.length; k++) {
            int row1 = tripleCells[i];
            int row2 = tripleCells[j];
            int row3 = tripleCells[k];
            Set<int> union = {...candidates[row1][col], ...candidates[row2][col], ...candidates[row3][col]};
            if (union.length == 3) {
              for (int r = 0; r < 9; r++) {
                if (r != row1 && r != row2 && r != row3 && board[r][col] == 0) {
                  for (int num in union) {
                    if (candidates[r][col].remove(num)) {
                      changed = true;
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // 박스에서 Naked Triples
    for (int boxRow = 0; boxRow < 3; boxRow++) {
      for (int boxCol = 0; boxCol < 3; boxCol++) {
        List<List<int>> tripleCells = [];
        for (int r = 0; r < 3; r++) {
          for (int c = 0; c < 3; c++) {
            int row = boxRow * 3 + r;
            int col = boxCol * 3 + c;
            if (board[row][col] == 0 &&
                candidates[row][col].length >= 2 &&
                candidates[row][col].length <= 3) {
              tripleCells.add([row, col]);
            }
          }
        }

        for (int i = 0; i < tripleCells.length; i++) {
          for (int j = i + 1; j < tripleCells.length; j++) {
            for (int k = j + 1; k < tripleCells.length; k++) {
              var c1 = tripleCells[i], c2 = tripleCells[j], c3 = tripleCells[k];
              Set<int> union = {
                ...candidates[c1[0]][c1[1]],
                ...candidates[c2[0]][c2[1]],
                ...candidates[c3[0]][c3[1]]
              };
              if (union.length == 3) {
                for (int r = 0; r < 3; r++) {
                  for (int c = 0; c < 3; c++) {
                    int row = boxRow * 3 + r;
                    int col = boxCol * 3 + c;
                    if ((row != c1[0] || col != c1[1]) &&
                        (row != c2[0] || col != c2[1]) &&
                        (row != c3[0] || col != c3[1]) &&
                        board[row][col] == 0) {
                      for (int num in union) {
                        if (candidates[row][col].remove(num)) {
                          changed = true;
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    return changed;
  }

  /// 사무라이 스도쿠용 X-Wing
  /// 두 행에서 특정 숫자가 같은 두 열에만 있으면, 그 두 열의 다른 행에서 제거
  static bool _applySamuraiXWing(
      List<List<int>> board, List<List<Set<int>>> candidates) {
    bool changed = false;

    // 행 기반 X-Wing
    for (int num = 1; num <= 9; num++) {
      List<List<int>> rowsWithTwoCols = [];
      for (int row = 0; row < 9; row++) {
        List<int> cols = [];
        for (int col = 0; col < 9; col++) {
          if (board[row][col] == 0 && candidates[row][col].contains(num)) {
            cols.add(col);
          }
        }
        if (cols.length == 2) {
          rowsWithTwoCols.add([row, cols[0], cols[1]]);
        }
      }

      for (int i = 0; i < rowsWithTwoCols.length; i++) {
        for (int j = i + 1; j < rowsWithTwoCols.length; j++) {
          if (rowsWithTwoCols[i][1] == rowsWithTwoCols[j][1] &&
              rowsWithTwoCols[i][2] == rowsWithTwoCols[j][2]) {
            int row1 = rowsWithTwoCols[i][0];
            int row2 = rowsWithTwoCols[j][0];
            int col1 = rowsWithTwoCols[i][1];
            int col2 = rowsWithTwoCols[i][2];

            for (int r = 0; r < 9; r++) {
              if (r != row1 && r != row2) {
                if (candidates[r][col1].remove(num)) changed = true;
                if (candidates[r][col2].remove(num)) changed = true;
              }
            }
          }
        }
      }
    }

    // 열 기반 X-Wing
    for (int num = 1; num <= 9; num++) {
      List<List<int>> colsWithTwoRows = [];
      for (int col = 0; col < 9; col++) {
        List<int> rows = [];
        for (int row = 0; row < 9; row++) {
          if (board[row][col] == 0 && candidates[row][col].contains(num)) {
            rows.add(row);
          }
        }
        if (rows.length == 2) {
          colsWithTwoRows.add([col, rows[0], rows[1]]);
        }
      }

      for (int i = 0; i < colsWithTwoRows.length; i++) {
        for (int j = i + 1; j < colsWithTwoRows.length; j++) {
          if (colsWithTwoRows[i][1] == colsWithTwoRows[j][1] &&
              colsWithTwoRows[i][2] == colsWithTwoRows[j][2]) {
            int col1 = colsWithTwoRows[i][0];
            int col2 = colsWithTwoRows[j][0];
            int row1 = colsWithTwoRows[i][1];
            int row2 = colsWithTwoRows[i][2];

            for (int c = 0; c < 9; c++) {
              if (c != col1 && c != col2) {
                if (candidates[row1][c].remove(num)) changed = true;
                if (candidates[row2][c].remove(num)) changed = true;
              }
            }
          }
        }
      }
    }

    return changed;
  }

  /// 사무라이 스도쿠용 Swordfish (X-Wing의 3행/3열 확장)
  static bool _applySamuraiSwordfish(
      List<List<int>> board, List<List<Set<int>>> candidates) {
    bool changed = false;

    // 행 기반 Swordfish
    for (int num = 1; num <= 9; num++) {
      List<List<int>> rowsWithCols = [];
      for (int row = 0; row < 9; row++) {
        List<int> cols = [];
        for (int col = 0; col < 9; col++) {
          if (board[row][col] == 0 && candidates[row][col].contains(num)) {
            cols.add(col);
          }
        }
        if (cols.length >= 2 && cols.length <= 3) {
          rowsWithCols.add([row, ...cols]);
        }
      }

      for (int i = 0; i < rowsWithCols.length; i++) {
        for (int j = i + 1; j < rowsWithCols.length; j++) {
          for (int k = j + 1; k < rowsWithCols.length; k++) {
            Set<int> allCols = {};
            for (int idx = 1; idx < rowsWithCols[i].length; idx++) {
              allCols.add(rowsWithCols[i][idx]);
            }
            for (int idx = 1; idx < rowsWithCols[j].length; idx++) {
              allCols.add(rowsWithCols[j][idx]);
            }
            for (int idx = 1; idx < rowsWithCols[k].length; idx++) {
              allCols.add(rowsWithCols[k][idx]);
            }

            if (allCols.length == 3) {
              int row1 = rowsWithCols[i][0];
              int row2 = rowsWithCols[j][0];
              int row3 = rowsWithCols[k][0];

              for (int r = 0; r < 9; r++) {
                if (r != row1 && r != row2 && r != row3) {
                  for (int col in allCols) {
                    if (candidates[r][col].remove(num)) changed = true;
                  }
                }
              }
            }
          }
        }
      }
    }

    // 열 기반 Swordfish
    for (int num = 1; num <= 9; num++) {
      List<List<int>> colsWithRows = [];
      for (int col = 0; col < 9; col++) {
        List<int> rows = [];
        for (int row = 0; row < 9; row++) {
          if (board[row][col] == 0 && candidates[row][col].contains(num)) {
            rows.add(row);
          }
        }
        if (rows.length >= 2 && rows.length <= 3) {
          colsWithRows.add([col, ...rows]);
        }
      }

      for (int i = 0; i < colsWithRows.length; i++) {
        for (int j = i + 1; j < colsWithRows.length; j++) {
          for (int k = j + 1; k < colsWithRows.length; k++) {
            Set<int> allRows = {};
            for (int idx = 1; idx < colsWithRows[i].length; idx++) {
              allRows.add(colsWithRows[i][idx]);
            }
            for (int idx = 1; idx < colsWithRows[j].length; idx++) {
              allRows.add(colsWithRows[j][idx]);
            }
            for (int idx = 1; idx < colsWithRows[k].length; idx++) {
              allRows.add(colsWithRows[k][idx]);
            }

            if (allRows.length == 3) {
              int col1 = colsWithRows[i][0];
              int col2 = colsWithRows[j][0];
              int col3 = colsWithRows[k][0];

              for (int c = 0; c < 9; c++) {
                if (c != col1 && c != col2 && c != col3) {
                  for (int row in allRows) {
                    if (candidates[row][c].remove(num)) changed = true;
                  }
                }
              }
            }
          }
        }
      }
    }

    return changed;
  }
}
