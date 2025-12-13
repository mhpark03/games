import 'package:flutter/material.dart';

enum JanggiPieceType { gung, cha, po, ma, sang, sa, byung }

enum JanggiColor { cho, han }

class JanggiPiece {
  final JanggiPieceType type;
  final JanggiColor color;

  JanggiPiece(this.type, this.color);

  String get displayName {
    switch (type) {
      case JanggiPieceType.gung:
        return color == JanggiColor.cho ? '초' : '한';
      case JanggiPieceType.cha:
        return '차';
      case JanggiPieceType.po:
        return '포';
      case JanggiPieceType.ma:
        return '마';
      case JanggiPieceType.sang:
        return '상';
      case JanggiPieceType.sa:
        return '사';
      case JanggiPieceType.byung:
        return color == JanggiColor.cho ? '졸' : '병';
    }
  }
}

enum JanggiGameMode { vsCho, vsHan, vsHuman }

class JanggiScreen extends StatefulWidget {
  final JanggiGameMode gameMode;

  const JanggiScreen({super.key, required this.gameMode});

  @override
  State<JanggiScreen> createState() => _JanggiScreenState();
}

class _JanggiScreenState extends State<JanggiScreen> {
  // 9열 x 10행 보드
  late List<List<JanggiPiece?>> board;
  JanggiColor currentTurn = JanggiColor.cho;
  int? selectedRow;
  int? selectedCol;
  List<List<int>>? validMoves;
  bool isGameOver = false;
  String? winner;
  bool isThinking = false;

