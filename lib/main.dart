import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'games/tetris/tetris_screen.dart';
import 'games/gomoku/gomoku_screen.dart';
import 'games/othello/othello_screen.dart';
import 'games/chess/chess_screen.dart';
import 'games/janggi/janggi_screen.dart';
import 'games/solitaire/solitaire_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const GameCenterApp());
}

class GameCenterApp extends StatelessWidget {
  const GameCenterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Center',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _showGomokuModeDialog(BuildContext context) async {
    // 저장된 게임이 있는지 확인
    final hasSaved = await GomokuScreen.hasSavedGame();
    final savedMode = hasSaved ? await GomokuScreen.getSavedGameMode() : null;
    final savedDifficulty = hasSaved ? await GomokuScreen.getSavedDifficulty() : null;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.amber.withValues(alpha: 0.5), width: 2),
          ),
          title: const Text(
            '게임 대상 선택',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 이어하기 버튼 (저장된 게임이 있을 때만)
                if (hasSaved && savedMode != null) ...[
                  _buildGomokuResumeButton(context, savedMode, savedDifficulty ?? Difficulty.medium),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade700),
                  const SizedBox(height: 8),
                  Text(
                    '새 게임',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _buildModeButton(
                  context,
                  title: '컴퓨터 (백)',
                  subtitle: '내가 흑돌 (선공)',
                  icon: Icons.computer,
                  mode: GameMode.vsComputerWhite,
                ),
                const SizedBox(height: 12),
                _buildModeButton(
                  context,
                  title: '컴퓨터 (흑)',
                  subtitle: '내가 백돌 (후공)',
                  icon: Icons.computer,
                  mode: GameMode.vsComputerBlack,
                ),
                const SizedBox(height: 12),
                _buildModeButton(
                  context,
                  title: '사람',
                  subtitle: '2인 플레이',
                  icon: Icons.people,
                  mode: GameMode.vsPerson,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGomokuResumeButton(BuildContext context, GameMode savedMode, Difficulty savedDifficulty) {
    String modeText;
    switch (savedMode) {
      case GameMode.vsComputerWhite:
        modeText = 'vs 컴퓨터(백)';
        break;
      case GameMode.vsComputerBlack:
        modeText = 'vs 컴퓨터(흑)';
        break;
      case GameMode.vsPerson:
        modeText = '2인 플레이';
        break;
    }

    String difficultyText = '';
    if (savedMode != GameMode.vsPerson) {
      switch (savedDifficulty) {
        case Difficulty.easy:
          difficultyText = ' - 쉬움';
          break;
        case Difficulty.medium:
          difficultyText = ' - 보통';
          break;
        case Difficulty.hard:
          difficultyText = ' - 어려움';
          break;
      }
    }

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GomokuScreen(
              gameMode: savedMode,
              difficulty: savedDifficulty,
              resumeGame: true,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_arrow, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이어하기',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$modeText$difficultyText',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.green.withValues(alpha: 0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required GameMode mode,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // 다이얼로그 닫기
        if (mode == GameMode.vsPerson) {
          // 2인 플레이는 난이도 선택 없이 바로 시작
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GomokuScreen(gameMode: mode),
            ),
          );
        } else {
          // 컴퓨터 대전은 난이도 선택
          _showDifficultyDialog(context, mode);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.amber.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.amber, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.amber.withValues(alpha: 0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // 오목 난이도 선택 다이얼로그
  void _showDifficultyDialog(BuildContext context, GameMode mode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.amber.withValues(alpha: 0.5), width: 2),
          ),
          title: const Text(
            '난이도 선택',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDifficultyButton(
                context,
                title: '쉬움',
                subtitle: '초보자용',
                icon: Icons.sentiment_satisfied,
                color: Colors.green,
                mode: mode,
                difficulty: Difficulty.easy,
              ),
              const SizedBox(height: 12),
              _buildDifficultyButton(
                context,
                title: '보통',
                subtitle: '일반 플레이어용',
                icon: Icons.sentiment_neutral,
                color: Colors.orange,
                mode: mode,
                difficulty: Difficulty.medium,
              ),
              const SizedBox(height: 12),
              _buildDifficultyButton(
                context,
                title: '어려움',
                subtitle: '고수용',
                icon: Icons.sentiment_very_dissatisfied,
                color: Colors.red,
                mode: mode,
                difficulty: Difficulty.hard,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDifficultyButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required GameMode mode,
    required Difficulty difficulty,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GomokuScreen(
              gameMode: mode,
              difficulty: difficulty,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: color.withValues(alpha: 0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // 오델로 게임 대상 선택 다이얼로그
  Future<void> _showOthelloModeDialog(BuildContext context) async {
    final hasSaved = await OthelloScreen.hasSavedGame();
    final savedMode = hasSaved ? await OthelloScreen.getSavedGameMode() : null;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.green.withValues(alpha: 0.5), width: 2),
          ),
          title: const Text(
            '게임 대상 선택',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasSaved && savedMode != null) ...[
                _buildOthelloResumeButton(context, savedMode),
                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade700),
                const SizedBox(height: 8),
                Text(
                  '새 게임',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _buildOthelloModeButton(
                context,
                title: '컴퓨터 (백)',
                subtitle: '내가 흑 (선공)',
                icon: Icons.computer,
                mode: OthelloGameMode.vsComputerWhite,
              ),
              const SizedBox(height: 12),
              _buildOthelloModeButton(
                context,
                title: '컴퓨터 (흑)',
                subtitle: '내가 백 (후공)',
                icon: Icons.computer,
                mode: OthelloGameMode.vsComputerBlack,
              ),
              const SizedBox(height: 12),
              _buildOthelloModeButton(
                context,
                title: '사람',
                subtitle: '2인 플레이',
                icon: Icons.people,
                mode: OthelloGameMode.vsPerson,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOthelloResumeButton(BuildContext context, OthelloGameMode savedMode) {
    String modeText;
    switch (savedMode) {
      case OthelloGameMode.vsComputerWhite:
        modeText = 'vs 컴퓨터(백)';
        break;
      case OthelloGameMode.vsComputerBlack:
        modeText = 'vs 컴퓨터(흑)';
        break;
      case OthelloGameMode.vsPerson:
        modeText = '2인 플레이';
        break;
    }

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OthelloScreen(
              gameMode: savedMode,
              resumeGame: true,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.teal.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_arrow, color: Colors.teal, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이어하기',
                  style: TextStyle(
                    color: Colors.teal,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  modeText,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.teal.withValues(alpha: 0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOthelloModeButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required OthelloGameMode mode,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OthelloScreen(gameMode: mode),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.green.withValues(alpha: 0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // 체스 게임 대상 선택 다이얼로그
  Future<void> _showChessModeDialog(BuildContext context) async {
    final hasSaved = await ChessScreen.hasSavedGame();
    final savedMode = hasSaved ? await ChessScreen.getSavedGameMode() : null;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.brown.withValues(alpha: 0.5), width: 2),
          ),
          title: const Text(
            '게임 대상 선택',
            style: TextStyle(
              color: Colors.brown,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasSaved && savedMode != null) ...[
                _buildChessResumeButton(context, savedMode),
                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade700),
                const SizedBox(height: 8),
                Text(
                  '새 게임',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _buildChessModeButton(
                context,
                title: '컴퓨터 (흑)',
                subtitle: '내가 백 (선공)',
                icon: Icons.computer,
                mode: ChessGameMode.vsComputerWhite,
              ),
              const SizedBox(height: 12),
              _buildChessModeButton(
                context,
                title: '컴퓨터 (백)',
                subtitle: '내가 흑 (후공)',
                icon: Icons.computer,
                mode: ChessGameMode.vsComputerBlack,
              ),
              const SizedBox(height: 12),
              _buildChessModeButton(
                context,
                title: '사람',
                subtitle: '2인 플레이',
                icon: Icons.people,
                mode: ChessGameMode.vsPerson,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChessResumeButton(BuildContext context, ChessGameMode savedMode) {
    String modeText;
    switch (savedMode) {
      case ChessGameMode.vsComputerWhite:
        modeText = 'vs 컴퓨터(흑)';
        break;
      case ChessGameMode.vsComputerBlack:
        modeText = 'vs 컴퓨터(백)';
        break;
      case ChessGameMode.vsPerson:
        modeText = '2인 플레이';
        break;
    }

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChessScreen(
              gameMode: savedMode,
              resumeGame: true,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_arrow, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이어하기',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  modeText,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.orange.withValues(alpha: 0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChessModeButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required ChessGameMode mode,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChessScreen(gameMode: mode),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.brown.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.brown.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.brown.shade300, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.brown.withValues(alpha: 0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // 장기 게임 이어하기 확인 다이얼로그
  Future<void> _showJanggiContinueDialog(BuildContext context) async {
    final hasSaved = await JanggiScreen.hasSavedGame();

    if (!context.mounted) return;

    if (hasSaved) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.grey.shade900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: const Color(0xFFD2691E).withValues(alpha: 0.5), width: 2),
            ),
            title: const Text(
              '저장된 게임',
              style: TextStyle(
                color: Color(0xFFD2691E),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            content: const Text(
              '이전에 플레이하던 게임이 있습니다.\n이어서 하시겠습니까?',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  JanggiScreen.clearSavedGame();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JanggiScreen(gameMode: JanggiGameMode.vsHuman),
                    ),
                  );
                },
                child: const Text(
                  '새 게임',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD2691E),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const JanggiScreen(
                        gameMode: JanggiGameMode.vsHuman,
                        resumeGame: true,
                      ),
                    ),
                  );
                },
                child: const Text('이어하기'),
              ),
            ],
          );
        },
      );
    } else {
      // 저장된 게임이 없으면 바로 새 게임 시작
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const JanggiScreen(gameMode: JanggiGameMode.vsHuman),
        ),
      );
    }
  }

  // 장기 게임 대상 선택 다이얼로그
  void _showJanggiModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFFD2691E).withValues(alpha: 0.5), width: 2),
          ),
          title: const Text(
            '게임 대상 선택',
            style: TextStyle(
              color: Color(0xFFD2691E),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildJanggiModeButton(
                context,
                title: '컴퓨터 (한)',
                subtitle: '내가 초 (선공)',
                icon: Icons.computer,
                mode: JanggiGameMode.vsHan,
              ),
              const SizedBox(height: 12),
              _buildJanggiModeButton(
                context,
                title: '컴퓨터 (초)',
                subtitle: '내가 한 (후공)',
                icon: Icons.computer,
                mode: JanggiGameMode.vsCho,
              ),
              const SizedBox(height: 12),
              _buildJanggiModeButton(
                context,
                title: '사람',
                subtitle: '2인 플레이',
                icon: Icons.people,
                mode: JanggiGameMode.vsHuman,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJanggiModeButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required JanggiGameMode mode,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JanggiScreen(gameMode: mode),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFD2691E).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFD2691E).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFD2691E), size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: const Color(0xFFD2691E).withValues(alpha: 0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade900,
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'GAME CENTER',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 4,
                  shadows: [
                    Shadow(
                      color: Colors.cyan,
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '게임을 선택하세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isLandscape = constraints.maxWidth > constraints.maxHeight;
                      final crossAxisCount = isLandscape ? 3 : 2;
                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.0,
                        children: [
                          _buildGameTile(
                            context,
                            title: 'TETRIS',
                            subtitle: '테트리스',
                            icon: Icons.grid_view_rounded,
                            color: Colors.cyan,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TetrisScreen(),
                              ),
                            ),
                          ),
                          _buildGameTile(
                            context,
                            title: 'OMOK',
                            subtitle: '오목',
                            icon: Icons.circle_outlined,
                            color: Colors.amber,
                            onTap: () => _showGomokuModeDialog(context),
                          ),
                          _buildGameTile(
                            context,
                            title: 'OTHELLO',
                            subtitle: '오델로',
                            icon: Icons.blur_circular,
                            color: Colors.green,
                            onTap: () => _showOthelloModeDialog(context),
                          ),
                          _buildGameTile(
                            context,
                            title: 'CHESS',
                            subtitle: '체스',
                            icon: Icons.castle,
                            color: Colors.brown,
                            onTap: () => _showChessModeDialog(context),
                          ),
                          _buildGameTile(
                            context,
                            title: 'JANGGI',
                            subtitle: '장기',
                            icon: Icons.apps,
                            color: const Color(0xFFD2691E),
                            onTap: () => _showJanggiContinueDialog(context),
                          ),
                          _buildGameTile(
                            context,
                            title: 'SOLITAIRE',
                            subtitle: '솔리테어',
                            icon: Icons.style,
                            color: Colors.green.shade700,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SolitaireScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'v1.0.0',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.3),
              color.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
