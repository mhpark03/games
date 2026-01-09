import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'models/maze.dart';
import 'widgets/maze_widget.dart';
import '../../services/ad_service.dart';

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
  List<Position>? hintPath;

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
    hintPath = null;
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
        hintPath = null; // 이동 시 힌트 숨기기
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

  // 힌트 광고 다이얼로그
  void _showHintAdDialog() {
    if (isGameWon) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text('dialog.hintTitle'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text(
          'dialog.hintMessage'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('app.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final adService = AdService();
              final result = await adService.showRewardedAd(
                onUserEarnedReward: (ad, reward) {
                  _useHint();
                },
              );
              if (!result && mounted) {
                // 광고가 없어도 기능 실행
                _useHint();
                adService.loadRewardedAd();
              }
            },
            child: Text('common.watchAd'.tr()),
          ),
        ],
      ),
    );
  }

  // 힌트 사용: 경로 표시
  void _useHint() {
    if (isGameWon) return;

    setState(() {
      hintPath = maze.findPathToEnd();
    });
    HapticFeedback.mediumImpact();
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
        child: OrientationBuilder(
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
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.grid_4x4, color: Colors.purpleAccent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'games.maze.name'.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.purple.shade100,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showRulesDialog,
            tooltip: 'app.rules'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: !isGameWon ? _showHintAdDialog : null,
            tooltip: 'common.hint'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.replay),
            onPressed: _newGame,
            tooltip: 'app.newGame'.tr(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildInfoPanel(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: MazeWidget(
                    maze: maze,
                    onMove: _movePlayer,
                    hintPath: hintPath,
                  ),
                ),
              ),
            ),
            _buildControls(),
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
            // 왼쪽 패널: 뒤로가기, 제목, 왼쪽/위 방향 버튼
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
                        Expanded(
                          child: Text(
                            'games.maze.name'.tr(),
                            style: TextStyle(
                              color: Colors.purple.shade100,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 이동 정보
                    _buildLandscapeInfoBox('games.maze.movesLabel'.tr(), moves.toString()),
                    const SizedBox(height: 8),
                    // 시간 정보
                    _buildLandscapeInfoBox('games.maze.timeLabel'.tr(), _formatTime(elapsedSeconds)),
                    const Spacer(),
                    // 왼쪽 컨트롤: 왼쪽 → 위
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final buttonSize = (constraints.maxWidth / 2.5).clamp(45.0, 60.0);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildLandscapeControlButton(
                              Icons.arrow_back,
                              () => _movePlayer(const Position(0, -1)),
                              buttonSize,
                            ),
                            _buildLandscapeControlButton(
                              Icons.arrow_upward,
                              () => _movePlayer(const Position(-1, 0)),
                              buttonSize,
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
            // 중앙: 미로 보드
            Expanded(
              flex: 3,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: MazeWidget(
                    maze: maze,
                    onMove: _movePlayer,
                    hintPath: hintPath,
                  ),
                ),
              ),
            ),
            // 오른쪽 패널: 버튼들, 아래/오른쪽 방향 버튼
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // 도움말 + 힌트 + 새게임 버튼
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildCircleButton(
                          icon: Icons.help_outline,
                          onPressed: _showRulesDialog,
                        ),
                        const SizedBox(width: 4),
                        _buildCircleButton(
                          icon: Icons.lightbulb_outline,
                          onPressed: !isGameWon ? _showHintAdDialog : null,
                          color: !isGameWon ? Colors.amber : Colors.white30,
                        ),
                        const SizedBox(width: 4),
                        _buildCircleButton(
                          icon: Icons.replay,
                          onPressed: _newGame,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 결과 메시지
                    if (isGameWon) _buildCompactResultMessage(),
                    const Spacer(),
                    // 오른쪽 컨트롤: 아래 → 오른쪽
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final buttonSize = (constraints.maxWidth / 2.5).clamp(45.0, 60.0);
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildLandscapeControlButton(
                              Icons.arrow_downward,
                              () => _movePlayer(const Position(1, 0)),
                              buttonSize,
                            ),
                            _buildLandscapeControlButton(
                              Icons.arrow_forward,
                              () => _movePlayer(const Position(0, 1)),
                              buttonSize,
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
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade800,
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.white70),
        onPressed: onPressed,
        iconSize: 20,
      ),
    );
  }

  Widget _buildLandscapeInfoBox(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 10,
            ),
          ),
          Text(
            value,
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

  Widget _buildLandscapeControlButton(IconData icon, VoidCallback onPressed, double size) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: Colors.purple, size: size * 0.5),
      ),
    );
  }

  Widget _buildCompactResultMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
          const SizedBox(height: 4),
          Text(
            'common.win'.tr(),
            style: const TextStyle(
              color: Colors.green,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoItem(
                icon: Icons.directions_walk,
                iconColor: Colors.purple,
                value: moves.toString(),
                label: 'games.maze.movesLabel'.tr(),
              ),
              _buildInfoItem(
                icon: Icons.timer,
                iconColor: Colors.orange,
                value: _formatTime(elapsedSeconds),
                label: 'games.maze.timeLabel'.tr(),
              ),
            ],
          ),
          if (isGameWon) ...[
            const SizedBox(height: 12),
            _buildResultMessage(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events,
            color: Colors.amber,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            'common.win'.tr(),
            style: const TextStyle(
              color: Colors.green,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(Icons.arrow_back, () => _movePlayer(const Position(0, -1))),
          _buildControlButton(Icons.arrow_upward, () => _movePlayer(const Position(-1, 0))),
          _buildControlButton(Icons.arrow_downward, () => _movePlayer(const Position(1, 0))),
          _buildControlButton(Icons.arrow_forward, () => _movePlayer(const Position(0, 1))),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: Colors.purple, size: 28),
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
          'games.maze.rulesTitle'.tr(),
          style: const TextStyle(color: Colors.purple),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRuleSection(
                'games.maze.rulesObjective'.tr(),
                'games.maze.rulesObjectiveDesc'.tr(),
              ),
              const SizedBox(height: 12),
              _buildRuleSection(
                'games.maze.rulesControls'.tr(),
                'games.maze.rulesControlsDesc'.tr(),
              ),
              const SizedBox(height: 12),
              _buildRuleSection(
                'games.maze.rulesButtons'.tr(),
                'games.maze.rulesButtonsDesc'.tr(),
              ),
              const SizedBox(height: 12),
              _buildRuleSection(
                'games.maze.rulesTips'.tr(),
                'games.maze.rulesTipsDesc'.tr(),
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

  Widget _buildRuleSection(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }
}
