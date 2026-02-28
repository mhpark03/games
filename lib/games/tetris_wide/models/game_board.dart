import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'piece.dart';

class GameBoard extends ChangeNotifier {
  final int rows;
  static const int cols = 20;
  static const String _startLevelKey = 'tetris_wide_start_level';

  late List<List<Color?>> board;

  Piece? currentPiece;
  Piece? nextPiece;
  int score = 0;
  int level = 1;
  int startLevel = 1;
  int linesCleared = 0;
  bool isGameOver = false;
  bool isPaused = false;
  Timer? _gameTimer;

  final Random _random = Random();

  static const int maxLevel = 10;

  GameBoard({this.rows = 20}) {
    board = List.generate(
      rows,
      (_) => List.generate(cols, (_) => null),
    );
    _loadStartLevel();
    _initGame();
  }

  Future<void> _loadStartLevel() async {
    final prefs = await SharedPreferences.getInstance();
    startLevel = prefs.getInt(_startLevelKey) ?? 1;
    level = startLevel;
    notifyListeners();
  }

  Future<void> _saveStartLevel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_startLevelKey, startLevel);
  }

  List<ClearedCell> lastClearedCells = [];

  void _initGame() {
    board = List.generate(
      rows,
      (_) => List.generate(cols, (_) => null),
    );
    score = 0;
    level = startLevel;
    linesCleared = 0;
    isGameOver = false;
    isPaused = false;
    _fillInitialBlocks();
    currentPiece = _generateRandomPiece();
    nextPiece = _generateRandomPiece();
  }

  void _fillInitialBlocks() {
    final startRow = rows ~/ 2;
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

  void setStartLevel(int newLevel) {
    if (newLevel >= 1 && newLevel <= maxLevel) {
      startLevel = newLevel;
      _saveStartLevel();
      notifyListeners();
    }
  }

  void startGame() {
    _initGame();
    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _gameTimer?.cancel();
    int speed = 500 - (level - 1) * 50;
    if (speed < 50) speed = 50;
    _gameTimer = Timer.periodic(Duration(milliseconds: speed), (_) {
      if (!isPaused && !isGameOver) {
        moveDown();
      }
    });
  }

  void pauseGame() {
    isPaused = !isPaused;
    notifyListeners();
  }

  void _restartTimer() {
    _gameTimer?.cancel();
    _startTimer();
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
    if (currentPiece == null || isGameOver || isPaused) return;

    currentPiece!.x--;
    if (!_isValidPosition(currentPiece!)) {
      currentPiece!.x++;
    }
    notifyListeners();
  }

  void moveRight() {
    if (currentPiece == null || isGameOver || isPaused) return;

    currentPiece!.x++;
    if (!_isValidPosition(currentPiece!)) {
      currentPiece!.x--;
    }
    notifyListeners();
  }

  void moveDown() {
    if (currentPiece == null || isGameOver || isPaused) return;

    currentPiece!.y++;
    if (!_isValidPosition(currentPiece!)) {
      currentPiece!.y--;
      _placePiece();
    }
    notifyListeners();
  }

  void hardDrop() {
    if (currentPiece == null || isGameOver || isPaused) return;

    while (_isValidPosition(currentPiece!)) {
      currentPiece!.y++;
    }
    currentPiece!.y--;
    _placePiece();
    notifyListeners();
  }

  void rotate() {
    if (currentPiece == null || isGameOver || isPaused) return;

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
    if (currentPiece == null || isGameOver || isPaused) return;

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
        board[row][col] = currentPiece!.color;
      }
    }

    _clearLines();

    currentPiece = nextPiece;
    nextPiece = _generateRandomPiece();

    if (!_isValidPosition(currentPiece!)) {
      isGameOver = true;
      _gameTimer?.cancel();
    }

    notifyListeners();
  }

  void _clearLines() {
    lastClearedCells = [];
    List<int> fullRows = [];

    // 1단계: 채워진 줄 찾기 + 셀 위치 기록
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

    // 2단계: 줄 제거 (아래→위 순서로 인덱스 유지)
    for (int i = fullRows.length - 1; i >= 0; i--) {
      board.removeAt(fullRows[i]);
      board.insert(0, List.generate(cols, (_) => null));
    }

    int clearedCount = fullRows.length;
    if (clearedCount > 0) {
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
        case 4:
          score += 800 * level;
          break;
      }

      int newLevel = startLevel + (linesCleared ~/ 10);
      if (newLevel > level && newLevel <= maxLevel) {
        level = newLevel;
        _restartTimer();
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
