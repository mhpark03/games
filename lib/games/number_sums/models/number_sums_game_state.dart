import 'number_sums_generator.dart';

/// Isolate에서 실행할 퍼즐 생성 함수 (top-level 함수)
Map<String, dynamic> generateNumberSumsPuzzleInIsolate(NumberSumsDifficulty difficulty) {
  final generator = NumberSumsGenerator();
  return generator.generatePuzzle(difficulty);
}

/// Undo를 위한 동작 기록
class NumberSumsUndoAction {
  final int row;
  final int col;
  final int previousValue;

  NumberSumsUndoAction({
    required this.row,
    required this.col,
    required this.previousValue,
  });
}

/// 게임 모드
enum NumberSumsGameMode {
  select, // 선택 모드: 올바른 수 찾기
  remove, // 제거 모드: 틀린 수 제거
  hint, // 힌트 모드: 자동으로 정답 처리
}

// 블록 색상 정의
const List<int> blockColors = [
  0xFFFFCDD2, // red 100
  0xFFC8E6C9, // green 100
  0xFFBBDEFB, // blue 100
  0xFFFFF9C4, // yellow 100
  0xFFE1BEE7, // purple 100
  0xFFFFE0B2, // orange 100
  0xFFB2EBF2, // cyan 100
  0xFFF8BBD9, // pink 100
  0xFFD7CCC8, // brown 100
  0xFFCFD8DC, // blueGrey 100
];

class NumberSumsGameState {
  final List<List<int>> solution;
  final List<List<int>> puzzle;
  final List<List<int>> currentBoard;
  final List<List<int>> cellTypes; // 0 = 헤더, 1 = 입력 셀
  final List<List<bool>> wrongCells;
  final List<List<bool>> markedCorrectCells; // 올바른 수로 표시된 셀
  final List<int> rowSums; // 각 행의 정답 합계
  final List<int> colSums; // 각 열의 정답 합계
  final List<List<int>> blockIds; // 각 셀의 블록 ID
  final List<int> blockSums; // 각 블록의 원래 정답 합계
  final int gridSize; // 전체 그리드 크기 (헤더 포함)
  final int gameSize; // 실제 게임 그리드 크기
  final NumberSumsDifficulty difficulty;
  int? selectedRow;
  int? selectedCol;
  int mistakes;
  bool isCompleted;
  int elapsedSeconds;
  int failureCount;
  final List<NumberSumsUndoAction> _undoHistory;
  static const int maxUndoCount = 20;

  NumberSumsGameState({
    required this.solution,
    required this.puzzle,
    required this.currentBoard,
    required this.cellTypes,
    required this.wrongCells,
    required this.markedCorrectCells,
    required this.rowSums,
    required this.colSums,
    required this.blockIds,
    required this.blockSums,
    required this.gridSize,
    required this.gameSize,
    required this.difficulty,
    this.selectedRow,
    this.selectedCol,
    this.mistakes = 0,
    this.isCompleted = false,
    this.elapsedSeconds = 0,
    this.failureCount = 0,
    List<NumberSumsUndoAction>? undoHistory,
  }) : _undoHistory = undoHistory ?? [];

  factory NumberSumsGameState.fromGeneratedData(Map<String, dynamic> data) {
    final gridSize = data['gridSize'] as int;
    final gameSize = data['gameSize'] as int;
    final solution = (data['solution'] as List)
        .map((row) => List<int>.from(row as List))
        .toList();
    final puzzle = (data['puzzle'] as List)
        .map((row) => List<int>.from(row as List))
        .toList();
    final cellTypes = (data['cellTypes'] as List)
        .map((row) => List<int>.from(row as List))
        .toList();
    final difficulty = NumberSumsDifficulty.values[data['difficulty'] as int];

    final wrongCellsData = data['wrongCells'] as List;
    final wrongCells = wrongCellsData
        .map((row) => (row as List).map((v) => v == 1).toList())
        .toList();

    final rowSums = List<int>.from(data['rowSums'] as List);
    final colSums = List<int>.from(data['colSums'] as List);

    final blockIds = (data['blockIds'] as List)
        .map((row) => List<int>.from(row as List))
        .toList();
    final blockSums = List<int>.from(data['blockSums'] as List);

    final currentBoard = puzzle.map((row) => List<int>.from(row)).toList();

    // 정답 표시 셀 초기화
    final markedCorrectCells = List.generate(
      gridSize,
      (_) => List.generate(gridSize, (_) => false),
    );

    return NumberSumsGameState(
      solution: solution,
      puzzle: puzzle,
      currentBoard: currentBoard,
      cellTypes: cellTypes,
      wrongCells: wrongCells,
      markedCorrectCells: markedCorrectCells,
      rowSums: rowSums,
      colSums: colSums,
      blockIds: blockIds,
      blockSums: blockSums,
      gridSize: gridSize,
      gameSize: gameSize,
      difficulty: difficulty,
    );
  }

