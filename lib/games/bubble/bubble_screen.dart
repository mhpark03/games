import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'models/bubble_game.dart';
import '../../services/ad_service.dart';

class BubbleScreen extends StatefulWidget {
  const BubbleScreen({super.key});

  @override
  State<BubbleScreen> createState() => _BubbleScreenState();
}

class _BubbleScreenState extends State<BubbleScreen> {
  late BubbleShooterGame game;
  int highScore = 0;
  Timer? gameLoop;
  Size? gameSize;
  bool showHintLine = false; // 힌트 안내선 표시 여부
  bool isLandscape = false; // 현재 화면 방향

  @override
  void initState() {
    super.initState();
    game = BubbleShooterGame();
    game.onUpdate = () => setState(() {});
    game.onGameOver = _showGameOverDialog;

    // 게임 루프 시작
    gameLoop = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (gameSize != null) {
        game.update(gameSize!.width, gameSize!.height);
      }
    });
  }

  @override
  void dispose() {
    gameLoop?.cancel();
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      showHintLine = false;
      game.reset();
    });
  }

  void _showHintAdDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'games.bubble.hintTitle'.tr(),
          style: const TextStyle(color: Color(0xFF00D9FF)),
        ),
        content: Text(
          'games.bubble.hintMessage'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'common.cancel'.tr(),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
            ),
            onPressed: () async {
              Navigator.pop(context);
              final adService = AdService();
              final result = await adService.showRewardedAd(
                onUserEarnedReward: (ad, reward) {
                  setState(() {
                    showHintLine = true;
                  });
                },
              );
              if (!result && mounted) {
                setState(() {
                  showHintLine = true;
                });
                adService.loadRewardedAd();
              }
            },
            child: Text(
              'common.watchAd'.tr(),
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog() {
    if (game.score > highScore) {
      highScore = game.score;
    }
    showHintLine = false; // 게임 종료 시 힌트 초기화

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.cyan.withValues(alpha: 0.5), width: 2),
        ),
        title: Text(
          'games.bubble.gameOver'.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFFFD700), fontSize: 28),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bubble_chart, color: Color(0xFF00D9FF), size: 64),
            const SizedBox(height: 16),
            Text(
              'games.bubble.finalScore'.tr(namedArgs: {'score': game.score.toString()}),
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              'games.bubble.highScoreLabel'.tr(namedArgs: {'score': highScore.toString()}),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetGame();
            },
            child: Text(
              'games.bubble.retry'.tr(),
              style: const TextStyle(color: Color(0xFF00D9FF), fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBubbleColor(BubbleColor color) {
    switch (color) {
      case BubbleColor.red:
        return Colors.red;
      case BubbleColor.blue:
        return Colors.blue;
      case BubbleColor.green:
        return Colors.green;
      case BubbleColor.yellow:
        return Colors.amber;
      case BubbleColor.purple:
        return Colors.purple;
      case BubbleColor.orange:
        return Colors.orange;
      case BubbleColor.empty:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            isLandscape = orientation == Orientation.landscape;
            if (isLandscape) {
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
        const SizedBox(height: 8),
        _buildScoreBoard(),
        const SizedBox(height: 8),
        Expanded(
          child: _buildGameArea(),
        ),
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
                        'games.bubble.name'.tr(),
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
                _buildLandscapeInfoBox('games.bubble.score'.tr(), game.score.toString(), Icons.star),
                const SizedBox(height: 8),
                _buildLandscapeInfoBox('games.bubble.highScore'.tr(), highScore.toString(), Icons.emoji_events),
                const Spacer(),
              ],
            ),
          ),
        ),
        // 중앙: 게임 영역 (flex 3으로 축소)
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _buildGameArea(),
          ),
        ),
        // 오른쪽 패널: 새 게임, 힌트, 도움말, 다음 버블
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
                      icon: Icons.refresh,
                      onPressed: _resetGame,
                    ),
                    const SizedBox(width: 8),
                    _buildCircleButton(
                      icon: Icons.lightbulb_outline,
                      onPressed: showHintLine ? null : _showHintAdDialog,
                    ),
                    const SizedBox(width: 8),
                    _buildCircleButton(
                      icon: Icons.help_outline,
                      onPressed: _showRulesDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 다음 버블
                _buildLandscapeNextBubble(),
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
    required VoidCallback? onPressed,
  }) {
    final isDisabled = onPressed == null;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDisabled ? Colors.grey.shade900 : Colors.grey.shade800,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isDisabled ? const Color(0xFF00D9FF) : Colors.white70,
        ),
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
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00D9FF), size: 18),
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

  Widget _buildLandscapeNextBubble() {
    return Column(
      children: [
        Text(
          'games.bubble.next'.tr(),
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: game.nextBubble != null
                ? _getBubbleColor(game.nextBubble!.color)
                : Colors.grey,
            boxShadow: [
              BoxShadow(
                color: (game.nextBubble != null
                        ? _getBubbleColor(game.nextBubble!.color)
                        : Colors.grey)
                    .withValues(alpha: 0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ],
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
                'games.bubble.name'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'games.bubble.subtitle'.tr(),
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: _resetGame,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          IconButton(
            onPressed: showHintLine ? null : _showHintAdDialog,
            icon: Icon(
              Icons.lightbulb_outline,
              color: showHintLine ? const Color(0xFF00D9FF) : Colors.white,
            ),
          ),
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
          'games.bubble.rulesTitle'.tr(),
          style: const TextStyle(color: Color(0xFF00D9FF)),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRuleSection(
                'games.bubble.rulesObjective'.tr(),
                'games.bubble.rulesObjectiveDesc'.tr(),
              ),
              const SizedBox(height: 12),
              _buildRuleSection(
                'games.bubble.rulesControls'.tr(),
                'games.bubble.rulesControlsDesc'.tr(),
              ),
              const SizedBox(height: 12),
              _buildRuleSection(
                'games.bubble.rulesScoring'.tr(),
                'games.bubble.rulesScoringDesc'.tr(),
              ),
              const SizedBox(height: 12),
              _buildRuleSection(
                'games.bubble.rulesTips'.tr(),
                'games.bubble.rulesTipsDesc'.tr(),
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
          _buildStatCard('games.bubble.score'.tr(), game.score.toString(), Icons.star),
          _buildStatCard('games.bubble.highScore'.tr(), highScore.toString(), Icons.emoji_events),
          // 다음 버블
          _buildNextBubbleCard(),
        ],
      ),
    );
  }

  Widget _buildNextBubbleCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'games.bubble.next'.tr(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: game.nextBubble != null
                  ? _getBubbleColor(game.nextBubble!.color)
                  : Colors.grey,
              boxShadow: [
                BoxShadow(
                  color: (game.nextBubble != null
                          ? _getBubbleColor(game.nextBubble!.color)
                          : Colors.grey)
                      .withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00D9FF), size: 20),
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

  Widget _buildGameArea() {
    // 가로모드에서는 버블 크기를 줄임
    final bubbleScale = isLandscape ? 0.7 : 1.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            gameSize = Size(constraints.maxWidth, constraints.maxHeight);
            // 가로모드에서는 발사대 위치를 더 아래로
            final shooterOffset = isLandscape ? 30 : 40;
            game.setShooterPosition(
              constraints.maxWidth / 2,
              constraints.maxHeight - shooterOffset,
            );

            return GestureDetector(
              onPanUpdate: (details) {
                game.aim(details.localPosition.dx, details.localPosition.dy);
                setState(() {});
              },
              onTapUp: (details) {
                game.aim(details.localPosition.dx, details.localPosition.dy);
                game.shoot();
              },
              child: CustomPaint(
                painter: BubbleGamePainter(
                  game: game,
                  getBubbleColor: _getBubbleColor,
                  showHint: showHintLine,
                  bubbleScale: bubbleScale,
                ),
                size: Size.infinite,
              ),
            );
          },
        ),
      ),
    );
  }

}

