import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/game_save_service.dart';

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
  late List<List<Stone>> board;
  bool isBlackTurn = true; // 흑돌 차례 여부
  bool gameOver = false;
  String gameMessage = '';
  List<List<int>>? winningStones;
  int? lastMoveRow; // 마지막 수 행
  int? lastMoveCol; // 마지막 수 열
  List<List<int>> moveHistory = []; // 수 히스토리 (되돌리기용)

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
    lastMoveRow = null;
    lastMoveCol = null;
    moveHistory = [];
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
        gameMessage = isBlackTurn ? '당신의 차례입니다' : '컴퓨터가 생각 중...';
        break;
      case GameMode.vsComputerBlack:
        gameMessage = isBlackTurn ? '컴퓨터가 생각 중...' : '당신의 차례입니다';
        break;
      case GameMode.vsPerson:
        gameMessage = isBlackTurn ? '흑돌 차례입니다' : '백돌 차례입니다';
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
        lastMoveRow = move[0];
        lastMoveCol = move[1];
        moveHistory.add([move[0], move[1]]); // 히스토리에 추가
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

  // 쉬움 난이도: 랜덤 요소 추가, 일부 위협 무시
  List<int>? _findMoveEasy(Stone computerStone, Stone userStone) {
    // 40% 확률로 랜덤 수 두기
    if (_random.nextDouble() < 0.4) {
      final emptyPositions = <List<int>>[];
      for (int i = 0; i < boardSize; i++) {
        for (int j = 0; j < boardSize; j++) {
          if (board[i][j] == Stone.none) {
            emptyPositions.add([i, j]);
          }
        }
      }
      if (emptyPositions.isNotEmpty) {
        // 중앙 근처 우선
        emptyPositions.sort((a, b) {
          int distA = (a[0] - boardSize ~/ 2).abs() + (a[1] - boardSize ~/ 2).abs();
          int distB = (b[0] - boardSize ~/ 2).abs() + (b[1] - boardSize ~/ 2).abs();
          return distA.compareTo(distB);
        });
        int index = _random.nextInt(min(5, emptyPositions.length));
        return emptyPositions[index];
      }
    }

    // 컴퓨터가 이길 수 있는지 확인 (항상 승리는 잡음)
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

    // 50% 확률로만 상대 5연속 막기
    if (_random.nextDouble() < 0.5) {
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
    }

    // 점수에 노이즈 추가하여 최선의 수 찾기
    int bestScore = -1;
    List<int>? bestMove;

    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (board[i][j] == Stone.none) {
          int score = _evaluatePositionForStone(i, j, computerStone, userStone);
          score += _random.nextInt(50); // 노이즈 추가
          if (score > bestScore) {
            bestScore = score;
            bestMove = [i, j];
          }
        }
      }
    }

    return bestMove;
  }

  // 보통 난이도: 기존 AI (균형 잡힌 플레이)
  List<int>? _findMoveMedium(Stone computerStone, Stone userStone) {
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

  // 어려움 난이도: 강화된 AI (위협 패턴 인식 강화)
  List<int>? _findMoveHard(Stone computerStone, Stone userStone) {
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

    // 양쪽 열린 4 만들기 / 막기
    List<int>? openFourMove = _findOpenFour(computerStone);
    if (openFourMove != null) return openFourMove;

    List<int>? blockOpenFour = _findOpenFour(userStone);
    if (blockOpenFour != null) return blockOpenFour;

    // 양쪽 열린 3 만들기 / 막기
    List<int>? openThreeMove = _findOpenThree(computerStone);
    if (openThreeMove != null) return openThreeMove;

    List<int>? blockOpenThree = _findOpenThree(userStone);
    if (blockOpenThree != null) return blockOpenThree;

    // 강화된 점수 평가
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
  List<int>? _findOpenThree(Stone stone) {
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

          if (count == 2 && openEnds == 2) {
            return [i, j];
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

  bool _isWinningStone(int row, int col) {
    if (winningStones == null) return false;
    for (var stone in winningStones!) {
      if (stone[0] == row && stone[1] == col) return true;
    }
    return false;
  }

  @override
  void dispose() {
    // 화면을 나갈 때 상태바 복원
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          // 가로 모드: 상태바 숨김 (몰입 모드)
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.immersiveSticky,
            overlays: [],
          );
          return _buildLandscapeLayout(context);
        } else {
          // 세로 모드: 상태바 표시
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.edgeToEdge,
            overlays: SystemUiOverlay.values,
          );
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
          '오목',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: moveHistory.isNotEmpty && !gameOver ? _undoMove : null,
            tooltip: '되돌리기',
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
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _buildGameBoard(),
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

  // 가로 모드 레이아웃
  Widget _buildLandscapeLayout(BuildContext context) {
    // 플레이어 정보 결정
    String blackPlayerName;
    String whitePlayerName;

    switch (widget.gameMode) {
      case GameMode.vsComputerWhite:
        blackPlayerName = '당신';
        whitePlayerName = '컴퓨터';
        break;
      case GameMode.vsComputerBlack:
        blackPlayerName = '컴퓨터';
        whitePlayerName = '당신';
        break;
      case GameMode.vsPerson:
        blackPlayerName = '흑돌';
        whitePlayerName = '백돌';
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
                      child: const Text(
                        '오목',
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
                      onPressed: moveHistory.isNotEmpty && !gameOver ? _undoMove : () {},
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
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Material(
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
    return Container(
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
