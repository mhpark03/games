import 'package:flutter/material.dart';

enum Stone { none, black, white }

class GomokuScreen extends StatefulWidget {
  const GomokuScreen({super.key});

  @override
  State<GomokuScreen> createState() => _GomokuScreenState();
}

class _GomokuScreenState extends State<GomokuScreen> {
  static const int boardSize = 15;
  late List<List<Stone>> board;
  bool isPlayerTurn = true;
  bool gameOver = false;
  String gameMessage = '당신의 차례입니다 (흑돌)';
  List<List<int>>? winningStones;

  @override
  void initState() {
    super.initState();
    _initBoard();
  }

  void _initBoard() {
    board = List.generate(
      boardSize,
      (_) => List.generate(boardSize, (_) => Stone.none),
    );
    isPlayerTurn = true;
    gameOver = false;
    gameMessage = '당신의 차례입니다 (흑돌)';
    winningStones = null;
  }

  void _resetGame() {
    setState(() {
      _initBoard();
    });
  }

  void _placeStone(int row, int col) {
    if (gameOver || board[row][col] != Stone.none || !isPlayerTurn) return;

    setState(() {
      board[row][col] = Stone.black;
      if (_checkWin(row, col, Stone.black)) {
        gameOver = true;
        gameMessage = '축하합니다! 당신이 이겼습니다!';
        return;
      }
      if (_isBoardFull()) {
        gameOver = true;
        gameMessage = '무승부입니다!';
        return;
      }
      isPlayerTurn = false;
      gameMessage = '컴퓨터가 생각 중...';
    });

    if (!gameOver) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _computerMove();
      });
    }
  }

  void _computerMove() {
    if (gameOver) return;

    final move = _findBestMove();
    if (move != null) {
      setState(() {
        board[move[0]][move[1]] = Stone.white;
        if (_checkWin(move[0], move[1], Stone.white)) {
          gameOver = true;
          gameMessage = '컴퓨터가 이겼습니다!';
          return;
        }
        if (_isBoardFull()) {
          gameOver = true;
          gameMessage = '무승부입니다!';
          return;
        }
        isPlayerTurn = true;
        gameMessage = '당신의 차례입니다 (흑돌)';
      });
    }
  }

  List<int>? _findBestMove() {
    int bestScore = -1;
    List<int>? bestMove;

    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == Stone.none) {
          board[i][j] = Stone.white;
          if (_checkWinWithoutHighlight(i, j, Stone.white)) {
            board[i][j] = Stone.none;
            return [i, j];
          }
          board[i][j] = Stone.none;
        }
      }
    }

    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == Stone.none) {
          board[i][j] = Stone.black;
          if (_checkWinWithoutHighlight(i, j, Stone.black)) {
            board[i][j] = Stone.none;
            return [i, j];
          }
          board[i][j] = Stone.none;
        }
      }
    }

    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == Stone.none) {
          int score = _evaluatePosition(i, j);
          if (score > bestScore) {
            bestScore = score;
            bestMove = [i, j];
          }
        }
      }
    }

    return bestMove;
  }

  int _evaluatePosition(int row, int col) {
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

    score += _evaluateLineScore(row, col, Stone.white) * 3;
    score += _evaluateLineScore(row, col, Stone.black) * 2;

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
                children: [
                  _buildLegend(Colors.black, '당신 (흑)'),
                  const SizedBox(width: 32),
                  _buildLegend(Colors.white, '컴퓨터 (백)'),
                ],
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

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: color == Colors.white ? Border.all(color: Colors.grey) : null,
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
