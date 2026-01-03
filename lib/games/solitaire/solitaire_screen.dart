import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:math';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/game_save_service.dart';
import '../../services/ad_service.dart';

enum Suit { hearts, diamonds, clubs, spades }

enum CardColor { red, black }

class PlayingCard {
  final int rank; // 1=Ace, 11=Jack, 12=Queen, 13=King
  final Suit suit;
  bool faceUp;

  PlayingCard(this.rank, this.suit, {this.faceUp = false});

  // JSON 직렬화
  Map<String, dynamic> toJson() => {
    'rank': rank,
    'suit': suit.index,
    'faceUp': faceUp,
  };

  factory PlayingCard.fromJson(Map<String, dynamic> json) {
    return PlayingCard(
      json['rank'] as int,
      Suit.values[json['suit'] as int],
      faceUp: json['faceUp'] as bool,
    );
  }

  CardColor get color =>
      (suit == Suit.hearts || suit == Suit.diamonds) ? CardColor.red : CardColor.black;

  String get rankString {
    switch (rank) {
      case 1:
        return 'A';
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      default:
        return rank.toString();
    }
  }

  String get suitString {
    switch (suit) {
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
      case Suit.spades:
        return '♠';
    }
  }

  Color get suitColor => color == CardColor.red ? Colors.red : Colors.black;
}

class SolitaireScreen extends StatefulWidget {
  const SolitaireScreen({super.key});

  @override
  State<SolitaireScreen> createState() => _SolitaireScreenState();
}

class _SolitaireScreenState extends State<SolitaireScreen> {
  // 7개의 테이블 열
  late List<List<PlayingCard>> tableau;
  // 4개의 파운데이션 (Ace부터 King까지 쌓는 곳)
  late List<List<PlayingCard>> foundations;
  // 스톡 파일 (남은 카드)
  late List<PlayingCard> stock;
  // 웨이스트 파일 (스톡에서 뒤집은 카드)
  late List<PlayingCard> waste;

  // 드래그 상태
  List<PlayingCard>? draggedCards;
  String? dragSource; // 'tableau_0', 'waste', 'foundation_0' 등
  int? dragSourceIndex;

  int moves = 0;
  bool isGameWon = false;
  bool isLoading = true;

  // 카드 뽑기 수 (1장 또는 3장)
  int drawCount = 1;

  // 카드 크기 모드 (true: 크게, false: 작게)
  bool _largeCardMode = false;

  // 왼손잡이 모드 (true: 왼손잡이 - 카드 넘기기가 오른쪽)
  bool _leftHandedMode = false;

  // 화면 너비 저장 (동적 카드 크기 계산용)
  double _screenWidth = 0;

  // 카드 크기 (화면 너비와 모드에 따라 동적 계산) - 표준 카드 비율 5:7 (0.714)
  double get cardWidth {
    if (_screenWidth == 0) return _largeCardMode ? 56 : 50;
    // 7열 + 패딩(16) + 열간격(7*4=28) 고려하여 계산
    final baseWidth = (_screenWidth - 16 - 28) / 7;
    if (_largeCardMode) {
      return baseWidth.clamp(50.0, 62.0);  // 크게 모드: 50~62
    } else {
      return baseWidth.clamp(42.0, 50.0);  // 작게 모드: 42~50
    }
  }
  double get cardHeight => cardWidth * 1.4;  // 비율 5:7
  double get cardOverlap => _largeCardMode ? (cardWidth * 0.43) : (cardWidth * 0.4);  // 테이블 카드 겹침 간격

  // Undo 히스토리
  List<Map<String, dynamic>> _undoHistory = [];