  NumberSumsGameState copyWith({
    List<List<int>>? solution,
    List<List<int>>? puzzle,
    List<List<int>>? currentBoard,
    List<List<int>>? cellTypes,
    List<List<bool>>? wrongCells,
    List<List<bool>>? markedCorrectCells,
    List<int>? rowSums,
    List<int>? colSums,
    List<List<int>>? blockIds,
    List<int>? blockSums,
    int? gridSize,
    int? gameSize,
    NumberSumsDifficulty? difficulty,
    int? selectedRow,
    int? selectedCol,
    int? mistakes,
    bool? isCompleted,
    int? elapsedSeconds,
    int? failureCount,
    bool clearSelection = false,
  }) {
    return NumberSumsGameState(
      solution: solution ?? this.solution,
      puzzle: puzzle ?? this.puzzle,
      currentBoard: currentBoard ?? this.currentBoard,
      cellTypes: cellTypes ?? this.cellTypes,
      wrongCells: wrongCells ?? this.wrongCells,
      markedCorrectCells: markedCorrectCells ?? this.markedCorrectCells,
      rowSums: rowSums ?? this.rowSums,
      colSums: colSums ?? this.colSums,
      blockIds: blockIds ?? this.blockIds,
      blockSums: blockSums ?? this.blockSums,
      gridSize: gridSize ?? this.gridSize,
      gameSize: gameSize ?? this.gameSize,
      difficulty: difficulty ?? this.difficulty,
      selectedRow: clearSelection ? null : (selectedRow ?? this.selectedRow),
      selectedCol: clearSelection ? null : (selectedCol ?? this.selectedCol),
      mistakes: mistakes ?? this.mistakes,
      isCompleted: isCompleted ?? this.isCompleted,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      failureCount: failureCount ?? this.failureCount,
      undoHistory: _undoHistory,
    );
  }

  bool isInputCell(int row, int col) {
    return cellTypes[row][col] == 1;
  }

  bool isWrongCell(int row, int col) {
    return wrongCells[row][col];
  }

  bool isMarkedCorrect(int row, int col) {
    return markedCorrectCells[row][col];
  }

  void saveToUndoHistory(int row, int col) {
    final action = NumberSumsUndoAction(
      row: row,
      col: col,
      previousValue: currentBoard[row][col],
    );
    _undoHistory.add(action);
    if (_undoHistory.length > maxUndoCount) {
      _undoHistory.removeAt(0);
    }
  }

  NumberSumsUndoAction? popFromUndoHistory() {
    if (_undoHistory.isEmpty) return null;

    final action = _undoHistory.removeLast();
    currentBoard[action.row][action.col] = action.previousValue;
    return action;
  }

  bool get canUndo => _undoHistory.isNotEmpty;

  bool get hasSelection => selectedRow != null && selectedCol != null;

  bool isSelected(int row, int col) {
    return selectedRow == row && selectedCol == col;
  }

  /// 남은 틀린 숫자 개수
  int get remainingWrongCount {
    int count = 0;
    for (int row = 1; row < gridSize; row++) {
      for (int col = 1; col < gridSize; col++) {
        if (wrongCells[row][col] && currentBoard[row][col] != 0) {
          count++;
        }
      }
    }
    return count;
  }

  /// 현재 보드 기준 행의 합계 (선택한 올바른 수의 합)
  int getCurrentRowSum(int row) {
    int sum = 0;
    for (int col = 1; col < gridSize; col++) {
      // 올바른 수이고 정답 처리된 경우만 합산
      // solution 값을 사용하여 정확한 정답 값만 계산
      if (!wrongCells[row][col] && markedCorrectCells[row][col]) {
        sum += solution[row][col];
      }
    }
    return sum;
  }

  /// 현재 보드 기준 열의 합계 (선택한 올바른 수의 합)
  int getCurrentColSum(int col) {
    int sum = 0;
    for (int row = 1; row < gridSize; row++) {
      // 올바른 수이고 정답 처리된 경우만 합산
      // solution 값을 사용하여 정확한 정답 값만 계산
      if (!wrongCells[row][col] && markedCorrectCells[row][col]) {
        sum += solution[row][col];
      }
    }
    return sum;
  }

