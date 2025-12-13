import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/gemini_service.dart';
import '../../services/game_save_service.dart';

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

enum JanggiGameMode { vsCho, vsHan, vsHuman }

class JanggiScreen extends StatefulWidget {
  final JanggiGameMode gameMode;
  final bool resumeGame;

  const JanggiScreen({
    super.key,
    required this.gameMode,
    this.resumeGame = false,
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

  Future<void> _loadGeminiApiKey() async {
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
    // 컴퓨터의 마상 배치는 랜덤으로 설정
    final random = DateTime.now().millisecondsSinceEpoch;
    if (widget.gameMode == JanggiGameMode.vsCho) {
      // 컴퓨터가 초일 때, 초의 배치는 랜덤
      choLeftPosition = random % 2 == 0 ? MaSangPosition.maSang : MaSangPosition.sangMa;
      choRightPosition = (random ~/ 2) % 2 == 0 ? MaSangPosition.maSang : MaSangPosition.sangMa;
    } else if (widget.gameMode == JanggiGameMode.vsHan) {
      // 컴퓨터가 한일 때, 한의 배치는 랜덤
      hanLeftPosition = random % 2 == 0 ? MaSangPosition.maSang : MaSangPosition.sangMa;
      hanRightPosition = (random ~/ 2) % 2 == 0 ? MaSangPosition.maSang : MaSangPosition.sangMa;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF5DEB3),
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
                    // 플레이어 초의 배치 (한과 대전 또는 2인 플레이)
                    if (widget.gameMode == JanggiGameMode.vsHan ||
                        widget.gameMode == JanggiGameMode.vsHuman) ...[
                      _buildPositionSelector(
                        '초 (플레이어)',
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
          },
        );
      },
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

    board[toRow][toCol] = board[fromRow][fromCol];
    board[fromRow][fromCol] = null;

    // 궁 잡힘 체크
    if (capturedPiece?.type == JanggiPieceType.gung) {
      isGameOver = true;
      winner = currentTurn == JanggiColor.cho ? '초' : '한';
    }

    currentTurn =
        currentTurn == JanggiColor.cho ? JanggiColor.han : JanggiColor.cho;

    // 장군 상태 업데이트
    isInCheck = _checkIsInCheck(currentTurn);

    // 외통수(체크메이트) 확인
    if (!isGameOver && _isCheckmate(currentTurn)) {
      isGameOver = true;
      winner = currentTurn == JanggiColor.cho ? '한' : '초';
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

  void _makeComputerMove() async {
    if (isGameOver) return;

    setState(() {
      isThinking = true;
    });

    JanggiColor computerColor =
        widget.gameMode == JanggiGameMode.vsCho
            ? JanggiColor.cho
            : JanggiColor.han;

    List<Map<String, dynamic>> allMoves = [];

    // 모든 합법적인 수 수집 (장군 회피 포함)
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 9; c++) {
        final piece = board[r][c];
        if (piece != null && piece.color == computerColor) {
          final moves = _getLegalMoves(r, c); // 합법적인 수만 사용
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

    if (allMoves.isEmpty) {
      setState(() {
        isThinking = false;
        isGameOver = true;
        winner = computerColor == JanggiColor.cho ? '한' : '초';
      });
      return;
    }

    Map<String, dynamic>? bestMove;

    // Gemini AI 사용 시도
    if (useGeminiAI && geminiService != null) {
      try {
        final geminiMove = await geminiService!.getBestMove(
          board: board,
          currentPlayer: computerColor == JanggiColor.cho ? 'cho' : 'han',
          legalMoves: allMoves,
        );

        if (geminiMove != null) {
          bestMove = geminiMove;
        }
      } catch (e) {
        // Gemini 실패 시 로컬 AI 사용
      }
    }

    // Gemini가 실패하거나 비활성화된 경우 로컬 AI 사용
    if (bestMove == null) {
      // 최고 점수 수 선택
      allMoves.sort((a, b) => b['score'].compareTo(a['score']));

      // 상위 수 중에서 랜덤 선택 (같은 점수인 경우)
      int topScore = allMoves[0]['score'];
      var topMoves = allMoves.where((m) => m['score'] == topScore).toList();
      bestMove = topMoves[(topMoves.length * (DateTime.now().millisecond / 1000)).floor() % topMoves.length];
    }

    if (!mounted) return;

    setState(() {
      isThinking = false;
      _movePiece(
          bestMove!['fromRow'], bestMove['fromCol'], bestMove['toRow'], bestMove['toCol']);
    });
  }

  int _evaluateMove(int fromRow, int fromCol, int toRow, int toCol, JanggiPiece piece, JanggiColor computerColor) {
    int score = 0;
    final target = board[toRow][toCol];
    final enemyColor = computerColor == JanggiColor.cho ? JanggiColor.han : JanggiColor.cho;

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

    // 차/포: 열린 줄 선호
    if (piece.type == JanggiPieceType.cha || piece.type == JanggiPieceType.po) {
      score += 30;
    }

    return score;
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
    });

    // 마상 배치 선택 다이얼로그 다시 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSetupDialog();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('장기'),
        backgroundColor: const Color(0xFFD2691E),
        foregroundColor: Colors.white,
        actions: [
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
