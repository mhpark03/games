import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/game_save_service.dart';

// 윷 결과
enum YutResult {
  backDo, // 빽도 (-1)
  do_, // 도 (1)
  gae, // 개 (2)
  geol, // 걸 (3)
  yut, // 윷 (4)
  mo, // 모 (5)
}

extension YutResultExtension on YutResult {
  int get moveCount {
    switch (this) {
      case YutResult.backDo:
        return -1;
      case YutResult.do_:
        return 1;
      case YutResult.gae:
        return 2;
      case YutResult.geol:
        return 3;
      case YutResult.yut:
        return 4;
      case YutResult.mo:
        return 5;
    }
  }

  String get name {
    switch (this) {
      case YutResult.backDo:
        return '빽도';
      case YutResult.do_:
        return '도';
      case YutResult.gae:
        return '개';
      case YutResult.geol:
        return '걸';
      case YutResult.yut:
        return '윷';
      case YutResult.mo:
        return '모';
    }
  }

  bool get isBonus => this == YutResult.yut || this == YutResult.mo;
}

// 말 클래스
class Piece {
  int position; // -1: 대기, 0-28: 보드 위치, 29: 골인
  bool isFinished;
  List<int> stackedPieces; // 업힌 말들의 인덱스

  Piece()
      : position = -1,
        isFinished = false,
        stackedPieces = [];

  Piece.fromMap(Map<String, dynamic> map)
      : position = map['position'] as int,
        isFinished = map['isFinished'] as bool,
        stackedPieces = List<int>.from(map['stackedPieces'] as List);

  Map<String, dynamic> toMap() => {
        'position': position,
        'isFinished': isFinished,
        'stackedPieces': stackedPieces,
      };

  bool get isOnBoard => position >= 0 && position <= 34;
  bool get isWaiting => position == -1;
}

class YutnoriScreen extends StatefulWidget {
  final int playerCount;
  final bool resumeGame;

  const YutnoriScreen({
    super.key,
    this.playerCount = 2,
    this.resumeGame = false,
  });

  static Future<bool> hasSavedGame() async {
    return await GameSaveService.hasSavedGame('yutnori');
  }

  static Future<int?> getSavedPlayerCount() async {
    final gameState = await GameSaveService.loadGame('yutnori');
    if (gameState == null) return null;
    return gameState['playerCount'] as int?;
  }

  static Future<void> clearSavedGame() async {
    await GameSaveService.clearSave();
  }

  @override
  State<YutnoriScreen> createState() => _YutnoriScreenState();
}

