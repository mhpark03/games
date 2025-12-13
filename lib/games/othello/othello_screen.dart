import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Disc { none, black, white }

enum OthelloGameMode {
  vsComputerWhite, // 사용자 흑돌(선공), 컴퓨터 백돌
  vsComputerBlack, // 컴퓨터 흑돌(선공), 사용자 백돌
  vsPerson,        // 2인 플레이
}

class OthelloScreen extends StatefulWidget {
  final OthelloGameMode gameMode;
  final bool resumeGame;

  const OthelloScreen({
    super.key,
    this.gameMode = OthelloGameMode.vsComputerWhite,
    this.resumeGame = false,
  });

  static Future<bool> hasSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('othello_board');
  }

  static Future<OthelloGameMode?> getSavedGameMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('othello_gameMode');
    if (modeIndex == null) return null;
    return OthelloGameMode.values[modeIndex];
  }

  static Future<void> clearSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('othello_board');
    await prefs.remove('othello_isBlackTurn');
    await prefs.remove('othello_gameMode');
  }

  @override
  State<OthelloScreen> createState() => _OthelloScreenState();
}

class _OthelloScreenState extends State<OthelloScreen> {
  static const int boardSize = 8;
  late List<List<Disc>> board;
  bool isBlackTurn = true;
  bool gameOver = false;
  String gameMessage = '';
  int blackCount = 2;
  int whiteCount = 2;
  List<List<int>> validMoves = [];

  Disc get currentPlayerDisc => isBlackTurn ? Disc.black : Disc.white;

  bool get isUserBlack => widget.gameMode != OthelloGameMode.vsComputerBlack;

  bool get isUserTurn {
    if (widget.gameMode == OthelloGameMode.vsPerson) return true;
    if (widget.gameMode == OthelloGameMode.vsComputerWhite) return isBlackTurn;
    return !isBlackTurn;
  }

  @override
  void initState() {
    super.initState();
    if (widget.resumeGame) {
      _loadGame();
    } else {
      _initBoard();
    }
  }

