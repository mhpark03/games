import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:easy_localization/easy_localization.dart';
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

// 배너 표시/숨김을 위한 NavigatorObserver
class BannerNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (previousRoute != null) {
      bannerController.hide();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null && previousRoute.isFirst) {
      bannerController.show();
    }
  }
}

final bannerNavigatorObserver = BannerNavigatorObserver();

// 전역 배너 표시 상태 관리
class BannerController extends ChangeNotifier {
  static final BannerController _instance = BannerController._internal();
  factory BannerController() => _instance;
  BannerController._internal();

  bool _isVisible = true;
  bool get isVisible => _isVisible;

  void show() {
    if (!_isVisible) {
      _isVisible = true;
      notifyListeners();
    }
  }

  void hide() {
    if (_isVisible) {
      _isVisible = false;
      notifyListeners();
    }
  }
}

final bannerController = BannerController();

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 다국어 지원 초기화
  await EasyLocalization.ensureInitialized();

  // AdMob 초기화
  await AdService.initialize();
  AdService().loadRewardedAd();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 전체 화면 모드 (상태바 숨김)
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('ko'),
        Locale('en'),
        Locale('ja'),
        Locale('zh'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const GameCenterApp(),
    ),
  );
}

class GameCenterApp extends StatefulWidget {
  const GameCenterApp({super.key});

  @override
  State<GameCenterApp> createState() => _GameCenterAppState();
}

class _GameCenterAppState extends State<GameCenterApp> {
  final AdService _adService = AdService();
  bool _bannerLoaded = false;

  @override
  void initState() {
    super.initState();
    bannerController.addListener(_onBannerVisibilityChanged);
  }

  @override
  void dispose() {
    bannerController.removeListener(_onBannerVisibilityChanged);
    _adService.disposeBannerAd();
    super.dispose();
  }

  void _onBannerVisibilityChanged() {
    setState(() {});
  }

  void _loadBannerAd(double screenWidth) {
    if (_bannerLoaded) return;
    _bannerLoaded = true;
    _adService.loadBannerAd(
      screenWidth: screenWidth,
      onLoaded: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Center',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [bannerNavigatorObserver],
      // 다국어 지원
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        // 배너 로드 (첫 빌드 시)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadBannerAd(MediaQuery.of(context).size.width);
        });

        final mediaQuery = MediaQuery.of(context);
        final isPortrait = mediaQuery.orientation == Orientation.portrait;
        final bannerLoaded = _adService.isBannerLoaded && _adService.bannerAd != null;
        final showBanner = isPortrait && bannerController.isVisible && bannerLoaded;
        final bannerHeight = bannerLoaded ? _adService.bannerAd!.size.height.toDouble() : 0.0;
        // 시스템 네비게이션 바 높이 (edgeToEdge 모드에서도 정확한 위치)
        final bottomPadding = mediaQuery.viewPadding.bottom;