class _YutnoriScreenState extends State<YutnoriScreen>
    with TickerProviderStateMixin {
  late int playerCount;
  int currentPlayer = 0; // 0 = 플레이어, 1+ = 컴퓨터
  bool gameOver = false;
  String? winner;
  List<int> rankings = []; // 완료 순서 (등수)

  // 각 플레이어의 말 (4개씩)
  late List<List<Piece>> playerPieces;

  // 윷 던지기 관련
  YutResult? currentYutResult;
  List<YutResult> pendingMoves = []; // 아직 사용하지 않은 윷 결과들
  bool isThrowingYut = false;
  bool canThrowYut = true;

  // 턴 대기 (다음 순서 버튼)
  bool waitingForNextTurn = false;
  int? lastPlayerIndex;
  Timer? _autoExecuteTimer; // 자동 실행 타이머

  // 최근 이동한 말 표시
  int? lastMovedPlayerIndex;
  int? lastMovedPieceIndex;

  // 자동 액션 대기 중
  bool isAutoActionPending = false;

  // 말 선택
  int? selectedPieceIndex;

  // 사용할 결과 선택 (여러 결과가 있을 때)
  int? selectedMoveIndex;

  // 애니메이션
  late AnimationController _yutAnimController;
  late Animation<double> _yutAnimation;

  // 메시지
  String? gameMessage;

  // 윷 이미지 상태 (던지기 애니메이션용)
  List<bool> yutStickStates = [false, false, false, false];

  // 윷판 위치 정보 (29개 위치)
  // 0: 시작점, 1-5: 우측 하단→우측 상단
  // 5-10: 우측 상단→좌측 상단
  // 10-15: 좌측 상단→좌측 하단
  // 15-20: 좌측 하단→시작점
  // 21-24: 우상단 대각선 (5→중앙)
  // 25-28: 좌상단 대각선 (10→중앙)
  // 22, 27: 중앙
  static const int boardSize = 29;
  static const int lastBoardPosition = 33; // 마지막 보드 위치
  static const int finishPosition = 100; // 골인 표시 (보드 위치가 아님)

  // 특수 위치
  static const int cornerTopRight = 5;
  static const int cornerTopLeft = 10;
  static const int cornerBottomLeft = 15;
  static const int startPosition = 0;
  static const int centerPosition = 22; // 중앙 위치

  @override
  void initState() {
    super.initState();
    playerCount = widget.playerCount;
    _yutAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _yutAnimation = CurvedAnimation(
      parent: _yutAnimController,
      curve: Curves.bounceOut,
    );

    // 항상 먼저 초기화 (async 로드 전에 playerPieces가 필요함)
    _initGame();

    if (widget.resumeGame) {
      _loadGame();
    }
  }

  @override
  void dispose() {
    _autoExecuteTimer?.cancel();
    _yutAnimController.dispose();
    super.dispose();
  }

  void _initGame() {
    playerPieces = List.generate(
      playerCount,
      (_) => List.generate(4, (_) => Piece()),
    );
    currentPlayer = 0;
    gameOver = false;
    winner = null;
    rankings = []; // 등수 초기화
    currentYutResult = null;
    pendingMoves = [];
    isThrowingYut = false;
    canThrowYut = true;
    waitingForNextTurn = false;
    lastPlayerIndex = null;
    lastMovedPlayerIndex = null;
    lastMovedPieceIndex = null;
    selectedPieceIndex = null;
    selectedMoveIndex = null;
    gameMessage = '윷을 던지세요!';
  }

  // 플레이어 턴인지 확인
  bool get isPlayerTurn => currentPlayer == 0;

  Future<void> _saveGame() async {
    if (gameOver) {
      await YutnoriScreen.clearSavedGame();
      return;
    }

    final gameState = {
      'playerCount': playerCount,
      'currentPlayer': currentPlayer,
      'playerPieces': playerPieces
          .map((pieces) => pieces.map((p) => p.toMap()).toList())
          .toList(),
      'pendingMoves': pendingMoves.map((m) => m.index).toList(),
      'canThrowYut': canThrowYut,
      'waitingForNextTurn': waitingForNextTurn,
      'lastMovedPlayerIndex': lastMovedPlayerIndex,
      'lastMovedPieceIndex': lastMovedPieceIndex,
    };

    await GameSaveService.saveGame('yutnori', gameState);
  }

  Future<void> _loadGame() async {
    final gameState = await GameSaveService.loadGame('yutnori');

    if (gameState == null) {
      // 저장된 게임이 없으면 초기화 상태 유지
      return;
    }

    playerCount = gameState['playerCount'] as int? ?? 2;
    currentPlayer = gameState['currentPlayer'] as int? ?? 0;

    final piecesData = gameState['playerPieces'] as List?;
    if (piecesData != null) {
      playerPieces = piecesData
          .map((playerData) => (playerData as List)
              .map((pieceData) =>
                  Piece.fromMap(Map<String, dynamic>.from(pieceData)))
              .toList())
          .toList();
    } else {
      playerPieces = List.generate(
        playerCount,
        (_) => List.generate(4, (_) => Piece()),
      );
    }

    final movesData = gameState['pendingMoves'] as List?;
    pendingMoves =
        movesData?.map((i) => YutResult.values[i as int]).toList() ?? [];

    canThrowYut = gameState['canThrowYut'] as bool? ?? pendingMoves.isEmpty;

    // waitingForNextTurn 상태 복원 - 컴퓨터 턴이면 대기 상태로
    if (currentPlayer > 0) {
      waitingForNextTurn = true;
    } else {
      waitingForNextTurn = gameState['waitingForNextTurn'] as bool? ?? false;
    }

    gameOver = false;
    winner = null;
    isThrowingYut = false;
    selectedPieceIndex = null;

    // 최근 이동한 말 정보 복원
    lastMovedPlayerIndex = gameState['lastMovedPlayerIndex'] as int?;
    lastMovedPieceIndex = gameState['lastMovedPieceIndex'] as int?;

    if (currentPlayer == 0) {
      if (pendingMoves.isNotEmpty) {
        if (pendingMoves.length > 1) {
          gameMessage = '사용할 결과를 선택하세요';
        } else {
          gameMessage = '${pendingMoves.first.name}! 말을 선택하세요';
        }
      } else if (canThrowYut) {
        gameMessage = '윷을 던지세요!';
      } else {
        gameMessage = '게임을 이어서 시작합니다';
      }
    } else {
      gameMessage = '${_getPlayerName(currentPlayer)} 차례 - 다음 버튼을 눌러주세요';
    }

    setState(() {});

    // 플레이어 턴이고 이동 대기 중이면 자동 액션 체크
    if (currentPlayer == 0 && pendingMoves.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _checkAutoAction();
      });
    }

    // 컴퓨터 턴이면 5초 후 자동 실행 타이머 시작
    if (currentPlayer > 0 && waitingForNextTurn) {
      _autoExecuteTimer?.cancel();
      _autoExecuteTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && waitingForNextTurn && !gameOver) {
          _onNextTurn();
        }
      });
    }
  }

  // 윷 던지기
  void _throwYut() {
    if (!canThrowYut || isThrowingYut || gameOver) return;

    setState(() {
      isThrowingYut = true;
      gameMessage = '윷을 던지는 중...';
    });

    _yutAnimController.reset();
    _yutAnimController.forward();

    // 랜덤 애니메이션
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_yutAnimController.status == AnimationStatus.completed) {
        timer.cancel();
        _finishThrowYut();
      } else {
        setState(() {
          yutStickStates = List.generate(4, (_) => Random().nextBool());
        });
      }
    });
  }

  void _finishThrowYut() {
    final result = _generateYutResult();

    setState(() {
      yutStickStates = _getYutStatesForResult(result);
      currentYutResult = result;
      pendingMoves.add(result);
      isThrowingYut = false;

      if (result.isBonus) {
        if (isPlayerTurn) {
          gameMessage = '${result.name}! 한 번 더 던지세요!';
        } else {
          gameMessage = '${_getPlayerName(currentPlayer)}: ${result.name}! 한 번 더!';
        }
        canThrowYut = true;
      } else {
        if (isPlayerTurn) {
          if (pendingMoves.length > 1) {
            gameMessage = '${result.name}! 사용할 결과를 선택하세요';
          } else {
            gameMessage = '${result.name}! 말을 선택하세요';
          }
        } else {
          gameMessage = '${_getPlayerName(currentPlayer)}: ${result.name}!';
        }
        canThrowYut = false;
      }
    });

    HapticFeedback.mediumImpact();
    _saveGame();

    // 컴퓨터 턴 처리
    if (currentPlayer > 0 && !gameOver) {
      if (canThrowYut) {
        // 윷/모가 나와서 한 번 더 던질 수 있으면 대기
        _waitForNextTurn();
      } else if (pendingMoves.isNotEmpty) {
        // 이동할 말이 있으면 바로 이동 (대기 없이)
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && !gameOver) _computerMovePiece();
        });
      }
    } else if (currentPlayer == 0 && !canThrowYut && !gameOver) {
      // 플레이어 턴이고 더 던질 수 없으면 자동 액션 체크
      _checkAutoAction();
    }
  }

  YutResult _generateYutResult() {
    // 실제 윷놀이 확률에 가깝게
    // 도: 약 37.5%, 개: 약 25%, 걸: 약 18.75%, 윷: 약 12.5%, 모: 약 6.25%
    // 빽도: 도가 나왔을 때 특수 조건 (첫 번째 막대만 뒤집힘)
    final random = Random();
    final sticks = List.generate(4, (_) => random.nextBool());
    final upCount = sticks.where((s) => s).length;

    // 빽도: 하나만 뒤집힘 + 특정 확률
    if (upCount == 1 && random.nextDouble() < 0.3) {
      return YutResult.backDo;
    }

    switch (upCount) {
      case 0:
        return YutResult.mo;
      case 1:
        return YutResult.do_;
      case 2:
        return YutResult.gae;
      case 3:
        return YutResult.geol;
      case 4:
        return YutResult.yut;
      default:
        return YutResult.do_;
    }
  }

  List<bool> _getYutStatesForResult(YutResult result) {
    switch (result) {
      case YutResult.mo:
        return [false, false, false, false];
      case YutResult.do_:
        return [true, false, false, false];
      case YutResult.backDo:
        return [true, false, false, false]; // 빽도도 하나만 뒤집힘
      case YutResult.gae:
        return [true, true, false, false];
      case YutResult.geol:
        return [true, true, true, false];
      case YutResult.yut:
        return [true, true, true, true];
    }
  }

  // 말 이동 가능 여부 확인
  bool _canMovePiece(int pieceIndex, YutResult move) {
    final piece = playerPieces[currentPlayer][pieceIndex];

    // 골인한 말은 이동 불가
    if (piece.isFinished) return false;

    // 빽도인 경우: 대기 중인 말은 이동 불가, 시작점(0)에 있는 말도 이동 불가
    if (move == YutResult.backDo) {
      if (piece.isWaiting) return false;
      if (piece.position == 0) return false;
    }

    return true;
  }

  // 이동 후 위치 계산
  // 위치 정규화 (같은 위치를 특정 번호로 통일)
  // 멈춘 경우에만 적용됨 (지나가는 경우는 최종 위치가 다르므로 변환 안됨)
  int _normalizePosition(int pos) {
    switch (pos) {
      case 5:
        return 21; // 우상단 코너 → 대각선 진입
      case 10:
        return 28; // 좌상단 코너 → 대각선 진입
      case 24:
        return 31; // 중앙 (우상단 경로) → 우하단 방향으로 변경
      case 0:
        return 34; // 시작점
      case 20:
        return 34; // 한 바퀴 완료 → 시작점
      case 27:
        return 15; // 좌하단 코너 (대각선에서 외곽 합류)
      default:
        return pos;
    }
  }

  int _calculateNewPosition(int currentPos, int moveCount) {
    if (currentPos == -1) {
      // 대기 중인 말: 출발점에서 이동칸수만큼 진행
      if (moveCount <= 0) return -1;
      return _normalizePosition(moveCount);
    }

    int newPos = currentPos;

    // 지름길 처리
    if (currentPos == 21) {
      // 우상단 코너(21)에서
      if (moveCount < 0) {
        // 빽도: 외곽 경로 4번으로
        return 4;
      }
      // 대각선으로: 21 → 22 → 23 → 24(중앙) → 25 → 26 → 27(→15) → 외곽 합류
      newPos = 21 + moveCount; // 도(1)면 22, 개(2)면 23...
      if (newPos > 26) {
        // 좌하단 코너(15) 방향으로 외곽 합류
        // 27→15, 28→16, 29→17, ...
        newPos = 15 + (newPos - 27);
        if (newPos >= 20) {
          return finishPosition;
        }
      }
    } else if (currentPos >= 22 && currentPos <= 24) {
      // 우상단 대각선에서 (22, 23, 24 → 25, 26 → 15로 합류)
      newPos = currentPos + moveCount;
      if (newPos > 26) {
        // 좌하단 코너(15) 방향으로 외곽 합류
        newPos = 15 + (newPos - 27);
        if (newPos >= 20) {
          return finishPosition;
        }
      }
    } else if (currentPos >= 25 && currentPos <= 26) {
      // 중앙→좌하단 대각선에서 (25, 26 → 15로 합류)
      newPos = currentPos + moveCount;
      if (newPos > 26) {
        // 좌하단 코너(15) 방향으로 외곽 합류
        newPos = 15 + (newPos - 27);
        if (newPos >= 20) {
          return finishPosition;
        }
      }
    } else if (currentPos == 28) {
      // 좌상단 코너(28)에서
      if (moveCount < 0) {
        // 빽도: 외곽 경로 9번으로
        return 9;
      }
      // 대각선으로: 28 → 29 → 30 → 31(중앙) → 32 → 33 → 골인
      newPos = 28 + moveCount; // 도(1)면 29, 개(2)면 30...
      if (newPos > lastBoardPosition) {
        return finishPosition;
      }
    } else if (currentPos >= 29 && currentPos <= 31) {
      // 좌상단 대각선에서 (29, 30, 31 → 32, 33 → 골인)
      newPos = currentPos + moveCount;
      if (newPos > lastBoardPosition) {
        return finishPosition;
      }
    } else if (currentPos >= 32 && currentPos <= lastBoardPosition) {
      // 중앙 → 우하단(골인 방향) 대각선에서
      newPos = currentPos + moveCount;
      if (newPos > lastBoardPosition) {
        return finishPosition;
      }
    } else if (currentPos == 34) {
      // 한 바퀴 완료 후 시작점에서 이동 → 골인
      if (moveCount > 0) {
        return finishPosition;
      }
      // 빽도면 19로
      return 19;
    } else {
      // 일반 외곽 경로 (1-19)
      newPos = currentPos + moveCount;

      // 빽도 처리
      if (newPos < 0) {
        return -1; // 대기로 돌아감
      }

      // 정확히 20이면 한 바퀴 완료 (시작점 도착) → 34로 변환
      if (newPos == 20) {
        return 34;
      }

      // 20 초과하면 골인 처리
      if (newPos > 20) {
        return finishPosition;
      }
    }

    return _normalizePosition(newPos);
  }

  // 선택된 이동 결과 가져오기
  YutResult? get selectedMove {
    if (pendingMoves.isEmpty) return null;
    if (selectedMoveIndex != null && selectedMoveIndex! < pendingMoves.length) {
      return pendingMoves[selectedMoveIndex!];
    }
    // 결과가 1개면 자동 선택
    if (pendingMoves.length == 1) return pendingMoves.first;
    return null;
  }

  // 결과 선택
  void _selectMove(int index) {
    setState(() {
      selectedMoveIndex = index;
      gameMessage = '${pendingMoves[index].name} 선택 - 이동할 말을 선택하세요';
    });
  }

  // 말 선택 및 이동
  void _selectPiece(int pieceIndex) {
    if (currentPlayer != 0 || pendingMoves.isEmpty || gameOver) return;

    // 결과가 여러 개인데 선택 안 했으면 먼저 선택하라고 안내
    if (pendingMoves.length > 1 && selectedMoveIndex == null) {
      setState(() {
        gameMessage = '먼저 사용할 결과를 선택하세요';
      });
      return;
    }

    final move = selectedMove!;
    if (!_canMovePiece(pieceIndex, move)) {
      setState(() {
        gameMessage = '이 말은 이동할 수 없습니다';
      });
      return;
    }

    setState(() {
      selectedPieceIndex = pieceIndex;
    });

    _movePiece(pieceIndex, move);
  }

  void _movePiece(int pieceIndex, YutResult move) {
    final piece = playerPieces[currentPlayer][pieceIndex];
    final oldPos = piece.position;
    final newPos = _calculateNewPosition(oldPos, move.moveCount);
    bool captured = false;

    // 사용할 이동의 인덱스 찾기
    final moveIndex = selectedMoveIndex ?? 0;

    setState(() {
      // 최근 이동한 말 기록
      lastMovedPlayerIndex = currentPlayer;
      lastMovedPieceIndex = pieceIndex;

      // 이동
      piece.position = newPos;

      // 골인 처리
      if (newPos == finishPosition) {
        piece.isFinished = true;
        piece.position = finishPosition;
        gameMessage = '${_getPlayerName(currentPlayer)} 말 골인!';

        // 업힌 말들도 골인
        for (var stackedIndex in piece.stackedPieces) {
          playerPieces[currentPlayer][stackedIndex].isFinished = true;
          playerPieces[currentPlayer][stackedIndex].position = finishPosition;
        }
        piece.stackedPieces.clear();
      } else if (newPos >= 0) {
        // 잡기 확인
        captured = _checkCapture(newPos);
        if (captured) {
          gameMessage = '${_getPlayerName(currentPlayer)} 잡았다! 한 번 더!';
          canThrowYut = true;
        }

        // 업기 확인
        _checkStack(pieceIndex, newPos);
      }

      // 사용한 이동 제거
      pendingMoves.removeAt(moveIndex);
      selectedMoveIndex = null; // 선택 초기화

      // 완료 확인 및 등수 기록
      if (_checkWin(currentPlayer) && !rankings.contains(currentPlayer)) {
        rankings.add(currentPlayer);
        final rank = rankings.length;
        gameMessage = '${_getPlayerName(currentPlayer)} ${rank}등 완료!';
      }

      // 게임 종료 확인: 플레이어 완료 또는 다른 모든 플레이어 완료
      if (_shouldEndGame()) {
        gameOver = true;
        final playerRank = rankings.indexOf(0) + 1;
        if (playerRank > 0) {
          winner = '$playerRank등';
        } else {
          // 플레이어가 아직 완료하지 않은 경우 (다른 모두가 완료)
          winner = '${rankings.length + 1}등';
        }
        gameMessage = '게임 종료! 나의 등수: $winner';
      } else if (pendingMoves.isEmpty && !canThrowYut) {
        // 턴 종료
        _nextTurn();
      } else if (pendingMoves.isNotEmpty) {
        if (isPlayerTurn) {
          if (pendingMoves.length == 1) {
            gameMessage = '${pendingMoves.first.name} - 말을 선택하세요';
          } else {
            gameMessage = '사용할 결과를 선택하세요';
          }
        } else {
          gameMessage = '${_getPlayerName(currentPlayer)}: ${pendingMoves.first.name} 이동 중...';
        }
      }

      selectedPieceIndex = null;
    });

    HapticFeedback.lightImpact();
    _saveGame();

    // 컴퓨터 턴 - 다음 버튼 대기 (5초 후 자동 실행)
    if (!gameOver && currentPlayer > 0 && (pendingMoves.isNotEmpty || canThrowYut)) {
      _waitForNextTurn();
    }
  }

  bool _checkCapture(int position) {
    bool captured = false;

    for (int p = 0; p < playerCount; p++) {
      if (p == currentPlayer) continue;

      for (var piece in playerPieces[p]) {
        if (piece.position == position && !piece.isFinished) {
          // 잡힘! 대기로 돌아감
          piece.position = -1;
          // 업힌 말들도 대기로
          for (var stackedIndex in piece.stackedPieces) {
            playerPieces[p][stackedIndex].position = -1;
          }
          piece.stackedPieces.clear();
          captured = true;
        }
      }
    }

    return captured;
  }

  void _checkStack(int movedPieceIndex, int position) {
    final movedPiece = playerPieces[currentPlayer][movedPieceIndex];

    for (int i = 0; i < 4; i++) {
      if (i == movedPieceIndex) continue;

      final piece = playerPieces[currentPlayer][i];
      if (piece.position == position && !piece.isFinished) {
        // 업기! 이동한 말에 업힘
        movedPiece.stackedPieces.add(i);
        // 업힌 말의 업힌 말들도 이전
        movedPiece.stackedPieces.addAll(piece.stackedPieces);
        piece.stackedPieces.clear();
        piece.position = -2; // 업힌 상태 표시 (화면에 안 보임)
      }
    }
  }

  bool _checkWin(int player) {
    return playerPieces[player].every((piece) => piece.isFinished);
  }

  // 게임 종료 확인: 플레이어(0)가 완료했거나, 다른 모든 플레이어가 완료한 경우
  bool _shouldEndGame() {
    // 플레이어가 완료한 경우
    if (rankings.contains(0)) {
      return true;
    }
    // 다른 모든 플레이어가 완료한 경우 (플레이어만 남은 경우)
    final otherPlayersCount = playerCount - 1;
    final finishedOthers = rankings.where((p) => p != 0).length;
    return finishedOthers >= otherPlayersCount;
  }

  void _nextTurn() {
    setState(() {
      lastPlayerIndex = currentPlayer;
      currentPlayer = (currentPlayer + 1) % playerCount;
      canThrowYut = true;
      pendingMoves.clear();
      selectedMoveIndex = null;
      gameMessage = '${_getPlayerName(currentPlayer)} 차례';
    });

    _saveGame();

    // 컴퓨터 턴이면 다음 순서 버튼 대기 (5초 후 자동 실행)
    if (currentPlayer > 0 && !gameOver) {
      _waitForNextTurn();
    }
  }

  String _getPlayerName(int player) {
    if (player == 0) return '플레이어';
    return '컴퓨터 $player';
  }

  // 컴퓨터 AI - 현재 상태에 따라 다음 액션 실행
  void _computerTurn() {
    if (gameOver || currentPlayer == 0) return;

    if (canThrowYut) {
      // 윷 던지기 (짧은 딜레이 후 실행)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !gameOver) _throwYut();
      });
    } else if (pendingMoves.isNotEmpty) {
      // 말 이동 (짧은 딜레이 후 실행)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !gameOver) _computerMovePiece();
      });
    }
  }

  void _computerMovePiece() {
    if (pendingMoves.isEmpty) return;

    final move = pendingMoves.first;

    // 이동 가능한 말 찾기
    List<int> movablePieces = [];
    for (int i = 0; i < 4; i++) {
      if (_canMovePiece(i, move)) {
        movablePieces.add(i);
      }
    }

    if (movablePieces.isEmpty) {
      // 이동 가능한 말이 없으면 스킵
      setState(() {
        pendingMoves.removeAt(0);
        if (pendingMoves.isEmpty && !canThrowYut) {
          _nextTurn();
        }
      });
      return;
    }

    // 전략적 선택: 잡을 수 있는 말 > 골인 가능한 말 > 가장 앞선 말
    int bestPiece = movablePieces.first;
    int bestScore = -100;

    for (var pieceIndex in movablePieces) {
      final piece = playerPieces[currentPlayer][pieceIndex];
      final newPos = _calculateNewPosition(piece.position, move.moveCount);

      int score = 0;

      // 골인 가능하면 높은 점수
      if (newPos == finishPosition) {
        score += 50 + piece.stackedPieces.length * 20;
      }

      // 잡을 수 있으면 높은 점수
      for (int p = 0; p < playerCount; p++) {
        if (p == currentPlayer) continue;
        for (var enemyPiece in playerPieces[p]) {
          if (enemyPiece.position == newPos && !enemyPiece.isFinished) {
            score += 30 + enemyPiece.stackedPieces.length * 15;
          }
        }
      }

      // 업을 수 있으면 점수 (안전 지역에서만)
      // 안전 지역: 코너 (5/21, 10/28, 15, 0/34)
      bool isSafePosition = (newPos == 21 || newPos == 28 || newPos == 15 || newPos == 34);
      for (int i = 0; i < 4; i++) {
        if (i == pieceIndex) continue;
        if (playerPieces[currentPlayer][i].position == newPos) {
          if (isSafePosition) {
            score += 10; // 안전 지역에서 업기
          } else {
            score -= 5; // 위험 지역에서 업기는 오히려 감점
          }
        }
      }

      // 진행도
      if (newPos >= 0) {
        score += newPos;
      }

      if (score > bestScore) {
        bestScore = score;
        bestPiece = pieceIndex;
      }
    }

    _movePiece(bestPiece, move);
  }

  void _restartGame() {
    setState(() {
      _initGame();
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            SystemChrome.setEnabledSystemUIMode(
              SystemUiMode.immersiveSticky,
              overlays: [],
            );
            return _buildLandscapeLayout();
          } else {
            SystemChrome.setEnabledSystemUIMode(
              SystemUiMode.edgeToEdge,
              overlays: SystemUiOverlay.values,
            );
            return _buildPortraitLayout();
          }
        },
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFDEB887),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B4513),
        foregroundColor: Colors.white,
        title: Text(
          '윷놀이 (${playerCount}인)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _restartGame,
            tooltip: '다시 시작',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 상단 컴퓨터: 2인용은 컴퓨터1, 3/4인용은 컴퓨터2
                if (playerCount >= 2)
                  _buildComputerHandWidget(playerCount == 2 ? 0 : 1),
                // 현재 턴 표시 및 게임 정보
                _buildTurnInfo(),
                // 중앙 영역 (좌우 컴퓨터 + 윷판)
                Expanded(
                  child: playerCount > 2
                      ? Row(
                          children: [
                            // 왼쪽 컴퓨터 (컴퓨터 3) - 4인용
                            if (playerCount >= 4)
                              _buildSideComputerWidget(2),
                            // 윷판
                            Expanded(child: _buildYutBoard()),
                            // 오른쪽 컴퓨터 (컴퓨터 1) - 3/4인용
                            if (playerCount >= 3)
                              _buildSideComputerWidget(0),
                          ],
                        )
                      : _buildYutBoard(),
                ),
                // 게임 메시지
                if (gameMessage != null) _buildMessage(),
                // 윷 던지기 영역
                _buildYutThrowArea(),
                // 플레이어 영역 (하단)
                _buildPlayerArea(),
              ],
            ),
            // 게임 오버 오버레이
            if (gameOver) _buildGameOverOverlay(),
          ],
        ),
      ),
    );
  }

  // 상단 컴퓨터 위젯
  Widget _buildComputerHandWidget(int computerIndex) {
    if (computerIndex >= playerCount - 1) return const SizedBox();

    final player = computerIndex + 1;
    final isCurrentTurn = currentPlayer == player;
    final finishedCount = playerPieces[player].where((p) => p.isFinished).length;
    final waitingCount = playerPieces[player].where((p) => p.isWaiting).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          // 컴퓨터 이름과 상태
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCurrentTurn ? _getPlayerColor(player) : const Color(0xFF8B4513),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.computer, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '컴퓨터 $player',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                // 말 상태: 골인/대기
                ...List.generate(4, (i) {
                  final pieceFinished = i < finishedCount;
                  final pieceWaiting = i < waitingCount && !pieceFinished;
                  return Container(
                    margin: const EdgeInsets.only(left: 3),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: pieceFinished
                          ? Colors.amber
                          : _getPlayerColor(player).withValues(alpha: pieceWaiting ? 0.4 : 1.0),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: pieceFinished
                        ? const Icon(Icons.check, color: Colors.white, size: 10)
                        : null,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 좌우 컴퓨터 위젯
  Widget _buildSideComputerWidget(int computerIndex) {
    if (computerIndex >= playerCount - 1) return const SizedBox();

    final player = computerIndex + 1;
    final isCurrentTurn = currentPlayer == player;
    final finishedCount = playerPieces[player].where((p) => p.isFinished).length;

    return Container(
      width: 55,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 컴퓨터 번호
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: isCurrentTurn ? _getPlayerColor(player) : const Color(0xFF8B4513),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                const Icon(Icons.computer, color: Colors.white, size: 14),
                Text(
                  'C$player',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 말 상태 (세로)
          Column(
            children: List.generate(4, (i) {
              final pieceFinished = i < finishedCount;
              return Container(
                margin: const EdgeInsets.only(bottom: 3),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: pieceFinished ? Colors.amber : _getPlayerColor(player),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: pieceFinished
                    ? const Icon(Icons.check, color: Colors.white, size: 10)
                    : null,
              );
            }),
          ),
        ],
      ),
    );
  }

  // 현재 턴 표시
  Widget _buildTurnInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 현재 턴 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getPlayerColor(currentPlayer),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPlayerTurn ? Icons.person : Icons.computer,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_getPlayerName(currentPlayer)} 차례',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // 남은 이동 표시
          if (pendingMoves.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Row(
                children: pendingMoves.asMap().entries.map((entry) {
                  final index = entry.key;
                  final move = entry.value;
                  final isSelected = selectedMoveIndex == index;
                  final canSelect = currentPlayer == 0 && pendingMoves.length > 1;
                  return GestureDetector(
                    onTap: canSelect ? () => _selectMove(index) : null,
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFFF8C00), Color(0xFFE65100)],
                              )
                            : canSelect
                                ? const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFF6D4C41), Color(0xFF5D4037)],
                                  )
                                : null,
                        color: (!isSelected && !canSelect) ? const Color(0xFF8B4513) : null,
                        borderRadius: BorderRadius.circular(6),
                        border: canSelect || isSelected
                            ? Border.all(
                                color: isSelected ? Colors.white : const Color(0xFFFFCC80),
                                width: isSelected ? 1.5 : 1,
                              )
                            : null,
                        boxShadow: canSelect || isSelected
                            ? [
                                BoxShadow(
                                  color: isSelected
                                      ? Colors.orange.withValues(alpha: 0.4)
                                      : Colors.black.withValues(alpha: 0.2),
                                  offset: const Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canSelect && !isSelected)
                            const Padding(
                              padding: EdgeInsets.only(right: 2),
                              child: Icon(Icons.touch_app, color: Colors.white70, size: 10),
                            ),
                          Text(
                            move.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isSelected ? 12 : 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isSelected)
                            const Padding(
                              padding: EdgeInsets.only(left: 2),
                              child: Icon(Icons.check, color: Colors.white, size: 10),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // 다음 순서 버튼
  Widget _buildPlayButton({bool compact = false}) {
    return GestureDetector(
      onTap: _onNextTurn,
      child: Container(
        padding: compact
            ? const EdgeInsets.all(8)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade700,
          borderRadius: BorderRadius.circular(compact ? 20 : 8),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: compact
            ? const Icon(Icons.play_arrow, color: Colors.white, size: 24)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.play_arrow, color: Colors.white, size: 20),
                  SizedBox(width: 4),
                  Text(
                    '다음',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // 컴퓨터 턴 대기 설정 (5초 후 자동 실행)
  void _waitForNextTurn() {
    _autoExecuteTimer?.cancel();
    setState(() {
      waitingForNextTurn = true;
    });
    // 5초 후 자동 실행
    _autoExecuteTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && waitingForNextTurn && !gameOver) {
        _onNextTurn();
      }
    });
  }

  // 다음 순서 버튼 눌렀을 때
  void _onNextTurn() {
    _autoExecuteTimer?.cancel();
    setState(() {
      waitingForNextTurn = false;
    });
    if (currentPlayer > 0 && !gameOver) {
      Future.delayed(const Duration(milliseconds: 300), () => _computerTurn());
    }
  }

  Widget _buildLandscapeLayout() {
    return Scaffold(
      body: Container(
        color: const Color(0xFFDEB887),
        child: SafeArea(
          child: Stack(
            children: [
              Row(
                children: [
                  // 좌측 열: C2 (상) + 턴정보/다음버튼 (중) + C3 (하)
                  SizedBox(
                    width: 130,
                    child: Column(
                      children: [
                        const SizedBox(height: 50), // 뒤로가기 버튼 공간
                        // C2 (좌상단)
                        if (playerCount >= 3)
                          _buildLandscapeCompactComputer(2)
                        else
                          const SizedBox(height: 50),
                        // 턴 정보 + 다음 버튼 (C2와 C3 사이)
                        Expanded(
                          child: _buildLandscapeLeftControls(),
                        ),
                        // C3 (좌하단)
                        if (playerCount >= 4)
                          _buildLandscapeCompactComputer(3)
                        else
                          const SizedBox(height: 50),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  // 중앙: 윷판 (최대 크기)
                  Expanded(
                    child: Column(
                      children: [
                        // 상단 제목
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B4513),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '윷놀이 (${playerCount}인)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // 윷판
                        Expanded(
                          child: Center(
                            child: _buildYutBoard(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 우측 열: C1 (상) + 윷던지기/결과 (중) + 플레이어 (하)
                  SizedBox(
                    width: 130,
                    child: Column(
                      children: [
                        const SizedBox(height: 50), // 새게임 버튼 공간
                        // C1 (우상단)
                        _buildLandscapeCompactComputer(1),
                        // 윷 던지기 + 결과 (C1과 플레이어 사이)
                        Expanded(
                          child: _buildLandscapeRightControls(),
                        ),
                        // 플레이어 (우하단)
                        _buildLandscapeCompactPlayer(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
              // 왼쪽 상단: 뒤로가기 버튼
              Positioned(
                top: 8,
                left: 8,
                child: _buildCircleButton(
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              // 오른쪽 상단: 새 게임 버튼
              Positioned(
                top: 8,
                right: 8,
                child: _buildCircleButton(
                  icon: Icons.refresh,
                  onPressed: _restartGame,
                ),
              ),
              // 게임 오버 오버레이
              if (gameOver) _buildGameOverOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  // 가로모드: 좌측 컨트롤 (턴 정보 + 다음 버튼 + 결과)
  Widget _buildLandscapeLeftControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 현재 턴 표시
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _getPlayerColor(currentPlayer),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPlayerTurn ? Icons.person : Icons.computer,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 3),
                Text(
                  '${_getPlayerName(currentPlayer)} 차례',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 남은 이동 표시 (결과 포함) - 클릭하여 선택
          if (pendingMoves.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: pendingMoves.asMap().entries.map((entry) {
                final index = entry.key;
                final move = entry.value;
                final isSelected = selectedMoveIndex == index;
                final canSelect = currentPlayer == 0 && pendingMoves.length > 1;
                return GestureDetector(
                  onTap: currentPlayer == 0 ? () => _selectMove(index) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFF8C00), Color(0xFFE65100)],
                            )
                          : canSelect
                              ? const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xFF6D4C41), Color(0xFF5D4037)],
                                )
                              : null,
                      color: (!isSelected && !canSelect) ? const Color(0xFF8B4513) : null,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white
                            : canSelect
                                ? const Color(0xFFFFCC80)
                                : const Color(0xFF5D4037),
                        width: isSelected ? 2 : 1.5,
                      ),
                      boxShadow: canSelect || isSelected
                          ? [
                              BoxShadow(
                                color: isSelected
                                    ? Colors.orange.withValues(alpha: 0.5)
                                    : Colors.black.withValues(alpha: 0.3),
                                offset: const Offset(0, 2),
                                blurRadius: 3,
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canSelect && !isSelected)
                          const Padding(
                            padding: EdgeInsets.only(right: 3),
                            child: Icon(Icons.touch_app, color: Colors.white70, size: 12),
                          ),
                        Text(
                          move.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSelected ? 14 : 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isSelected)
                          const Padding(
                            padding: EdgeInsets.only(left: 3),
                            child: Icon(Icons.check, color: Colors.white, size: 12),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // 가로모드: 우측 컨트롤 (메시지 + 윷 던지기)
  Widget _buildLandscapeRightControls() {
    // 결과가 있으면 결과 이름 제외한 메시지만 표시
    String? displayMessage = gameMessage;
    if (displayMessage != null) {
      // 모든 윷 결과 이름을 메시지에서 제거
      for (final result in YutResult.values) {
        // "컴퓨터 1: 모! 한 번 더!" -> "컴퓨터 1: 한 번 더!"
        displayMessage = displayMessage!.replaceAll(': ${result.name}! ', ': ');
        displayMessage = displayMessage.replaceAll(': ${result.name}!', ':');
        // "빽도! 말을 선택하세요" -> "말을 선택하세요"
        displayMessage = displayMessage.replaceFirst('${result.name}! ', '');
        displayMessage = displayMessage.replaceFirst('${result.name}!', '');
        // "빽도 - 말을 선택하세요" -> "말을 선택하세요"
        displayMessage = displayMessage.replaceFirst('${result.name} - ', '');
      }
      // 빈 콜론 정리 ("컴퓨터 1:" -> "")
      if (displayMessage != null && displayMessage.trim().endsWith(':')) {
        displayMessage = '';
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 메시지 (상단) - 결과 이름 제외
        if (displayMessage != null && displayMessage.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF8B4513).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        // 윷 스틱 표시 (세로모드처럼 세로 막대 4개 가로로 배치)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 18,
              height: 55,
              decoration: BoxDecoration(
                color: yutStickStates[i]
                    ? const Color(0xFF8B4513)
                    : const Color(0xFFF5DEB3),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF654321), width: 2),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        // 버튼 영역 (윷 던지기 / 결과 표시 / 다음 버튼 / 던지는 중)
        if (isPlayerTurn && canThrowYut && !isThrowingYut)
          GestureDetector(
            onTap: _throwYut,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E7D32), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0, 3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.casino, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    '던지기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (isThrowingYut)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade600, width: 2),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  '던지는 중',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        else if (waitingForNextTurn && currentPlayer > 0)
          // 컴퓨터 차례일 때 다음 버튼 (결과 표시보다 우선)
          _buildPlayButton(compact: true)
        else if (currentYutResult != null && !isThrowingYut)
          // 던지기 결과 표시 (버튼 위치에)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFFD700),
                  const Color(0xFFFF8C00),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFB8860B), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.5),
                  offset: const Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              currentYutResult!.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // 가로모드: 컴팩트 컴퓨터 위젯
  Widget _buildLandscapeCompactComputer(int playerIndex) {
    final isCurrentTurn = currentPlayer == playerIndex;
    final finishedCount =
        playerPieces[playerIndex].where((p) => p.isFinished).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? _getPlayerColor(playerIndex).withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isCurrentTurn
                  ? _getPlayerColor(playerIndex)
                  : const Color(0xFF8B4513),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.computer, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  'C$playerIndex',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 말 상태
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (i) {
              final pieceFinished = i < finishedCount;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: pieceFinished
                      ? Colors.amber
                      : _getPlayerColor(playerIndex),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // 가로모드: 컴팩트 플레이어 위젯
  Widget _buildLandscapeCompactPlayer() {
    final isCurrentTurn = currentPlayer == 0;
    final finishedCount = playerPieces[0].where((p) => p.isFinished).length;
    final waitingCount = playerPieces[0].where((p) => p.isWaiting).length;

    // 이동 가능한 대기 말이 있는지 확인 (선택된 결과 또는 아무 결과로)
    bool canStartNewPiece = false;
    final moveToCheck = selectedMove ?? (pendingMoves.isNotEmpty ? pendingMoves.first : null);
    if (moveToCheck != null) {
      for (int i = 0; i < 4; i++) {
        if (playerPieces[0][i].isWaiting && _canMovePiece(i, moveToCheck)) {
          canStartNewPiece = true;
          break;
        }
      }
    }

    // 이동 가능한 말이 있는지 확인 (전체)
    bool hasMovablePiece = false;
    if (moveToCheck != null) {
      for (int i = 0; i < 4; i++) {
        if (_canMovePiece(i, moveToCheck)) {
          hasMovablePiece = true;
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? _getPlayerColor(0).withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isCurrentTurn
                  ? _getPlayerColor(0)
                  : const Color(0xFF8B4513),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  '플레이어',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // 새로 달기 버튼 (대기 말이 있고 이동 가능할 때, 자동 실행 대기 중 아닐 때)
          if (isCurrentTurn && pendingMoves.isNotEmpty && waitingCount > 0 && canStartNewPiece && !isAutoActionPending)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: GestureDetector(
                onTap: _startNewPiece,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '새로 달기 ($waitingCount)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          // 건너뛰기 버튼 (이동 불가시, 자동 실행 대기 중 아닐 때)
          if (isCurrentTurn && pendingMoves.isNotEmpty && !hasMovablePiece && !isAutoActionPending)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: GestureDetector(
                onTap: _skipMove,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '건너뛰기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          // 말 상태
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (i) {
              final pieceFinished = i < finishedCount;
              final pieceWaiting = playerPieces[0][i].isWaiting;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: pieceFinished
                      ? Colors.amber
                      : pieceWaiting
                          ? _getPlayerColor(0).withValues(alpha: 0.5)
                          : _getPlayerColor(0),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // 새로 달기 (대기 중인 말 중 첫 번째 이동 가능한 말 선택)
  void _startNewPiece() {
    if (pendingMoves.isEmpty) return;
    final move = selectedMove ?? pendingMoves.first;
    setState(() {
      isAutoActionPending = false;
      // 결과가 여러 개인데 선택 안 했으면 첫 번째를 자동 선택
      if (pendingMoves.length > 1 && selectedMoveIndex == null) {
        selectedMoveIndex = 0;
      }
    });
    for (int i = 0; i < 4; i++) {
      if (playerPieces[currentPlayer][i].isWaiting &&
          _canMovePiece(i, move)) {
        _selectPiece(i);
        return;
      }
    }
  }

  // 이동 불가시 건너뛰기
  void _skipMove() {
    if (pendingMoves.isEmpty) return;

    final moveIndex = selectedMoveIndex ?? 0;

    setState(() {
      isAutoActionPending = false;
      pendingMoves.removeAt(moveIndex);
      selectedMoveIndex = null;
      if (pendingMoves.isEmpty && !canThrowYut) {
        _nextTurn();
      } else if (pendingMoves.isNotEmpty) {
        if (pendingMoves.length == 1) {
          gameMessage = '${pendingMoves.first.name}! 말을 선택하세요';
        } else {
          gameMessage = '사용할 결과를 선택하세요';
        }
        // 새로운 결과에 대해 자동 액션 체크
        _checkAutoAction();
      }
    });
    _saveGame();
  }

  // 자동 액션 체크 및 실행 (말판에 말이 없을 때 새로 달기, 이동 불가시 건너뛰기)
  void _checkAutoAction() {
    if (currentPlayer != 0 || pendingMoves.isEmpty || isAutoActionPending) return;

    // 결과가 1개일 때만 자동 액션 실행 (여러 개면 선택이 필요)
    if (pendingMoves.length > 1) return;

    final move = pendingMoves.first;

    // 말판 위에 있는 플레이어 말이 있는지 확인
    bool hasPieceOnBoard = false;
    for (int i = 0; i < 4; i++) {
      if (!playerPieces[0][i].isWaiting && !playerPieces[0][i].isFinished) {
        hasPieceOnBoard = true;
        break;
      }
    }

    // 이동 가능한 대기 말 확인
    bool canStartNewPiece = false;
    for (int i = 0; i < 4; i++) {
      if (playerPieces[0][i].isWaiting && _canMovePiece(i, move)) {
        canStartNewPiece = true;
        break;
      }
    }

    // 이동 가능한 말 전체 확인
    bool hasMovablePiece = false;
    for (int i = 0; i < 4; i++) {
      if (_canMovePiece(i, move)) {
        hasMovablePiece = true;
        break;
      }
    }

    // 말판에 말이 없고 새로 달기 가능한 경우 - 자동 새로 달기
    if (!hasPieceOnBoard && canStartNewPiece) {
      setState(() {
        isAutoActionPending = true;
        gameMessage = '새로 달기합니다...';
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && isAutoActionPending && currentPlayer == 0) {
          _startNewPiece();
        }
      });
      return;
    }

    // 이동 가능한 말이 없는 경우 - 자동 건너뛰기
    if (!hasMovablePiece) {
      setState(() {
        isAutoActionPending = true;
        gameMessage = '이동할 수 없어 건너뜁니다...';
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && isAutoActionPending && currentPlayer == 0) {
          _skipMove();
        }
      });
      return;
    }
  }

  // 가로모드: 컴퓨터 위젯
  Widget _buildLandscapeComputerWidget(int playerIndex) {
    final isCurrentTurn = currentPlayer == playerIndex;
    final finishedCount =
        playerPieces[playerIndex].where((p) => p.isFinished).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? _getPlayerColor(playerIndex).withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCurrentTurn
                  ? _getPlayerColor(playerIndex)
                  : const Color(0xFF8B4513),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.computer, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  'C$playerIndex',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // 말 상태
          Row(
            children: List.generate(4, (i) {
              final pieceFinished = i < finishedCount;
              return Container(
                margin: const EdgeInsets.only(left: 2),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: pieceFinished
                      ? Colors.amber
                      : _getPlayerColor(playerIndex),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: pieceFinished
                    ? const Icon(Icons.check, color: Colors.white, size: 8)
                    : null,
              );
            }),
          ),
        ],
      ),
    );
  }

  // 가로모드: 플레이어 위젯
  Widget _buildLandscapePlayerWidget() {
    final isCurrentTurn = currentPlayer == 0;
    final finishedCount = playerPieces[0].where((p) => p.isFinished).length;
    final waitingPieces = <int>[];
    for (int i = 0; i < 4; i++) {
      if (playerPieces[0][i].isWaiting) {
        waitingPieces.add(i);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? _getPlayerColor(0).withValues(alpha: 0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrentTurn
                      ? _getPlayerColor(0)
                      : const Color(0xFF8B4513),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      '플레이어',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // 말 상태
              Row(
                children: List.generate(4, (i) {
                  final pieceFinished = i < finishedCount;
                  return Container(
                    margin: const EdgeInsets.only(left: 2),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color:
                          pieceFinished ? Colors.amber : _getPlayerColor(0),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: pieceFinished
                        ? const Icon(Icons.check, color: Colors.white, size: 8)
                        : null,
                  );
                }),
              ),
            ],
          ),
          // 대기 중인 말 (선택 가능 - 결과 선택 후에만 하이라이트)
          if (waitingPieces.isNotEmpty && isCurrentTurn && pendingMoves.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: waitingPieces.map((pieceIndex) {
                  final moveForCheck = selectedMove;
                  final canMove = moveForCheck != null && _canMovePiece(pieceIndex, moveForCheck);
                  return GestureDetector(
                    onTap: canMove ? () => _selectPiece(pieceIndex) : null,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _getPlayerColor(0),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: canMove ? Colors.yellow : Colors.white,
                          width: canMove ? 2 : 1,
                        ),
                        boxShadow: canMove
                            ? [
                                BoxShadow(
                                  color: Colors.yellow.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // 가로모드: 중앙 컨트롤 (윷 던지기 + 메시지 + 다음 버튼)
  Widget _buildLandscapeCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 윷 스틱 표시
        Row(
          children: List.generate(4, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 20,
              height: 50,
              decoration: BoxDecoration(
                color: yutStickStates[i]
                    ? const Color(0xFF8B4513)
                    : const Color(0xFFF5DEB3),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF654321), width: 1),
              ),
            );
          }),
        ),
        const SizedBox(width: 16),
        // 메시지 + 다음 버튼 또는 윷 던지기 버튼
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (gameMessage != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B4513),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  gameMessage!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (waitingForNextTurn && currentPlayer > 0)
              _buildPlayButton(compact: true)
            else if (isPlayerTurn && canThrowYut && !isThrowingYut)
              GestureDetector(
                onTap: _throwYut,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4513),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '윷 던지기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF8B4513),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF8B4513).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        gameMessage!,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildOpponentInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(playerCount - 1, (index) {
          final player = index + 1;
          final isCurrentTurn = currentPlayer == player;
          final finishedCount =
              playerPieces[player].where((p) => p.isFinished).length;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  isCurrentTurn ? Colors.blue : const Color(0xFF8B4513),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.computer, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  '컴퓨터 $player',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                // 골인한 말 표시
                ...List.generate(4, (i) {
                  return Container(
                    margin: const EdgeInsets.only(left: 2),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: i < finishedCount
                          ? _getPlayerColor(player)
                          : Colors.grey.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOpponentInfoVertical() {
    return Column(
      children: List.generate(playerCount - 1, (index) {
        final player = index + 1;
        final isCurrentTurn = currentPlayer == player;
        final finishedCount =
            playerPieces[player].where((p) => p.isFinished).length;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCurrentTurn ? Colors.blue : const Color(0xFF8B4513),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.computer, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '컴퓨터 $player',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(4, (i) {
                  return Container(
                    margin: const EdgeInsets.only(left: 2),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: i < finishedCount
                          ? _getPlayerColor(player)
                          : Colors.grey.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildYutBoard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = min(constraints.maxWidth, constraints.maxHeight) * 0.9;
        final center = size / 2;
        final radius = size * 0.4;

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: YutBoardPainter(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 시작점/골인점 라벨
                  Positioned(
                    left: center + radius * 0.85 - 24,
                    top: center + radius * 0.85 + 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '출발/골인',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // 진행 방향 화살표 (시작점에서 위로)
                  Positioned(
                    left: center + radius * 0.85 + 6,
                    top: center + radius * 0.55,
                    child: Column(
                      children: [
                        Icon(Icons.arrow_upward, color: Colors.blue.shade700, size: 18),
                        Text(
                          '진행',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 말들
                  ..._buildPiecesOnBoard(size),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildPiecesOnBoard(double boardSize) {
    List<Widget> pieces = [];

    // 각 위치에 있는 말들을 수집
    Map<int, List<Map<String, int>>> piecesAtPosition = {};
    for (int playerIndex = 0; playerIndex < playerCount; playerIndex++) {
      for (int pieceIndex = 0;
          pieceIndex < playerPieces[playerIndex].length;
          pieceIndex++) {
        final piece = playerPieces[playerIndex][pieceIndex];
        if (piece.isOnBoard) {
          piecesAtPosition.putIfAbsent(piece.position, () => []);
          piecesAtPosition[piece.position]!.add({
            'player': playerIndex,
            'piece': pieceIndex,
          });
        }
      }
    }

    // 위치별로 말 위젯 생성
    for (var entry in piecesAtPosition.entries) {
      final position = entry.key;
      final piecesHere = entry.value;
      final pos = _getBoardPosition(position, boardSize);

      for (int i = 0; i < piecesHere.length; i++) {
        final playerIndex = piecesHere[i]['player']!;
        final pieceIndex = piecesHere[i]['piece']!;
        final piece = playerPieces[playerIndex][pieceIndex];

        // 최근 이동한 말인지 확인
        final isLastMoved = lastMovedPlayerIndex == playerIndex &&
            lastMovedPieceIndex == pieceIndex;

        // 같은 위치에 여러 말이 있을 때만 오프셋 적용
        final offset = piecesHere.length > 1
            ? _getPieceOffsetForMultiple(i, piecesHere.length)
            : Offset.zero;

        // 말 크기의 절반만큼 빼서 중앙 정렬 (기본 크기 28px)
        final pieceSize = 28.0 + piece.stackedPieces.length * 4;
        final halfSize = pieceSize / 2;

        final moveForHighlight = selectedMove;
        pieces.add(
          Positioned(
            left: pos.dx + offset.dx - halfSize,
            top: pos.dy + offset.dy - halfSize,
            child: GestureDetector(
              onTap: currentPlayer == 0 &&
                      playerIndex == 0 &&
                      pendingMoves.isNotEmpty &&
                      moveForHighlight != null
                  ? () => _selectPiece(pieceIndex)
                  : null,
              child: _buildPieceWidget(
                playerIndex,
                pieceIndex,
                piece.stackedPieces.length,
                isSelectable: currentPlayer == 0 &&
                    playerIndex == 0 &&
                    moveForHighlight != null &&
                    _canMovePiece(pieceIndex, moveForHighlight),
                isLastMoved: isLastMoved,
              ),
            ),
          ),
        );
      }
    }

    return pieces;
  }

  // 여러 말이 같은 위치에 있을 때 오프셋 계산
  Offset _getPieceOffsetForMultiple(int index, int total) {
    if (total == 2) {
      return index == 0 ? const Offset(-10, 0) : const Offset(10, 0);
    } else if (total == 3) {
      const offsets = [Offset(-10, -6), Offset(10, -6), Offset(0, 10)];
      return offsets[index];
    } else {
      const offsets = [
        Offset(-10, -10),
        Offset(10, -10),
        Offset(-10, 10),
        Offset(10, 10),
      ];
      return offsets[index % 4];
    }
  }

  Offset _getBoardPosition(int position, double size) {
    // 윷판 위치 계산 - YutBoardPainter의 점 위치와 동일하게 계산
    final center = size / 2;
    final radius = size * 0.4;

    if (position == 0) {
      // 시작점 (우하단 코너)
      return Offset(center + radius * 0.85, center + radius * 0.85);
    } else if (position >= 1 && position <= 4) {
      // 우측 하단 → 우측 상단 (i/5 간격)
      final t = position / 5;
      return Offset(
        center + radius * 0.85,
        center + radius * 0.85 - radius * 1.7 * t,
      );
    } else if (position == 5) {
      // 우상단 코너
      return Offset(center + radius * 0.85, center - radius * 0.85);
    } else if (position >= 6 && position <= 9) {
      // 우상단 → 좌상단 (i/5 간격)
      final t = (position - 5) / 5;
      return Offset(
        center + radius * 0.85 - radius * 1.7 * t,
        center - radius * 0.85,
      );
    } else if (position == 10) {
      // 좌상단 코너
      return Offset(center - radius * 0.85, center - radius * 0.85);
    } else if (position >= 11 && position <= 14) {
      // 좌상단 → 좌하단 (i/5 간격)
      final t = (position - 10) / 5;
      return Offset(
        center - radius * 0.85,
        center - radius * 0.85 + radius * 1.7 * t,
      );
    } else if (position == 15) {
      // 좌하단 코너
      return Offset(center - radius * 0.85, center + radius * 0.85);
    } else if (position >= 16 && position <= 19) {
      // 좌하단 → 우하단 (i/5 간격)
      final t = (position - 15) / 5;
      return Offset(
        center - radius * 0.85 + radius * 1.7 * t,
        center + radius * 0.85,
      );
    } else if (position == 21) {
      // 우상단 코너 (position 5와 동일)
      return Offset(center + radius * 0.85, center - radius * 0.85);
    } else if (position == 22) {
      // 우상단 대각선 첫 번째 점 (코너 → 중앙, 1/3 지점)
      return Offset(
        center + radius * 0.85 - radius * 0.85 * (1 / 3),
        center - radius * 0.85 + radius * 0.85 * (1 / 3),
      );
    } else if (position == 23) {
      // 우상단 대각선 두 번째 점 (코너 → 중앙, 2/3 지점)
      return Offset(
        center + radius * 0.85 - radius * 0.85 * (2 / 3),
        center - radius * 0.85 + radius * 0.85 * (2 / 3),
      );
    } else if (position == 24) {
      // 중앙 (우상단 경로에서 도착, position 31과 동일)
      return Offset(center, center);
    } else if (position == 25) {
      // 중앙 → 좌하단 첫 번째 점 (1/3 지점)
      return Offset(
        center - radius * 0.85 * (1 / 3),
        center + radius * 0.85 * (1 / 3),
      );
    } else if (position == 26) {
      // 중앙 → 좌하단 두 번째 점 (2/3 지점)
      return Offset(
        center - radius * 0.85 * (2 / 3),
        center + radius * 0.85 * (2 / 3),
      );
    } else if (position == 27) {
      // 좌하단 코너 (position 15와 동일, 자동으로 15로 변환됨)
      return Offset(center - radius * 0.85, center + radius * 0.85);
    } else if (position == 28) {
      // 좌상단 코너 (position 10과 동일)
      return Offset(center - radius * 0.85, center - radius * 0.85);
    } else if (position == 29) {
      // 좌상단 대각선 첫 번째 점 (코너 → 중앙, 1/3 지점)
      return Offset(
        center - radius * 0.85 + radius * 0.85 * (1 / 3),
        center - radius * 0.85 + radius * 0.85 * (1 / 3),
      );
    } else if (position == 30) {
      // 좌상단 대각선 두 번째 점 (코너 → 중앙, 2/3 지점)
      return Offset(
        center - radius * 0.85 + radius * 0.85 * (2 / 3),
        center - radius * 0.85 + radius * 0.85 * (2 / 3),
      );
    } else if (position == 31) {
      // 중앙 (정확한 중앙점)
      return Offset(center, center);
    } else if (position == 32) {
      // 중앙 → 우하단 첫 번째 점 (1/3 지점)
      return Offset(
        center + radius * 0.85 * (1 / 3),
        center + radius * 0.85 * (1 / 3),
      );
    } else if (position == 33) {
      // 중앙 → 우하단 두 번째 점 (2/3 지점)
      return Offset(
        center + radius * 0.85 * (2 / 3),
        center + radius * 0.85 * (2 / 3),
      );
    } else if (position == 34) {
      // 시작점 (position 0과 동일)
      return Offset(center + radius * 0.85, center + radius * 0.85);
    }

    return Offset(center, center);
  }

  Widget _buildPieceWidget(
    int playerIndex,
    int pieceIndex,
    int stackCount, {
    bool isSelectable = false,
    bool isLastMoved = false,
  }) {
    final color = _getPlayerColor(playerIndex);
    final size = 28.0 + stackCount * 4;

    // 테두리 색상 결정: 선택 가능 > 최근 이동 > 기본
    Color borderColor;
    double borderWidth;
    if (isSelectable) {
      borderColor = Colors.yellow;
      borderWidth = 3;
    } else if (isLastMoved) {
      borderColor = Colors.orange;
      borderWidth = 3;
    } else {
      borderColor = Colors.white;
      borderWidth = 2;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelectable
                ? Colors.yellow.withValues(alpha: 0.5)
                : isLastMoved
                    ? Colors.orange.withValues(alpha: 0.6)
                    : Colors.black.withValues(alpha: 0.3),
            blurRadius: isSelectable || isLastMoved ? 8 : 4,
          ),
        ],
      ),
      child: stackCount > 0
          ? Center(
              child: Text(
                '${stackCount + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Color _getPlayerColor(int playerIndex) {
    final colors = [
      Colors.blue, // 플레이어
      Colors.red, // 컴퓨터 1
      Colors.purple, // 컴퓨터 2 (초록 → 보라로 변경)
      Colors.orange, // 컴퓨터 3
    ];
    return colors[playerIndex % colors.length];
  }

  Widget _buildYutThrowArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // 윷 스틱 표시
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 20,
                height: 60,
                decoration: BoxDecoration(
                  color: yutStickStates[index]
                      ? const Color(0xFF8B4513)
                      : const Color(0xFFF5DEB3),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF654321), width: 2),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // 버튼 영역 (고정 높이로 말판 위치 고정)
          SizedBox(
            height: 48,
            child: Center(
              child: _buildThrowButtonContent(),
            ),
          ),
        ],
      ),
    );
  }

  // 던지기 버튼/결과 내용 위젯
  Widget _buildThrowButtonContent() {
    if (canThrowYut && currentPlayer == 0 && !isThrowingYut) {
      return GestureDetector(
        onTap: _throwYut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4CAF50), Color(0xFF388E3C)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2E7D32), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                offset: const Offset(0, 3),
                blurRadius: 4,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.casino, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                '던지기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (isThrowingYut) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade600, width: 2),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8),
            Text(
              '던지는 중',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else if (waitingForNextTurn && currentPlayer > 0) {
      // 컴퓨터 차례일 때 다음 버튼 (결과 표시보다 우선)
      return _buildPlayButton(compact: false);
    } else if (currentYutResult != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFB8860B), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.5),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: Text(
          currentYutResult!.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black54,
                offset: Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      );
    } else if (pendingMoves.isNotEmpty) {
      final canSelect = currentPlayer == 0 && pendingMoves.length > 1;
      return Wrap(
        spacing: 8,
        alignment: WrapAlignment.center,
        children: pendingMoves.asMap().entries.map((entry) {
          final index = entry.key;
          final move = entry.value;
          final isSelected = selectedMoveIndex == index;
          final isClickable = currentPlayer == 0;
          return GestureDetector(
            onTap: isClickable ? () => _selectMove(index) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFF8C00), Color(0xFFE65100)],
                      )
                    : canSelect
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF6D4C41), Color(0xFF5D4037)],
                          )
                        : null,
                color: (!isSelected && !canSelect) ? const Color(0xFF8B4513) : null,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : canSelect
                          ? const Color(0xFFFFCC80)
                          : const Color(0xFF5D4037),
                  width: isSelected ? 2 : 1.5,
                ),
                boxShadow: canSelect || isSelected
                    ? [
                        BoxShadow(
                          color: isSelected
                              ? Colors.orange.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canSelect && !isSelected)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.touch_app, color: Colors.white70, size: 14),
                    ),
                  Text(
                    move.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isSelected ? 16 : 14,
                    ),
                  ),
                  if (isSelected)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }
    return const SizedBox();
  }

  Widget _buildYutThrowAreaCompact() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 윷 스틱 (가로)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 16,
                height: 40,
                decoration: BoxDecoration(
                  color: yutStickStates[index]
                      ? const Color(0xFF8B4513)
                      : const Color(0xFFF5DEB3),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: const Color(0xFF654321), width: 1),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // 버튼 또는 결과
          if (canThrowYut && currentPlayer == 0)
            GestureDetector(
              onTap: isThrowingYut ? null : _throwYut,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B4513),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isThrowingYut ? '...' : '던지기',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else if (pendingMoves.isNotEmpty)
            Column(
              children: pendingMoves.asMap().entries.map((entry) {
                final index = entry.key;
                final move = entry.value;
                final isSelected = selectedMoveIndex == index;
                return GestureDetector(
                  onTap: currentPlayer == 0 ? () => _selectMove(index) : null,
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFF8C00) : const Color(0xFF8B4513),
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                    ),
                    child: Text(
                      move.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSelected ? 12 : 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerArea() {
    final isCurrentTurn = currentPlayer == 0;
    final finishedCount =
        playerPieces[0].where((p) => p.isFinished).length;
    final waitingCount =
        playerPieces[0].where((p) => p.isWaiting).length;

    // 이동 가능한 대기 말이 있는지 확인 (선택된 결과 또는 아무 결과로)
    bool canStartNewPiece = false;
    final moveToCheck = selectedMove ?? (pendingMoves.isNotEmpty ? pendingMoves.first : null);
    if (moveToCheck != null) {
      for (int i = 0; i < 4; i++) {
        if (playerPieces[0][i].isWaiting && _canMovePiece(i, moveToCheck)) {
          canStartNewPiece = true;
          break;
        }
      }
    }

    // 이동 가능한 말이 있는지 확인 (전체)
    bool hasMovablePiece = false;
    if (moveToCheck != null) {
      for (int i = 0; i < 4; i++) {
        if (_canMovePiece(i, moveToCheck)) {
          hasMovablePiece = true;
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrentTurn
            ? _getPlayerColor(0).withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 플레이어 정보와 말 상태
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isCurrentTurn ? _getPlayerColor(0) : const Color(0xFF8B4513),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                const Text(
                  '플레이어',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                // 말 상태: 골인/대기/진행중
                ...List.generate(4, (i) {
                  final pieceFinished = i < finishedCount;
                  final pieceWaiting = playerPieces[0][i].isWaiting;
                  return Container(
                    margin: const EdgeInsets.only(left: 3),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: pieceFinished
                          ? Colors.amber
                          : pieceWaiting
                              ? _getPlayerColor(0).withValues(alpha: 0.5)
                              : _getPlayerColor(0),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: pieceFinished
                        ? const Icon(Icons.check, color: Colors.white, size: 12)
                        : null,
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 새로 달기 버튼 (대기 말이 있고 이동 가능할 때, 자동 실행 대기 중 아닐 때)
          if (isCurrentTurn && pendingMoves.isNotEmpty && waitingCount > 0 && canStartNewPiece && !isAutoActionPending)
            GestureDetector(
              onTap: _startNewPiece,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '새로 달기 ($waitingCount)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // 건너뛰기 버튼 (이동 불가시, 자동 실행 대기 중 아닐 때)
          if (isCurrentTurn && pendingMoves.isNotEmpty && !hasMovablePiece && !isAutoActionPending)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: _skipMove,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    '건너뛰기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerAreaVertical() {
    final isCurrentTurn = currentPlayer == 0;
    final finishedCount =
        playerPieces[0].where((p) => p.isFinished).length;
    final waitingPieces = playerPieces[0]
        .asMap()
        .entries
        .where((e) => e.value.isWaiting)
        .toList();

    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCurrentTurn ? Colors.blue : const Color(0xFF8B4513),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    const Text(
                      '플레이어',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // 골인한 말
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(4, (i) {
                    return Container(
                      margin: const EdgeInsets.only(left: 2),
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: i < finishedCount
                            ? _getPlayerColor(0)
                            : Colors.grey.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 대기 중인 말들
          if (waitingPieces.isNotEmpty)
            Column(
              children: [
                const Text(
                  '대기',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: waitingPieces.map((entry) {
                    final moveForCheck = selectedMove;
                    final canMove = moveForCheck != null &&
                        currentPlayer == 0 &&
                        _canMovePiece(entry.key, moveForCheck);
                    return GestureDetector(
                      onTap: canMove ? () => _selectPiece(entry.key) : null,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _getPlayerColor(0),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: canMove ? Colors.yellow : Colors.white,
                            width: canMove ? 2 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // 등수순으로 정렬된 순위 리스트 생성
  List<Widget> _buildRankingList() {
    // 모든 플레이어를 등수순으로 정렬
    List<int> sortedPlayers = List.generate(playerCount, (i) => i);
    sortedPlayers.sort((a, b) {
      final rankA = rankings.contains(a) ? rankings.indexOf(a) : playerCount;
      final rankB = rankings.contains(b) ? rankings.indexOf(b) : playerCount;
      return rankA.compareTo(rankB);
    });

    return sortedPlayers.map((playerIndex) {
      final rank = rankings.contains(playerIndex)
          ? rankings.indexOf(playerIndex) + 1
          : rankings.length + 1;
      final isPlayer = playerIndex == 0;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$rank등: ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isPlayer ? FontWeight.bold : FontWeight.normal,
                color: isPlayer ? Colors.blue.shade800 : Colors.grey.shade700,
              ),
            ),
            Text(
              _getPlayerName(playerIndex),
              style: TextStyle(
                fontSize: 14,
                fontWeight: isPlayer ? FontWeight.bold : FontWeight.normal,
                color: isPlayer ? Colors.blue.shade800 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildGameOverOverlay() {
    // 플레이어 등수 계산
    final playerRank = rankings.contains(0) ? rankings.indexOf(0) + 1 : rankings.length + 1;
    final isFirstPlace = playerRank == 1;

    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFFDEB887),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFirstPlace ? Colors.amber : Colors.blue,
              width: 3,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFirstPlace ? Icons.emoji_events : Icons.flag,
                color: isFirstPlace ? Colors.amber : Colors.blue,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                '게임 종료',
                style: const TextStyle(
                  color: Color(0xFF8B4513),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '나의 등수: $playerRank등',
                style: TextStyle(
                  color: isFirstPlace ? Colors.amber.shade800 : Colors.blue.shade800,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // 전체 순위 표시
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      '순위',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B4513),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._buildRankingList(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _restartGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  '다시 하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 윷판 그리기
class YutBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final fillPaint = Paint()
      ..color = const Color(0xFFF5DEB3)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // 배경 원
    canvas.drawCircle(center, radius * 1.1, fillPaint);
    canvas.drawCircle(center, radius * 1.1, paint);

    // 외곽 사각형
    final rect = Rect.fromCenter(
      center: center,
      width: radius * 1.7,
      height: radius * 1.7,
    );
    canvas.drawRect(rect, paint);

    // 대각선
    canvas.drawLine(
      Offset(center.dx - radius * 0.85, center.dy - radius * 0.85),
      Offset(center.dx + radius * 0.85, center.dy + radius * 0.85),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + radius * 0.85, center.dy - radius * 0.85),
      Offset(center.dx - radius * 0.85, center.dy + radius * 0.85),
      paint,
    );

    // 위치 점들
    final dotPaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.fill;

    final positions = _getAllPositions(center, radius);
    for (var pos in positions) {
      canvas.drawCircle(pos, 6, dotPaint);
      canvas.drawCircle(
          pos,
          6,
          Paint()
            ..color = const Color(0xFF654321)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }

    // 코너 큰 점
    final cornerPositions = [
      Offset(center.dx + radius * 0.85, center.dy + radius * 0.85), // 시작
      Offset(center.dx + radius * 0.85, center.dy - radius * 0.85), // 우상
      Offset(center.dx - radius * 0.85, center.dy - radius * 0.85), // 좌상
      Offset(center.dx - radius * 0.85, center.dy + radius * 0.85), // 좌하
      center, // 중앙
    ];

    for (var pos in cornerPositions) {
      canvas.drawCircle(pos, 10, dotPaint);
      canvas.drawCircle(
          pos,
          10,
          Paint()
            ..color = const Color(0xFF654321)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  List<Offset> _getAllPositions(Offset center, double radius) {
    List<Offset> positions = [];

    // 외곽 점들 (코너 제외)
    for (int i = 1; i <= 4; i++) {
      // 우측
      positions.add(Offset(
        center.dx + radius * 0.85,
        center.dy + radius * 0.85 - radius * 1.7 * (i / 5),
      ));
    }
    for (int i = 1; i <= 4; i++) {
      // 상단
      positions.add(Offset(
        center.dx + radius * 0.85 - radius * 1.7 * (i / 5),
        center.dy - radius * 0.85,
      ));
    }
    for (int i = 1; i <= 4; i++) {
      // 좌측
      positions.add(Offset(
        center.dx - radius * 0.85,
        center.dy - radius * 0.85 + radius * 1.7 * (i / 5),
      ));
    }
    for (int i = 1; i <= 4; i++) {
      // 하단
      positions.add(Offset(
        center.dx - radius * 0.85 + radius * 1.7 * (i / 5),
        center.dy + radius * 0.85,
      ));
    }

    // 대각선 점들 - 게임 위치와 일치하도록 (간격 균일하게 1/3, 2/3)
    // 우상단(5) → 중앙: 2개 점 (positions 20, 21)
    for (int i = 1; i <= 2; i++) {
      positions.add(Offset(
        center.dx + radius * 0.85 - radius * 0.85 * (i / 3),
        center.dy - radius * 0.85 + radius * 0.85 * (i / 3),
      ));
    }
    // 좌상단(10) → 중앙: 2개 점 (positions 25, 26)
    for (int i = 1; i <= 2; i++) {
      positions.add(Offset(
        center.dx - radius * 0.85 + radius * 0.85 * (i / 3),
        center.dy - radius * 0.85 + radius * 0.85 * (i / 3),
      ));
    }
    // 중앙 → 우하단 (출발/골인 방향): 2개 점 (positions 28, 29)
    for (int i = 1; i <= 2; i++) {
      positions.add(Offset(
        center.dx + radius * 0.85 * (i / 3),
        center.dy + radius * 0.85 * (i / 3),
      ));
    }
    // 중앙 → 좌하단: 2개 점 (positions 30, 31)
    for (int i = 1; i <= 2; i++) {
      positions.add(Offset(
        center.dx - radius * 0.85 * (i / 3),
        center.dy + radius * 0.85 * (i / 3),
      ));
    }

    return positions;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