  /// 행의 모든 셀이 결정되었는지 확인
  bool isRowComplete(int row) {
    for (int col = 1; col < gridSize; col++) {
      bool isCorrectCell = !wrongCells[row][col];
      bool isWrongCell = wrongCells[row][col];

      if (isCorrectCell && !markedCorrectCells[row][col]) {
        return false;
      }
      if (isWrongCell && currentBoard[row][col] != 0) {
        return false;
      }
    }
    return true;
  }

  /// 열의 모든 셀이 결정되었는지 확인
  bool isColComplete(int col) {
    for (int row = 1; row < gridSize; row++) {
      bool isCorrectCell = !wrongCells[row][col];
      bool isWrongCell = wrongCells[row][col];

      if (isCorrectCell && !markedCorrectCells[row][col]) {
        return false;
      }
      if (isWrongCell && currentBoard[row][col] != 0) {
        return false;
      }
    }
    return true;
  }

  /// 셀의 블록 ID 가져오기
  int getBlockId(int row, int col) {
    if (row < 1 || row >= gridSize || col < 1 || col >= gridSize) {
      return -1;
    }
    return blockIds[row][col];
  }

  /// 블록의 현재 합계 (올바른 수 중 아직 정답 처리 안 된 것만)
  int getCurrentBlockSum(int blockId) {
    if (blockId < 0 || blockId >= blockSums.length) return 0;

    int sum = 0;
    for (int row = 1; row < gridSize; row++) {
      for (int col = 1; col < gridSize; col++) {
        // 블록에 속하고, 올바른 수이고, 아직 마킹되지 않은 경우만
        // solution 값을 사용하여 정확한 정답 값만 계산
        if (blockIds[row][col] == blockId &&
            !wrongCells[row][col] &&
            !markedCorrectCells[row][col]) {
          sum += solution[row][col];
        }
      }
    }
    return sum;
  }

  /// 블록의 모든 셀이 결정되었는지 확인
  /// (정답 셀은 마킹됨, 틀린 셀은 제거됨)
  bool isBlockComplete(int blockId) {
    if (blockId < 0 || blockId >= blockSums.length) return false;

    for (int row = 1; row < gridSize; row++) {
      for (int col = 1; col < gridSize; col++) {
        if (blockIds[row][col] == blockId) {
          // 이 셀이 결정되지 않았는지 확인
          bool isCorrectCell = !wrongCells[row][col];
          bool isWrongCell = wrongCells[row][col];

          if (isCorrectCell && !markedCorrectCells[row][col]) {
            // 정답 셀인데 아직 마킹되지 않음
            return false;
          }
          if (isWrongCell && currentBoard[row][col] != 0) {
            // 틀린 셀인데 아직 제거되지 않음
            return false;
          }
        }
      }
    }
    return true;
  }

  /// 셀의 블록 색상 가져오기 (모든 셀이 결정되면 배경색 제거)
  int? getBlockColor(int row, int col) {
    final blockId = getBlockId(row, col);
    if (blockId < 0) return null;

    // 블록의 모든 셀이 결정되면 배경색 없음 (흰색)
    if (isBlockComplete(blockId)) return null;

    return blockColors[blockId % blockColors.length];
  }

  /// 블록의 첫 번째 셀인지 확인 (합계 표시용)
  bool isBlockFirstCell(int row, int col) {
    final blockId = getBlockId(row, col);
    if (blockId < 0) return false;

    // 블록에서 가장 위-왼쪽 셀 찾기
    for (int r = 1; r < gridSize; r++) {
      for (int c = 1; c < gridSize; c++) {
        if (blockIds[r][c] == blockId) {
          return r == row && c == col;
        }
      }
    }
    return false;
  }

  /// 보드가 완성되었는지 확인 (모든 셀이 결정되어야 함)
  bool checkCompletion() {
    for (int row = 1; row < gridSize; row++) {
      for (int col = 1; col < gridSize; col++) {
        bool isCorrectCell = !wrongCells[row][col];
        bool isWrongCell = wrongCells[row][col];

        // 정답 셀인데 아직 마킹되지 않음
        if (isCorrectCell && !markedCorrectCells[row][col]) {
          return false;
        }
        // 틀린 셀인데 아직 제거되지 않음
        if (isWrongCell && currentBoard[row][col] != 0) {
          return false;
        }
      }
    }
    return true;
  }
}
