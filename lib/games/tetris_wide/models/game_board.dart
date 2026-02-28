import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'piece.dart';

class GameBoard extends ChangeNotifier {
  final int rows;
  static const int cols = 20;
  static const String _speedKey = 'tetris_wide_speed';

  late List<List<Color?>> board;

  Piece? currentPiece;
  Piece? nextPiece;
  int score = 0;
  int level = 1;
  int linesCleared = 0;
  bool isGameOver = false;
  bool isLevelComplete = false;
  bool isPaused = false;
  int speed = 300;
  int speedBoost = 0;
  int currentFillRows = 0;
  Timer? _gameTimer;

  final Random _random = Random();

  /// 실제 적용 속도 (설정 속도 - 부스트)
  int get activeSpeed => (speed - speedBoost * 20).clamp(50, 999);

  GameBoard({this.rows = 20}) {
    board = List.generate(
      rows,
      (_) => List.generate(cols, (_) => null),
    );
    _loadSpeed();
    _initGame();
  }

  Future<void> _loadSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    speed = prefs.getInt(_speedKey) ?? 300;
    notifyListeners();
  }

  Future<void> _saveSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_speedKey, speed);
  }

  void setSpeed(int newSpeed) {
    speed = newSpeed;
    _saveSpeed();
    notifyListeners();
  }

  List<ClearedCell> lastClearedCells = [];
  List<FallingCell> lastFallingCells = [];

  void _initGame() {
    board = List.generate(
      rows,
      (_) => List.generate(cols, (_) => null),
    );
    score = 0;
    level = 1;
    linesCleared = 0;
    isGameOver = false;
    isLevelComplete = false;
    isPaused = false;
    speedBoost = 0;
    currentFillRows = rows ~/ 3;
    _fillInitialBlocks();
    currentPiece = _generateRandomPiece();
    nextPiece = _generateRandomPiece();
  }

  void _fillInitialBlocks() {
    final fillRows = currentFillRows.clamp(1, rows - 4);
    final startRow = rows - fillRows;
    for (int row = startRow; row < rows; row++) {
      final minFill = (cols * 0.5).round();
      final maxFill = (cols * 0.75).round();
      final fillCount = minFill + _random.nextInt(maxFill - minFill + 1);
      final positions = List.generate(cols, (i) => i)..shuffle(_random);
      for (int i = 0; i < fillCount; i++) {
        board[row][positions[i]] = Piece.blockColor;
      }
      bool isFull = board[row].every((c) => c != null);
      if (isFull) {
        board[row][_random.nextInt(cols)] = null;
      }
    }
  }

  void startGame() {
    _initGame();
    _startTimer();
    notifyListeners();
  }

  void nextLevel() {
    level++;
    isLevelComplete = false;

    // 다음 레벨 채울 줄 수 계산
    currentFillRows += 2;
    final maxFill = (rows * 2) ~/ 3;
    if (currentFillRows > maxFill) {
      // 2/3 초과 시 1/3로 리셋, 속도 20ms 빠르게
      currentFillRows = rows ~/ 3;
      speedBoost++;
    }

    board = List.generate(
      rows,
      (_) => List.generate(cols, (_) => null),
    );
    _fillInitialBlocks();
    currentPiece = _generateRandomPiece();
    nextPiece = _generateRandomPiece();
    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(Duration(milliseconds: activeSpeed), (_) {
      if (!isPaused && !isGameOver && !isLevelComplete) {
        moveDown();
      }
    });
  }

  void pauseGame() {
    isPaused = !isPaused;
    notifyListeners();
  }

  Piece _generateRandomPiece() {
    PieceType type = PieceType.values[_random.nextInt(PieceType.values.length)];
    return Piece(type: type);
  }

  bool _isValidPosition(Piece piece) {
    for (var cell in piece.cells) {
      int row = cell[0];
      int col = cell[1];

      if (row < 0 || row >= rows || col < 0 || col >= cols) {
        return false;
      }

      if (board[row][col] != null) {
        return false;
      }
    }
    return true;
  }

  void moveLeft() {
    if (currentPiece == null || isGameOver || isPaused || isLevelComplete) return;

    currentPiece!.x--;
    if (!_isValidPosition(currentPiece!)) {
      currentPiece!.x++;
    }
    notifyListeners();
  }

  void moveRight() {
    if (currentPiece == null || isGameOver || isPaused || isLevelComplete) return;

    currentPiece!.x++;
    if (!_isValidPosition(currentPiece!)) {
      currentPiece!.x--;
    }
    notifyListeners();
  }

  void moveDown() {
    if (currentPiece == null || isGameOver || isPaused || isLevelComplete) return;

    currentPiece!.y++;
    if (!_isValidPosition(currentPiece!)) {
      currentPiece!.y--;
      _placePiece();
    }
    notifyListeners();
  }

  void hardDrop() {
    if (currentPiece == null || isGameOver || isPaused || isLevelComplete) return;

    while (_isValidPosition(currentPiece!)) {
      currentPiece!.y++;
    }
    currentPiece!.y--;
    _placePiece();
    notifyListeners();
  }

  void rotate() {
    if (currentPiece == null || isGameOver || isPaused || isLevelComplete) return;

    currentPiece!.rotate();
    if (!_isValidPosition(currentPiece!)) {
      int originalX = currentPiece!.x;

      currentPiece!.x--;
      if (_isValidPosition(currentPiece!)) {
        notifyListeners();
        return;
      }

      currentPiece!.x = originalX + 1;
      if (_isValidPosition(currentPiece!)) {
        notifyListeners();
        return;
      }

      currentPiece!.x = originalX - 2;
      if (_isValidPosition(currentPiece!)) {
        notifyListeners();
        return;
      }

      currentPiece!.x = originalX + 2;
      if (_isValidPosition(currentPiece!)) {
        notifyListeners();
        return;
      }

      currentPiece!.x = originalX;
      currentPiece!.rotateBack();
    }
    notifyListeners();
  }

  void rotateLeft() {
    if (currentPiece == null || isGameOver || isPaused || isLevelComplete) return;

    currentPiece!.rotateBack();
    if (!_isValidPosition(currentPiece!)) {
      int originalX = currentPiece!.x;

      currentPiece!.x--;
      if (_isValidPosition(currentPiece!)) {
        notifyListeners();
        return;
      }

      currentPiece!.x = originalX + 1;
      if (_isValidPosition(currentPiece!)) {
        notifyListeners();
        return;
      }

      currentPiece!.x = originalX - 2;
      if (_isValidPosition(currentPiece!)) {
        notifyListeners();
        return;
      }

      currentPiece!.x = originalX + 2;
      if (_isValidPosition(currentPiece!)) {
        notifyListeners();
        return;
      }

      currentPiece!.x = originalX;
      currentPiece!.rotate();
    }
    notifyListeners();
  }

  void _placePiece() {
    if (currentPiece == null) return;

    Set<int> affectedCols = {};
    for (var cell in currentPiece!.cells) {
      int row = cell[0];
      int col = cell[1];
      if (row >= 0 && row < rows && col >= 0 && col < cols) {
        board[row][col] = Piece.newBlockColor;
        affectedCols.add(col);
      }
    }

    _clearLines(affectedCols);

    // 남은 줄이 1줄 이하면 레벨 클리어
    if (remainingRows <= 1) {
      isLevelComplete = true;
      _gameTimer?.cancel();
      notifyListeners();
      return;
    }

    currentPiece = nextPiece;
    nextPiece = _generateRandomPiece();

    if (!_isValidPosition(currentPiece!)) {
      isGameOver = true;
      _gameTimer?.cancel();
    }

    notifyListeners();
  }

  /// 블록이 존재하는 줄 수
  int get remainingRows {
    int count = 0;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (board[row][col] != null) {
          count++;
          break;
        }
      }
    }
    return count;
  }

  void _clearLines(Set<int> affectedCols) {
    lastClearedCells = [];
    lastFallingCells = [];

    // 클리어 전 신규 셀 위치 기록 (원래 좌표계, 꽉 찬 줄 제외)
    final Set<int> initialFullRows = {};
    for (int row = 0; row < rows; row++) {
      if (board[row].every((c) => c != null)) {
        initialFullRows.add(row);
      }
    }

    final Map<int, List<int>> newCellsBefore = {}; // col → rows (아래→위)
    for (int col in affectedCols) {
      for (int row = rows - 1; row >= 0; row--) {
        if (board[row][col] == Piece.newBlockColor && !initialFullRows.contains(row)) {
          newCellsBefore.putIfAbsent(col, () => []).add(row);
        }
      }
    }

    // 줄 클리어 → 중력(신규 셀만) → 연쇄 클리어 반복
    bool hadClears = true;
    while (hadClears) {
      hadClears = _clearFullRows();
      if (hadClears) {
        _applyGravity(affectedCols);
      }
    }

    // 신규 셀의 이동 경로 계산
    if (lastClearedCells.isNotEmpty) {
      for (int col in affectedCols) {
        final before = newCellsBefore[col];
        if (before == null || before.isEmpty) continue;

        // 최종 보드에서 신규 셀 위치 (아래→위)
        List<int> after = [];
        for (int row = rows - 1; row >= 0; row--) {
          if (board[row][col] == Piece.newBlockColor) {
            after.add(row);
          }
        }

        final count = before.length < after.length ? before.length : after.length;
        for (int i = 0; i < count; i++) {
          if (before[i] != after[i]) {
            lastFallingCells.add(FallingCell(
              col, before[i], after[i], Piece.newBlockColor,
            ));
          }
        }
      }
    }
  }

  /// 채워진 줄을 찾아 제거. 클리어된 줄이 있으면 true 반환.
  bool _clearFullRows() {
    List<int> fullRows = [];

    for (int row = 0; row < rows; row++) {
      bool isLineFull = true;
      for (int col = 0; col < cols; col++) {
        if (board[row][col] == null) {
          isLineFull = false;
          break;
        }
      }
      if (isLineFull) {
        fullRows.add(row);
        for (int col = 0; col < cols; col++) {
          lastClearedCells.add(ClearedCell(row, col, board[row][col]!));
        }
      }
    }

    if (fullRows.isEmpty) return false;

    for (int i = fullRows.length - 1; i >= 0; i--) {
      board.removeAt(fullRows[i]);
    }
    for (int i = 0; i < fullRows.length; i++) {
      board.insert(0, List.generate(cols, (_) => null));
    }

    int clearedCount = fullRows.length;
    linesCleared += clearedCount;

    switch (clearedCount) {
      case 1:
        score += 100 * level;
        break;
      case 2:
        score += 300 * level;
        break;
      case 3:
        score += 500 * level;
        break;
      default:
        score += 800 * level;
        break;
    }

    return true;
  }

  /// 신규 셀(newBlockColor)만 아래로 낙하시킴
  void _applyGravity(Set<int> affectedCols) {
    for (int col in affectedCols) {
      // 아래→위 순으로 처리: 아래쪽 신규 셀이 먼저 착지
      for (int row = rows - 1; row >= 0; row--) {
        if (board[row][col] == Piece.newBlockColor) {
          int targetRow = row;
          while (targetRow + 1 < rows && board[targetRow + 1][col] == null) {
            targetRow++;
          }
          if (targetRow != row) {
            board[targetRow][col] = Piece.newBlockColor;
            board[row][col] = null;
          }
        }
      }
    }
  }

  /// 신규 셀(진한색)을 기존 색으로 변환
  void normalizeNewCells() {
    bool changed = false;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (board[row][col] == Piece.newBlockColor) {
          board[row][col] = Piece.blockColor;
          changed = true;
        }
      }
    }
    if (changed) notifyListeners();
  }

  int getGhostY() {
    if (currentPiece == null) return 0;

    Piece ghost = currentPiece!.copy();
    while (_isValidPosition(ghost)) {
      ghost.y++;
    }
    ghost.y--;
    return ghost.y;
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }
}

class ClearedCell {
  final int row;
  final int col;
  final Color color;
  ClearedCell(this.row, this.col, this.color);
}

class FallingCell {
  final int col;
  final int fromRow;
  final int toRow;
  final Color color;
  FallingCell(this.col, this.fromRow, this.toRow, this.color);
}
