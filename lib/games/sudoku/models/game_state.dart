import 'sudoku_generator.dart';

enum Difficulty { easy, medium, hard, expert }

/// Isolate에서 실행할 퍼즐 생성 함수 (top-level 함수)
Map<String, dynamic> generatePuzzleInIsolate(Difficulty difficulty) {
  final generator = SudokuGenerator();
  final solution = generator.generateSolvedBoard();

  int emptyCells;
  switch (difficulty) {
    case Difficulty.easy:
      emptyCells = 30;
      break;
    case Difficulty.medium:
      emptyCells = 45;
      break;
    case Difficulty.hard:
      emptyCells = 60;
      break;
    case Difficulty.expert:
      emptyCells = 70;
      break;
  }

  final puzzle = generator.generatePuzzle(solution, emptyCells);

  return {
    'solution': solution,
    'puzzle': puzzle,
    'difficulty': difficulty.index,
  };
}

/// Undo를 위한 동작 기록
class UndoAction {
  final int row;
  final int col;
  final int previousValue;
  final Set<int> previousNotes;
  // 영향받는 관련 셀들의 메모 상태 (행/열/박스 내 셀들)
  final Map<String, Set<int>> affectedCellsNotes;

  UndoAction({
    required this.row,
    required this.col,
    required this.previousValue,
    required this.previousNotes,
    this.affectedCellsNotes = const {},
  });

  /// 셀 키 생성 (row_col 형식)
  static String cellKey(int row, int col) => '${row}_$col';

  /// 셀 키에서 row, col 추출
  static (int, int) parseKey(String key) {
    final parts = key.split('_');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }
}

class GameState {
  final List<List<int>> solution;
  final List<List<int>> puzzle;
  final List<List<int>> currentBoard;
  final List<List<bool>> isFixed;
  final List<List<Set<int>>> notes; // 메모 기능
  final Difficulty difficulty;
  int? selectedRow;
  int? selectedCol;
  int? quickInputNumber; // 빠른 입력 모드에서 선택된 숫자
  int mistakes;
  bool isCompleted;
  // 게임 통계
  int elapsedSeconds;
  int failureCount;
  // Undo 히스토리 (최대 10개)
  final List<UndoAction> _undoHistory = [];
  static const int maxUndoCount = 10;

  GameState({
    required this.solution,
    required this.puzzle,
    required this.currentBoard,
    required this.isFixed,
    required this.notes,
    required this.difficulty,
    this.selectedRow,
    this.selectedCol,
    this.quickInputNumber,
    this.mistakes = 0,
    this.isCompleted = false,
    this.elapsedSeconds = 0,
    this.failureCount = 0,
  });

  /// 동기적으로 새 게임 생성 (메인 스레드에서 실행, UI 블로킹 가능)
  factory GameState.newGame(Difficulty difficulty) {
    final data = generatePuzzleInIsolate(difficulty);
    return GameState.fromGeneratedData(data);
  }

  /// 생성된 데이터로부터 GameState 생성 (isolate에서 생성된 데이터 사용)
  factory GameState.fromGeneratedData(Map<String, dynamic> data) {
    final solution = (data['solution'] as List)
        .map((row) => List<int>.from(row as List))
        .toList();
    final puzzle = (data['puzzle'] as List)
        .map((row) => List<int>.from(row as List))
        .toList();
    final difficulty = Difficulty.values[data['difficulty'] as int];

    final currentBoard = puzzle.map((row) => List<int>.from(row)).toList();
    final isFixed = puzzle
        .map((row) => row.map((cell) => cell != 0).toList())
        .toList();
    // 메모 초기화: 9x9 각각 빈 Set
    final notes = List.generate(
      9,
      (_) => List.generate(9, (_) => <int>{}),
    );

    return GameState(
      solution: solution,
      puzzle: puzzle,
      currentBoard: currentBoard,
      isFixed: isFixed,
      notes: notes,
      difficulty: difficulty,
    );
  }

