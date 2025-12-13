import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('chess_board');
  }

  static Future<ChessGameMode?> getSavedGameMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt('chess_gameMode');
    if (modeIndex == null) return null;
    return ChessGameMode.values[modeIndex];
  }

  static Future<void> clearSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chess_board');
    await prefs.remove('chess_isWhiteTurn');
    await prefs.remove('chess_gameMode');
    await prefs.remove('chess_enPassant');
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

    final prefs = await SharedPreferences.getInstance();
    final boardData = board.map((row) => row.map((p) => p?.toJson()).toList()).toList();
    await prefs.setString('chess_board', jsonEncode(boardData));
    await prefs.setBool('chess_isWhiteTurn', isWhiteTurn);
    await prefs.setInt('chess_gameMode', widget.gameMode.index);
    if (enPassantTarget != null) {
      await prefs.setString('chess_enPassant', jsonEncode(enPassantTarget));
    } else {
      await prefs.remove('chess_enPassant');
    }
  }

  Future<void> _loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    final boardJson = prefs.getString('chess_board');

    if (boardJson == null) {
      _initBoard();
      return;
    }

    final boardData = jsonDecode(boardJson) as List;
    board = boardData.map<List<ChessPiece?>>((row) {
      return (row as List).map<ChessPiece?>((p) {
        if (p == null) return null;
        return ChessPiece.fromJson(p as Map<String, dynamic>);
      }).toList();
    }).toList();

    isWhiteTurn = prefs.getBool('chess_isWhiteTurn') ?? true;
    final epJson = prefs.getString('chess_enPassant');
    enPassantTarget = epJson != null ? List<int>.from(jsonDecode(epJson)) : null;
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

    setState(() {
      // 앙파상 처리
      if (piece.type == PieceType.pawn && enPassantTarget != null &&
          toRow == enPassantTarget![0] && toCol == enPassantTarget![1]) {
        board[fromRow][toCol] = null;
      }

      // 캐슬링 처리
      if (piece.type == PieceType.king && (toCol - fromCol).abs() == 2) {
        if (toCol > fromCol) {
          // 킹사이드 캐슬링
          board[fromRow][5] = board[fromRow][7];
          board[fromRow][7] = null;
          board[fromRow][5]!.hasMoved = true;
        } else {
          // 퀸사이드 캐슬링
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
          board[toRow][toCol] = ChessPiece(
            type: PieceType.queen,
            color: piece.color,
            hasMoved: true,
          );
        }
      }

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
      appBar: AppBar(
        title: const Text(
          '체스',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown.shade700,
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
                        ? Colors.white
                        : Colors.black,
                    shadows: [
                      Shadow(
                        color: piece.color == PieceColor.white
                            ? Colors.black
                            : Colors.white,
                        blurRadius: 2,
                      ),
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
