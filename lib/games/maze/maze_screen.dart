import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'models/maze.dart';
import 'widgets/maze_widget.dart';

enum MazeDifficulty { easy, medium, hard }

class MazeScreen extends StatefulWidget {
  final MazeDifficulty difficulty;

  const MazeScreen({
    super.key,
    this.difficulty = MazeDifficulty.medium,
  });

  @override
  State<MazeScreen> createState() => _MazeScreenState();
}

class _MazeScreenState extends State<MazeScreen> {
  late Maze maze;
  late MazeDifficulty difficulty;
  int moves = 0;
  int elapsedSeconds = 0;
  Timer? timer;
  bool isGameWon = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    difficulty = widget.difficulty;
    _initializeMaze();
    _startTimer();
  }

  @override
  void dispose() {
    timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _initializeMaze() {
    final size = _getMazeSize();
    maze = Maze(rows: size.$1, cols: size.$2);
    moves = 0;
    elapsedSeconds = 0;
    isGameWon = false;
  }

  (int, int) _getMazeSize() {
    switch (difficulty) {
      case MazeDifficulty.easy:
        return (25, 25);
      case MazeDifficulty.medium:
        return (35, 35);
      case MazeDifficulty.hard:
        return (51, 51);
    }
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isGameWon) {
        setState(() {
          elapsedSeconds++;
        });
      }
    });
  }

  void _movePlayer(Position direction) {
    if (isGameWon) return;

    setState(() {
      if (maze.movePlayer(direction)) {
        moves++;
        if (maze.isGameWon) {
          isGameWon = true;
          timer?.cancel();
          _showWinDialog();
        }
      }
    });
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.purple.withValues(alpha: 0.5), width: 2),
        ),
        title: Text(
          'games.maze.congratulations'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFFFD700), fontSize: 28),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 64),
            const SizedBox(height: 16),
            Text(
              'games.maze.escaped'.tr(),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text(
              'games.maze.moves'.tr(namedArgs: {'count': moves.toString()}),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            Text(
              'games.maze.time'.tr(namedArgs: {'time': _formatTime(elapsedSeconds)}),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _newGame();
            },
            child: Text(
              'app.newGame'.tr(),
              style: const TextStyle(color: Color(0xFF00D9FF), fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _newGame() {
    setState(() {
      _initializeMaze();
    });
    _startTimer();
  }

  void _resetGame() {
    setState(() {
      maze.reset();
      moves = 0;
      elapsedSeconds = 0;
      isGameWon = false;
    });
    _startTimer();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowUp:
        case LogicalKeyboardKey.keyW:
          _movePlayer(const Position(-1, 0));
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowDown:
        case LogicalKeyboardKey.keyS:
          _movePlayer(const Position(1, 0));
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowLeft:
        case LogicalKeyboardKey.keyA:
          _movePlayer(const Position(0, -1));
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowRight:
        case LogicalKeyboardKey.keyD:
          _movePlayer(const Position(0, 1));
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyR:
          _resetGame();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyN:
          _newGame();
          return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: MazeWidget(
                        maze: maze,
                        onMove: _movePlayer,
                      ),
                    ),
                  ),
                ),
                _buildControls(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'games.maze.name'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'games.maze.subtitle'.tr(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              _buildStatCard('games.maze.movesLabel'.tr(), moves.toString(), Icons.directions_walk),
              const SizedBox(width: 12),
              _buildStatCard('games.maze.timeLabel'.tr(), _formatTime(elapsedSeconds), Icons.timer),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.purple, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10,
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
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 방향 버튼 한 줄 배치
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(Icons.arrow_back, () => _movePlayer(const Position(0, -1))),
              _buildControlButton(Icons.arrow_upward, () => _movePlayer(const Position(-1, 0))),
              _buildControlButton(Icons.arrow_downward, () => _movePlayer(const Position(1, 0))),
              _buildControlButton(Icons.arrow_forward, () => _movePlayer(const Position(0, 1))),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton('games.maze.reset'.tr(), Icons.refresh, _resetGame),
              const SizedBox(width: 16),
              _buildActionButton('games.maze.newMaze'.tr(), Icons.casino, _newGame),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: Colors.purple, size: 28),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
