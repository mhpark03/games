import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'models/game_board.dart';
import 'widgets/game_board_widget.dart';
import 'widgets/next_piece_widget.dart';
import '../tetris/widgets/control_button.dart';
import '../../services/input_sdk_service.dart';

class TetrisWideScreen extends StatefulWidget {
  final int startLevel;
  const TetrisWideScreen({super.key, this.startLevel = 1});

  @override
  State<TetrisWideScreen> createState() => _TetrisWideScreenState();
}

class _TetrisWideScreenState extends State<TetrisWideScreen>
    with SingleTickerProviderStateMixin {
  late GameBoard _gameBoard;
  final FocusNode _focusNode = FocusNode();
  bool _gameOverDialogShown = false;
  bool _levelCompleteDialogShown = false;
  final List<_SlidingRow> _slidingRows = [];
  final List<_FallingCell> _fallingCells = [];
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  int _calculateRows() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final pixelRatio = view.devicePixelRatio;
    final screenHeight = view.physicalSize.height / pixelRatio;
    final screenWidth = view.physicalSize.width / pixelRatio;
    final viewPaddingTop = view.padding.top / pixelRatio;
    final viewPaddingBottom = view.padding.bottom / pixelRatio;

    // UI element heights: AppBar(56) + InfoRow(~50) + Controls(~70) + bottom spacing(4)
    const fixedHeight = 56.0 + 50.0 + 70.0 + 4.0;
    final safeArea = viewPaddingTop + viewPaddingBottom;
    final boardPadding = 12.0; // 6px top/bottom padding around board

    final availableHeight = screenHeight - fixedHeight - safeArea - boardPadding;
    final availableWidth = screenWidth - 24.0; // 12px horizontal padding each side
    final cellSizeFromWidth = availableWidth / GameBoard.cols;
    // 웹 넓은 화면에서 셀이 너무 커지는 것을 방지 → 세로 칸수 확보
    final cellSize = cellSizeFromWidth > 20.0 ? 20.0 : cellSizeFromWidth;
    final rows = (availableHeight / cellSize).floor();

    return rows.clamp(20, 60);
  }

  @override
  void initState() {
    super.initState();
    InputSdkService.setActionGameContext();
    _gameBoard = GameBoard(rows: _calculateRows(), startLevel: widget.startLevel);
    _gameBoard.addListener(_onGameUpdate);
    _gameBoard.startGame();
    _ticker = createTicker(_onTick);
  }

  void _onGameUpdate() {
    bool hasNewAnimations = false;
    if (_gameBoard.lastClearedCells.isNotEmpty) {
      _startSlideAnimation(_gameBoard.lastClearedCells);
      _gameBoard.lastClearedCells = [];
      hasNewAnimations = true;
    }
    if (_gameBoard.lastFallingCells.isNotEmpty) {
      _startFallingAnimation(_gameBoard.lastFallingCells);
      _gameBoard.lastFallingCells = [];
      hasNewAnimations = true;
    }
    // 애니메이션 없으면 즉시 색상 정규화
    if (!hasNewAnimations && _slidingRows.isEmpty && _fallingCells.isEmpty) {
      _gameBoard.normalizeNewCells();
    }
    if (_gameBoard.isLevelComplete && !_levelCompleteDialogShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLevelCompleteDialog();
      });
    }
    setState(() {});
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;

    for (var row in _slidingRows) {
      row.update(dt);
    }
    _slidingRows.removeWhere((r) => r.isDone);

    for (var cell in _fallingCells) {
      cell.update(dt);
    }
    _fallingCells.removeWhere((c) => c.isDone);

    if (_slidingRows.isEmpty && _fallingCells.isEmpty) {
      _ticker!.stop();
      // 연쇄 클리어 확인: 낙하로 새 줄이 채워졌으면 다시 애니메이션 실행
      if (!_gameBoard.isGameOver &&
          !_gameBoard.isLevelComplete &&
          _gameBoard.stepCascade()) {
        // stepCascade()가 notifyListeners() 호출 → _onGameUpdate()에서
        // 새 슬라이드/낙하 애니메이션이 시작되고 ticker가 재시작됨
      } else {
        _gameBoard.normalizeNewCells();
      }
    }
    setState(() {});
  }

  void _startSlideAnimation(List<ClearedCell> cells) {
    // Group cells by row
    final Map<int, List<Color?>> rowMap = {};
    for (var cell in cells) {
      rowMap.putIfAbsent(cell.row, () => List.filled(GameBoard.cols, null));
      rowMap[cell.row]![cell.col] = cell.color;
    }

    final sortedRows = rowMap.keys.toList()..sort();
    for (int i = 0; i < sortedRows.length; i++) {
      final row = sortedRows[i];
      _slidingRows.add(_SlidingRow(
        row: row,
        colors: rowMap[row]!,
        direction: i % 2 == 0 ? 1 : -1,
      ));
    }

    if (!_ticker!.isActive) {
      _lastTick = Duration.zero;
      _ticker!.start();
    }
  }

  void _startFallingAnimation(List<FallingCell> cells) {
    for (var cell in cells) {
      _fallingCells.add(_FallingCell(
        col: cell.col,
        fromRow: cell.fromRow,
        toRow: cell.toRow,
        color: cell.color,
      ));
    }
    if (!_ticker!.isActive) {
      _lastTick = Duration.zero;
      _ticker!.start();
    }
  }

  Set<int>? _getSkipCells() {
    if (_fallingCells.isEmpty) return null;
    final set = <int>{};
    for (var cell in _fallingCells) {
      if (!cell.isDone) {
        set.add(cell.toRow * GameBoard.cols + cell.col);
      }
    }
    return set.isEmpty ? null : set;
  }

  @override
  void dispose() {
    _ticker?.stop();
    _ticker?.dispose();
    _gameBoard.removeListener(_onGameUpdate);
    _gameBoard.dispose();
    _focusNode.dispose();
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

  void _showSpeedSettingDialog() {
    _gameBoard.pauseGame();
    int tempLevel = _gameBoard.level;
    int tempSpeed = _gameBoard.speed;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text(
            'games.tetrisWide.gameSetting'.tr(),
            style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // 레벨 설정
              Text(
                'games.tetrisWide.level'.tr(),
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'games.tetrisWide.levelValue'.tr(namedArgs: {'level': tempLevel.toString()}),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.cyan, size: 36),
                    onPressed: tempLevel > 1 ? () => setDialogState(() => tempLevel--) : null,
                  ),
                  Expanded(
                    child: Slider(
                      value: tempLevel.toDouble(),
                      min: 1,
                      max: 20,
                      divisions: 19,
                      activeColor: Colors.cyan,
                      inactiveColor: Colors.grey,
                      onChanged: (v) => setDialogState(() => tempLevel = v.toInt()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.cyan, size: 36),
                    onPressed: tempLevel < 20 ? () => setDialogState(() => tempLevel++) : null,
                  ),
                ],
              ),
              const Divider(color: Colors.grey, height: 24),
              // 속도 설정
              Text(
                'games.tetrisWide.speedSetting'.tr(),
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                '${tempSpeed}ms',
                style: const TextStyle(color: Colors.white, fontSize: 28),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.cyan, size: 36),
                    onPressed: tempSpeed > 50 ? () => setDialogState(() => tempSpeed -= 50) : null,
                  ),
                  Expanded(
                    child: Slider(
                      value: tempSpeed.toDouble(),
                      min: 50,
                      max: 500,
                      divisions: 9,
                      activeColor: Colors.cyan,
                      inactiveColor: Colors.grey,
                      onChanged: (v) => setDialogState(() => tempSpeed = v.toInt()),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.cyan, size: 36),
                    onPressed: tempSpeed < 500 ? () => setDialogState(() => tempSpeed += 50) : null,
                  ),
                ],
              ),
              Text(
                'games.tetrisWide.speedDesc'.tr(),
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _gameBoard.pauseGame(); // 재개
              },
              child: Text(
                'games.tetrisWide.cancel'.tr(),
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _gameBoard.startLevel = tempLevel;
                _gameBoard.setSpeed(tempSpeed);
                _gameBoard.startGame();
              },
              child: Text(
                'games.tetrisWide.startGame'.tr(),
                style: const TextStyle(color: Colors.cyan, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLevelCompleteDialog() {
    if (_levelCompleteDialogShown) return;
    _levelCompleteDialogShown = true;

    final completedLevel = _gameBoard.level;

    // 다음 레벨 정보 미리 계산
    int nextFill = _gameBoard.currentFillRows + 2;
    int nextSpeedBoost = _gameBoard.speedBoost;
    final maxFill = (_gameBoard.rows * 2) ~/ 3;
    if (nextFill > maxFill) {
      nextFill = _gameBoard.rows ~/ 3;
      nextSpeedBoost++;
    }
    final nextSpeed = (_gameBoard.speed - nextSpeedBoost * 20).clamp(50, 999);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          'games.tetrisWide.levelComplete'.tr(namedArgs: {'level': completedLevel.toString()}),
          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 24),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'games.tetrisWide.scoreValue'.tr(namedArgs: {'score': _gameBoard.score.toString()}),
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 12),
            Text(
              'games.tetrisWide.fillRows'.tr(namedArgs: {'rows': nextFill.toString()}),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'games.tetrisWide.speed'.tr(namedArgs: {'speed': nextSpeed.toString()}),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _levelCompleteDialogShown = false;
              _gameBoard.nextLevel();
            },
            child: Text(
              'games.tetrisWide.nextLevel'.tr(),
              style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ).then((_) {
      _levelCompleteDialogShown = false;
    });
  }

  void _showGameOverDialog() {
    if (_gameOverDialogShown) return;
    _gameOverDialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          'games.tetrisWide.gameOverTitle'.tr(),
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'games.tetrisWide.scoreValue'.tr(namedArgs: {'score': _gameBoard.score.toString()}),
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              'games.tetrisWide.levelValueColon'.tr(namedArgs: {'level': _gameBoard.level.toString()}),
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            Text(
              'games.tetrisWide.linesValue'.tr(namedArgs: {'lines': _gameBoard.linesCleared.toString()}),
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
            child: Text(
              'games.tetrisWide.playAgain'.tr(),
              style: const TextStyle(color: Colors.cyan, fontSize: 18),
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
              return _buildLandscapeLayout();
            } else {
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
        title: Text(
          'games.tetrisWide.name'.tr().toUpperCase(),
          style: const TextStyle(
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
            onPressed: _showSpeedSettingDialog,
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
            // Score, Level, Lines, Next block - all in one row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(child: _buildInfoBox('games.tetrisWide.score'.tr(), _gameBoard.score.toString())),
                  const SizedBox(width: 3),
                  Expanded(child: _buildInfoBox('games.tetrisWide.level'.tr(), _gameBoard.level.toString())),
                  const SizedBox(width: 3),
                  Expanded(child: _buildInfoBox('games.tetrisWide.lines'.tr(), _gameBoard.remainingRows.toString())),
                  const SizedBox(width: 3),
                  InlineNextPieceWidget(piece: _gameBoard.nextPiece),
                ],
              ),
            ),
            // Game board - full width
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GameBoardWidget(gameBoard: _gameBoard, skipCells: _getSkipCells()),
                      if (_slidingRows.isNotEmpty || _fallingCells.isNotEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _AnimationOverlayPainter(
                                slidingRows: _slidingRows,
                                fallingCells: _fallingCells,
                                cols: GameBoard.cols,
                                rows: _gameBoard.rows,
                                borderWidth: 2,
                              ),
                            ),
                          ),
                        ),
                      if (_gameBoard.isPaused)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black54,
                            child: Center(
                              child: Text(
                                'games.tetrisWide.paused'.tr(),
                                style: const TextStyle(
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
            // Control buttons
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
            // Left panel
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildCircleButton(
                          icon: Icons.arrow_back,
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'games.tetrisWide.name'.tr().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.cyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 2,
                              fontStyle: FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildLandscapeInfoBox('games.tetrisWide.score'.tr(), _gameBoard.score.toString()),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildLandscapeInfoBox('games.tetrisWide.level'.tr(), _gameBoard.level.toString()),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildLandscapeInfoBox('games.tetrisWide.lines'.tr(), _gameBoard.remainingRows.toString()),
                        ),
                      ],
                    ),
                    const Spacer(),
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
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Center panel: game board
            Expanded(
              flex: 3,
              child: Center(
                child: AspectRatio(
                  aspectRatio: GameBoard.cols / _gameBoard.rows,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GameBoardWidget(gameBoard: _gameBoard, skipCells: _getSkipCells()),
                        if (_slidingRows.isNotEmpty || _fallingCells.isNotEmpty)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _AnimationOverlayPainter(
                                  slidingRows: _slidingRows,
                                  fallingCells: _fallingCells,
                                  cols: GameBoard.cols,
                                  rows: _gameBoard.rows,
                                  borderWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        if (_gameBoard.isPaused)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black54,
                              child: Center(
                                child: Text(
                                  'games.tetrisWide.paused'.tr(),
                                  style: const TextStyle(
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
            // Right panel
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildCircleButton(
                          icon: Icons.help_outline,
                          onPressed: _showRulesDialog,
                        ),
                        const SizedBox(width: 8),
                        _buildCircleButton(
                          icon: Icons.settings,
                          onPressed: _showSpeedSettingDialog,
                        ),
                        const SizedBox(width: 8),
                        _buildCircleButton(
                          icon: _gameBoard.isPaused ? Icons.play_arrow : Icons.pause,
                          onPressed: _gameBoard.pauseGame,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    NextPieceWidget(piece: _gameBoard.nextPiece),
                    const Spacer(),
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
                    const SizedBox(height: 16),
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

  Widget _buildInfoBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
        title: Text(
          'games.tetrisWide.rulesTitle'.tr(),
          style: const TextStyle(color: Colors.cyan),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'games.tetrisWide.objective'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.tetrisWide.objectiveDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.tetrisWide.controls'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.tetrisWide.controlsDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.tetrisWide.scoring'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.tetrisWide.scoringDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.tetrisWide.gameOverTitle'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.tetrisWide.gameOverDesc'.tr(),
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

class _SlidingRow {
  final int row;
  final List<Color?> colors;
  final int direction; // 1 = right, -1 = left
  double time;

  static const double _blinkCycle = 0.18;  // 1회 깜빡임 주기
  static const int _blinkCount = 3;         // 총 깜빡임 횟수
  static const double _blinkDuration = _blinkCycle * _blinkCount; // 0.54s
  static const double slideDuration = 0.28;

  _SlidingRow({
    required this.row,
    required this.colors,
    required this.direction,
  }) : time = 0.0;

  void update(double dt) {
    time += dt;
  }

  // 주기의 60%는 밝게, 40%는 꺼짐
  bool get _isBlinkOn {
    if (time >= _blinkDuration) return false;
    return (time % _blinkCycle) < (_blinkCycle * 0.6);
  }

  double get flashOpacity => _isBlinkOn ? 0.92 : 0.0;

  double get slideProgress {
    if (time < _blinkDuration) return 0.0;
    final t = ((time - _blinkDuration) / slideDuration).clamp(0.0, 1.0);
    return 1.0 - (1.0 - t) * (1.0 - t); // ease-out quadratic
  }

  double get opacity {
    if (time < _blinkDuration) return 1.0;
    final t = ((time - _blinkDuration) / slideDuration).clamp(0.0, 1.0);
    return 1.0 - t;
  }

  bool get isDone => time >= _blinkDuration + slideDuration;
}

class _FallingCell {
  final int col;
  final int fromRow;
  final int toRow;
  final Color color;
  double time;

  static const double delay = 0.35;
  static const double duration = 0.25;

  _FallingCell({
    required this.col,
    required this.fromRow,
    required this.toRow,
    required this.color,
  }) : time = 0.0;

  void update(double dt) {
    time += dt;
  }

  double get currentRow {
    if (time < delay) return fromRow.toDouble();
    final t = ((time - delay) / duration).clamp(0.0, 1.0);
    // ease-in: 가속 낙하 느낌
    final eased = t * t;
    return fromRow + (toRow - fromRow) * eased;
  }

  bool get isDone => time >= delay + duration;
}

class _AnimationOverlayPainter extends CustomPainter {
  final List<_SlidingRow> slidingRows;
  final List<_FallingCell> fallingCells;
  final int cols;
  final int rows;
  final double borderWidth;

  _AnimationOverlayPainter({
    required this.slidingRows,
    required this.fallingCells,
    required this.cols,
    required this.rows,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final boardWidth = size.width - borderWidth * 2;
    final boardHeight = size.height - borderWidth * 2;
    final cellWidth = boardWidth / cols;
    final cellHeight = boardHeight / rows;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(borderWidth, borderWidth, boardWidth, boardHeight));

    // 슬라이드 줄 그리기
    for (var slidingRow in slidingRows) {
      final offsetX = slidingRow.slideProgress * boardWidth * slidingRow.direction;
      final alpha = slidingRow.opacity;

      for (int col = 0; col < cols; col++) {
        final color = slidingRow.colors[col];
        if (color == null) continue;

        final x = borderWidth + col * cellWidth + offsetX;
        final y = borderWidth + slidingRow.row * cellHeight;
        _drawCell(canvas, x, y, cellWidth, cellHeight, color, alpha);
      }

      if (slidingRow.flashOpacity > 0) {
        final flashPaint = Paint()
          ..color = const Color(0xFFFFEB3B).withValues(alpha: slidingRow.flashOpacity);
        final y = borderWidth + slidingRow.row * cellHeight;
        canvas.drawRect(
          Rect.fromLTWH(borderWidth, y, boardWidth, cellHeight),
          flashPaint,
        );
      }
    }

    // 낙하 셀 그리기
    for (var cell in fallingCells) {
      if (cell.isDone) continue;
      final x = borderWidth + cell.col * cellWidth;
      final y = borderWidth + cell.currentRow * cellHeight;
      _drawCell(canvas, x, y, cellWidth, cellHeight, cell.color, 1.0);
    }

    canvas.restore();
  }

  void _drawCell(Canvas canvas, double x, double y, double width, double height, Color color, double alpha) {
    final fillPaint = Paint()..color = color.withValues(alpha: alpha);
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3 * alpha)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3 * alpha)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTWH(x + 1, y + 1, width - 2, height - 2),
      fillPaint,
    );
    canvas.drawLine(Offset(x + 2, y + 2), Offset(x + width - 2, y + 2), borderPaint);
    canvas.drawLine(Offset(x + 2, y + 2), Offset(x + 2, y + height - 2), borderPaint);
    canvas.drawLine(Offset(x + width - 2, y + 2), Offset(x + width - 2, y + height - 2), shadowPaint);
    canvas.drawLine(Offset(x + 2, y + height - 2), Offset(x + width - 2, y + height - 2), shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) =>
      slidingRows.isNotEmpty || fallingCells.isNotEmpty;
}
