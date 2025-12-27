import 'killer_cage.dart';
import 'killer_sudoku_generator.dart';

/// Isolate에서 실행할 퍼즐 생성 함수 (top-level 함수)
Map<String, dynamic> generateKillerPuzzleInIsolate(KillerDifficulty difficulty) {
  final generator = KillerSudokuGenerator();
  final result = generator.generatePuzzle(difficulty);
  return {
    'solution': result['solution'],
    'puzzle': result['puzzle'],
    'cages': (result['cages'] as List<KillerCage>).map((c) => c.toJson()).toList(),
    'difficulty': difficulty.index,
  };
}

/// Undo를 위한 동작 기록
class KillerUndoAction {
  final int row;
  final int col;
  final int previousValue;
  final Set<int> previousNotes;
  final Map<String, Set<int>> affectedCellsNotes;

  KillerUndoAction({
    required this.row,
    required this.col,
    required this.previousValue,
    required this.previousNotes,
    this.affectedCellsNotes = const {},
  });

  static String cellKey(int row, int col) => '${row}_$col';

  static (int, int) parseKey(String key) {
    final parts = key.split('_');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }
}

class KillerGameState {
  final List<List<int>> solution;
  final List<List<int>> puzzle;
  final List<List<int>> currentBoard;
  final List<List<bool>> isFixed;
  final List<List<Set<int>>> notes;
  final List<KillerCage> cages;
  final KillerDifficulty difficulty;
  int? selectedRow;
  int? selectedCol;
  int? quickInputNumber;
  int mistakes;
  bool isCompleted;
  int elapsedSeconds;
  int failureCount;
  final List<KillerUndoAction> _undoHistory;
  static const int maxUndoCount = 10;

  KillerGameState({
    required this.solution,
    required this.puzzle,
    required this.currentBoard,
    required this.isFixed,
    required this.notes,
    required this.cages,
    required this.difficulty,
    this.selectedRow,
    this.selectedCol,
    this.quickInputNumber,
    this.mistakes = 0,
    this.isCompleted = false,
    this.elapsedSeconds = 0,
    this.failureCount = 0,
    List<KillerUndoAction>? undoHistory,
  }) : _undoHistory = undoHistory ?? [];

  /// 생성된 데이터로부터 GameState 생성
  factory KillerGameState.fromGeneratedData(Map<String, dynamic> data) {
    final solution = (data['solution'] as List)
        .map((row) => List<int>.from(row as List))
        .toList();
    final puzzle = (data['puzzle'] as List)
        .map((row) => List<int>.from(row as List))
        .toList();
    final cages = (data['cages'] as List)
        .map((c) => KillerCage.fromJson(c as Map<String, dynamic>))
        .toList();
    final difficulty = KillerDifficulty.values[data['difficulty'] as int];

    final currentBoard = puzzle.map((row) => List<int>.from(row)).toList();
    final isFixed =
        puzzle.map((row) => row.map((cell) => cell != 0).toList()).toList();
    final notes = List.generate(
      9,
      (_) => List.generate(9, (_) => <int>{}),
    );

    return KillerGameState(
      solution: solution,
      puzzle: puzzle,
      currentBoard: currentBoard,
      isFixed: isFixed,
      notes: notes,
      cages: cages,
      difficulty: difficulty,
    );
  }

