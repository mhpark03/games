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
  late List<bool> _isDenseCol;

  final Random _random = Random();

  /// 실제 적용 속도 (설정 속도 - 부스트)
  int get activeSpeed => (speed - speedBoost * 20).clamp(50, 999);

  int startLevel;

  GameBoard({this.rows = 20, this.startLevel = 1}) {
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
    linesCleared = 0;
    isGameOver = false;
    isLevelComplete = false;
    isPaused = false;

    // startLevel에 맞춰 level, currentFillRows, speedBoost 계산
    level = startLevel.clamp(1, 99);
    currentFillRows = rows ~/ 3;
    speedBoost = 0;
    final maxFill = (rows * 2) ~/ 3;
    for (int i = 1; i < level; i++) {
      currentFillRows += 2;
      if (currentFillRows > maxFill) {
        currentFillRows = rows ~/ 3;
        speedBoost++;
      }
    }

    _isDenseCol = List.generate(cols, (_) => _random.nextDouble() < 0.6);
    _fillInitialBlocks();
    currentPiece = _generateRandomPiece();
    nextPiece = _generateRandomPiece();
  }

  void _fillInitialBlocks() {
    final fillRows = currentFillRows.clamp(1, rows - 4);
    final startRow = rows - fillRows;

    // Step 1: 셀별 초기 랜덤 채움 (밀집/공백 열 기반)
    for (int row = startRow; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final prob = _isDenseCol[col] ? 0.72 : 0.48;
        if (_random.nextDouble() < prob) {
          board[row][col] = Piece.blockColor;
        }
      }
    }

    // Step 2: CA 스무딩 2회 → 고립된 구멍·블록 제거, 덩어리 연속성 확보
    // 규칙: 8방향 이웃(자신 포함 9칸) 중 채워진 수가 임계값 이상이면 채움
    //       밀집 열 임계값=4, 공백 열 임계값=5 (더 강하게 비워짐)
    for (int pass = 0; pass < 2; pass++) {
      final next = List.generate(rows, (r) => List<Color?>.from(board[r]));
      for (int row = startRow; row < rows; row++) {
        for (int col = 0; col < cols; col++) {
          int filled = 0;
          for (int dr = -1; dr <= 1; dr++) {
            for (int dc = -1; dc <= 1; dc++) {
              final nr = row + dr, nc = col + dc;
              if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
                if (board[nr][nc] != null) filled++;
              }
            }
          }
          final threshold = _isDenseCol[col] ? 4 : 5;
          next[row][col] = filled >= threshold ? Piece.blockColor : null;
        }
      }
      for (int row = startRow; row < rows; row++) {
        board[row] = next[row];
      }
    }

    // Step 3: 꽉 찬 줄 빈칸 보장
    for (int row = 0; row < rows; row++) {
      if (board[row].every((c) => c != null)) {
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

    for (var cell in currentPiece!.cells) {
      int row = cell[0];
      int col = cell[1];
      if (row >= 0 && row < rows && col >= 0 && col < cols) {
        board[row][col] = Piece.newBlockColor;
      }
    }

    _clearLines();

    // 남은 줄이 1줄 이하면 레벨 클리어
    if (remainingRows <= 2) {
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

  void _clearLines() {
    lastClearedCells = [];
    lastFallingCells = [];

    // 줄 클리어 → 제거된 줄 위 셀 중력 → 연쇄 반복
    int maxClearedRow;
    while ((maxClearedRow = _clearFullRows()) >= 0) {
      _applyGravityAbove(maxClearedRow);
    }
  }

  /// 채워진 줄을 찾아 제거.
  /// 클리어된 가장 아래(bottommost) 줄 인덱스 반환, 없으면 -1.
  int _clearFullRows() {
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

    if (fullRows.isEmpty) return -1;

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

    return fullRows.last; // bottommost cleared row
  }

  /// 제거된 줄(maxClearedRow) 위에 있던 셀만 아래로 낙하.
  /// 연쇄 클리어 시 동일 셀의 이동 경로를 합산(coalesce)해 lastFallingCells에 기록.
  void _applyGravityAbove(int maxClearedRow) {
    for (int col = 0; col < cols; col++) {
      // maxClearedRow 이하 행(위에서 내려온 셀)만 대상, 아래→위 순
      for (int row = maxClearedRow; row >= 0; row--) {
        if (board[row][col] == null) continue;
        int targetRow = row;
        while (targetRow + 1 < rows && board[targetRow + 1][col] == null) {
          targetRow++;
        }
        if (targetRow == row) continue;

        final color = board[row][col]!;
        board[targetRow][col] = color;
        board[row][col] = null;

        // 연쇄 낙하 합산: 이전 라운드에서 row까지 내려온 셀이면 fromRow를 유지
        final existingIdx = lastFallingCells.indexWhere(
          (c) => c.col == col && c.toRow == row,
        );
        if (existingIdx >= 0) {
          final old = lastFallingCells[existingIdx];
          lastFallingCells[existingIdx] = FallingCell(col, old.fromRow, targetRow, color);
        } else {
          lastFallingCells.add(FallingCell(col, row, targetRow, color));
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
