import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Stone { none, black, white }

enum GameMode {
  vsComputerWhite, // 사용자 흑돌(선공), 컴퓨터 백돌
  vsComputerBlack, // 컴퓨터 흑돌(선공), 사용자 백돌
  vsPerson,        // 2인 플레이
}

class GomokuScreen extends StatefulWidget {
  final GameMode gameMode;
  final bool resumeGame; // 이어하기 여부

  const GomokuScreen({
    super.key,
    this.gameMode = GameMode.vsComputerWhite,
    this.resumeGame = false,
  });

  // 저장된 게임이 있는지 확인
  static Future<bool> hasSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('gomoku_board');
  }

  // 저장된 게임 모드 가져오기
  static Future<GameMode?> getSavedGameMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('gomoku_gameMode');
    if (modeIndex == null) return null;
    return GameMode.values[modeIndex];
  }

  // 저장된 게임 삭제
  static Future<void> clearSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gomoku_board');
    await prefs.remove('gomoku_isBlackTurn');
    await prefs.remove('gomoku_gameMode');
  }

  @override
  State<GomokuScreen> createState() => _GomokuScreenState();
}

class _GomokuScreenState extends State<GomokuScreen> {
  static const int boardSize = 15;
  late List<List<Stone>> board;
  bool isBlackTurn = true; // 흑돌 차례 여부
  bool gameOver = false;
  String gameMessage = '';
  List<List<int>>? winningStones;

  // 현재 플레이어가 두는 돌 색상
  Stone get currentPlayerStone => isBlackTurn ? Stone.black : Stone.white;

  // 사용자가 흑돌인지 여부 (vsComputerBlack에서는 사용자가 백돌)
  bool get isUserBlack => widget.gameMode != GameMode.vsComputerBlack;

  // 현재 차례가 사용자 차례인지 여부
  bool get isUserTurn {
    if (widget.gameMode == GameMode.vsPerson) return true; // 2인 플레이는 항상 사용자
    if (widget.gameMode == GameMode.vsComputerWhite) return isBlackTurn; // 사용자가 흑돌
    return !isBlackTurn; // vsComputerBlack: 사용자가 백돌
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
      (_) => List.generate(boardSize, (_) => Stone.none),
    );
    isBlackTurn = true;
    gameOver = false;
    winningStones = null;
    _updateMessage();