        return Stack(
          children: [
            // 메인 컨텐츠
            Positioned.fill(
              bottom: showBanner ? bannerHeight + bottomPadding : 0,
              child: child ?? const SizedBox(),
            ),
            // 배너 광고 (viewPadding.bottom 위에 배치)
            if (bannerLoaded && showBanner)
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomPadding,
                child: Container(
                  color: Colors.black,
                  height: bannerHeight,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: _adService.bannerAd!.size.width.toDouble(),
                    height: bannerHeight,
                    child: AdWidget(ad: _adService.bannerAd!),
                  ),
                ),
              ),
          ],
        );
      },
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 스플래시 화면 제거 (1초 후)
    Future.delayed(const Duration(seconds: 1), () {
      FlutterNativeSplash.remove();
    });
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
          title: Text(
            'dialog.selectMode'.tr(),
            style: const TextStyle(
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
                    'app.newGame'.tr(),
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _buildModeButton(
                  context,
                  title: 'vs.vsComputer'.tr() + ' (${'games.gomoku.white'.tr()})',
                  subtitle: 'vs.playAs'.tr(namedArgs: {'piece': 'games.gomoku.black'.tr()}),
                  icon: Icons.computer,
                  mode: GameMode.vsComputerWhite,
                ),
                const SizedBox(height: 12),
                _buildModeButton(
                  context,
                  title: 'vs.vsComputer'.tr() + ' (${'games.gomoku.black'.tr()})',
                  subtitle: 'vs.playAs'.tr(namedArgs: {'piece': 'games.gomoku.white'.tr()}),
                  icon: Icons.computer,
                  mode: GameMode.vsComputerBlack,
                ),
                const SizedBox(height: 12),
                _buildModeButton(
                  context,
                  title: 'vs.twoPlayer'.tr(),
                  subtitle: 'vs.twoPlayer'.tr(),
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
        modeText = '${'vs.vsComputer'.tr()}(${'games.gomoku.white'.tr()})';
        break;
      case GameMode.vsComputerBlack:
        modeText = '${'vs.vsComputer'.tr()}(${'games.gomoku.black'.tr()})';
        break;
      case GameMode.vsPerson:
        modeText = 'vs.twoPlayer'.tr();
        break;
    }

    String difficultyText = '';
    if (savedMode != GameMode.vsPerson) {
      switch (savedDifficulty) {
        case Difficulty.easy:
          difficultyText = ' - ${'common.easy'.tr()}';
          break;
        case Difficulty.medium:
          difficultyText = ' - ${'common.normal'.tr()}';
          break;
        case Difficulty.hard:
          difficultyText = ' - ${'common.hard'.tr()}';
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
                Text(
                  'app.continue'.tr(),
                  style: const TextStyle(
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
          title: Text(
            'dialog.selectDifficulty'.tr(),
            style: const TextStyle(
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
                  title: 'common.easy'.tr(),
                  subtitle: '',
                  icon: Icons.sentiment_satisfied,
                  color: Colors.green,
                  mode: mode,
                  difficulty: Difficulty.easy,
                ),
                const SizedBox(height: 12),
                _buildDifficultyButton(
                  context,
                  title: 'common.normal'.tr(),
                  subtitle: '',
                  icon: Icons.sentiment_neutral,
                  color: Colors.orange,
                  mode: mode,
                  difficulty: Difficulty.medium,
                ),
                const SizedBox(height: 12),
                _buildDifficultyButton(
                  context,
                  title: 'common.hard'.tr(),
                  subtitle: '',
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
          title: Text(
            'dialog.selectMode'.tr(),
            style: const TextStyle(
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
                    'app.newGame'.tr(),
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _buildOthelloModeButton(
                  context,
                  title: '${'vs.vsComputer'.tr()} (${'games.othello.white'.tr()})',
                  subtitle: 'vs.playAs'.tr(namedArgs: {'piece': 'games.othello.black'.tr()}),
                  icon: Icons.computer,
                  mode: OthelloGameMode.vsComputerWhite,
                ),
                const SizedBox(height: 8),
                _buildOthelloModeButton(
                  context,
                  title: '${'vs.vsComputer'.tr()} (${'games.othello.black'.tr()})',
                  subtitle: 'vs.playAs'.tr(namedArgs: {'piece': 'games.othello.white'.tr()}),
                  icon: Icons.computer,
                  mode: OthelloGameMode.vsComputerBlack,
                ),
                const SizedBox(height: 8),
                _buildOthelloModeButton(
                  context,
                  title: 'vs.twoPlayer'.tr(),
                  subtitle: 'vs.twoPlayer'.tr(),
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
        modeText = '${'vs.vsComputer'.tr()}(${'games.othello.white'.tr()})';
        break;
      case OthelloGameMode.vsComputerBlack:
        modeText = '${'vs.vsComputer'.tr()}(${'games.othello.black'.tr()})';
        break;
      case OthelloGameMode.vsPerson:
        modeText = 'vs.twoPlayer'.tr();
        break;
    }

    String difficultyText = '';
    if (savedMode != OthelloGameMode.vsPerson) {
      switch (savedDifficulty) {
        case OthelloDifficulty.easy:
          difficultyText = ' - ${'common.easy'.tr()}';
          break;
        case OthelloDifficulty.medium:
          difficultyText = ' - ${'common.normal'.tr()}';
          break;
        case OthelloDifficulty.hard:
          difficultyText = ' - ${'common.hard'.tr()}';
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
                Text(
                  'app.continue'.tr(),
                  style: const TextStyle(
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
          title: Text(
            'dialog.selectDifficulty'.tr(),
            style: const TextStyle(
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
                  title: 'common.easy'.tr(),
                  subtitle: '',
                  icon: Icons.sentiment_satisfied,
                  color: Colors.green,
                  mode: mode,
                  difficulty: OthelloDifficulty.easy,
                ),
                const SizedBox(height: 12),
                _buildOthelloDifficultyButton(
                  context,
                  title: 'common.normal'.tr(),
                  subtitle: '',
                  icon: Icons.sentiment_neutral,
                  color: Colors.orange,
                  mode: mode,
                  difficulty: OthelloDifficulty.medium,
                ),
                const SizedBox(height: 12),
                _buildOthelloDifficultyButton(
                  context,
                  title: 'common.hard'.tr(),
                  subtitle: '',
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
          title: Text(
            'dialog.selectMode'.tr(),
            style: const TextStyle(
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
                    'app.newGame'.tr(),
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _buildChessModeButton(
                  context,
                  title: '${'vs.vsComputer'.tr()} (${'games.chess.black'.tr()})',
                  subtitle: '${'vs.playAs'.tr(namedArgs: {'piece': 'games.chess.white'.tr()})} (${'vs.first'.tr()})',
                  icon: Icons.computer,
                  mode: ChessGameMode.vsComputerWhite,
                ),
                const SizedBox(height: 8),
                _buildChessModeButton(
                  context,
                  title: '${'vs.vsComputer'.tr()} (${'games.chess.white'.tr()})',
                  subtitle: '${'vs.playAs'.tr(namedArgs: {'piece': 'games.chess.black'.tr()})} (${'vs.second'.tr()})',
                  icon: Icons.computer,
                  mode: ChessGameMode.vsComputerBlack,
                ),
                const SizedBox(height: 8),
                _buildChessModeButton(
                  context,
                  title: 'vs.person'.tr(),
                  subtitle: 'vs.twoPlayer'.tr(),
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
        modeText = '${'vs.vsComputer'.tr()}(${'games.chess.black'.tr()})';
        break;
      case ChessGameMode.vsComputerBlack:
        modeText = '${'vs.vsComputer'.tr()}(${'games.chess.white'.tr()})';
        break;
      case ChessGameMode.vsPerson:
        modeText = 'vs.twoPlayer'.tr();
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
                Text(
                  'app.continue'.tr(),
                  style: const TextStyle(
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
          title: Text(
            'dialog.selectMode'.tr(),
            style: const TextStyle(
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
                  title: '${'vs.vsComputer'.tr()} (${'games.janggi.han'.tr()})',
                  subtitle: '${'vs.playAs'.tr(namedArgs: {'piece': 'games.janggi.cho'.tr()})} (${'vs.first'.tr()})',
                  icon: Icons.computer,
                  mode: JanggiGameMode.vsHan,
                ),
                const SizedBox(height: 12),
                _buildJanggiModeButton(
                  context,
                  title: '${'vs.vsComputer'.tr()} (${'games.janggi.cho'.tr()})',
                  subtitle: '${'vs.playAs'.tr(namedArgs: {'piece': 'games.janggi.han'.tr()})} (${'vs.second'.tr()})',
                  icon: Icons.computer,
                  mode: JanggiGameMode.vsCho,
                ),
                const SizedBox(height: 12),
                _buildJanggiModeButton(
                  context,
                  title: 'vs.person'.tr(),
                  subtitle: 'vs.twoPlayer'.tr(),
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
          title: Text(
            'dialog.selectDifficulty'.tr(),
            style: const TextStyle(
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
                    'app.newGame'.tr(),
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _buildMinesweeperDifficultyButton(
                  context,
                  title: 'common.easy'.tr(),
                  subtitle: '9x9, ${'games.minesweeper.mines'.tr()} 10',
                  icon: Icons.sentiment_satisfied,
                  color: Colors.green,
                  difficulty: MinesweeperDifficulty.easy,
                ),
                const SizedBox(height: 12),
                _buildMinesweeperDifficultyButton(
                  context,
                  title: 'common.normal'.tr(),
                  subtitle: '16x16, ${'games.minesweeper.mines'.tr()} 40',
                  icon: Icons.sentiment_neutral,
                  color: Colors.orange,
                  difficulty: MinesweeperDifficulty.medium,
                ),
                const SizedBox(height: 12),
                _buildMinesweeperDifficultyButton(
                  context,
                  title: 'common.hard'.tr(),
                  subtitle: '24x16, ${'games.minesweeper.mines'.tr()} 75',
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
        difficultyText = 'common.easy'.tr();
        break;
      case MinesweeperDifficulty.medium:
        difficultyText = 'common.normal'.tr();
        break;
      case MinesweeperDifficulty.hard:
        difficultyText = 'common.hard'.tr();
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
                Text(
                  'app.continue'.tr(),
                  style: const TextStyle(
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
          title: Text(
            'dialog.selectDifficulty'.tr(),
            style: const TextStyle(
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
                  title: '3 Digits',
                  subtitle: 'common.easy'.tr(),
                  icon: Icons.looks_3,
                  color: Colors.green,
                  difficulty: BaseballDifficulty.easy,
                ),
                const SizedBox(height: 12),
                _buildBaseballDifficultyButton(
                  context,
                  title: '4 Digits',
                  subtitle: 'common.hard'.tr(),
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
          title: Text(
            'dialog.selectPlayers'.tr(),
            style: const TextStyle(
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
                    'app.newGame'.tr(),
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
                Text(
                  'app.continue'.tr(),
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'common.playerCountGame'.tr(namedArgs: {'count': savedPlayerCount.toString()}),
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
                  'common.playerCount'.tr(namedArgs: {'count': playerCount.toString()}),
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
                'dialog.selectPlayers'.tr(),
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
                      'app.newGame'.tr(),
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
                  'app.continue'.tr(),
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: compact ? 13 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'common.playerCountGame'.tr(namedArgs: {'count': savedPlayerCount.toString()}),
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
                    'common.playerCount'.tr(namedArgs: {'count': playerCount.toString()}),
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
                        'common.playerCount'.tr(namedArgs: {'count': playerCount.toString()}),
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
                'dialog.selectPlayers'.tr(),
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
                      'app.newGame'.tr(),
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
          difficultyText = ' - ${'common.easy'.tr()}';
          break;
        case HulaDifficulty.medium:
          difficultyText = ' - ${'common.normal'.tr()}';
          break;
        case HulaDifficulty.hard:
          difficultyText = ' - ${'common.hard'.tr()}';
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
                  'app.continue'.tr(),
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: compact ? 13 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${'common.playerCountGame'.tr(namedArgs: {'count': savedPlayerCount.toString()})}$difficultyText',
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
                    'common.playerCount'.tr(namedArgs: {'count': playerCount.toString()}),
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
                        'common.playerCount'.tr(namedArgs: {'count': playerCount.toString()}),
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
                '${'games.hula.name'.tr()} ${'common.playerCount'.tr(namedArgs: {'count': playerCount.toString()})} - ${'dialog.selectDifficulty'.tr()}',
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
                        Expanded(child: _buildHulaDifficultyButton(context, playerCount: playerCount, difficulty: HulaDifficulty.easy, title: 'common.easy'.tr(), icon: Icons.sentiment_satisfied, color: Colors.green, compact: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildHulaDifficultyButton(context, playerCount: playerCount, difficulty: HulaDifficulty.medium, title: 'common.normal'.tr(), icon: Icons.sentiment_neutral, color: Colors.orange, compact: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildHulaDifficultyButton(context, playerCount: playerCount, difficulty: HulaDifficulty.hard, title: 'common.hard'.tr(), icon: Icons.sentiment_very_dissatisfied, color: Colors.red, compact: true)),
                      ],
                    )
                  else ...[
                    _buildHulaDifficultyButton(context, playerCount: playerCount, difficulty: HulaDifficulty.easy, title: 'common.easy'.tr(), icon: Icons.sentiment_satisfied, color: Colors.green),
                    const SizedBox(height: 12),
                    _buildHulaDifficultyButton(context, playerCount: playerCount, difficulty: HulaDifficulty.medium, title: 'common.normal'.tr(), icon: Icons.sentiment_neutral, color: Colors.orange),
                    const SizedBox(height: 12),
                    _buildHulaDifficultyButton(context, playerCount: playerCount, difficulty: HulaDifficulty.hard, title: 'common.hard'.tr(), icon: Icons.sentiment_very_dissatisfied, color: Colors.red),
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
                  _buildSudokuResumeButton(context, 'games.sudoku.classic'.tr(), Colors.blue),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade700),
                  const SizedBox(height: 8),
                  Text('app.newGame'.tr(), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                _buildSudokuDifficultyButton(context, 'common.easy'.tr(), sudoku.Difficulty.easy, Colors.green),
                const SizedBox(height: 8),
                _buildSudokuDifficultyButton(context, 'common.normal'.tr(), sudoku.Difficulty.medium, Colors.orange),
                const SizedBox(height: 8),
                _buildSudokuDifficultyButton(context, 'common.hard'.tr(), sudoku.Difficulty.hard, Colors.red),
                const SizedBox(height: 8),
                _buildSudokuDifficultyButton(context, 'common.expert'.tr(), sudoku.Difficulty.expert, Colors.purple),
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
            Text('app.continue'.tr(), style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
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
                  Text('app.newGame'.tr(), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                _buildSamuraiDifficultyButton(context, 'common.easy'.tr(), sudoku.SamuraiDifficulty.easy, Colors.green),
                const SizedBox(height: 8),
                _buildSamuraiDifficultyButton(context, 'common.normal'.tr(), sudoku.SamuraiDifficulty.medium, Colors.orange),
                const SizedBox(height: 8),
                _buildSamuraiDifficultyButton(context, 'common.hard'.tr(), sudoku.SamuraiDifficulty.hard, Colors.red),
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
            Text('app.continue'.tr(), style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
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
                  Text('app.newGame'.tr(), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                _buildKillerDifficultyButton(context, 'common.easy'.tr(), sudoku.KillerDifficulty.easy, Colors.green),
                const SizedBox(height: 8),
                _buildKillerDifficultyButton(context, 'common.normal'.tr(), sudoku.KillerDifficulty.medium, Colors.orange),
                const SizedBox(height: 8),
                _buildKillerDifficultyButton(context, 'common.hard'.tr(), sudoku.KillerDifficulty.hard, Colors.red),
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
            Text('app.continue'.tr(), style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
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
                  Text('app.newGame'.tr(), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                _buildNumberSumsDifficultyButton(context, '${'common.easy'.tr()} (5x5)', number_sums.NumberSumsDifficulty.easy, Colors.green),
                const SizedBox(height: 8),
                _buildNumberSumsDifficultyButton(context, '${'common.normal'.tr()} (6x6)', number_sums.NumberSumsDifficulty.medium, Colors.orange),
                const SizedBox(height: 8),
                _buildNumberSumsDifficultyButton(context, '${'common.hard'.tr()} (7x7)', number_sums.NumberSumsDifficulty.hard, Colors.red),
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
            Text('app.continue'.tr(), style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildExitButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: IconButton(
        icon: const Icon(Icons.power_settings_new, color: Colors.white),
        iconSize: 24,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        tooltip: '앱 종료',
        onPressed: () => _showExitDialog(context),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('app.exit'.tr()),
        content: Text('app.exitConfirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('app.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              SystemNavigator.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('app.exit'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: IconButton(
        icon: const Icon(Icons.language, color: Colors.white),
        iconSize: 24,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        tooltip: 'app.language'.tr(),
        onPressed: () => _showLanguageDialog(context),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('app.selectLanguage'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption(context, '한국어', const Locale('ko')),
              _buildLanguageOption(context, 'English', const Locale('en')),
              _buildLanguageOption(context, '日本語', const Locale('ja')),
              _buildLanguageOption(context, '简体中文', const Locale('zh')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('app.close'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, String label, Locale locale) {
    final isSelected = context.locale == locale;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected ? Colors.cyan : Colors.grey,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.cyan : null,
        ),
      ),
      onTap: () {
        context.setLocale(locale);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Container(
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'app.title'.tr(),
                                style: const TextStyle(
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
                                'app.subtitle'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildLanguageButton(context),
                                  _buildExitButton(context),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'app.title'.tr(),
                                      style: const TextStyle(
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
                                      'app.subtitle'.tr(),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildLanguageButton(context),
                                  _buildExitButton(context),
                                ],
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
                                title: 'games.tetris.name'.tr(),
                                subtitle: 'games.tetris.subtitle'.tr(),
                                icon: Icons.grid_view_rounded,
                                color: Colors.cyan,
                                description: 'games.tetris.description'.tr(),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const TetrisScreen(),
                                  ),
                                ),
                              ),
                              _buildGameTile(
                                context,
                                title: 'games.gomoku.name'.tr(),
                                subtitle: 'games.gomoku.subtitle'.tr(),
                                icon: Icons.circle_outlined,
                                color: Colors.amber,
                                description: 'games.gomoku.description'.tr(),
                                onTap: () => _showGomokuModeDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: 'games.othello.name'.tr(),
                                subtitle: 'games.othello.subtitle'.tr(),
                                icon: Icons.blur_circular,
                                color: Colors.green,
                                description: 'games.othello.description'.tr(),
                                onTap: () => _showOthelloModeDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: 'games.chess.name'.tr(),
                                subtitle: 'games.chess.subtitle'.tr(),
                                icon: Icons.castle,
                                color: Colors.brown,
                                description: 'games.chess.description'.tr(),
                                onTap: () => _showChessModeDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: 'games.janggi.name'.tr(),
                                subtitle: 'games.janggi.subtitle'.tr(),
                                icon: Icons.apps,
                                color: const Color(0xFFD2691E),
                                description: 'games.janggi.description'.tr(),
                                onTap: () => _showJanggiContinueDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: 'games.solitaire.name'.tr(),
                                subtitle: 'games.solitaire.subtitle'.tr(),
                                icon: Icons.style,
                                color: Colors.green.shade700,
                                description: 'games.solitaire.description'.tr(),
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
                                title: 'games.minesweeper.name'.tr(),
                                subtitle: 'games.minesweeper.subtitle'.tr(),
                                icon: Icons.terrain,
                                color: Colors.blueGrey,
                                description: 'games.minesweeper.description'.tr(),
                                onTap: () => _showMinesweeperDifficultyDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: 'games.baseball.name'.tr(),
                                subtitle: 'games.baseball.subtitle'.tr(),
                                icon: Icons.sports_baseball,
                                color: Colors.deepOrange,
                                description: 'games.baseball.description'.tr(),
                                onTap: () => _showBaseballDifficultyDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: 'games.onecard.name'.tr(),
                                subtitle: 'games.onecard.subtitle'.tr(),
                                icon: Icons.style,
                                color: Colors.purple,
                                description: 'games.onecard.description'.tr(),
                                onTap: () => _showOneCardModeDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: 'games.yutnori.name'.tr(),
                                subtitle: 'games.yutnori.subtitle'.tr(),
                                icon: Icons.casino,
                                color: const Color(0xFFDEB887),
                                description: 'games.yutnori.description'.tr(),
                                onTap: () => _showYutnoriModeDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: 'games.hula.name'.tr(),
                                subtitle: 'games.hula.subtitle'.tr(),
                                icon: Icons.style,
                                color: Colors.teal,
                                description: 'games.hula.description'.tr(),
                                onTap: () => _showHulaModeDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: 'games.sudoku.name'.tr(),
                                subtitle: 'games.sudoku.subtitle'.tr(),
                                icon: Icons.grid_3x3,
                                color: Colors.blue,
                                description: 'games.sudoku.description'.tr(),
                                onTap: () => _showSudokuModeDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: 'games.sudoku.samurai'.tr(),
                                subtitle: 'Samurai',
                                icon: Icons.apps,
                                color: Colors.deepPurple,
                                description: 'games.sudoku.description'.tr(),
                                onTap: () => _showSamuraiSudokuDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: 'games.sudoku.killer'.tr(),
                                subtitle: 'Killer',
                                icon: Icons.calculate,
                                color: Colors.teal.shade700,
                                description: 'games.sudoku.description'.tr(),
                                onTap: () => _showKillerSudokuDialog(context),
                              ),
                              _buildGameTile(
                                context,
                                title: 'games.numberSums.name'.tr(),
                                subtitle: 'games.numberSums.subtitle'.tr(),
                                icon: Icons.add_box,
                                color: Colors.deepOrange.shade700,
                                description: 'games.numberSums.description'.tr(),
                                onTap: () => _showNumberSumsDialog(context),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
            ),
          ),
        ],
      ),
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
