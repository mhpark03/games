import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'models/mole_game.dart';

class MoleScreen extends StatefulWidget {
  const MoleScreen({super.key});

  @override
  State<MoleScreen> createState() => _MoleScreenState();
}

class _MoleScreenState extends State<MoleScreen> {
  late MoleGame game;
  int highScore = 0;

  @override
  void initState() {
    super.initState();
    game = MoleGame();
    game.onUpdate = () => setState(() {});
    game.onGameEnd = _showGameOverDialog;
  }

  @override
  void dispose() {
    game.dispose();
    super.dispose();
  }

  void _startGame() {
    game.start();
  }

  void _showGameOverDialog() {
    if (game.score > highScore) {
      highScore = game.score;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.brown.withValues(alpha: 0.5), width: 2),
        ),
        title: Text(
          'games.mole.gameOver'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFFFD700), fontSize: 28),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 64),
            const SizedBox(height: 16),
            Text(
              'games.mole.finalScore'.tr(namedArgs: {'score': game.score.toString()}),
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              'games.mole.highScoreLabel'.tr(namedArgs: {'score': highScore.toString()}),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'common.confirm'.tr(),
              style: const TextStyle(color: Color(0xFF00D9FF), fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
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
    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildScoreBoard(),
        const SizedBox(height: 24),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildGameGrid(),
          ),
        ),
        _buildControls(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // 왼쪽 패널: 뒤로가기, 제목, 점수
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
                        'games.mole.name'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLandscapeInfoBox('games.mole.score'.tr(), game.score.toString(), Icons.star),
                const SizedBox(height: 8),
                _buildLandscapeInfoBox('games.mole.time'.tr(), '${game.timeLeft}${'games.mole.seconds'.tr()}', Icons.timer),
                const Spacer(),
              ],
            ),
          ),
        ),
        // 중앙: 게임 그리드
        Expanded(
          flex: 3,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildGameGrid(),
            ),
          ),
        ),
        // 오른쪽 패널: 도움말, 최고점수, 시작 버튼
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
                  ],
                ),
                const SizedBox(height: 8),
                _buildLandscapeInfoBox('games.mole.highScore'.tr(), highScore.toString(), Icons.emoji_events),
                const SizedBox(height: 16),
                _buildLandscapeStartButton(),
                const Spacer(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade800,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white70),
        onPressed: onPressed,
        iconSize: 20,
      ),
    );
  }

  Widget _buildLandscapeInfoBox(String label, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.brown.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
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
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeStartButton() {
    return GestureDetector(
      onTap: game.isPlaying ? null : _startGame,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: game.isPlaying ? Colors.grey.shade800 : Colors.brown,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          game.isPlaying ? 'games.mole.playing'.tr() : 'games.mole.start'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
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
                'games.mole.name'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'games.mole.subtitle'.tr(),
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: _showRulesDialog,
            icon: const Icon(Icons.help_outline, color: Colors.white),
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
          'games.mole.rulesTitle'.tr(),
          style: const TextStyle(color: Color(0xFFFFD700)),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRuleSection(
                'games.mole.rulesObjective'.tr(),
                'games.mole.rulesObjectiveDesc'.tr(),
              ),
              const SizedBox(height: 12),
              _buildRuleSection(
                'games.mole.rulesControls'.tr(),
                'games.mole.rulesControlsDesc'.tr(),
              ),
              const SizedBox(height: 12),
              _buildRuleSection(
                'games.mole.rulesScoring'.tr(),
                'games.mole.rulesScoringDesc'.tr(),
              ),
              const SizedBox(height: 12),
              _buildRuleSection(
                'games.mole.rulesTips'.tr(),
                'games.mole.rulesTipsDesc'.tr(),
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

  Widget _buildScoreBoard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard('games.mole.score'.tr(), game.score.toString(), Icons.star),
          _buildStatCard('games.mole.time'.tr(), '${game.timeLeft}${'games.mole.seconds'.tr()}', Icons.timer),
          _buildStatCard('games.mole.highScore'.tr(), highScore.toString(), Icons.emoji_events),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 20),
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameGrid() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF8B4513),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF5D3A1A), width: 4),
        ),
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 9,
          itemBuilder: (context, index) => _buildHole(index),
        ),
      ),
    );
  }

  Widget _buildHole(int index) {
    final hasMole = game.holes[index];

    return GestureDetector(
      onTap: () {
        if (game.isPlaying && hasMole) {
          game.whack(index);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF3D2314),
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: hasMole
              ? Container(
                  key: const ValueKey('mole'),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B6914),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF5D4A1A),
                          width: 3,
                        ),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('👀', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                            Text('👃', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : Container(
                  key: const ValueKey('empty'),
                  margin: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A1810),
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: game.isPlaying ? null : _startGame,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: game.isPlaying
                ? Colors.grey.shade800
                : Colors.brown,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            game.isPlaying ? 'games.mole.playing'.tr() : 'games.mole.start'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