    // 컴퓨터(흑) 모드일 때 컴퓨터가 먼저 둠
    if (widget.gameMode == GameMode.vsComputerBlack) {
      gameMessage = '컴퓨터가 생각 중...';
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _computerMove();
      });
    }
  }

  // 게임 상태 저장
  Future<void> _saveGame() async {
    if (gameOver) {
      await GomokuScreen.clearSavedGame();
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // 보드 상태를 2D 리스트로 변환
    final boardData = board.map((row) => row.map((s) => s.index).toList()).toList();
    await prefs.setString('gomoku_board', jsonEncode(boardData));
    await prefs.setBool('gomoku_isBlackTurn', isBlackTurn);
    await prefs.setInt('gomoku_gameMode', widget.gameMode.index);
  }

  // 저장된 게임 불러오기
  Future<void> _loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    final boardJson = prefs.getString('gomoku_board');

    if (boardJson == null) {
      _initBoard();
      return;
    }

    final boardData = jsonDecode(boardJson) as List;
    board = boardData
        .map<List<Stone>>((row) => (row as List)
            .map<Stone>((s) => Stone.values[s as int])
            .toList())
        .toList();

    isBlackTurn = prefs.getBool('gomoku_isBlackTurn') ?? true;
    gameOver = false;
    winningStones = null;

    setState(() {
      _updateMessage();
    });

    // 컴퓨터 차례인 경우 컴퓨터가 두도록
    if (!isUserTurn && widget.gameMode != GameMode.vsPerson) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _computerMove();
      });
    }
  }

  void _updateMessage() {
    if (gameOver) return;

    switch (widget.gameMode) {
      case GameMode.vsComputerWhite:
        gameMessage = isBlackTurn ? '당신의 차례입니다 (흑돌)' : '컴퓨터가 생각 중...';
        break;
      case GameMode.vsComputerBlack:
        gameMessage = isBlackTurn ? '컴퓨터가 생각 중...' : '당신의 차례입니다 (백돌)';
        break;
      case GameMode.vsPerson:
        gameMessage = isBlackTurn ? '흑돌 차례입니다' : '백돌 차례입니다';
        break;
    }
  }

  void _resetGame() {
    GomokuScreen.clearSavedGame(); // 저장된 게임 삭제
    setState(() {
      _initBoard();
    });
  }

  void _placeStone(int row, int col) {
    if (gameOver || board[row][col] != Stone.none || !isUserTurn) return;

    final stone = currentPlayerStone;

    setState(() {
      board[row][col] = stone;
      if (_checkWin(row, col, stone)) {
        gameOver = true;
        _setWinMessage(stone);
        _saveGame(); // 게임 종료 시 저장 데이터 삭제
        return;
      }
      if (_isBoardFull()) {
        gameOver = true;
        gameMessage = '무승부입니다!';
        _saveGame(); // 게임 종료 시 저장 데이터 삭제
        return;
      }
      isBlackTurn = !isBlackTurn;
      _updateMessage();
    });

    // 게임 상태 저장
    _saveGame();

    // 컴퓨터 모드이고 게임이 끝나지 않았으면 컴퓨터 차례
    if (!gameOver && widget.gameMode != GameMode.vsPerson) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _computerMove();
      });
    }
  }

  void _setWinMessage(Stone winner) {
    switch (widget.gameMode) {
      case GameMode.vsComputerWhite:
        gameMessage = winner == Stone.black
            ? '축하합니다! 당신이 이겼습니다!'
            : '컴퓨터가 이겼습니다!';
        break;
      case GameMode.vsComputerBlack:
        gameMessage = winner == Stone.white
            ? '축하합니다! 당신이 이겼습니다!'
            : '컴퓨터가 이겼습니다!';
        break;
      case GameMode.vsPerson:
        gameMessage = winner == Stone.black
            ? '흑돌이 이겼습니다!'
            : '백돌이 이겼습니다!';
        break;
    }
  }

  void _computerMove() {
    if (gameOver) return;

    final computerStone = currentPlayerStone;
    final userStone = computerStone == Stone.black ? Stone.white : Stone.black;
    final move = _findBestMove(computerStone, userStone);

    if (move != null) {
      setState(() {
        board[move[0]][move[1]] = computerStone;
        if (_checkWin(move[0], move[1], computerStone)) {
          gameOver = true;
          _setWinMessage(computerStone);
          _saveGame(); // 게임 종료 시 저장 데이터 삭제
          return;
        }
        if (_isBoardFull()) {
          gameOver = true;
          gameMessage = '무승부입니다!';
          _saveGame(); // 게임 종료 시 저장 데이터 삭제
          return;
        }
        isBlackTurn = !isBlackTurn;
        _updateMessage();
      });

      // 게임 상태 저장
      _saveGame();
    }
  }

  List<int>? _findBestMove(Stone computerStone, Stone userStone) {
    int bestScore = -1;
    List<int>? bestMove;

    // 컴퓨터가 이길 수 있는지 확인
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == Stone.none) {
          board[i][j] = computerStone;
          if (_checkWinWithoutHighlight(i, j, computerStone)) {
            board[i][j] = Stone.none;
            return [i, j];
          }
          board[i][j] = Stone.none;
        }
      }
    }

    // 사용자가 이기는 것을 막기
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == Stone.none) {
          board[i][j] = userStone;
          if (_checkWinWithoutHighlight(i, j, userStone)) {
            board[i][j] = Stone.none;
            return [i, j];
          }
          board[i][j] = Stone.none;
        }
      }
    }

    // 최선의 위치 찾기
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == Stone.none) {
          int score = _evaluatePositionForStone(i, j, computerStone, userStone);
          if (score > bestScore) {
            bestScore = score;
            bestMove = [i, j];
          }
        }
      }
    }

    return bestMove;
  }

  int _evaluatePositionForStone(int row, int col, Stone computerStone, Stone userStone) {
    int score = 0;

    int centerDist = (row - boardSize ~/ 2).abs() + (col - boardSize ~/ 2).abs();
    score += (boardSize - centerDist) * 2;

    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        int nr = row + dr;
        int nc = col + dc;
        if (nr >= 0 && nr < boardSize && nc >= 0 && nc < boardSize) {
          if (board[nr][nc] != Stone.none) {
            score += 10;
          }
        }
      }
    }

    score += _evaluateLineScore(row, col, computerStone) * 3;
    score += _evaluateLineScore(row, col, userStone) * 2;

    return score;
  }

  int _evaluateLineScore(int row, int col, Stone stone) {
    int score = 0;
    final directions = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1]
    ];

    for (var dir in directions) {
      int count = 0;
      int openEnds = 0;

      for (int i = 1; i < 5; i++) {
        int nr = row + dir[0] * i;
        int nc = col + dir[1] * i;
        if (nr < 0 || nr >= boardSize || nc < 0 || nc >= boardSize) break;
        if (board[nr][nc] == stone) {
          count++;
        } else if (board[nr][nc] == Stone.none) {
          openEnds++;
          break;
        } else {
          break;
        }
      }

      for (int i = 1; i < 5; i++) {
        int nr = row - dir[0] * i;
        int nc = col - dir[1] * i;
        if (nr < 0 || nr >= boardSize || nc < 0 || nc >= boardSize) break;
        if (board[nr][nc] == stone) {
          count++;
        } else if (board[nr][nc] == Stone.none) {
          openEnds++;
          break;
        } else {
          break;
        }
      }

      if (count >= 4) {
        score += 10000;
      } else if (count == 3 && openEnds == 2) {
        score += 1000;
      } else if (count == 3 && openEnds == 1) {
        score += 100;
      } else if (count == 2 && openEnds == 2) {
        score += 50;
      } else if (count == 2 && openEnds == 1) {
        score += 10;
      } else if (count == 1 && openEnds == 2) {
        score += 5;
      }
    }

    return score;
  }

  bool _checkWin(int row, int col, Stone stone) {
    final directions = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1]
    ];

    for (var dir in directions) {
      List<List<int>> stones = [
        [row, col]
      ];

      for (int i = 1; i < 5; i++) {
        int nr = row + dir[0] * i;
        int nc = col + dir[1] * i;
        if (nr < 0 || nr >= boardSize || nc < 0 || nc >= boardSize) break;
        if (board[nr][nc] == stone) {
          stones.add([nr, nc]);
        } else {
          break;
        }
      }

      for (int i = 1; i < 5; i++) {
        int nr = row - dir[0] * i;
        int nc = col - dir[1] * i;
        if (nr < 0 || nr >= boardSize || nc < 0 || nc >= boardSize) break;
        if (board[nr][nc] == stone) {
          stones.add([nr, nc]);
        } else {
          break;
        }
      }

      if (stones.length >= 5) {
        winningStones = stones;
        return true;
      }
    }
    return false;
  }

  bool _checkWinWithoutHighlight(int row, int col, Stone stone) {
    final directions = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1]
    ];

    for (var dir in directions) {
      int count = 1;

      for (int i = 1; i < 5; i++) {
        int nr = row + dir[0] * i;
        int nc = col + dir[1] * i;
        if (nr < 0 || nr >= boardSize || nc < 0 || nc >= boardSize) break;
        if (board[nr][nc] == stone) {
          count++;
        } else {
          break;
        }
      }

      for (int i = 1; i < 5; i++) {
        int nr = row - dir[0] * i;
        int nc = col - dir[1] * i;
        if (nr < 0 || nr >= boardSize || nc < 0 || nc >= boardSize) break;
        if (board[nr][nc] == stone) {
          count++;
        } else {
          break;
        }
      }

      if (count >= 5) return true;
    }
    return false;
  }

  bool _isBoardFull() {
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == Stone.none) return false;
      }
    }
    return true;
  }

  bool _isWinningStone(int row, int col) {
    if (winningStones == null) return false;
    for (var stone in winningStones!) {
      if (stone[0] == row && stone[1] == col) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '오목',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown.shade800,
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
              Colors.brown.shade900,
              Colors.black,
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: gameOver
                      ? (gameMessage.contains('축하')
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.3))
                      : Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: gameOver
                        ? (gameMessage.contains('축하') ? Colors.green : Colors.red)
                        : Colors.amber,
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
                        : Colors.amber,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDEB887),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: BoardPainter(),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: boardSize,
                        ),
                        itemCount: boardSize * boardSize,
                        itemBuilder: (context, index) {
                          int row = index ~/ boardSize;
                          int col = index % boardSize;
                          return GestureDetector(
                            onTap: () => _placeStone(row, col),
                            child: Container(
                              color: Colors.transparent,
                              child: Center(
                                child: _buildStone(row, col),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
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

  Widget _buildStone(int row, int col) {
    if (board[row][col] == Stone.none) return const SizedBox();

    bool isWinning = _isWinningStone(row, col);
    Color stoneColor = board[row][col] == Stone.black ? Colors.black : Colors.white;

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: stoneColor,
        border: isWinning
            ? Border.all(color: Colors.red, width: 3)
            : (board[row][col] == Stone.white
                ? Border.all(color: Colors.grey, width: 1)
                : null),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 3,
            offset: const Offset(2, 2),
          ),
        ],
        gradient: RadialGradient(
          colors: board[row][col] == Stone.black
              ? [Colors.grey.shade700, Colors.black]
              : [Colors.white, Colors.grey.shade300],
          center: const Alignment(-0.3, -0.3),
        ),
      ),
    );
  }

  List<Widget> _buildLegendByMode() {
    switch (widget.gameMode) {
      case GameMode.vsComputerWhite:
        return [
          _buildLegend(Colors.black, '당신 (흑)'),
          const SizedBox(width: 32),
          _buildLegend(Colors.white, '컴퓨터 (백)'),
        ];
      case GameMode.vsComputerBlack:
        return [
          _buildLegend(Colors.black, '컴퓨터 (흑)'),
          const SizedBox(width: 32),
          _buildLegend(Colors.white, '당신 (백)'),
        ];
      case GameMode.vsPerson:
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

class BoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;

    double cellSize = size.width / 15;
    double padding = cellSize / 2;

    for (int i = 0; i < 15; i++) {
      canvas.drawLine(
        Offset(padding, padding + i * cellSize),
        Offset(size.width - padding, padding + i * cellSize),
        paint,
      );
      canvas.drawLine(
        Offset(padding + i * cellSize, padding),
        Offset(padding + i * cellSize, size.height - padding),
        paint,
      );
    }

    final starPoints = [
      [3, 3], [3, 7], [3, 11],
      [7, 3], [7, 7], [7, 11],
      [11, 3], [11, 7], [11, 11],
    ];

    final starPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    for (var point in starPoints) {
      canvas.drawCircle(
        Offset(padding + point[1] * cellSize, padding + point[0] * cellSize),
        4,
        starPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
