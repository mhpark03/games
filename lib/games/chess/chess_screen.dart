import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/game_save_service.dart';

enum PieceType { king, queen, rook, bishop, knight, pawn }
enum PieceColor { white, black }

class ChessPiece {
  final PieceType type;
  final PieceColor color;
  bool hasMoved;

  ChessPiece({required this.type, required this.color, this.hasMoved = false});

  String get symbol {
    const symbols = {
      PieceType.king: '♚',
      PieceType.queen: '♛',
      PieceType.rook: '♜',
      PieceType.bishop: '♝',
      PieceType.knight: '♞',
      PieceType.pawn: '♟',
    };
    return symbols[type]!;
  }

  int get value {
    const values = {
      PieceType.king: 10000,
      PieceType.queen: 900,
      PieceType.rook: 500,
      PieceType.bishop: 330,
      PieceType.knight: 320,
      PieceType.pawn: 100,
    };
    return values[type]!;
  }

  ChessPiece copy() => ChessPiece(type: type, color: color, hasMoved: hasMoved);

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'color': color.index,
    'hasMoved': hasMoved,
  };

  factory ChessPiece.fromJson(Map<String, dynamic> json) => ChessPiece(
    type: PieceType.values[json['type']],
    color: PieceColor.values[json['color']],
    hasMoved: json['hasMoved'] ?? false,
  );
}

enum ChessGameMode {
  vsComputerWhite,
  vsComputerBlack,
  vsPerson,
}

class ChessScreen extends StatefulWidget {
  final ChessGameMode gameMode;
  final bool resumeGame;

  const ChessScreen({
    super.key,
    this.gameMode = ChessGameMode.vsComputerWhite,
    this.resumeGame = false,
  });

  static Future<bool> hasSavedGame() async {
    return await GameSaveService.hasSavedGame('chess');
  }

  static Future<ChessGameMode?> getSavedGameMode() async {
    final gameState = await GameSaveService.loadGame('chess');
    if (gameState == null) return null;
    final modeIndex = gameState['gameMode'] as int?;
    if (modeIndex == null) return null;
    return ChessGameMode.values[modeIndex];
  }

  static Future<void> clearSavedGame() async {
    await GameSaveService.clearSave();
  }

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  late List<List<ChessPiece?>> board;
  bool isWhiteTurn = true;
  bool gameOver = false;
  String gameMessage = '';
  List<int>? selectedSquare;
  List<List<int>> validMoves = [];
  List<int>? enPassantTarget;
  bool isInCheck = false;
  // 수 히스토리: 되돌리기용
  List<Map<String, dynamic>> moveHistory = [];

  bool get isUserWhite => widget.gameMode != ChessGameMode.vsComputerBlack;