  // 게임 타이머
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _loadCardSizeSetting();
    _checkSavedGame();
  }

  // 카드 크기 설정 불러오기
  Future<void> _loadCardSizeSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _largeCardMode = prefs.getBool('solitaire_large_card') ?? false;
      _leftHandedMode = prefs.getBool('solitaire_left_handed') ?? false;
    });
  }

  // 카드 크기 설정 저장
  Future<void> _saveCardSizeSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('solitaire_large_card', value);
  }

  // 왼손잡이 모드 설정 저장
  Future<void> _saveLeftHandedSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('solitaire_left_handed', value);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isGameWon && !_isPaused) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _checkSavedGame() async {
    final hasSave = await GameSaveService.hasSavedGame('solitaire');

    // 먼저 기본 초기화를 해서 late 변수 오류 방지
    _initGame();

    if (hasSave && mounted) {
      // 저장된 게임이 있으면 다이얼로그 표시
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showContinueDialog();
      });
    } else {
      // 새 게임: 카드 뽑기 모드 선택
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDrawModeDialog();
      });
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showDrawModeDialog() {
    showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.green.shade800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white30, width: 2),
          ),
          title: const Text(
            '게임 모드 선택',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            '스톡에서 카드를 몇 장씩 뽑으시겠습니까?',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade800,
                    ),
                    onPressed: () {
                      Navigator.pop(context, 1);
                    },
                    child: const Text('1장씩'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context, 3);
                    },
                    child: const Text('3장씩'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ).then((selectedCount) {
      if (selectedCount != null && mounted) {
        _startNewGame(selectedCount);
      }
    });
  }

  void _startNewGame(int count) {
    setState(() {
      drawCount = count;
      _initGame();
    });
    _saveGame();
  }

  void _showContinueDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.green.shade800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white30, width: 2),
          ),
          title: const Text(
            '저장된 게임',
            style: TextStyle(
              color: Colors.white,
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
                _clearSavedGame();
                // 새 게임 시 모드 선택 다이얼로그 표시
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _showDrawModeDialog();
                  }
                });
              },
              child: const Text(
                '새 게임',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade800,
              ),
              onPressed: () {
                Navigator.pop(context);
                _loadGame();
              },
              child: const Text('이어하기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveGame() async {
    if (isGameWon) return; // 승리한 게임은 저장하지 않음

    final gameState = {
      'tableau': tableau.map((col) => col.map((c) => c.toJson()).toList()).toList(),
      'foundations': foundations.map((col) => col.map((c) => c.toJson()).toList()).toList(),
      'stock': stock.map((c) => c.toJson()).toList(),
      'waste': waste.map((c) => c.toJson()).toList(),
      'moves': moves,
      'drawCount': drawCount,
      'elapsedSeconds': _elapsedSeconds,
    };

    await GameSaveService.saveGame('solitaire', gameState);
  }

  Future<void> _loadGame() async {
    final gameState = await GameSaveService.loadGame('solitaire');

    if (gameState != null) {
      try {
        setState(() {
          tableau = (gameState['tableau'] as List)
              .map((col) => (col as List)
                  .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
                  .toList())
              .toList();

          foundations = (gameState['foundations'] as List)
              .map((col) => (col as List)
                  .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
                  .toList())
              .toList();

          stock = (gameState['stock'] as List)
              .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
              .toList();

          waste = (gameState['waste'] as List)
              .map((c) => PlayingCard.fromJson(c as Map<String, dynamic>))
              .toList();

          moves = gameState['moves'] as int;
          drawCount = gameState['drawCount'] as int? ?? 1;
          _elapsedSeconds = gameState['elapsedSeconds'] as int? ?? 0;
          isGameWon = false;
          draggedCards = null;
          dragSource = null;
          dragSourceIndex = null;

          // 각 테이블 열의 맨 위 카드가 반드시 오픈되도록 보장
          for (var col in tableau) {
            if (col.isNotEmpty && !col.last.faceUp) {
              col.last.faceUp = true;
            }
          }
        });
        _startTimer();
      } catch (e) {
        _initGame();
      }
    } else {
      _initGame();
    }
  }

  Future<void> _clearSavedGame() async {
    await GameSaveService.clearSave();
  }

  void _initGame() {
    // 항상 풀 수 있는 게임 생성 (역방향 딜 방식)
    _generateSolvableGame();

    moves = 0;
    isGameWon = false;
    draggedCards = null;
    dragSource = null;
    dragSourceIndex = null;
    _undoHistory = [];
    _elapsedSeconds = 0;
    _startTimer();
  }

  // 역방향 딜로 항상 풀 수 있는 게임 생성
  void _generateSolvableGame() {
    final random = Random();

    // 1. 완성된 상태에서 시작 (모든 카드가 파운데이션에)
    List<List<PlayingCard>> solvedFoundations = [];
    for (var suit in Suit.values) {
      List<PlayingCard> pile = [];
      for (int rank = 1; rank <= 13; rank++) {
        pile.add(PlayingCard(rank, suit, faceUp: true));
      }
      solvedFoundations.add(pile);
    }

    // 2. 테이블과 스톡 초기화
    tableau = List.generate(7, (_) => []);
    foundations = List.generate(4, (_) => []);
    stock = [];
    waste = [];

    // 3. 역방향으로 카드를 이동하여 초기 상태 생성
    // 먼저 테이블에 필요한 카드 수 계산 (1+2+3+4+5+6+7 = 28장)
    List<PlayingCard> allCards = [];
    for (var pile in solvedFoundations) {
      allCards.addAll(pile);
    }
    allCards.shuffle(random);

    // 4. 테이블에 카드 배치 (유효한 시퀀스로)
    int cardIndex = 0;
    for (int col = 0; col < 7; col++) {
      for (int row = 0; row <= col; row++) {
        allCards[cardIndex].faceUp = (row == col); // 맨 위만 앞면
        tableau[col].add(allCards[cardIndex]);
        cardIndex++;
      }
    }

    // 5. 나머지 카드는 스톡으로
    for (int i = cardIndex; i < allCards.length; i++) {
      allCards[i].faceUp = false;
      stock.add(allCards[i]);
    }

    // 6. 테이블 맨 위 카드들을 유효한 시퀀스로 재배치
    _rearrangeTableauForSolvability(random);
  }

  // 테이블 카드 재배치로 풀이 가능성 보장
  void _rearrangeTableauForSolvability(Random random) {
    // 각 열의 맨 위 카드를 수집
    List<PlayingCard> topCards = [];
    for (int col = 0; col < 7; col++) {
      if (tableau[col].isNotEmpty) {
        topCards.add(tableau[col].removeLast());
      }
    }

    // 에이스가 접근 가능하도록 정렬 (낮은 숫자 우선)
    topCards.sort((a, b) => a.rank.compareTo(b.rank));

    // 색상이 번갈아 가도록 재배치
    List<PlayingCard> redCards = topCards.where((c) => c.color == CardColor.red).toList();
    List<PlayingCard> blackCards = topCards.where((c) => c.color == CardColor.black).toList();

    redCards.shuffle(random);
    blackCards.shuffle(random);

    // 번갈아 가며 배치
    List<PlayingCard> arranged = [];
    int ri = 0, bi = 0;
    bool useRed = random.nextBool();

    while (ri < redCards.length || bi < blackCards.length) {
      if (useRed && ri < redCards.length) {
        arranged.add(redCards[ri++]);
      } else if (!useRed && bi < blackCards.length) {
        arranged.add(blackCards[bi++]);
      } else if (ri < redCards.length) {
        arranged.add(redCards[ri++]);
      } else {
        arranged.add(blackCards[bi++]);
      }
      useRed = !useRed;
    }

    // 다시 테이블에 배치
    for (int col = 0; col < 7 && col < arranged.length; col++) {
      arranged[col].faceUp = true;
      tableau[col].add(arranged[col]);
    }

    // 스톡 셔플 (자연스러운 카드 배치)
    stock.shuffle(random);
  }

  // 현재 상태를 히스토리에 저장
  void _saveStateToHistory() {
    final state = {
      'tableau': tableau
          .map((col) => col.map((c) => PlayingCard(c.rank, c.suit, faceUp: c.faceUp)).toList())
          .toList(),
      'foundations': foundations
          .map((col) => col.map((c) => PlayingCard(c.rank, c.suit, faceUp: c.faceUp)).toList())
          .toList(),
      'stock': stock.map((c) => PlayingCard(c.rank, c.suit, faceUp: c.faceUp)).toList(),
      'waste': waste.map((c) => PlayingCard(c.rank, c.suit, faceUp: c.faceUp)).toList(),
      'moves': moves,
    };
    _undoHistory.add(state);
    // 최대 50개까지만 저장
    if (_undoHistory.length > 50) {
      _undoHistory.removeAt(0);
    }
  }

  // 되돌리기 광고 확인 다이얼로그
  void _showUndoAdDialog() {
    if (_undoHistory.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('되돌리기', style: TextStyle(color: Colors.white)),
        content: const Text(
          '광고를 시청하고 되돌리기를 사용하시겠습니까?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final adService = AdService();
              final result = await adService.showRewardedAd(
                onUserEarnedReward: (ad, reward) {
                  _undo();
                },
              );
              if (!result && mounted) {
                // 광고가 없어도 기능 실행
                _undo();
                adService.loadRewardedAd();
              }
            },
            child: const Text('광고 보기'),
          ),
        ],
      ),
    );
  }

  // Undo 실행
  void _undo() {
    if (_undoHistory.isEmpty) return;

    final state = _undoHistory.removeLast();
    setState(() {
      tableau = (state['tableau'] as List).map((col) => (col as List).cast<PlayingCard>()).toList();
      foundations = (state['foundations'] as List).map((col) => (col as List).cast<PlayingCard>()).toList();
      stock = (state['stock'] as List).cast<PlayingCard>();
      waste = (state['waste'] as List).cast<PlayingCard>();
      moves = state['moves'] as int;
    });
    _saveGame();
  }

  void _drawFromStock() {
    _saveStateToHistory();
    setState(() {
      if (stock.isEmpty) {
        // 스톡이 비면 웨이스트를 뒤집어서 스톡으로
        if (waste.isNotEmpty) {
          stock = waste.reversed.toList();
          for (var card in stock) {
            card.faceUp = false;
          }
          waste = [];
        }
      } else {
        // 스톡에서 drawCount장 뽑기
        int count = min(drawCount, stock.length);
        for (int i = 0; i < count; i++) {
          final card = stock.removeLast();
          card.faceUp = true;
          waste.add(card);
        }
        moves++;
      }
    });
    _saveGame();
  }

  bool _canPlaceOnTableau(PlayingCard card, int tableauIndex) {
    final pile = tableau[tableauIndex];
    if (pile.isEmpty) {
      // 빈 열에는 King만 놓을 수 있음
      return card.rank == 13;
    }
    final topCard = pile.last;
    // 색이 다르고, 랭크가 1 작아야 함
    return topCard.faceUp &&
        topCard.color != card.color &&
        topCard.rank == card.rank + 1;
  }

  bool _canPlaceOnFoundation(PlayingCard card, int foundationIndex) {
    final pile = foundations[foundationIndex];
    if (pile.isEmpty) {
      // 빈 파운데이션에는 Ace만 놓을 수 있음
      return card.rank == 1;
    }
    final topCard = pile.last;
    // 같은 수트이고, 랭크가 1 커야 함
    return topCard.suit == card.suit && topCard.rank == card.rank - 1;
  }

  void _checkWin() {
    // 모든 파운데이션에 13장씩 있으면 승리
    if (foundations.every((f) => f.length == 13)) {
      setState(() {
        isGameWon = true;
      });
      _clearSavedGame(); // 승리 시 저장된 게임 삭제
      _showWinDialog();
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.green.shade800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.amber, width: 3),
          ),
          title: const Column(
            children: [
              Text(
                '🎉',
                style: TextStyle(fontSize: 48),
              ),
              SizedBox(height: 8),
              Text(
                '축하합니다!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            '게임을 완료했습니다!\n총 $moves번 이동했습니다.',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _showDrawModeDialog();
                },
                child: const Text(
                  '새 게임',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 모든 테이블 카드가 열려있는지 확인 (자동 완료 가능 여부)
  bool _canAutoComplete() {
    // 테이블의 모든 카드가 앞면이어야 함
    for (var column in tableau) {
      for (var card in column) {
        if (!card.faceUp) return false;
      }
    }

    return true;
  }

  // 자동 완료 체크 및 실행
  void _checkAutoComplete() {
    if (!_canAutoComplete()) return;

    // 자동 완료 애니메이션 실행
    _runAutoComplete();
  }

  // 자동 완료 실행
  void _runAutoComplete() async {
    while (!isGameWon) {
      bool moved = false;

      // 1. 웨이스트에서 파운데이션으로 이동
      if (waste.isNotEmpty) {
        final card = waste.last;
        for (int f = 0; f < 4; f++) {
          if (_canPlaceOnFoundation(card, f)) {
            setState(() {
              waste.removeLast();
              foundations[f].add(card);
              moves++;
            });
            moved = true;
            await Future.delayed(const Duration(milliseconds: 100));
            _checkWin();
            break;
          }
        }
        if (moved) continue;
      }

      // 2. 스톡에서 웨이스트로 카드 뽑기
      if (stock.isNotEmpty && !moved) {
        setState(() {
          final card = stock.removeLast();
          card.faceUp = true;
          waste.add(card);
        });
        await Future.delayed(const Duration(milliseconds: 50));
        continue;
      }

      // 3. 테이블에서 파운데이션으로 이동
      for (int col = 0; col < 7; col++) {
        if (tableau[col].isEmpty) continue;

        final card = tableau[col].last;

        for (int f = 0; f < 4; f++) {
          if (_canPlaceOnFoundation(card, f)) {
            setState(() {
              tableau[col].removeLast();
              foundations[f].add(card);
              moves++;
            });
            moved = true;
            await Future.delayed(const Duration(milliseconds: 100));
            _checkWin();
            break;
          }
        }

        if (moved) break;
      }

      if (!moved) break; // 더 이상 이동할 카드가 없으면 종료
    }

    _saveGame();
  }

  void _onCardDragStart(List<PlayingCard> cards, String source, int? sourceIndex) {
    setState(() {
      draggedCards = cards;
      dragSource = source;
      dragSourceIndex = sourceIndex;
    });
  }

  void _onCardDragEnd() {
    setState(() {
      draggedCards = null;
      dragSource = null;
      dragSourceIndex = null;
    });
  }

  void _moveCards(String target, int? targetIndex) {
    if (draggedCards == null || dragSource == null) return;

    _saveStateToHistory();
    setState(() {
      bool moved = false;

      if (target.startsWith('tableau_') && targetIndex != null) {
        // 테이블로 이동
        if (_canPlaceOnTableau(draggedCards!.first, targetIndex)) {
          // 원래 위치에서 제거
          _removeCardsFromSource();
          // 새 위치에 추가
          tableau[targetIndex].addAll(draggedCards!);
          moved = true;
        }
      } else if (target.startsWith('foundation_') && targetIndex != null) {
        // 파운데이션으로 이동 (한 장만 가능)
        if (draggedCards!.length == 1 &&
            _canPlaceOnFoundation(draggedCards!.first, targetIndex)) {
          _removeCardsFromSource();
          foundations[targetIndex].add(draggedCards!.first);
          moved = true;
        }
      }

      if (moved) {
        moves++;
        // 테이블에서 카드를 옮겼으면 아래 카드 뒤집기
        if (dragSource!.startsWith('tableau_')) {
          final col = dragSourceIndex!;
          if (tableau[col].isNotEmpty && !tableau[col].last.faceUp) {
            tableau[col].last.faceUp = true;
          }
        }
        _checkWin();
        _saveGame();
      }

      _onCardDragEnd();
    });

    // 이동 후 자동 완료 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoComplete();
    });
  }

  void _removeCardsFromSource() {
    if (dragSource == 'waste') {
      waste.removeLast();
    } else if (dragSource!.startsWith('tableau_')) {
      final col = dragSourceIndex!;
      final startIndex = tableau[col].indexOf(draggedCards!.first);
      tableau[col].removeRange(startIndex, tableau[col].length);
    } else if (dragSource!.startsWith('foundation_')) {
      foundations[dragSourceIndex!].removeLast();
    }
  }

  void _autoMoveCard(PlayingCard card, String source, int? sourceIndex) {
    // 1순위: 파운데이션으로 이동 시도
    for (int i = 0; i < 4; i++) {
      if (_canPlaceOnFoundation(card, i)) {
        _saveStateToHistory();
        setState(() {
          if (source == 'waste') {
            waste.removeLast();
          } else if (source.startsWith('tableau_')) {
            tableau[sourceIndex!].removeLast();
            if (tableau[sourceIndex].isNotEmpty && !tableau[sourceIndex].last.faceUp) {
              tableau[sourceIndex].last.faceUp = true;
            }
          }
          foundations[i].add(card);
          moves++;
          _checkWin();
        });
        _saveGame();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAutoComplete();
        });
        return;
      }
    }

    // 2순위: 테이블로 이동 시도
    for (int i = 0; i < 7; i++) {
      // 같은 열로는 이동하지 않음
      if (source == 'tableau_$i') continue;

      if (_canPlaceOnTableau(card, i)) {
        _saveStateToHistory();
        setState(() {
          if (source == 'waste') {
            waste.removeLast();
          } else if (source.startsWith('tableau_')) {
            tableau[sourceIndex!].removeLast();
            if (tableau[sourceIndex].isNotEmpty && !tableau[sourceIndex].last.faceUp) {
              tableau[sourceIndex].last.faceUp = true;
            }
          }
          tableau[i].add(card);
          moves++;
        });
        _saveGame();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAutoComplete();
        });
        return;
      }
    }
  }

  // 여러 카드를 한번에 이동 (중간 카드 더블탭 시 사용)
  void _autoMoveCards(List<PlayingCard> cards, int sourceIndex) {
    if (cards.isEmpty) return;

    final firstCard = cards.first;

    // 테이블로 이동 시도 (여러 카드는 파운데이션으로 이동 불가)
    for (int i = 0; i < 7; i++) {
      // 같은 열로는 이동하지 않음
      if (i == sourceIndex) continue;

      if (_canPlaceOnTableau(firstCard, i)) {
        _saveStateToHistory();
        setState(() {
          // 원본 열에서 카드들 제거
          tableau[sourceIndex].removeRange(
            tableau[sourceIndex].length - cards.length,
            tableau[sourceIndex].length,
          );
          // 뒤집힌 카드 오픈
          if (tableau[sourceIndex].isNotEmpty && !tableau[sourceIndex].last.faceUp) {
            tableau[sourceIndex].last.faceUp = true;
          }
          // 새 열에 카드들 추가
          tableau[i].addAll(cards);
          moves++;
        });
        _saveGame();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAutoComplete();
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 화면 너비 저장 (동적 카드 크기 계산용)
    _screenWidth = MediaQuery.of(context).size.width;

    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.green.shade700,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            return _buildLandscapeLayout();
          } else {
            return _buildPortraitLayout();
          }
        },
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('솔리테어'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: '카드 설정',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showRulesDialog,
            tooltip: 'app.rules'.tr(),
          ),
          Opacity(
            opacity: _undoHistory.isNotEmpty ? 1.0 : 0.3,
            child: IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undoHistory.isEmpty ? null : _showUndoAdDialog,
              tooltip: 'common.undo'.tr(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _clearSavedGame();
              _showDrawModeDialog();
            },
            tooltip: '새 게임',
          ),
        ],
      ),
      backgroundColor: Colors.green.shade700,
      body: SafeArea(
        child: Column(
          children: [
            // 상태 바
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.green.shade800.withValues(alpha: 0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timer,
                        color: _isPaused ? Colors.amber : Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isPaused ? '일시정지' : _formatTime(_elapsedSeconds),
                        style: TextStyle(
                          color: _isPaused ? Colors.amber : Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _togglePause,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _isPaused ? Colors.amber.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            _isPaused ? Icons.play_arrow : Icons.pause,
                            color: _isPaused ? Colors.amber : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.swap_horiz, color: Colors.white70, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '이동: $moves',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.style, color: Colors.white70, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${drawCount}장',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildGameContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Scaffold(
      body: Container(
        color: Colors.green.shade700,
        child: SafeArea(
          child: Stack(
            children: [
              // 메인 게임 컨텐츠 - 가로 모드에서 너비 제한
              LayoutBuilder(
                builder: (context, constraints) {
                  // 화면 높이 기준으로 적절한 너비 계산 (카드 비율 유지)
                  final maxWidth = constraints.maxHeight * 1.4;
                  final actualWidth = min(constraints.maxWidth, maxWidth);
                  return Center(
                    child: SizedBox(
                      width: actualWidth,
                      child: _buildGameContent(),
                    ),
                  );
                },
              ),
              // 왼쪽 상단: 뒤로가기 버튼 + 제목 + 상태 정보
              Positioned(
                top: 4,
                left: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildCircleButton(
                          icon: Icons.arrow_back,
                          onPressed: () => Navigator.pop(context),
                          tooltip: '뒤로가기',
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '솔리테어',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 상태 정보 (제목 아래 세로 배치)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 카드 뽑기 모드
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${drawCount}장 모드',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // 시간 + 일시정지 버튼
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer,
                                size: 14,
                                color: _isPaused ? Colors.amber : Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _isPaused ? '일시정지' : _formatTime(_elapsedSeconds),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: _isPaused ? Colors.amber : Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _togglePause,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _isPaused ? Colors.amber.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    _isPaused ? Icons.play_arrow : Icons.pause,
                                    size: 16,
                                    color: _isPaused ? Colors.amber : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // 이동 횟수
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swap_horiz, size: 14, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(
                                '이동: $moves',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 오른쪽 상단: 설정 + 되돌리기 + 새 게임 버튼
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  children: [
                    _buildCircleButton(
                      icon: Icons.settings,
                      onPressed: _showSettingsDialog,
                      tooltip: '카드 설정',
                    ),
                    const SizedBox(width: 8),
                    _buildCircleButton(
                      icon: Icons.undo,
                      onPressed: _undoHistory.isEmpty ? null : _showUndoAdDialog,
                      tooltip: '되돌리기',
                    ),
                    const SizedBox(width: 8),
                    _buildCircleButton(
                      icon: Icons.refresh,
                      onPressed: () {
                        _clearSavedGame();
                        _showDrawModeDialog();
                      },
                      tooltip: '새 게임',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameContent() {
    // 스톡과 웨이스트 위젯
    final stockWasteWidgets = [
      _buildStock(),
      SizedBox(width: _largeCardMode ? 6 : 8),
      _buildWaste(),
    ];

    // 파운데이션 위젯들
    final foundationWidgets = List.generate(4, (index) {
      return Padding(
        padding: EdgeInsets.only(
          left: _leftHandedMode ? 0 : (_largeCardMode ? 4 : 6),
          right: _leftHandedMode ? (_largeCardMode ? 4 : 6) : 0,
        ),
        child: SizedBox(
          width: cardWidth + 4,
          height: cardHeight + 4,
          child: _buildFoundation(index),
        ),
      );
    });

    return Column(
      children: [
        // 상단: 스톡, 웨이스트, 파운데이션 (왼손잡이 모드에 따라 위치 변경)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: _leftHandedMode
                ? [
                    // 왼손잡이: 파운데이션 왼쪽, 스톡/웨이스트 오른쪽
                    ...foundationWidgets,
                    const Spacer(),
                    ...stockWasteWidgets,
                  ]
                : [
                    // 오른손잡이: 스톡/웨이스트 왼쪽, 파운데이션 오른쪽
                    ...stockWasteWidgets,
                    const Spacer(),
                    ...foundationWidgets,
                  ],
          ),
        ),
        // 하단: 테이블 7열
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(7, (index) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _buildTableauColumn(index),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    VoidCallback? onPressed,
    String? tooltip,
  }) {
    final isEnabled = onPressed != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.3,
      child: Material(
        color: Colors.black.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Tooltip(
            message: tooltip ?? '',
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Icon(
                icon,
                color: Colors.white70,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStock() {
    return GestureDetector(
      onTap: _drawFromStock,
      child: _buildCardPlaceholder(
        child: stock.isNotEmpty
            ? _buildCardBack()
            : const Icon(Icons.refresh, color: Colors.white54, size: 30),
      ),
    );
  }

  Widget _buildWaste() {
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) => false,
      builder: (context, candidateData, rejectedData) {
        if (waste.isEmpty) {
          return _buildCardPlaceholder();
        }

        // 3장 모드일 때 최대 3장까지 겹쳐서 표시
        if (drawCount == 3 && waste.length > 1) {
          // 표시할 카드 수 (최대 3장)
          final visibleCount = min(3, waste.length);
          final startIndex = waste.length - visibleCount;
          final topCard = waste.last;
          final wasteSpacing = _largeCardMode ? 16.0 : 15.0;

          return SizedBox(
            width: cardWidth + (visibleCount - 1) * wasteSpacing,
            height: cardHeight,
            child: Stack(
              children: List.generate(visibleCount, (i) {
                final cardIndex = startIndex + i;
                final card = waste[cardIndex];
                final isTop = i == visibleCount - 1;

                final cardWidget = _buildCard(card, width: cardWidth, height: cardHeight);

                if (isTop) {
                  // 맨 위 카드만 드래그 가능
                  return Positioned(
                    left: i * wasteSpacing,
                    child: Draggable<Map<String, dynamic>>(
                      data: {'cards': [topCard], 'source': 'waste', 'index': null},
                      feedback: _buildCard(topCard, width: cardWidth, height: cardHeight),
                      childWhenDragging: i > 0
                          ? _buildCard(waste[cardIndex - 1], width: cardWidth, height: cardHeight)
                          : SizedBox(width: cardWidth, height: cardHeight),
                      onDragStarted: () => _onCardDragStart([topCard], 'waste', null),
                      onDragEnd: (_) => _onCardDragEnd(),
                      child: GestureDetector(
                        onDoubleTap: () => _autoMoveCard(topCard, 'waste', null),
                        child: cardWidget,
                      ),
                    ),
                  );
                } else {
                  return Positioned(
                    left: i * wasteSpacing,
                    child: cardWidget,
                  );
                }
              }),
            ),
          );
        }

        // 1장 모드 또는 카드가 1장일 때
        final card = waste.last;
        return Draggable<Map<String, dynamic>>(
          data: {'cards': [card], 'source': 'waste', 'index': null},
          feedback: _buildCard(card, width: cardWidth, height: cardHeight),
          childWhenDragging: waste.length > 1
              ? _buildCard(waste[waste.length - 2], width: cardWidth, height: cardHeight)
              : _buildCardPlaceholder(),
          onDragStarted: () => _onCardDragStart([card], 'waste', null),
          onDragEnd: (_) => _onCardDragEnd(),
          child: GestureDetector(
            onDoubleTap: () => _autoMoveCard(card, 'waste', null),
            child: _buildCard(card, width: cardWidth, height: cardHeight),
          ),
        );
      },
    );
  }

  Widget _buildFoundation(int index) {
    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        final cards = data['cards'] as List<PlayingCard>;
        return cards.length == 1 && _canPlaceOnFoundation(cards.first, index);
      },
      onAcceptWithDetails: (details) {
        _moveCards('foundation_$index', index);
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        final pile = foundations[index];

        Widget cardWidget;
        if (pile.isEmpty) {
          cardWidget = _buildCardPlaceholder(
            child: Text(
              ['♠', '♥', '♣', '♦'][index],
              style: TextStyle(
                fontSize: cardWidth * 0.48,
                color: Colors.white.withAlpha(77),
              ),
            ),
          );
        } else {
          final card = pile.last;
          cardWidget = Draggable<Map<String, dynamic>>(
            data: {'cards': [card], 'source': 'foundation_$index', 'index': index},
            feedback: _buildCard(card, width: cardWidth, height: cardHeight),
            childWhenDragging: pile.length > 1
                ? _buildCard(pile[pile.length - 2], width: cardWidth, height: cardHeight)
                : _buildCardPlaceholder(
                    child: Text(
                      ['♠', '♥', '♣', '♦'][index],
                      style: TextStyle(
                        fontSize: cardWidth * 0.48,
                        color: Colors.white.withAlpha(77),
                      ),
                    ),
                  ),
            onDragStarted: () => _onCardDragStart([card], 'foundation_$index', index),
            onDragEnd: (_) => _onCardDragEnd(),
            child: _buildCard(card, width: cardWidth, height: cardHeight),
          );
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isHighlighted ? Colors.yellow : Colors.white30,
              width: isHighlighted ? 3 : 2,
            ),
          ),
          child: cardWidget,
        );
      },
    );
  }

  Widget _buildTableauColumn(int columnIndex) {
    final cards = tableau[columnIndex];

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        final dragCards = data['cards'] as List<PlayingCard>;
        return _canPlaceOnTableau(dragCards.first, columnIndex);
      },
      onAcceptWithDetails: (details) {
        _moveCards('tableau_$columnIndex', columnIndex);
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;

        if (cards.isEmpty) {
          // 드래그 타겟 인식 영역을 넓히기 위해 패딩 추가
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Container(
              height: cardHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isHighlighted ? Colors.yellow : Colors.white30,
                  width: isHighlighted ? 3 : 2,
                ),
              ),
              child: Center(
                child: Text(
                  'K',
                  style: TextStyle(
                    fontSize: cardWidth * 0.4,
                    color: Colors.white24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }

        // 드래그 타겟 인식 영역을 넓히기 위해 패딩 추가
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SingleChildScrollView(
            child: Column(
              children: List.generate(cards.length, (cardIndex) {
              final card = cards[cardIndex];
              final isLast = cardIndex == cards.length - 1;

              // 드래그 중인 카드인지 확인 (첫 번째 카드 제외 - Draggable이 관리)
              final isDragging = draggedCards != null &&
                  dragSource == 'tableau_$columnIndex' &&
                  draggedCards!.contains(card) &&
                  draggedCards!.first != card;  // 첫 번째 카드는 Draggable이 처리

              // 이 카드가 실질적으로 마지막 카드인지 확인
              // (실제 마지막이거나, 바로 다음 카드부터 드래그 중인 경우)
              final isEffectivelyLast = isLast ||
                  (draggedCards != null &&
                   dragSource == 'tableau_$columnIndex' &&
                   !draggedCards!.contains(card) &&
                   cardIndex + 1 < cards.length &&
                   draggedCards!.first == cards[cardIndex + 1]);

              // 앞면 카드는 드래그 가능
              if (card.faceUp) {
                // 이 카드부터 끝까지의 카드들
                final dragCards = cards.sublist(cardIndex);

                // 드래그 중인 카드는 숨김 (첫 번째 카드 제외)
                if (isDragging) {
                  return SizedBox(
                    height: isLast ? cardHeight : cardOverlap,
                  );
                }

                return Padding(
                  padding: EdgeInsets.only(top: cardIndex == 0 ? 0 : 0),
                  child: Draggable<Map<String, dynamic>>(
                    data: {
                      'cards': dragCards,
                      'source': 'tableau_$columnIndex',
                      'index': columnIndex,
                    },
                    feedback: Material(
                      color: Colors.transparent,
                      child: SizedBox(
                        width: cardWidth,
                        height: cardHeight + (dragCards.length - 1) * cardOverlap,
                        child: Stack(
                          children: dragCards
                              .asMap()
                              .entries
                              .map((entry) => Positioned(
                                    top: entry.key * cardOverlap,
                                    left: 0,
                                    child: _buildCard(entry.value,
                                        width: cardWidth, height: cardHeight),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                    childWhenDragging: SizedBox(
                      height: isLast ? cardHeight : cardOverlap,
                    ),
                    onDragStarted: () => _onCardDragStart(
                        dragCards, 'tableau_$columnIndex', columnIndex),
                    onDragEnd: (_) => _onCardDragEnd(),
                    child: GestureDetector(
                      onDoubleTap: () {
                        if (isLast) {
                          // 마지막 카드: 파운데이션 또는 테이블로 이동
                          _autoMoveCard(card, 'tableau_$columnIndex', columnIndex);
                        } else {
                          // 중간 카드: 이 카드부터 끝까지 테이블로 이동
                          _autoMoveCards(dragCards, columnIndex);
                        }
                      },
                      child: SizedBox(
                        height: isEffectivelyLast ? cardHeight : cardOverlap,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _buildCard(card,
                              width: double.infinity,
                              height: cardHeight,
                              showPartial: !isEffectivelyLast),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                // 뒷면 카드
                return SizedBox(
                  height: isEffectivelyLast ? cardHeight : cardOverlap,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _buildCardBack(
                        width: double.infinity,
                        height: cardHeight,
                        showPartial: !isEffectivelyLast),
                  ),
                );
              }
            }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardPlaceholder({Widget? child}) {
    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white30, width: 2),
      ),
      child: child != null ? Center(child: child) : null,
    );
  }

  Widget _buildCardBack({
    double width = 50,
    double height = 70,
    bool showPartial = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.blue.shade800,
        borderRadius: showPartial
            ? const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              )
            : BorderRadius.circular(6),
        border: showPartial
            ? const Border(
                top: BorderSide(color: Colors.white, width: 1),
                left: BorderSide(color: Colors.white, width: 1),
                right: BorderSide(color: Colors.white, width: 1),
              )
            : Border.all(color: Colors.white, width: 1),
        boxShadow: showPartial
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(51),
                  blurRadius: 2,
                  offset: const Offset(1, 1),
                ),
              ],
      ),
      child: showPartial
          ? null
          : Center(
              child: Container(
                width: width - 10,
                height: height - 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white24),
                ),
              ),
            ),
    );
  }

  Widget _buildCard(
    PlayingCard card, {
    double width = 50,
    double height = 70,
    bool showPartial = false,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: showPartial
            ? const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              )
            : BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade400),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: showPartial
          ? Padding(
              padding: const EdgeInsets.only(left: 3, top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.rankString,
                    style: TextStyle(
                      color: card.suitColor,
                      fontSize: _largeCardMode ? (cardWidth * 0.25) : (cardWidth * 0.22),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    card.suitString,
                    style: TextStyle(
                      color: card.suitColor,
                      fontSize: _largeCardMode ? (cardWidth * 0.22) : (cardWidth * 0.18),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : _largeCardMode
              ? _buildLargeCardContent(card)
              : _buildSmallCardContent(card),
    );
  }

  // 작은 카드 레이아웃 (기존)
  Widget _buildSmallCardContent(PlayingCard card) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        children: [
          // 상단: 랭크만 표시 (왼쪽 정렬)
          Align(
            alignment: Alignment.topLeft,
            child: Text(
              card.rankString,
              style: TextStyle(
                color: card.suitColor,
                fontSize: cardWidth * 0.2,  // 동적 글자 크기
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
          // 중앙 영역: 숫자에 맞는 무늬 배열
          Expanded(
            child: _buildPipPattern(card),
          ),
        ],
      ),
    );
  }

  // 큰 카드 레이아웃 (새로운)
  Widget _buildLargeCardContent(PlayingCard card) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Column(
        children: [
          // 상단: 숫자 + 무늬 (크게 표시)
          Align(
            alignment: Alignment.topLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  card.rankString,
                  style: TextStyle(
                    color: card.suitColor,
                    fontSize: cardWidth * 0.27,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                Text(
                  card.suitString,
                  style: TextStyle(
                    color: card.suitColor,
                    fontSize: cardWidth * 0.24,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          // 중앙: 큰 무늬 하나
          Expanded(
            child: Center(
              child: Text(
                card.suitString,
                style: TextStyle(
                  color: card.suitColor,
                  fontSize: cardWidth * 0.5,  // 동적 무늬 크기
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 카드 숫자에 맞는 무늬 패턴 생성
  Widget _buildPipPattern(PlayingCard card) {
    final suit = card.suitString;
    final color = card.suitColor;

    // 숫자에 따라 무늬 크기 조정 (많을수록 작게)
    double pipSize;
    if (card.rank <= 3) {
      pipSize = 12.0;
    } else if (card.rank <= 6) {
      pipSize = 10.0;
    } else if (card.rank <= 8) {
      pipSize = 9.0;
    } else {
      pipSize = 8.0; // 9, 10
    }

    // J, Q, K는 그림으로 표시
    if (card.rank >= 11 && card.rank <= 13) {
      IconData icon;
      if (card.rank == 11) {
        // Jack - 기사
        icon = Icons.security;
      } else if (card.rank == 12) {
        // Queen - 여왕
        icon = Icons.auto_awesome;
      } else {
        // King - 왕관
        icon = Icons.workspace_premium;
      }
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          Text(
            suit,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      );
    }

    // A는 큰 무늬 하나
    if (card.rank == 1) {
      return Center(
        child: Text(
          suit,
          style: TextStyle(color: color, fontSize: 20),
        ),
      );
    }

    // 2-10은 패턴으로 표시
    return LayoutBuilder(
      builder: (context, constraints) {
        final positions = _getPipPositions(card.rank, constraints.maxWidth, constraints.maxHeight, pipSize);
        return Stack(
          clipBehavior: Clip.none,
          children: positions.map((pos) {
            final isInverted = pos['inverted'] == true;
            return Positioned(
              left: pos['x'] as double,
              top: pos['y'] as double,
              child: isInverted
                  ? Transform.rotate(
                      angle: 3.14159,
                      child: Text(suit, style: TextStyle(color: color, fontSize: pipSize)),
                    )
                  : Text(suit, style: TextStyle(color: color, fontSize: pipSize)),
            );
          }).toList(),
        );
      },
    );
  }

  // 카드 숫자별 무늬 위치 계산
  List<Map<String, dynamic>> _getPipPositions(int rank, double width, double height, double pipSize) {
    final centerX = (width - pipSize) / 2;
    final leftX = width * 0.1;
    final rightX = width * 0.9 - pipSize;

    // 상하 여백을 두고 배치 (높이의 5%~85% 범위 내)
    final topY = height * 0.05;
    final midTopY = height * 0.25;
    final centerY = height * 0.40;
    final midBottomY = height * 0.55;
    final bottomY = height * 0.70;

    // 2, 3번 카드는 pipSize가 12로 크므로 높이의 60% 이내에 배치
    switch (rank) {
      case 2:
        // 2는 상하로 배치 (0%, 60%)
        return [
          {'x': centerX, 'y': 0.0, 'inverted': false},
          {'x': centerX, 'y': height * 0.55, 'inverted': true},
        ];
      case 3:
        // 3은 상중하 배치 (0%, 28%, 55%)
        return [
          {'x': centerX, 'y': 0.0, 'inverted': false},
          {'x': centerX, 'y': height * 0.28, 'inverted': false},
          {'x': centerX, 'y': height * 0.55, 'inverted': true},
        ];
      case 4:
        return [
          {'x': leftX, 'y': topY, 'inverted': false},
          {'x': rightX, 'y': topY, 'inverted': false},
          {'x': leftX, 'y': bottomY, 'inverted': true},
          {'x': rightX, 'y': bottomY, 'inverted': true},
        ];
      case 5:
        return [
          {'x': leftX, 'y': topY, 'inverted': false},
          {'x': rightX, 'y': topY, 'inverted': false},
          {'x': centerX, 'y': centerY, 'inverted': false},
          {'x': leftX, 'y': bottomY, 'inverted': true},
          {'x': rightX, 'y': bottomY, 'inverted': true},
        ];
      case 6:
        return [
          {'x': leftX, 'y': topY, 'inverted': false},
          {'x': rightX, 'y': topY, 'inverted': false},
          {'x': leftX, 'y': centerY, 'inverted': false},
          {'x': rightX, 'y': centerY, 'inverted': false},
          {'x': leftX, 'y': bottomY, 'inverted': true},
          {'x': rightX, 'y': bottomY, 'inverted': true},
        ];
      case 7:
        return [
          {'x': leftX, 'y': topY, 'inverted': false},
          {'x': rightX, 'y': topY, 'inverted': false},
          {'x': centerX, 'y': midTopY, 'inverted': false},
          {'x': leftX, 'y': centerY, 'inverted': false},
          {'x': rightX, 'y': centerY, 'inverted': false},
          {'x': leftX, 'y': bottomY, 'inverted': true},
          {'x': rightX, 'y': bottomY, 'inverted': true},
        ];
      case 8:
        return [
          {'x': leftX, 'y': topY, 'inverted': false},
          {'x': rightX, 'y': topY, 'inverted': false},
          {'x': centerX, 'y': midTopY, 'inverted': false},
          {'x': leftX, 'y': centerY, 'inverted': false},
          {'x': rightX, 'y': centerY, 'inverted': false},
          {'x': centerX, 'y': midBottomY, 'inverted': true},
          {'x': leftX, 'y': bottomY, 'inverted': true},
          {'x': rightX, 'y': bottomY, 'inverted': true},
        ];
      case 9:
        // 9는 4줄 + 중앙 1개 = 9개 (5% ~ 70% 범위)
        return [
          {'x': leftX, 'y': height * 0.05, 'inverted': false},
          {'x': rightX, 'y': height * 0.05, 'inverted': false},
          {'x': leftX, 'y': height * 0.22, 'inverted': false},
          {'x': rightX, 'y': height * 0.22, 'inverted': false},
          {'x': centerX, 'y': height * 0.38, 'inverted': false},
          {'x': leftX, 'y': height * 0.53, 'inverted': true},
          {'x': rightX, 'y': height * 0.53, 'inverted': true},
          {'x': leftX, 'y': height * 0.70, 'inverted': true},
          {'x': rightX, 'y': height * 0.70, 'inverted': true},
        ];
      case 10:
        // 10은 좌우 4줄 + 중앙 2개 = 10개 (5% ~ 70% 범위)
        return [
          // 1행
          {'x': leftX, 'y': height * 0.05, 'inverted': false},
          {'x': rightX, 'y': height * 0.05, 'inverted': false},
          // 중앙 상단
          {'x': centerX, 'y': height * 0.16, 'inverted': false},
          // 2행
          {'x': leftX, 'y': height * 0.27, 'inverted': false},
          {'x': rightX, 'y': height * 0.27, 'inverted': false},
          // 3행
          {'x': leftX, 'y': height * 0.48, 'inverted': true},
          {'x': rightX, 'y': height * 0.48, 'inverted': true},
          // 중앙 하단
          {'x': centerX, 'y': height * 0.59, 'inverted': true},
          // 4행
          {'x': leftX, 'y': height * 0.70, 'inverted': true},
          {'x': rightX, 'y': height * 0.70, 'inverted': true},
        ];
      default:
        return [];
    }
  }

  // 설정 다이얼로그
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '게임 설정',
            style: TextStyle(color: Colors.green.shade400),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 카드 글자 크기 설정
                const Text(
                  '카드 글자 크기',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setDialogState(() {});
                          setState(() {
                            _largeCardMode = false;
                          });
                          _saveCardSizeSetting(false);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: !_largeCardMode
                                ? Colors.green.shade700
                                : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: !_largeCardMode
                                  ? Colors.green.shade400
                                  : Colors.grey.shade600,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 50,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(left: 3, top: 2),
                                      child: Align(
                                        alignment: Alignment.topLeft,
                                        child: Text(
                                          'A',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                      child: Center(
                                        child: Text(
                                          '♥',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '작게',
                                style: TextStyle(
                                  color: !_largeCardMode
                                      ? Colors.white
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setDialogState(() {});
                          setState(() {
                            _largeCardMode = true;
                          });
                          _saveCardSizeSetting(true);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _largeCardMode
                                ? Colors.green.shade700
                                : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _largeCardMode
                                  ? Colors.green.shade400
                                  : Colors.grey.shade600,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 50,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Column(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(left: 3, top: 2),
                                      child: Align(
                                        alignment: Alignment.topLeft,
                                        child: Text(
                                          'A♥',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: Text(
                                          '♥',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontSize: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '크게',
                                style: TextStyle(
                                  color: _largeCardMode
                                      ? Colors.white
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // 손잡이 설정 (카드 넘기기 위치)
                const Text(
                  '카드 넘기기 위치',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setDialogState(() {});
                          setState(() {
                            _leftHandedMode = false;
                          });
                          _saveLeftHandedSetting(false);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: !_leftHandedMode
                                ? Colors.green.shade700
                                : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: !_leftHandedMode
                                  ? Colors.green.shade400
                                  : Colors.grey.shade600,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.back_hand,
                                size: 32,
                                color: !_leftHandedMode
                                    ? Colors.white
                                    : Colors.grey,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '오른손잡이',
                                style: TextStyle(
                                  color: !_leftHandedMode
                                      ? Colors.white
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '왼쪽에서 넘기기',
                                style: TextStyle(
                                  color: !_leftHandedMode
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setDialogState(() {});
                          setState(() {
                            _leftHandedMode = true;
                          });
                          _saveLeftHandedSetting(true);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _leftHandedMode
                                ? Colors.green.shade700
                                : Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _leftHandedMode
                                  ? Colors.green.shade400
                                  : Colors.grey.shade600,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Transform.flip(
                                flipX: true,
                                child: Icon(
                                  Icons.back_hand,
                                  size: 32,
                                  color: _leftHandedMode
                                      ? Colors.white
                                      : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '왼손잡이',
                                style: TextStyle(
                                  color: _leftHandedMode
                                      ? Colors.white
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '오른쪽에서 넘기기',
                                style: TextStyle(
                                  color: _leftHandedMode
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
          'games.solitaire.rulesTitle'.tr(),
          style: TextStyle(color: Colors.green.shade400),
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
                '4개의 에이스 파일에 무늬별로\n'
                'A부터 K까지 순서대로 카드를 쌓으세요!',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '🎮 게임 방법',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• 테이블: 빨강↔검정 교대로 내림차순 쌓기\n'
                '• 에이스 파일: 같은 무늬로 오름차순 쌓기\n'
                '• 덱을 탭하여 새 카드 뒤집기\n'
                '• K만 빈 테이블 칸에 놓을 수 있음',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '🃏 카드 이동',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• 앞면 카드를 드래그하여 이동\n'
                '• 여러 장을 한 번에 이동 가능\n'
                '• 더블탭으로 자동 이동 (에이스 파일)',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '💡 팁',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• 에이스가 나오면 바로 위로 올리세요\n'
                '• 뒷면 카드를 빨리 뒤집는 것이 중요\n'
                '• 1장/3장 모드로 난이도 조절 가능',
                style: TextStyle(color: Colors.white70, fontSize: 13),
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
