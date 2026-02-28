import 'dart:math';
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
  const TetrisWideScreen({super.key});

  @override
  State<TetrisWideScreen> createState() => _TetrisWideScreenState();
}

class _TetrisWideScreenState extends State<TetrisWideScreen>
    with SingleTickerProviderStateMixin {
  late GameBoard _gameBoard;
  final FocusNode _focusNode = FocusNode();
  bool _gameOverDialogShown = false;
  bool _levelCompleteDialogShown = false;
  final List<_Particle> _particles = [];
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  int _calculateRows() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final pixelRatio = view.devicePixelRatio;
    final screenHeight = view.physicalSize.height / pixelRatio;
    final screenWidth = view.physicalSize.width / pixelRatio;
    final viewPaddingTop = view.padding.top / pixelRatio;
    final viewPaddingBottom = view.padding.bottom / pixelRatio;

    // UI element heights: AppBar(56) + InfoRow(~76) + Controls(~92) + bottom spacing(8)
    const fixedHeight = 56.0 + 76.0 + 92.0 + 8.0;
    final safeArea = viewPaddingTop + viewPaddingBottom;
    final boardPadding = 24.0; // 12px top/bottom padding around board

    final availableHeight = screenHeight - fixedHeight - safeArea - boardPadding;
    final availableWidth = screenWidth - 24.0; // 12px horizontal padding each side
    final cellSize = availableWidth / GameBoard.cols;
    final rows = (availableHeight / cellSize).floor();

    return rows.clamp(20, 50);
  }

  @override
  void initState() {
    super.initState();
    InputSdkService.setActionGameContext();
    _gameBoard = GameBoard(rows: _calculateRows());
    _gameBoard.addListener(_onGameUpdate);
    _gameBoard.startGame();
    _ticker = createTicker(_onTick);
  }

  void _onGameUpdate() {
    if (_gameBoard.lastClearedCells.isNotEmpty) {
      _spawnParticles(_gameBoard.lastClearedCells);
      _gameBoard.lastClearedCells = [];
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

    for (var p in _particles) {
      p.update(dt);
    }
    _particles.removeWhere((p) => p.isDead);

    if (_particles.isEmpty) {
      _ticker!.stop();
    }
    setState(() {});
  }

  void _spawnParticles(List<ClearedCell> cells) {
    final random = Random();
    for (var cell in cells) {
      final cx = cell.col + 0.5;
      final cy = cell.row + 0.5;
      final count = 3 + random.nextInt(3);
      for (int i = 0; i < count; i++) {
        final angle = random.nextDouble() * 2 * pi;
        final speed = 3 + random.nextDouble() * 7;
        _particles.add(_Particle(
          x: cx + (random.nextDouble() - 0.5) * 0.3,
          y: cy + (random.nextDouble() - 0.5) * 0.3,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed - 4,
          size: 0.15 + random.nextDouble() * 0.3,
          color: cell.color,
          rotation: random.nextDouble() * pi * 2,
          rotationSpeed: (random.nextDouble() - 0.5) * 12,
        ));
      }
    }
    if (!_ticker!.isActive) {
      _lastTick = Duration.zero;
      _ticker!.start();
    }
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

  void _showLevelCompleteDialog() {
    if (_levelCompleteDialogShown) return;
    _levelCompleteDialogShown = true;

    final completedLevel = _gameBoard.level;
    final nextFillRows = (5 + _gameBoard.level * 2).clamp(1, _gameBoard.rows - 4);

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
            const SizedBox(height: 8),
            Text(
              'games.tetrisWide.linesValue'.tr(namedArgs: {'lines': _gameBoard.linesCleared.toString()}),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              'games.tetrisWide.fillRows'.tr(namedArgs: {'rows': nextFillRows.toString()}),
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
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(child: _buildInfoBox('games.tetrisWide.score'.tr(), _gameBoard.score.toString())),
                  const SizedBox(width: 6),
                  Expanded(child: _buildInfoBox('games.tetrisWide.level'.tr(), _gameBoard.level.toString())),
                  const SizedBox(width: 6),
                  Expanded(child: _buildInfoBox('games.tetrisWide.lines'.tr(), _gameBoard.remainingRows.toString())),
                  const SizedBox(width: 6),
                  InlineNextPieceWidget(piece: _gameBoard.nextPiece),
                ],
              ),
            ),
            // Game board - full width
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GameBoardWidget(gameBoard: _gameBoard),
                      if (_particles.isNotEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _ParticlePainter(
                                _particles, GameBoard.cols, _gameBoard.rows, 2,
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
                    const SizedBox(height: 88),
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
                        GameBoardWidget(gameBoard: _gameBoard),
                        if (_particles.isNotEmpty)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _ParticlePainter(
                                  _particles, GameBoard.cols, _gameBoard.rows, 2,
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

class _Particle {
  double x, y;
  double vx, vy;
  double size;
  double opacity;
  Color color;
  double rotation;
  double rotationSpeed;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    this.rotation = 0,
    this.rotationSpeed = 0,
  }) : opacity = 1.0;

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 15 * dt;
    opacity -= 1.5 * dt;
    rotation += rotationSpeed * dt;
    if (opacity < 0) opacity = 0;
  }

  bool get isDead => opacity <= 0;
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final int cols;
  final int rows;
  final double borderWidth;

  _ParticlePainter(this.particles, this.cols, this.rows, this.borderWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final boardWidth = size.width - borderWidth * 2;
    final boardHeight = size.height - borderWidth * 2;
    final cellWidth = boardWidth / cols;
    final cellHeight = boardHeight / rows;

    for (var p in particles) {
      if (p.opacity <= 0) continue;
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity.clamp(0.0, 1.0));

      final px = borderWidth + p.x * cellWidth;
      final py = borderWidth + p.y * cellHeight;
      final psize = p.size * cellWidth;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: psize, height: psize),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => particles.isNotEmpty;
}
