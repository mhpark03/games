import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/game_save_service.dart';
import '../../services/input_sdk_service.dart';

// 카드 무늬
enum Suit { spade, heart, diamond, club }

// 플레잉 카드
class PlayingCard {
  final Suit suit;
  final int rank; // 1-13 (A, 2-10, J, Q, K)

  PlayingCard({required this.suit, required this.rank});

  // 카드 점수 (A=1, 2-9=숫자, J=10, Q=11, K=12)
  int get point {
    if (rank == 1) return 1;
    if (rank == 11) return 10; // J
    if (rank == 12) return 11; // Q
    if (rank == 13) return 12; // K
    return rank;
  }

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
        return '$rank';
    }
  }

  String get suitSymbol {
    switch (suit) {
      case Suit.spade:
        return '♠';
      case Suit.heart:
        return '♥';
      case Suit.diamond:
        return '♦';
      case Suit.club:
        return '♣';
    }
  }

  Color get suitColor {
    if (suit == Suit.heart || suit == Suit.diamond) {
      return Colors.red;
    }
    return Colors.black;
  }

  int get suitIndex {
    switch (suit) {
      case Suit.spade:
        return 0;
      case Suit.heart:
        return 1;
      case Suit.diamond:
        return 2;
      case Suit.club:
        return 3;
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is PlayingCard) {
      return suit == other.suit && rank == other.rank;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(suit, rank);

  @override
  String toString() => '$suitSymbol$rankString';
}

// 멜드 (등록된 조합)
class Meld {
  final List<PlayingCard> cards;
  final bool isRun; // true = Run (시퀀스), false = Group (세트)

  Meld({required this.cards, required this.isRun});

  int get size => cards.length;
}

// 땡큐 옵션 타입
enum ThankYouType {
  seven,        // 7 단독 등록
  attachPlayer, // 플레이어 멜드에 붙이기
  attachComputer, // 컴퓨터 멜드에 붙이기
  newMeld,      // 새 멜드 생성
}

// 땡큐 옵션
class ThankYouOption {
  final ThankYouType type;
  final PlayingCard discardCard;
  final List<PlayingCard> handCards; // 손패에서 사용할 카드들
  final int? meldIndex; // 붙일 멜드 인덱스
  final int? computerIndex; // 컴퓨터 인덱스 (컴퓨터 멜드에 붙일 때)
  final bool isRun; // 새 멜드가 Run인지

  ThankYouOption({
    required this.type,
    required this.discardCard,
    this.handCards = const [],
    this.meldIndex,
    this.computerIndex,
    this.isRun = false,
  });

  // 옵션 설명 문자열
  String get description {
    switch (type) {
      case ThankYouType.seven:
        return '${discardCard.suitSymbol}7 단독 등록';
      case ThankYouType.attachPlayer:
        return '${discardCard.suitSymbol}${discardCard.rankString} 내 멜드에 붙이기';
      case ThankYouType.attachComputer:
        return '${discardCard.suitSymbol}${discardCard.rankString} 컴퓨터${computerIndex! + 1} 멜드에 붙이기';
      case ThankYouType.newMeld:
        final allCards = [...handCards, discardCard];
        if (isRun) {
          allCards.sort((a, b) => a.rank.compareTo(b.rank));
        }
        final cardStr = allCards.map((c) => '${c.suitSymbol}${c.rankString}').join(' ');
        return isRun ? 'Run: $cardStr' : 'Group: $cardStr';
    }
  }
}

// 훌라 난이도
enum HulaDifficulty { easy, medium, hard }

// 52장 덱 생성
List<PlayingCard> createDeck() {
  final deck = <PlayingCard>[];
  for (final suit in Suit.values) {
    for (int rank = 1; rank <= 13; rank++) {
      deck.add(PlayingCard(suit: suit, rank: rank));
    }
  }
  return deck;
}

class HulaScreen extends StatefulWidget {
  final int playerCount;
  final bool resumeGame;
  final HulaDifficulty difficulty;

  const HulaScreen({
    super.key,
    this.playerCount = 2,
    this.resumeGame = false,
    this.difficulty = HulaDifficulty.medium,
  });

  static Future<bool> hasSavedGame() async {
    return await GameSaveService.hasSavedGame('hula');
  }

  static Future<int?> getSavedPlayerCount() async {
    final gameState = await GameSaveService.loadGame('hula');
    if (gameState == null) return null;
    return gameState['playerCount'] as int?;
  }

  static Future<HulaDifficulty?> getSavedDifficulty() async {
    final gameState = await GameSaveService.loadGame('hula');
    if (gameState == null) return null;
    final difficultyIndex = gameState['difficulty'] as int?;
    if (difficultyIndex == null) return null;
    return HulaDifficulty.values[difficultyIndex];
  }

  static Future<void> clearSavedGame() async {
    await GameSaveService.clearSave();
  }

  @override
  State<HulaScreen> createState() => _HulaScreenState();
}

class _HulaScreenState extends State<HulaScreen> with TickerProviderStateMixin {
  // 카드 덱
  List<PlayingCard> deck = [];
  List<PlayingCard> discardPile = [];

  // 손패
  List<PlayingCard> playerHand = [];
  List<List<PlayingCard>> computerHands = [];

  // 등록된 멜드
  List<Meld> playerMelds = [];
  List<List<Meld>> computerMelds = [];

  // 게임 상태
  late int playerCount;
  int currentTurn = 0; // 0 = 플레이어
  bool gameOver = false;
  String? winner;
  int? winnerIndex;
  bool isHula = false; // 훌라 여부

  // 컴퓨터 난이도 (0=쉬움, 1=보통, 2=어려움)
  List<int> computerDifficulties = [];

  // 턴 단계
  bool hasDrawn = false; // 이번 턴에 드로우했는지
  List<int> selectedCardIndices = []; // 선택된 카드 인덱스들
  bool waitingForNextTurn = false; // 다음 턴 대기 중
  Timer? _nextTurnTimer; // 자동 진행 타이머
  int _autoPlayCountdown = 10; // 자동 진행 카운트다운
  int _lastDiscardTurn = 0; // 마지막으로 카드를 버린 플레이어 턴
  Timer? _computerActionTimer; // 컴퓨터 액션 딜레이 타이머
  static const int _computerActionDelay = 2000; // 컴퓨터 액션 딜레이 (밀리초)
  VoidCallback? _pendingComputerAction; // 대기 후 실행할 컴퓨터 동작
  bool _thankYouWaiting = false; // 플레이어 땡큐 대기 중
  int _thankYouCountdown = 0; // 땡큐 대기 카운트다운
  Timer? _thankYouTimer; // 땡큐 대기 타이머
  static const int _thankYouWaitSeconds = 5; // 땡큐 대기 시간 (초)

  // 점수
  List<int> scores = [];

  // 메시지
  String? gameMessage;
  Timer? _messageTimer;

  // 애니메이션
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    InputSdkService.setBoardGameContext();
    playerCount = widget.playerCount;

    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    if (widget.resumeGame) {
      _loadSavedGame();
    } else {
      _initGame();
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _nextTurnTimer?.cancel();
    _computerActionTimer?.cancel();
    _thankYouTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _initGame() {
    // 타이머 모두 취소
    _cancelNextTurnTimer();
    _messageTimer?.cancel();
    _computerActionTimer?.cancel();

    deck = createDeck();
    deck.shuffle(Random());

    discardPile = [];
    playerHand = [];
    computerHands = List.generate(playerCount - 1, (_) => []);
    playerMelds = [];
    computerMelds = List.generate(playerCount - 1, (_) => []);
    scores = List.generate(playerCount, (_) => 0);

    // 컴퓨터 난이도 설정 (선택된 난이도 적용)
    final difficultyValue = widget.difficulty.index; // 0=쉬움, 1=보통, 2=어려움
    computerDifficulties = List.generate(playerCount - 1, (_) => difficultyValue);

    final random = Random();

    // 각 플레이어에게 7장씩 배분
    for (int i = 0; i < 7; i++) {
      playerHand.add(deck.removeLast());
      for (int c = 0; c < playerCount - 1; c++) {
        computerHands[c].add(deck.removeLast());
      }
    }

    // 버린 더미에 1장 공개
    discardPile.add(deck.removeLast());

    // 손패 정렬
    _sortHand(playerHand);
    for (var hand in computerHands) {
      _sortHand(hand);
    }

    // 시작 플레이어 랜덤 선택 (0 = 플레이어, 1~N = 컴퓨터)
    currentTurn = random.nextInt(playerCount);
    gameOver = false;
    winner = null;
    winnerIndex = null;
    isHula = false;
    hasDrawn = false;
    selectedCardIndices = [];
    waitingForNextTurn = false;
    gameMessage = null;
    _lastDiscardTurn = 0;
    _pendingComputerAction = null;

    setState(() {});
    _saveGame();

    // 컴퓨터가 먼저 시작하면 대기 상태로 전환
    if (currentTurn != 0) {
      final startingComputer = currentTurn;
      _showMessage('games.hula.computerStartsFirst'.tr(namedArgs: {'num': '$startingComputer'}));
      setState(() {
        waitingForNextTurn = true;
      });
      _startNextTurnTimer();
    } else {
      // 플레이어가 먼저 시작
      _showMessage('games.hula.yourTurnDraw'.tr());
    }
  }

  // 다음 턴 자동 진행 타이머 시작
  void _startNextTurnTimer({int seconds = 10}) {
    _cancelNextTurnTimer();
    _autoPlayCountdown = seconds;

    // 메시지 타이머 취소 (타이머 동안 메시지 유지)
    _messageTimer?.cancel();

    _nextTurnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || gameOver) {
        timer.cancel();
        return;
      }

      setState(() {
        _autoPlayCountdown--;
      });

      if (_autoPlayCountdown <= 0) {
        timer.cancel();
        _onNextTurn();
      }
    });
  }

  // 다음 턴 타이머 취소
  void _cancelNextTurnTimer() {
    _nextTurnTimer?.cancel();
    _nextTurnTimer = null;
  }

  // 컴퓨터 동작 후 대기 상태로 전환 (다음 동작을 콜백으로 저장)
  void _startWaitWithAction(VoidCallback nextAction, {int seconds = 10}) {
    setState(() {
      waitingForNextTurn = true;
      _pendingComputerAction = nextAction;
    });
    _startNextTurnTimer(seconds: seconds);
  }

  // 다음 턴 버튼 클릭
  void _onNextTurn() {
    _cancelNextTurnTimer();
    final pendingAction = _pendingComputerAction;
    setState(() {
      waitingForNextTurn = false;
      _pendingComputerAction = null;
    });
    _messageTimer?.cancel();

    if (gameOver) return;

    // 대기 중인 컴퓨터 동작이 있으면 실행
    if (pendingAction != null) {
      Timer(const Duration(milliseconds: 300), () {
        if (mounted && !gameOver) {
          pendingAction();
        }
      });
      return;
    }

    // 플레이어 후 순서 컴퓨터 땡큐 확인
    final afterResult = _checkComputerThankYouAfterPlayer(_lastDiscardTurn);
    if (afterResult != null) {
      Timer(const Duration(milliseconds: 300), () {
        if (mounted && !gameOver) {
          _executeComputerThankYou(afterResult);
        }
      });
      return;
    }

    // 땡큐 없으면 다음 턴 진행
    if (currentTurn != 0) {
      Timer(const Duration(milliseconds: 300), () {
        if (mounted && !gameOver) {
          _computerTurn();
        }
      });
    }
  }

  void _sortHand(List<PlayingCard> hand) {
    hand.sort((a, b) {
      if (a.suit != b.suit) {
        return a.suitIndex.compareTo(b.suitIndex);
      }
      return a.rank.compareTo(b.rank);
    });
  }

  // 카드를 Map으로 변환
  Map<String, dynamic> _cardToMap(PlayingCard card) {
    return {
      'suit': card.suit.index,
      'rank': card.rank,
    };
  }

  // Map에서 카드 복원
  PlayingCard _mapToCard(Map<String, dynamic> map) {
    return PlayingCard(
      suit: Suit.values[map['suit'] as int],
      rank: map['rank'] as int,
    );
  }

  // 멜드를 Map으로 변환
  Map<String, dynamic> _meldToMap(Meld meld) {
    return {
      'cards': meld.cards.map(_cardToMap).toList(),
      'isRun': meld.isRun,
    };
  }

  // Map에서 멜드 복원
  Meld _mapToMeld(Map<String, dynamic> map) {
    final cardsList = (map['cards'] as List)
        .map((c) => _mapToCard(c as Map<String, dynamic>))
        .toList();
    return Meld(
      cards: cardsList,
      isRun: map['isRun'] as bool,
    );
  }

  // 게임 상태 저장
  Future<void> _saveGame() async {
    if (gameOver) {
      await HulaScreen.clearSavedGame();
      return;
    }

    final gameState = {
      'playerCount': playerCount,
      'difficulty': widget.difficulty.index,
      'deck': deck.map(_cardToMap).toList(),
      'discardPile': discardPile.map(_cardToMap).toList(),
      'playerHand': playerHand.map(_cardToMap).toList(),
      'computerHands': computerHands
          .map((hand) => hand.map(_cardToMap).toList())
          .toList(),
      'playerMelds': playerMelds.map(_meldToMap).toList(),
      'computerMelds': computerMelds
          .map((melds) => melds.map(_meldToMap).toList())
          .toList(),
      'currentTurn': currentTurn,
      'hasDrawn': hasDrawn,
      'scores': scores,
      'computerDifficulties': computerDifficulties,
      'waitingForNextTurn': waitingForNextTurn,
      'lastDiscardTurn': _lastDiscardTurn,
    };

    await GameSaveService.saveGame('hula', gameState);
  }

  // 저장된 게임 불러오기
  Future<void> _loadSavedGame() async {
    final gameState = await GameSaveService.loadGame('hula');

    if (gameState == null) {
      _initGame();
      return;
    }

    setState(() {
      playerCount = gameState['playerCount'] as int;

      // 덱 복원
      deck = (gameState['deck'] as List)
          .map((c) => _mapToCard(c as Map<String, dynamic>))
          .toList();

      // 버린 더미 복원
      discardPile = (gameState['discardPile'] as List)
          .map((c) => _mapToCard(c as Map<String, dynamic>))
          .toList();

      // 플레이어 손패 복원
      playerHand = (gameState['playerHand'] as List)
          .map((c) => _mapToCard(c as Map<String, dynamic>))
          .toList();

      // 컴퓨터 손패 복원
      computerHands = (gameState['computerHands'] as List)
          .map((hand) => (hand as List)
              .map((c) => _mapToCard(c as Map<String, dynamic>))
              .toList())
          .toList();

      // 플레이어 멜드 복원
      playerMelds = (gameState['playerMelds'] as List)
          .map((m) => _mapToMeld(m as Map<String, dynamic>))
          .toList();

      // 컴퓨터 멜드 복원
      computerMelds = (gameState['computerMelds'] as List)
          .map((melds) => (melds as List)
              .map((m) => _mapToMeld(m as Map<String, dynamic>))
              .toList())
          .toList();

      currentTurn = gameState['currentTurn'] as int;
      hasDrawn = gameState['hasDrawn'] as bool;
      scores = List<int>.from(gameState['scores'] as List);

      // 난이도 복원 (저장된 게임에 없으면 선택된 난이도 사용)
      if (gameState.containsKey('computerDifficulties')) {
        computerDifficulties = List<int>.from(gameState['computerDifficulties'] as List);
      } else {
        final difficultyValue = widget.difficulty.index;
        computerDifficulties = List.generate(playerCount - 1, (_) => difficultyValue);
      }

      gameOver = false;
      winner = null;
      winnerIndex = null;
      isHula = false;
      selectedCardIndices = [];

      // 대기 상태 복원
      waitingForNextTurn = gameState['waitingForNextTurn'] as bool? ?? false;
      _lastDiscardTurn = gameState['lastDiscardTurn'] as int? ?? 0;

      // 내 차례에서는 대기 상태 불필요 (타이머/시작버튼 없음)
      if (currentTurn == 0) {
        waitingForNextTurn = false;
      }
    });
    _cancelNextTurnTimer();

    // 내 차례면 메시지만 표시
    if (currentTurn == 0) {
      _showMessage(hasDrawn ? 'games.hula.discardOrRegister'.tr() : 'games.hula.drawCard'.tr());
    }
    // 컴퓨터 턴이고 대기 상태면 타이머 시작
    else if (waitingForNextTurn) {
      _startNextTurnTimer();
    }
    // 컴퓨터 턴이고 드로우 전이면 대기 상태로 만들고 타이머 시작
    else if (!hasDrawn) {
      setState(() {
        waitingForNextTurn = true;
      });
      _startNextTurnTimer();
    }
    // 컴퓨터 턴이고 드로우 후면 버리기 단계로 진행
    else {
      final computerIndex = currentTurn - 1;
      _computerActionTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted && !gameOver) {
          _computerTurnDiscard(computerIndex);
        }
      });
    }
  }

  void _showMessage(String message, {int seconds = 2, bool keepDuringWait = false}) {
    setState(() {
      gameMessage = message;
    });
    _messageTimer?.cancel();
    // 메시지는 다음 동작까지 항상 유지 (타이머로 지우지 않음)
  }

  // 덱에서 카드 드로우
  void _drawFromDeck() {
    if (hasDrawn || gameOver || currentTurn != 0) return;

    // 대기 상태면 타이머 취소
    if (waitingForNextTurn) {
      _cancelNextTurnTimer();
    }

    if (deck.isEmpty) {
      // 덱이 비면 버린 더미 섞기
      if (discardPile.length <= 1) {
        _showMessage('games.hula.noMoreCards'.tr());
        return;
      }
      final topCard = discardPile.removeLast();
      deck = List.from(discardPile);
      deck.shuffle(Random());
      discardPile = [topCard];
    }

    final card = deck.removeLast();
    playerHand.add(card);
    _sortHand(playerHand);

    setState(() {
      hasDrawn = true;
      selectedCardIndices = [];
      waitingForNextTurn = false;
    });
    _showMessage('games.hula.drewFromDeck'.tr(namedArgs: {'card': '${card.suitSymbol}${card.rankString}'}));
    _saveGame();
  }

  // 버린 더미에서 카드 가져오기 (땡큐)
  void _drawFromDiscard() {
    if (gameOver) return;
    if (discardPile.isEmpty) return;

    // 플레이어 턴이거나, 대기 중일 때 (땡큐)
    if (currentTurn == 0 && hasDrawn) return;
    if (currentTurn != 0 && !waitingForNextTurn) return;

    // 땡큐 가능 여부 확인 (등록 가능한 경우에만)
    if (!_canThankYou()) return;

    // 모든 가능한 옵션 찾기
    final options = _findAllThankYouOptions();
    if (options.isEmpty) return;

    // 옵션이 1개면 바로 실행, 2개 이상이면 선택 다이얼로그
    if (options.length == 1) {
      _executeThankYouOption(options.first);
    } else {
      _showThankYouOptionsDialog(options);
    }
  }

  // 땡큐 옵션 선택 다이얼로그 표시
  void _showThankYouOptionsDialog(List<ThankYouOption> options) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(
              '${options.first.discardCard.suitSymbol}${options.first.discardCard.rankString}',
              style: TextStyle(
                color: options.first.discardCard.suitColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text('${'games.hula.thankYou'.tr()} ${'dialog.selectMode'.tr()}'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: _buildOptionIcon(option),
                  title: Text(
                    option.description,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _executeThankYouOption(option);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('app.cancel'.tr()),
          ),
        ],
      ),
    );
  }

  // 옵션 아이콘 빌드
  Widget _buildOptionIcon(ThankYouOption option) {
    IconData icon;
    Color color;
    switch (option.type) {
      case ThankYouType.seven:
        icon = Icons.looks_one;
        color = Colors.purple;
      case ThankYouType.attachPlayer:
        icon = Icons.add_circle;
        color = Colors.green;
      case ThankYouType.attachComputer:
        icon = Icons.add_circle_outline;
        color = Colors.orange;
      case ThankYouType.newMeld:
        icon = option.isRun ? Icons.linear_scale : Icons.grid_view;
        color = Colors.blue;
    }
    return Icon(icon, color: color, size: 32);
  }

  // 땡큐 옵션 실행
  void _executeThankYouOption(ThankYouOption option) {
    // 땡큐 대기 타이머 취소
    _thankYouTimer?.cancel();
    setState(() {
      _thankYouWaiting = false;
      _thankYouCountdown = 0;
    });

    // 땡큐 상황: 대기 중에 가져가기
    if (waitingForNextTurn || currentTurn != 0) {
      _cancelNextTurnTimer();
      setState(() {
        currentTurn = 0;
        waitingForNextTurn = false;
      });
    }

    // ★ option.discardCard를 사용하여 정확한 카드 제거 (타이머로 인한 상태 변경 방지)
    final card = option.discardCard;
    // discardPile에서 해당 카드가 마지막에 있는지 확인 후 제거
    if (discardPile.isNotEmpty && discardPile.last == card) {
      discardPile.removeLast();
    } else {
      // 카드가 없거나 다른 카드면 무시 (이미 다른 처리로 제거됨)
      return;
    }
    String meldMessage = '';

    switch (option.type) {
      case ThankYouType.seven:
        playerMelds.add(Meld(cards: [card], isRun: false));
        meldMessage = 'games.hula.thankYouRegister7'.tr(namedArgs: {'card': '${card.suitSymbol}7'});

      case ThankYouType.attachPlayer:
        _attachToMeld(option.meldIndex!, card);
        meldMessage = 'games.hula.thankYouAttach'.tr(namedArgs: {'card': '${card.suitSymbol}${card.rankString}'});

      case ThankYouType.attachComputer:
        _attachToMeldList(option.meldIndex!, card, computerMelds[option.computerIndex!]);
        meldMessage = 'games.hula.thankYouAttachToComputer'.tr(namedArgs: {'card': '${card.suitSymbol}${card.rankString}', 'num': '${option.computerIndex! + 1}'});

      case ThankYouType.newMeld:
        final newMeldCards = [...option.handCards, card];
        // 손패에서 제거
        for (final c in option.handCards) {
          playerHand.remove(c);
        }
        if (option.isRun) {
          newMeldCards.sort((a, b) => a.rank.compareTo(b.rank));
        }
        playerMelds.add(Meld(cards: newMeldCards, isRun: option.isRun));
        meldMessage = 'games.hula.thankYouNewMeld'.tr(namedArgs: {'desc': option.description});
    }

    setState(() {
      hasDrawn = true;
      selectedCardIndices = [];
    });
    _showMessage(meldMessage);
    _saveGame();

    // 손패가 비었으면 승리
    if (playerHand.isEmpty) {
      _playerWins();
    }
  }

  // 카드 선택/해제
  void _toggleCardSelection(int index) {
    if (gameOver || currentTurn != 0) return;

    setState(() {
      if (selectedCardIndices.contains(index)) {
        selectedCardIndices.remove(index);
      } else {
        selectedCardIndices.add(index);
      }
      selectedCardIndices.sort();
    });
  }

  // 선택된 카드들이 유효한 멜드인지 확인
  bool _isValidMeld(List<PlayingCard> cards) {
    if (cards.length < 3) return false;

    // Group (같은 숫자) 체크
    if (_isValidGroup(cards)) return true;

    // Run (같은 무늬 연속) 체크
    if (_isValidRun(cards)) return true;

    return false;
  }

  bool _isValidGroup(List<PlayingCard> cards) {
    if (cards.length < 3 || cards.length > 4) return false;
    final rank = cards.first.rank;
    return cards.every((c) => c.rank == rank);
  }

  bool _isValidRun(List<PlayingCard> cards) {
    if (cards.length < 3) return false;

    final suit = cards.first.suit;
    if (!cards.every((c) => c.suit == suit)) return false;

    // 랭크 정렬
    final ranks = cards.map((c) => c.rank).toList()..sort();

    // A-2-3 또는 Q-K-A 처리
    // A를 1 또는 14로 취급
    bool isSequential = true;
    for (int i = 1; i < ranks.length; i++) {
      if (ranks[i] != ranks[i - 1] + 1) {
        isSequential = false;
        break;
      }
    }
    if (isSequential) return true;

    // A를 14로 취급해서 다시 체크 (Q-K-A)
    if (ranks.contains(1)) {
      final highRanks = ranks.map((r) => r == 1 ? 14 : r).toList()..sort();
      isSequential = true;
      for (int i = 1; i < highRanks.length; i++) {
        if (highRanks[i] != highRanks[i - 1] + 1) {
          isSequential = false;
          break;
        }
      }
      if (isSequential) return true;
    }

    return false;
  }

  // 기존 멜드에 카드 붙이기 가능 여부 확인
  int _canAttachToMeld(PlayingCard card) {
    for (int i = 0; i < playerMelds.length; i++) {
      final meld = playerMelds[i];

      // 단독 7 카드 특별 처리: Run으로만 확장 가능 (Group 불가)
      if (meld.cards.length == 1 && meld.cards.first.rank == 7) {
        final seven = meld.cards.first;
        // 같은 무늬의 6 또는 8이면 Run으로 확장
        if (card.suit == seven.suit && (card.rank == 6 || card.rank == 8)) {
          return i;
        }
        continue;
      }

      if (meld.isRun) {
        // Run: 같은 무늬이고 앞이나 뒤에 연속되는 카드
        if (card.suit == meld.cards.first.suit) {
          final ranks = meld.cards.map((c) => c.rank).toList()..sort();
          final minRank = ranks.first;
          final maxRank = ranks.last;

          // 앞에 붙이기 (A-2-3에 K 붙이기는 제외, 단 A가 14로 사용된 경우 제외)
          if (card.rank == minRank - 1) return i;
          // 뒤에 붙이기
          if (card.rank == maxRank + 1) return i;
          // A를 14로 취급 (Q-K-A 케이스)
          if (maxRank == 13 && card.rank == 1) return i;
          // A-2-3에서 A 앞에 K는 안됨 (A가 1로 사용된 경우)
        }
      } else {
        // Group: 같은 숫자 (최대 4장까지)
        if (meld.cards.length < 4 && card.rank == meld.cards.first.rank) {
          // 이미 같은 무늬가 있는지 확인
          if (!meld.cards.any((c) => c.suit == card.suit)) {
            return i;
          }
        }
      }
    }
    return -1;
  }

  // 멜드에 카드 붙이기
  void _attachToMeld(int meldIndex, PlayingCard card) {
    final meld = playerMelds[meldIndex];
    final newCards = [...meld.cards, card];
    bool newIsRun = meld.isRun;

    // 단독 7 카드에 붙이는 경우: Run 또는 Group 결정
    if (meld.cards.length == 1 && meld.cards.first.rank == 7) {
      final seven = meld.cards.first;
      if (card.suit == seven.suit && (card.rank == 6 || card.rank == 8)) {
        // 같은 무늬의 6 또는 8 → Run으로 변환
        newIsRun = true;
      } else {
        // 다른 7 → Group 유지
        newIsRun = false;
      }
    }

    if (newIsRun) {
      // Run은 정렬
      newCards.sort((a, b) => a.rank.compareTo(b.rank));
    }

    playerMelds[meldIndex] = Meld(cards: newCards, isRun: newIsRun);
  }

  // 7 카드인지 확인
  bool _isSeven(PlayingCard card) => card.rank == 7;


  // 특정 무늬의 7이 멜드로 등록되었는지 확인
  bool _isSevenRegistered(Suit suit) {
    // 플레이어 멜드에서 확인
    for (final meld in playerMelds) {
      if (meld.cards.any((c) => c.rank == 7 && c.suit == suit)) {
        return true;
      }
    }
    // 컴퓨터 멜드에서 확인
    for (final melds in computerMelds) {
      for (final meld in melds) {
        if (meld.cards.any((c) => c.rank == 7 && c.suit == suit)) {
          return true;
        }
      }
    }
    return false;
  }

  // 특정 숫자의 카드가 멜드에 몇 장 있는지 확인
  int _countMeldedCards(int rank) {
    int count = 0;
    // 플레이어 멜드에서 확인
    for (final meld in playerMelds) {
      count += meld.cards.where((c) => c.rank == rank).length;
    }
    // 컴퓨터 멜드에서 확인
    for (final melds in computerMelds) {
      for (final meld in melds) {
        count += meld.cards.where((c) => c.rank == rank).length;
      }
    }
    return count;
  }

  // 등록된 런에 붙일 가능성 계산 (중간 카드가 남아있으면 보너스)
  double _calculateRunAttachPotential(PlayingCard card) {
    double bonus = 0;

    // 모든 멜드에서 런 확인
    final allMelds = [...playerMelds];
    for (final melds in computerMelds) {
      allMelds.addAll(melds);
    }

    for (final meld in allMelds) {
      if (!meld.isRun || meld.cards.isEmpty) continue;
      if (meld.cards.first.suit != card.suit) continue;

      // 런의 최소/최대 랭크 찾기
      final ranks = meld.cards.map((c) => c.rank).toList()..sort();
      final minRank = ranks.first;
      final maxRank = ranks.last;

      // 카드가 런에서 1칸 떨어져 있으면 (바로 붙일 수 있음)
      if (card.rank == minRank - 1 || card.rank == maxRank + 1) {
        bonus += 30; // 바로 붙일 수 있음
      }
      // 카드가 런에서 2칸 떨어져 있으면 (중간 카드 필요)
      else if (card.rank == minRank - 2 || card.rank == maxRank + 2) {
        // 중간 카드가 남아있는지 확인 (각 무늬당 1장뿐)
        final bridgeRank = card.rank < minRank ? minRank - 1 : maxRank + 1;
        final bridgeUsed = discardPile.where((c) => c.rank == bridgeRank && c.suit == card.suit).length +
            _countMeldedCardsWithSuit(bridgeRank, card.suit);

        if (bridgeUsed == 0) {
          // 중간 카드가 남아있음 - 붙일 가능성 있음
          bonus += 25;
        }
        // bridgeUsed >= 1: 중간 카드가 사라짐 - 보너스 없음 (일반 단독 카드로 처리)
      }
    }

    return bonus;
  }

  // 특정 숫자와 무늬의 카드가 멜드에 있는지 확인
  int _countMeldedCardsWithSuit(int rank, Suit suit) {
    int count = 0;
    for (final meld in playerMelds) {
      count += meld.cards.where((c) => c.rank == rank && c.suit == suit).length;
    }
    for (final melds in computerMelds) {
      for (final meld in melds) {
        count += meld.cards.where((c) => c.rank == rank && c.suit == suit).length;
      }
    }
    return count;
  }

  // 땡큐 가능 여부 확인 (버린 카드를 가져와서 바로 등록 가능한지)
  // ★ 7 단독 땡큐 제거 - 3장 이상의 멜드로만 등록 가능
  bool _canThankYou() {
    if (discardPile.isEmpty) return false;
    final card = discardPile.last;

    // 손패와 합쳐서 새로운 멜드 가능한지 확인
    final thankYouCards = _findThankYouMeldCards(card);
    if (thankYouCards != null) return true;

    // 기존 멜드에 붙이기 가능한지 확인
    for (int i = 0; i < playerMelds.length; i++) {
      if (_canAttachToMeldAtIndex(card, playerMelds, i)) return true;
    }
    for (int c = 0; c < computerMelds.length; c++) {
      for (int i = 0; i < computerMelds[c].length; i++) {
        if (_canAttachToMeldAtIndex(card, computerMelds[c], i)) return true;
      }
    }

    return false;
  }

  // 땡큐 카드와 손패로 만들 수 있는 멜드 카드 찾기 (첫 번째만)
  List<PlayingCard>? _findThankYouMeldCards(PlayingCard discardCard) {
    final options = _findAllNewMeldOptions(discardCard);
    if (options.isNotEmpty) {
      return options.first.handCards;
    }
    return null;
  }

  // 모든 가능한 새 멜드 옵션 찾기 (손패와 합쳐서)
  List<ThankYouOption> _findAllNewMeldOptions(PlayingCard discardCard) {
    final options = <ThankYouOption>[];

    // Group 체크: 같은 숫자 2장 이상 있는지
    final sameRank = playerHand.where((c) => c.rank == discardCard.rank).toList();
    if (sameRank.length >= 2) {
      // 3장 Group
      options.add(ThankYouOption(
        type: ThankYouType.newMeld,
        discardCard: discardCard,
        handCards: sameRank.take(2).toList(),
        isRun: false,
      ));
    }

    // Run 체크: 같은 무늬의 연속 숫자
    final sameSuit = playerHand.where((c) => c.suit == discardCard.suit).toList();
    if (sameSuit.length >= 2) {
      sameSuit.sort((a, b) => a.rank.compareTo(b.rank));

      // 모든 2장 조합 체크
      for (int i = 0; i < sameSuit.length; i++) {
        for (int j = i + 1; j < sameSuit.length; j++) {
          final c1 = sameSuit[i];
          final c2 = sameSuit[j];

          // c1, c2, discardCard가 연속인지 확인
          final ranks = [c1.rank, c2.rank, discardCard.rank]..sort();
          bool isSequential = ranks[1] == ranks[0] + 1 && ranks[2] == ranks[1] + 1;

          // A-2-3 또는 Q-K-A 특수 케이스
          if (!isSequential && ranks.contains(1)) {
            final highRanks = ranks.map((r) => r == 1 ? 14 : r).toList()..sort();
            isSequential = highRanks[1] == highRanks[0] + 1 && highRanks[2] == highRanks[1] + 1;
          }

          if (isSequential) {
            options.add(ThankYouOption(
              type: ThankYouType.newMeld,
              discardCard: discardCard,
              handCards: [c1, c2],
              isRun: true,
            ));
          }
        }
      }
    }

    return options;
  }

  // 모든 땡큐 옵션 찾기
  List<ThankYouOption> _findAllThankYouOptions() {
    if (discardPile.isEmpty) return [];
    final card = discardPile.last;
    final options = <ThankYouOption>[];

    // ★ 7 단독 땡큐 제거 - 3장 이상의 멜드로만 등록 가능

    // 1. 플레이어 멜드에 붙이기 가능
    for (int i = 0; i < playerMelds.length; i++) {
      if (_canAttachToMeldAtIndex(card, playerMelds, i)) {
        options.add(ThankYouOption(
          type: ThankYouType.attachPlayer,
          discardCard: card,
          meldIndex: i,
        ));
      }
    }

    // 2. 컴퓨터 멜드에 붙이기 가능
    for (int c = 0; c < computerMelds.length; c++) {
      for (int i = 0; i < computerMelds[c].length; i++) {
        if (_canAttachToMeldAtIndex(card, computerMelds[c], i)) {
          options.add(ThankYouOption(
            type: ThankYouType.attachComputer,
            discardCard: card,
            meldIndex: i,
            computerIndex: c,
          ));
        }
      }
    }

    // 3. 손패와 합쳐서 새 멜드 생성
    options.addAll(_findAllNewMeldOptions(card));

    return options;
  }

  // 특정 인덱스의 멜드에 카드를 붙일 수 있는지 확인
  bool _canAttachToMeldAtIndex(PlayingCard card, List<Meld> melds, int index) {
    if (index < 0 || index >= melds.length) return false;
    final meld = melds[index];

    // 단독 7 카드 특별 처리: Run으로만 확장 가능 (Group 불가)
    if (meld.cards.length == 1 && meld.cards.first.rank == 7) {
      final seven = meld.cards.first;
      if (card.suit == seven.suit && (card.rank == 6 || card.rank == 8)) {
        return true;
      }
      return false;
    }

    if (meld.isRun) {
      if (card.suit == meld.cards.first.suit) {
        final ranks = meld.cards.map((c) => c.rank).toList()..sort();
        final minRank = ranks.first;
        final maxRank = ranks.last;
        if (card.rank == minRank - 1) return true;
        if (card.rank == maxRank + 1) return true;
        if (maxRank == 13 && card.rank == 1) return true;
      }
    } else {
      if (meld.cards.length < 4 && card.rank == meld.cards.first.rank) {
        if (!meld.cards.any((c) => c.suit == card.suit)) {
          return true;
        }
      }
    }
    return false;
  }

  // 범용: 특정 멜드 목록에 카드를 붙일 수 있는지 확인
  int _canAttachToMeldList(PlayingCard card, List<Meld> melds) {
    for (int i = 0; i < melds.length; i++) {
      final meld = melds[i];

      // 단독 7 카드 특별 처리: Run으로만 확장 가능 (Group 불가)
      if (meld.cards.length == 1 && meld.cards.first.rank == 7) {
        final seven = meld.cards.first;
        if (card.suit == seven.suit && (card.rank == 6 || card.rank == 8)) {
          return i;
        }
        continue;
      }

      if (meld.isRun) {
        if (card.suit == meld.cards.first.suit) {
          final ranks = meld.cards.map((c) => c.rank).toList()..sort();
          final minRank = ranks.first;
          final maxRank = ranks.last;
          if (card.rank == minRank - 1) return i;
          if (card.rank == maxRank + 1) return i;
          if (maxRank == 13 && card.rank == 1) return i;
        }
      } else {
        if (meld.cards.length < 4 && card.rank == meld.cards.first.rank) {
          if (!meld.cards.any((c) => c.suit == card.suit)) {
            return i;
          }
        }
      }
    }
    return -1;
  }

  // 범용: 특정 멜드 목록에 카드 붙이기
  void _attachToMeldList(int meldIndex, PlayingCard card, List<Meld> melds) {
    final meld = melds[meldIndex];
    final newCards = [...meld.cards, card];
    bool newIsRun = meld.isRun;

    if (meld.cards.length == 1 && meld.cards.first.rank == 7) {
      final seven = meld.cards.first;
      if (card.suit == seven.suit && (card.rank == 6 || card.rank == 8)) {
        newIsRun = true;
      } else {
        newIsRun = false;
      }
    }

    if (newIsRun) {
      newCards.sort((a, b) => a.rank.compareTo(b.rank));
    }

    melds[meldIndex] = Meld(cards: newCards, isRun: newIsRun);
  }

  // 스마트 카드 버리기: 버릴 카드 선택
  PlayingCard _selectCardToDiscard(List<PlayingCard> hand, {int? computerIndex}) {
    if (hand.length == 1) return hand.first;

    // 난이도에 따른 랜덤 선택 확률 (쉬움: 40%, 보통: 15%, 어려움: 0%)
    if (computerIndex != null && computerIndex < computerDifficulties.length) {
      final difficulty = computerDifficulties[computerIndex];
      final randomChance = difficulty == 0 ? 40 : (difficulty == 1 ? 15 : 0);
      if (Random().nextInt(100) < randomChance) {
        // 랜덤하게 카드 선택 (단, 7은 제외)
        final nonSevenCards = hand.where((c) => !_isSeven(c)).toList();
        if (nonSevenCards.isNotEmpty) {
          return nonSevenCards[Random().nextInt(nonSevenCards.length)];
        }
      }
    }

    // 스톱 위험도 계산 (컴퓨터의 경우)
    double stopRisk = 0.0;
    if (computerIndex != null) {
      stopRisk = _estimateStopRisk(computerIndex + 1);
    }

    // ★ 자신의 손패가 적으면 스톱 고려 (자신이 스톱할 가능성)
    // 손패 5장 이하면 낮은 점수 카드 유지가 중요
    double selfStopBonus = 0.0;
    if (hand.length <= 3) {
      selfStopBonus = 1.0; // 3장 이하: 최대 보너스
    } else if (hand.length <= 4) {
      selfStopBonus = 0.8; // 4장: 높은 보너스
    } else if (hand.length <= 5) {
      selfStopBonus = 0.5; // 5장: 중간 보너스
    }

    // 각 카드의 "유지 가치" 점수 계산 (높을수록 유지해야 함)
    final scores = <PlayingCard, double>{};

    for (final card in hand) {
      double keepScore = 0;

      // ★ 자신의 손패가 적을 때 낮은 점수 카드 유지 보너스
      if (selfStopBonus > 0) {
        if (card.point <= 3) {
          keepScore += (4 - card.point) * 40 * selfStopBonus; // A: 120, 2: 80, 3: 40 (at 100%)
        } else if (card.point >= 10) {
          keepScore -= 50 * selfStopBonus; // K/Q/J/10 유지 가치 낮춤
        }
      }

      // 스톱 위험도가 높을 때 낮은 점수 카드 유지 보너스
      if (stopRisk >= 40.0) {
        // 낮은 점수 카드 (A=1, 2=2, 3=3)는 유지 가치 높임
        // 높은 점수 카드 (K/Q/J/10=10)는 유지 가치 낮춤
        final riskMultiplier = stopRisk / 100.0; // 0.4 ~ 1.0
        if (card.point <= 3) {
          keepScore += (4 - card.point) * 30 * riskMultiplier; // A: 90, 2: 60, 3: 30 (at 100% risk)
        } else if (card.point >= 10) {
          keepScore -= 40 * riskMultiplier; // K/Q/J/10 유지 가치 낮춤
        }
      }

      // 1. 7 카드는 절대 버리면 안 됨 (단독 등록 가능)
      if (_isSeven(card)) {
        keepScore += 1000;
      }

      // 2. 6/8 카드: 같은 무늬의 7이 등록되지 않았으면 높은 우선순위
      if ((card.rank == 6 || card.rank == 8) && !_isSevenRegistered(card.suit)) {
        keepScore += 80;
      }

      // 3. 5/9 카드: 같은 무늬의 7이 등록되지 않았으면 두 번째 우선순위
      if ((card.rank == 5 || card.rank == 9) && !_isSevenRegistered(card.suit)) {
        keepScore += 60;
      }

      // 4. 같은 숫자 카드 개수 (Group 가능성)
      final sameRankCount = hand.where((c) => c.rank == card.rank).length;
      if (sameRankCount >= 2) {
        // 그룹 가능성 확인: 이미 멜드된 같은 랭크 카드 수
        final meldedCount = _countMeldedCards(card.rank);

        if (meldedCount >= 2) {
          // 그룹 불가능 - 단독 카드처럼 처리
          // A/2/3 보너스
          if (card.rank == 1) {
            keepScore += 50;
          } else if (card.rank == 2) {
            keepScore += 45;
          } else if (card.rank == 3) {
            keepScore += 40;
          } else if (card.rank < 5 || card.rank > 9) {
            // 5-9 제외한 기타 단독 카드: 역순 (K=4, Q=8, J=12, ... 4=40)
            keepScore += (14 - card.rank) * 4;
          }
        } else {
          // 그룹 가능성 있음
          keepScore += sameRankCount * 30; // 2장: 60, 3장: 90

          // K/Q/J 페어는 다른 플레이어가 버릴 확률이 높아 보너스
          if (card.rank >= 11 && card.rank <= 13) {
            keepScore += 40;
          }

          // 이미 멜드된 카드가 있으면 확률 감소
          if (meldedCount == 1) {
            keepScore -= 20;
          }
        }
      } else {
        // 단독 카드 처리
        // A/2/3은 스톱 상황에서 유리
        if (card.rank == 1) {
          keepScore += 50;
        } else if (card.rank == 2) {
          keepScore += 45;
        } else if (card.rank == 3) {
          keepScore += 40;
        } else if (card.rank < 5 || card.rank > 9) {
          // 5-9 제외한 기타 단독 카드: 역순 (K=4, Q=8, J=12, ... 4=40)
          keepScore += (14 - card.rank) * 4;
        }
      }

      // 5. 같은 무늬 연속 카드 (Run 가능성)
      final sameSuitCards = hand.where((c) => c.suit == card.suit).toList();
      if (sameSuitCards.length >= 2) {
        sameSuitCards.sort((a, b) => a.rank.compareTo(b.rank));
        int consecutiveCount = 1;
        for (int i = 0; i < sameSuitCards.length - 1; i++) {
          // 연속이거나 1칸 건너뛴 경우 (2,4 같은 경우 3이 오면 Run 가능)
          final diff = sameSuitCards[i + 1].rank - sameSuitCards[i].rank;
          if (diff == 1 || diff == 2) {
            if (sameSuitCards[i].rank == card.rank ||
                sameSuitCards[i + 1].rank == card.rank) {
              consecutiveCount++;
            }
          }
        }
        if (consecutiveCount >= 2) {
          keepScore += consecutiveCount * 25; // 2장 연속: 50, 3장: 75
        }
      }

      // 6. 등록된 멜드에 바로 붙일 수 있는지 확인 (7 단독 포함)
      bool canAttachNow = false;
      if (_canAttachToMeldList(card, playerMelds) >= 0) {
        canAttachNow = true;
      }
      if (!canAttachNow) {
        for (final melds in computerMelds) {
          if (_canAttachToMeldList(card, melds) >= 0) {
            canAttachNow = true;
            break;
          }
        }
      }
      if (canAttachNow) {
        keepScore += 100; // ★ 바로 붙일 수 있는 카드는 높은 유지 가치
      }

      // 6-1. 등록된 런에 2칸 떨어진 경우 (중간 카드 필요)
      keepScore += _calculateRunAttachPotential(card);

      // 7. 버린 더미에서 같은 카드 확인 (확률 계산)
      // 같은 숫자가 이미 많이 버려졌으면 Group 확률 낮음
      final discardedSameRank =
          discardPile.where((c) => c.rank == card.rank).length;
      if (discardedSameRank >= 2) {
        keepScore -= 20; // Group 가능성 낮음
      }

      // 같은 무늬의 필요한 카드가 버려졌으면 Run 확률 낮음
      final neededForRun = [card.rank - 1, card.rank + 1];
      final discardedNeeded = discardPile
          .where((c) => c.suit == card.suit && neededForRun.contains(c.rank))
          .length;
      if (discardedNeeded >= 1) {
        keepScore -= 15 * discardedNeeded;
      }

      // 8. 카드 점수 (낮은 점수 카드 유지 선호)
      keepScore -= card.point * 2;

      scores[card] = keepScore;
    }

    // 가장 낮은 유지 가치를 가진 카드 버리기
    final sortedCards = hand.toList()
      ..sort((a, b) => scores[a]!.compareTo(scores[b]!));

    // 최종 안전장치: 7은 절대 버리지 않음 (다른 카드가 있는 경우)
    final selectedCard = sortedCards.first;
    if (_isSeven(selectedCard)) {
      final nonSeven = sortedCards.firstWhere((c) => !_isSeven(c), orElse: () => selectedCard);
      return nonSeven;
    }

    return selectedCard;
  }

  // 훌라 가능성 분석 (모든 카드를 한 번에 낼 수 있는지)
  // 반환: { 'canHula': bool, 'playableCount': int, 'probability': double }
  Map<String, dynamic> _analyzeHulaPotential(List<PlayingCard> hand, List<Meld> melds) {
    // 이미 멜드가 등록되어 있으면 훌라 불가능
    if (melds.isNotEmpty) {
      return {'canHula': false, 'playableCount': 0, 'probability': 0.0};
    }

    if (hand.isEmpty) {
      return {'canHula': true, 'playableCount': 0, 'probability': 100.0};
    }

    // 시뮬레이션: 모든 카드를 낼 수 있는지 계산
    final testHand = List<PlayingCard>.from(hand);
    final testMelds = <Meld>[];
    int playableCount = 0;

    // 1. 모든 가능한 멜드 찾기 (3장 이상)
    List<PlayingCard>? meld;
    while ((meld = _findBestMeld(testHand)) != null) {
      for (final card in meld!) {
        testHand.remove(card);
        playableCount++;
      }
      final isRun = _isValidRun(meld);
      testMelds.add(Meld(cards: meld, isRun: isRun));
    }

    // 2. 7 카드 단독 등록
    final sevens = testHand.where((c) => _isSeven(c)).toList();
    for (final seven in sevens) {
      testHand.remove(seven);
      testMelds.add(Meld(cards: [seven], isRun: false));
      playableCount++;
    }

    // 3. 자신의 멜드에 붙일 수 있는 카드
    bool attached = true;
    while (attached && testMelds.isNotEmpty) {
      attached = false;
      for (int i = testHand.length - 1; i >= 0; i--) {
        final card = testHand[i];
        final meldIndex = _canAttachToMeldList(card, testMelds);
        if (meldIndex >= 0) {
          _attachToMeldList(meldIndex, card, testMelds);
          testHand.removeAt(i);
          playableCount++;
          attached = true;
        }
      }
    }

    // 4. 다른 플레이어 멜드에 붙일 수 있는 카드 (자신의 멜드가 생긴 후에만)
    if (testMelds.isNotEmpty) {
      attached = true;
      while (attached && testHand.isNotEmpty) {
        attached = false;
        for (int i = testHand.length - 1; i >= 0; i--) {
          final card = testHand[i];

          // 플레이어 멜드에 붙이기
          if (playerMelds.isNotEmpty) {
            final idx = _canAttachToMeldList(card, playerMelds);
            if (idx >= 0) {
              testHand.removeAt(i);
              playableCount++;
              attached = true;
              continue;
            }
          }

          // 컴퓨터 멜드에 붙이기
          for (int c = 0; c < computerMelds.length; c++) {
            if (computerMelds[c].isNotEmpty) {
              final idx = _canAttachToMeldList(card, computerMelds[c]);
              if (idx >= 0) {
                testHand.removeAt(i);
                playableCount++;
                attached = true;
                break;
              }
            }
          }
        }
      }
    }

    // 남은 카드 확인
    final remainingCount = testHand.length;
    final canHula = remainingCount == 0;

    // 확률 계산
    double probability = 0.0;
    if (canHula) {
      probability = 100.0;
    } else {
      // 남은 카드가 적을수록 확률 높음
      // 남은 카드로 멜드를 만들 수 있는 가능성 계산
      probability = _calculateRemainingProbability(testHand, hand.length);
    }

    return {
      'canHula': canHula,
      'playableCount': playableCount,
      'remainingCount': remainingCount,
      'probability': probability,
    };
  }

  // 남은 카드로 멜드를 만들 확률 계산
  double _calculateRemainingProbability(List<PlayingCard> remaining, int originalHandSize) {
    if (remaining.isEmpty) return 100.0;

    double probability = 0.0;
    final checked = <PlayingCard>{};

    // 1. 기존 멜드에 붙일 수 있는 카드 확인 (확률 높음)
    int attachableCount = 0;
    for (final card in remaining) {
      bool canAttach = false;
      // 플레이어 멜드
      if (playerMelds.isNotEmpty && _canAttachToMeldList(card, playerMelds) >= 0) {
        canAttach = true;
      }
      // 컴퓨터 멜드
      if (!canAttach) {
        for (final cMelds in computerMelds) {
          if (cMelds.isNotEmpty && _canAttachToMeldList(card, cMelds) >= 0) {
            canAttach = true;
            break;
          }
        }
      }
      if (canAttach) {
        attachableCount++;
        probability += 25.0; // 붙일 수 있는 카드는 확률 높음
      }
    }

    // 2. 붙일 수 없는 카드들의 Group/Run 가능성
    for (final card in remaining) {
      if (checked.contains(card)) continue;
      checked.add(card);

      // 같은 숫자 카드 확인 (Group 가능성)
      final sameRank = remaining.where((c) => c.rank == card.rank).length;
      final discardedSameRank = discardPile.where((c) => c.rank == card.rank).length;
      final totalSameRank = sameRank + discardedSameRank;

      // 4장 중 남은 장수로 Group 확률 계산
      if (sameRank >= 2) {
        final neededForGroup = 3 - sameRank;
        final availableInDeck = 4 - totalSameRank;
        if (availableInDeck >= neededForGroup) {
          probability += 20.0 * (availableInDeck / 4.0);
        }
      }

      // 같은 무늬 연속 카드 확인 (Run 가능성)
      final sameSuit = remaining.where((c) => c.suit == card.suit).toList();
      if (sameSuit.length >= 2) {
        sameSuit.sort((a, b) => a.rank.compareTo(b.rank));
        // 연속 카드 확인
        bool hasConsecutive = false;
        for (int i = 0; i < sameSuit.length - 1; i++) {
          if (sameSuit[i + 1].rank - sameSuit[i].rank <= 2) {
            hasConsecutive = true;
            break;
          }
        }
        if (hasConsecutive) {
          // 필요한 카드가 버려졌는지 확인
          final neededRanks = <int>[];
          for (final c in sameSuit) {
            neededRanks.addAll([c.rank - 1, c.rank + 1]);
          }
          final discardedNeeded = discardPile
              .where((c) => c.suit == card.suit && neededRanks.contains(c.rank))
              .length;
          probability += 15.0 * (1 - discardedNeeded / neededRanks.length);
        }
      }
    }

    // 남은 카드 수에 따른 페널티 (붙일 수 있는 카드 제외)
    final nonAttachable = remaining.length - attachableCount;
    final remainingPenalty = nonAttachable * 10.0;
    probability = (probability - remainingPenalty).clamp(0.0, 100.0);

    return probability;
  }

  // 다른 플레이어의 스톱 위험도 계산
  // 반환: 0.0 ~ 100.0 (높을수록 스톱 가능성 높음)
  double _estimateStopRisk(int myIndex) {
    double maxRisk = 0.0;

    // 플레이어(0) 체크
    if (myIndex != 0) {
      final playerRisk = _calculatePlayerStopRisk(playerHand, playerMelds);
      maxRisk = maxRisk > playerRisk ? maxRisk : playerRisk;
    }

    // 다른 컴퓨터들 체크
    for (int i = 0; i < computerHands.length; i++) {
      if (i + 1 == myIndex) continue; // 자신 제외

      final risk = _calculatePlayerStopRisk(computerHands[i], computerMelds[i]);
      maxRisk = maxRisk > risk ? maxRisk : risk;
    }

    return maxRisk;
  }

  // 특정 플레이어의 스톱 가능성 계산
  double _calculatePlayerStopRisk(List<PlayingCard> hand, List<Meld> melds) {
    double risk = 0.0;

    // 1. 손패 수에 따른 위험도 (적을수록 위험)
    // 3장 이하: 매우 위험, 5장 이하: 위험, 7장 이하: 주의
    if (hand.length <= 2) {
      risk += 80.0;
    } else if (hand.length <= 3) {
      risk += 60.0;
    } else if (hand.length <= 4) {
      risk += 40.0;
    } else if (hand.length <= 5) {
      risk += 25.0;
    } else if (hand.length <= 7) {
      risk += 10.0;
    }

    // 2. 등록된 멜드 수에 따른 위험도
    // 멜드가 많을수록 카드 정리가 잘 되어 있음
    if (melds.length >= 4) {
      risk += 30.0;
    } else if (melds.length >= 3) {
      risk += 20.0;
    } else if (melds.length >= 2) {
      risk += 10.0;
    }

    // 3. 손패 점수 추정 (낮을수록 스톱 가능성 높음)
    final handScore = _calculateHandScore(hand);
    if (handScore <= 5) {
      risk += 25.0;
    } else if (handScore <= 10) {
      risk += 15.0;
    } else if (handScore <= 20) {
      risk += 5.0;
    }

    // 4. 기존 멜드에 붙일 수 있는 카드 수 (멜드가 있을 때만)
    if (melds.isNotEmpty) {
      int attachableCount = 0;
      for (final card in hand) {
        // 자신의 멜드에 붙이기
        if (_canAttachToMeldList(card, melds) >= 0) {
          attachableCount++;
          continue;
        }
        // 플레이어 멜드에 붙이기
        if (playerMelds.isNotEmpty && _canAttachToMeldList(card, playerMelds) >= 0) {
          attachableCount++;
          continue;
        }
        // 컴퓨터 멜드에 붙이기
        for (final cMelds in computerMelds) {
          if (cMelds.isNotEmpty && _canAttachToMeldList(card, cMelds) >= 0) {
            attachableCount++;
            break;
          }
        }
      }
      // 붙일 수 있는 카드가 많을수록 위험도 증가
      if (attachableCount >= 3) {
        risk += 20.0;
      } else if (attachableCount >= 2) {
        risk += 12.0;
      } else if (attachableCount >= 1) {
        risk += 5.0;
      }
    }

    return risk.clamp(0.0, 100.0);
  }

  // 컴퓨터가 스톱을 외칠지 결정
  bool _shouldComputerCallStop(int computerIndex) {
    // 난이도에 따른 스톱 확률 (쉬움: 0%, 보통: 50%, 어려움: 100%)
    final difficulty = computerDifficulties.length > computerIndex
        ? computerDifficulties[computerIndex]
        : 2;
    if (difficulty == 0) return false; // 쉬운 난이도는 스톱 안 함

    final myHand = computerHands[computerIndex];
    final myScore = _calculateHandScore(myHand);

    // 1. 손패가 너무 많으면 스톱 안 함 (불리할 가능성)
    if (myHand.length > 5) return false;

    // 2. 내 점수가 너무 높으면 스톱 안 함
    if (myScore > 15) return false;

    // 3. 다른 플레이어 점수 추정 및 비교
    int betterCount = 0; // 나보다 점수가 낮을 것 같은 플레이어 수
    int totalPlayers = playerCount - 1; // 자신 제외
    bool someoneAboutToWin = false;

    // 플레이어 확인
    final playerScore = _calculateHandScore(playerHand);
    if (playerScore < myScore) {
      betterCount++;
    }
    if (playerHand.length <= 2) {
      someoneAboutToWin = true;
    }

    // 다른 컴퓨터 확인
    for (int i = 0; i < computerHands.length; i++) {
      if (i == computerIndex) continue;

      final otherHand = computerHands[i];
      final otherScore = _calculateHandScore(otherHand);

      if (otherScore < myScore) {
        betterCount++;
      }
      if (otherHand.length <= 2) {
        someoneAboutToWin = true;
      }
    }

    // 4. 스톱 결정 조건

    // 4-1. 내 점수가 0이면 무조건 스톱 (완벽)
    if (myScore == 0) return true;

    // 4-2. 상대가 곧 이길 것 같고 내 점수가 낮으면 선제 스톱
    if (someoneAboutToWin && myScore <= 5 && betterCount == 0) {
      return true;
    }

    // 4-3. 손패 2장 이하 & 점수 5점 이하 & 모든 상대보다 유리
    if (myHand.length <= 2 && myScore <= 5 && betterCount == 0) {
      return true;
    }

    // 4-4. 손패 3장 이하 & 점수 3점 이하 & 절반 이상 상대보다 유리
    if (myHand.length <= 3 && myScore <= 3 && betterCount <= totalPlayers / 2) {
      return true;
    }

    // 4-5. 손패 1장 & 점수 10점 이하 (거의 확실히 유리)
    if (myHand.length == 1 && myScore <= 10 && betterCount == 0) {
      // 보통 난이도는 50% 확률
      if (difficulty == 1 && Random().nextInt(100) >= 50) return false;
      return true;
    }

    return false;
  }

  // 컴퓨터가 스톱 선언
  void _computerCallStop(int computerIndex) {
    _showMessage('games.hula.computerStop'.tr(namedArgs: {'num': '${computerIndex + 1}'}));
    _calculateScoresAndEnd(stopperIndex: computerIndex + 1); // 컴퓨터 인덱스 + 1
  }

  // 멜드 등록 여부 결정 (훌라 가능성 + 스톱 위험도 고려)
  bool _shouldRegisterMelds(List<PlayingCard> hand, List<Meld> melds, {int? computerIndex}) {
    // 이미 멜드가 있으면 훌라 불가능 → 등록해도 됨
    if (melds.isNotEmpty) return true;

    final analysis = _analyzeHulaPotential(hand, melds);

    // 훌라 가능하면 즉시 등록 (승리)
    if (analysis['canHula'] == true) return true;

    final probability = analysis['probability'] as double;
    final remainingCount = analysis['remainingCount'] as int;

    // 스톱 위험도 계산
    final myIndex = computerIndex ?? 0;
    final stopRisk = _estimateStopRisk(myIndex);
    final myHandScore = _calculateHandScore(hand);

    // 스톱 위험도가 높으면 등록하여 벌점 최소화
    // 위험도 70% 이상이고 내 손패 점수가 높으면 즉시 등록
    if (stopRisk >= 70.0 && myHandScore >= 15) {
      return true; // 방어적 등록
    }

    // 위험도 50% 이상이고 내 손패 점수가 매우 높으면 등록
    if (stopRisk >= 50.0 && myHandScore >= 25) {
      return true;
    }

    // 훌라 확률 vs 스톱 위험도 비교
    // 스톱 위험도가 훌라 확률보다 높으면 등록 고려
    if (stopRisk > probability && stopRisk >= 40.0) {
      // 단, 훌라가 거의 완성 상태면 (남은 카드 1장) 계속 시도
      if (remainingCount <= 1 && probability >= 50.0) {
        return false; // 훌라 시도 계속
      }
      return true; // 방어적 등록
    }

    // 훌라 확률이 높으면 대기
    // 60% 이상이고 남은 카드가 3장 이하면 훌라 시도
    if (probability >= 60.0 && remainingCount <= 3) {
      // 단, 스톱 위험도가 매우 높으면 등록
      if (stopRisk >= 60.0) {
        return true;
      }
      return false; // 등록 대기
    }

    // 손패가 많으면 일단 등록 (방어적)
    if (hand.length >= 10) return true;

    // 확률이 40% 이상이고 남은 카드가 2장 이하면 대기
    if (probability >= 40.0 && remainingCount <= 2) {
      // 단, 스톱 위험도가 높으면 등록
      if (stopRisk >= 50.0) {
        return true;
      }
      return false;
    }

    // 그 외에는 등록
    return true;
  }

  // 7 카드 3장 이상일 때 Group vs Run 전략 결정
  String _decideSevensStrategy(List<PlayingCard> sevens, List<PlayingCard> hand) {
    // Run 가능성 점수 계산
    double runPotential = 0;
    // Group 점수 (기본값: 3장 즉시 제거)
    double groupScore = 30;

    for (final seven in sevens) {
      final suit = seven.suit;

      // 손에 있는 6, 8 확인
      final hasSix = hand.any((c) => c.suit == suit && c.rank == 6);
      final hasEight = hand.any((c) => c.suit == suit && c.rank == 8);

      // 손에 있는 5, 9 확인 (더 긴 Run 가능성)
      final hasFive = hand.any((c) => c.suit == suit && c.rank == 5);
      final hasNine = hand.any((c) => c.suit == suit && c.rank == 9);

      // 버린 더미에서 6, 8 확인
      final discardedSix = discardPile.where((c) => c.suit == suit && c.rank == 6).length;
      final discardedEight = discardPile.where((c) => c.suit == suit && c.rank == 8).length;

      // Run 가능성 계산
      double sevenRunScore = 0;

      // 이미 6 또는 8을 가지고 있으면 Run 유리
      if (hasSix) sevenRunScore += 25;
      if (hasEight) sevenRunScore += 25;

      // 5 또는 9도 있으면 긴 Run 가능
      if (hasSix && hasFive) sevenRunScore += 15;
      if (hasEight && hasNine) sevenRunScore += 15;

      // 6, 8이 버려졌으면 Run 확률 낮음
      // 같은 숫자는 4장뿐이므로 2장 이상 버려지면 확률 낮음
      if (discardedSix >= 2) sevenRunScore -= 20;
      if (discardedEight >= 2) sevenRunScore -= 20;
      if (discardedSix == 1) sevenRunScore -= 5;
      if (discardedEight == 1) sevenRunScore -= 5;

      // 6, 8 모두 없고 버려진 것도 많으면 Run 불가능에 가까움
      if (!hasSix && !hasEight && discardedSix + discardedEight >= 2) {
        sevenRunScore -= 30;
      }

      runPotential += sevenRunScore;
    }

    // 평균 Run 가능성
    runPotential /= sevens.length;

    // Group 점수 조정
    // 4번째 7이 손에 있으면 Group 유리
    if (sevens.length >= 4) {
      groupScore += 20;
    }

    // 방어적 관점: 손패가 많으면 빨리 줄이는 Group 선호
    if (hand.length > 10) {
      groupScore += 15;
    }

    // 공격적 관점: 손패가 적으면 Run으로 더 많이 붙이기 선호
    if (hand.length <= 5) {
      runPotential += 10;
    }

    // 결정
    if (runPotential > groupScore) {
      return 'run';
    } else {
      return 'group';
    }
  }

  // 멜드 등록
  void _registerMeld() {
    final selectedCards =
        selectedCardIndices.map((i) => playerHand[i]).toList();

    // 7 카드 단독 등록 (훌라 특별 규칙)
    if (selectedCardIndices.length == 1 && _isSeven(selectedCards.first)) {
      final card = selectedCards.first;
      playerHand.remove(card);
      playerMelds.add(Meld(cards: [card], isRun: false));

      setState(() {
        selectedCardIndices = [];
      });
      _showMessage('games.hula.registered7Alone'.tr());
      _saveGame();

      if (playerHand.isEmpty) {
        _playerWins();
      }
      return;
    }

    // 1~2장 선택: 기존 멜드에 붙이기 시도 (플레이어 + 컴퓨터 멜드)
    if (selectedCardIndices.length < 3) {
      // 각 카드에 대해 붙이기 가능 여부 확인
      bool attached = false;
      for (final card in selectedCards) {
        // 1. 플레이어 멜드에 붙이기 시도
        final playerMeldIndex = _canAttachToMeld(card);
        if (playerMeldIndex >= 0) {
          _attachToMeld(playerMeldIndex, card);
          playerHand.remove(card);
          attached = true;
          continue;
        }

        // 2. 컴퓨터 멜드에 붙이기 시도
        for (int c = 0; c < computerMelds.length; c++) {
          final compMeldIndex = _canAttachToMeldList(card, computerMelds[c]);
          if (compMeldIndex >= 0) {
            _attachToMeldList(compMeldIndex, card, computerMelds[c]);
            playerHand.remove(card);
            attached = true;
            break;
          }
        }
      }

      if (attached) {
        setState(() {
          selectedCardIndices = [];
        });
        _showMessage('games.hula.addedToMeld'.tr());
        _saveGame();

        if (playerHand.isEmpty) {
          _playerWins();
        }
        return;
      }

      _showMessage('games.hula.noMeldToAttach'.tr());
      return;
    }

    // 3장 이상: 새 멜드 등록
    if (!_isValidMeld(selectedCards)) {
      _showMessage('games.hula.invalidCombination'.tr());
      return;
    }

    final isRun = _isValidRun(selectedCards);

    // 카드 제거 (역순으로)
    for (int i = selectedCardIndices.length - 1; i >= 0; i--) {
      playerHand.removeAt(selectedCardIndices[i]);
    }

    playerMelds.add(Meld(cards: selectedCards, isRun: isRun));

    setState(() {
      selectedCardIndices = [];
    });

    _showMessage(isRun ? 'games.hula.registeredRun'.tr() : 'games.hula.registeredGroup'.tr());
    _saveGame();

    // 손패가 비었으면 승리
    if (playerHand.isEmpty) {
      _playerWins();
    }
  }

  // 카드 버리기
  void _discardCard() {
    if (!hasDrawn) {
      _showMessage('games.hula.drawFirst'.tr());
      return;
    }
    if (selectedCardIndices.length != 1) {
      _showMessage('games.hula.selectOneToDiscard'.tr());
      return;
    }

    final cardIndex = selectedCardIndices.first;
    final card = playerHand.removeAt(cardIndex);
    discardPile.add(card);

    setState(() {
      selectedCardIndices = [];
      hasDrawn = false;
    });

    _showMessage('games.hula.discardedCard'.tr(namedArgs: {'card': '${card.suitSymbol}${card.rankString}'}));
    _saveGame();

    // 손패가 비었으면 승리
    if (playerHand.isEmpty) {
      _playerWins();
      return;
    }

    // 땡큐 확인: 플레이어 전 순서 컴퓨터는 즉시, 후 순서는 10초 후
    _lastDiscardTurn = 0;
    Timer(const Duration(milliseconds: 300), () {
      if (mounted && !gameOver) {
        // 1. 플레이어 전 순서 컴퓨터 땡큐 확인 (즉시)
        final beforeResult = _checkComputerThankYouBeforePlayer(0);
        if (beforeResult != null) {
          _executeComputerThankYou(beforeResult);
        } else {
          // 2. 플레이어 후 순서 컴퓨터가 있으면 10초 대기
          _startThankYouWait();
        }
      }
    });
  }

  // 땡큐 대기 시작 (플레이어에게 기회 부여)
  void _startThankYouWait() {
    // 플레이어가 땡큐 가능한지 확인
    final canPlayerThankYou = _canThankYou();

    setState(() {
      currentTurn = (currentTurn + 1) % playerCount;
      hasDrawn = false;
      selectedCardIndices = [];
      waitingForNextTurn = currentTurn == 0; // 플레이어 턴일 때만 대기 상태
    });
    _saveGame();

    if (currentTurn != 0) {
      // 다음이 컴퓨터 턴인데 플레이어가 땡큐 가능하면 대기 시간 부여
      if (canPlayerThankYou) {
        _startThankYouCountdown();
      } else {
        // 땡큐 불가능하면 바로 진행
        Timer(const Duration(milliseconds: 300), () {
          if (mounted && !gameOver) {
            _onNextTurn();
          }
        });
      }
    } else {
      // 플레이어 턴: 메시지 타이머만 취소 (메시지 유지)
      _messageTimer?.cancel();
    }
  }

  // 땡큐 대기 카운트다운 시작
  void _startThankYouCountdown() {
    _thankYouTimer?.cancel();
    setState(() {
      _thankYouWaiting = true;
      _thankYouCountdown = _thankYouWaitSeconds;
    });

    _thankYouTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || gameOver) {
        timer.cancel();
        return;
      }

      setState(() {
        _thankYouCountdown--;
      });

      if (_thankYouCountdown <= 0) {
        timer.cancel();
        _endThankYouWait();
      }
    });
  }

  // 땡큐 대기 종료 (시간 초과 또는 플레이어가 땡큐/패스)
  void _endThankYouWait() {
    _thankYouTimer?.cancel();
    setState(() {
      _thankYouWaiting = false;
      _thankYouCountdown = 0;
    });

    if (mounted && !gameOver && currentTurn != 0) {
      // 플레이어 후 순서 컴퓨터 땡큐 확인
      final afterResult = _checkComputerThankYouAfterPlayer(_lastDiscardTurn);
      if (afterResult != null) {
        _executeComputerThankYou(afterResult);
      } else {
        _onNextTurn();
      }
    }
  }

  void _playerWins() {
    // 등록 없이 한 번에 다 냈으면 훌라
    isHula = playerMelds.isEmpty && playerHand.isEmpty;
    _endGame(0);
  }

  void _endTurn() {
    if (gameOver) return;

    setState(() {
      currentTurn = (currentTurn + 1) % playerCount;
      hasDrawn = false;
      selectedCardIndices = [];
      waitingForNextTurn = currentTurn == 0; // 플레이어 턴일 때만 대기 상태
    });
    _saveGame();

    if (currentTurn != 0) {
      // 컴퓨터 턴: 타이머 없이 바로 진행 (드로우 후 타이머가 동작함)
      Timer(const Duration(milliseconds: 300), () {
        if (mounted && !gameOver) {
          _computerTurn();
        }
      });
    } else {
      // 플레이어 턴: 타이머 없이 대기 (동작할 때까지 유지)
      _messageTimer?.cancel();
    }
  }

  void _computerTurn() {
    if (gameOver) return;
    _computerActionTimer?.cancel();

    final computerIndex = currentTurn - 1;
    final hand = computerHands[computerIndex];
    final melds = computerMelds[computerIndex];

    // 난이도에 따른 땡큐(드로우) 확률 (쉬움: 50%, 보통: 80%, 어려움: 100%)
    final difficulty = computerDifficulties.length > computerIndex
        ? computerDifficulties[computerIndex]
        : 2;
    final drawDiscardChance = difficulty == 0 ? 50 : (difficulty == 1 ? 80 : 100);

    // 1. 드로우 (버린 더미 or 덱)
    PlayingCard drawnCard;
    final topDiscard = discardPile.isNotEmpty ? discardPile.last : null;

    // 버린 카드가 멜드에 도움이 되면 가져오기 (난이도 적용)
    bool takeDiscard = false;
    if (topDiscard != null && Random().nextInt(100) < drawDiscardChance) {
      // 7 카드는 단독 등록 가능하므로 항상 가져오기
      if (_isSeven(topDiscard)) {
        takeDiscard = true;
      } else {
        final testHand = [...hand, topDiscard];
        if (_findBestMeld(testHand) != null) {
          takeDiscard = true;
        }
      }
    }

    if (takeDiscard && discardPile.isNotEmpty) {
      drawnCard = discardPile.removeLast();
      _showMessage('games.hula.computerThankYou'.tr(namedArgs: {'num': '${computerIndex + 1}', 'card': '${drawnCard.suitSymbol}${drawnCard.rankString}'}));
    } else {
      if (deck.isEmpty && discardPile.length > 1) {
        final topCard = discardPile.removeLast();
        deck = List.from(discardPile);
        deck.shuffle(Random());
        discardPile = [topCard];
      }
      if (deck.isEmpty) {
        _endTurn();
        return;
      }
      drawnCard = deck.removeLast();
      _showMessage('games.hula.computerDrew'.tr(namedArgs: {'num': '${computerIndex + 1}'}));
    }

    hand.add(drawnCard);
    _sortHand(hand);
    setState(() {});
    _saveGame();

    // 드로우 후 대기 상태로 전환 (1초 타이머)
    _startWaitWithAction(() => _computerTurnRegister(computerIndex), seconds: 1);
  }

  // 컴퓨터 턴 - 멜드 등록 단계
  void _computerTurnRegister(int computerIndex) {
    if (gameOver) return;

    final hand = computerHands[computerIndex];
    final melds = computerMelds[computerIndex];

    // 훌라 가능성 확인 후 등록 여부 결정 (스톱 위험도 포함)
    // 훌라 시도 중이면 7도 등록하지 않음 (0점이므로 손해 없음)
    final shouldRegister = _shouldRegisterMelds(hand, melds, computerIndex: computerIndex + 1);

    if (!shouldRegister) {
      _computerTurnDiscard(computerIndex);
      return;
    }

    // 등록할 멜드 수집
    final meldsToRegister = <Map<String, dynamic>>[];

    // 7 카드 먼저 등록 (가장 우선순위)
    final testHand = List<PlayingCard>.from(hand);
    final sevens = testHand.where((c) => _isSeven(c)).toList();
    if (sevens.isNotEmpty) {
      if (sevens.length >= 3) {
        final decision = _decideSevensStrategy(sevens, testHand);
        if (decision == 'group') {
          meldsToRegister.add({'cards': sevens.take(3).toList(), 'isRun': false, 'type': '7group'});
          for (final seven in sevens.skip(3)) {
            meldsToRegister.add({'cards': [seven], 'isRun': false, 'type': '7'});
          }
        } else {
          for (final seven in sevens) {
            meldsToRegister.add({'cards': [seven], 'isRun': false, 'type': '7'});
          }
        }
      } else {
        for (final seven in sevens) {
          meldsToRegister.add({'cards': [seven], 'isRun': false, 'type': '7'});
        }
      }
      // testHand에서 7 제거
      for (final seven in sevens) {
        testHand.remove(seven);
      }
    }

    // 일반 멜드 찾기 (7 카드 제외된 상태)
    List<PlayingCard>? bestMeld;
    while ((bestMeld = _findBestMeld(testHand)) != null) {
      final isRun = _isValidRun(bestMeld!);
      meldsToRegister.add({'cards': List<PlayingCard>.from(bestMeld), 'isRun': isRun, 'type': 'meld'});
      for (final card in bestMeld) {
        testHand.remove(card);
      }
    }

    // 순차적으로 등록 실행
    _computerRegisterMeldsSequentially(computerIndex, meldsToRegister, 0);
  }

  // 멜드를 순차적으로 등록 (대기 상태 포함)
  void _computerRegisterMeldsSequentially(int computerIndex, List<Map<String, dynamic>> meldsToRegister, int index) {
    if (gameOver) return;
    if (index >= meldsToRegister.length) {
      // 모든 등록 완료, 붙여놓기 단계로 (타이머 없이 바로 진행)
      _computerTurnAttach(computerIndex);
      return;
    }

    final hand = computerHands[computerIndex];
    final melds = computerMelds[computerIndex];
    final meldData = meldsToRegister[index];
    final cards = meldData['cards'] as List<PlayingCard>;
    final isRun = meldData['isRun'] as bool;
    final type = meldData['type'] as String;

    // 카드가 손에 있는지 확인
    bool allCardsInHand = cards.every((c) => hand.contains(c));
    if (!allCardsInHand) {
      // 이미 처리된 카드, 다음으로
      _computerRegisterMeldsSequentially(computerIndex, meldsToRegister, index + 1);
      return;
    }

    // 멜드 등록
    for (final card in cards) {
      hand.remove(card);
    }
    melds.add(Meld(cards: cards, isRun: isRun));

    // 메시지 표시
    if (type == '7group') {
      _showMessage('games.hula.computerRegister7Group'.tr(namedArgs: {'num': '${computerIndex + 1}'}));
    } else if (type == '7') {
      _showMessage('games.hula.computerRegister7'.tr(namedArgs: {'num': '${computerIndex + 1}'}));
    } else {
      final cardStr = cards.map((c) => '${c.suitSymbol}${c.rankString}').join(' ');
      _showMessage('games.hula.computerRegisterMeld'.tr(namedArgs: {'num': '${computerIndex + 1}', 'type': isRun ? 'Run' : 'Group', 'cards': cardStr}));
    }

    setState(() {});
    _saveGame();

    if (hand.isEmpty) {
      _endGame(currentTurn);
      return;
    }

    // 등록 후 대기 상태로 전환 (다음 등록 또는 붙여놓기 단계)
    _startWaitWithAction(() => _computerRegisterMeldsSequentially(computerIndex, meldsToRegister, index + 1));
  }

  // 컴퓨터 턴 - 붙여놓기 단계
  void _computerTurnAttach(int computerIndex) {
    if (gameOver) return;

    final hand = computerHands[computerIndex];
    final melds = computerMelds[computerIndex];

    // 자신의 멜드가 없으면 붙여놓기 불가 (훌라 규칙)
    if (melds.isEmpty) {
      _computerTurnDiscard(computerIndex);
      return;
    }

    // 난이도에 따른 붙여놓기 확률 (쉬움: 50%, 보통: 80%, 어려움: 100%)
    final difficulty = computerDifficulties.length > computerIndex
        ? computerDifficulties[computerIndex]
        : 2;
    final attachChance = difficulty == 0 ? 50 : (difficulty == 1 ? 80 : 100);

    // 붙일 수 있는 카드 찾기
    for (int i = hand.length - 1; i >= 0; i--) {
      final card = hand[i];

      // 자신의 멜드에 붙이기
      final ownMeldIndex = _canAttachToMeldList(card, melds);
      if (ownMeldIndex >= 0 && Random().nextInt(100) < attachChance) {
        _attachToMeldList(ownMeldIndex, card, melds);
        hand.removeAt(i);
        _showMessage('games.hula.computerAttach'.tr(namedArgs: {'num': '${computerIndex + 1}', 'card': '${card.suitSymbol}${card.rankString}'}));
        setState(() {});
        _saveGame();

        if (hand.isEmpty) {
          _endGame(currentTurn);
          return;
        }

        // 붙이기 후 대기 상태로 전환
        _startWaitWithAction(() => _computerTurnAttach(computerIndex));
        return;
      }

      // 플레이어 멜드에 붙이기
      final playerMeldIndex = _canAttachToMeldList(card, playerMelds);
      if (playerMeldIndex >= 0 && Random().nextInt(100) < attachChance) {
        _attachToMeldList(playerMeldIndex, card, playerMelds);
        hand.removeAt(i);
        _showMessage('games.hula.computerAttachToPlayer'.tr(namedArgs: {'num': '${computerIndex + 1}', 'card': '${card.suitSymbol}${card.rankString}'}));
        setState(() {});
        _saveGame();

        if (hand.isEmpty) {
          _endGame(currentTurn);
          return;
        }

        // 붙이기 후 대기 상태로 전환
        _startWaitWithAction(() => _computerTurnAttach(computerIndex));
        return;
      }

      // 다른 컴퓨터 멜드에 붙이기
      for (int c = 0; c < computerMelds.length; c++) {
        if (c == computerIndex) continue;
        final otherMeldIndex = _canAttachToMeldList(card, computerMelds[c]);
        if (otherMeldIndex >= 0 && Random().nextInt(100) < attachChance) {
          _attachToMeldList(otherMeldIndex, card, computerMelds[c]);
          hand.removeAt(i);
          _showMessage('games.hula.computerAttachToComputer'.tr(namedArgs: {'num': '${computerIndex + 1}', 'card': '${card.suitSymbol}${card.rankString}', 'target': '${c + 1}'}));
          setState(() {});
          _saveGame();

          if (hand.isEmpty) {
            _endGame(currentTurn);
            return;
          }

          // 붙이기 후 대기 상태로 전환
          _startWaitWithAction(() => _computerTurnAttach(computerIndex));
          return;
        }
      }
    }

    // 붙일 카드 없음, 버리기 단계로
    _computerTurnDiscard(computerIndex);
  }

  // 컴퓨터 턴 - 버리기 단계
  void _computerTurnDiscard(int computerIndex) {
    if (gameOver) return;

    final hand = computerHands[computerIndex];
    final melds = computerMelds[computerIndex];

    // 손에 7이 있고, 이미 멜드가 있으면 (훌라 불가능) 7 등록
    // 훌라 시도 중(melds.isEmpty)이면 7을 손에 보유 (0점이므로 손해 없음)
    final sevens = hand.where((c) => _isSeven(c)).toList();
    if (sevens.isNotEmpty && melds.isNotEmpty) {
      final seven = sevens.first;
      hand.remove(seven);
      melds.add(Meld(cards: [seven], isRun: false));
      _showMessage('games.hula.computerRegister7'.tr(namedArgs: {'num': '${computerIndex + 1}'}));
      setState(() {});
      _saveGame();

      if (hand.isEmpty) {
        _endGame(currentTurn);
        return;
      }

      // 딜레이 후 다시 버리기 단계
      _computerActionTimer = Timer(Duration(milliseconds: _computerActionDelay), () {
        if (mounted && !gameOver) {
          _computerTurnDiscard(computerIndex);
        }
      });
      return;
    }

    // 스마트 카드 버리기 (난이도 적용)
    final discardCard = _selectCardToDiscard(hand, computerIndex: computerIndex);
    hand.remove(discardCard);
    discardPile.add(discardCard);
    _sortHand(hand);

    _showMessage('${'games.hula.computer'.tr(namedArgs: {'num': '${computerIndex + 1}'})}: ${discardCard.suitSymbol}${discardCard.rankString} ${'games.hula.discarded'.tr()}');
    setState(() {});
    _saveGame();

    if (hand.isEmpty) {
      _endGame(currentTurn);
      return;
    }

    // 스톱 호출 여부 확인
    if (_shouldComputerCallStop(computerIndex)) {
      _computerCallStop(computerIndex);
      return;
    }

    // 땡큐 확인: 플레이어 전 순서 컴퓨터는 즉시, 후 순서는 10초 후
    _lastDiscardTurn = currentTurn;
    _computerActionTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && !gameOver) {
        // 1. 플레이어 전 순서 컴퓨터 땡큐 확인 (즉시)
        final beforeResult = _checkComputerThankYouBeforePlayer(currentTurn);
        if (beforeResult != null) {
          _executeComputerThankYou(beforeResult);
        } else {
          // 2. 플레이어에게 10초 기회 부여 후 플레이어 후 순서 컴퓨터 확인
          _startThankYouWait();
        }
      }
    });
  }

  // 컴퓨터가 땡큐할 수 있는지 확인
  // beforePlayer: true면 플레이어 전 순서만, false면 플레이어 후 순서만
  int? _checkComputerThankYou(int fromTurn, {bool? beforePlayer}) {
    if (discardPile.isEmpty) return null;
    final topCard = discardPile.last;
    final random = Random();

    // fromTurn 다음 순서부터 확인
    bool passedPlayer = false;
    for (int i = 1; i < playerCount; i++) {
      final checkTurn = (fromTurn + i) % playerCount;

      if (checkTurn == 0) {
        passedPlayer = true;
        continue; // 플레이어는 건너뜀 (플레이어는 버튼으로 땡큐)
      }

      // beforePlayer 필터링
      if (beforePlayer == true && passedPlayer) continue; // 플레이어 전만 확인
      if (beforePlayer == false && !passedPlayer) continue; // 플레이어 후만 확인

      final computerIndex = checkTurn - 1;
      if (computerIndex < 0 || computerIndex >= computerHands.length) continue;
      final hand = computerHands[computerIndex];

      // 난이도에 따른 땡큐 확률 (쉬움: 50%, 보통: 80%, 어려움: 100%)
      final difficulty = computerDifficulties.length > computerIndex
          ? computerDifficulties[computerIndex]
          : 2;
      final thankYouChance = difficulty == 0 ? 50 : (difficulty == 1 ? 80 : 100);

      bool shouldThankYou = false;

      // 7 카드는 항상 땡큐 (난이도 적용)
      if (_isSeven(topCard)) {
        shouldThankYou = true;
      } else {
        // 멜드를 만들 수 있으면 땡큐
        final testHand = [...hand, topCard];
        if (_findBestMeld(testHand) != null) {
          shouldThankYou = true;
        }
      }

      if (shouldThankYou) {
        // 난이도에 따른 확률 체크
        if (random.nextInt(100) < thankYouChance) {
          return computerIndex;
        }
      }
    }
    return null;
  }

  // 플레이어 전 순서 컴퓨터만 땡큐 확인 (즉시 실행)
  int? _checkComputerThankYouBeforePlayer(int fromTurn) {
    return _checkComputerThankYou(fromTurn, beforePlayer: true);
  }

  // 플레이어 후 순서 컴퓨터만 땡큐 확인 (10초 후 실행)
  int? _checkComputerThankYouAfterPlayer(int fromTurn) {
    return _checkComputerThankYou(fromTurn, beforePlayer: false);
  }

  // 컴퓨터 땡큐 실행
  void _executeComputerThankYou(int computerIndex) {
    if (discardPile.isEmpty) return;
    _computerActionTimer?.cancel();

    // ★ 플레이어 땡큐 대기 상태 해제 (AI가 먼저 땡큐함)
    _thankYouTimer?.cancel();
    _thankYouWaiting = false;
    _thankYouCountdown = 0;

    // 땡큐한 컴퓨터의 턴으로 설정
    currentTurn = computerIndex + 1;

    final card = discardPile.removeLast();
    final hand = computerHands[computerIndex];

    hand.add(card);
    _sortHand(hand);
    _showMessage('games.hula.computerThankYou'.tr(namedArgs: {'num': '${computerIndex + 1}', 'card': '${card.suitSymbol}${card.rankString}'}));
    setState(() {});
    _saveGame();

    // 땡큐 후 바로 등록 단계로 진행 (등록 후 타이머가 동작함)
    Timer(const Duration(milliseconds: 300), () {
      if (mounted && !gameOver) {
        _executeComputerThankYouRegister(computerIndex);
      }
    });
  }

  // 컴퓨터 땡큐 후 - 멜드 등록 단계
  void _executeComputerThankYouRegister(int computerIndex) {
    if (gameOver) return;

    final hand = computerHands[computerIndex];
    final melds = computerMelds[computerIndex];

    // 훌라 가능성 확인 후 등록 여부 결정 (스톱 위험도 포함)
    final shouldRegister = _shouldRegisterMelds(hand, melds, computerIndex: computerIndex + 1);

    if (!shouldRegister) {
      _computerDiscardAfterThankYou(computerIndex);
      return;
    }

    // 등록할 멜드 수집
    final meldsToRegister = <Map<String, dynamic>>[];

    // 일반 멜드 찾기
    final testHand = List<PlayingCard>.from(hand);
    List<PlayingCard>? bestMeld;
    while ((bestMeld = _findBestMeld(testHand)) != null) {
      final isRun = _isValidRun(bestMeld!);
      meldsToRegister.add({'cards': List<PlayingCard>.from(bestMeld), 'isRun': isRun, 'type': 'meld'});
      for (final card in bestMeld) {
        testHand.remove(card);
      }
    }

    // 7 카드 찾기
    final sevens = testHand.where((c) => _isSeven(c)).toList();
    if (sevens.length >= 3) {
      final decision = _decideSevensStrategy(sevens, testHand);
      if (decision == 'group') {
        meldsToRegister.add({'cards': sevens.take(3).toList(), 'isRun': false, 'type': '7group'});
        for (final seven in sevens.skip(3)) {
          meldsToRegister.add({'cards': [seven], 'isRun': false, 'type': '7'});
        }
      } else {
        for (final seven in sevens) {
          meldsToRegister.add({'cards': [seven], 'isRun': false, 'type': '7'});
        }
      }
    } else {
      for (final seven in sevens) {
        meldsToRegister.add({'cards': [seven], 'isRun': false, 'type': '7'});
      }
    }

    // 순차적으로 등록 실행
    _executeComputerThankYouRegisterSequentially(computerIndex, meldsToRegister, 0);
  }

  // 땡큐 후 멜드를 순차적으로 등록 (대기 상태 포함)
  void _executeComputerThankYouRegisterSequentially(int computerIndex, List<Map<String, dynamic>> meldsToRegister, int index) {
    if (gameOver) return;
    if (index >= meldsToRegister.length) {
      // 모든 등록 완료, 붙여놓기 단계로 (타이머 없이 바로 진행)
      _executeComputerThankYouAttach(computerIndex);
      return;
    }

    final hand = computerHands[computerIndex];
    final melds = computerMelds[computerIndex];
    final meldData = meldsToRegister[index];
    final cards = meldData['cards'] as List<PlayingCard>;
    final isRun = meldData['isRun'] as bool;
    final type = meldData['type'] as String;

    // 카드가 손에 있는지 확인
    bool allCardsInHand = cards.every((c) => hand.contains(c));
    if (!allCardsInHand) {
      // 이미 처리된 카드, 다음으로
      _executeComputerThankYouRegisterSequentially(computerIndex, meldsToRegister, index + 1);
      return;
    }

    // 멜드 등록
    for (final card in cards) {
      hand.remove(card);
    }
    melds.add(Meld(cards: cards, isRun: isRun));

    // 메시지 표시
    if (type == '7group') {
      _showMessage('games.hula.computerRegister7Group'.tr(namedArgs: {'num': '${computerIndex + 1}'}));
    } else if (type == '7') {
      _showMessage('games.hula.computerRegister7'.tr(namedArgs: {'num': '${computerIndex + 1}'}));
    } else {
      final cardStr = cards.map((c) => '${c.suitSymbol}${c.rankString}').join(' ');
      _showMessage('games.hula.computerRegisterMeld'.tr(namedArgs: {'num': '${computerIndex + 1}', 'type': isRun ? 'Run' : 'Group', 'cards': cardStr}));
    }

    setState(() {});
    _saveGame();

    if (hand.isEmpty) {
      _endGame(computerIndex + 1);
      return;
    }

    // 등록 후 대기 상태로 전환
    _startWaitWithAction(() => _executeComputerThankYouRegisterSequentially(computerIndex, meldsToRegister, index + 1));
  }

  // 컴퓨터 땡큐 후 - 붙여놓기 단계
  void _executeComputerThankYouAttach(int computerIndex) {
    if (gameOver) return;

    final hand = computerHands[computerIndex];
    final melds = computerMelds[computerIndex];

    // 자신의 멜드가 없으면 붙여놓기 불가 (훌라 규칙)
    if (melds.isEmpty) {
      _computerDiscardAfterThankYou(computerIndex);
      return;
    }

    // 난이도에 따른 붙여놓기 확률 (쉬움: 50%, 보통: 80%, 어려움: 100%)
    final difficulty = computerDifficulties.length > computerIndex
        ? computerDifficulties[computerIndex]
        : 2;
    final attachChance = difficulty == 0 ? 50 : (difficulty == 1 ? 80 : 100);

    // 붙일 수 있는 카드 찾기
    for (int i = hand.length - 1; i >= 0; i--) {
      final card = hand[i];

      // 자신의 멜드에 붙이기
      final ownMeldIndex = _canAttachToMeldList(card, melds);
      if (ownMeldIndex >= 0 && Random().nextInt(100) < attachChance) {
        _attachToMeldList(ownMeldIndex, card, melds);
        hand.removeAt(i);
        _showMessage('games.hula.computerAttach'.tr(namedArgs: {'num': '${computerIndex + 1}', 'card': '${card.suitSymbol}${card.rankString}'}));
        setState(() {});
        _saveGame();

        if (hand.isEmpty) {
          _endGame(computerIndex + 1);
          return;
        }

        // 붙이기 후 대기 상태로 전환
        _startWaitWithAction(() => _executeComputerThankYouAttach(computerIndex));
        return;
      }

      // 플레이어 멜드에 붙이기
      final playerMeldIndex = _canAttachToMeldList(card, playerMelds);
      if (playerMeldIndex >= 0 && Random().nextInt(100) < attachChance) {
        _attachToMeldList(playerMeldIndex, card, playerMelds);
        hand.removeAt(i);
        _showMessage('games.hula.computerAttachToPlayer'.tr(namedArgs: {'num': '${computerIndex + 1}', 'card': '${card.suitSymbol}${card.rankString}'}));
        setState(() {});
        _saveGame();

        if (hand.isEmpty) {
          _endGame(computerIndex + 1);
          return;
        }

        // 붙이기 후 대기 상태로 전환
        _startWaitWithAction(() => _executeComputerThankYouAttach(computerIndex));
        return;
      }

      // 다른 컴퓨터 멜드에 붙이기
      for (int c = 0; c < computerMelds.length; c++) {
        if (c == computerIndex) continue;
        final otherMeldIndex = _canAttachToMeldList(card, computerMelds[c]);
        if (otherMeldIndex >= 0 && Random().nextInt(100) < attachChance) {
          _attachToMeldList(otherMeldIndex, card, computerMelds[c]);
          hand.removeAt(i);
          _showMessage('games.hula.computerAttachToComputer'.tr(namedArgs: {'num': '${computerIndex + 1}', 'card': '${card.suitSymbol}${card.rankString}', 'target': '${c + 1}'}));
          setState(() {});
          _saveGame();

          if (hand.isEmpty) {
            _endGame(computerIndex + 1);
            return;
          }

          // 붙이기 후 대기 상태로 전환
          _startWaitWithAction(() => _executeComputerThankYouAttach(computerIndex));
          return;
        }
      }
    }

    // 붙일 카드 없음, 버리기 단계로
    _computerDiscardAfterThankYou(computerIndex);
  }

  // 땡큐 후 컴퓨터가 카드 버리기
  void _computerDiscardAfterThankYou(int computerIndex) {
    final hand = computerHands[computerIndex];
    final melds = computerMelds[computerIndex];

    // 손에 7이 있으면 먼저 등록
    final sevens = hand.where((c) => _isSeven(c)).toList();
    if (sevens.isNotEmpty) {
      final seven = sevens.first;
      hand.remove(seven);
      melds.add(Meld(cards: [seven], isRun: false));
      _showMessage('games.hula.computerRegister7'.tr(namedArgs: {'num': '${computerIndex + 1}'}));
      setState(() {});
      _saveGame();

      if (hand.isEmpty) {
        _endGame(computerIndex + 1);
        return;
      }

      // 딜레이 후 다시 버리기 단계
      _computerActionTimer = Timer(Duration(milliseconds: _computerActionDelay), () {
        if (mounted && !gameOver) {
          _computerDiscardAfterThankYou(computerIndex);
        }
      });
      return;
    }

    // 스마트 카드 버리기 (난이도 적용)
    final discardCard = _selectCardToDiscard(hand, computerIndex: computerIndex);
    hand.remove(discardCard);
    discardPile.add(discardCard);
    _sortHand(hand);

    _showMessage('${'games.hula.computer'.tr(namedArgs: {'num': '${computerIndex + 1}'})}: ${discardCard.suitSymbol}${discardCard.rankString} ${'games.hula.discarded'.tr()}');
    setState(() {});
    _saveGame();

    if (hand.isEmpty) {
      _endGame(computerIndex + 1);
      return;
    }

    // 스톱 호출 여부 확인
    if (_shouldComputerCallStop(computerIndex)) {
      _computerCallStop(computerIndex);
      return;
    }

    // 땡큐 확인: 플레이어 전 순서 컴퓨터는 즉시, 후 순서는 10초 후
    final discardTurn = computerIndex + 1;
    _lastDiscardTurn = discardTurn;
    Timer(const Duration(milliseconds: 500), () {
      if (mounted && !gameOver) {
        // 1. 플레이어 전 순서 컴퓨터 땡큐 확인 (즉시)
        final beforeResult = _checkComputerThankYouBeforePlayer(discardTurn);
        if (beforeResult != null) {
          _executeComputerThankYou(beforeResult);
        } else {
          // 2. 플레이어에게 10초 기회 부여 후 플레이어 후 순서 컴퓨터 확인
          _startThankYouWait();
        }
      }
    });
  }

  List<PlayingCard>? _findBestMeld(List<PlayingCard> hand) {
    if (hand.length < 3) return null;

    // Group 찾기
    final rankGroups = <int, List<PlayingCard>>{};
    for (final card in hand) {
      rankGroups.putIfAbsent(card.rank, () => []).add(card);
    }
    for (final group in rankGroups.values) {
      if (group.length >= 3) {
        return group.take(3).toList();
      }
    }

    // Run 찾기
    final suitGroups = <Suit, List<PlayingCard>>{};
    for (final card in hand) {
      suitGroups.putIfAbsent(card.suit, () => []).add(card);
    }
    for (final cards in suitGroups.values) {
      if (cards.length >= 3) {
        cards.sort((a, b) => a.rank.compareTo(b.rank));
        for (int i = 0; i <= cards.length - 3; i++) {
          final run = <PlayingCard>[cards[i]];
          for (int j = i + 1; j < cards.length && run.length < 3; j++) {
            if (cards[j].rank == run.last.rank + 1) {
              run.add(cards[j]);
            }
          }
          if (run.length >= 3) {
            return run;
          }
        }
      }
    }

    return null;
  }

  // 스톱 선언 (플레이어)
  void _callStop() {
    if (gameOver) return;
    _calculateScoresAndEnd(stopperIndex: 0); // 플레이어가 스톱
  }

  void _calculateScoresAndEnd({required int stopperIndex}) {
    // 모든 플레이어 점수 계산
    // 등록(멜드)을 하지 못한 플레이어는 패널티로 점수 두 배
    scores[0] = _calculateHandScore(playerHand);
    if (playerMelds.isEmpty) {
      scores[0] *= 2; // 등록 못한 패널티
    }
    for (int i = 0; i < computerHands.length; i++) {
      scores[i + 1] = _calculateHandScore(computerHands[i]);
      if (computerMelds[i].isEmpty) {
        scores[i + 1] *= 2; // 등록 못한 패널티
      }
    }

    // 최저 점수 찾기
    int minScore = scores[0];
    List<int> minIndices = [0]; // 최저 점수를 가진 모든 플레이어 인덱스

    for (int i = 1; i < scores.length; i++) {
      if (scores[i] < minScore) {
        minScore = scores[i];
        minIndices = [i];
      } else if (scores[i] == minScore) {
        minIndices.add(i);
      }
    }

    // 동점자가 여러 명인 경우
    if (minIndices.length > 1) {
      // 스톱한 사람이 동점자에 포함되어 있으면 스톱한 사람은 패배
      if (minIndices.contains(stopperIndex)) {
        // 스톱한 사람을 제외한 동점자 중 첫 번째가 승리
        minIndices.remove(stopperIndex);
        _endGame(minIndices.first);
      } else {
        // 스톱한 사람이 동점자가 아니면 첫 번째 동점자가 승리
        _endGame(minIndices.first);
      }
    } else {
      // 단독 최저 점수면 그 사람이 승리
      _endGame(minIndices.first);
    }
  }

  int _calculateHandScore(List<PlayingCard> hand) {
    return hand.fold(0, (sum, card) => sum + card.point);
  }

  void _endGame(int winnerIdx) {
    // 점수 계산 (등록 못한 플레이어는 패널티로 두 배)
    scores[0] = _calculateHandScore(playerHand);
    if (playerMelds.isEmpty) {
      scores[0] *= 2; // 등록 못한 패널티
    }
    for (int i = 0; i < computerHands.length; i++) {
      scores[i + 1] = _calculateHandScore(computerHands[i]);
      if (computerMelds[i].isEmpty) {
        scores[i + 1] *= 2; // 등록 못한 패널티
      }
    }

    setState(() {
      gameOver = true;
      winnerIndex = winnerIdx;
      if (winnerIdx == 0) {
        winner = 'common.player'.tr();
      } else {
        winner = '${'common.computer'.tr()}$winnerIdx';
      }
    });

    // 게임 종료 시 저장된 게임 삭제
    _saveGame();

    _showGameOverDialog();
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: winnerIndex == 0 ? Colors.amber : Colors.red.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        title: Column(
          children: [
            Text(
              winnerIndex == 0 ? 'games.hula.victory'.tr() : 'games.hula.defeat'.tr(),
              style: TextStyle(
                color: winnerIndex == 0 ? Colors.amber : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
              textAlign: TextAlign.center,
            ),
            if (isHula && winnerIndex == 0)
              Text(
                'games.hula.hulaWin'.tr(),
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'games.hula.winnerWins'.tr(namedArgs: {'winner': winner ?? ''}),
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Text(
              'games.hula.remainingScore'.tr(),
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '${'common.player'.tr()}: ${scores[0]}${'common.score'.tr()}',
              style: TextStyle(
                color: winnerIndex == 0 ? Colors.amber : Colors.white70,
              ),
            ),
            ...List.generate(
              computerHands.length,
              (i) => Text(
                '${'common.computer'.tr()}${i + 1}: ${scores[i + 1]}${'common.score'.tr()}',
                style: TextStyle(
                  color: winnerIndex == i + 1 ? Colors.red : Colors.white70,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initGame();
            },
            child: Text('app.newGame'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('app.close'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      backgroundColor: const Color(0xFF0D5C2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('${'games.hula.name'.tr()} (${playerCount}${'common.players'.tr()})',
            style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _initGame,
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: _showRulesDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: _buildGameContent(false),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Container(
      color: const Color(0xFF0D5C2E),
      child: SafeArea(
        child: Stack(
          children: [
            _buildGameContent(true),
            // 왼쪽 상단: 뒤로가기 버튼 + 제목
            Positioned(
              top: 4,
              left: 8,
              child: Row(
                children: [
                  _buildCircleButton(
                    icon: Icons.arrow_back,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${'games.hula.name'.tr()} (${playerCount}${'common.players'.tr()})',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 오른쪽 상단: 새 게임 + 도움말 버튼
            Positioned(
              top: 4,
              right: 8,
              child: Row(
                children: [
                  _buildCircleButton(
                    icon: Icons.refresh,
                    onPressed: _initGame,
                  ),
                  const SizedBox(width: 8),
                  _buildCircleButton(
                    icon: Icons.help_outline,
                    onPressed: _showRulesDialog,
                  ),
                ],
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
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildGameContent(bool isLandscape) {
    return Column(
      children: [
        // 상단 컴퓨터: 2인은 COM1, 3인은 COM2, 4인은 COM2
        if (computerHands.isNotEmpty)
          _buildTopComputerHand(
              computerHands.length == 1 ? 0 : 1, isLandscape),

        // 중앙 영역 (좌우 컴퓨터 + 덱/버린더미)
        Expanded(
          child: computerHands.length >= 2
              ? Row(
                  children: [
                    // 왼쪽 컴퓨터 (COM3) - 4인 게임만
                    if (computerHands.length >= 3)
                      _buildSideComputerHand(2, isLandscape),
                    // 중앙 카드 영역
                    Expanded(child: _buildCenterArea(isLandscape)),
                    // 오른쪽 컴퓨터 (COM1) - 3인 이상
                    _buildSideComputerHand(0, isLandscape),
                  ],
                )
              : _buildCenterArea(isLandscape),
        ),

        // 하단 영역 (메시지, 멜드, 손패, 버튼)
        _buildBottomSection(isLandscape),
      ],
    );
  }

  // 하단 영역 (스크롤 가능)
  Widget _buildBottomSection(bool isLandscape) {
    return Flexible(
      flex: 0,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 메시지
            if (gameMessage != null)
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: isLandscape ? 2 : 8),
                margin: EdgeInsets.only(bottom: isLandscape ? 2 : 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  gameMessage!,
                  style: TextStyle(
                      color: Colors.white, fontSize: isLandscape ? 11 : 14),
                ),
              ),

            // 등록된 멜드
            if (playerMelds.isNotEmpty) _buildPlayerMelds(isLandscape),

            // 플레이어 손패
            _buildPlayerHand(isLandscape),

            // 액션 버튼
            _buildActionButtons(isLandscape),
          ],
        ),
      ),
    );
  }

  // 상단 컴퓨터 (가로 배치)
  Widget _buildTopComputerHand(int computerIndex, bool isLandscape) {
    if (computerIndex >= computerHands.length) return const SizedBox();

    final hand = computerHands[computerIndex];
    final melds = computerMelds[computerIndex];
    final isCurrentTurn = currentTurn == computerIndex + 1;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isLandscape ? 4 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrentTurn ? Colors.amber.shade700 : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.computer, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'COM${computerIndex + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'games.hula.cardsCount'.tr(namedArgs: {'count': '${hand.length}'}),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    if (melds.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${'games.hula.meldsCount'.tr(namedArgs: {'count': '${melds.length}'})})',
                        style: const TextStyle(color: Colors.green, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 카드 뒷면 표시
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              min(hand.length, isLandscape ? 10 : 8),
              (j) => Container(
                width: isLandscape ? 20 : 24,
                height: isLandscape ? 28 : 34,
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade900],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.white24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 좌/우측 컴퓨터 (세로 배치)
  Widget _buildSideComputerHand(int computerIndex, bool isLandscape) {
    if (computerIndex >= computerHands.length) return const SizedBox();

    final hand = computerHands[computerIndex];
    final melds = computerMelds[computerIndex];
    final isCurrentTurn = currentTurn == computerIndex + 1;

    return Container(
      width: isLandscape ? 45 : 55,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 컴퓨터 이름
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isCurrentTurn ? Colors.amber.shade700 : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.computer, color: Colors.white, size: 10),
                    const SizedBox(width: 2),
                    Text(
                      '${computerIndex + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // 카드 수
          Text(
            'games.hula.cardsCount'.tr(namedArgs: {'count': '${hand.length}'}),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          if (melds.isNotEmpty)
            Text(
              'games.hula.meldsCount'.tr(namedArgs: {'count': '${melds.length}'}),
              style: const TextStyle(color: Colors.green, fontSize: 9),
            ),
          const SizedBox(height: 8),
          // 세로 카드 스택
          Expanded(
            child: _buildVerticalCardStack(hand.length, isLandscape),
          ),
        ],
      ),
    );
  }

  // 세로 카드 스택
  Widget _buildVerticalCardStack(int cardCount, bool isLandscape) {
    const overlap = 10.0;
    final cardHeight = isLandscape ? 28.0 : 32.0;
    final cardWidth = isLandscape ? 22.0 : 26.0;
    const maxVisible = 7;
    final visibleCount = cardCount > maxVisible ? maxVisible : cardCount;
    final totalHeight = cardHeight + (visibleCount - 1) * overlap;

    return Center(
      child: SizedBox(
        width: cardWidth,
        height: totalHeight,
        child: Stack(
          children: List.generate(visibleCount, (index) {
            return Positioned(
              top: index * overlap,
              child: Container(
                width: cardWidth,
                height: cardHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade800, Colors.blue.shade900],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCenterArea(bool isLandscape) {
    final cardWidth = isLandscape ? 50.0 : 70.0;
    final cardHeight = isLandscape ? 70.0 : 100.0;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 덱 - 내 차례이고 드로우 전이면 탭 가능 (waitingForNextTurn 상태에서도)
              GestureDetector(
                onTap: currentTurn == 0 && !hasDrawn
                    ? _drawFromDeck
                    : null,
                child: Container(
                  width: cardWidth,
                  height: cardHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade700, Colors.blue.shade900],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: currentTurn == 0 && !hasDrawn
                          ? Colors.yellow
                          : Colors.white24,
                      width: currentTurn == 0 && !hasDrawn
                          ? 3
                          : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🂠', style: TextStyle(fontSize: 28)),
                      Text(
                        '${deck.length}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: isLandscape ? 12 : 20),
              // 버린 더미
              Builder(
                builder: (context) {
                  // 땡큐 가능: 대기 중이거나 플레이어 턴에서 드로우 안했을 때, 그리고 등록 가능할 때만
                  final canTakeDiscard = discardPile.isNotEmpty &&
                      ((currentTurn == 0 && !hasDrawn) || waitingForNextTurn || _thankYouWaiting) &&
                      _canThankYou();
                  // 땡큐 대기 중이면 주황색 깜빡임, 일반 땡큐 가능이면 주황색, 일반 드로우면 녹색
                  final borderColor =
                      _thankYouWaiting && canTakeDiscard
                          ? Colors.orange
                          : (waitingForNextTurn && canTakeDiscard
                              ? Colors.orange
                              : (canTakeDiscard ? Colors.green : Colors.grey));

                  return GestureDetector(
                    onTap: canTakeDiscard ? _drawFromDiscard : null,
                    child: Stack(
                      children: [
                        Container(
                          width: cardWidth,
                          height: cardHeight,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: borderColor,
                              width: canTakeDiscard ? 3 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(2, 2),
                              ),
                            ],
                          ),
                          child: discardPile.isEmpty
                              ? Center(
                                  child: Text(
                                    'games.hula.emptyDiscardPile'.tr(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                )
                              : _buildCardFace(discardPile.last, small: true),
                        ),
                        // 땡큐 대기 카운트다운 표시
                        if (_thankYouWaiting && canTakeDiscard)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '땡큐?',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '$_thankYouCountdown',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          // 현재 순서 표시 (항상 표시)
          if (!gameOver)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 현재 순서 표시
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: currentTurn == 0 ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currentTurn == 0
                          ? 'common.yourTurnIs'.tr()
                          : (waitingForNextTurn ? '${'common.computer'.tr()}$currentTurn ($_autoPlayCountdown)' : '${'common.computer'.tr()}$currentTurn ${'common.turn'.tr()}'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // 시작하기 버튼 (컴퓨터 차례 대기 중일 때만 표시)
                  if (waitingForNextTurn && currentTurn != 0) ...[
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _onNextTurn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'games.hula.startButton'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          // 모든 등록된 멜드 표시
          _buildAllMeldsArea(isLandscape),
        ],
      ),
    );
  }

  Widget _buildCardFace(PlayingCard card, {bool small = false}) {
    final fontSize = small ? 14.0 : 18.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(small ? 6 : 8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.suitSymbol,
            style: TextStyle(
              fontSize: fontSize + 4,
              color: card.suitColor,
            ),
          ),
          Text(
            card.rankString,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: card.suitColor,
            ),
          ),
        ],
      ),
    );
  }

  // 모든 플레이어의 멜드를 표시 (붙여놓기 가능)
  Widget _buildAllMeldsArea(bool isLandscape) {
    // 모든 멜드 수집
    final List<Map<String, dynamic>> allMelds = [];

    // 플레이어 멜드
    for (int i = 0; i < playerMelds.length; i++) {
      allMelds.add({
        'meldIndex': i,
        'meld': playerMelds[i],
        'melds': playerMelds,
      });
    }

    // 컴퓨터 멜드
    for (int c = 0; c < computerMelds.length; c++) {
      for (int i = 0; i < computerMelds[c].length; i++) {
        allMelds.add({
          'meldIndex': i,
          'meld': computerMelds[c][i],
          'melds': computerMelds[c],
        });
      }
    }

    // 고정 높이 영역 (멜드가 없어도 공간 유지)
    final fixedHeight = isLandscape ? 50.0 : 70.0;
    final cardHeight = isLandscape ? 22.0 : 28.0;
    final cardWidth = isLandscape ? 16.0 : 20.0;
    final overlap = isLandscape ? 10.0 : 12.0;

    return Container(
      height: fixedHeight,
      margin: EdgeInsets.only(top: isLandscape ? 4 : 8),
      child: allMelds.isEmpty
          ? const SizedBox()
          : SingleChildScrollView(
              child: Wrap(
                spacing: isLandscape ? 8 : 12,
                runSpacing: isLandscape ? 4 : 6,
                alignment: WrapAlignment.center,
                children: allMelds.map((meldInfo) {
                  final meld = meldInfo['meld'] as Meld;
                  final melds = meldInfo['melds'] as List<Meld>;
                  final meldIndex = meldInfo['meldIndex'] as int;

                  // 선택된 카드가 이 멜드에 붙일 수 있는지 확인
                  bool canAttach = false;
                  if (selectedCardIndices.length == 1 &&
                      currentTurn == 0 &&
                      hasDrawn &&
                      playerMelds.isNotEmpty) {
                    final card = playerHand[selectedCardIndices.first];
                    canAttach = _canAttachToMeldList(card, melds) == meldIndex;
                  }

                  // 겹치는 카드 스택 너비 계산
                  final stackWidth = cardWidth + (meld.cards.length - 1) * overlap;

                  return GestureDetector(
                    onTap: canAttach
                        ? () {
                            final card = playerHand[selectedCardIndices.first];
                            _attachToMeldList(meldIndex, card, melds);
                            playerHand.remove(card);
                            selectedCardIndices.clear();

                            if (playerHand.isEmpty) {
                              _endGame(0);
                            } else {
                              setState(() {});
                              _saveGame();
                            }
                          }
                        : null,
                    child: Container(
                      width: stackWidth,
                      height: cardHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        border: canAttach
                            ? Border.all(color: Colors.yellow, width: 2)
                            : null,
                      ),
                      child: Stack(
                        children: List.generate(meld.cards.length, (i) {
                          final card = meld.cards[i];
                          return Positioned(
                            left: i * overlap,
                            child: Container(
                              width: cardWidth,
                              height: cardHeight,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(color: Colors.grey.shade400, width: 0.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 1,
                                    offset: const Offset(0.5, 0.5),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    card.suitSymbol,
                                    style: TextStyle(
                                      fontSize: isLandscape ? 8 : 10,
                                      color: card.suitColor,
                                      height: 1,
                                    ),
                                  ),
                                  Text(
                                    card.rankString,
                                    style: TextStyle(
                                      fontSize: isLandscape ? 7 : 9,
                                      fontWeight: FontWeight.bold,
                                      color: card.suitColor,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildPlayerMelds(bool isLandscape) {
    return Container(
      height: isLandscape ? 28 : 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: playerMelds.length,
        itemBuilder: (context, meldIndex) {
          final meld = playerMelds[meldIndex];
          return Container(
            margin: const EdgeInsets.only(right: 8),
            padding: EdgeInsets.symmetric(horizontal: isLandscape ? 6 : 8, vertical: isLandscape ? 2 : 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  meld.isRun ? 'Run: ' : 'Set: ',
                  style: TextStyle(color: Colors.green, fontSize: isLandscape ? 9 : 10),
                ),
                ...meld.cards.map((card) => Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Text(
                        '${card.suitSymbol}${card.rankString}',
                        style: TextStyle(
                          color: card.suitColor == Colors.red
                              ? Colors.red.shade300
                              : Colors.white,
                          fontSize: isLandscape ? 10 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayerHand(bool isLandscape) {
    final cardWidth = isLandscape ? 40.0 : 50.0;
    final cardHeight = isLandscape ? 58.0 : 72.0;
    final symbolSize = isLandscape ? 16.0 : 20.0;
    final rankSize = isLandscape ? 14.0 : 16.0;

    // 세로 모드: 2줄, 가로 모드: 1줄
    final int cardsPerRow = isLandscape
        ? playerHand.length
        : (playerHand.length / 2).ceil();

    final List<int> row1 = List.generate(
      cardsPerRow > playerHand.length ? playerHand.length : cardsPerRow,
      (i) => i,
    );
    final List<int> row2 = isLandscape
        ? []
        : List.generate(
            playerHand.length - cardsPerRow > 0
                ? playerHand.length - cardsPerRow
                : 0,
            (i) => cardsPerRow + i,
          );

    Widget buildCard(int index) {
      final card = playerHand[index];
      final isSelected = selectedCardIndices.contains(index);

      return GestureDetector(
        onTap: () => _toggleCardSelection(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(
              0, isSelected ? (isLandscape ? -8 : -10) : 0, 0),
          margin: EdgeInsets.symmetric(horizontal: isLandscape ? 2 : 2),
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isLandscape ? 6 : 6),
            border: Border.all(
              color: isSelected ? Colors.amber : Colors.grey.shade400,
              width: isSelected ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? Colors.amber.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.2),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(1, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                card.suitSymbol,
                style: TextStyle(
                  fontSize: symbolSize,
                  color: card.suitColor,
                ),
              ),
              Text(
                card.rankString,
                style: TextStyle(
                  fontSize: rankSize,
                  fontWeight: FontWeight.bold,
                  color: card.suitColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildCardRow(List<int> indices) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: indices.map((index) => buildCard(index)).toList(),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: isLandscape ? 4 : 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildCardRow(row1),
            if (row2.isNotEmpty) ...[
              const SizedBox(height: 4),
              buildCardRow(row2),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isLandscape) {
    // 7 단독: 특별 규칙, 1~2장: 붙이기 가능 여부, 3장+: 새 멜드 가능 여부
    bool canMeld = false;
    if (selectedCardIndices.length >= 3) {
      final cards = selectedCardIndices.map((i) => playerHand[i]).toList();
      canMeld = _isValidMeld(cards);
    } else if (selectedCardIndices.length == 1 && _isSeven(playerHand[selectedCardIndices.first])) {
      // 7 카드 단독 등록 가능 (훌라 특별 규칙)
      canMeld = true;
    } else if (selectedCardIndices.isNotEmpty && playerMelds.isNotEmpty) {
      // 1~2장 선택 시 붙이기 가능 여부 확인 (자신의 멜드가 있어야만 붙이기 가능 - 훌라 규칙)
      for (final idx in selectedCardIndices) {
        final card = playerHand[idx];
        // 플레이어 멜드 확인
        if (_canAttachToMeld(card) >= 0) {
          canMeld = true;
          break;
        }
        // 컴퓨터 멜드 확인
        for (final compMelds in computerMelds) {
          if (_canAttachToMeldList(card, compMelds) >= 0) {
            canMeld = true;
            break;
          }
        }
        if (canMeld) break;
      }
    }
    final canDiscard = hasDrawn && selectedCardIndices.length == 1;
    final iconSize = isLandscape ? 14.0 : 18.0;
    final buttonPadding = isLandscape
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
        : null;

    return Container(
      padding: EdgeInsets.all(isLandscape ? 6 : 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 멜드 등록 (드로우 후에만 가능)
          ElevatedButton.icon(
            onPressed: currentTurn == 0 && hasDrawn && canMeld ? _registerMeld : null,
            icon: Icon(Icons.check_circle, size: iconSize),
            label: Text('games.hula.meld'.tr(), style: TextStyle(fontSize: isLandscape ? 12 : 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade700,
              padding: buttonPadding,
              minimumSize: isLandscape ? const Size(70, 32) : null,
            ),
          ),
          // 버리기
          ElevatedButton.icon(
            onPressed: currentTurn == 0 && canDiscard ? _discardCard : null,
            icon: Icon(Icons.delete_outline, size: iconSize),
            label: Text('games.hula.discardButton'.tr(), style: TextStyle(fontSize: isLandscape ? 12 : 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade700,
              padding: buttonPadding,
              minimumSize: isLandscape ? const Size(70, 32) : null,
            ),
          ),
          // 스톱
          ElevatedButton.icon(
            onPressed: currentTurn == 0 && !gameOver ? _callStop : null,
            icon: Icon(Icons.stop_circle, size: iconSize),
            label: Text('games.hula.stopButton'.tr(), style: TextStyle(fontSize: isLandscape ? 12 : 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade700,
              padding: buttonPadding,
              minimumSize: isLandscape ? const Size(70, 32) : null,
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
          'games.hula.rulesTitle'.tr(),
          style: const TextStyle(color: Colors.amber),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'games.hula.rulesObjective'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.hula.rulesObjectiveDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.hula.rulesProgress'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.hula.rulesProgressDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.hula.rulesMeldTypes'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.hula.rulesMeldTypesDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.hula.rulesSeven'.tr(),
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.hula.rulesSevenDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.hula.rulesThankYouMeld'.tr(),
                style: const TextStyle(
                  color: Colors.cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.hula.rulesThankYouMeldDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.hula.rulesStop'.tr(),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.hula.rulesStopDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.hula.rulesScoring'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.hula.rulesScoringDesc'.tr(),
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
