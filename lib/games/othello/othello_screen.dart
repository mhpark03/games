import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/game_save_service.dart';
import '../../services/ad_service.dart';

enum Disc { none, black, white }

enum OthelloGameMode {
  vsComputerWhite, // 사용자 흑돌(선공), 컴퓨터 백돌
  vsComputerBlack, // 컴퓨터 흑돌(선공), 사용자 백돌
  vsPerson,        // 2인 플레이
}

enum OthelloDifficulty {
  easy,   // 쉬움
  medium, // 보통
  hard,   // 어려움
}

class OthelloScreen extends StatefulWidget {
  final OthelloGameMode gameMode;
  final OthelloDifficulty difficulty;
  final bool resumeGame;

  const OthelloScreen({
    super.key,
    this.gameMode = OthelloGameMode.vsComputerWhite,
    this.difficulty = OthelloDifficulty.medium,
    this.resumeGame = false,
  });

  static Future<bool> hasSavedGame() async {
    return await GameSaveService.hasSavedGame('othello');
  }

  static Future<OthelloGameMode?> getSavedGameMode() async {
    final gameState = await GameSaveService.loadGame('othello');
    if (gameState == null) return null;
    final modeIndex = gameState['gameMode'] as int?;
    if (modeIndex == null) return null;
    return OthelloGameMode.values[modeIndex];
  }

  static Future<OthelloDifficulty?> getSavedDifficulty() async {
    final gameState = await GameSaveService.loadGame('othello');
    if (gameState == null) return null;
    final difficultyIndex = gameState['difficulty'] as int?;
    if (difficultyIndex == null) return OthelloDifficulty.medium; // 기본값
    return OthelloDifficulty.values[difficultyIndex];
  }

  static Future<void> clearSavedGame() async {
    await GameSaveService.clearSave();
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
  // 수 히스토리: {row, col, disc, flippedDiscs}
  List<Map<String, dynamic>> moveHistory = [];

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
    moveHistory = [];
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

    final boardData = board.map((row) => row.map((d) => d.index).toList()).toList();

    final gameState = {
      'board': boardData,
      'isBlackTurn': isBlackTurn,
      'gameMode': widget.gameMode.index,
      'difficulty': widget.difficulty.index,
    };

    await GameSaveService.saveGame('othello', gameState);
  }

