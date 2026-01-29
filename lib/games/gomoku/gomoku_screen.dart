import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/game_save_service.dart';
import '../../services/ad_service.dart';
import '../../services/input_sdk_service.dart';

enum Stone { none, black, white }

enum GameMode {
  vsComputerWhite, // 사용자 흑돌(선공), 컴퓨터 백돌
  vsComputerBlack, // 컴퓨터 흑돌(선공), 사용자 백돌
  vsPerson,        // 2인 플레이
}

enum Difficulty {
  easy,   // 쉬움
  medium, // 보통
  hard,   // 어려움
}

class GomokuScreen extends StatefulWidget {
  final GameMode gameMode;
  final Difficulty difficulty;
  final bool resumeGame; // 이어하기 여부

  const GomokuScreen({
    super.key,
    this.gameMode = GameMode.vsComputerWhite,
    this.difficulty = Difficulty.medium,
    this.resumeGame = false,
  });

  // 저장된 게임이 있는지 확인
  static Future<bool> hasSavedGame() async {
    return await GameSaveService.hasSavedGame('gomoku');
  }

  // 저장된 게임 모드 가져오기
  static Future<GameMode?> getSavedGameMode() async {
    final gameState = await GameSaveService.loadGame('gomoku');
    if (gameState == null) return null;
    final modeIndex = gameState['gameMode'] as int?;
    if (modeIndex == null) return null;
    return GameMode.values[modeIndex];
  }

  // 저장된 난이도 가져오기
  static Future<Difficulty?> getSavedDifficulty() async {
    final gameState = await GameSaveService.loadGame('gomoku');
    if (gameState == null) return null;
    final difficultyIndex = gameState['difficulty'] as int?;
    if (difficultyIndex == null) return Difficulty.medium; // 기본값
    return Difficulty.values[difficultyIndex];
  }

  // 저장된 게임 삭제
  static Future<void> clearSavedGame() async {
    await GameSaveService.clearSave();
  }

  @override
  State<GomokuScreen> createState() => _GomokuScreenState();
}

class _GomokuScreenState extends State<GomokuScreen> {
  static const int boardSize = 15;
  List<List<Stone>> board = List.generate(
    boardSize,
    (_) => List.generate(boardSize, (_) => Stone.none),
  );
  bool isBlackTurn = true; // 흑돌 차례 여부
  bool gameOver = false;
  String gameMessage = '';
  List<List<int>>? winningStones;
  int? lastMoveRow; // 마지막 수 행
  int? lastMoveCol; // 마지막 수 열
  List<List<int>> moveHistory = []; // 수 히스토리 (되돌리기용)

  // 확대/축소 컨트롤러
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;

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
    InputSdkService.setBoardGameContext();
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
    lastMoveRow = null;
    lastMoveCol = null;
    moveHistory = [];
    _updateMessage();

    // 컴퓨터(흑) 모드일 때 컴퓨터가 먼저 둠
    if (widget.gameMode == GameMode.vsComputerBlack) {
      gameMessage = 'games.gomoku.computerThinking'.tr();
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

    // 보드 상태를 2D 리스트로 변환
    final boardData = board.map((row) => row.map((s) => s.index).toList()).toList();

    final gameState = {
      'board': boardData,
      'isBlackTurn': isBlackTurn,
      'gameMode': widget.gameMode.index,
      'difficulty': widget.difficulty.index,
      'lastMoveRow': lastMoveRow,
      'lastMoveCol': lastMoveCol,
    };

    await GameSaveService.saveGame('gomoku', gameState);
  }