class BubbleGamePainter extends CustomPainter {
  final BubbleShooterGame game;
  final Color Function(BubbleColor) getBubbleColor;
  final bool showHint;
  final double bubbleScale;

  BubbleGamePainter({
    required this.game,
    required this.getBubbleColor,
    this.showHint = false,
    this.bubbleScale = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / BubbleShooterGame.cols;
    final baseBubbleRadius = BubbleShooterGame.bubbleRadius * bubbleScale;
    final cellHeight = baseBubbleRadius * 2 * 0.866;

    // 그리드 버블 그리기
    for (int row = 0; row < BubbleShooterGame.rows; row++) {
      for (int col = 0; col < BubbleShooterGame.cols; col++) {
        final bubble = game.grid[row][col];
        if (bubble == null) continue;

        final offset = (row % 2 == 1) ? cellWidth / 2 : 0;
        final x = col * cellWidth + cellWidth / 2 + offset;
        final y = row * cellHeight + baseBubbleRadius;

        _drawBubble(canvas, x, y, baseBubbleRadius, getBubbleColor(bubble.color));
      }
    }

    // 발사 중인 버블
    if (game.shootingBubble != null) {
      _drawBubble(
        canvas,
        game.shootingBubble!.x,
        game.shootingBubble!.y,
        baseBubbleRadius,
        getBubbleColor(game.shootingBubble!.color),
      );
    }

    // 떨어지는 버블
    for (final bubble in game.fallingBubbles) {
      _drawBubble(
        canvas,
        bubble.x,
        bubble.y,
        baseBubbleRadius * 0.9,
        getBubbleColor(bubble.color).withValues(alpha: 0.8),
      );
    }

    // 터지는 버블
    for (final bubble in game.poppingBubbles) {
      _drawBubble(
        canvas,
        bubble.x,
        bubble.y,
        baseBubbleRadius * 0.7,
        getBubbleColor(bubble.color).withValues(alpha: 0.6),
      );
    }

    // 조준선 (힌트 모드이거나 발사 중이 아닐 때)
    final shouldDrawAimLine = showHint || (!game.isShooting && game.currentBubble != null);
    if (shouldDrawAimLine && game.currentBubble != null) {
      final bubbleColor = getBubbleColor(game.currentBubble!.color);
      _drawAimLine(canvas, size, baseBubbleRadius, bubbleColor, showHint);
    }

    // 발사대
    _drawShooter(canvas, size, bubbleScale);
  }

  void _drawAimLine(Canvas canvas, Size size, double bubbleRadius, Color color, bool isHintMode) {
    final cellWidth = size.width / BubbleShooterGame.cols;
    final cellHeight = bubbleRadius * 2 * 0.866;

    // 경로 포인트 계산
    final points = <Offset>[];
    double x = game.shooterX;
    double y = game.shooterY;
    double vx = cos(game.aimAngle);
    double vy = sin(game.aimAngle);

    points.add(Offset(x, y));

    // 경로 추적 (벽 반사 및 버블 충돌 포함)
    bool hitBubble = false;
    for (int step = 0; step < 500 && !hitBubble; step++) {
      x += vx * 2;
      y += vy * 2;

      // 좌우 벽 반사
      if (x < bubbleRadius) {
        x = bubbleRadius;
        vx = -vx;
        points.add(Offset(x, y));
      } else if (x > size.width - bubbleRadius) {
        x = size.width - bubbleRadius;
        vx = -vx;
        points.add(Offset(x, y));
      }

      // 상단 도달 시 종료
      if (y < bubbleRadius) {
        points.add(Offset(x, bubbleRadius));
        break;
      }

      // 버블과 충돌 체크
      for (int row = 0; row < BubbleShooterGame.rows; row++) {
        for (int col = 0; col < BubbleShooterGame.cols; col++) {
          if (game.grid[row][col] == null) continue;

          final offset = (row % 2 == 1) ? cellWidth / 2 : 0;
          final bx = col * cellWidth + cellWidth / 2 + offset;
          final by = row * cellHeight + bubbleRadius;

          final dx = x - bx;
          final dy = y - by;
          final dist = sqrt(dx * dx + dy * dy);

          if (dist < bubbleRadius * 1.9) {
            points.add(Offset(x, y));
            hitBubble = true;
            break;
          }
        }
        if (hitBubble) break;
      }
    }

    // 마지막 점 추가
    if (!hitBubble && points.last.dy > bubbleRadius) {
      points.add(Offset(x, y));
    }

    // 점선 그리기 (힌트 모드에서는 더 밝고 크게)
    final alpha = isHintMode ? 1.0 : 0.8;
    final lineWidth = isHintMode ? 6.0 : 4.0;
    final dotRadiusValue = isHintMode ? 7.0 : 5.0;
    final dotSpacing = isHintMode ? 16.0 : 18.0;

    final dotPaint = Paint()
      ..color = isHintMode ? const Color(0xFF00D9FF) : color.withValues(alpha: alpha)
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      final start = points[i];
      final end = points[i + 1];

      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final distance = sqrt(dx * dx + dy * dy);
      if (distance < 1) continue;

      final unitX = dx / distance;
      final unitY = dy / distance;

      double traveled = 0;
      bool draw = true;

      while (traveled < distance) {
        if (draw) {
          canvas.drawCircle(
            Offset(start.dx + unitX * traveled, start.dy + unitY * traveled),
            dotRadiusValue,
            dotPaint,
          );
        }
        traveled += dotSpacing / 2;
        draw = !draw;
      }
    }
  }

