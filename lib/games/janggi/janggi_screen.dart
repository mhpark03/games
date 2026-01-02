import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/gemini_service.dart';
import '../../services/game_save_service.dart';
import '../../services/ad_service.dart';

enum JanggiPieceType { gung, cha, po, ma, sang, sa, byung }

enum JanggiColor { cho, han }

// 마상 배치: 좌측(1,2번 위치)과 우측(6,7번 위치)의 마/상 순서
enum MaSangPosition {
  maSang, // 마상 (안쪽 마, 바깥쪽 상)
  sangMa, // 상마 (안쪽 상, 바깥쪽 마)
}

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

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'color': color.index,
  };

  factory JanggiPiece.fromJson(Map<String, dynamic> json) => JanggiPiece(
    JanggiPieceType.values[json['type'] as int],
    JanggiColor.values[json['color'] as int],
  );
}

// 이동 기록 (취소 기능용)
class MoveRecord {
  final int fromRow;
  final int fromCol;
  final int toRow;
  final int toCol;
  final JanggiPiece? capturedPiece;
  final bool wasInCheck;
  final int previousCheckCount;

  MoveRecord({
    required this.fromRow,
    required this.fromCol,
    required this.toRow,
    required this.toCol,
    this.capturedPiece,
    required this.wasInCheck,
    required this.previousCheckCount,
  });

  Map<String, dynamic> toJson() => {
    'fromRow': fromRow,
    'fromCol': fromCol,
    'toRow': toRow,
    'toCol': toCol,
    'capturedPiece': capturedPiece?.toJson(),
    'wasInCheck': wasInCheck,
    'previousCheckCount': previousCheckCount,
  };

  factory MoveRecord.fromJson(Map<String, dynamic> json) => MoveRecord(
    fromRow: json['fromRow'] as int,
    fromCol: json['fromCol'] as int,
    toRow: json['toRow'] as int,
    toCol: json['toCol'] as int,
    capturedPiece: json['capturedPiece'] != null
        ? JanggiPiece.fromJson(json['capturedPiece'] as Map<String, dynamic>)
        : null,
    wasInCheck: json['wasInCheck'] as bool? ?? false,
    previousCheckCount: json['previousCheckCount'] as int? ?? 0,
  );
}

enum JanggiGameMode { vsCho, vsHan, vsHuman }

// AI 난이도 설정
enum JanggiDifficulty {
  easy,   // 쉬움: 탐색 깊이 1, 랜덤 수 확률 30%
  normal, // 보통: 탐색 깊이 2, 랜덤 수 확률 15%
  hard,   // 어려움: 탐색 깊이 3, 랜덤 수 확률 0%
}

class JanggiScreen extends StatefulWidget {
  final JanggiGameMode gameMode;
  final bool resumeGame;
  final JanggiDifficulty difficulty;

  const JanggiScreen({
    super.key,
    required this.gameMode,
    this.resumeGame = false,
    this.difficulty = JanggiDifficulty.normal,
  });

  static Future<bool> hasSavedGame() async {
    return await GameSaveService.hasSavedGame('janggi');
  }

  static Future<JanggiGameMode?> getSavedGameMode() async {
    final gameState = await GameSaveService.loadGame('janggi');
    if (gameState == null) return null;
    final modeIndex = gameState['gameMode'] as int?;
    if (modeIndex == null) return null;
    return JanggiGameMode.values[modeIndex];
  }

  static Future<JanggiDifficulty?> getSavedDifficulty() async {
    final gameState = await GameSaveService.loadGame('janggi');
    if (gameState == null) return null;
    final difficultyIndex = gameState['difficulty'] as int?;
    if (difficultyIndex == null) return null;
    return JanggiDifficulty.values[difficultyIndex];
  }

  static Future<void> clearSavedGame() async {
    await GameSaveService.clearSave();
  }

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
  bool isInCheck = false; // 현재 턴 플레이어가 장군 상태인지

  // 마지막 이동 위치 표시
  int? lastMoveFromRow;
  int? lastMoveFromCol;
  int? lastMoveToRow;
  int? lastMoveToCol;

  // 보드 상태 히스토리 (반복 검출용)
  List<String> _boardHistory = [];
  int _consecutiveCheckCount = 0; // 연속 장군 횟수

  // 이동 기록 (취소 기능용)
  List<MoveRecord> _moveHistory = [];

  // AI 난이도 설정
  JanggiDifficulty _difficulty = JanggiDifficulty.normal;

  // Gemini AI 설정
  String? geminiApiKey;
  GeminiService? geminiService;
  bool useGeminiAI = true;

  // 마상 배치 설정
  bool isSetupPhase = true;
  MaSangPosition choLeftPosition = MaSangPosition.maSang;
  MaSangPosition choRightPosition = MaSangPosition.maSang;
  MaSangPosition hanLeftPosition = MaSangPosition.maSang;
  MaSangPosition hanRightPosition = MaSangPosition.maSang;

  @override
  void initState() {
    super.initState();
    board = List.generate(10, (_) => List.filled(9, null));
    _loadGeminiApiKey();

    if (widget.resumeGame) {
      // 저장된 게임 불러오기
      _loadGame();
    } else {
      // 게임 시작 시 마상 배치 선택 다이얼로그 표시
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSetupDialog();
      });
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // 빌드 시 주입된 API 키 (--dart-define=GEMINI_API_KEY=xxx)
  static const String _buildTimeApiKey = String.fromEnvironment('GEMINI_API_KEY');

  Future<void> _loadGeminiApiKey() async {
    // 1. 빌드 시 주입된 API 키 우선 사용
    if (_buildTimeApiKey.isNotEmpty) {
      setState(() {
        geminiApiKey = _buildTimeApiKey;
        geminiService = GeminiService(_buildTimeApiKey);
      });
      return;
    }

    // 2. SharedPreferences에서 저장된 키 사용
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('gemini_api_key');
    if (apiKey != null && apiKey.isNotEmpty) {
      setState(() {
        geminiApiKey = apiKey;
        geminiService = GeminiService(apiKey);
      });
    }
  }

