import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'games/tetris/tetris_screen.dart';
import 'games/gomoku/gomoku_screen.dart';
import 'games/othello/othello_screen.dart';
import 'games/chess/chess_screen.dart';
import 'games/janggi/janggi_screen.dart';
import 'games/solitaire/solitaire_screen.dart';
import 'games/minesweeper/minesweeper_screen.dart';
import 'games/baseball/baseball_screen.dart';
import 'games/onecard/onecard_screen.dart';
import 'games/yutnori/yutnori_screen.dart';
import 'games/hula/hula_screen.dart';
import 'games/sudoku/screens/game_screen.dart' as sudoku;
import 'games/sudoku/screens/samurai_game_screen.dart' as sudoku;
import 'games/sudoku/screens/killer_game_screen.dart' as sudoku;
import 'games/sudoku/models/game_state.dart' as sudoku;
import 'games/sudoku/models/samurai_game_state.dart' as sudoku;
import 'games/sudoku/models/killer_sudoku_generator.dart' as sudoku;
import 'games/sudoku/services/game_storage.dart' as sudoku;
import 'games/number_sums/screens/number_sums_game_screen.dart' as number_sums;
import 'games/number_sums/models/number_sums_generator.dart' as number_sums;
import 'games/number_sums/services/game_storage.dart' as number_sums;
import 'services/ad_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// 라우트 옵저버 (게임 화면에서 돌아올 때 배너 광고 상태 갱신용)
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // AdMob 초기화
  await AdService.initialize();
  AdService().loadRewardedAd();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
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
      navigatorObservers: [routeObserver],
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final AdService _adService = AdService();
  int _bannerAdKey = 0; // AdWidget 강제 리빌드용
  bool _bannerLoaded = false;

  @override
  void initState() {
    super.initState();
    // 스플래시 화면 제거 (1초 후)
    Future.delayed(const Duration(seconds: 1), () {
      FlutterNativeSplash.remove();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
    // 배너 광고 로드
    if (!_bannerLoaded) {
      _bannerLoaded = true;
      _loadBannerAd();
    }
  }

  void _loadBannerAd({bool forceReload = false}) {
    _adService.loadBannerAd(
      forceReload: forceReload,
      onLoaded: () {
        if (mounted) {
          setState(() {
            if (forceReload) _bannerAdKey++;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _adService.disposeBannerAd();
    super.dispose();
  }

  @override
  void didPopNext() {
    // 게임 화면에서 돌아올 때 배너 광고 강제 새로고침
    if (mounted) {
      _loadBannerAd(forceReload: true);
    }
  }

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
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
          content: SingleChildScrollView(
            child: Column(
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
    final savedDifficulty = hasSaved ? await OthelloScreen.getSavedDifficulty() : null;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasSaved && savedMode != null) ...[
                  _buildOthelloResumeButton(context, savedMode, savedDifficulty ?? OthelloDifficulty.medium),
                  const SizedBox(height: 12),
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
                const SizedBox(height: 8),
                _buildOthelloModeButton(
                  context,
                  title: '컴퓨터 (흑)',
                  subtitle: '내가 백 (후공)',
                  icon: Icons.computer,
                  mode: OthelloGameMode.vsComputerBlack,
                ),
                const SizedBox(height: 8),
                _buildOthelloModeButton(
                  context,
                  title: '사람',
                  subtitle: '2인 플레이',
                  icon: Icons.people,
                  mode: OthelloGameMode.vsPerson,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOthelloResumeButton(BuildContext context, OthelloGameMode savedMode, OthelloDifficulty savedDifficulty) {
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

    String difficultyText = '';
    if (savedMode != OthelloGameMode.vsPerson) {
      switch (savedDifficulty) {
        case OthelloDifficulty.easy:
          difficultyText = ' - 쉬움';
          break;
        case OthelloDifficulty.medium:
          difficultyText = ' - 보통';
          break;
        case OthelloDifficulty.hard:
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
            builder: (context) => OthelloScreen(
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
        if (mode == OthelloGameMode.vsPerson) {
          // 2인 플레이는 난이도 선택 없이 바로 시작
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OthelloScreen(gameMode: mode),
            ),
          );
        } else {
          // 컴퓨터 대전은 난이도 선택
          _showOthelloDifficultyDialog(context, mode);
        }
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

  // 오델로 난이도 선택 다이얼로그
  void _showOthelloDifficultyDialog(BuildContext context, OthelloGameMode mode) {
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
            '난이도 선택',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildOthelloDifficultyButton(
                  context,
                  title: '쉬움',
                  subtitle: '초보자용',
                  icon: Icons.sentiment_satisfied,
                  color: Colors.green,
                  mode: mode,
                  difficulty: OthelloDifficulty.easy,
                ),
                const SizedBox(height: 12),
                _buildOthelloDifficultyButton(
                  context,
                  title: '보통',
                  subtitle: '일반 플레이어용',
                  icon: Icons.sentiment_neutral,
                  color: Colors.orange,
                  mode: mode,
                  difficulty: OthelloDifficulty.medium,
                ),
                const SizedBox(height: 12),
                _buildOthelloDifficultyButton(
                  context,
                  title: '어려움',
                  subtitle: '고수용',
                  icon: Icons.sentiment_very_dissatisfied,
                  color: Colors.red,
                  mode: mode,
                  difficulty: OthelloDifficulty.hard,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOthelloDifficultyButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required OthelloGameMode mode,
    required OthelloDifficulty difficulty,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OthelloScreen(
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
          content: SingleChildScrollView(
            child: Column(
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
                const SizedBox(height: 8),
                _buildChessModeButton(
                  context,
                  title: '컴퓨터 (백)',
                  subtitle: '내가 흑 (후공)',
                  icon: Icons.computer,
                  mode: ChessGameMode.vsComputerBlack,
                ),
                const SizedBox(height: 8),
                _buildChessModeButton(
                  context,
                  title: '사람',
                  subtitle: '2인 플레이',
                  icon: Icons.people,
                  mode: ChessGameMode.vsPerson,
                ),
              ],
            ),
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
    final savedGameMode = hasSaved ? await JanggiScreen.getSavedGameMode() : null;
    final savedDifficulty = hasSaved ? await JanggiScreen.getSavedDifficulty() : null;

    if (!context.mounted) return;

    if (hasSaved && savedGameMode != null) {
      String modeText;
      switch (savedGameMode) {
        case JanggiGameMode.vsHan:
          modeText = '컴퓨터 (한)';
          break;
        case JanggiGameMode.vsCho:
          modeText = '컴퓨터 (초)';
          break;
        case JanggiGameMode.vsHuman:
          modeText = '2인 플레이';
          break;
      }

      String difficultyText = '';
      if (savedGameMode != JanggiGameMode.vsHuman && savedDifficulty != null) {
        switch (savedDifficulty) {
          case JanggiDifficulty.easy:
            difficultyText = ' - 쉬움';
            break;
          case JanggiDifficulty.normal:
            difficultyText = ' - 보통';
            break;
          case JanggiDifficulty.hard:
            difficultyText = ' - 어려움';
            break;
        }
      }

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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '이전에 플레이하던 게임이 있습니다.\n이어서 하시겠습니까?',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$modeText$difficultyText',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  JanggiScreen.clearSavedGame();
                  _showJanggiModeDialog(context);
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
                      builder: (context) => JanggiScreen(
                        gameMode: savedGameMode,
                        difficulty: savedDifficulty ?? JanggiDifficulty.normal,
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
      // 저장된 게임이 없으면 게임 모드 선택 다이얼로그 표시
      _showJanggiModeDialog(context);
    }
  }

  // 장기 게임 대상 선택 다이얼로그
  void _showJanggiModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
          content: SingleChildScrollView(
            child: Column(
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
        if (mode == JanggiGameMode.vsHuman) {
          // 2인 플레이는 난이도 선택 없이 바로 게임 시작
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JanggiScreen(gameMode: mode),
            ),
          );
        } else {
          // 컴퓨터 대전은 난이도 선택 다이얼로그 표시
          _showJanggiDifficultyDialog(context, mode);
        }
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

  // 장기 난이도 선택 다이얼로그
  void _showJanggiDifficultyDialog(BuildContext context, JanggiGameMode mode) {
    String modeText = mode == JanggiGameMode.vsHan ? '컴퓨터 (한)' : '컴퓨터 (초)';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFFD2691E).withValues(alpha: 0.5), width: 2),
          ),
          title: Text(
            '$modeText - 난이도 선택',
            style: const TextStyle(
              color: Color(0xFFD2691E),
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildJanggiDifficultyButton(context, mode: mode, difficulty: JanggiDifficulty.easy, title: '쉬움', icon: Icons.sentiment_satisfied, color: Colors.green),
              const SizedBox(height: 12),
              _buildJanggiDifficultyButton(context, mode: mode, difficulty: JanggiDifficulty.normal, title: '보통', icon: Icons.sentiment_neutral, color: Colors.orange),
              const SizedBox(height: 12),
              _buildJanggiDifficultyButton(context, mode: mode, difficulty: JanggiDifficulty.hard, title: '어려움', icon: Icons.sentiment_very_dissatisfied, color: Colors.red),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJanggiDifficultyButton(
    BuildContext context, {
    required JanggiGameMode mode,
    required JanggiDifficulty difficulty,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JanggiScreen(
              gameMode: mode,
              difficulty: difficulty,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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

  // 지뢰찾기 난이도 선택 다이얼로그
  Future<void> _showMinesweeperDifficultyDialog(BuildContext context) async {
    final hasSaved = await MinesweeperScreen.hasSavedGame();
    final savedDifficulty = hasSaved ? await MinesweeperScreen.getSavedDifficulty() : null;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.blueGrey.withValues(alpha: 0.5), width: 2),
          ),
          title: const Text(
            '난이도 선택',
            style: TextStyle(
              color: Colors.blueGrey,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasSaved && savedDifficulty != null) ...[
                  _buildMinesweeperResumeButton(context, savedDifficulty),
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
                _buildMinesweeperDifficultyButton(
                  context,
                  title: '초급',
                  subtitle: '9x9, 지뢰 10개',
                  icon: Icons.sentiment_satisfied,
                  color: Colors.green,
                  difficulty: MinesweeperDifficulty.easy,
                ),
                const SizedBox(height: 12),
                _buildMinesweeperDifficultyButton(
                  context,
                  title: '중급',
                  subtitle: '16x16, 지뢰 40개',
                  icon: Icons.sentiment_neutral,
                  color: Colors.orange,
                  difficulty: MinesweeperDifficulty.medium,
                ),
                const SizedBox(height: 12),
                _buildMinesweeperDifficultyButton(
                  context,
                  title: '고급',
                  subtitle: '24x16, 지뢰 75개',
                  icon: Icons.sentiment_very_dissatisfied,
                  color: Colors.red,
                  difficulty: MinesweeperDifficulty.hard,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMinesweeperResumeButton(BuildContext context, MinesweeperDifficulty savedDifficulty) {
    String difficultyText;
    switch (savedDifficulty) {
      case MinesweeperDifficulty.easy:
        difficultyText = '초급';
        break;
      case MinesweeperDifficulty.medium:
        difficultyText = '중급';
        break;
      case MinesweeperDifficulty.hard:
        difficultyText = '고급';
        break;
    }

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MinesweeperScreen(
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
                  difficultyText,
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

  Widget _buildMinesweeperDifficultyButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required MinesweeperDifficulty difficulty,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MinesweeperScreen(
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

  // 숫자 야구 난이도 선택 다이얼로그
  void _showBaseballDifficultyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.deepOrange.withValues(alpha: 0.5), width: 2),
          ),
          title: const Text(
            '난이도 선택',
            style: TextStyle(
              color: Colors.deepOrange,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBaseballDifficultyButton(
                  context,
                  title: '3자리',
                  subtitle: '초보자용 (쉬움)',
                  icon: Icons.looks_3,
                  color: Colors.green,
                  difficulty: BaseballDifficulty.easy,
                ),
                const SizedBox(height: 12),
                _buildBaseballDifficultyButton(
                  context,
                  title: '4자리',
                  subtitle: '고수용 (어려움)',
                  icon: Icons.looks_4,
                  color: Colors.red,
                  difficulty: BaseballDifficulty.hard,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBaseballDifficultyButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required BaseballDifficulty difficulty,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BaseballScreen(
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

  // 원카드 인원 선택 다이얼로그
  Future<void> _showOneCardModeDialog(BuildContext context) async {
    final hasSaved = await OneCardScreen.hasSavedGame();
    final savedPlayerCount = hasSaved ? await OneCardScreen.getSavedPlayerCount() : null;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.purple.withValues(alpha: 0.5), width: 2),
          ),
          title: const Text(
            '인원 선택',
            style: TextStyle(
              color: Colors.purple,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 이어하기 버튼 (저장된 게임이 있을 때만)
                if (hasSaved && savedPlayerCount != null) ...[
                  _buildOneCardResumeButton(context, savedPlayerCount),
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
                _buildOneCardPlayerCountButton(
                  context,
                  playerCount: 2,
                  subtitle: '1 vs 1',
                  icon: Icons.people,
                ),
                const SizedBox(height: 12),
                _buildOneCardPlayerCountButton(
                  context,
                  playerCount: 3,
                  subtitle: '1 vs 2',
                  icon: Icons.groups,
                ),
                const SizedBox(height: 12),
                _buildOneCardPlayerCountButton(
                  context,
                  playerCount: 4,
                  subtitle: '1 vs 3',
                  icon: Icons.groups,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOneCardResumeButton(BuildContext context, int savedPlayerCount) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OneCardScreen(
              playerCount: savedPlayerCount,
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
                  '${savedPlayerCount}인 게임',
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

  Widget _buildOneCardPlayerCountButton(
    BuildContext context, {
    required int playerCount,
    required String subtitle,
    required IconData icon,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OneCardScreen(playerCount: playerCount),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.purple.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.purple, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${playerCount}인',
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
              color: Colors.purple.withValues(alpha: 0.7),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // 윷놀이 인원 선택 다이얼로그
  Future<void> _showYutnoriModeDialog(BuildContext context) async {
    final hasSaved = await YutnoriScreen.hasSavedGame();
    final savedPlayerCount = hasSaved ? await YutnoriScreen.getSavedPlayerCount() : null;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            return AlertDialog(
              backgroundColor: Colors.grey.shade900,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 100 : 20,
                vertical: isLandscape ? 12 : 24,
              ),
              contentPadding: EdgeInsets.fromLTRB(20, isLandscape ? 8 : 16, 20, isLandscape ? 12 : 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: const Color(0xFFDEB887).withValues(alpha: 0.5), width: 2),
              ),
              title: Text(
                '인원 선택',
                style: TextStyle(
                  color: const Color(0xFFDEB887),
                  fontWeight: FontWeight.bold,
                  fontSize: isLandscape ? 16 : 20,
                ),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 이어하기 버튼 (저장된 게임이 있을 때만)
                  if (hasSaved && savedPlayerCount != null) ...[
                    _buildYutnoriResumeButton(context, savedPlayerCount, compact: isLandscape),
                    SizedBox(height: isLandscape ? 8 : 16),
                    Divider(color: Colors.grey.shade700, height: 1),
                    SizedBox(height: isLandscape ? 6 : 8),
                    Text(
                      '새 게임',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: isLandscape ? 10 : 12,
                      ),
                    ),
                    SizedBox(height: isLandscape ? 6 : 8),
                  ],
                  // 가로모드: 버튼들을 가로로 배치
                  if (isLandscape)
                    Row(
                      children: [
                        Expanded(child: _buildYutnoriPlayerCountButton(context, playerCount: 2, subtitle: '1 vs 1', icon: Icons.people, compact: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildYutnoriPlayerCountButton(context, playerCount: 3, subtitle: '1 vs 2', icon: Icons.groups, compact: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildYutnoriPlayerCountButton(context, playerCount: 4, subtitle: '1 vs 3', icon: Icons.groups, compact: true)),
                      ],
                    )
                  else ...[
                    _buildYutnoriPlayerCountButton(context, playerCount: 2, subtitle: '1 vs 1', icon: Icons.people),
                    const SizedBox(height: 12),
                    _buildYutnoriPlayerCountButton(context, playerCount: 3, subtitle: '1 vs 2', icon: Icons.groups),
                    const SizedBox(height: 12),
                    _buildYutnoriPlayerCountButton(context, playerCount: 4, subtitle: '1 vs 3', icon: Icons.groups),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildYutnoriResumeButton(BuildContext context, int savedPlayerCount, {bool compact = false}) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => YutnoriScreen(
              playerCount: savedPlayerCount,
              resumeGame: true,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(compact ? 8 : 12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 8 : 12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.play_arrow, color: Colors.green, size: compact ? 22 : 28),
            SizedBox(width: compact ? 8 : 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이어하기',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: compact ? 13 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${savedPlayerCount}인 게임',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: compact ? 10 : 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.green.withValues(alpha: 0.7),
              size: compact ? 12 : 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYutnoriPlayerCountButton(
    BuildContext context, {
    required int playerCount,
    required String subtitle,
    required IconData icon,
    bool compact = false,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => YutnoriScreen(playerCount: playerCount),
          ),
        );
      },
      borderRadius: BorderRadius.circular(compact ? 8 : 12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 8 : 12),
        decoration: BoxDecoration(
          color: const Color(0xFFDEB887).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
          border: Border.all(
            color: const Color(0xFFDEB887).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: compact
            // 컴팩트 모드: 세로 배치
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: const Color(0xFFDEB887), size: 22),
                  const SizedBox(height: 4),
                  Text(
                    '${playerCount}인',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 10,
                    ),
                  ),
                ],
              )
            // 일반 모드: 가로 배치
            : Row(
                children: [
                  Icon(icon, color: const Color(0xFFDEB887), size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${playerCount}인',
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
                    color: const Color(0xFFDEB887).withValues(alpha: 0.7),
                    size: 16,
                  ),
                ],
              ),
      ),
    );
  }

  // 훌라 인원 선택 다이얼로그
  Future<void> _showHulaModeDialog(BuildContext context) async {
    final hasSaved = await HulaScreen.hasSavedGame();
    final savedPlayerCount = hasSaved ? await HulaScreen.getSavedPlayerCount() : null;
    final savedDifficulty = hasSaved ? await HulaScreen.getSavedDifficulty() : null;

    if (!context.mounted) return;

    final parentContext = context;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            return AlertDialog(
              backgroundColor: Colors.grey.shade900,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 100 : 20,
                vertical: isLandscape ? 12 : 24,
              ),
              contentPadding: EdgeInsets.fromLTRB(20, isLandscape ? 8 : 16, 20, isLandscape ? 12 : 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.teal.withValues(alpha: 0.5), width: 2),
              ),
              title: Text(
                '인원 선택',
                style: TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                  fontSize: isLandscape ? 16 : 20,
                ),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 이어하기 버튼 (저장된 게임이 있을 때만)
                  if (hasSaved && savedPlayerCount != null) ...[
                    _buildHulaResumeButton(dialogContext, savedPlayerCount, savedDifficulty, compact: isLandscape),
                    SizedBox(height: isLandscape ? 8 : 16),
                    Divider(color: Colors.grey.shade700, height: 1),
                    SizedBox(height: isLandscape ? 6 : 8),
                    Text(
                      '새 게임',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: isLandscape ? 10 : 12,
                      ),
                    ),
                    SizedBox(height: isLandscape ? 6 : 8),
                  ],
                  // 가로모드: 버튼들을 가로로 배치
                  if (isLandscape)
                    Row(
                      children: [
                        Expanded(child: _buildHulaPlayerCountButton(parentContext, dialogContext: dialogContext, playerCount: 2, subtitle: '1 vs 1', icon: Icons.people, compact: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildHulaPlayerCountButton(parentContext, dialogContext: dialogContext, playerCount: 3, subtitle: '1 vs 2', icon: Icons.groups, compact: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildHulaPlayerCountButton(parentContext, dialogContext: dialogContext, playerCount: 4, subtitle: '1 vs 3', icon: Icons.groups, compact: true)),
                      ],
                    )
                  else ...[
                    _buildHulaPlayerCountButton(parentContext, dialogContext: dialogContext, playerCount: 2, subtitle: '1 vs 1', icon: Icons.people),
                    const SizedBox(height: 12),
                    _buildHulaPlayerCountButton(parentContext, dialogContext: dialogContext, playerCount: 3, subtitle: '1 vs 2', icon: Icons.groups),
                    const SizedBox(height: 12),
                    _buildHulaPlayerCountButton(parentContext, dialogContext: dialogContext, playerCount: 4, subtitle: '1 vs 3', icon: Icons.groups),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHulaResumeButton(BuildContext context, int savedPlayerCount, HulaDifficulty? savedDifficulty, {bool compact = false}) {
    String difficultyText = '';
    if (savedDifficulty != null) {
      switch (savedDifficulty) {
        case HulaDifficulty.easy:
          difficultyText = ' - 쉬움';
          break;
        case HulaDifficulty.medium:
          difficultyText = ' - 보통';
          break;
        case HulaDifficulty.hard:
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
            builder: (context) => HulaScreen(
              playerCount: savedPlayerCount,
              difficulty: savedDifficulty ?? HulaDifficulty.medium,
              resumeGame: true,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(compact ? 8 : 12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 8 : 12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.play_arrow, color: Colors.green, size: compact ? 22 : 28),
            SizedBox(width: compact ? 8 : 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이어하기',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: compact ? 13 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${savedPlayerCount}인 게임$difficultyText',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: compact ? 10 : 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.green.withValues(alpha: 0.7),
              size: compact ? 12 : 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHulaPlayerCountButton(
    BuildContext context, {
    required BuildContext dialogContext,
    required int playerCount,
    required String subtitle,
    required IconData icon,
    bool compact = false,
  }) {
    return InkWell(
      onTap: () async {
        Navigator.pop(dialogContext);
        await Future.delayed(const Duration(milliseconds: 100));
        if (context.mounted) {
          _showHulaDifficultyDialog(context, playerCount);
        }
      },
      borderRadius: BorderRadius.circular(compact ? 8 : 12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 8 : 12),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
          border: Border.all(
            color: Colors.teal.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: compact
            // 컴팩트 모드: 세로 배치
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.teal, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    '${playerCount}인',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 10,
                    ),
                  ),
                ],
              )
            // 일반 모드: 가로 배치
            : Row(
                children: [
                  Icon(icon, color: Colors.teal, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${playerCount}인',
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
                    color: Colors.teal.withValues(alpha: 0.7),
                    size: 16,
                  ),
                ],
              ),
      ),
    );
  }

  // 훌라 난이도 선택 다이얼로그
  void _showHulaDifficultyDialog(BuildContext context, int playerCount) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;

            return AlertDialog(
              backgroundColor: Colors.grey.shade900,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 100 : 20,
                vertical: isLandscape ? 20 : 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.teal.withValues(alpha: 0.5), width: 2),
              ),
              title: Text(
                '훌라 ${playerCount}인 - 난이도 선택',
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLandscape)
                    Row(
                      children: [
                        Expanded(child: _buildHulaDifficultyButton(context, playerCount: playerCount, difficulty: HulaDifficulty.easy, title: '쉬움', icon: Icons.sentiment_satisfied, color: Colors.green, compact: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildHulaDifficultyButton(context, playerCount: playerCount, difficulty: HulaDifficulty.medium, title: '보통', icon: Icons.sentiment_neutral, color: Colors.orange, compact: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildHulaDifficultyButton(context, playerCount: playerCount, difficulty: HulaDifficulty.hard, title: '어려움', icon: Icons.sentiment_very_dissatisfied, color: Colors.red, compact: true)),
                      ],
                    )
                  else ...[
                    _buildHulaDifficultyButton(context, playerCount: playerCount, difficulty: HulaDifficulty.easy, title: '쉬움', icon: Icons.sentiment_satisfied, color: Colors.green),
                    const SizedBox(height: 12),
                    _buildHulaDifficultyButton(context, playerCount: playerCount, difficulty: HulaDifficulty.medium, title: '보통', icon: Icons.sentiment_neutral, color: Colors.orange),
                    const SizedBox(height: 12),
                    _buildHulaDifficultyButton(context, playerCount: playerCount, difficulty: HulaDifficulty.hard, title: '어려움', icon: Icons.sentiment_very_dissatisfied, color: Colors.red),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHulaDifficultyButton(
    BuildContext context, {
    required int playerCount,
    required HulaDifficulty difficulty,
    required String title,
    required IconData icon,
    required Color color,
    bool compact = false,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HulaScreen(
              playerCount: playerCount,
              difficulty: difficulty,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(compact ? 8 : 12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 10 : 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: compact
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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

  // 스도쿠 게임 다이얼로그
  Future<void> _showSudokuModeDialog(BuildContext context) async {
    final hasSaved = await sudoku.GameStorage.hasRegularGame();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.blue.withValues(alpha: 0.5), width: 2),
          ),
          title: const Text(
            '스도쿠',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasSaved) ...[
                  _buildSudokuResumeButton(context, '일반 스도쿠', Colors.blue),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade700),
                  const SizedBox(height: 8),
                  Text('새 게임', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                _buildSudokuDifficultyButton(context, '쉬움', sudoku.Difficulty.easy, Colors.green),
                const SizedBox(height: 8),
                _buildSudokuDifficultyButton(context, '보통', sudoku.Difficulty.medium, Colors.orange),
                const SizedBox(height: 8),
                _buildSudokuDifficultyButton(context, '어려움', sudoku.Difficulty.hard, Colors.red),
                const SizedBox(height: 8),
                _buildSudokuDifficultyButton(context, '달인', sudoku.Difficulty.expert, Colors.purple),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSudokuResumeButton(BuildContext context, String title, Color color) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        final savedGame = await sudoku.GameStorage.loadRegularGame();
        if (savedGame != null && context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => sudoku.GameScreen(savedGameState: savedGame)));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.5), width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_arrow, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Text('이어하기', style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: Colors.green.withValues(alpha: 0.7), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSudokuDifficultyButton(BuildContext context, String label, sudoku.Difficulty difficulty, Color color) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => sudoku.GameScreen(initialDifficulty: difficulty)));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.play_arrow, color: color, size: 24),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.7), size: 16),
          ],
        ),
      ),
    );
  }

  // 사무라이 스도쿠 다이얼로그
  Future<void> _showSamuraiSudokuDialog(BuildContext context) async {
    final hasSaved = await sudoku.GameStorage.hasSamuraiGame();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.5), width: 2),
          ),
          title: const Text(
            '사무라이 스도쿠',
            style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasSaved) ...[
                  _buildSamuraiResumeButton(context),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade700),
                  const SizedBox(height: 8),
                  Text('새 게임', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                _buildSamuraiDifficultyButton(context, '쉬움', sudoku.SamuraiDifficulty.easy, Colors.green),
                const SizedBox(height: 8),
                _buildSamuraiDifficultyButton(context, '보통', sudoku.SamuraiDifficulty.medium, Colors.orange),
                const SizedBox(height: 8),
                _buildSamuraiDifficultyButton(context, '어려움', sudoku.SamuraiDifficulty.hard, Colors.red),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSamuraiResumeButton(BuildContext context) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        final savedGame = await sudoku.GameStorage.loadSamuraiGame();
        if (savedGame != null && context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => sudoku.SamuraiGameScreen(savedGameState: savedGame)));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.5), width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_arrow, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Text('이어하기', style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: Colors.green.withValues(alpha: 0.7), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSamuraiDifficultyButton(BuildContext context, String label, sudoku.SamuraiDifficulty difficulty, Color color) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => sudoku.SamuraiGameScreen(initialDifficulty: difficulty)));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.play_arrow, color: color, size: 24),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.7), size: 16),
          ],
        ),
      ),
    );
  }

  // 킬러 스도쿠 다이얼로그
  Future<void> _showKillerSudokuDialog(BuildContext context) async {
    final hasSaved = await sudoku.GameStorage.hasKillerGame();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.teal.shade700.withValues(alpha: 0.5), width: 2),
          ),
          title: Text(
            '킬러 스도쿠',
            style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasSaved) ...[
                  _buildKillerResumeButton(context),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade700),
                  const SizedBox(height: 8),
                  Text('새 게임', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                _buildKillerDifficultyButton(context, '쉬움', sudoku.KillerDifficulty.easy, Colors.green),
                const SizedBox(height: 8),
                _buildKillerDifficultyButton(context, '보통', sudoku.KillerDifficulty.medium, Colors.orange),
                const SizedBox(height: 8),
                _buildKillerDifficultyButton(context, '어려움', sudoku.KillerDifficulty.hard, Colors.red),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKillerResumeButton(BuildContext context) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        final savedGame = await sudoku.GameStorage.loadKillerGame();
        if (savedGame != null && context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => sudoku.KillerGameScreen(savedGameState: savedGame)));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.5), width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_arrow, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Text('이어하기', style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: Colors.green.withValues(alpha: 0.7), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildKillerDifficultyButton(BuildContext context, String label, sudoku.KillerDifficulty difficulty, Color color) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => sudoku.KillerGameScreen(initialDifficulty: difficulty)));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.play_arrow, color: color, size: 24),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.7), size: 16),
          ],
        ),
      ),
    );
  }

  // 넘버 썸즈 다이얼로그
  Future<void> _showNumberSumsDialog(BuildContext context) async {
    final hasSaved = await number_sums.GameStorage.hasNumberSumsGame();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.deepOrange.shade700.withValues(alpha: 0.5), width: 2),
          ),
          title: Text(
            '넘버 썸즈',
            style: TextStyle(color: Colors.deepOrange.shade700, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasSaved) ...[
                  _buildNumberSumsResumeButton(context),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade700),
                  const SizedBox(height: 8),
                  Text('새 게임', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                _buildNumberSumsDifficultyButton(context, '쉬움 (5x5)', number_sums.NumberSumsDifficulty.easy, Colors.green),
                const SizedBox(height: 8),
                _buildNumberSumsDifficultyButton(context, '보통 (6x6)', number_sums.NumberSumsDifficulty.medium, Colors.orange),
                const SizedBox(height: 8),
                _buildNumberSumsDifficultyButton(context, '어려움 (7x7)', number_sums.NumberSumsDifficulty.hard, Colors.red),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNumberSumsResumeButton(BuildContext context) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        final savedGame = await number_sums.GameStorage.loadNumberSumsGame();
        if (savedGame != null && context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => number_sums.NumberSumsGameScreen(savedGameState: savedGame)));
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.5), width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_arrow, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Text('이어하기', style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: Colors.green.withValues(alpha: 0.7), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberSumsDifficultyButton(BuildContext context, String label, number_sums.NumberSumsDifficulty difficulty, Color color) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => number_sums.NumberSumsGameScreen(initialDifficulty: difficulty)));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.play_arrow, color: color, size: 24),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color.withValues(alpha: 0.7), size: 16),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > constraints.maxHeight;
              return Column(
                children: [
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: isLandscape
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
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
                              Text(
                                '게임을 선택하세요 (길게 누르면 설명)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
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
                                '게임을 선택하세요 (길게 누르면 설명)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isLandscapeGrid = constraints.maxWidth > constraints.maxHeight;
                          final crossAxisCount = isLandscapeGrid ? 5 : 3;
                          // 배너 광고 공간을 고려하여 aspectRatio 조정
                          final aspectRatio = isLandscapeGrid ? 2.3 : 1.05;
                          return GridView.count(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 6,
                            childAspectRatio: aspectRatio,
                            padding: EdgeInsets.zero,
                            children: [
                              _buildGameTile(
                                context,
                                title: '테트리스',
                                subtitle: 'Tetris',
                                icon: Icons.grid_view_rounded,
                                color: Colors.cyan,
                                description: '떨어지는 블록을 회전하고 배치하여 가로줄을 완성하면 줄이 사라집니다. 블록이 천장에 닿으면 게임 오버!',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const TetrisScreen(),
                                  ),
                                ),
                              ),
                              _buildGameTile(
                                context,
                                title: '오목',
                                subtitle: 'Omok',
                                icon: Icons.circle_outlined,
                                color: Colors.amber,
                                description: '흑과 백이 번갈아 돌을 놓아 가로, 세로, 대각선으로 5개를 먼저 연속으로 놓으면 승리합니다.',
                                onTap: () => _showGomokuModeDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: '오델로',
                                subtitle: 'Othello',
                                icon: Icons.blur_circular,
                                color: Colors.green,
                                description: '상대 돌을 자신의 돌 사이에 끼워 뒤집어 더 많은 돌을 차지하면 승리합니다. 리버시라고도 불립니다.',
                                onTap: () => _showOthelloModeDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: '체스',
                                subtitle: 'Chess',
                                icon: Icons.castle,
                                color: Colors.brown,
                                description: '각 기물의 고유한 움직임을 활용하여 상대 킹을 체크메이트하면 승리하는 전략 게임입니다.',
                                onTap: () => _showChessModeDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: '장기',
                                subtitle: 'Janggi',
                                icon: Icons.apps,
                                color: const Color(0xFFD2691E),
                                description: '한국 전통 보드 게임으로, 상대방의 궁(왕)을 외통수로 잡으면 승리합니다.',
                                onTap: () => _showJanggiContinueDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: '솔리테어',
                                subtitle: 'Solitaire',
                                icon: Icons.style,
                                color: Colors.green.shade700,
                                description: '카드를 정렬하여 에이스부터 킹까지 무늬별로 쌓아 올리는 1인용 카드 게임입니다.',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SolitaireScreen(),
                                    ),
                                  );
                                },
                              ),
                              _buildGameTile(
                                context,
                                title: '지뢰찾기',
                                subtitle: 'Minesweeper',
                                icon: Icons.terrain,
                                color: Colors.blueGrey,
                                description: '숫자 힌트를 이용하여 지뢰를 피하면서 모든 안전한 칸을 찾아내는 퍼즐 게임입니다.',
                                onTap: () => _showMinesweeperDifficultyDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: '숫자야구',
                                subtitle: 'Number Baseball',
                                icon: Icons.sports_baseball,
                                color: Colors.deepOrange,
                                description: '스트라이크와 볼 힌트를 이용하여 상대방의 비밀 숫자 3자리를 맞추는 추리 게임입니다.',
                                onTap: () => _showBaseballDifficultyDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: '원카드',
                                subtitle: 'One Card',
                                icon: Icons.style,
                                color: Colors.purple,
                                description: '같은 숫자나 무늬의 카드를 내며, 먼저 모든 카드를 버리면 승리하는 카드 게임입니다.',
                                onTap: () => _showOneCardModeDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: '윷놀이',
                                subtitle: 'Yut Nori',
                                icon: Icons.casino,
                                color: const Color(0xFFDEB887),
                                description: '윷을 던져 나온 결과대로 말을 이동하여 먼저 모든 말을 골인시키면 승리하는 한국 전통 게임입니다.',
                                onTap: () => _showYutnoriModeDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: '훌라',
                                subtitle: 'Hula',
                                icon: Icons.style,
                                color: Colors.teal,
                                description: '같은 무늬 연속 3장(런) 또는 같은 숫자 3장(그룹)으로 멜드를 등록하고 카드를 버려 점수를 낮추는 게임입니다.',
                                onTap: () => _showHulaModeDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: '스도쿠',
                                subtitle: 'Sudoku',
                                icon: Icons.grid_3x3,
                                color: Colors.blue,
                                description: '9x9 격자에 1부터 9까지 숫자를 행, 열, 3x3 박스에 중복 없이 채우는 논리 퍼즐입니다.',
                                onTap: () => _showSudokuModeDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: '사무라이',
                                subtitle: 'Samurai',
                                icon: Icons.apps,
                                color: Colors.deepPurple,
                                description: '5개의 스도쿠 보드가 겹쳐진 확장 스도쿠입니다. 겹치는 영역의 숫자는 모든 보드에서 유효해야 합니다.',
                                onTap: () => _showSamuraiSudokuDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: '킬러 스도쿠',
                                subtitle: 'Killer',
                                icon: Icons.calculate,
                                color: Colors.teal.shade700,
                                description: '케이지(점선 영역) 안의 숫자 합이 지정된 값이 되어야 하는 조건이 추가된 스도쿠입니다.',
                                onTap: () => _showKillerSudokuDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: '넘버 썸즈',
                                subtitle: 'Number Sums',
                                icon: Icons.add_box,
                                color: Colors.deepOrange.shade700,
                                description: '각 행과 열의 합계 힌트를 이용하여 빈 칸에 숫자를 채우는 퍼즐 게임입니다.',
                                onTap: () => _showNumberSumsDialog(context),
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
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: _adService.isBannerLoaded && _adService.bannerAd != null
          ? Container(
              key: ValueKey('banner_$_bannerAdKey'),
              color: Colors.black,
              width: double.infinity,
              height: 100, // largeBanner 고정 높이
              alignment: Alignment.center,
              child: AdWidget(ad: _adService.bannerAd!),
            )
          : null,
    );
  }

  void _showGameDescription(BuildContext context, String title, String description, Color color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.5), width: 2),
        ),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          description,
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('확인', style: TextStyle(color: color)),
          ),
        ],
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
    String? description,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: description != null
          ? () => _showGameDescription(context, title, description, color)
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 120;
          return Container(
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
            child: isCompact
                // 가로모드: 아이콘과 텍스트를 가로로 배치
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 24,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: color,
                                letterSpacing: 1,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                // 세로모드: 아이콘+한글 가로배치, 영어 아래 배치
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                size: 20,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                title, // 한글 이름
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle, // 영어 이름
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}