  GameState copyWith({
    List<List<int>>? solution,
    List<List<int>>? puzzle,
    List<List<int>>? currentBoard,
    List<List<bool>>? isFixed,
    List<List<Set<int>>>? notes,
    Difficulty? difficulty,
    int? selectedRow,
    int? selectedCol,
    int? quickInputNumber,
    int? mistakes,
    bool? isCompleted,
    int? elapsedSeconds,
    int? failureCount,
    bool clearSelection = false,
    bool clearQuickInput = false,
  }) {
    return GameState(
      solution: solution ?? this.solution,
      puzzle: puzzle ?? this.puzzle,
      currentBoard: currentBoard ?? this.currentBoard,
      isFixed: isFixed ?? this.isFixed,
      notes: notes ?? this.notes,
      difficulty: difficulty ?? this.difficulty,
      selectedRow: clearSelection ? null : (selectedRow ?? this.selectedRow),
      selectedCol: clearSelection ? null : (selectedCol ?? this.selectedCol),
      quickInputNumber: clearQuickInput ? null : (quickInputNumber ?? this.quickInputNumber),
      mistakes: mistakes ?? this.mistakes,
      isCompleted: isCompleted ?? this.isCompleted,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      failureCount: failureCount ?? this.failureCount,
    );
  }

  /// 메모 토글
  void toggleNote(int row, int col, int number) {
    if (currentBoard[row][col] != 0) return;
    if (isFixed[row][col]) return;

    if (notes[row][col].contains(number)) {
      notes[row][col].remove(number);
    } else {
      notes[row][col].add(number);
    }
  }