  void _drawBubble(Canvas canvas, double x, double y, double radius, Color color) {
    // 그림자
    canvas.drawCircle(
      Offset(x, y + 2),
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );

    // 메인 버블
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      colors: [
        Color.lerp(color, Colors.white, 0.3)!,
        color,
        Color.lerp(color, Colors.black, 0.2)!,
      ],
    );

    canvas.drawCircle(
      Offset(x, y),
      radius,
      Paint()..shader = gradient.createShader(
        Rect.fromCircle(center: Offset(x, y), radius: radius),
      ),
    );

    // 하이라이트
    canvas.drawCircle(
      Offset(x - radius * 0.3, y - radius * 0.3),
      radius * 0.25,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  void _drawShooter(Canvas canvas, Size size, double scale) {
    final shooterX = game.shooterX;
    final shooterY = game.shooterY;

    // 발사대 베이스
    final basePaint = Paint()
      ..color = const Color(0xFF4A4A6A)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(shooterX, shooterY + 10 * scale),
      30 * scale,
      basePaint,
    );

    // 발사대 포신
    final barrelPaint = Paint()
      ..color = const Color(0xFF6A6A8A)
      ..strokeWidth = 12 * scale
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(shooterX, shooterY),
      Offset(
        shooterX + cos(game.aimAngle) * 40 * scale,
        shooterY + sin(game.aimAngle) * 40 * scale,
      ),
      barrelPaint,
    );
  }

  @override
  bool shouldRepaint(covariant BubbleGamePainter oldDelegate) => true;
}