  Future<void> _loadGame() async {
    final gameState = await GameSaveService.loadGame('othello');

    if (gameState == null) {
      _initBoard();
      return;
    }

    final boardData = gameState['board'] as List;
    board = boardData
        .map<List<Disc>>((row) => (row as List)
            .map<Disc>((d) => Disc.values[d as int])
            .toList())
        .toList();

    isBlackTurn = gameState['isBlackTurn'] as bool? ?? true;
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

  // 되돌리기 광고 확인 다이얼로그
  void _showUndoAdDialog() {
    if (moveHistory.isEmpty || gameOver) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('되돌리기', style: TextStyle(color: Colors.white)),
        content: const Text(
          '광고를 시청하고 되돌리기를 사용하시겠습니까?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final adService = AdService();
              final result = await adService.showRewardedAd(
                onUserEarnedReward: (ad, reward) {
                  _undoMove();
                },
              );
              if (!result && mounted) {
                // 광고가 없어도 기능 실행
                _undoMove();
                adService.loadRewardedAd();
              }
            },
            child: const Text('광고 보기'),
          ),
        ],
      ),
    );
  }

  // 되돌리기 기능
  void _undoMove() {
    if (moveHistory.isEmpty || gameOver) return;

    setState(() {
      // 컴퓨터 대전 모드에서는 2수 되돌리기 (사용자 + 컴퓨터)
      int undoCount = widget.gameMode == OthelloGameMode.vsPerson ? 1 : 2;

      for (int i = 0; i < undoCount && moveHistory.isNotEmpty; i++) {
        final lastMove = moveHistory.removeLast();
        final row = lastMove['row'] as int;
        final col = lastMove['col'] as int;
        final disc = lastMove['disc'] as Disc;
        final flippedDiscs = lastMove['flippedDiscs'] as List<List<int>>;

        // 놓은 돌 제거
        board[row][col] = Disc.none;

        // 뒤집힌 돌 복원
        final opponentDisc = disc == Disc.black ? Disc.white : Disc.black;
        for (var pos in flippedDiscs) {
          board[pos[0]][pos[1]] = opponentDisc;
        }

        // 점수 복원
        if (disc == Disc.black) {
          blackCount -= 1 + flippedDiscs.length;
          whiteCount += flippedDiscs.length;
        } else {
          whiteCount -= 1 + flippedDiscs.length;
          blackCount += flippedDiscs.length;
        }

        // 턴 복원
        isBlackTurn = !isBlackTurn;
      }

      _updateValidMoves();
      _updateMessage();
    });

    _saveGame();
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

    // 히스토리에 저장
    moveHistory.add({
      'row': row,
      'col': col,
      'disc': disc,
      'flippedDiscs': flipped,
    });

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

  final Random _random = Random();

  void _computerMove() {
    if (gameOver || validMoves.isEmpty) return;

    List<int>? bestMove;

    switch (widget.difficulty) {
      case OthelloDifficulty.easy:
        bestMove = _findMoveEasy();
        break;
      case OthelloDifficulty.medium:
        bestMove = _findMoveMedium();
        break;
      case OthelloDifficulty.hard:
        bestMove = _findMoveHard();
        break;
    }

    bestMove ??= validMoves.first;
    _makeMove(bestMove[0], bestMove[1]);

    if (!gameOver && widget.gameMode != OthelloGameMode.vsPerson && !isUserTurn) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _computerMove();
      });
    }
  }

  // 쉬움 난이도: 랜덤 요소 추가, 코너 등 전략적 위치 무시
  List<int>? _findMoveEasy() {
    // 40% 확률로 완전 랜덤 수
    if (_random.nextDouble() < 0.4) {
      return validMoves[_random.nextInt(validMoves.length)];
    }

    // 단순히 가장 많이 뒤집는 수 선택 (전략적 위치 고려 안 함)
    List<int>? bestMove;
    int bestScore = -1;

    for (var move in validMoves) {
      int score = _getFlippedDiscs(move[0], move[1], currentPlayerDisc).length;
      // 노이즈 추가
      score += _random.nextInt(3);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }

  // 보통 난이도: 기존 AI (코너 우선, 코너 옆 회피)
  List<int>? _findMoveMedium() {
    List<int>? bestMove;
    int bestScore = -9999;

    // 코너 우선
    final corners = [[0, 0], [0, 7], [7, 0], [7, 7]];
    for (var corner in corners) {
      if (validMoves.any((m) => m[0] == corner[0] && m[1] == corner[1])) {
        return corner;
      }
    }

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

    return bestMove;
  }

  // 어려움 난이도: 위치 가중치 + 안정성 고려
  List<int>? _findMoveHard() {
    // 위치별 가중치 (코너 최고, 코너 옆 최악)
    final weights = [
      [100, -20, 10,  5,  5, 10, -20, 100],
      [-20, -50, -2, -2, -2, -2, -50, -20],
      [ 10,  -2,  5,  1,  1,  5,  -2,  10],
      [  5,  -2,  1,  0,  0,  1,  -2,   5],
      [  5,  -2,  1,  0,  0,  1,  -2,   5],
      [ 10,  -2,  5,  1,  1,  5,  -2,  10],
      [-20, -50, -2, -2, -2, -2, -50, -20],
      [100, -20, 10,  5,  5, 10, -20, 100],
    ];

    List<int>? bestMove;
    int bestScore = -10000;

    for (var move in validMoves) {
      int row = move[0];
      int col = move[1];

      // 위치 가중치
      int score = weights[row][col];

      // 뒤집는 돌 수
      int flippedCount = _getFlippedDiscs(row, col, currentPlayerDisc).length;
      score += flippedCount * 2;

      // 코너 확보 보너스
      if (_isCorner(row, col)) {
        score += 50;
      }

      // 가장자리 선호
      if (_isEdge(row, col) && !_isNearCorner(row, col)) {
        score += 5;
      }

      // 안정적인 돌 보너스 (코너에서 연결된 돌)
      score += _countStableDiscs(row, col, currentPlayerDisc) * 10;

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }

  bool _isCorner(int row, int col) {
    return (row == 0 || row == 7) && (col == 0 || col == 7);
  }

  bool _isEdge(int row, int col) {
    return row == 0 || row == 7 || col == 0 || col == 7;
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

  // 안정적인 돌 수 계산 (코너에서 연결된 돌)
  int _countStableDiscs(int row, int col, Disc disc) {
    int stable = 0;

    // 코너 확인
    final cornerChecks = [
      {'corner': [0, 0], 'dirs': [[0, 1], [1, 0], [1, 1]]},
      {'corner': [0, 7], 'dirs': [[0, -1], [1, 0], [1, -1]]},
      {'corner': [7, 0], 'dirs': [[0, 1], [-1, 0], [-1, 1]]},
      {'corner': [7, 7], 'dirs': [[0, -1], [-1, 0], [-1, -1]]},
    ];

    for (var check in cornerChecks) {
      final corner = check['corner'] as List<int>;
      if (board[corner[0]][corner[1]] == disc) {
        // 코너가 같은 색이면 연결된 돌 수 확인
        final dirs = check['dirs'] as List<List<int>>;
        for (var dir in dirs) {
          int r = corner[0];
          int c = corner[1];
          while (r >= 0 && r < boardSize && c >= 0 && c < boardSize) {
            if (board[r][c] == disc) {
              if (r == row && c == col) stable++;
            } else {
              break;
            }
            r += dir[0];
            c += dir[1];
          }
        }
      }
    }

    return stable;
  }

  bool _isValidMovePosition(int row, int col) {
    return validMoves.any((m) => m[0] == row && m[1] == col);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return _buildLandscapeLayout(context);
        } else {
          return _buildPortraitLayout(context);
        }
      },
    );
  }

  // 세로 모드 레이아웃
  Widget _buildPortraitLayout(BuildContext context) {
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
            icon: const Icon(Icons.help_outline),
            onPressed: _showRulesDialog,
            tooltip: 'app.rules'.tr(),
          ),
          Opacity(
            opacity: moveHistory.isNotEmpty && !gameOver ? 1.0 : 0.3,
            child: IconButton(
              icon: const Icon(Icons.undo),
              onPressed: moveHistory.isNotEmpty && !gameOver ? _showUndoAdDialog : null,
              tooltip: 'common.undo'.tr(),
            ),
          ),
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
                  child: _buildGameBoard(),
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

  // 가로 모드 레이아웃
  Widget _buildLandscapeLayout(BuildContext context) {
    // 플레이어 정보 결정
    String blackPlayerName;
    String whitePlayerName;

    switch (widget.gameMode) {
      case OthelloGameMode.vsComputerWhite:
        blackPlayerName = '당신';
        whitePlayerName = '컴퓨터';
        break;
      case OthelloGameMode.vsComputerBlack:
        blackPlayerName = '컴퓨터';
        whitePlayerName = '당신';
        break;
      case OthelloGameMode.vsPerson:
        blackPlayerName = '흑';
        whitePlayerName = '백';
        break;
    }

    return Scaffold(
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
        child: SafeArea(
          child: Stack(
            children: [
              // 메인 영역: 플레이어 표시 + 게임 보드
              Row(
                children: [
                  // 왼쪽 패널: 흑돌 플레이어 (상하좌우 중앙)
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _buildPlayerIndicator(
                          isBlack: true,
                          playerName: blackPlayerName,
                          score: blackCount,
                          isCurrentTurn: isBlackTurn && !gameOver,
                        ),
                      ),
                    ),
                  ),
                  // 가운데: 게임 보드 (최대 크기)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.maxHeight;
                      return SizedBox(
                        width: size,
                        height: size,
                        child: _buildGameBoard(),
                      );
                    },
                  ),
                  // 오른쪽 패널: 백돌 플레이어 (상하좌우 중앙)
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _buildPlayerIndicator(
                          isBlack: false,
                          playerName: whitePlayerName,
                          score: whiteCount,
                          isCurrentTurn: !isBlackTurn && !gameOver,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // 왼쪽 상단: 뒤로가기 버튼 + 제목
              Positioned(
                top: 4,
                left: 4,
                child: Row(
                  children: [
                    _buildCircleButton(
                      icon: Icons.arrow_back,
                      onPressed: () => Navigator.pop(context),
                      tooltip: '뒤로가기',
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '오델로',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 오른쪽 상단: 되돌리기 + 새 게임 버튼
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  children: [
                    _buildCircleButton(
                      icon: Icons.undo,
                      onPressed: moveHistory.isNotEmpty && !gameOver ? _showUndoAdDialog : null,
                      tooltip: '되돌리기',
                    ),
                    const SizedBox(width: 8),
                    _buildCircleButton(
                      icon: Icons.refresh,
                      onPressed: _resetGame,
                      tooltip: '새 게임',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 원형 버튼 위젯
  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    final isEnabled = onPressed != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.3,
      child: Material(
        color: Colors.black.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Tooltip(
            message: tooltip,
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Icon(
                icon,
                color: Colors.white70,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 가로 모드용 플레이어 표시 위젯
  Widget _buildPlayerIndicator({
    required bool isBlack,
    required String playerName,
    required int score,
    required bool isCurrentTurn,
  }) {
    // 하이라이트 색상: 오델로는 teal 사용
    final highlightColor = Colors.teal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? highlightColor.withValues(alpha: 0.4)
            : Colors.grey.shade900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentTurn ? highlightColor : Colors.grey.shade700,
          width: isCurrentTurn ? 4 : 1,
        ),
        boxShadow: isCurrentTurn
            ? [
                BoxShadow(
                  color: highlightColor.withValues(alpha: 0.8),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.6),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 현재 턴일 때 돌 아이콘에도 강조 표시
          Container(
            padding: const EdgeInsets.all(6),
            decoration: isCurrentTurn
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: highlightColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: highlightColor.withValues(alpha: 0.6),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : null,
            child: _buildDiscIcon(isBlack, size: 48),
          ),
          const SizedBox(height: 8),
          // 점수 표시
          Text(
            '$score',
            style: TextStyle(
              color: isCurrentTurn ? Colors.white : Colors.grey.shade400,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            playerName,
            style: TextStyle(
              color: isCurrentTurn ? Colors.teal.shade100 : Colors.grey.shade500,
              fontSize: 16,
              fontWeight: isCurrentTurn ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isBlack ? '(흑)' : '(백)',
            style: TextStyle(
              color: isCurrentTurn ? Colors.teal.shade200 : Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          // 현재 턴 표시 텍스트 추가
          if (isCurrentTurn)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '차례',
                style: TextStyle(
                  color: highlightColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 돌 아이콘 위젯
  Widget _buildDiscIcon(bool isBlack, {double size = 20}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isBlack ? Colors.black : Colors.white,
        border: Border.all(
          color: isBlack ? Colors.grey.shade600 : Colors.grey,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
        gradient: RadialGradient(
          colors: isBlack
              ? [Colors.grey.shade600, Colors.black]
              : [Colors.white, Colors.grey.shade300],
          center: const Alignment(-0.3, -0.3),
        ),
      ),
    );
  }

  // 게임 보드 위젯
  Widget _buildGameBoard() {
    return Container(
      margin: const EdgeInsets.all(8),
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

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'games.othello.rulesTitle'.tr(),
          style: const TextStyle(color: Colors.green),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                '🎯 게임 목표',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '게임이 끝났을 때 자신의 돌이\n'
                '더 많으면 승리합니다!',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '🎮 게임 방법',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• 흑이 먼저 시작합니다\n'
                '• 상대 돌을 자신의 돌 사이에 끼워\n'
                '  뒤집을 수 있는 곳에만 놓을 수 있습니다\n'
                '• 놓을 곳이 없으면 턴을 넘깁니다',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '🔄 뒤집기 규칙',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• 가로, 세로, 대각선 모든 방향 가능\n'
                '• 한 번에 여러 방향 뒤집기 가능\n'
                '• 반드시 1개 이상 뒤집어야 놓을 수 있음',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '💡 전략 팁',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• 코너를 차지하면 절대 뒤집히지 않습니다\n'
                '• 가장자리도 유리한 위치입니다\n'
                '• 중반까지는 적게 뒤집는 게 유리할 수 있음',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('app.confirm'.tr()),
          ),
        ],
      ),
    );
  }
}