  KillerGameState copyWith({
    List<List<int>>? solution,
    List<List<int>>? puzzle,
    List<List<int>>? currentBoard,
    List<List<bool>>? isFixed,
    List<List<Set<int>>>? notes,
    List<KillerCage>? cages,
    KillerDifficulty? difficulty,
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
    return KillerGameState(
      solution: solution ?? this.solution,
      puzzle: puzzle ?? this.puzzle,
      currentBoard: currentBoard ?? this.currentBoard,
      isFixed: isFixed ?? this.isFixed,
      notes: notes ?? this.notes,
      cages: cages ?? this.cages,
      difficulty: difficulty ?? this.difficulty,
      selectedRow: clearSelection ? null : (selectedRow ?? this.selectedRow),
      selectedCol: clearSelection ? null : (selectedCol ?? this.selectedCol),
      quickInputNumber:
          clearQuickInput ? null : (quickInputNumber ?? this.quickInputNumber),
      mistakes: mistakes ?? this.mistakes,
      isCompleted: isCompleted ?? this.isCompleted,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      failureCount: failureCount ?? this.failureCount,
      undoHistory: _undoHistory,
    );
  }

  /// Get cage containing a specific cell
  KillerCage? getCageForCell(int row, int col) {
    for (var cage in cages) {
      if (cage.containsCell(row, col)) return cage;
    }
    return null;
  }

  /// Check if cage has error (duplicate or sum exceeded)
  bool hasCageError(KillerCage cage) {
    final values = <int>[];
    int sum = 0;
    bool hasEmpty = false;

    for (var cell in cage.cells) {
      int value = currentBoard[cell[0]][cell[1]];
      if (value == 0) {
        hasEmpty = true;
      } else {
        if (values.contains(value)) return true; // Duplicate in cage
        values.add(value);
        sum += value;
      }
    }

    if (!hasEmpty && sum != cage.targetSum) return true; // Wrong sum
    if (sum > cage.targetSum) return true; // Sum exceeded
    return false;
  }

  /// Check if specific cell has cage-related error
  bool hasCellCageError(int row, int col) {
    final cage = getCageForCell(row, col);
    if (cage == null) return false;
    return hasCageError(cage);
  }

  /// Extended error check including standard Sudoku + cage rules + solution check
  bool hasError(int row, int col) {
    int value = currentBoard[row][col];
    if (value == 0) return false;

    // Check if value matches solution (wrong answer)
    if (value != solution[row][col]) {
      return true;
    }

    // Standard Sudoku validation
    if (!KillerSudokuGenerator.isValidMove(currentBoard, row, col, value)) {
      return true;
    }

    // Cage validation - check for duplicates within cage
    final cage = getCageForCell(row, col);
    if (cage != null) {
      for (var cell in cage.cells) {
        if (cell[0] != row || cell[1] != col) {
          if (currentBoard[cell[0]][cell[1]] == value) {
            return true; // Duplicate in cage
          }
        }
      }
    }

    return false;
  }

  /// Check if same cage as selected cell
  bool isSameCage(int row, int col) {
    if (selectedRow == null || selectedCol == null) return false;
    final selectedCage = getCageForCell(selectedRow!, selectedCol!);
    if (selectedCage == null) return false;
    return selectedCage.containsCell(row, col);
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

  /// 같은 행/열/박스/케이지의 메모에서 해당 숫자 삭제
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

    // 같은 케이지의 메모에서 삭제
    final cage = getCageForCell(row, col);
    if (cage != null) {
      for (var cell in cage.cells) {
        if (cell[0] != row || cell[1] != col) {
          notes[cell[0]][cell[1]].remove(number);
        }
      }
    }
  }

  /// 셀의 메모 지우기
  void clearNotes(int row, int col) {
    notes[row][col].clear();
  }

  /// 현재 상태를 Undo 히스토리에 저장
  void saveToUndoHistory(int row, int col, {int? numberToInput}) {
    Map<String, Set<int>> affectedNotes = {};

    if (numberToInput != null && numberToInput != 0) {
      // 같은 행
      for (int c = 0; c < 9; c++) {
        if (c != col && notes[row][c].contains(numberToInput)) {
          affectedNotes[KillerUndoAction.cellKey(row, c)] =
              Set<int>.from(notes[row][c]);
        }
      }
      // 같은 열
      for (int r = 0; r < 9; r++) {
        if (r != row && notes[r][col].contains(numberToInput)) {
          affectedNotes[KillerUndoAction.cellKey(r, col)] =
              Set<int>.from(notes[r][col]);
        }
      }
      // 같은 3x3 박스
      int boxRow = (row ~/ 3) * 3;
      int boxCol = (col ~/ 3) * 3;
      for (int r = boxRow; r < boxRow + 3; r++) {
        for (int c = boxCol; c < boxCol + 3; c++) {
          if ((r != row || c != col) && notes[r][c].contains(numberToInput)) {
            affectedNotes[KillerUndoAction.cellKey(r, c)] =
                Set<int>.from(notes[r][c]);
          }
        }
      }
      // 같은 케이지
      final cage = getCageForCell(row, col);
      if (cage != null) {
        for (var cell in cage.cells) {
          if ((cell[0] != row || cell[1] != col) &&
              notes[cell[0]][cell[1]].contains(numberToInput)) {
            affectedNotes[KillerUndoAction.cellKey(cell[0], cell[1])] =
                Set<int>.from(notes[cell[0]][cell[1]]);
          }
        }
      }
    }

    final action = KillerUndoAction(
      row: row,
      col: col,
      previousValue: currentBoard[row][col],
      previousNotes: Set<int>.from(notes[row][col]),
      affectedCellsNotes: affectedNotes,
    );
    _undoHistory.add(action);
    if (_undoHistory.length > maxUndoCount) {
      _undoHistory.removeAt(0);
    }
  }

  /// Undo 실행
  bool undo() {
    if (_undoHistory.isEmpty) return false;

    final action = _undoHistory.removeLast();
    currentBoard[action.row][action.col] = action.previousValue;
    notes[action.row][action.col] = Set<int>.from(action.previousNotes);

    for (final entry in action.affectedCellsNotes.entries) {
      final (r, c) = KillerUndoAction.parseKey(entry.key);
      notes[r][c] = Set<int>.from(entry.value);
    }
    return true;
  }

  bool get canUndo => _undoHistory.isNotEmpty;
  int get undoCount => _undoHistory.length;

  void clearUndoHistory() {
    _undoHistory.clear();
  }

  /// 모든 빈 셀에 메모 자동 채우기 (케이지 규칙 포함)
  void fillAllNotes() {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (currentBoard[row][col] == 0) {
          final Set<int> newNotes = <int>{};
          for (int num = 1; num <= 9; num++) {
            if (_isValidCandidate(row, col, num)) {
              newNotes.add(num);
            }
          }
          notes[row][col] = newNotes;
        }
      }
    }
  }

  /// Check if a number is a valid candidate (Sudoku rules + cage rules)
  bool _isValidCandidate(int row, int col, int num) {
    // Standard Sudoku check
    if (!KillerSudokuGenerator.isValidMove(currentBoard, row, col, num)) {
      return false;
    }

    // Cage duplicate check
    final cage = getCageForCell(row, col);
    if (cage != null) {
      for (var cell in cage.cells) {
        if (cell[0] != row || cell[1] != col) {
          if (currentBoard[cell[0]][cell[1]] == num) {
            return false;
          }
        }
      }
    }

    return true;
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
