import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/game_board.dart';
import 'widgets/game_board_widget.dart';
import 'widgets/next_piece_widget.dart';
import 'widgets/control_button.dart';

class TetrisScreen extends StatefulWidget {
  const TetrisScreen({super.key});

  @override
  State<TetrisScreen> createState() => _TetrisScreenState();
}

class _TetrisScreenState extends State<TetrisScreen> {
  late GameBoard _gameBoard;
  final FocusNode _focusNode = FocusNode();
  bool _gameOverDialogShown = false;

  @override
  void initState() {
    super.initState();
    _gameBoard = GameBoard();
    _gameBoard.addListener(_onGameUpdate);
    _gameBoard.startGame();
  }

  void _onGameUpdate() {
    setState(() {});
  }

  @override
  void dispose() {
    _gameBoard.removeListener(_onGameUpdate);
    _gameBoard.dispose();
    _focusNode.dispose();
    // 화면을 나갈 때 상태바 복원
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _gameBoard.moveLeft();
        break;
      case LogicalKeyboardKey.arrowRight:
        _gameBoard.moveRight();
        break;
      case LogicalKeyboardKey.arrowDown:
        _gameBoard.moveDown();
        break;
      case LogicalKeyboardKey.arrowUp:
        _gameBoard.rotate();
        break;
      case LogicalKeyboardKey.space:
        _gameBoard.hardDrop();
        break;
      case LogicalKeyboardKey.keyP:
        _gameBoard.pauseGame();
        break;
      case LogicalKeyboardKey.keyR:
        if (_gameBoard.isGameOver) {
          _gameBoard.startGame();
        }
        break;
    }
  }

  void _showLevelSelectDialog() {
    _gameBoard.pauseGame();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'SELECT START LEVEL',
          style: TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Level ${_gameBoard.startLevel}',
                style: const TextStyle(color: Colors.white, fontSize: 32),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.cyan, size: 40),
                    onPressed: _gameBoard.startLevel > 1
                        ? () {
                            _gameBoard.setStartLevel(_gameBoard.startLevel - 1);
                            setDialogState(() {});
                          }
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Slider(
                      value: _gameBoard.startLevel.toDouble(),
                      min: 1,
                      max: GameBoard.maxLevel.toDouble(),
                      divisions: GameBoard.maxLevel - 1,
                      activeColor: Colors.cyan,
                      inactiveColor: Colors.grey,
                      onChanged: (value) {
                        _gameBoard.setStartLevel(value.toInt());
                        setDialogState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.cyan, size: 40),
                    onPressed: _gameBoard.startLevel < GameBoard.maxLevel
                        ? () {
                            _gameBoard.setStartLevel(_gameBoard.startLevel + 1);
                            setDialogState(() {});
                          }
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Speed: ${500 - (_gameBoard.startLevel - 1) * 50}ms',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _gameBoard.pauseGame();
            },
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _gameBoard.startGame();
            },
            child: const Text(
              'START GAME',
              style: TextStyle(color: Colors.cyan, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog() {
    if (_gameOverDialogShown) return;
    _gameOverDialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'GAME OVER',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Score: ${_gameBoard.score}',
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              'Level: ${_gameBoard.level}',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            Text(
              'Lines: ${_gameBoard.linesCleared}',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _gameOverDialogShown = false;
              _gameBoard.startGame();
            },
            child: const Text(
              'PLAY AGAIN',
              style: TextStyle(color: Colors.cyan, fontSize: 18),
            ),
          ),
        ],
      ),
    ).then((_) {
      _gameOverDialogShown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_gameBoard.isGameOver && !_gameOverDialogShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGameOverDialog();
      });
    }

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        body: OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.landscape) {
              // 가로 모드: 상태바 숨김
              SystemChrome.setEnabledSystemUIMode(
                SystemUiMode.immersiveSticky,
                overlays: [],
              );
              return _buildLandscapeLayout();
            } else {
              // 세로 모드: 상태바 표시
              SystemChrome.setEnabledSystemUIMode(
                SystemUiMode.edgeToEdge,
                overlays: SystemUiOverlay.values,
              );
              return _buildPortraitLayout();
            }
          },
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'TETRIS',
          style: TextStyle(
            color: Colors.cyan,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 4,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: _showRulesDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _showLevelSelectDialog,
          ),
          IconButton(
            icon: Icon(
              _gameBoard.isPaused ? Icons.play_arrow : Icons.pause,
              color: Colors.white,
            ),
            onPressed: _gameBoard.pauseGame,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoBox('SCORE', _gameBoard.score.toString()),
                  _buildInfoBox('LEVEL', _gameBoard.level.toString()),
                  _buildInfoBox('LINES', _gameBoard.linesCleared.toString()),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: Stack(
                            children: [
                              GameBoardWidget(gameBoard: _gameBoard),
                              if (_gameBoard.isPaused)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black54,
                                    child: const Center(
                                      child: Text(
                                        'PAUSED',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    NextPieceWidget(piece: _gameBoard.nextPiece),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final buttonSize = (constraints.maxWidth - 48) / 4;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      HoldControlButton(
                        icon: Icons.arrow_left,
                        onPressed: _gameBoard.moveLeft,
                        size: buttonSize,
                      ),
                      ControlButton(
                        icon: Icons.rotate_left,
                        onPressed: _gameBoard.rotateLeft,
                        size: buttonSize,
                      ),
                      ControlButton(
                        icon: Icons.vertical_align_bottom,
                        onPressed: _gameBoard.hardDrop,
                        size: buttonSize,
                      ),
                      HoldControlButton(
                        icon: Icons.arrow_right,
                        onPressed: _gameBoard.moveRight,
                        size: buttonSize,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: SafeArea(
        child: Row(
          children: [
            // 왼쪽 패널: 제목, 점수/레벨, 왼쪽 컨트롤
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // 뒤로가기 + 제목
                    Row(
                      children: [
                        _buildCircleButton(
                          icon: Icons.arrow_back,
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'TETRIS',
                          style: TextStyle(
                            color: Colors.cyan,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            letterSpacing: 2,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // SCORE (전체 너비)
                    _buildLandscapeInfoBox('SCORE', _gameBoard.score.toString()),
                    const SizedBox(height: 8),
                    // LV와 LINE (가로 배치)
                    Row(
                      children: [
                        Expanded(
                          child: _buildLandscapeInfoBox('LV', _gameBoard.level.toString()),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildLandscapeInfoBox('LINE', _gameBoard.linesCleared.toString()),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // 왼쪽 컨트롤: Arrow Left → Rotate Left → Hard Drop
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final buttonSize = (constraints.maxWidth / 3.5).clamp(45.0, 65.0);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            HoldControlButton(
                              icon: Icons.arrow_left,
                              onPressed: _gameBoard.moveLeft,
                              size: buttonSize,
                            ),
                            ControlButton(
                              icon: Icons.rotate_left,
                              onPressed: _gameBoard.rotateLeft,
                              size: buttonSize,
                            ),
                            ControlButton(
                              icon: Icons.vertical_align_bottom,
                              onPressed: _gameBoard.hardDrop,
                              size: buttonSize,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 88),
                  ],
                ),
              ),
            ),
            // 가운데 패널: 게임 보드
            Expanded(
              flex: 3,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 10 / 20,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Stack(
                      children: [
                        GameBoardWidget(gameBoard: _gameBoard),
                        if (_gameBoard.isPaused)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black54,
                              child: const Center(
                                child: Text(
                                  'PAUSED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 오른쪽 패널: 설정/일시정지, 다음 피스, 오른쪽 컨트롤
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // 설정 + 일시정지 버튼
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildCircleButton(
                          icon: Icons.settings,
                          onPressed: _showLevelSelectDialog,
                        ),
                        const SizedBox(width: 8),
                        _buildCircleButton(
                          icon: _gameBoard.isPaused ? Icons.play_arrow : Icons.pause,
                          onPressed: _gameBoard.pauseGame,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 다음 피스
                    NextPieceWidget(piece: _gameBoard.nextPiece),
                    const Spacer(),
                    // 오른쪽 컨트롤: Soft Drop → Rotate Right → Arrow Right
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final buttonSize = (constraints.maxWidth / 3.5).clamp(45.0, 65.0);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            HoldControlButton(
                              icon: Icons.arrow_drop_down,
                              onPressed: _gameBoard.moveDown,
                              size: buttonSize,
                            ),
                            ControlButton(
                              icon: Icons.rotate_right,
                              onPressed: _gameBoard.rotate,
                              size: buttonSize,
                            ),
                            HoldControlButton(
                              icon: Icons.arrow_right,
                              onPressed: _gameBoard.moveRight,
                              size: buttonSize,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 88),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.grey.shade800,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeInfoBox(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyan, width: 2),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactInfoBox(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyan, width: 2),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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
          '테트리스 게임 규칙',
          style: TextStyle(color: Colors.cyan),
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
                '떨어지는 블록을 배치하여 가로줄을 완성하세요.\n'
                '완성된 줄은 사라지고 점수를 얻습니다.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '🎮 조작 방법',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• ←→ : 블록 좌우 이동\n'
                '• ↓ : 블록 빠르게 내리기\n'
                '• 회전 버튼 : 블록 90° 회전\n'
                '• 드롭 버튼 : 블록 즉시 떨어뜨리기',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '💯 점수 시스템',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• 1줄 완성: 100점\n'
                '• 2줄 동시: 300점\n'
                '• 3줄 동시: 500점\n'
                '• 4줄 동시 (테트리스): 800점',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '⚠️ 게임 오버',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '블록이 천장에 닿으면 게임이 끝납니다.',
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