  Future<void> _saveGeminiApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', apiKey);
    setState(() {
      geminiApiKey = apiKey;
      geminiService = apiKey.isNotEmpty ? GeminiService(apiKey) : null;
    });
  }

  Future<void> _saveGame() async {
    if (isGameOver || isSetupPhase) {
      await JanggiScreen.clearSavedGame();
      return;
    }

    final boardData = board.map((row) => row.map((p) => p?.toJson()).toList()).toList();

    final gameState = {
      'board': boardData,
      'currentTurn': currentTurn.index,
      'gameMode': widget.gameMode.index,
      'isInCheck': isInCheck,
      'choLeftPosition': choLeftPosition.index,
      'choRightPosition': choRightPosition.index,
      'hanLeftPosition': hanLeftPosition.index,
      'hanRightPosition': hanRightPosition.index,
      'lastMoveFromRow': lastMoveFromRow,
      'lastMoveFromCol': lastMoveFromCol,
      'lastMoveToRow': lastMoveToRow,
      'lastMoveToCol': lastMoveToCol,
      'boardHistory': _boardHistory,
      'consecutiveCheckCount': _consecutiveCheckCount,
      'difficulty': _difficulty.index,
      'moveHistory': _moveHistory.map((m) => m.toJson()).toList(),
    };

    await GameSaveService.saveGame('janggi', gameState);
  }

  Future<void> _loadGame() async {
    final gameState = await GameSaveService.loadGame('janggi');

    if (gameState == null) {
      // 저장된 게임이 없으면 새 게임 시작
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSetupDialog();
      });
      return;
    }

    final boardData = gameState['board'] as List;
    board = boardData.map<List<JanggiPiece?>>((row) {
      return (row as List).map<JanggiPiece?>((p) {
        if (p == null) return null;
        return JanggiPiece.fromJson(p as Map<String, dynamic>);
      }).toList();
    }).toList();

    currentTurn = JanggiColor.values[gameState['currentTurn'] as int? ?? 0];
    isInCheck = gameState['isInCheck'] as bool? ?? false;
    choLeftPosition = MaSangPosition.values[gameState['choLeftPosition'] as int? ?? 0];
    choRightPosition = MaSangPosition.values[gameState['choRightPosition'] as int? ?? 0];
    hanLeftPosition = MaSangPosition.values[gameState['hanLeftPosition'] as int? ?? 0];
    hanRightPosition = MaSangPosition.values[gameState['hanRightPosition'] as int? ?? 0];
    lastMoveFromRow = gameState['lastMoveFromRow'] as int?;
    lastMoveFromCol = gameState['lastMoveFromCol'] as int?;
    lastMoveToRow = gameState['lastMoveToRow'] as int?;
    lastMoveToCol = gameState['lastMoveToCol'] as int?;

    // 보드 히스토리 복원
    final savedHistory = gameState['boardHistory'];
    if (savedHistory != null && savedHistory is List) {
      _boardHistory = savedHistory.map((e) => e.toString()).toList();
    } else {
      _boardHistory = [];
    }
    _consecutiveCheckCount = gameState['consecutiveCheckCount'] as int? ?? 0;

    // 난이도 복원
    final savedDifficulty = gameState['difficulty'] as int?;
    if (savedDifficulty != null && savedDifficulty < JanggiDifficulty.values.length) {
      _difficulty = JanggiDifficulty.values[savedDifficulty];
    } else {
      _difficulty = JanggiDifficulty.normal;
    }

    // 이동 기록 복원
    final savedMoveHistory = gameState['moveHistory'];
    if (savedMoveHistory != null && savedMoveHistory is List) {
      _moveHistory = savedMoveHistory
          .map((m) => MoveRecord.fromJson(m as Map<String, dynamic>))
          .toList();
    } else {
      _moveHistory = [];
    }

    setState(() {
      isSetupPhase = false;
      isGameOver = false;
      selectedRow = null;
      selectedCol = null;
      validMoves = null;
      winner = null;
      isThinking = false;
    });

    // 컴퓨터 턴이면 자동으로 수 두기
    if (widget.gameMode != JanggiGameMode.vsHuman) {
      if ((widget.gameMode == JanggiGameMode.vsCho && currentTurn == JanggiColor.cho) ||
          (widget.gameMode == JanggiGameMode.vsHan && currentTurn == JanggiColor.han)) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _makeComputerMove();
        });
      }
    }
  }

  void _showAISettingsDialog() {
    final controller = TextEditingController(text: geminiApiKey ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF5DEB3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF8B4513), width: 3),
              ),
              title: const Row(
                children: [
                  Icon(Icons.smart_toy, color: Color(0xFF8B4513)),
                  SizedBox(width: 8),
                  Text(
                    'Gemini AI 설정',
                    style: TextStyle(
                      color: Color(0xFF8B4513),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gemini API 키를 입력하면 더 똑똑한 AI와 대국할 수 있습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'API 키는 Google AI Studio에서 무료로 발급받을 수 있습니다:\nhttps://aistudio.google.com/apikey',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        labelText: 'Gemini API Key',
                        hintText: 'AIza...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Gemini AI 사용'),
                        const Spacer(),
                        Switch(
                          value: useGeminiAI,
                          onChanged: (value) {
                            setDialogState(() {
                              useGeminiAI = value;
                            });
                            setState(() {});
                          },
                          activeColor: const Color(0xFF8B4513),
                        ),
                      ],
                    ),
                    if (geminiService != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'API 키가 설정됨',
                              style: TextStyle(color: Colors.green, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '취소',
                    style: TextStyle(color: Color(0xFF8B4513)),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B4513),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    _saveGeminiApiKey(controller.text.trim());
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          controller.text.trim().isNotEmpty
                              ? 'Gemini AI가 활성화되었습니다'
                              : 'API 키가 제거되었습니다',
                        ),
                        backgroundColor: const Color(0xFF8B4513),
                      ),
                    );
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _startGame() {
    setState(() {
      isSetupPhase = false;
      _initBoard();
    });

    // 컴퓨터가 초(선공)인 경우 첫 수 두기
    if (widget.gameMode == JanggiGameMode.vsCho) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _makeComputerMove();
      });
    }
  }

  void _showSetupDialog() {
    // 컴퓨터 대전 시 난이도 설정 (선택된 난이도 적용)
    if (widget.gameMode != JanggiGameMode.vsHuman) {
      _difficulty = widget.difficulty;
    }

    // 컴퓨터의 마상 배치는 랜덤으로 설정 (4가지 조합 중 하나)
    final random = Random();
    if (widget.gameMode == JanggiGameMode.vsCho) {
      // 컴퓨터가 초일 때, 초의 배치는 랜덤
      choLeftPosition = random.nextBool() ? MaSangPosition.maSang : MaSangPosition.sangMa;
      choRightPosition = random.nextBool() ? MaSangPosition.maSang : MaSangPosition.sangMa;
    } else if (widget.gameMode == JanggiGameMode.vsHan) {
      // 컴퓨터가 한일 때, 한의 배치는 랜덤
      hanLeftPosition = random.nextBool() ? MaSangPosition.maSang : MaSangPosition.sangMa;
      hanRightPosition = random.nextBool() ? MaSangPosition.maSang : MaSangPosition.sangMa;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return OrientationBuilder(
              builder: (context, orientation) {
                if (orientation == Orientation.landscape) {
                  return _buildLandscapeSetupDialog(setDialogState);
                } else {
                  return _buildPortraitSetupDialog(setDialogState);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPortraitSetupDialog(StateSetter setDialogState) {
    return AlertDialog(
      backgroundColor: const Color(0xFFF5DEB3),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF8B4513), width: 3),
      ),
      title: const Text(
        '마상 배치 선택',
        style: TextStyle(
          color: Color(0xFF8B4513),
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 컴퓨터가 초일 때 (vsCho 모드) - 컴퓨터 초 배치 표시
            if (widget.gameMode == JanggiGameMode.vsCho) ...[
              _buildComputerPositionDisplay(
                '초 (컴퓨터)',
                JanggiColor.cho,
                choLeftPosition,
                choRightPosition,
              ),
              const SizedBox(height: 16),
            ],
            // 플레이어 초의 배치 (한과 대전 또는 2인 플레이)
            if (widget.gameMode == JanggiGameMode.vsHan ||
                widget.gameMode == JanggiGameMode.vsHuman) ...[
              _buildPositionSelector(
                widget.gameMode == JanggiGameMode.vsHuman ? '초' : '초 (플레이어)',
                JanggiColor.cho,
                choLeftPosition,
                choRightPosition,
                (left, right) {
                  setDialogState(() {
                    choLeftPosition = left;
                    choRightPosition = right;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],
            // 플레이어 한의 배치 (초와 대전 또는 2인 플레이)
            if (widget.gameMode == JanggiGameMode.vsCho ||
                widget.gameMode == JanggiGameMode.vsHuman) ...[
              _buildPositionSelector(
                widget.gameMode == JanggiGameMode.vsHuman ? '한' : '한 (플레이어)',
                JanggiColor.han,
                hanLeftPosition,
                hanRightPosition,
                (left, right) {
                  setDialogState(() {
                    hanLeftPosition = left;
                    hanRightPosition = right;
                  });
                },
              ),
            ],
            // 컴퓨터가 한일 때 (vsHan 모드) - 컴퓨터 한 배치 표시
            if (widget.gameMode == JanggiGameMode.vsHan) ...[
              const SizedBox(height: 16),
              _buildComputerPositionDisplay(
                '한 (컴퓨터)',
                JanggiColor.han,
                hanLeftPosition,
                hanRightPosition,
              ),
            ],
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B4513),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                // 메인 상태 업데이트
              });
              _startGame();
            },
            child: const Text(
              '게임 시작',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeSetupDialog(StateSetter setDialogState) {
    return Dialog(
      backgroundColor: const Color(0xFFF5DEB3),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF8B4513), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '마상 배치 선택',
              style: TextStyle(
                fontSize: 20,
                color: Color(0xFF8B4513),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 왼쪽: 초
                  if (widget.gameMode == JanggiGameMode.vsCho)
                    // 컴퓨터가 초
                    Expanded(
                      child: _buildComputerPositionDisplay(
                        '초 (컴퓨터)',
                        JanggiColor.cho,
                        choLeftPosition,
                        choRightPosition,
                      ),
                    ),
                  if (widget.gameMode == JanggiGameMode.vsHan ||
                      widget.gameMode == JanggiGameMode.vsHuman)
                    // 플레이어가 초
                    Expanded(
                      child: _buildPositionSelector(
                        widget.gameMode == JanggiGameMode.vsHuman ? '초' : '초 (플레이어)',
                        JanggiColor.cho,
                        choLeftPosition,
                        choRightPosition,
                        (left, right) {
                          setDialogState(() {
                            choLeftPosition = left;
                            choRightPosition = right;
                          });
                        },
                      ),
                    ),
                  const SizedBox(width: 16),
                  // 오른쪽: 한
                  if (widget.gameMode == JanggiGameMode.vsCho ||
                      widget.gameMode == JanggiGameMode.vsHuman)
                    // 플레이어가 한
                    Expanded(
                      child: _buildPositionSelector(
                        widget.gameMode == JanggiGameMode.vsHuman ? '한' : '한 (플레이어)',
                        JanggiColor.han,
                        hanLeftPosition,
                        hanRightPosition,
                        (left, right) {
                          setDialogState(() {
                            hanLeftPosition = left;
                            hanRightPosition = right;
                          });
                        },
                      ),
                    ),
                  if (widget.gameMode == JanggiGameMode.vsHan)
                    // 컴퓨터가 한
                    Expanded(
                      child: _buildComputerPositionDisplay(
                        '한 (컴퓨터)',
                        JanggiColor.han,
                        hanLeftPosition,
                        hanRightPosition,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    // 메인 상태 업데이트
                  });
                  _startGame();
                },
                child: const Text(
                  '게임 시작',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionSelector(
    String title,
    JanggiColor color,
    MaSangPosition leftPos,
    MaSangPosition rightPos,
    Function(MaSangPosition, MaSangPosition) onChanged,
  ) {
    final pieceColor = color == JanggiColor.cho
        ? const Color(0xFF006400)
        : const Color(0xFFB22222);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pieceColor.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pieceColor.withAlpha(128)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: pieceColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSideSelector(
                  '좌측',
                  leftPos,
                  pieceColor,
                  (pos) => onChanged(pos, rightPos),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSideSelector(
                  '우측',
                  rightPos,
                  pieceColor,
                  (pos) => onChanged(leftPos, pos),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '배치: ${_getPositionName(leftPos, rightPos)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideSelector(
    String label,
    MaSangPosition position,
    Color color,
    Function(MaSangPosition) onChanged,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPositionButton(
              '마상',
              MaSangPosition.maSang,
              position,
              color,
              onChanged,
            ),
            const SizedBox(width: 4),
            _buildPositionButton(
              '상마',
              MaSangPosition.sangMa,
              position,
              color,
              onChanged,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPositionButton(
    String label,
    MaSangPosition buttonPos,
    MaSangPosition currentPos,
    Color color,
    Function(MaSangPosition) onChanged,
  ) {
    final isSelected = buttonPos == currentPos;
    return GestureDetector(
      onTap: () => onChanged(buttonPos),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  String _getPositionName(MaSangPosition left, MaSangPosition right) {
    if (left == MaSangPosition.maSang && right == MaSangPosition.maSang) {
      return '내마외상';
    } else if (left == MaSangPosition.sangMa && right == MaSangPosition.sangMa) {
      return '외마내상';
    } else if (left == MaSangPosition.maSang && right == MaSangPosition.sangMa) {
      return '좌내마 우외마';
    } else {
      return '좌외마 우내마';
    }
  }

  // 컴퓨터의 마상 배치 표시 (읽기 전용)
  Widget _buildComputerPositionDisplay(
    String title,
    JanggiColor color,
    MaSangPosition leftPos,
    MaSangPosition rightPos,
  ) {
    final pieceColor = color == JanggiColor.cho
        ? const Color(0xFF006400)
        : const Color(0xFFB22222);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pieceColor.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pieceColor.withAlpha(80)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.computer, size: 16, color: pieceColor.withAlpha(180)),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: pieceColor.withAlpha(180),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPositionLabel('좌측', leftPos, pieceColor),
              const SizedBox(width: 16),
              _buildPositionLabel('우측', rightPos, pieceColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '배치: ${_getPositionName(leftPos, rightPos)}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionLabel(String side, MaSangPosition pos, Color color) {
    final posName = pos == MaSangPosition.maSang ? '마상' : '상마';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Column(
        children: [
          Text(
            side,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          Text(
            posName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }

  void _initBoard() {
    board = List.generate(10, (_) => List.filled(9, null));

    // 한(상단) 배치 - 마상 위치 적용
    board[0][0] = JanggiPiece(JanggiPieceType.cha, JanggiColor.han);
    // 좌측 마상 (1,2번 위치)
    if (hanLeftPosition == MaSangPosition.maSang) {
      board[0][1] = JanggiPiece(JanggiPieceType.ma, JanggiColor.han);
      board[0][2] = JanggiPiece(JanggiPieceType.sang, JanggiColor.han);
    } else {
      board[0][1] = JanggiPiece(JanggiPieceType.sang, JanggiColor.han);
      board[0][2] = JanggiPiece(JanggiPieceType.ma, JanggiColor.han);
    }
    board[0][3] = JanggiPiece(JanggiPieceType.sa, JanggiColor.han);
    board[0][5] = JanggiPiece(JanggiPieceType.sa, JanggiColor.han);
    // 우측 마상 (6,7번 위치)
    if (hanRightPosition == MaSangPosition.maSang) {
      board[0][6] = JanggiPiece(JanggiPieceType.sang, JanggiColor.han);
      board[0][7] = JanggiPiece(JanggiPieceType.ma, JanggiColor.han);
    } else {
      board[0][6] = JanggiPiece(JanggiPieceType.ma, JanggiColor.han);
      board[0][7] = JanggiPiece(JanggiPieceType.sang, JanggiColor.han);
    }
    board[0][8] = JanggiPiece(JanggiPieceType.cha, JanggiColor.han);
    board[1][4] = JanggiPiece(JanggiPieceType.gung, JanggiColor.han);
    board[2][1] = JanggiPiece(JanggiPieceType.po, JanggiColor.han);
    board[2][7] = JanggiPiece(JanggiPieceType.po, JanggiColor.han);
    board[3][0] = JanggiPiece(JanggiPieceType.byung, JanggiColor.han);
    board[3][2] = JanggiPiece(JanggiPieceType.byung, JanggiColor.han);
    board[3][4] = JanggiPiece(JanggiPieceType.byung, JanggiColor.han);
    board[3][6] = JanggiPiece(JanggiPieceType.byung, JanggiColor.han);
    board[3][8] = JanggiPiece(JanggiPieceType.byung, JanggiColor.han);

    // 초(하단) 배치 - 마상 위치 적용
    board[9][0] = JanggiPiece(JanggiPieceType.cha, JanggiColor.cho);
    // 좌측 마상 (1,2번 위치)
    if (choLeftPosition == MaSangPosition.maSang) {
      board[9][1] = JanggiPiece(JanggiPieceType.ma, JanggiColor.cho);
      board[9][2] = JanggiPiece(JanggiPieceType.sang, JanggiColor.cho);
    } else {
      board[9][1] = JanggiPiece(JanggiPieceType.sang, JanggiColor.cho);
      board[9][2] = JanggiPiece(JanggiPieceType.ma, JanggiColor.cho);
    }
    board[9][3] = JanggiPiece(JanggiPieceType.sa, JanggiColor.cho);
    board[9][5] = JanggiPiece(JanggiPieceType.sa, JanggiColor.cho);
    // 우측 마상 (6,7번 위치)
    if (choRightPosition == MaSangPosition.maSang) {
      board[9][6] = JanggiPiece(JanggiPieceType.sang, JanggiColor.cho);
      board[9][7] = JanggiPiece(JanggiPieceType.ma, JanggiColor.cho);
    } else {
      board[9][6] = JanggiPiece(JanggiPieceType.ma, JanggiColor.cho);
      board[9][7] = JanggiPiece(JanggiPieceType.sang, JanggiColor.cho);
    }
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

    // 궁성 내 대각선 이동 (포는 기물을 뛰어넘어야 함)
    _addPoPalaceDiagonalMoves(moves, row, col, piece);

    return moves;
  }

  // 포의 궁성 내 대각선 이동 (뛰어넘기 규칙 적용)
  void _addPoPalaceDiagonalMoves(
      List<List<int>> moves, int row, int col, JanggiPiece piece) {
    // 궁성 대각선 경로 정의: [시작, 중간(뛰어넘을 위치), 끝]
    final List<List<List<int>>> diagonalPaths = [
      // 초 궁성 대각선 1: (9,5) - (8,4) - (7,3)
      [[9, 5], [8, 4], [7, 3]],
      // 초 궁성 대각선 2: (9,3) - (8,4) - (7,5)
      [[9, 3], [8, 4], [7, 5]],
      // 한 궁성 대각선 1: (2,5) - (1,4) - (0,3)
      [[2, 5], [1, 4], [0, 3]],
      // 한 궁성 대각선 2: (2,3) - (1,4) - (0,5)
      [[2, 3], [1, 4], [0, 5]],
    ];

    for (var path in diagonalPaths) {
      // 현재 위치가 대각선 경로의 시작 또는 끝에 있는지 확인
      int posIndex = -1;
      if (row == path[0][0] && col == path[0][1]) {
        posIndex = 0;
      } else if (row == path[2][0] && col == path[2][1]) {
        posIndex = 2;
      } else if (row == path[1][0] && col == path[1][1]) {
        // 중앙에서 양쪽 끝으로 이동 가능 (뛰어넘을 기물 없음 - 포는 중앙에서 대각선 이동 불가)
        continue;
      }

      if (posIndex == -1) continue;

      // 뛰어넘을 기물 확인 (중앙 위치)
      final midRow = path[1][0];
      final midCol = path[1][1];
      final midPiece = board[midRow][midCol];

      // 중앙에 기물이 있고, 포가 아니어야 뛰어넘을 수 있음
      if (midPiece != null && midPiece.type != JanggiPieceType.po) {
        // 목표 위치 (반대편 끝)
        final targetIndex = posIndex == 0 ? 2 : 0;
        final targetRow = path[targetIndex][0];
        final targetCol = path[targetIndex][1];
        final targetPiece = board[targetRow][targetCol];

        // 목표 위치가 비어있거나 적 기물(포 제외)이면 이동 가능
        if (targetPiece == null) {
          moves.add([targetRow, targetCol]);
        } else if (targetPiece.color != piece.color &&
            targetPiece.type != JanggiPieceType.po) {
          moves.add([targetRow, targetCol]);
        }
      }
    }
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

  // 궁의 위치 찾기
  List<int>? _findGung(JanggiColor color) {
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = board[r][c];
        if (piece != null &&
            piece.type == JanggiPieceType.gung &&
            piece.color == color) {
          return [r, c];
        }
      }
    }
    return null;
  }

  // 특정 색이 장군 상태인지 확인
  bool _checkIsInCheck(JanggiColor color) {
    final gungPos = _findGung(color);
    if (gungPos == null) return false;

    final enemyColor =
        color == JanggiColor.cho ? JanggiColor.han : JanggiColor.cho;

    // 모든 상대 말이 궁을 공격할 수 있는지 확인
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = board[r][c];
        if (piece != null && piece.color == enemyColor) {
          final moves = _getValidMoves(r, c);
          if (moves.any((m) => m[0] == gungPos[0] && m[1] == gungPos[1])) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // 이동 후 자신의 궁이 장군 상태가 되는지 확인
  bool _wouldBeInCheckAfterMove(
      int fromRow, int fromCol, int toRow, int toCol, JanggiColor color) {
    // 임시로 이동 실행
    final movingPiece = board[fromRow][fromCol];
    final capturedPiece = board[toRow][toCol];

    board[toRow][toCol] = movingPiece;
    board[fromRow][fromCol] = null;

    // 장군 상태 확인
    final wouldBeInCheck = _checkIsInCheck(color);

    // 원복
    board[fromRow][fromCol] = movingPiece;
    board[toRow][toCol] = capturedPiece;

    return wouldBeInCheck;
  }

  // 합법적인 수만 필터링 (장군 회피 필수)
  List<List<int>> _getLegalMoves(int row, int col) {
    final piece = board[row][col];
    if (piece == null) return [];

    final basicMoves = _getValidMoves(row, col);
    final legalMoves = <List<int>>[];

    for (var move in basicMoves) {
      if (!_wouldBeInCheckAfterMove(row, col, move[0], move[1], piece.color)) {
        legalMoves.add(move);
      }
    }

    return legalMoves;
  }

  // 외통수(체크메이트) 확인
  bool _isCheckmate(JanggiColor color) {
    if (!_checkIsInCheck(color)) return false;

    // 모든 아군 말의 합법적인 수가 있는지 확인
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = board[r][c];
        if (piece != null && piece.color == color) {
          final legalMoves = _getLegalMoves(r, c);
          if (legalMoves.isNotEmpty) {
            return false;
          }
        }
      }
    }
    return true;
  }

  void _onTap(int row, int col) {
    if (isSetupPhase || isGameOver || isThinking) return;

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
          validMoves = _getLegalMoves(row, col); // 합법적인 수만 표시
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
          validMoves = _getLegalMoves(row, col); // 합법적인 수만 표시
        }
      }
    });
  }

  void _movePiece(int fromRow, int fromCol, int toRow, int toCol) {
    final capturedPiece = board[toRow][toCol];

    // 이동 기록 저장 (취소 기능용)
    _moveHistory.add(MoveRecord(
      fromRow: fromRow,
      fromCol: fromCol,
      toRow: toRow,
      toCol: toCol,
      capturedPiece: capturedPiece,
      wasInCheck: isInCheck,
      previousCheckCount: _consecutiveCheckCount,
    ));

    board[toRow][toCol] = board[fromRow][fromCol];
    board[fromRow][fromCol] = null;

    // 마지막 이동 위치 저장
    lastMoveFromRow = fromRow;
    lastMoveFromCol = fromCol;
    lastMoveToRow = toRow;
    lastMoveToCol = toCol;

    // 궁 잡힘 체크
    if (capturedPiece?.type == JanggiPieceType.gung) {
      isGameOver = true;
      winner = currentTurn == JanggiColor.cho ? '초' : '한';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGameOverDialog();
      });
      return;
    }

    currentTurn =
        currentTurn == JanggiColor.cho ? JanggiColor.han : JanggiColor.cho;

    // 장군 상태 업데이트
    isInCheck = _checkIsInCheck(currentTurn);

    // 보드 상태 히스토리 저장 및 연속 장군 카운트
    _boardHistory.add(_getBoardStateString());
    if (isInCheck) {
      _consecutiveCheckCount++;
    } else {
      _consecutiveCheckCount = 0;
    }

    // 외통수(체크메이트) 확인
    if (!isGameOver && _isCheckmate(currentTurn)) {
      isGameOver = true;
      winner = currentTurn == JanggiColor.cho ? '한' : '초';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGameOverDialog();
      });
      return;
    }

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

    // 게임 저장
    _saveGame();
  }

  // 취소 광고 다이얼로그
  void _showUndoAdDialog() {
    if (_moveHistory.isEmpty || isGameOver || isThinking) return;

    // vs 컴퓨터 모드에서는 플레이어 턴일 때만 취소 가능
    if (widget.gameMode != JanggiGameMode.vsHuman) {
      final playerColor = widget.gameMode == JanggiGameMode.vsCho
          ? JanggiColor.han
          : JanggiColor.cho;
      if (currentTurn != playerColor) return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5DEB3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF8B4513), width: 3),
        ),
        title: const Row(
          children: [
            Icon(Icons.undo, color: Color(0xFF8B4513), size: 28),
            SizedBox(width: 8),
            Text('한 수 취소', style: TextStyle(color: Color(0xFF8B4513))),
          ],
        ),
        content: const Text(
          '광고를 시청하고 마지막 수를 취소하시겠습니까?',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Color(0xFF8B4513))),
          ),
          ElevatedButton.icon(
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
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('광고 보고 취소'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B4513),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _undoMove() {
    if (_moveHistory.isEmpty) return;

    setState(() {
      // vs 컴퓨터 모드에서는 컴퓨터의 수도 함께 취소 (2수 취소)
      int undoCount = 1;
      if (widget.gameMode != JanggiGameMode.vsHuman && _moveHistory.length >= 2) {
        undoCount = 2;
      }

      for (int i = 0; i < undoCount && _moveHistory.isNotEmpty; i++) {
        final lastMove = _moveHistory.removeLast();

        // 말 되돌리기
        board[lastMove.fromRow][lastMove.fromCol] = board[lastMove.toRow][lastMove.toCol];
        board[lastMove.toRow][lastMove.toCol] = lastMove.capturedPiece;

        // 턴 되돌리기
        currentTurn = currentTurn == JanggiColor.cho ? JanggiColor.han : JanggiColor.cho;

        // 장군 상태 복원
        isInCheck = lastMove.wasInCheck;
        _consecutiveCheckCount = lastMove.previousCheckCount;

        // 보드 히스토리에서 마지막 항목 제거
        if (_boardHistory.isNotEmpty) {
          _boardHistory.removeLast();
        }
      }

      // 마지막 이동 표시 업데이트
      if (_moveHistory.isNotEmpty) {
        final prevMove = _moveHistory.last;
        lastMoveFromRow = prevMove.fromRow;
        lastMoveFromCol = prevMove.fromCol;
        lastMoveToRow = prevMove.toRow;
        lastMoveToCol = prevMove.toCol;
      } else {
        lastMoveFromRow = null;
        lastMoveFromCol = null;
        lastMoveToRow = null;
        lastMoveToCol = null;
      }

      // 선택 초기화
      selectedRow = null;
      selectedCol = null;
      validMoves = null;
    });

    _saveGame();
    HapticFeedback.mediumImpact();
  }

  void _makeComputerMove() async {
    if (isGameOver) return;

    setState(() {
      isThinking = true;
    });

    JanggiColor computerColor =
        widget.gameMode == JanggiGameMode.vsCho
            ? JanggiColor.cho
            : JanggiColor.han;

    // 별도 isolate에서 계산하지 않으므로 UI 블로킹 방지를 위해 약간의 지연
    await Future.delayed(const Duration(milliseconds: 100));

    Map<String, dynamic>? bestMove;

    // Gemini AI 사용 시도
    if (useGeminiAI && geminiService != null) {
      try {
        // Gemini용 합법적인 수 수집
        List<Map<String, dynamic>> allMoves = [];
        for (int r = 0; r < 10; r++) {
          for (int c = 0; c < 9; c++) {
            final piece = board[r][c];
            if (piece != null && piece.color == computerColor) {
              final moves = _getLegalMoves(r, c);
              for (var move in moves) {
                int score = _evaluateMove(r, c, move[0], move[1], piece, computerColor);
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

        if (allMoves.isNotEmpty) {
          final geminiMove = await geminiService!.getBestMove(
            board: board,
            currentPlayer: computerColor == JanggiColor.cho ? 'cho' : 'han',
            legalMoves: allMoves,
          );

          if (geminiMove != null) {
            bestMove = geminiMove;
          }
        }
      } catch (e) {
        // Gemini 실패 시 로컬 AI 사용
      }
    }

    // Gemini가 실패하거나 비활성화된 경우 Minimax AI 사용
    if (bestMove == null) {
      bestMove = _findBestMove(computerColor);
    }

    if (!mounted) return;

    if (bestMove == null) {
      // 합법적인 수가 없음 (패배)
      setState(() {
        isThinking = false;
        isGameOver = true;
        winner = computerColor == JanggiColor.cho ? '한' : '초';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGameOverDialog();
      });
      return;
    }

    setState(() {
      isThinking = false;
      _movePiece(
          bestMove!['fromRow'], bestMove['fromCol'], bestMove['toRow'], bestMove['toCol']);
    });
  }

  // 난이도별 AI 탐색 깊이
  int get _aiSearchDepth {
    switch (_difficulty) {
      case JanggiDifficulty.easy:
        return 1;
      case JanggiDifficulty.normal:
        return 2;
      case JanggiDifficulty.hard:
        return 3;
    }
  }

  // 난이도별 랜덤 수 확률 (0.0 ~ 1.0)
  double get _randomMoveChance {
    switch (_difficulty) {
      case JanggiDifficulty.easy:
        return 0.30; // 30% 확률로 랜덤 수
      case JanggiDifficulty.normal:
        return 0.15; // 15% 확률로 랜덤 수
      case JanggiDifficulty.hard:
        return 0.0; // 항상 최선의 수
    }
  }

  // 난이도 이름 반환
  String get _difficultyName {
    switch (_difficulty) {
      case JanggiDifficulty.easy:
        return '쉬움';
      case JanggiDifficulty.normal:
        return '보통';
      case JanggiDifficulty.hard:
        return '어려움';
    }
  }

  // 랜덤 난이도 설정 (쉬움 50%, 보통 35%, 어려움 15%)
  void _randomizeDifficulty() {
    final rand = Random().nextDouble();
    if (rand < 0.50) {
      _difficulty = JanggiDifficulty.easy;
    } else if (rand < 0.85) {
      _difficulty = JanggiDifficulty.normal;
    } else {
      _difficulty = JanggiDifficulty.hard;
    }
  }

  // 기물 가치 (정적 평가용)
  int _getPieceValue(JanggiPieceType type) {
    switch (type) {
      case JanggiPieceType.gung:
        return 0; // 궁은 잡히면 게임 종료이므로 별도 처리
      case JanggiPieceType.cha:
        return 1300;
      case JanggiPieceType.po:
        return 700;
      case JanggiPieceType.ma:
        return 500;
      case JanggiPieceType.sang:
        return 500;
      case JanggiPieceType.sa:
        return 200;
      case JanggiPieceType.byung:
        return 200;
    }
  }

  // 위치 가치 테이블 (초 기준, 한은 반전)
  static const List<List<int>> _byungPositionValue = [
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [5, 10, 15, 20, 25, 20, 15, 10, 5],
    [10, 15, 20, 30, 35, 30, 20, 15, 10],
    [15, 20, 30, 40, 50, 40, 30, 20, 15],
    [25, 35, 45, 55, 65, 55, 45, 35, 25],
    [35, 50, 60, 70, 80, 70, 60, 50, 35],
    [50, 70, 80, 90, 100, 90, 80, 70, 50],
    [70, 90, 100, 110, 120, 110, 100, 90, 70],
  ];

  static const List<List<int>> _chaPositionValue = [
    [10, 10, 10, 15, 15, 15, 10, 10, 10],
    [10, 15, 15, 20, 25, 20, 15, 15, 10],
    [10, 15, 20, 25, 30, 25, 20, 15, 10],
    [15, 20, 25, 30, 35, 30, 25, 20, 15],
    [20, 25, 30, 35, 40, 35, 30, 25, 20],
    [20, 25, 30, 35, 40, 35, 30, 25, 20],
    [15, 20, 25, 30, 35, 30, 25, 20, 15],
    [10, 15, 20, 25, 30, 25, 20, 15, 10],
    [10, 15, 15, 20, 25, 20, 15, 15, 10],
    [10, 10, 10, 15, 15, 15, 10, 10, 10],
  ];

  static const List<List<int>> _poPositionValue = [
    [5, 5, 5, 10, 15, 10, 5, 5, 5],
    [5, 10, 15, 20, 25, 20, 15, 10, 5],
    [10, 15, 20, 25, 30, 25, 20, 15, 10],
    [15, 20, 25, 30, 35, 30, 25, 20, 15],
    [20, 25, 30, 40, 45, 40, 30, 25, 20],
    [20, 25, 30, 40, 45, 40, 30, 25, 20],
    [15, 20, 25, 30, 35, 30, 25, 20, 15],
    [10, 15, 20, 25, 30, 25, 20, 15, 10],
    [5, 10, 15, 20, 25, 20, 15, 10, 5],
    [5, 5, 5, 10, 15, 10, 5, 5, 5],
  ];

  static const List<List<int>> _maSangPositionValue = [
    [0, 5, 10, 10, 10, 10, 10, 5, 0],
    [5, 10, 15, 20, 20, 20, 15, 10, 5],
    [10, 15, 25, 30, 30, 30, 25, 15, 10],
    [10, 20, 30, 35, 40, 35, 30, 20, 10],
    [15, 25, 35, 45, 50, 45, 35, 25, 15],
    [15, 25, 35, 45, 50, 45, 35, 25, 15],
    [10, 20, 30, 35, 40, 35, 30, 20, 10],
    [10, 15, 25, 30, 30, 30, 25, 15, 10],
    [5, 10, 15, 20, 20, 20, 15, 10, 5],
    [0, 5, 10, 10, 10, 10, 10, 5, 0],
  ];

  // 위치 가치 가져오기
  int _getPositionValue(JanggiPiece piece, int row, int col) {
    int r = piece.color == JanggiColor.cho ? row : 9 - row;

    switch (piece.type) {
      case JanggiPieceType.byung:
        return _byungPositionValue[r][col];
      case JanggiPieceType.cha:
        return _chaPositionValue[r][col];
      case JanggiPieceType.po:
        return _poPositionValue[r][col];
      case JanggiPieceType.ma:
      case JanggiPieceType.sang:
        return _maSangPositionValue[r][col];
      case JanggiPieceType.gung:
      case JanggiPieceType.sa:
        // 궁과 사는 궁성에 있을 때 보너스
        if (_isInPalace(row, col, piece.color)) {
          return col == 4 ? 20 : 10; // 중앙 선호
        }
        return 0;
    }
  }

  // 기물이 위협받는지 확인
  bool _isPieceUnderAttack(int row, int col, JanggiColor pieceColor) {
    final enemyColor = pieceColor == JanggiColor.cho ? JanggiColor.han : JanggiColor.cho;

    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = board[r][c];
        if (piece != null && piece.color == enemyColor) {
          final moves = _getValidMoves(r, c);
          if (moves.any((m) => m[0] == row && m[1] == col)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  // 기물이 보호받는지 확인
  bool _isPieceProtected(int row, int col, JanggiColor pieceColor) {
    // 임시로 기물을 제거하고 아군이 그 위치를 공격할 수 있는지 확인
    final piece = board[row][col];
    board[row][col] = null;

    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final allyPiece = board[r][c];
        if (allyPiece != null && allyPiece.color == pieceColor) {
          final moves = _getValidMoves(r, c);
          if (moves.any((m) => m[0] == row && m[1] == col)) {
            board[row][col] = piece;
            return true;
          }
        }
      }
    }

    board[row][col] = piece;
    return false;
  }

  // 이동성(mobility) 계산
  int _getMobility(JanggiColor color) {
    int mobility = 0;
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = board[r][c];
        if (piece != null && piece.color == color) {
          mobility += _getLegalMoves(r, c).length;
        }
      }
    }
    return mobility;
  }

  // 궁성 안전도 평가
  int _evaluateKingSafety(JanggiColor color) {
    final gungPos = _findGung(color);
    if (gungPos == null) return -10000;

    int safety = 0;

    // 사가 궁 주변에 있으면 보너스
    final directions = [
      [-1, 0], [1, 0], [0, -1], [0, 1]
    ];

    for (var dir in directions) {
      int r = gungPos[0] + dir[0];
      int c = gungPos[1] + dir[1];
      if (r >= 0 && r < 10 && c >= 0 && c < 9) {
        final piece = board[r][c];
        if (piece != null && piece.color == color && piece.type == JanggiPieceType.sa) {
          safety += 50;
        }
      }
    }

    // 장군 상태이면 감점
    if (_checkIsInCheck(color)) {
      safety -= 200;
    }

    return safety;
  }

  // 빠른 보드 평가 함수 (Minimax 탐색용 - 성능 최적화)
  int _evaluateBoardFast(JanggiColor aiColor) {
    int score = 0;
    final enemyColor = aiColor == JanggiColor.cho ? JanggiColor.han : JanggiColor.cho;

    // 궁 존재 확인
    if (_findGung(enemyColor) == null) return 100000;
    if (_findGung(aiColor) == null) return -100000;

    // 기물 가치 및 위치 합산 (빠른 평가)
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = board[r][c];
        if (piece != null) {
          int pieceValue = _getPieceValue(piece.type);
          int positionValue = _getPositionValue(piece, r, c);
          int totalValue = pieceValue + positionValue;

          if (piece.color == aiColor) {
            score += totalValue;
          } else {
            score -= totalValue;
          }
        }
      }
    }

    // 장군 상태 보너스/패널티
    if (_checkIsInCheck(enemyColor)) {
      score += 150;
    }
    if (_checkIsInCheck(aiColor)) {
      score -= 150;
    }

    return score;
  }

  // 정적 보드 평가 함수 (현재 보드 상태 점수 - 루트 레벨용)
  int _evaluateBoard(JanggiColor aiColor) {
    int score = 0;
    final enemyColor = aiColor == JanggiColor.cho ? JanggiColor.han : JanggiColor.cho;

    // 외통수 확인
    if (_isCheckmate(enemyColor)) {
      return 100000;
    }
    if (_isCheckmate(aiColor)) {
      return -100000;
    }

    // 궁 존재 확인
    if (_findGung(enemyColor) == null) return 100000;
    if (_findGung(aiColor) == null) return -100000;

    // 기물 가치 합산
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = board[r][c];
        if (piece != null) {
          int pieceValue = _getPieceValue(piece.type);
          int positionValue = _getPositionValue(piece, r, c);

          // 위협받는 기물은 가치 감소
          if (_isPieceUnderAttack(r, c, piece.color)) {
            if (_isPieceProtected(r, c, piece.color)) {
              pieceValue -= pieceValue ~/ 4; // 보호되면 25% 감소
            } else {
              pieceValue -= pieceValue ~/ 2; // 보호 안 되면 50% 감소
            }
          }

          int totalValue = pieceValue + positionValue;

          if (piece.color == aiColor) {
            score += totalValue;
          } else {
            score -= totalValue;
          }
        }
      }
    }

    // 이동성 평가
    int aiMobility = _getMobility(aiColor);
    int enemyMobility = _getMobility(enemyColor);
    score += (aiMobility - enemyMobility) * 5;

    // 궁성 안전도 평가
    score += _evaluateKingSafety(aiColor);
    score -= _evaluateKingSafety(enemyColor);

    // 장군 보너스
    if (_checkIsInCheck(enemyColor)) {
      score += 100;
    }

    return score;
  }

  // Minimax + Alpha-Beta Pruning
  int _minimax(int depth, int alpha, int beta, bool isMaximizing, JanggiColor aiColor) {
    final enemyColor = aiColor == JanggiColor.cho ? JanggiColor.han : JanggiColor.cho;

    // 깊이 0이거나 게임 종료 시 정적 평가 (빠른 평가 함수 사용)
    if (depth == 0) {
      return _evaluateBoardFast(aiColor);
    }

    // 게임 종료 조건 확인
    if (_findGung(aiColor) == null) return -100000 + ((_aiSearchDepth - depth) * 1000);
    if (_findGung(enemyColor) == null) return 100000 - ((_aiSearchDepth - depth) * 1000);

    JanggiColor currentColor = isMaximizing ? aiColor : enemyColor;

    // 모든 합법적인 수 수집
    List<Map<String, dynamic>> allMoves = [];
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = board[r][c];
        if (piece != null && piece.color == currentColor) {
          final moves = _getLegalMoves(r, c);
          for (var move in moves) {
            // 수 우선순위 계산 (이동 순서 최적화)
            int priority = 0;
            final target = board[move[0]][move[1]];
            if (target != null) {
              priority = _getPieceValue(target.type) * 10;
            }
            allMoves.add({
              'fromRow': r,
              'fromCol': c,
              'toRow': move[0],
              'toCol': move[1],
              'priority': priority,
            });
          }
        }
      }
    }

    // 합법적인 수가 없으면 패배/승리
    if (allMoves.isEmpty) {
      if (_checkIsInCheck(currentColor)) {
        return isMaximizing ? -100000 + ((_aiSearchDepth - depth) * 1000) : 100000 - ((_aiSearchDepth - depth) * 1000);
      }
      return 0; // 스테일메이트 (무승부)
    }

    // 수 정렬 (캡처 수 우선)
    allMoves.sort((a, b) => b['priority'].compareTo(a['priority']));

    if (isMaximizing) {
      int maxEval = -1000000;

      for (var move in allMoves) {
        // 이동 실행
        final movingPiece = board[move['fromRow']][move['fromCol']];
        final capturedPiece = board[move['toRow']][move['toCol']];
        board[move['toRow']][move['toCol']] = movingPiece;
        board[move['fromRow']][move['fromCol']] = null;

        int eval = _minimax(depth - 1, alpha, beta, false, aiColor);

        // 원복
        board[move['fromRow']][move['fromCol']] = movingPiece;
        board[move['toRow']][move['toCol']] = capturedPiece;

        maxEval = maxEval > eval ? maxEval : eval;
        alpha = alpha > eval ? alpha : eval;

        // Beta cutoff
        if (beta <= alpha) {
          break;
        }
      }

      return maxEval;
    } else {
      int minEval = 1000000;

      for (var move in allMoves) {
        // 이동 실행
        final movingPiece = board[move['fromRow']][move['fromCol']];
        final capturedPiece = board[move['toRow']][move['toCol']];
        board[move['toRow']][move['toCol']] = movingPiece;
        board[move['fromRow']][move['fromCol']] = null;

        int eval = _minimax(depth - 1, alpha, beta, true, aiColor);

        // 원복
        board[move['fromRow']][move['fromCol']] = movingPiece;
        board[move['toRow']][move['toCol']] = capturedPiece;

        minEval = minEval < eval ? minEval : eval;
        beta = beta < eval ? beta : eval;

        // Alpha cutoff
        if (beta <= alpha) {
          break;
        }
      }

      return minEval;
    }
  }

  // 최선의 수 찾기 (루트 레벨 minimax)
  Map<String, dynamic>? _findBestMove(JanggiColor aiColor) {
    List<Map<String, dynamic>> allMoves = [];

    // 모든 합법적인 수 수집
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = board[r][c];
        if (piece != null && piece.color == aiColor) {
          final moves = _getLegalMoves(r, c);
          for (var move in moves) {
            int priority = 0;
            final target = board[move[0]][move[1]];
            if (target != null) {
              priority = _getPieceValue(target.type) * 10;
            }
            allMoves.add({
              'fromRow': r,
              'fromCol': c,
              'toRow': move[0],
              'toCol': move[1],
              'priority': priority,
            });
          }
        }
      }
    }

    if (allMoves.isEmpty) return null;

    // 난이도에 따라 랜덤 수 선택
    if (_randomMoveChance > 0 && Random().nextDouble() < _randomMoveChance) {
      // 랜덤 수 선택 (단, 궁을 잃는 수는 제외)
      final safeMoves = allMoves.where((move) {
        final movingPiece = board[move['fromRow']][move['fromCol']];
        final capturedPiece = board[move['toRow']][move['toCol']];
        board[move['toRow']][move['toCol']] = movingPiece;
        board[move['fromRow']][move['fromCol']] = null;

        final isSafe = !_checkIsInCheck(aiColor);

        board[move['fromRow']][move['fromCol']] = movingPiece;
        board[move['toRow']][move['toCol']] = capturedPiece;

        return isSafe;
      }).toList();

      if (safeMoves.isNotEmpty) {
        return safeMoves[Random().nextInt(safeMoves.length)];
      }
    }

    // 수 정렬 (캡처 수 우선)
    allMoves.sort((a, b) => b['priority'].compareTo(a['priority']));

    Map<String, dynamic>? bestMove;
    int bestScore = -1000000;
    int alpha = -1000000;
    int beta = 1000000;

    for (var move in allMoves) {
      // 이동 실행
      final movingPiece = board[move['fromRow']][move['fromCol']];
      final capturedPiece = board[move['toRow']][move['toCol']];
      board[move['toRow']][move['toCol']] = movingPiece;
      board[move['fromRow']][move['fromCol']] = null;

      int score = _minimax(_aiSearchDepth - 1, alpha, beta, false, aiColor);

      // 원복
      board[move['fromRow']][move['fromCol']] = movingPiece;
      board[move['toRow']][move['toCol']] = capturedPiece;

      if (score > bestScore) {
        bestScore = score;
        bestMove = Map.from(move);
        bestMove['score'] = score;
      }

      alpha = alpha > score ? alpha : score;
    }

    return bestMove;
  }

  int _evaluateMove(int fromRow, int fromCol, int toRow, int toCol, JanggiPiece piece, JanggiColor computerColor) {
    int score = 0;
    final target = board[toRow][toCol];
    final enemyColor = computerColor == JanggiColor.cho ? JanggiColor.han : JanggiColor.cho;

    // 상대 말 잡기
    if (target != null) {
      score += _getPieceValue(target.type) * 10;
    }

    // 이동 후 상대에게 장군을 걸 수 있는지 확인
    final movingPiece = board[fromRow][fromCol];
    final capturedPiece = board[toRow][toCol];
    board[toRow][toCol] = movingPiece;
    board[fromRow][fromCol] = null;

    if (_checkIsInCheck(enemyColor)) {
      score += 500; // 장군을 거는 수에 높은 점수

      // 외통수 확인
      if (_isCheckmate(enemyColor)) {
        score += 50000; // 외통수는 최고 점수
      }
    }

    // 원복
    board[fromRow][fromCol] = movingPiece;
    board[toRow][toCol] = capturedPiece;

    // 위치 가치 변화
    int fromPositionValue = _getPositionValue(piece, fromRow, fromCol);
    int toPositionValue = _getPositionValue(piece, toRow, toCol);
    score += (toPositionValue - fromPositionValue);

    // 위협받는 위치에서 이동 보너스
    if (_isPieceUnderAttack(fromRow, fromCol, computerColor)) {
      if (!_isPieceProtected(fromRow, fromCol, computerColor)) {
        score += _getPieceValue(piece.type) ~/ 2; // 위협 회피 보너스
      }
    }

    // 보호받는 위치로 이동 보너스
    // 임시로 이동 후 보호 여부 확인
    board[toRow][toCol] = movingPiece;
    board[fromRow][fromCol] = null;
    if (_isPieceProtected(toRow, toCol, computerColor)) {
      score += 30;
    }
    // 이동 후 위협받으면 감점
    if (_isPieceUnderAttack(toRow, toCol, computerColor)) {
      if (!_isPieceProtected(toRow, toCol, computerColor)) {
        score -= _getPieceValue(piece.type) ~/ 2;
      }
    }
    board[fromRow][fromCol] = movingPiece;
    board[toRow][toCol] = capturedPiece;

    return score;
  }

  // 보드 상태를 문자열로 변환 (반복 검출용)
  String _getBoardStateString() {
    final buffer = StringBuffer();
    buffer.write(currentTurn == JanggiColor.cho ? 'C' : 'H');
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = board[r][c];
        if (piece == null) {
          buffer.write('.');
        } else {
          String code;
          switch (piece.type) {
            case JanggiPieceType.gung:
              code = 'K';
              break;
            case JanggiPieceType.cha:
              code = 'R';
              break;
            case JanggiPieceType.po:
              code = 'C';
              break;
            case JanggiPieceType.ma:
              code = 'N';
              break;
            case JanggiPieceType.sang:
              code = 'E';
              break;
            case JanggiPieceType.sa:
              code = 'A';
              break;
            case JanggiPieceType.byung:
              code = 'P';
              break;
          }
          buffer.write(piece.color == JanggiColor.cho ? code.toLowerCase() : code);
        }
      }
    }
    return buffer.toString();
  }

  // 무승부 선언 가능 여부 확인
  bool _canDeclareDraw() {
    if (isGameOver || isSetupPhase) return false;

    // 1. 동일 보드 상태가 3회 이상 반복된 경우 (3회 반복 규칙)
    final currentState = _getBoardStateString();
    int repeatCount = 0;
    for (final state in _boardHistory) {
      if (state == currentState) {
        repeatCount++;
      }
    }
    if (repeatCount >= 2) {
      // 현재 상태 포함 3회 이상
      return true;
    }

    // 2. 현재 장군 상태이고 연속 장군이 4회 이상인 경우
    if (_consecutiveCheckCount >= 4) {
      return true;
    }

    // 3. 장군 상태에서 피할 수 있는 수가 1개뿐인 경우
    if (isInCheck) {
      int legalMoveCount = 0;
      for (int r = 0; r < 10; r++) {
        for (int c = 0; c < 9; c++) {
          final piece = board[r][c];
          if (piece != null && piece.color == currentTurn) {
            final moves = _getValidMoves(r, c);
            // 장군을 피하는 수만 계산
            for (final move in moves) {
              final targetRow = move[0];
              final targetCol = move[1];

              // 임시 이동
              final capturedPiece = board[targetRow][targetCol];
              board[targetRow][targetCol] = piece;
              board[r][c] = null;

              // 이동 후에도 장군인지 확인
              final stillInCheck = _checkIsInCheck(currentTurn);

              // 원상복구
              board[r][c] = piece;
              board[targetRow][targetCol] = capturedPiece;

              if (!stillInCheck) {
                legalMoveCount++;
                if (legalMoveCount > 1) break; // 2개 이상이면 더 이상 체크 불필요
              }
            }
            if (legalMoveCount > 1) break;
          }
        }
        if (legalMoveCount > 1) break;
      }

      // 장군을 피할 수 있는 수가 1개뿐이면 무승부 선언 가능
      if (legalMoveCount == 1) {
        return true;
      }
    }

    return false;
  }

  void _showDrawDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5DEB3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF8B4513), width: 3),
          ),
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.handshake, color: Color(0xFF8B4513), size: 28),
              SizedBox(width: 8),
              Text(
                '무승부 선언',
                style: TextStyle(
                  color: Color(0xFF8B4513),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: const Text(
            '무승부로 게임을 종료하시겠습니까?\n\n반복되는 장군 등의 상황에서\n무승부를 선언할 수 있습니다.',
            style: TextStyle(color: Color(0xFF5D4037)),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '계속하기',
                style: TextStyle(color: Color(0xFF8B4513)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B4513),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context);
                _declareDraw();
              },
              child: const Text('무승부'),
            ),
          ],
        );
      },
    );
  }

  void _declareDraw() {
    JanggiScreen.clearSavedGame();

    setState(() {
      isGameOver = true;
      winner = null;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5DEB3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF8B4513), width: 4),
          ),
          title: const Column(
            children: [
              Icon(
                Icons.balance,
                size: 60,
                color: Color(0xFF8B4513),
              ),
              SizedBox(height: 12),
              Text(
                '무승부',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B4513),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '게임이 무승부로 종료되었습니다.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF5D4037),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 초 기물
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFF90EE90),
                    child: Text(
                      '초',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006400),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.handshake, size: 40, color: Color(0xFF8B4513)),
                  SizedBox(width: 16),
                  // 한 기물
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFFFFB6C1),
                    child: Text(
                      '한',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB22222),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B4513),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context);
                _resetGame();
              },
              child: const Text(
                '새 게임',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGameOverDialog() {
    // 저장된 게임 삭제
    JanggiScreen.clearSavedGame();

    final isPlayerWin = widget.gameMode == JanggiGameMode.vsHuman ||
        (widget.gameMode == JanggiGameMode.vsHan && winner == '초') ||
        (widget.gameMode == JanggiGameMode.vsCho && winner == '한');

    final winnerColor = winner == '초' ? JanggiColor.cho : JanggiColor.han;
    final Color winnerDisplayColor = winnerColor == JanggiColor.cho
        ? const Color(0xFF006400)
        : const Color(0xFFB22222);

    String title;
    String message;
    IconData icon;

    if (widget.gameMode == JanggiGameMode.vsHuman) {
      title = '$winner 승리!';
      message = '$winner가 승리하였습니다!';
      icon = Icons.emoji_events;
    } else if (isPlayerWin) {
      title = '축하합니다!';
      message = '플레이어($winner)가 컴퓨터를 이겼습니다!';
      icon = Icons.celebration;
    } else {
      title = '패배...';
      message = '컴퓨터($winner)에게 졌습니다.\n다시 도전해보세요!';
      icon = Icons.sentiment_dissatisfied;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5DEB3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: winnerDisplayColor, width: 4),
          ),
          title: Column(
            children: [
              Icon(
                icon,
                size: 60,
                color: winnerDisplayColor,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: winnerDisplayColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF8B4513),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // 승리 기물 표시
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: winnerColor == JanggiColor.cho
                      ? const Color(0xFF90EE90)
                      : const Color(0xFFFFB6C1),
                  border: Border.all(color: winnerDisplayColor, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: winnerDisplayColor.withAlpha(100),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    winner ?? '',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: winnerDisplayColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                '결과 확인',
                style: TextStyle(
                  color: Color(0xFF8B4513),
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: winnerDisplayColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context);
                _resetGame();
              },
              child: const Text(
                '새 게임',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _resetGame() {
    JanggiScreen.clearSavedGame();

    setState(() {
      board = List.generate(10, (_) => List.filled(9, null));
      currentTurn = JanggiColor.cho;
      selectedRow = null;
      selectedCol = null;
      validMoves = null;
      isGameOver = false;
      winner = null;
      isThinking = false;
      isInCheck = false;
      isSetupPhase = true;
      lastMoveFromRow = null;
      lastMoveFromCol = null;
      lastMoveToRow = null;
      lastMoveToCol = null;
      _boardHistory = [];
      _consecutiveCheckCount = 0;
      _moveHistory = [];
    });

    // 마상 배치 선택 다이얼로그 다시 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSetupDialog();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            // 가로 모드: 상태바 숨김 (몰입 모드)
            SystemChrome.setEnabledSystemUIMode(
              SystemUiMode.immersiveSticky,
              overlays: [],
            );
            return _buildLandscapeLayout();
          } else {
            // 세로 모드: 전체 화면
            SystemChrome.setEnabledSystemUIMode(
              SystemUiMode.immersiveSticky,
              overlays: [],
            );
            return _buildPortraitLayout();
          }
        },
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('장기'),
        backgroundColor: const Color(0xFFD2691E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showRulesDialog,
            tooltip: '게임 규칙',
          ),
          // 무승부 선언 버튼 (반복 장군/장군 불가 상황에서만 표시)
          if (_canDeclareDraw())
            IconButton(
              icon: const Icon(Icons.handshake),
              onPressed: _showDrawDialog,
              tooltip: '무승부 선언',
            ),
          // Gemini AI 상태 표시
          if (widget.gameMode != JanggiGameMode.vsHuman)
            IconButton(
              icon: Icon(
                geminiService != null ? Icons.smart_toy : Icons.smart_toy_outlined,
                color: geminiService != null ? Colors.lightGreenAccent : Colors.white70,
              ),
              onPressed: _showAISettingsDialog,
              tooltip: geminiService != null ? 'Gemini AI 활성화됨' : 'AI 설정',
            ),
          // 취소 버튼
          IconButton(
            icon: Icon(
              Icons.undo,
              color: _moveHistory.isNotEmpty && !isGameOver && !isThinking
                  ? Colors.white
                  : Colors.white38,
            ),
            onPressed: _moveHistory.isNotEmpty && !isGameOver && !isThinking
                ? _showUndoAdDialog
                : null,
            tooltip: '한 수 취소',
          ),
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

  Widget _buildLandscapeLayout() {
    String choPlayerName;
    String hanPlayerName;

    switch (widget.gameMode) {
      case JanggiGameMode.vsCho:
        choPlayerName = '컴퓨터';
        hanPlayerName = '당신';
        break;
      case JanggiGameMode.vsHan:
        choPlayerName = '당신';
        hanPlayerName = '컴퓨터';
        break;
      case JanggiGameMode.vsHuman:
        choPlayerName = '플레이어 1';
        hanPlayerName = '플레이어 2';
        break;
    }

    return Scaffold(
      body: Container(
        color: const Color(0xFFF5DEB3),
        child: SafeArea(
          child: Stack(
            children: [
              // 메인 영역: 플레이어 표시 + 게임 보드
              Row(
                children: [
                  // 왼쪽 패널: 초 플레이어
                  Expanded(
                    child: Center(
                      child: _buildPlayerIndicator(
                        color: JanggiColor.cho,
                        playerName: choPlayerName,
                        isCurrentTurn: currentTurn == JanggiColor.cho && !isGameOver,
                      ),
                    ),
                  ),
                  // 가운데: 장기 보드
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.maxHeight;
                      return SizedBox(
                        width: size * 0.9,
                        height: size,
                        child: _buildBoard(),
                      );
                    },
                  ),
                  // 오른쪽 패널: 한 플레이어
                  Expanded(
                    child: Center(
                      child: _buildPlayerIndicator(
                        color: JanggiColor.han,
                        playerName: hanPlayerName,
                        isCurrentTurn: currentTurn == JanggiColor.han && !isGameOver,
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
                        color: const Color(0xFF8B4513).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '장기',
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
              // 오른쪽 상단: 무승부 + AI설정 + 새 게임 버튼
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  children: [
                    if (_canDeclareDraw())
                      _buildCircleButton(
                        icon: Icons.handshake,
                        onPressed: _showDrawDialog,
                        tooltip: '무승부 선언',
                      ),
                    if (_canDeclareDraw())
                      const SizedBox(width: 8),
                    if (widget.gameMode != JanggiGameMode.vsHuman)
                      _buildCircleButton(
                        icon: geminiService != null ? Icons.smart_toy : Icons.smart_toy_outlined,
                        onPressed: _showAISettingsDialog,
                        tooltip: geminiService != null ? 'Gemini AI 활성화됨' : 'AI 설정',
                      ),
                    if (widget.gameMode != JanggiGameMode.vsHuman)
                      const SizedBox(width: 8),
                    // 취소 버튼
                    _buildCircleButton(
                      icon: Icons.undo,
                      onPressed: _moveHistory.isNotEmpty && !isGameOver && !isThinking
                          ? _showUndoAdDialog
                          : null,
                      tooltip: '한 수 취소',
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
        color: const Color(0xFF8B4513).withValues(alpha: 0.7),
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
    required JanggiColor color,
    required String playerName,
    required bool isCurrentTurn,
  }) {
    final pieceColor = color == JanggiColor.cho
        ? const Color(0xFF006400)
        : const Color(0xFFB22222);
    final bgColor = color == JanggiColor.cho
        ? const Color(0xFF90EE90)
        : const Color(0xFFFFB6C1);
    final borderColor = isCurrentTurn ? pieceColor : Colors.brown.shade300;
    final label = color == JanggiColor.cho ? '초' : '한';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFDEB887).withValues(alpha: 0.5),
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
              color: bgColor,
              border: Border.all(color: pieceColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: pieceColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            playerName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.brown.shade800,
            ),
          ),
          Text(
            '($label)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.brown.shade600,
            ),
          ),
          if (isCurrentTurn && !isGameOver)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isInCheck ? Colors.red.shade700 : pieceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isInCheck ? '장군!' : (isThinking ? '생각중...' : '차례'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (isGameOver)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: winner == label ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  winner == label ? '승리' : '패배',
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

  Widget _buildStatusBar() {
    String status;
    Color bgColor = const Color(0xFFD2691E);

    if (isSetupPhase) {
      status = '마상 배치 선택 중...';
      bgColor = Colors.blueGrey;
    } else if (isGameOver) {
      status = '$winner 승리!';
      bgColor = Colors.purple;
    } else if (isThinking) {
      status = useGeminiAI && geminiService != null
          ? 'Gemini AI 생각 중...'
          : '컴퓨터 생각 중...';
      bgColor = useGeminiAI && geminiService != null
          ? Colors.indigo
          : const Color(0xFFD2691E);
    } else if (isInCheck) {
      status = '${currentTurn == JanggiColor.cho ? "초" : "한"} 장군!';
      bgColor = Colors.red.shade700;
    } else {
      status = '${currentTurn == JanggiColor.cho ? "초" : "한"} 차례';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: bgColor,
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
          // 컴퓨터 대전 시 난이도 표시
          if (widget.gameMode != JanggiGameMode.vsHuman && !isSetupPhase) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getDifficultyColor(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _difficultyName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 난이도별 색상
  Color _getDifficultyColor() {
    switch (_difficulty) {
      case JanggiDifficulty.easy:
        return Colors.green;
      case JanggiDifficulty.normal:
        return Colors.orange;
      case JanggiDifficulty.hard:
        return Colors.red;
    }
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
    final isLastMoveFrom = lastMoveFromRow == row && lastMoveFromCol == col;
    final isLastMoveTo = lastMoveToRow == row && lastMoveToCol == col;

    Color? bgColor;
    if (isSelected) {
      bgColor = Colors.yellow.withAlpha(128);
    } else if (isValidMove) {
      bgColor = Colors.green.withAlpha(77);
    } else if (isLastMoveTo) {
      bgColor = Colors.blue.withAlpha(100);
    } else if (isLastMoveFrom) {
      bgColor = Colors.blue.withAlpha(50);
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor ?? Colors.transparent,
        border: (isLastMoveFrom || isLastMoveTo) && !isSelected && !isValidMove
            ? Border.all(color: Colors.blue.withAlpha(180), width: 2)
            : null,
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

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          '장기 게임 규칙',
          style: TextStyle(color: Color(0xFFD2691E)),
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
                '상대방의 궁(왕)을 외통수로 잡으면 승리!\n'
                '(궁이 장군을 피할 수 없는 상태)',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '🏰 기물 이동',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• 궁: 궁성 안에서 1칸 이동\n'
                '• 차: 가로/세로 무제한\n'
                '• 포: 가로/세로로 다른 기물 뛰어넘어 이동\n'
                '• 마: 가로/세로 1칸 + 대각선 1칸\n'
                '• 상: 가로/세로 1칸 + 대각선 2칸\n'
                '• 사: 궁성 안에서 1칸 이동\n'
                '• 졸/병: 앞/좌/우로 1칸',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '⚔️ 특수 규칙',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• 장군: 상대 궁을 공격하는 상태\n'
                '• 외통수: 장군을 피할 수 없는 상태\n'
                '• 빅장: 양측 궁이 마주보면 먼저 비킨 쪽이 불리\n'
                '• 포는 포를 뛰어넘거나 잡을 수 없음',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '💡 팁',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• 차가 가장 강력한 기물입니다\n'
                '• 포는 다른 기물이 있어야 공격 가능\n'
                '• 마와 상의 경로에 기물이 있으면 이동 불가',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
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