  bool get isUserTurn {
    if (widget.gameMode == ChessGameMode.vsPerson) return true;
    if (widget.gameMode == ChessGameMode.vsComputerWhite) return isWhiteTurn;
    return !isWhiteTurn;
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

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _initBoard() {
    board = List.generate(8, (_) => List.generate(8, (_) => null));

    // 백 기물 배치
    board[7][0] = ChessPiece(type: PieceType.rook, color: PieceColor.white);
    board[7][1] = ChessPiece(type: PieceType.knight, color: PieceColor.white);
    board[7][2] = ChessPiece(type: PieceType.bishop, color: PieceColor.white);
    board[7][3] = ChessPiece(type: PieceType.queen, color: PieceColor.white);
    board[7][4] = ChessPiece(type: PieceType.king, color: PieceColor.white);
    board[7][5] = ChessPiece(type: PieceType.bishop, color: PieceColor.white);
    board[7][6] = ChessPiece(type: PieceType.knight, color: PieceColor.white);
    board[7][7] = ChessPiece(type: PieceType.rook, color: PieceColor.white);
    for (int i = 0; i < 8; i++) {
      board[6][i] = ChessPiece(type: PieceType.pawn, color: PieceColor.white);
    }

    // 흑 기물 배치
    board[0][0] = ChessPiece(type: PieceType.rook, color: PieceColor.black);
    board[0][1] = ChessPiece(type: PieceType.knight, color: PieceColor.black);
    board[0][2] = ChessPiece(type: PieceType.bishop, color: PieceColor.black);
    board[0][3] = ChessPiece(type: PieceType.queen, color: PieceColor.black);
    board[0][4] = ChessPiece(type: PieceType.king, color: PieceColor.black);
    board[0][5] = ChessPiece(type: PieceType.bishop, color: PieceColor.black);
    board[0][6] = ChessPiece(type: PieceType.knight, color: PieceColor.black);
    board[0][7] = ChessPiece(type: PieceType.rook, color: PieceColor.black);
    for (int i = 0; i < 8; i++) {
      board[1][i] = ChessPiece(type: PieceType.pawn, color: PieceColor.black);
    }

    isWhiteTurn = true;
    gameOver = false;
    selectedSquare = null;
    validMoves = [];
    enPassantTarget = null;
    isInCheck = false;
    moveHistory = [];
    _updateMessage();

    if (widget.gameMode == ChessGameMode.vsComputerBlack) {
      gameMessage = '컴퓨터가 생각 중...';
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _computerMove();
      });
    }
  }

  Future<void> _saveGame() async {
    if (gameOver) {
      await ChessScreen.clearSavedGame();
      return;
    }

    final boardData = board.map((row) => row.map((p) => p?.toJson()).toList()).toList();

    final gameState = {
      'board': boardData,
      'isWhiteTurn': isWhiteTurn,
      'gameMode': widget.gameMode.index,
      'enPassantTarget': enPassantTarget,
    };

    await GameSaveService.saveGame('chess', gameState);
  }

  Future<void> _loadGame() async {
    final gameState = await GameSaveService.loadGame('chess');

    if (gameState == null) {
      _initBoard();
      return;
    }

    final boardData = gameState['board'] as List;
    board = boardData.map<List<ChessPiece?>>((row) {
      return (row as List).map<ChessPiece?>((p) {
        if (p == null) return null;
        return ChessPiece.fromJson(p as Map<String, dynamic>);
      }).toList();
    }).toList();

    isWhiteTurn = gameState['isWhiteTurn'] as bool? ?? true;
    final epData = gameState['enPassantTarget'];
    enPassantTarget = epData != null ? List<int>.from(epData as List) : null;
    gameOver = false;
    selectedSquare = null;
    validMoves = [];

    final currentColor = isWhiteTurn ? PieceColor.white : PieceColor.black;
    isInCheck = _isKingInCheck(currentColor);

    setState(() {
      _updateMessage();
    });

    if (!isUserTurn && widget.gameMode != ChessGameMode.vsPerson) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _computerMove();
      });
    }
  }

  void _updateMessage() {
    if (gameOver) return;

    String turnText;
    switch (widget.gameMode) {
      case ChessGameMode.vsComputerWhite:
        turnText = isWhiteTurn ? '당신의 차례입니다 (백)' : '컴퓨터가 생각 중...';
        break;
      case ChessGameMode.vsComputerBlack:
        turnText = isWhiteTurn ? '컴퓨터가 생각 중...' : '당신의 차례입니다 (흑)';
        break;
      case ChessGameMode.vsPerson:
        turnText = isWhiteTurn ? '백 차례입니다' : '흑 차례입니다';
        break;
    }

    if (isInCheck) {
      turnText += ' (체크!)';
    }

    gameMessage = turnText;
  }

  void _resetGame() {
    ChessScreen.clearSavedGame();
    setState(() {
      _initBoard();
    });
  }

  void _onSquareTap(int row, int col) {
    if (gameOver || !isUserTurn) return;

    final piece = board[row][col];
    final currentColor = isWhiteTurn ? PieceColor.white : PieceColor.black;

    if (selectedSquare != null) {
      // 이미 선택된 기물이 있으면
      if (validMoves.any((m) => m[0] == row && m[1] == col)) {
        // 유효한 수면 이동
        _makeMove(selectedSquare![0], selectedSquare![1], row, col);
        return;
      }
    }

    // 새로운 기물 선택
    if (piece != null && piece.color == currentColor) {
      setState(() {
        selectedSquare = [row, col];
        validMoves = _getValidMoves(row, col);
      });
    } else {
      setState(() {
        selectedSquare = null;
        validMoves = [];
      });
    }
  }

  void _makeMove(int fromRow, int fromCol, int toRow, int toCol) {
    final piece = board[fromRow][fromCol]!;
    final captured = board[toRow][toCol];
    final pieceHadMoved = piece.hasMoved;
    final previousEnPassant = enPassantTarget != null ? List<int>.from(enPassantTarget!) : null;

    // 히스토리 기록 준비
    bool wasEnPassant = false;
    ChessPiece? enPassantCaptured;
    bool wasCastling = false;
    bool castlingKingside = false;
    bool? rookHadMoved;
    bool wasPromotion = false;

    setState(() {
      // 앙파상 처리
      if (piece.type == PieceType.pawn && enPassantTarget != null &&
          toRow == enPassantTarget![0] && toCol == enPassantTarget![1]) {
        wasEnPassant = true;
        enPassantCaptured = board[fromRow][toCol]?.copy();
        board[fromRow][toCol] = null;
      }

      // 캐슬링 처리
      if (piece.type == PieceType.king && (toCol - fromCol).abs() == 2) {
        wasCastling = true;
        if (toCol > fromCol) {
          // 킹사이드 캐슬링
          castlingKingside = true;
          rookHadMoved = board[fromRow][7]!.hasMoved;
          board[fromRow][5] = board[fromRow][7];
          board[fromRow][7] = null;
          board[fromRow][5]!.hasMoved = true;
        } else {
          // 퀸사이드 캐슬링
          castlingKingside = false;
          rookHadMoved = board[fromRow][0]!.hasMoved;
          board[fromRow][3] = board[fromRow][0];
          board[fromRow][0] = null;
          board[fromRow][3]!.hasMoved = true;
        }
      }

      // 앙파상 타겟 설정
      if (piece.type == PieceType.pawn && (toRow - fromRow).abs() == 2) {
        enPassantTarget = [(fromRow + toRow) ~/ 2, fromCol];
      } else {
        enPassantTarget = null;
      }

      // 이동 실행
      board[toRow][toCol] = piece;
      board[fromRow][fromCol] = null;
      piece.hasMoved = true;

      // 폰 프로모션
      if (piece.type == PieceType.pawn) {
        if ((piece.color == PieceColor.white && toRow == 0) ||
            (piece.color == PieceColor.black && toRow == 7)) {
          wasPromotion = true;
          board[toRow][toCol] = ChessPiece(
            type: PieceType.queen,
            color: piece.color,
            hasMoved: true,
          );
        }
      }

      // 히스토리에 저장
      moveHistory.add({
        'fromRow': fromRow,
        'fromCol': fromCol,
        'toRow': toRow,
        'toCol': toCol,
        'pieceType': piece.type,
        'pieceColor': piece.color,
        'pieceHadMoved': pieceHadMoved,
        'captured': captured?.copy(),
        'wasEnPassant': wasEnPassant,
        'enPassantCaptured': enPassantCaptured,
        'wasCastling': wasCastling,
        'castlingKingside': castlingKingside,
        'rookHadMoved': rookHadMoved,
        'wasPromotion': wasPromotion,
        'previousEnPassant': previousEnPassant,
      });

      selectedSquare = null;
      validMoves = [];
      isWhiteTurn = !isWhiteTurn;

      final nextColor = isWhiteTurn ? PieceColor.white : PieceColor.black;
      isInCheck = _isKingInCheck(nextColor);

      // 체크메이트/스테일메이트 확인
      if (!_hasAnyValidMove(nextColor)) {
        gameOver = true;
        if (isInCheck) {
          _setWinMessage(piece.color);
        } else {
          gameMessage = '스테일메이트! 무승부입니다.';
        }
        _saveGame();
        return;
      }

      _updateMessage();
    });

    _saveGame();

    if (!gameOver && widget.gameMode != ChessGameMode.vsPerson && !isUserTurn) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _computerMove();
      });
    }
  }

  // 되돌리기 기능
  void _undoMove() {
    if (moveHistory.isEmpty || gameOver) return;

    setState(() {
      // 컴퓨터 대전 모드에서는 2수 되돌리기 (사용자 + 컴퓨터)
      int undoCount = widget.gameMode == ChessGameMode.vsPerson ? 1 : 2;

      for (int i = 0; i < undoCount && moveHistory.isNotEmpty; i++) {
        final lastMove = moveHistory.removeLast();
        final fromRow = lastMove['fromRow'] as int;
        final fromCol = lastMove['fromCol'] as int;
        final toRow = lastMove['toRow'] as int;
        final toCol = lastMove['toCol'] as int;
        final pieceType = lastMove['pieceType'] as PieceType;
        final pieceColor = lastMove['pieceColor'] as PieceColor;
        final pieceHadMoved = lastMove['pieceHadMoved'] as bool;
        final captured = lastMove['captured'] as ChessPiece?;
        final wasEnPassant = lastMove['wasEnPassant'] as bool;
        final enPassantCaptured = lastMove['enPassantCaptured'] as ChessPiece?;
        final wasCastling = lastMove['wasCastling'] as bool;
        final castlingKingside = lastMove['castlingKingside'] as bool;
        final rookHadMoved = lastMove['rookHadMoved'] as bool?;
        final wasPromotion = lastMove['wasPromotion'] as bool;
        final previousEnPassant = lastMove['previousEnPassant'] as List<int>?;

        // 기물 복원 (프로모션인 경우 폰으로 복원)
        final restoredPiece = ChessPiece(
          type: wasPromotion ? PieceType.pawn : pieceType,
          color: pieceColor,
          hasMoved: pieceHadMoved,
        );
        board[fromRow][fromCol] = restoredPiece;
        board[toRow][toCol] = captured;

        // 앙파상 복원
        if (wasEnPassant && enPassantCaptured != null) {
          board[fromRow][toCol] = enPassantCaptured;
        }

        // 캐슬링 복원
        if (wasCastling) {
          if (castlingKingside) {
            // 킹사이드 캐슬링 복원
            final rook = board[fromRow][5]!;
            rook.hasMoved = rookHadMoved ?? false;
            board[fromRow][7] = rook;
            board[fromRow][5] = null;
          } else {
            // 퀸사이드 캐슬링 복원
            final rook = board[fromRow][3]!;
            rook.hasMoved = rookHadMoved ?? false;
            board[fromRow][0] = rook;
            board[fromRow][3] = null;
          }
        }

        // 앙파상 타겟 복원
        enPassantTarget = previousEnPassant;

        // 턴 복원
        isWhiteTurn = !isWhiteTurn;
      }

      // 체크 상태 업데이트
      final currentColor = isWhiteTurn ? PieceColor.white : PieceColor.black;
      isInCheck = _isKingInCheck(currentColor);

      _updateMessage();
    });

    _saveGame();
  }

  void _setWinMessage(PieceColor winner) {
    switch (widget.gameMode) {
      case ChessGameMode.vsComputerWhite:
        gameMessage = winner == PieceColor.white
            ? '체크메이트! 당신이 이겼습니다!'
            : '체크메이트! 컴퓨터가 이겼습니다.';
        break;
      case ChessGameMode.vsComputerBlack:
        gameMessage = winner == PieceColor.black
            ? '체크메이트! 당신이 이겼습니다!'
            : '체크메이트! 컴퓨터가 이겼습니다.';
        break;
      case ChessGameMode.vsPerson:
        gameMessage = winner == PieceColor.white
            ? '체크메이트! 백이 이겼습니다!'
            : '체크메이트! 흑이 이겼습니다!';
        break;
    }
  }

  List<List<int>> _getValidMoves(int row, int col) {
    final piece = board[row][col];
    if (piece == null) return [];

    List<List<int>> moves = [];
    final color = piece.color;

    switch (piece.type) {
      case PieceType.pawn:
        moves = _getPawnMoves(row, col, color);
        break;
      case PieceType.knight:
        moves = _getKnightMoves(row, col, color);
        break;
      case PieceType.bishop:
        moves = _getBishopMoves(row, col, color);
        break;
      case PieceType.rook:
        moves = _getRookMoves(row, col, color);
        break;
      case PieceType.queen:
        moves = [..._getBishopMoves(row, col, color), ..._getRookMoves(row, col, color)];
        break;
      case PieceType.king:
        moves = _getKingMoves(row, col, color);
        break;
    }

    // 체크 상태를 벗어나는 수만 필터링
    moves = moves.where((move) {
      return !_wouldBeInCheck(row, col, move[0], move[1], color);
    }).toList();

    return moves;
  }

  List<List<int>> _getPawnMoves(int row, int col, PieceColor color) {
    List<List<int>> moves = [];
    final direction = color == PieceColor.white ? -1 : 1;
    final startRow = color == PieceColor.white ? 6 : 1;

    // 전진
    if (_isInBounds(row + direction, col) && board[row + direction][col] == null) {
      moves.add([row + direction, col]);
      // 첫 이동 시 2칸
      if (row == startRow && board[row + 2 * direction][col] == null) {
        moves.add([row + 2 * direction, col]);
      }
    }

    // 대각선 공격
    for (int dc in [-1, 1]) {
      if (_isInBounds(row + direction, col + dc)) {
        final target = board[row + direction][col + dc];
        if (target != null && target.color != color) {
          moves.add([row + direction, col + dc]);
        }
        // 앙파상
        if (enPassantTarget != null &&
            enPassantTarget![0] == row + direction &&
            enPassantTarget![1] == col + dc) {
          moves.add([row + direction, col + dc]);
        }
      }
    }

    return moves;
  }

  List<List<int>> _getKnightMoves(int row, int col, PieceColor color) {
    List<List<int>> moves = [];
    final offsets = [
      [-2, -1], [-2, 1], [-1, -2], [-1, 2],
      [1, -2], [1, 2], [2, -1], [2, 1],
    ];

    for (var offset in offsets) {
      final r = row + offset[0];
      final c = col + offset[1];
      if (_isInBounds(r, c)) {
        final target = board[r][c];
        if (target == null || target.color != color) {
          moves.add([r, c]);
        }
      }
    }

    return moves;
  }

  List<List<int>> _getBishopMoves(int row, int col, PieceColor color) {
    return _getSlidingMoves(row, col, color, [[-1, -1], [-1, 1], [1, -1], [1, 1]]);
  }

  List<List<int>> _getRookMoves(int row, int col, PieceColor color) {
    return _getSlidingMoves(row, col, color, [[-1, 0], [1, 0], [0, -1], [0, 1]]);
  }

  List<List<int>> _getSlidingMoves(int row, int col, PieceColor color, List<List<int>> directions) {
    List<List<int>> moves = [];

    for (var dir in directions) {
      int r = row + dir[0];
      int c = col + dir[1];

      while (_isInBounds(r, c)) {
        final target = board[r][c];
        if (target == null) {
          moves.add([r, c]);
        } else {
          if (target.color != color) {
            moves.add([r, c]);
          }
          break;
        }
        r += dir[0];
        c += dir[1];
      }
    }

    return moves;
  }

  List<List<int>> _getKingMoves(int row, int col, PieceColor color) {
    List<List<int>> moves = [];
    final piece = board[row][col]!;

    // 일반 이동
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final r = row + dr;
        final c = col + dc;
        if (_isInBounds(r, c)) {
          final target = board[r][c];
          if (target == null || target.color != color) {
            moves.add([r, c]);
          }
        }
      }
    }

    // 캐슬링
    if (!piece.hasMoved && !isInCheck) {
      // 킹사이드
      if (_canCastle(row, col, true, color)) {
        moves.add([row, col + 2]);
      }
      // 퀸사이드
      if (_canCastle(row, col, false, color)) {
        moves.add([row, col - 2]);
      }
    }

    return moves;
  }

  bool _canCastle(int row, int col, bool kingSide, PieceColor color) {
    final rookCol = kingSide ? 7 : 0;
    final rook = board[row][rookCol];

    if (rook == null || rook.type != PieceType.rook || rook.hasMoved) {
      return false;
    }

    // 사이에 기물이 없는지 확인
    final start = kingSide ? col + 1 : 1;
    final end = kingSide ? rookCol : col;
    for (int c = start; c < end; c++) {
      if (board[row][c] != null) return false;
    }

    // 킹이 지나가는 칸이 공격받지 않는지 확인
    final step = kingSide ? 1 : -1;
    for (int c = col; c != col + 3 * step; c += step) {
      if (_isSquareAttacked(row, c, color)) return false;
    }

    return true;
  }

  bool _isInBounds(int row, int col) {
    return row >= 0 && row < 8 && col >= 0 && col < 8;
  }

  bool _isKingInCheck(PieceColor color) {
    // 킹 위치 찾기
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = board[r][c];
        if (piece != null && piece.type == PieceType.king && piece.color == color) {
          return _isSquareAttacked(r, c, color);
        }
      }
    }
    return false;
  }

  bool _isSquareAttacked(int row, int col, PieceColor defendingColor) {
    final attackingColor = defendingColor == PieceColor.white ? PieceColor.black : PieceColor.white;

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = board[r][c];
        if (piece != null && piece.color == attackingColor) {
          final moves = _getRawMoves(r, c, piece);
          if (moves.any((m) => m[0] == row && m[1] == col)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  List<List<int>> _getRawMoves(int row, int col, ChessPiece piece) {
    switch (piece.type) {
      case PieceType.pawn:
        // 폰의 공격 방향만 확인
        final direction = piece.color == PieceColor.white ? -1 : 1;
        List<List<int>> moves = [];
        for (int dc in [-1, 1]) {
          if (_isInBounds(row + direction, col + dc)) {
            moves.add([row + direction, col + dc]);
          }
        }
        return moves;
      case PieceType.knight:
        return _getKnightMoves(row, col, piece.color);
      case PieceType.bishop:
        return _getBishopMoves(row, col, piece.color);
      case PieceType.rook:
        return _getRookMoves(row, col, piece.color);
      case PieceType.queen:
        return [..._getBishopMoves(row, col, piece.color), ..._getRookMoves(row, col, piece.color)];
      case PieceType.king:
        List<List<int>> moves = [];
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final r = row + dr;
            final c = col + dc;
            if (_isInBounds(r, c)) {
              moves.add([r, c]);
            }
          }
        }
        return moves;
    }
  }

  bool _wouldBeInCheck(int fromRow, int fromCol, int toRow, int toCol, PieceColor color) {
    // 임시로 이동
    final piece = board[fromRow][fromCol];
    final captured = board[toRow][toCol];
    board[toRow][toCol] = piece;
    board[fromRow][fromCol] = null;

    final inCheck = _isKingInCheck(color);

    // 원복
    board[fromRow][fromCol] = piece;
    board[toRow][toCol] = captured;

    return inCheck;
  }

  bool _hasAnyValidMove(PieceColor color) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = board[r][c];
        if (piece != null && piece.color == color) {
          if (_getValidMoves(r, c).isNotEmpty) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _computerMove() {
    if (gameOver) return;

    final color = isWhiteTurn ? PieceColor.white : PieceColor.black;
    final move = _findBestMove(color, 2);

    if (move != null) {
      _makeMove(move[0], move[1], move[2], move[3]);
    }
  }

  List<int>? _findBestMove(PieceColor color, int depth) {
    List<int>? bestMove;
    int bestScore = -999999;
    List<List<int>> allMoves = [];

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = board[r][c];
        if (piece != null && piece.color == color) {
          final moves = _getValidMoves(r, c);
          for (var move in moves) {
            allMoves.add([r, c, move[0], move[1]]);
          }
        }
      }
    }

    // 무작위 셔플하여 같은 점수일 때 다양한 수 선택
    allMoves.shuffle(Random());

    for (var move in allMoves) {
      final score = _evaluateMove(move[0], move[1], move[2], move[3], color, depth);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove;
  }

  int _evaluateMove(int fromRow, int fromCol, int toRow, int toCol, PieceColor color, int depth) {
    // 임시 이동
    final piece = board[fromRow][fromCol]!;
    final captured = board[toRow][toCol];
    final oldEnPassant = enPassantTarget;
    final oldHasMoved = piece.hasMoved;

    board[toRow][toCol] = piece;
    board[fromRow][fromCol] = null;
    piece.hasMoved = true;

    // 앙파상 타겟 업데이트
    if (piece.type == PieceType.pawn && (toRow - fromRow).abs() == 2) {
      enPassantTarget = [(fromRow + toRow) ~/ 2, fromCol];
    } else {
      enPassantTarget = null;
    }

    int score;
    if (depth <= 0) {
      score = _evaluateBoard(color);
    } else {
      final opponentColor = color == PieceColor.white ? PieceColor.black : PieceColor.white;
      final opponentBest = _findBestMoveScore(opponentColor, depth - 1);
      score = -opponentBest;
    }

    // 원복
    board[fromRow][fromCol] = piece;
    board[toRow][toCol] = captured;
    piece.hasMoved = oldHasMoved;
    enPassantTarget = oldEnPassant;

    return score;
  }

  int _findBestMoveScore(PieceColor color, int depth) {
    int bestScore = -999999;

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = board[r][c];
        if (piece != null && piece.color == color) {
          final moves = _getValidMoves(r, c);
          for (var move in moves) {
            final score = _evaluateMove(r, c, move[0], move[1], color, depth);
            if (score > bestScore) {
              bestScore = score;
            }
          }
        }
      }
    }

    return bestScore == -999999 ? 0 : bestScore;
  }

  int _evaluateBoard(PieceColor color) {
    int score = 0;

    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = board[r][c];
        if (piece != null) {
          int pieceScore = piece.value;
          // 위치 보너스
          pieceScore += _getPositionBonus(piece, r, c);

          if (piece.color == color) {
            score += pieceScore;
          } else {
            score -= pieceScore;
          }
        }
      }
    }

    return score;
  }

  int _getPositionBonus(ChessPiece piece, int row, int col) {
    // 중앙 제어 보너스
    int centerBonus = 0;
    if (col >= 2 && col <= 5 && row >= 2 && row <= 5) {
      centerBonus = 10;
      if (col >= 3 && col <= 4 && row >= 3 && row <= 4) {
        centerBonus = 20;
      }
    }

    // 폰 전진 보너스
    if (piece.type == PieceType.pawn) {
      if (piece.color == PieceColor.white) {
        centerBonus += (6 - row) * 10;
      } else {
        centerBonus += (row - 1) * 10;
      }
    }

    return centerBonus;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
            return _buildLandscapeLayout();
          } else {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
            return _buildPortraitLayout();
          }
        },
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '체스',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown.shade700,
        foregroundColor: Colors.white,
        actions: [
          Opacity(
            opacity: moveHistory.isNotEmpty && !gameOver ? 1.0 : 0.3,
            child: IconButton(
              icon: const Icon(Icons.undo),
              onPressed: moveHistory.isNotEmpty && !gameOver ? _undoMove : null,
              tooltip: '되돌리기',
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
              Colors.brown.shade800,
              Colors.black,
            ],
          ),
        ),
        child: Column(
          children: [
            // 메시지
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: gameOver
                      ? (gameMessage.contains('당신이')
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.3))
                      : isInCheck
                          ? Colors.orange.withValues(alpha: 0.3)
                          : Colors.brown.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: gameOver
                        ? (gameMessage.contains('당신이') ? Colors.green : Colors.red)
                        : isInCheck
                            ? Colors.orange
                            : Colors.brown.shade400,
                    width: 2,
                  ),
                ),
                child: Text(
                  gameMessage,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: gameOver
                        ? (gameMessage.contains('당신이') ? Colors.green : Colors.red)
                        : isInCheck
                            ? Colors.orange
                            : Colors.brown.shade200,
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
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                        ),
                        itemCount: 64,
                        itemBuilder: (context, index) {
                          final row = index ~/ 8;
                          final col = index % 8;
                          return _buildSquare(row, col);
                        },
                      ),
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

  Widget _buildLandscapeLayout() {
    String whitePlayerName;
    String blackPlayerName;

    switch (widget.gameMode) {
      case ChessGameMode.vsComputerWhite:
        whitePlayerName = '당신';
        blackPlayerName = '컴퓨터';
        break;
      case ChessGameMode.vsComputerBlack:
        whitePlayerName = '컴퓨터';
        blackPlayerName = '당신';
        break;
      case ChessGameMode.vsPerson:
        whitePlayerName = '플레이어 1';
        blackPlayerName = '플레이어 2';
        break;
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.brown.shade800,
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
                  // 왼쪽 패널: 백 플레이어
                  Expanded(
                    child: Center(
                      child: _buildPlayerIndicator(
                        isWhite: true,
                        playerName: whitePlayerName,
                        isCurrentTurn: isWhiteTurn && !gameOver,
                      ),
                    ),
                  ),
                  // 가운데: 체스 보드
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
                  // 오른쪽 패널: 흑 플레이어
                  Expanded(
                    child: Center(
                      child: _buildPlayerIndicator(
                        isWhite: false,
                        playerName: blackPlayerName,
                        isCurrentTurn: !isWhiteTurn && !gameOver,
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
                        '체스',
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
                      onPressed: moveHistory.isNotEmpty && !gameOver ? _undoMove : null,
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

  Widget _buildCircleButton({
    required IconData icon,
    VoidCallback? onPressed,
    String? tooltip,
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
            message: tooltip ?? '',
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

  Widget _buildPlayerIndicator({
    required bool isWhite,
    required String playerName,
    required bool isCurrentTurn,
  }) {
    final color = isWhite ? Colors.white : Colors.black;
    final borderColor = isCurrentTurn ? Colors.brown.shade300 : Colors.brown.shade700;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.brown.shade900.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: isCurrentTurn ? 3 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: isWhite ? Colors.grey : Colors.grey.shade400,
                width: isWhite ? 1 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            playerName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.brown.shade200,
            ),
          ),
          Text(
            isWhite ? '(백)' : '(흑)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.brown.shade400,
            ),
          ),
          if (isCurrentTurn && !gameOver)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isInCheck ? Colors.orange : Colors.brown.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isInCheck ? '체크!' : '차례',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (gameOver)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: gameMessage.contains('당신이')
                      ? (widget.gameMode == ChessGameMode.vsComputerWhite && isWhite) ||
                        (widget.gameMode == ChessGameMode.vsComputerBlack && !isWhite)
                          ? Colors.green
                          : Colors.red
                      : gameMessage.contains('백이') && isWhite || gameMessage.contains('흑이') && !isWhite
                          ? Colors.green
                          : gameMessage.contains('무승부')
                              ? Colors.grey
                              : Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  gameMessage.contains('무승부')
                      ? '무승부'
                      : gameMessage.contains('당신이')
                          ? (widget.gameMode == ChessGameMode.vsComputerWhite && isWhite) ||
                            (widget.gameMode == ChessGameMode.vsComputerBlack && !isWhite)
                              ? '승리'
                              : '패배'
                          : (gameMessage.contains('백이') && isWhite) || (gameMessage.contains('흑이') && !isWhite)
                              ? '승리'
                              : '패배',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameBoard() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 64,
          itemBuilder: (context, index) {
            final row = index ~/ 8;
            final col = index % 8;
            return _buildSquare(row, col);
          },
        ),
      ),
    );
  }

  Widget _buildSquare(int row, int col) {
    final isLight = (row + col) % 2 == 0;
    final piece = board[row][col];
    final isSelected = selectedSquare != null &&
        selectedSquare![0] == row &&
        selectedSquare![1] == col;
    final isValidMove = validMoves.any((m) => m[0] == row && m[1] == col);

    Color bgColor = isLight ? const Color(0xFFEEEED2) : const Color(0xFF769656);

    if (isSelected) {
      bgColor = Colors.yellow.shade300;
    } else if (isValidMove) {
      bgColor = isLight
          ? Colors.yellow.shade200.withValues(alpha: 0.8)
          : Colors.yellow.shade700.withValues(alpha: 0.8);
    }

    return GestureDetector(
      onTap: () => _onSquareTap(row, col),
      child: Container(
        color: bgColor,
        child: Stack(
          children: [
            if (isValidMove && piece == null)
              Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
              ),
            if (piece != null)
              Center(
                child: Text(
                  piece.symbol,
                  style: TextStyle(
                    fontSize: 36,
                    color: piece.color == PieceColor.white
                        ? const Color(0xFFFFF8DC) // 크림색으로 변경
                        : Colors.black,
                    shadows: piece.color == PieceColor.white
                        ? const [
                            // 흰색 말에 검은 테두리 효과
                            Shadow(offset: Offset(-1.5, -1.5), color: Colors.black),
                            Shadow(offset: Offset(1.5, -1.5), color: Colors.black),
                            Shadow(offset: Offset(1.5, 1.5), color: Colors.black),
                            Shadow(offset: Offset(-1.5, 1.5), color: Colors.black),
                            Shadow(offset: Offset(0, 2), color: Colors.black, blurRadius: 3),
                          ]
                        : const [
                            Shadow(color: Colors.white, blurRadius: 2),
                          ],
                  ),
                ),
              ),
            if (isValidMove && piece != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.8),
                      width: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLegendByMode() {
    switch (widget.gameMode) {
      case ChessGameMode.vsComputerWhite:
        return [
          _buildLegend(Colors.white, '당신 (백)'),
          const SizedBox(width: 32),
          _buildLegend(Colors.black, '컴퓨터 (흑)'),
        ];
      case ChessGameMode.vsComputerBlack:
        return [
          _buildLegend(Colors.white, '컴퓨터 (백)'),
          const SizedBox(width: 32),
          _buildLegend(Colors.black, '당신 (흑)'),
        ];
      case ChessGameMode.vsPerson:
        return [
          _buildLegend(Colors.white, '플레이어 1 (백)'),
          const SizedBox(width: 32),
          _buildLegend(Colors.black, '플레이어 2 (흑)'),
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