  // 저장된 게임 불러오기
  Future<void> _loadGame() async {
    final gameState = await GameSaveService.loadGame('gomoku');

    if (gameState == null) {
      _initBoard();
      return;
    }

    final boardData = gameState['board'] as List;
    board = boardData
        .map<List<Stone>>((row) => (row as List)
            .map<Stone>((s) => Stone.values[s as int])
            .toList())
        .toList();

    isBlackTurn = gameState['isBlackTurn'] as bool? ?? true;
    gameOver = false;
    winningStones = null;
    lastMoveRow = gameState['lastMoveRow'] as int?;
    lastMoveCol = gameState['lastMoveCol'] as int?;

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
        gameMessage = isBlackTurn ? 'games.gomoku.yourTurn'.tr() : 'games.gomoku.computerThinking'.tr();
        break;
      case GameMode.vsComputerBlack:
        gameMessage = isBlackTurn ? 'games.gomoku.computerThinking'.tr() : 'games.gomoku.yourTurn'.tr();
        break;
      case GameMode.vsPerson:
        gameMessage = isBlackTurn ? 'games.gomoku.blackTurn'.tr() : 'games.gomoku.whiteTurn'.tr();
        break;
    }
  }

  // 돌 아이콘 위젯
  Widget _buildStoneIcon(bool isBlack, {double size = 20}) {
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

  // 메시지 위젯 빌드 (아이콘 포함)
  Widget _buildMessageWidget() {
    final textColor = gameOver
        ? (gameMessage.contains('축하') ? Colors.green : Colors.red)
        : Colors.amber;

    // 게임 종료 시에는 텍스트만 표시
    if (gameOver) {
      return Text(
        gameMessage,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      );
    }

    // 진행 중일 때 돌 아이콘과 함께 표시
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStoneIcon(isBlackTurn, size: 22),
        const SizedBox(width: 10),
        Text(
          gameMessage,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  void _resetGame() {
    GomokuScreen.clearSavedGame(); // 저장된 게임 삭제
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
        title: Text('dialog.undoTitle'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text(
          'dialog.undoMessage'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('app.cancel'.tr()),
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
            child: Text('common.watchAd'.tr()),
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
      int undoCount = widget.gameMode == GameMode.vsPerson ? 1 : 2;

      for (int i = 0; i < undoCount && moveHistory.isNotEmpty; i++) {
        final lastMove = moveHistory.removeLast();
        board[lastMove[0]][lastMove[1]] = Stone.none;
        isBlackTurn = !isBlackTurn;
      }

      // 마지막 수 위치 업데이트
      if (moveHistory.isNotEmpty) {
        final prevMove = moveHistory.last;
        lastMoveRow = prevMove[0];
        lastMoveCol = prevMove[1];
      } else {
        lastMoveRow = null;
        lastMoveCol = null;
      }

      winningStones = null;
      _updateMessage();
    });

    _saveGame();
  }

  void _placeStone(int row, int col) {
    if (gameOver || board[row][col] != Stone.none || !isUserTurn) return;

    final stone = currentPlayerStone;

    setState(() {
      board[row][col] = stone;
      lastMoveRow = row;
      lastMoveCol = col;
      moveHistory.add([row, col]); // 히스토리에 추가
      if (_checkWin(row, col, stone)) {
        gameOver = true;
        _setWinMessage(stone);
        _saveGame(); // 게임 종료 시 저장 데이터 삭제
        Future.microtask(() => _showGameOverDialog());
        return;
      }
      if (_isDraw()) {
        gameOver = true;
        gameMessage = '무승부입니다!';
        _saveGame(); // 게임 종료 시 저장 데이터 삭제
        Future.microtask(() => _showGameOverDialog());
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
            ? 'games.gomoku.youWin'.tr()
            : 'common.computerWins'.tr();
        break;
      case GameMode.vsComputerBlack:
        gameMessage = winner == Stone.white
            ? 'games.gomoku.youWin'.tr()
            : 'common.computerWins'.tr();
        break;
      case GameMode.vsPerson:
        gameMessage = winner == Stone.black
            ? 'games.gomoku.blackWins'.tr()
            : 'games.gomoku.whiteWins'.tr();
        break;
    }
  }

  // 게임 종료 팝업
  void _showGameOverDialog() {
    final youWinMessage = 'games.gomoku.youWin'.tr();
    final drawMessage = 'common.draw'.tr();
    final isWin = gameMessage == youWinMessage;
    final isDraw = gameMessage == drawMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              isDraw ? Icons.handshake : (isWin ? Icons.emoji_events : Icons.sentiment_dissatisfied),
              color: isDraw ? Colors.grey : (isWin ? Colors.amber : Colors.red),
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              isDraw ? 'common.draw'.tr() : (isWin ? 'common.win'.tr() : 'common.lose'.tr()),
              style: TextStyle(
                color: isDraw ? Colors.grey : (isWin ? Colors.amber : Colors.red),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          gameMessage,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('common.confirm'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('app.close'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown.shade700,
            ),
            child: Text('app.newGame'.tr()),
          ),
        ],
      ),
    );
  }

  void _computerMove() {
    if (gameOver) return;

    final computerStone = currentPlayerStone;
    final userStone = computerStone == Stone.black ? Stone.white : Stone.black;
    final move = _findBestMove(computerStone, userStone);

    if (move != null) {
      setState(() {
        board[move[0]][move[1]] = computerStone;
        lastMoveRow = move[0];
        lastMoveCol = move[1];
        moveHistory.add([move[0], move[1]]); // 히스토리에 추가
        if (_checkWin(move[0], move[1], computerStone)) {
          gameOver = true;
          _setWinMessage(computerStone);
          _saveGame(); // 게임 종료 시 저장 데이터 삭제
          Future.microtask(() => _showGameOverDialog());
          return;
        }
        if (_isDraw()) {
          gameOver = true;
          gameMessage = '무승부입니다!';
          _saveGame(); // 게임 종료 시 저장 데이터 삭제
          Future.microtask(() => _showGameOverDialog());
          return;
        }
        isBlackTurn = !isBlackTurn;
        _updateMessage();
      });

      // 게임 상태 저장
      _saveGame();
    }
  }

  final Random _random = Random();

  List<int>? _findBestMove(Stone computerStone, Stone userStone) {
    // 컴퓨터의 첫 수인 경우: 사용자 돌 근처 2칸 범위 내에서 랜덤 선택
    final firstMove = _findFirstMoveNearUser(userStone);
    if (firstMove != null) return firstMove;

    switch (widget.difficulty) {
      case Difficulty.easy:
        return _findMoveEasy(computerStone, userStone);
      case Difficulty.medium:
        return _findMoveMedium(computerStone, userStone);
      case Difficulty.hard:
        return _findMoveHard(computerStone, userStone);
    }
  }

  // 컴퓨터 첫 수: 사용자 돌 근처 2칸 범위 내 랜덤 선택
  List<int>? _findFirstMoveNearUser(Stone userStone) {
    // 보드에 사용자 돌이 1개만 있는 경우 (컴퓨터 첫 수)
    int userStoneCount = 0;
    int? userRow, userCol;

    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == userStone) {
          userStoneCount++;
          userRow = i;
          userCol = j;
        } else if (board[i][j] != Stone.none) {
          return null; // 컴퓨터 돌이 이미 있으면 첫 수가 아님
        }
      }
    }

    if (userStoneCount != 1 || userRow == null || userCol == null) {
      return null;
    }

    // 사용자 돌 주변 2칸 범위 내 빈 칸 수집
    final candidates = <List<int>>[];
    for (int dr = -2; dr <= 2; dr++) {
      for (int dc = -2; dc <= 2; dc++) {
        if (dr == 0 && dc == 0) continue;
        int nr = userRow + dr;
        int nc = userCol + dc;
        if (nr >= 0 && nr < boardSize && nc >= 0 && nc < boardSize && board[nr][nc] == Stone.none) {
          candidates.add([nr, nc]);
        }
      }
    }

    if (candidates.isEmpty) return null;

    // 랜덤 선택
    return candidates[_random.nextInt(candidates.length)];
  }

  // 쉬움 난이도
  List<int>? _findMoveEasy(Stone computerStone, Stone userStone) {
    // 1. 승리 수 (내 5연속 완성)
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

    // 2. 상대 4연속 막기
    List<int>? blockFour = _findFourInRow(userStone);
    if (blockFour != null) return blockFour;

    // 3. 상대 열린 3연속 막기
    List<int>? blockOpenThree = _findOpenThree(userStone);
    if (blockOpenThree != null) return blockOpenThree;

    // 4. 내 4연속 만들기
    List<int>? fourMove = _findFourInRow(computerStone);
    if (fourMove != null) return fourMove;

    // 5. 내 열린 3 만들기
    List<int>? openThreeMove = _findOpenThree(computerStone);
    if (openThreeMove != null) return openThreeMove;

    // 6. 공격적 위치 평가 (노이즈 포함)
    int bestScore = -1;
    List<int>? bestMove;

    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == Stone.none) {
          int score = _evaluateLineScore(i, j, computerStone) * 3;
          score += _random.nextInt(30); // 노이즈 추가
          int centerDist = (i - boardSize ~/ 2).abs() + (j - boardSize ~/ 2).abs();
          score += (boardSize - centerDist);
          if (score > bestScore) {
            bestScore = score;
            bestMove = [i, j];
          }
        }
      }
    }

    return bestMove;
  }

  // 보통 난이도: 공격 우선 플레이 (한쪽 막힌 수비는 후순위)
  List<int>? _findMoveMedium(Stone computerStone, Stone userStone) {
    // 1. 컴퓨터가 이길 수 있는지 확인
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

    // 2. 상대 4연속 막기
    List<int>? blockFour = _findFourInRow(userStone);
    if (blockFour != null) return blockFour;

    // 3. 내 열린 4 만들기
    List<int>? openFourMove = _findOpenFour(computerStone);
    if (openFourMove != null) return openFourMove;

    // 4. 상대 열린 3연속 막기 (보통: 점수 평가로 최적 위치 선택)
    List<int>? blockOpenThree = _blockOpenThreeSmartHard(userStone, computerStone);
    if (blockOpenThree != null) return blockOpenThree;

    // 5. 내 열린 3 만들기
    List<int>? openThreeMove = _findOpenThree(computerStone);
    if (openThreeMove != null) return openThreeMove;

    // 6. 공격 위주 위치 평가 (수비 점수 제외)
    int bestScore = -1;
    List<int>? bestMove;

    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == Stone.none) {
          int score = 0;
          // 중앙 근접 점수
          int centerDist = (i - boardSize ~/ 2).abs() + (j - boardSize ~/ 2).abs();
          score += (boardSize - centerDist) * 2;
          // 공격 점수만 (수비 점수 제외 - 공격 위주)
          score += _evaluateLineScore(i, j, computerStone) * 3;
          if (score > bestScore) {
            bestScore = score;
            bestMove = [i, j];
          }
        }
      }
    }

    return bestMove;
  }

  // 어려움 난이도: 강화된 AI
  List<int>? _findMoveHard(Stone computerStone, Stone userStone) {
    // 1. 승리 수 (내 5연속 완성)
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

    // 2. 상대 4연속 막기 (한쪽 막힌 것 포함)
    List<int>? blockFour = _findFourInRow(userStone);
    if (blockFour != null) return blockFour;

    // 3. 내 열린 4 만들기
    List<int>? openFourMove = _findOpenFour(computerStone);
    if (openFourMove != null) return openFourMove;

    // 4. 상대 열린 3연속 막기 (어려움: 점수 평가로 최적 위치 선택)
    List<int>? blockOpenThree = _blockOpenThreeSmartHard(userStone, computerStone);
    if (blockOpenThree != null) return blockOpenThree;

    // 5. 상대 3x3 또는 4x3 위협 막기
    List<int>? blockDoubleThreat = _findDoubleThreat(userStone);
    if (blockDoubleThreat != null) return blockDoubleThreat;

    // 6. 내 열린 3 만들기
    List<int>? openThreeMove = _findOpenThree(computerStone);
    if (openThreeMove != null) return openThreeMove;

    // 7. 강화된 점수 평가
    int bestScore = -1;
    List<int>? bestMove;

    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == Stone.none) {
          int score = _evaluatePositionHard(i, j, computerStone, userStone);
          if (score > bestScore) {
            bestScore = score;
            bestMove = [i, j];
          }
        }
      }
    }

    return bestMove;
  }

  // 4연속 찾기 (한쪽이라도 열려있으면 막아야 함)
  List<int>? _findFourInRow(Stone stone) {
    final directions = [[0, 1], [1, 0], [1, 1], [1, -1]];

    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] != Stone.none) continue;

        for (var dir in directions) {
          int count = 0;

          // 정방향 체크
          int ni = i + dir[0];
          int nj = j + dir[1];
          while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == stone) {
            count++;
            ni += dir[0];
            nj += dir[1];
          }

          // 역방향 체크
          ni = i - dir[0];
          nj = j - dir[1];
          while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == stone) {
            count++;
            ni -= dir[0];
            nj -= dir[1];
          }

          // 4개 이상 연속이면 이 위치에 두면 5연속 완성/차단
          if (count >= 4) {
            return [i, j];
          }
        }
      }
    }
    return null;
  }

  // 열린 3 막을 때 3x3/4x3 가능성 체크하여 최적 위치 반환
  // 우선순위:
  // 1. 한칸 건너뛴 3열 + 양끝 열림 (_●_●●_ → 채우면 양쪽 열린 4)
  // 2. 연속된 열린 3 (_●●●_)
  // 3. 일반 한칸 건너뛴 패턴
  List<int>? _blockOpenThreeSmart(Stone stone) {
    final directions = [[0, 1], [1, 0], [1, 1], [1, -1]];
    List<List<int>> criticalGappedPositions = []; // 한칸 건너뛴 + 양끝 열림 (최우선)
    List<List<int>> consecutivePositions = []; // 연속된 열린 3
    List<List<int>> gappedPositions = []; // 일반 한칸 건너뛴 패턴

    // 모든 열린 3 찾기
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] != Stone.none) continue;

        for (var dir in directions) {
          int countForward = 0;
          int countBackward = 0;
          bool openForward = false;
          bool openBackward = false;
          List<List<int>> emptyEnds = [];

          // 정방향 체크
          int ni = i + dir[0];
          int nj = j + dir[1];
          while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == stone) {
            countForward++;
            ni += dir[0];
            nj += dir[1];
          }
          if (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == Stone.none) {
            openForward = true;
            emptyEnds.add([ni, nj]);
          }

          // 역방향 체크
          ni = i - dir[0];
          nj = j - dir[1];
          while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == stone) {
            countBackward++;
            ni -= dir[0];
            nj -= dir[1];
          }
          if (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == Stone.none) {
            openBackward = true;
            emptyEnds.add([ni, nj]);
          }

          int totalCount = countForward + countBackward;

          if (totalCount >= 2) {
            // 한칸 건너뛴 + 양끝 열림: 빈칸 채우면 양쪽 열린 4연속 (최우선)
            if (openForward && openBackward && countForward > 0 && countBackward > 0 && totalCount >= 3) {
              criticalGappedPositions.add([i, j]);
            }
            // 연속된 열린 3: 한쪽에만 돌이 있음 (_●●●_의 끝)
            else if (openForward && openBackward) {
              if ((countForward >= 2 && countBackward == 0) || (countBackward >= 2 && countForward == 0)) {
                consecutivePositions.add([i, j]);
                for (var pos in emptyEnds) {
                  consecutivePositions.add(pos);
                }
              }
            }
            // 한칸 건너뛴 패턴: 양쪽에 돌이 있고 양쪽 열림 (●_●●의 중간)
            // 쉬움/보통: 양쪽 열린 것만 막음 (공격 위주)
            // 중간 빈칸만 추가 (양끝은 제외 - 중간 막기 우선)
            else if (openForward && openBackward && countForward > 0 && countBackward > 0) {
              gappedPositions.add([i, j]);
            }
          }
        }
      }
    }

    // 1. 연속된 열린 3 먼저 막기 (가장 급함)
    if (consecutivePositions.isNotEmpty) {
      return consecutivePositions.first;
    }

    // 2. 한칸 건너뛴 + 양끝 열림 (막지 않으면 양쪽 열린 4)
    if (criticalGappedPositions.isNotEmpty) {
      return criticalGappedPositions.first;
    }

    // 3. 일반 한칸 건너뛴 패턴 처리
    if (gappedPositions.isNotEmpty) {
      return gappedPositions.first;
    }

    // 4. 3x3 가능 위치 (후순위 - 위에서 못 찾았을 때만)
    for (var pos in consecutivePositions) {
      if (_wouldCreateDoubleThreat(pos[0], pos[1], stone)) {
        return pos;
      }
    }
    for (var pos in criticalGappedPositions) {
      if (_wouldCreateDoubleThreat(pos[0], pos[1], stone)) {
        return pos;
      }
    }
    for (var pos in gappedPositions) {
      if (_wouldCreateDoubleThreat(pos[0], pos[1], stone)) {
        return pos;
      }
    }

    return null;
  }

  // 어려움 난이도용: 한칸 건너뛴 패턴에서 점수 평가로 최적 위치 선택
  List<int>? _blockOpenThreeSmartHard(Stone userStone, Stone computerStone) {
    final directions = [[0, 1], [1, 0], [1, 1], [1, -1]];
    List<List<int>> allPositions = []; // 모든 후보 위치 (점수 평가용)
    List<List<int>> consecutivePositions = []; // 연속된 열린 3

    // 모든 열린 3 찾기
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] != Stone.none) continue;

        for (var dir in directions) {
          int countForward = 0;
          int countBackward = 0;
          bool openForward = false;
          bool openBackward = false;
          List<List<int>> emptyEnds = [];

          // 정방향 체크
          int ni = i + dir[0];
          int nj = j + dir[1];
          while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == userStone) {
            countForward++;
            ni += dir[0];
            nj += dir[1];
          }
          if (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == Stone.none) {
            openForward = true;
            emptyEnds.add([ni, nj]);
          }

          // 역방향 체크
          ni = i - dir[0];
          nj = j - dir[1];
          while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == userStone) {
            countBackward++;
            ni -= dir[0];
            nj -= dir[1];
          }
          if (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == Stone.none) {
            openBackward = true;
            emptyEnds.add([ni, nj]);
          }

          int totalCount = countForward + countBackward;

          if (totalCount >= 2 && openForward && openBackward) {
            // 한칸 건너뛴 패턴: 중간과 양끝 모두 후보로 (점수 평가)
            if (countForward > 0 && countBackward > 0 && totalCount >= 3) {
              allPositions.add([i, j]); // 중간
              for (var pos in emptyEnds) {
                allPositions.add(pos); // 양끝
              }
            }
            // 연속된 열린 3: 한쪽에만 돌이 있음
            else if ((countForward >= 2 && countBackward == 0) || (countBackward >= 2 && countForward == 0)) {
              consecutivePositions.add([i, j]);
              for (var pos in emptyEnds) {
                consecutivePositions.add(pos);
              }
            }
            // 일반 한칸 건너뛴 (양쪽에 돌, 총 2개)
            else if (countForward > 0 && countBackward > 0) {
              allPositions.add([i, j]); // 중간
              for (var pos in emptyEnds) {
                allPositions.add(pos); // 양끝
              }
            }
          }
        }
      }
    }

    // 1. 연속된 열린 3 먼저 막기 (가장 급함)
    if (consecutivePositions.isNotEmpty) {
      return consecutivePositions.first;
    }

    // 2. 한칸 건너뛴 패턴: 점수 평가로 최적 위치 선택
    if (allPositions.isNotEmpty) {
      int bestScore = -1;
      List<int>? bestPos;

      for (var pos in allPositions) {
        // 공격 점수 + 수비 점수 합산
        int score = _evaluateLineScore(pos[0], pos[1], computerStone) * 3; // 공격
        score += _evaluateLineScore(pos[0], pos[1], userStone) * 2; // 수비

        // 중앙 근접 보너스
        int centerDist = (pos[0] - boardSize ~/ 2).abs() + (pos[1] - boardSize ~/ 2).abs();
        score += (boardSize - centerDist);

        if (score > bestScore) {
          bestScore = score;
          bestPos = pos;
        }
      }

      return bestPos;
    }

    // 3. 3x3 가능 위치 (후순위)
    for (var pos in consecutivePositions) {
      if (_wouldCreateDoubleThreat(pos[0], pos[1], userStone)) {
        return pos;
      }
    }
    for (var pos in allPositions) {
      if (_wouldCreateDoubleThreat(pos[0], pos[1], userStone)) {
        return pos;
      }
    }

    return null;
  }

  // 해당 위치에 돌을 놓으면 3x3 또는 4x3이 되는지 체크
  bool _wouldCreateDoubleThreat(int row, int col, Stone stone) {
    board[row][col] = stone;

    int threatCount = 0;
    bool hasFourThreat = false;
    final directions = [[0, 1], [1, 0], [1, 1], [1, -1]];

    for (var dir in directions) {
      int count = 1;
      int openEnds = 0;

      int ni = row + dir[0];
      int nj = col + dir[1];
      while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == stone) {
        count++;
        ni += dir[0];
        nj += dir[1];
      }
      if (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == Stone.none) {
        openEnds++;
      }

      ni = row - dir[0];
      nj = col - dir[1];
      while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == stone) {
        count++;
        ni -= dir[0];
        nj -= dir[1];
      }
      if (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == Stone.none) {
        openEnds++;
      }

      if (count >= 3 && openEnds >= 1) {
        threatCount++;
        if (count >= 4) hasFourThreat = true;
      }
    }

    board[row][col] = Stone.none;

    return threatCount >= 2 || (hasFourThreat && threatCount >= 1);
  }

  // 3x3 또는 4x3 위협 찾기 (두 방향에서 동시에 위협이 되는 위치)
  List<int>? _findDoubleThreat(Stone stone) {
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] != Stone.none) continue;

        int threatCount = 0;
        bool hasFourThreat = false;

        // 임시로 돌을 놓고 각 방향의 위협 체크
        board[i][j] = stone;

        final directions = [[0, 1], [1, 0], [1, 1], [1, -1]];
        for (var dir in directions) {
          int count = 1;
          int openEnds = 0;

          // 정방향 체크
          int ni = i + dir[0];
          int nj = j + dir[1];
          while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == stone) {
            count++;
            ni += dir[0];
            nj += dir[1];
          }
          if (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == Stone.none) {
            openEnds++;
          }

          // 역방향 체크
          ni = i - dir[0];
          nj = j - dir[1];
          while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == stone) {
            count++;
            ni -= dir[0];
            nj -= dir[1];
          }
          if (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == Stone.none) {
            openEnds++;
          }

          // 열린 3 이상이면 위협
          if (count >= 3 && openEnds >= 1) {
            threatCount++;
            if (count >= 4) hasFourThreat = true;
          }
        }

        board[i][j] = Stone.none;

        // 3x3 (열린 3이 2개 이상) 또는 4x3 (4 + 열린 3)
        if (threatCount >= 2 || (hasFourThreat && threatCount >= 1)) {
          return [i, j];
        }
      }
    }
    return null;
  }

  // 양쪽 열린 4 찾기 (4개 연속 + 양쪽 빈 칸)
  List<int>? _findOpenFour(Stone stone) {
    final directions = [[0, 1], [1, 0], [1, 1], [1, -1]];

    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] != Stone.none) continue;

        for (var dir in directions) {
          int count = 0;
          int openEnds = 0;

          // 정방향 체크
          int ni = i + dir[0];
          int nj = j + dir[1];
          while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == stone) {
            count++;
            ni += dir[0];
            nj += dir[1];
          }
          if (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == Stone.none) {
            openEnds++;
          }

          // 역방향 체크
          ni = i - dir[0];
          nj = j - dir[1];
          while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == stone) {
            count++;
            ni -= dir[0];
            nj -= dir[1];
          }
          if (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == Stone.none) {
            openEnds++;
          }

          if (count >= 3 && openEnds == 2) {
            return [i, j];
          }
        }
      }
    }
    return null;
  }

  // 양쪽 열린 3 찾기 (3개 연속 + 양쪽 빈 칸)
  // 우선순위:
  // 1. 한칸 건너뛴 3열 + 양끝 열림 (_●_●●_ → 채우면 양쪽 열린 4)
  // 2. 연속된 열린 3 (_●●●_)
  // 3. 일반 한칸 건너뛴 패턴
  List<int>? _findOpenThree(Stone stone) {
    final directions = [[0, 1], [1, 0], [1, 1], [1, -1]];

    // 1단계: 한칸 건너뛴 3열 + 양끝 열림 (_●_●●_ 패턴)
    // 빈칸 채우면 양쪽 열린 4연속이 되어 막을 수 없음 → 최우선 막기
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] != Stone.none) continue;

        for (var dir in directions) {
          int countForward = 0;
          int countBackward = 0;
          bool openForward = false;
          bool openBackward = false;

          // 정방향 체크
          int ni = i + dir[0];
          int nj = j + dir[1];
          while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == stone) {
            countForward++;
            ni += dir[0];
            nj += dir[1];
          }
          if (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == Stone.none) {
            openForward = true;
          }

          // 역방향 체크
          ni = i - dir[0];
          nj = j - dir[1];
          while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == stone) {
            countBackward++;
            ni -= dir[0];
            nj -= dir[1];
          }
          if (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == Stone.none) {
            openBackward = true;
          }

          int totalCount = countForward + countBackward;

          // 한칸 건너뛴 3열 + 양끝 열림: 빈칸 채우면 양쪽 열린 4연속
          // 예: _●_●●_ (countForward=2, countBackward=1, 양끝 열림)
          if (openForward && openBackward && countForward > 0 && countBackward > 0 && totalCount >= 3) {
            return [i, j];
          }
        }
      }
    }

    // 2단계: 연속된 열린 3의 끝 찾기 (_●●●_ 패턴의 빈칸)
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] != Stone.none) continue;

        for (var dir in directions) {
          int countForward = 0;
          int countBackward = 0;
          bool openForward = false;
          bool openBackward = false;

          // 정방향 체크
          int ni = i + dir[0];
          int nj = j + dir[1];
          while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == stone) {
            countForward++;
            ni += dir[0];
            nj += dir[1];
          }
          if (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == Stone.none) {
            openForward = true;
          }

          // 역방향 체크
          ni = i - dir[0];
          nj = j - dir[1];
          while (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == stone) {
            countBackward++;
            ni -= dir[0];
            nj -= dir[1];
          }
          if (ni >= 0 && ni < boardSize && nj >= 0 && nj < boardSize && board[ni][nj] == Stone.none) {
            openBackward = true;
          }

          // 연속된 열린 3 이상: 한쪽에만 2개 이상 연속, 양쪽 열림
          if (openForward && openBackward) {
            if ((countForward >= 2 && countBackward == 0) || (countBackward >= 2 && countForward == 0)) {
              return [i, j];
            }
          }
        }
      }
    }

    return null;
  }

  // 어려움 난이도용 강화된 위치 평가
  int _evaluatePositionHard(int row, int col, Stone computerStone, Stone userStone) {
    int score = 0;

    // 중앙 근접 점수 (더 높은 가중치)
    int centerDist = (row - boardSize ~/ 2).abs() + (col - boardSize ~/ 2).abs();
    score += (boardSize - centerDist) * 3;

    // 인접 돌 점수
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        int nr = row + dr;
        int nc = col + dc;
        if (nr >= 0 && nr < boardSize && nc >= 0 && nc < boardSize) {
          if (board[nr][nc] == computerStone) {
            score += 15; // 자기 돌 근처 선호
          } else if (board[nr][nc] == userStone) {
            score += 10; // 상대 돌 근처도 중요
          }
        }
      }
    }

    // 라인 점수 (공격 더 중요)
    score += _evaluateLineScore(row, col, computerStone) * 4;
    score += _evaluateLineScore(row, col, userStone) * 3;

    return score;
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

  // 누군가 아직 승리할 수 있는지 확인
  bool _canAnyoneWin() {
    final directions = [
      [0, 1],  // 가로
      [1, 0],  // 세로
      [1, 1],  // 대각선 ↘
      [1, -1], // 대각선 ↙
    ];

    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col < boardSize; col++) {
        for (var dir in directions) {
          // 5칸 라인이 보드 안에 있는지 확인
          int endRow = row + dir[0] * 4;
          int endCol = col + dir[1] * 4;

          if (endRow < 0 || endRow >= boardSize || endCol < 0 || endCol >= boardSize) continue;

          bool hasBlack = false;
          bool hasWhite = false;

          // 5칸 라인에 어떤 돌이 있는지 확인
          for (int i = 0; i < 5; i++) {
            int r = row + dir[0] * i;
            int c = col + dir[1] * i;

            if (board[r][c] == Stone.black) hasBlack = true;
            if (board[r][c] == Stone.white) hasWhite = true;
          }

          // 한 색상만 있거나 빈 칸만 있으면 아직 승리 가능
          if (!hasBlack || !hasWhite) {
            return true;
          }
        }
      }
    }

    return false; // 모든 라인에 양측 돌이 섞여있어 승리 불가
  }

  // 무승부 확인 (보드가 가득 찼거나 더 이상 승리 불가능)
  bool _isDraw() {
    return _isBoardFull() || !_canAnyoneWin();
  }

  bool _isWinningStone(int row, int col) {
    if (winningStones == null) return false;
    for (var stone in winningStones!) {
      if (stone[0] == row && stone[1] == col) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  // 확대 기능
  void _zoomIn() {
    setState(() {
      _currentScale = (_currentScale * 1.5).clamp(1.0, 3.0);
      _transformationController.value = Matrix4.identity()..scale(_currentScale);
    });
  }

  // 축소 기능
  void _zoomOut() {
    setState(() {
      _currentScale = (_currentScale / 1.5).clamp(1.0, 3.0);
      _transformationController.value = Matrix4.identity()..scale(_currentScale);
    });
  }

  // 원래 크기로 복원
  void _resetZoom() {
    setState(() {
      _currentScale = 1.0;
      _transformationController.value = Matrix4.identity();
    });
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
        title: Text(
          'games.gomoku.name'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown.shade800,
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
            tooltip: 'app.newGame'.tr(),
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
                child: _buildMessageWidget(),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: _buildGameBoard(),
                    ),
                    // 확대/축소 버튼 (바둑판 바로 밑)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: _buildZoomControls(),
                    ),
                  ],
                ),
              ),
            ),
            // 범례
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
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
      case GameMode.vsComputerWhite:
        blackPlayerName = 'common.you'.tr();
        whitePlayerName = 'common.computer'.tr();
        break;
      case GameMode.vsComputerBlack:
        blackPlayerName = 'common.computer'.tr();
        whitePlayerName = 'common.you'.tr();
        break;
      case GameMode.vsPerson:
        blackPlayerName = 'games.gomoku.blackStone'.tr();
        whitePlayerName = 'games.gomoku.whiteStone'.tr();
        break;
    }

    return Scaffold(
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
        child: SafeArea(
          child: Stack(
            children: [
              // 메인 영역: 플레이어 표시 + 게임 보드
              Row(
                children: [
                  // 왼쪽 패널: 흑돌 플레이어 (상하좌우 중앙)
                  Expanded(
                    child: Center(
                      child: _buildPlayerIndicator(
                        isBlack: true,
                        playerName: blackPlayerName,
                        isCurrentTurn: isBlackTurn && !gameOver,
                      ),
                    ),
                  ),
                  // 가운데: 게임 보드 + 확대/축소 버튼
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.maxHeight;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: size,
                            height: size,
                            child: _buildGameBoard(),
                          ),
                          // 확대/축소 버튼 (세로 배치)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: _buildVerticalZoomControls(),
                          ),
                        ],
                      );
                    },
                  ),
                  // 오른쪽 패널: 백돌 플레이어 (상하좌우 중앙)
                  Expanded(
                    child: Center(
                      child: _buildPlayerIndicator(
                        isBlack: false,
                        playerName: whitePlayerName,
                        isCurrentTurn: !isBlackTurn && !gameOver,
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
                      child: Text(
                        'games.gomoku.name'.tr(),
                        style: const TextStyle(
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
                      tooltip: 'common.undo'.tr(),
                    ),
                    const SizedBox(width: 8),
                    _buildCircleButton(
                      icon: Icons.refresh,
                      onPressed: _resetGame,
                      tooltip: 'app.newGame'.tr(),
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
    required bool isCurrentTurn,
  }) {
    // 하이라이트 색상: 더 밝고 눈에 띄는 색상 사용
    final highlightColor = Colors.amber;

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
                  color: Colors.orange.withValues(alpha: 0.6),
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
            child: _buildStoneIcon(isBlack, size: 48),
          ),
          const SizedBox(height: 12),
          Text(
            playerName,
            style: TextStyle(
              color: isCurrentTurn ? Colors.amber.shade100 : Colors.grey.shade500,
              fontSize: 16,
              fontWeight: isCurrentTurn ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isBlack ? '(흑)' : '(백)',
            style: TextStyle(
              color: isCurrentTurn ? Colors.amber.shade200 : Colors.grey.shade600,
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

  // 게임 보드 위젯
  Widget _buildGameBoard() {
    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 1.0,
      maxScale: 3.0,
      onInteractionEnd: (details) {
        // 핀치 줌 후 현재 스케일 동기화
        final scale = _transformationController.value.getMaxScaleOnAxis();
        setState(() {
          _currentScale = scale;
        });
      },
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
    );
  }

  // 확대/축소 버튼 그룹 위젯 (가로 배치 - 세로 모드용)
  Widget _buildZoomControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildZoomButton(
          icon: Icons.remove,
          onPressed: _currentScale > 1.0 ? _zoomOut : null,
          tooltip: 'common.zoomOut'.tr(),
        ),
        const SizedBox(width: 8),
        _buildZoomButton(
          icon: Icons.refresh,
          onPressed: _currentScale != 1.0 ? _resetZoom : null,
          tooltip: 'common.resetZoom'.tr(),
        ),
        const SizedBox(width: 8),
        _buildZoomButton(
          icon: Icons.add,
          onPressed: _currentScale < 3.0 ? _zoomIn : null,
          tooltip: 'common.zoomIn'.tr(),
        ),
      ],
    );
  }

  // 확대/축소 버튼 그룹 위젯 (세로 배치 - 가로 모드용)
  Widget _buildVerticalZoomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildZoomButton(
          icon: Icons.add,
          onPressed: _currentScale < 3.0 ? _zoomIn : null,
          tooltip: 'common.zoomIn'.tr(),
        ),
        const SizedBox(height: 8),
        _buildZoomButton(
          icon: Icons.refresh,
          onPressed: _currentScale != 1.0 ? _resetZoom : null,
          tooltip: 'common.resetZoom'.tr(),
        ),
        const SizedBox(height: 8),
        _buildZoomButton(
          icon: Icons.remove,
          onPressed: _currentScale > 1.0 ? _zoomOut : null,
          tooltip: 'common.zoomOut'.tr(),
        ),
      ],
    );
  }

  // 확대/축소 버튼 위젯
  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    final isEnabled = onPressed != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.4,
      child: Material(
        color: Colors.black.withValues(alpha: 0.6),
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
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStone(int row, int col) {
    if (board[row][col] == Stone.none) return const SizedBox();

    bool isWinning = _isWinningStone(row, col);
    bool isLastMove = (row == lastMoveRow && col == lastMoveCol);
    Color stoneColor = board[row][col] == Stone.black ? Colors.black : Colors.white;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
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
        ),
        // 마지막 수 표시 (빨간 점)
        if (isLastMove && !isWinning)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: board[row][col] == Stone.black ? Colors.red : Colors.red.shade700,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildLegendByMode() {
    final black = 'games.gomoku.black'.tr();
    final white = 'games.gomoku.white'.tr();

    switch (widget.gameMode) {
      case GameMode.vsComputerWhite:
        return [
          _buildLegend(Colors.black, 'common.playerWithColor'.tr(namedArgs: {'player': 'common.you'.tr(), 'color': black})),
          const SizedBox(width: 32),
          _buildLegend(Colors.white, 'common.playerWithColor'.tr(namedArgs: {'player': 'common.computer'.tr(), 'color': white})),
        ];
      case GameMode.vsComputerBlack:
        return [
          _buildLegend(Colors.black, 'common.playerWithColor'.tr(namedArgs: {'player': 'common.computer'.tr(), 'color': black})),
          const SizedBox(width: 32),
          _buildLegend(Colors.white, 'common.playerWithColor'.tr(namedArgs: {'player': 'common.you'.tr(), 'color': white})),
        ];
      case GameMode.vsPerson:
        return [
          _buildLegend(Colors.black, 'common.playerWithColor'.tr(namedArgs: {'player': 'games.gomoku.player1'.tr(), 'color': black})),
          const SizedBox(width: 32),
          _buildLegend(Colors.white, 'common.playerWithColor'.tr(namedArgs: {'player': 'games.gomoku.player2'.tr(), 'color': white})),
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
          'games.gomoku.rulesTitle'.tr(),
          style: const TextStyle(color: Colors.amber),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'games.gomoku.rulesObjective'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.gomoku.rulesObjectiveDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.gomoku.rulesHowToPlay'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.gomoku.rulesHowToPlayDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.gomoku.rulesForbidden'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.gomoku.rulesForbiddenDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.gomoku.rulesTips'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.gomoku.rulesTipsDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
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