  void _initBoard() {
    board = List.generate(
      boardSize,
      (_) => List.generate(boardSize, (_) => Disc.none),
    );
    // 초기 배치
    board[3][3] = Disc.white;
    board[3][4] = Disc.black;
    board[4][3] = Disc.black;
    board[4][4] = Disc.white;

    isBlackTurn = true;
    gameOver = false;
    blackCount = 2;
    whiteCount = 2;
    _updateValidMoves();
    _updateMessage();

    if (widget.gameMode == OthelloGameMode.vsComputerBlack) {
      gameMessage = '컴퓨터가 생각 중...';
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _computerMove();
      });
    }
  }

  Future<void> _saveGame() async {
    if (gameOver) {
      await OthelloScreen.clearSavedGame();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final boardData = board.map((row) => row.map((d) => d.index).toList()).toList();
    await prefs.setString('othello_board', jsonEncode(boardData));
    await prefs.setBool('othello_isBlackTurn', isBlackTurn);
    await prefs.setInt('othello_gameMode', widget.gameMode.index);
  }

  Future<void> _loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    final boardJson = prefs.getString('othello_board');

    if (boardJson == null) {
      _initBoard();
      return;
    }

    final boardData = jsonDecode(boardJson) as List;
    board = boardData
        .map<List<Disc>>((row) => (row as List)
            .map<Disc>((d) => Disc.values[d as int])
            .toList())
        .toList();

    isBlackTurn = prefs.getBool('othello_isBlackTurn') ?? true;
    gameOver = false;
    _countDiscs();
    _updateValidMoves();

    setState(() {
      _updateMessage();
    });

    if (!isUserTurn && widget.gameMode != OthelloGameMode.vsPerson) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _computerMove();
      });
    }
  }

  void _countDiscs() {
    blackCount = 0;
    whiteCount = 0;
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == Disc.black) blackCount++;
        if (board[i][j] == Disc.white) whiteCount++;
      }
    }
  }

  void _updateValidMoves() {
    validMoves = [];
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (_isValidMove(i, j, currentPlayerDisc)) {
          validMoves.add([i, j]);
        }
      }
    }
  }

  bool _isValidMove(int row, int col, Disc disc) {
    if (board[row][col] != Disc.none) return false;

    final directions = [
      [-1, -1], [-1, 0], [-1, 1],
      [0, -1],           [0, 1],
      [1, -1],  [1, 0],  [1, 1],
    ];

    for (var dir in directions) {
      if (_wouldFlip(row, col, dir[0], dir[1], disc)) {
        return true;
      }
    }
    return false;
  }

  bool _wouldFlip(int row, int col, int dr, int dc, Disc disc) {
    int r = row + dr;
    int c = col + dc;
    bool hasOpponent = false;
    Disc opponent = disc == Disc.black ? Disc.white : Disc.black;

    while (r >= 0 && r < boardSize && c >= 0 && c < boardSize) {
      if (board[r][c] == opponent) {
        hasOpponent = true;
      } else if (board[r][c] == disc) {
        return hasOpponent;
      } else {
        return false;
      }
      r += dr;
      c += dc;
    }
    return false;
  }

  List<List<int>> _getFlippedDiscs(int row, int col, Disc disc) {
    List<List<int>> flipped = [];
    final directions = [
      [-1, -1], [-1, 0], [-1, 1],
      [0, -1],           [0, 1],
      [1, -1],  [1, 0],  [1, 1],
    ];

    for (var dir in directions) {
      List<List<int>> temp = [];
      int r = row + dir[0];
      int c = col + dir[1];
      Disc opponent = disc == Disc.black ? Disc.white : Disc.black;

      while (r >= 0 && r < boardSize && c >= 0 && c < boardSize) {
        if (board[r][c] == opponent) {
          temp.add([r, c]);
        } else if (board[r][c] == disc) {
          flipped.addAll(temp);
          break;
        } else {
          break;
        }
        r += dir[0];
        c += dir[1];
      }
    }
    return flipped;
  }

  void _updateMessage() {
    if (gameOver) return;

    String turnText;
    switch (widget.gameMode) {
      case OthelloGameMode.vsComputerWhite:
        turnText = isBlackTurn ? '당신의 차례입니다 (흑)' : '컴퓨터가 생각 중...';
        break;
      case OthelloGameMode.vsComputerBlack:
        turnText = isBlackTurn ? '컴퓨터가 생각 중...' : '당신의 차례입니다 (백)';
        break;
      case OthelloGameMode.vsPerson:
        turnText = isBlackTurn ? '흑 차례입니다' : '백 차례입니다';
        break;
    }
    gameMessage = turnText;
  }

  void _resetGame() {
    OthelloScreen.clearSavedGame();
    setState(() {
      _initBoard();
    });
  }

  void _placeDisc(int row, int col) {
    if (gameOver || !isUserTurn) return;
    if (!_isValidMove(row, col, currentPlayerDisc)) return;

    _makeMove(row, col);

    if (!gameOver && widget.gameMode != OthelloGameMode.vsPerson) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _computerMove();
      });
    }
  }

  void _makeMove(int row, int col) {
    final disc = currentPlayerDisc;
    final flipped = _getFlippedDiscs(row, col, disc);

    setState(() {
      board[row][col] = disc;
      for (var pos in flipped) {
        board[pos[0]][pos[1]] = disc;
      }

      if (disc == Disc.black) {
        blackCount += 1 + flipped.length;
        whiteCount -= flipped.length;
      } else {
        whiteCount += 1 + flipped.length;
        blackCount -= flipped.length;
      }

      isBlackTurn = !isBlackTurn;
      _updateValidMoves();

      // 다음 플레이어가 둘 곳이 없으면 패스
      if (validMoves.isEmpty) {
        isBlackTurn = !isBlackTurn;
        _updateValidMoves();

        // 둘 다 둘 곳이 없으면 게임 종료
        if (validMoves.isEmpty) {
          gameOver = true;
          _setWinMessage();
          _saveGame();
          return;
        }
      }

      _updateMessage();
    });

    _saveGame();
  }

  void _setWinMessage() {
    String winner;
    if (blackCount > whiteCount) {
      switch (widget.gameMode) {
        case OthelloGameMode.vsComputerWhite:
          winner = '축하합니다! 당신이 이겼습니다!';
          break;
        case OthelloGameMode.vsComputerBlack:
          winner = '컴퓨터가 이겼습니다!';
          break;
        case OthelloGameMode.vsPerson:
          winner = '흑이 이겼습니다!';
          break;
      }
    } else if (whiteCount > blackCount) {
      switch (widget.gameMode) {
        case OthelloGameMode.vsComputerWhite:
          winner = '컴퓨터가 이겼습니다!';
          break;
        case OthelloGameMode.vsComputerBlack:
          winner = '축하합니다! 당신이 이겼습니다!';
          break;
        case OthelloGameMode.vsPerson:
          winner = '백이 이겼습니다!';
          break;
      }
    } else {
      winner = '무승부입니다!';
    }
    gameMessage = '$winner ($blackCount : $whiteCount)';
  }

  void _computerMove() {
    if (gameOver || validMoves.isEmpty) return;

    // 간단한 AI: 코너 우선, 그 다음 가장 많이 뒤집는 수
    List<int>? bestMove;
    int bestScore = -1;

    // 코너 위치
    final corners = [[0, 0], [0, 7], [7, 0], [7, 7]];
    for (var corner in corners) {
      if (validMoves.any((m) => m[0] == corner[0] && m[1] == corner[1])) {
        bestMove = corner;
        break;
      }
    }

    if (bestMove == null) {
      // 가장 많이 뒤집는 수 선택
      for (var move in validMoves) {
        int score = _getFlippedDiscs(move[0], move[1], currentPlayerDisc).length;
        // 코너 옆은 피하기
        if (_isNearCorner(move[0], move[1])) {
          score -= 10;
        }
        if (score > bestScore) {
          bestScore = score;
          bestMove = move;
        }
      }
    }

    if (bestMove != null) {
      _makeMove(bestMove[0], bestMove[1]);

      if (!gameOver && widget.gameMode != OthelloGameMode.vsPerson && !isUserTurn) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _computerMove();
        });
      }
    }
  }

  bool _isNearCorner(int row, int col) {
    final dangerous = [
      [0, 1], [1, 0], [1, 1],
      [0, 6], [1, 6], [1, 7],
      [6, 0], [6, 1], [7, 1],
      [6, 6], [6, 7], [7, 6],
    ];
    return dangerous.any((d) => d[0] == row && d[1] == col);
  }

  bool _isValidMovePosition(int row, int col) {
    return validMoves.any((m) => m[0] == row && m[1] == col);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '오델로',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetGame,
            tooltip: '새 게임',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade900,
              Colors.black,
            ],
          ),
        ),
        child: Column(
          children: [
            // 점수판
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildScoreCard(Disc.black, blackCount),
                  _buildScoreCard(Disc.white, whiteCount),
                ],
              ),
            ),
            // 메시지
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: gameOver
                      ? (gameMessage.contains('축하')
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.3))
                      : Colors.teal.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: gameOver
                        ? (gameMessage.contains('축하') ? Colors.green : Colors.red)
                        : Colors.teal,
                    width: 2,
                  ),
                ),
                child: Text(
                  gameMessage,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: gameOver
                        ? (gameMessage.contains('축하') ? Colors.green : Colors.red)
                        : Colors.teal,
                  ),
                ),
              ),
            ),
            // 보드
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(4),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: boardSize,
                        mainAxisSpacing: 2,
                        crossAxisSpacing: 2,
                      ),
                      itemCount: boardSize * boardSize,
                      itemBuilder: (context, index) {
                        int row = index ~/ boardSize;
                        int col = index % boardSize;
                        bool isValid = _isValidMovePosition(row, col) && isUserTurn;
                        return GestureDetector(
                          onTap: () => _placeDisc(row, col),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              borderRadius: BorderRadius.circular(4),
                              border: isValid
                                  ? Border.all(color: Colors.yellow, width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: _buildDisc(row, col, isValid),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            // 레전드
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _buildLegendByMode(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(Disc disc, int count) {
    bool isCurrentTurn = (disc == Disc.black && isBlackTurn) ||
        (disc == Disc.white && !isBlackTurn);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? Colors.teal.withValues(alpha: 0.3)
            : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentTurn ? Colors.teal : Colors.grey,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: disc == Disc.black ? Colors.black : Colors.white,
              border: disc == Disc.white
                  ? Border.all(color: Colors.grey)
                  : Border.all(color: Colors.grey.shade400, width: 2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isCurrentTurn ? Colors.teal : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisc(int row, int col, bool isValidMove) {
    if (board[row][col] == Disc.none) {
      if (isValidMove) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.yellow.withValues(alpha: 0.5),
          ),
        );
      }
      return const SizedBox();
    }

    Color discColor = board[row][col] == Disc.black ? Colors.black : Colors.white;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: discColor,
        border: board[row][col] == Disc.white
            ? Border.all(color: Colors.grey.shade400, width: 1)
            : Border.all(color: Colors.grey.shade600, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 3,
            offset: const Offset(2, 2),
          ),
        ],
        gradient: RadialGradient(
          colors: board[row][col] == Disc.black
              ? [Colors.grey.shade700, Colors.black]
              : [Colors.white, Colors.grey.shade300],
          center: const Alignment(-0.3, -0.3),
        ),
      ),
    );
  }

  List<Widget> _buildLegendByMode() {
    switch (widget.gameMode) {
      case OthelloGameMode.vsComputerWhite:
        return [
          _buildLegend(Colors.black, '당신 (흑)'),
          const SizedBox(width: 32),
          _buildLegend(Colors.white, '컴퓨터 (백)'),
        ];
      case OthelloGameMode.vsComputerBlack:
        return [
          _buildLegend(Colors.black, '컴퓨터 (흑)'),
          const SizedBox(width: 32),
          _buildLegend(Colors.white, '당신 (백)'),
        ];
      case OthelloGameMode.vsPerson:
        return [
          _buildLegend(Colors.black, '플레이어 1 (흑)'),
          const SizedBox(width: 32),
          _buildLegend(Colors.white, '플레이어 2 (백)'),
        ];
    }
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: color == Colors.white ? Colors.grey : Colors.grey.shade400,
              width: color == Colors.white ? 1 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 2,
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ],
    );
  }
}