  /// 같은 행/열/박스의 메모에서 해당 숫자 삭제
  void removeNumberFromRelatedNotes(int row, int col, int number) {
    // 같은 행의 메모에서 삭제
    for (int c = 0; c < 9; c++) {
      if (c != col) {
        notes[row][c].remove(number);
      }
    }

    // 같은 열의 메모에서 삭제
    for (int r = 0; r < 9; r++) {
      if (r != row) {
        notes[r][col].remove(number);
      }
    }

    // 같은 3x3 박스의 메모에서 삭제
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        int targetRow = boxRow + r;
        int targetCol = boxCol + c;
        if (targetRow != row || targetCol != col) {
          notes[targetRow][targetCol].remove(number);
        }
      }
    }
  }

  /// 셀의 메모 지우기
  void clearNotes(int row, int col) {
    notes[row][col].clear();
  }

  /// 현재 상태를 Undo 히스토리에 저장 (관련 셀 메모 포함)
  void saveToUndoHistory(int row, int col, {int? numberToInput}) {
    // 영향받는 관련 셀들의 메모 상태 저장
    Map<String, Set<int>> affectedNotes = {};

    // numberToInput이 주어진 경우, 해당 숫자가 영향을 미칠 관련 셀들의 메모 저장
    if (numberToInput != null && numberToInput != 0) {
      // 같은 행
      for (int c = 0; c < 9; c++) {
        if (c != col && notes[row][c].contains(numberToInput)) {
          affectedNotes[UndoAction.cellKey(row, c)] = Set<int>.from(notes[row][c]);
        }
      }
      // 같은 열
      for (int r = 0; r < 9; r++) {
        if (r != row && notes[r][col].contains(numberToInput)) {
          affectedNotes[UndoAction.cellKey(r, col)] = Set<int>.from(notes[r][col]);
        }
      }
      // 같은 3x3 박스
      int boxRow = (row ~/ 3) * 3;
      int boxCol = (col ~/ 3) * 3;
      for (int r = boxRow; r < boxRow + 3; r++) {
        for (int c = boxCol; c < boxCol + 3; c++) {
          if ((r != row || c != col) && notes[r][c].contains(numberToInput)) {
            affectedNotes[UndoAction.cellKey(r, c)] = Set<int>.from(notes[r][c]);
          }
        }
      }
    }

    final action = UndoAction(
      row: row,
      col: col,
      previousValue: currentBoard[row][col],
      previousNotes: Set<int>.from(notes[row][col]),
      affectedCellsNotes: affectedNotes,
    );
    _undoHistory.add(action);
    // 최대 개수 초과 시 가장 오래된 것 제거
    if (_undoHistory.length > maxUndoCount) {
      _undoHistory.removeAt(0);
    }
  }

  /// Undo 실행 - 이전 상태로 복원
  bool undo() {
    if (_undoHistory.isEmpty) return false;

    final action = _undoHistory.removeLast();
    currentBoard[action.row][action.col] = action.previousValue;
    notes[action.row][action.col] = Set<int>.from(action.previousNotes);

    // 영향받았던 관련 셀들의 메모도 복원
    for (final entry in action.affectedCellsNotes.entries) {
      final (r, c) = UndoAction.parseKey(entry.key);
      notes[r][c] = Set<int>.from(entry.value);
    }
    return true;
  }

  /// Undo 가능 여부
  bool get canUndo => _undoHistory.isNotEmpty;

  /// Undo 히스토리 개수
  int get undoCount => _undoHistory.length;

  /// Undo 히스토리 초기화
  void clearUndoHistory() {
    _undoHistory.clear();
  }

  /// 모든 빈 셀에 메모 자동 채우기
  void fillAllNotes() {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        // 빈 셀(값이 0)에만 메모 적용
        if (currentBoard[row][col] == 0) {
          // 새로운 Set 생성하여 유효한 숫자 추가
          final Set<int> newNotes = <int>{};
          for (int num = 1; num <= 9; num++) {
            if (SudokuGenerator.isValidMove(currentBoard, row, col, num)) {
              newNotes.add(num);
            }
          }
          // 무조건 새 Set으로 교체 (기존 메모 무시)
          notes[row][col] = newNotes;
        }
      }
    }
  }

  bool get isQuickInputMode => quickInputNumber != null;

  bool get hasSelection => selectedRow != null && selectedCol != null;

  int? get selectedValue {
    if (!hasSelection) return null;
    return currentBoard[selectedRow!][selectedCol!];
  }

  bool isSelected(int row, int col) {
    return selectedRow == row && selectedCol == col;
  }

  bool isSameRowOrCol(int row, int col) {
    if (!hasSelection) return false;
    return selectedRow == row || selectedCol == col;
  }

  bool isSameBox(int row, int col) {
    if (!hasSelection) return false;
    int selectedBoxRow = (selectedRow! ~/ 3) * 3;
    int selectedBoxCol = (selectedCol! ~/ 3) * 3;
    int cellBoxRow = (row ~/ 3) * 3;
    int cellBoxCol = (col ~/ 3) * 3;
    return selectedBoxRow == cellBoxRow && selectedBoxCol == cellBoxCol;
  }

  bool isSameValue(int row, int col) {
    if (!hasSelection) return false;
    int cellValue = currentBoard[row][col];
    return cellValue != 0 && cellValue == selectedValue;
  }

  bool hasError(int row, int col) {
    int value = currentBoard[row][col];
    if (value == 0) return false;
    // solution과 비교하여 오류 체크
    return value != solution[row][col];
  }

  /// 각 숫자가 보드에서 몇 번 사용되었는지 카운트
  Map<int, int> getNumberCounts() {
    final counts = <int, int>{};
    for (int num = 1; num <= 9; num++) {
      counts[num] = 0;
    }
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        int value = currentBoard[row][col];
        if (value != 0) {
          counts[value] = (counts[value] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  /// 모두 올바르게 채워진 숫자들 (정답과 비교하여 9개 모두 맞은 숫자)
  Set<int> getCompletedNumbers() {
    Set<int> completed = {};
    for (int num = 1; num <= 9; num++) {
      bool allCorrect = true;
      for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
          if (solution[row][col] == num) {
            // 이 위치에 정답이 num인데, 현재 보드에 num이 아니면 완료 아님
            if (currentBoard[row][col] != num) {
              allCorrect = false;
              break;
            }
          }
        }
        if (!allCorrect) break;
      }
      if (allCorrect) {
        completed.add(num);
      }
    }
    return completed;
  }
}
