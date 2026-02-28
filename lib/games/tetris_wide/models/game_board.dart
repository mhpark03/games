import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'piece.dart';

class GameBoard extends ChangeNotifier {
  final int rows;
  static const int cols = 20;

  late List<List<Color?>> board;

  Piece? currentPiece;
  Piece? nextPiece;
  int score = 0;
  int level = 1;
  int linesCleared = 0;
  bool isGameOver = false;
  bool isLevelComplete = false;
  bool isPaused = false;
  Timer? _gameTimer;

  final Random _random = Random();

  GameBoard({this.rows = 20}) {
    board = List.generate(
      rows,
      (_) => List.generate(cols, (_) => null),
    );
    _initGame();
  }

  List<ClearedCell> lastClearedCells = [];

  /// 레벨별 채울 줄 수: 1단계=5, 2단계=7, 3단계=9 ...
  int get _fillRows => (5 + (level - 1) * 2).clamp(1, rows - 4);

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
    _fillInitialBlocks();
    currentPiece = _generateRandomPiece();
    nextPiece = _generateRandomPiece();
  }

  void _fillInitialBlocks() {
    final fillRows = _fillRows;
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
    _gameTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
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
        board[row][col] = currentPiece!.color;
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

    // 줄 클리어 → 중력 → 연쇄 클리어 반복
    bool hadClears = true;
    while (hadClears) {
      hadClears = _clearFullRows();
      if (hadClears) {
        _applyGravity(affectedCols);
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

  /// 지정된 열에서만 빈 칸 아래로 블록을 떨어뜨림
  void _applyGravity(Set<int> affectedCols) {
    for (int col in affectedCols) {
      // 열의 블록을 아래부터 모아서 바닥에 채움
      List<Color> cells = [];
      for (int row = rows - 1; row >= 0; row--) {
        if (board[row][col] != null) {
          cells.add(board[row][col]!);
        }
      }
      for (int row = rows - 1; row >= 0; row--) {
        int idx = rows - 1 - row;
        board[row][col] = idx < cells.length ? cells[idx] : null;
      }
    }
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