  @override
  void initState() {
    super.initState();
    _initBoard();

    // 컴퓨터가 초(선공)인 경우 첫 수 두기
    if (widget.gameMode == JanggiGameMode.vsCho) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _makeComputerMove();
      });
    }
  }

  void _initBoard() {
    board = List.generate(10, (_) => List.filled(9, null));

    // 한(상단) 배치
    board[0][0] = JanggiPiece(JanggiPieceType.cha, JanggiColor.han);
    board[0][1] = JanggiPiece(JanggiPieceType.sang, JanggiColor.han);
    board[0][2] = JanggiPiece(JanggiPieceType.ma, JanggiColor.han);
    board[0][3] = JanggiPiece(JanggiPieceType.sa, JanggiColor.han);
    board[0][5] = JanggiPiece(JanggiPieceType.sa, JanggiColor.han);
    board[0][6] = JanggiPiece(JanggiPieceType.sang, JanggiColor.han);
    board[0][7] = JanggiPiece(JanggiPieceType.ma, JanggiColor.han);
    board[0][8] = JanggiPiece(JanggiPieceType.cha, JanggiColor.han);
    board[1][4] = JanggiPiece(JanggiPieceType.gung, JanggiColor.han);
    board[2][1] = JanggiPiece(JanggiPieceType.po, JanggiColor.han);
    board[2][7] = JanggiPiece(JanggiPieceType.po, JanggiColor.han);
    board[3][0] = JanggiPiece(JanggiPieceType.byung, JanggiColor.han);
    board[3][2] = JanggiPiece(JanggiPieceType.byung, JanggiColor.han);
    board[3][4] = JanggiPiece(JanggiPieceType.byung, JanggiColor.han);
    board[3][6] = JanggiPiece(JanggiPieceType.byung, JanggiColor.han);
    board[3][8] = JanggiPiece(JanggiPieceType.byung, JanggiColor.han);

    // 초(하단) 배치
    board[9][0] = JanggiPiece(JanggiPieceType.cha, JanggiColor.cho);
    board[9][1] = JanggiPiece(JanggiPieceType.sang, JanggiColor.cho);
    board[9][2] = JanggiPiece(JanggiPieceType.ma, JanggiColor.cho);
    board[9][3] = JanggiPiece(JanggiPieceType.sa, JanggiColor.cho);
    board[9][5] = JanggiPiece(JanggiPieceType.sa, JanggiColor.cho);
    board[9][6] = JanggiPiece(JanggiPieceType.sang, JanggiColor.cho);
    board[9][7] = JanggiPiece(JanggiPieceType.ma, JanggiColor.cho);
    board[9][8] = JanggiPiece(JanggiPieceType.cha, JanggiColor.cho);
    board[8][4] = JanggiPiece(JanggiPieceType.gung, JanggiColor.cho);
    board[7][1] = JanggiPiece(JanggiPieceType.po, JanggiColor.cho);
    board[7][7] = JanggiPiece(JanggiPieceType.po, JanggiColor.cho);
    board[6][0] = JanggiPiece(JanggiPieceType.byung, JanggiColor.cho);
    board[6][2] = JanggiPiece(JanggiPieceType.byung, JanggiColor.cho);
    board[6][4] = JanggiPiece(JanggiPieceType.byung, JanggiColor.cho);
    board[6][6] = JanggiPiece(JanggiPieceType.byung, JanggiColor.cho);
    board[6][8] = JanggiPiece(JanggiPieceType.byung, JanggiColor.cho);
  }

  bool _isInPalace(int row, int col, JanggiColor color) {
    if (color == JanggiColor.han) {
      return row >= 0 && row <= 2 && col >= 3 && col <= 5;
    } else {
      return row >= 7 && row <= 9 && col >= 3 && col <= 5;
    }
  }

  bool _isInEnemyPalace(int row, int col, JanggiColor color) {
    if (color == JanggiColor.cho) {
      return row >= 0 && row <= 2 && col >= 3 && col <= 5;
    } else {
      return row >= 7 && row <= 9 && col >= 3 && col <= 5;
    }
  }

  List<List<int>> _getValidMoves(int row, int col) {
    final piece = board[row][col];
    if (piece == null) return [];

    List<List<int>> moves = [];

    switch (piece.type) {
      case JanggiPieceType.gung:
      case JanggiPieceType.sa:
        moves = _getGungSaMoves(row, col, piece);
        break;
      case JanggiPieceType.cha:
        moves = _getChaMoves(row, col, piece);
        break;
      case JanggiPieceType.po:
        moves = _getPoMoves(row, col, piece);
        break;
      case JanggiPieceType.ma:
        moves = _getMaMoves(row, col, piece);
        break;
      case JanggiPieceType.sang:
        moves = _getSangMoves(row, col, piece);
        break;
      case JanggiPieceType.byung:
        moves = _getByungMoves(row, col, piece);
        break;
    }

    return moves;
  }

  List<List<int>> _getGungSaMoves(int row, int col, JanggiPiece piece) {
    List<List<int>> moves = [];
    final directions = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1]
    ];

    // 궁성 대각선 이동 (중앙과 모서리)
    bool canDiagonal = false;
    if (piece.color == JanggiColor.cho) {
      canDiagonal = (row == 8 && col == 4) ||
          (row == 7 && col == 3) ||
          (row == 7 && col == 5) ||
          (row == 9 && col == 3) ||
          (row == 9 && col == 5);
    } else {
      canDiagonal = (row == 1 && col == 4) ||
          (row == 0 && col == 3) ||
          (row == 0 && col == 5) ||
          (row == 2 && col == 3) ||
          (row == 2 && col == 5);
    }

    if (canDiagonal) {
      directions.addAll([
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1]
      ]);
    }

    for (var dir in directions) {
      int newRow = row + dir[0];
      int newCol = col + dir[1];

      if (newRow >= 0 &&
          newRow < 10 &&
          newCol >= 0 &&
          newCol < 9 &&
          _isInPalace(newRow, newCol, piece.color)) {
        final target = board[newRow][newCol];
        if (target == null || target.color != piece.color) {
          moves.add([newRow, newCol]);
        }
      }
    }

    return moves;
  }

  List<List<int>> _getChaMoves(int row, int col, JanggiPiece piece) {
    List<List<int>> moves = [];
    final directions = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1]
    ];

    for (var dir in directions) {
      int newRow = row + dir[0];
      int newCol = col + dir[1];

      while (newRow >= 0 && newRow < 10 && newCol >= 0 && newCol < 9) {
        final target = board[newRow][newCol];
        if (target == null) {
          moves.add([newRow, newCol]);
        } else if (target.color != piece.color) {
          moves.add([newRow, newCol]);
          break;
        } else {
          break;
        }
        newRow += dir[0];
        newCol += dir[1];
      }
    }

    // 궁성 내 대각선 이동
    _addPalaceDiagonalMoves(moves, row, col, piece, false);

    return moves;
  }

  List<List<int>> _getPoMoves(int row, int col, JanggiPiece piece) {
    List<List<int>> moves = [];
    final directions = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1]
    ];

    for (var dir in directions) {
      int newRow = row + dir[0];
      int newCol = col + dir[1];
      bool jumped = false;

      while (newRow >= 0 && newRow < 10 && newCol >= 0 && newCol < 9) {
        final target = board[newRow][newCol];
        if (!jumped) {
          if (target != null && target.type != JanggiPieceType.po) {
            jumped = true;
          }
        } else {
          if (target == null) {
            moves.add([newRow, newCol]);
          } else if (target.type == JanggiPieceType.po) {
            break;
          } else if (target.color != piece.color) {
            moves.add([newRow, newCol]);
            break;
          } else {
            break;
          }
        }
        newRow += dir[0];
        newCol += dir[1];
      }
    }

    return moves;
  }

  List<List<int>> _getMaMoves(int row, int col, JanggiPiece piece) {
    List<List<int>> moves = [];
    final steps = [
      [
        [-1, 0],
        [-2, -1]
      ],
      [
        [-1, 0],
        [-2, 1]
      ],
      [
        [1, 0],
        [2, -1]
      ],
      [
        [1, 0],
        [2, 1]
      ],
      [
        [0, -1],
        [-1, -2]
      ],
      [
        [0, -1],
        [1, -2]
      ],
      [
        [0, 1],
        [-1, 2]
      ],
      [
        [0, 1],
        [1, 2]
      ],
    ];

    for (var step in steps) {
      int midRow = row + step[0][0];
      int midCol = col + step[0][1];

      if (midRow >= 0 &&
          midRow < 10 &&
          midCol >= 0 &&
          midCol < 9 &&
          board[midRow][midCol] == null) {
        int newRow = row + step[1][0];
        int newCol = col + step[1][1];

        if (newRow >= 0 && newRow < 10 && newCol >= 0 && newCol < 9) {
          final target = board[newRow][newCol];
          if (target == null || target.color != piece.color) {
            moves.add([newRow, newCol]);
          }
        }
      }
    }

    return moves;
  }

  List<List<int>> _getSangMoves(int row, int col, JanggiPiece piece) {
    List<List<int>> moves = [];
    final steps = [
      [
        [-1, 0],
        [-2, -1],
        [-3, -2]
      ],
      [
        [-1, 0],
        [-2, 1],
        [-3, 2]
      ],
      [
        [1, 0],
        [2, -1],
        [3, -2]
      ],
      [
        [1, 0],
        [2, 1],
        [3, 2]
      ],
      [
        [0, -1],
        [-1, -2],
        [-2, -3]
      ],
      [
        [0, -1],
        [1, -2],
        [2, -3]
      ],
      [
        [0, 1],
        [-1, 2],
        [-2, 3]
      ],
      [
        [0, 1],
        [1, 2],
        [2, 3]
      ],
    ];

    for (var step in steps) {
      int mid1Row = row + step[0][0];
      int mid1Col = col + step[0][1];
      int mid2Row = row + step[1][0];
      int mid2Col = col + step[1][1];
      int newRow = row + step[2][0];
      int newCol = col + step[2][1];

      if (mid1Row >= 0 &&
          mid1Row < 10 &&
          mid1Col >= 0 &&
          mid1Col < 9 &&
          board[mid1Row][mid1Col] == null &&
          mid2Row >= 0 &&
          mid2Row < 10 &&
          mid2Col >= 0 &&
          mid2Col < 9 &&
          board[mid2Row][mid2Col] == null &&
          newRow >= 0 &&
          newRow < 10 &&
          newCol >= 0 &&
          newCol < 9) {
        final target = board[newRow][newCol];
        if (target == null || target.color != piece.color) {
          moves.add([newRow, newCol]);
        }
      }
    }

    return moves;
  }

  List<List<int>> _getByungMoves(int row, int col, JanggiPiece piece) {
    List<List<int>> moves = [];
    List<List<int>> directions;

    if (piece.color == JanggiColor.cho) {
      directions = [
        [-1, 0],
        [0, -1],
        [0, 1]
      ];
    } else {
      directions = [
        [1, 0],
        [0, -1],
        [0, 1]
      ];
    }

    // 상대 궁성 내에서 대각선 이동 가능
    if (_isInEnemyPalace(row, col, piece.color)) {
      if (piece.color == JanggiColor.cho) {
        if ((row == 2 && col == 4) ||
            (row == 1 && col == 3) ||
            (row == 1 && col == 5)) {
          directions.add([-1, -1]);
          directions.add([-1, 1]);
        }
      } else {
        if ((row == 7 && col == 4) ||
            (row == 8 && col == 3) ||
            (row == 8 && col == 5)) {
          directions.add([1, -1]);
          directions.add([1, 1]);
        }
      }
    }

    for (var dir in directions) {
      int newRow = row + dir[0];
      int newCol = col + dir[1];

      if (newRow >= 0 && newRow < 10 && newCol >= 0 && newCol < 9) {
        final target = board[newRow][newCol];
        if (target == null || target.color != piece.color) {
          moves.add([newRow, newCol]);
        }
      }
    }

    return moves;
  }

  void _addPalaceDiagonalMoves(
      List<List<int>> moves, int row, int col, JanggiPiece piece, bool isPo) {
    // 궁성 중앙에서 대각선 이동
    List<List<int>> diagonals = [];

    // 초 궁성
    if ((row == 8 && col == 4)) {
      diagonals = [
        [7, 3],
        [7, 5],
        [9, 3],
        [9, 5]
      ];
    } else if ((row == 7 && col == 3) ||
        (row == 7 && col == 5) ||
        (row == 9 && col == 3) ||
        (row == 9 && col == 5)) {
      diagonals = [
        [8, 4]
      ];
    }
    // 한 궁성
    else if ((row == 1 && col == 4)) {
      diagonals = [
        [0, 3],
        [0, 5],
        [2, 3],
        [2, 5]
      ];
    } else if ((row == 0 && col == 3) ||
        (row == 0 && col == 5) ||
        (row == 2 && col == 3) ||
        (row == 2 && col == 5)) {
      diagonals = [
        [1, 4]
      ];
    }

    for (var diag in diagonals) {
      final target = board[diag[0]][diag[1]];
      if (target == null || target.color != piece.color) {
        if (!isPo || target?.type != JanggiPieceType.po) {
          moves.add(diag);
        }
      }
    }
  }

  void _onTap(int row, int col) {
    if (isGameOver || isThinking) return;

    // 컴퓨터 턴인 경우 무시
    if ((widget.gameMode == JanggiGameMode.vsCho &&
            currentTurn == JanggiColor.cho) ||
        (widget.gameMode == JanggiGameMode.vsHan &&
            currentTurn == JanggiColor.han)) {
      return;
    }

    setState(() {
      if (selectedRow != null && selectedCol != null) {
        // 이미 선택된 말이 있는 경우
        if (validMoves != null &&
            validMoves!.any((m) => m[0] == row && m[1] == col)) {
          // 유효한 이동
          _movePiece(selectedRow!, selectedCol!, row, col);
          selectedRow = null;
          selectedCol = null;
          validMoves = null;
        } else if (board[row][col]?.color == currentTurn) {
          // 같은 색 다른 말 선택
          selectedRow = row;
          selectedCol = col;
          validMoves = _getValidMoves(row, col);
        } else {
          selectedRow = null;
          selectedCol = null;
          validMoves = null;
        }
      } else {
        // 새로운 말 선택
        if (board[row][col]?.color == currentTurn) {
          selectedRow = row;
          selectedCol = col;
          validMoves = _getValidMoves(row, col);
        }
      }
    });
  }

  void _movePiece(int fromRow, int fromCol, int toRow, int toCol) {
    final capturedPiece = board[toRow][toCol];

    board[toRow][toCol] = board[fromRow][fromCol];
    board[fromRow][fromCol] = null;

    // 궁 잡힘 체크
    if (capturedPiece?.type == JanggiPieceType.gung) {
      isGameOver = true;
      winner = currentTurn == JanggiColor.cho ? '초' : '한';
    }

    currentTurn =
        currentTurn == JanggiColor.cho ? JanggiColor.han : JanggiColor.cho;

    // 컴퓨터 턴
    if (!isGameOver && widget.gameMode != JanggiGameMode.vsHuman) {
      if ((widget.gameMode == JanggiGameMode.vsCho &&
              currentTurn == JanggiColor.cho) ||
          (widget.gameMode == JanggiGameMode.vsHan &&
              currentTurn == JanggiColor.han)) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _makeComputerMove();
        });
      }
    }
  }

  void _makeComputerMove() {
    if (isGameOver) return;

    setState(() {
      isThinking = true;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      JanggiColor computerColor =
          widget.gameMode == JanggiGameMode.vsCho
              ? JanggiColor.cho
              : JanggiColor.han;

      List<Map<String, dynamic>> allMoves = [];

      // 모든 가능한 수 수집
      for (int r = 0; r < 10; r++) {
        for (int c = 0; c < 9; c++) {
          final piece = board[r][c];
          if (piece != null && piece.color == computerColor) {
            final moves = _getValidMoves(r, c);
            for (var move in moves) {
              int score = _evaluateMove(r, c, move[0], move[1], piece);
              allMoves.add({
                'fromRow': r,
                'fromCol': c,
                'toRow': move[0],
                'toCol': move[1],
                'score': score,
              });
            }
          }
        }
      }

      if (allMoves.isEmpty) {
        setState(() {
          isThinking = false;
          isGameOver = true;
          winner = computerColor == JanggiColor.cho ? '한' : '초';
        });
        return;
      }

      // 최고 점수 수 선택
      allMoves.sort((a, b) => b['score'].compareTo(a['score']));

      // 상위 수 중에서 랜덤 선택 (같은 점수인 경우)
      int topScore = allMoves[0]['score'];
      var topMoves = allMoves.where((m) => m['score'] == topScore).toList();
      var bestMove = topMoves[(topMoves.length * (DateTime.now().millisecond / 1000)).floor() % topMoves.length];

      setState(() {
        isThinking = false;
        _movePiece(
            bestMove['fromRow'], bestMove['fromCol'], bestMove['toRow'], bestMove['toCol']);
      });
    });
  }

  int _evaluateMove(int fromRow, int fromCol, int toRow, int toCol, JanggiPiece piece) {
    int score = 0;
    final target = board[toRow][toCol];

    // 상대 말 잡기
    if (target != null) {
      switch (target.type) {
        case JanggiPieceType.gung:
          score += 10000;
          break;
        case JanggiPieceType.cha:
          score += 1300;
          break;
        case JanggiPieceType.po:
          score += 700;
          break;
        case JanggiPieceType.ma:
          score += 500;
          break;
        case JanggiPieceType.sang:
          score += 500;
          break;
        case JanggiPieceType.sa:
          score += 300;
          break;
        case JanggiPieceType.byung:
          score += 200;
          break;
      }
    }

    // 중앙으로 이동 선호
    int centerCol = 4;
    score += (4 - (toCol - centerCol).abs()) * 5;

    // 졸/병: 전진 선호
    if (piece.type == JanggiPieceType.byung) {
      if (piece.color == JanggiColor.cho) {
        score += (9 - toRow) * 10;
      } else {
        score += toRow * 10;
      }
    }

    // 궁/사: 궁성 중앙 선호
    if (piece.type == JanggiPieceType.gung || piece.type == JanggiPieceType.sa) {
      if (toCol == 4) score += 20;
    }

    return score;
  }

  void _resetGame() {
    setState(() {
      _initBoard();
      currentTurn = JanggiColor.cho;
      selectedRow = null;
      selectedCol = null;
      validMoves = null;
      isGameOver = false;
      winner = null;
      isThinking = false;
    });

    if (widget.gameMode == JanggiGameMode.vsCho) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _makeComputerMove();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('장기'),
        backgroundColor: const Color(0xFFD2691E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetGame,
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5DEB3),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusBar(),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 10,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    child: _buildBoard(),
                  ),
                ),
              ),
            ),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    String status;
    if (isGameOver) {
      status = '$winner 승리!';
    } else if (isThinking) {
      status = '컴퓨터 생각 중...';
    } else {
      status = '${currentTurn == JanggiColor.cho ? "초" : "한"} 차례';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: const Color(0xFFD2691E),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: currentTurn == JanggiColor.cho
                  ? const Color(0xFF006400)
                  : const Color(0xFFB22222),
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFDEB887),
        border: Border.all(color: const Color(0xFF8B4513), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth / 9;
          final cellHeight = constraints.maxHeight / 10;

          return Stack(
            children: [
              // 선 그리기
              CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: JanggiBoardPainter(cellWidth, cellHeight),
              ),
              // 말 그리기
              ...List.generate(10, (row) {
                return List.generate(9, (col) {
                  return Positioned(
                    left: col * cellWidth,
                    top: row * cellHeight,
                    width: cellWidth,
                    height: cellHeight,
                    child: GestureDetector(
                      onTap: () => _onTap(row, col),
                      child: _buildCell(row, col, cellWidth, cellHeight),
                    ),
                  );
                });
              }).expand((e) => e),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCell(int row, int col, double cellWidth, double cellHeight) {
    final piece = board[row][col];
    final isSelected = selectedRow == row && selectedCol == col;
    final isValidMove =
        validMoves?.any((m) => m[0] == row && m[1] == col) ?? false;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.yellow.withAlpha(128)
            : isValidMove
                ? Colors.green.withAlpha(77)
                : Colors.transparent,
      ),
      child: Center(
        child: piece != null
            ? _buildPiece(piece, cellWidth * 0.85, cellHeight * 0.85)
            : isValidMove
                ? Container(
                    width: cellWidth * 0.3,
                    height: cellHeight * 0.3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withAlpha(179),
                    ),
                  )
                : null,
      ),
    );
  }

  Widget _buildPiece(JanggiPiece piece, double width, double height) {
    final isGung = piece.type == JanggiPieceType.gung;
    final size = isGung ? width * 0.95 : width * 0.85;
    final Color pieceColor = piece.color == JanggiColor.cho
        ? const Color(0xFF006400)
        : const Color(0xFFB22222);
    final Color bgColor = piece.color == JanggiColor.cho
        ? const Color(0xFF90EE90)
        : const Color(0xFFFFB6C1);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(
          color: pieceColor,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          piece.displayName,
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
            color: pieceColor,
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFD2691E).withAlpha(51),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem('초', JanggiColor.cho),
          const Text(
            'VS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          _buildLegendItem('한', JanggiColor.han),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, JanggiColor color) {
    final pieceColor = color == JanggiColor.cho
        ? const Color(0xFF006400)
        : const Color(0xFFB22222);
    final bgColor = color == JanggiColor.cho
        ? const Color(0xFF90EE90)
        : const Color(0xFFFFB6C1);

    bool isCurrentPlayer = false;
    if (widget.gameMode == JanggiGameMode.vsHuman) {
      isCurrentPlayer = true;
    } else if (widget.gameMode == JanggiGameMode.vsCho) {
      isCurrentPlayer = color == JanggiColor.han;
    } else {
      isCurrentPlayer = color == JanggiColor.cho;
    }

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(color: pieceColor, width: 2),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: pieceColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isCurrentPlayer ? '플레이어' : '컴퓨터',
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}

class JanggiBoardPainter extends CustomPainter {
  final double cellWidth;
  final double cellHeight;

  JanggiBoardPainter(this.cellWidth, this.cellHeight);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B4513)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // 가로선 (10줄 -> 교차점 기준)
    for (int i = 0; i < 10; i++) {
      final y = i * cellHeight + cellHeight / 2;
      canvas.drawLine(
        Offset(cellWidth / 2, y),
        Offset(size.width - cellWidth / 2, y),
        paint,
      );
    }

    // 세로선 (9줄)
    for (int i = 0; i < 9; i++) {
      final x = i * cellWidth + cellWidth / 2;
      canvas.drawLine(
        Offset(x, cellHeight / 2),
        Offset(x, size.height - cellHeight / 2),
        paint,
      );
    }

    // 궁성 대각선 (상단 - 한)
    final palace1Paint = Paint()
      ..color = const Color(0xFF8B4513)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // 상단 궁성
    canvas.drawLine(
      Offset(3 * cellWidth + cellWidth / 2, cellHeight / 2),
      Offset(5 * cellWidth + cellWidth / 2, 2 * cellHeight + cellHeight / 2),
      palace1Paint,
    );
    canvas.drawLine(
      Offset(5 * cellWidth + cellWidth / 2, cellHeight / 2),
      Offset(3 * cellWidth + cellWidth / 2, 2 * cellHeight + cellHeight / 2),
      palace1Paint,
    );

    // 하단 궁성
    canvas.drawLine(
      Offset(3 * cellWidth + cellWidth / 2, 7 * cellHeight + cellHeight / 2),
      Offset(5 * cellWidth + cellWidth / 2, 9 * cellHeight + cellHeight / 2),
      palace1Paint,
    );
    canvas.drawLine(
      Offset(5 * cellWidth + cellWidth / 2, 7 * cellHeight + cellHeight / 2),
      Offset(3 * cellWidth + cellWidth / 2, 9 * cellHeight + cellHeight / 2),
      palace1Paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
