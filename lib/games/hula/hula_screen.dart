import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/game_save_service.dart';

// 카드 무늬
enum Suit { spade, heart, diamond, club }

// 플레잉 카드
class PlayingCard {
  final Suit suit;
  final int rank; // 1-13 (A, 2-10, J, Q, K)

  PlayingCard({required this.suit, required this.rank});

  // 카드 점수 (A=1, 2-10=숫자, J/Q/K=10)
  int get point {
    if (rank == 1) return 1;
    if (rank >= 11) return 10;
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

  const HulaScreen({
    super.key,
    this.playerCount = 2,
    this.resumeGame = false,
  });

  static Future<bool> hasSavedGame() async {
    return await GameSaveService.hasSavedGame('hula');
  }

  static Future<int?> getSavedPlayerCount() async {
    final gameState = await GameSaveService.loadGame('hula');
    if (gameState == null) return null;
    return gameState['playerCount'] as int?;
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

  // 턴 단계
  bool hasDrawn = false; // 이번 턴에 드로우했는지
  List<int> selectedCardIndices = []; // 선택된 카드 인덱스들
  bool waitingForNextTurn = false; // 다음 턴 대기 중
  Timer? _nextTurnTimer; // 자동 진행 타이머
  int _autoPlayCountdown = 5; // 자동 진행 카운트다운
  int _lastDiscardTurn = 0; // 마지막으로 카드를 버린 플레이어 턴

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
    _animController.dispose();
    super.dispose();
  }

  void _initGame() {
    deck = createDeck();
    deck.shuffle(Random());

    discardPile = [];
    playerHand = [];
    computerHands = List.generate(playerCount - 1, (_) => []);
    playerMelds = [];
    computerMelds = List.generate(playerCount - 1, (_) => []);
    scores = List.generate(playerCount, (_) => 0);

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

    currentTurn = 0;
    gameOver = false;
    winner = null;
    winnerIndex = null;
    isHula = false;
    hasDrawn = false;
    selectedCardIndices = [];
    waitingForNextTurn = false;
    _cancelNextTurnTimer();

    setState(() {});
    _saveGame();
  }

  // 다음 턴 자동 진행 타이머 시작
  void _startNextTurnTimer() {
    _cancelNextTurnTimer();
    _autoPlayCountdown = 5;

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

  // 다음 턴 버튼 클릭
  void _onNextTurn() {
    _cancelNextTurnTimer();
    setState(() {
      waitingForNextTurn = false;
    });

    if (gameOver) return;

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

      gameOver = false;
      winner = null;
      winnerIndex = null;
      isHula = false;
      selectedCardIndices = [];
      waitingForNextTurn = false;
    });
    _cancelNextTurnTimer();

    // 컴퓨터 턴이면 대기 상태로 시작
    if (currentTurn != 0) {
      setState(() {
        waitingForNextTurn = true;
      });
      _startNextTurnTimer();
    }
  }

  void _showMessage(String message, {int seconds = 2}) {
    setState(() {
      gameMessage = message;
    });
    _messageTimer?.cancel();
    _messageTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) {
        setState(() {
          gameMessage = null;
        });
      }
    });
  }

  // 덱에서 카드 드로우
  void _drawFromDeck() {
    if (hasDrawn || gameOver || currentTurn != 0) return;
    if (deck.isEmpty) {
      // 덱이 비면 버린 더미 섞기
      if (discardPile.length <= 1) {
        _showMessage('더 이상 카드가 없습니다');
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
    });
    _showMessage('덱에서 ${card.suitSymbol}${card.rankString} 드로우');
    _saveGame();
  }

  // 버린 더미에서 카드 가져오기 (땡큐)
  void _drawFromDiscard() {
    if (gameOver) return;
    if (discardPile.isEmpty) return;

    // 플레이어 턴이거나, 대기 중일 때 (땡큐)
    if (currentTurn == 0 && hasDrawn) return;
    if (currentTurn != 0 && !waitingForNextTurn) return;

    // 땡큐 상황: 대기 중에 가져가기
    if (waitingForNextTurn) {
      _cancelNextTurnTimer();
      setState(() {
        currentTurn = 0;
        waitingForNextTurn = false;
      });
    }

    final card = discardPile.removeLast();
    playerHand.add(card);
    _sortHand(playerHand);

    setState(() {
      hasDrawn = true;
      selectedCardIndices = [];
    });
    _showMessage('땡큐! ${card.suitSymbol}${card.rankString} 획득');
    _saveGame();
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

      // 단독 7 카드 특별 처리: Run 또는 Group으로 확장 가능
      if (meld.cards.length == 1 && meld.cards.first.rank == 7) {
        final seven = meld.cards.first;
        // 같은 무늬의 6 또는 8이면 Run으로 확장
        if (card.suit == seven.suit && (card.rank == 6 || card.rank == 8)) {
          return i;
        }
        // 다른 무늬의 7이면 Group으로 확장
        if (card.rank == 7 && card.suit != seven.suit) {
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

  // 범용: 특정 멜드 목록에 카드를 붙일 수 있는지 확인
  int _canAttachToMeldList(PlayingCard card, List<Meld> melds) {
    for (int i = 0; i < melds.length; i++) {
      final meld = melds[i];

      // 단독 7 카드 특별 처리
      if (meld.cards.length == 1 && meld.cards.first.rank == 7) {
        final seven = meld.cards.first;
        if (card.suit == seven.suit && (card.rank == 6 || card.rank == 8)) {
          return i;
        }
        if (card.rank == 7 && card.suit != seven.suit) {
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
  PlayingCard _selectCardToDiscard(List<PlayingCard> hand) {
    if (hand.length == 1) return hand.first;

    // 각 카드의 "유지 가치" 점수 계산 (높을수록 유지해야 함)
    final scores = <PlayingCard, double>{};

    for (final card in hand) {
      double keepScore = 0;

      // 1. 7 카드는 절대 버리면 안 됨 (단독 등록 가능)
      if (_isSeven(card)) {
        keepScore += 1000;
      }

      // 2. 같은 숫자 카드 개수 (Group 가능성)
      final sameRankCount = hand.where((c) => c.rank == card.rank).length;
      if (sameRankCount >= 2) {
        keepScore += sameRankCount * 30; // 2장: 60, 3장: 90
      }

      // 3. 같은 무늬 연속 카드 (Run 가능성)
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

      // 4. 버린 더미에서 같은 카드 확인 (확률 계산)
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

      // 5. 카드 점수 (낮은 점수 카드 유지 선호)
      keepScore -= card.point * 2;

      scores[card] = keepScore;
    }

    // 가장 낮은 유지 가치를 가진 카드 버리기
    final sortedCards = hand.toList()
      ..sort((a, b) => scores[a]!.compareTo(scores[b]!));

    return sortedCards.first;
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

    // 3. 기존 멜드에 붙일 수 있는 카드
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

    // 남은 카드 수에 따른 페널티
    final remainingPenalty = remaining.length * 10.0;
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

    return risk.clamp(0.0, 100.0);
  }

  // 컴퓨터가 스톱을 외칠지 결정
  bool _shouldComputerCallStop(int computerIndex) {
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
      return true;
    }

    return false;
  }

  // 컴퓨터가 스톱 선언
  void _computerCallStop(int computerIndex) {
    _showMessage('컴퓨터${computerIndex + 1}: 스톱!');
    _calculateScoresAndEnd();
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
      _showMessage('7 단독 등록!');
      _saveGame();

      if (playerHand.isEmpty) {
        _playerWins();
      }
      return;
    }

    // 1~2장 선택: 기존 멜드에 붙이기 시도
    if (selectedCardIndices.length < 3) {
      // 각 카드에 대해 붙이기 가능 여부 확인
      bool attached = false;
      for (final card in selectedCards) {
        final meldIndex = _canAttachToMeld(card);
        if (meldIndex >= 0) {
          _attachToMeld(meldIndex, card);
          playerHand.remove(card);
          attached = true;
        }
      }

      if (attached) {
        setState(() {
          selectedCardIndices = [];
        });
        _showMessage('멜드에 카드 추가!');
        _saveGame();

        if (playerHand.isEmpty) {
          _playerWins();
        }
        return;
      }

      _showMessage('붙일 수 있는 멜드가 없습니다');
      return;
    }

    // 3장 이상: 새 멜드 등록
    if (!_isValidMeld(selectedCards)) {
      _showMessage('유효하지 않은 조합입니다');
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

    _showMessage(isRun ? 'Run 등록!' : 'Group 등록!');
    _saveGame();

    // 손패가 비었으면 승리
    if (playerHand.isEmpty) {
      _playerWins();
    }
  }

  // 카드 버리기
  void _discardCard() {
    if (!hasDrawn) {
      _showMessage('먼저 카드를 드로우하세요');
      return;
    }
    if (selectedCardIndices.length != 1) {
      _showMessage('버릴 카드 1장을 선택하세요');
      return;
    }

    final cardIndex = selectedCardIndices.first;
    final card = playerHand.removeAt(cardIndex);
    discardPile.add(card);

    setState(() {
      selectedCardIndices = [];
      hasDrawn = false;
    });

    _showMessage('${card.suitSymbol}${card.rankString} 버림');
    _saveGame();

    // 손패가 비었으면 승리
    if (playerHand.isEmpty) {
      _playerWins();
      return;
    }

    // 땡큐 확인: 플레이어 전 순서 컴퓨터는 즉시, 후 순서는 5초 후
    _lastDiscardTurn = 0;
    Timer(const Duration(milliseconds: 300), () {
      if (mounted && !gameOver) {
        // 1. 플레이어 전 순서 컴퓨터 땡큐 확인 (즉시)
        final beforeResult = _checkComputerThankYouBeforePlayer(0);
        if (beforeResult != null) {
          _executeComputerThankYou(beforeResult);
        } else {
          // 2. 플레이어 후 순서 컴퓨터가 있으면 5초 대기
          _startThankYouWait();
        }
      }
    });
  }

  // 땡큐 대기 시작 (플레이어에게 5초 기회 부여)
  void _startThankYouWait() {
    setState(() {
      currentTurn = (currentTurn + 1) % playerCount;
      hasDrawn = false;
      selectedCardIndices = [];
      waitingForNextTurn = true;
    });
    _startNextTurnTimer();
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
    });

    if (currentTurn != 0) {
      // 컴퓨터 턴: 대기 상태로 전환하고 타이머 시작
      setState(() {
        waitingForNextTurn = true;
      });
      _startNextTurnTimer();
    }
  }

  void _computerTurn() {
    if (gameOver) return;

    final computerIndex = currentTurn - 1;
    final hand = computerHands[computerIndex];
    final melds = computerMelds[computerIndex];

    // 1. 드로우 (버린 더미 or 덱)
    PlayingCard drawnCard;
    final topDiscard = discardPile.isNotEmpty ? discardPile.last : null;

    // 버린 카드가 멜드에 도움이 되면 가져오기
    bool takeDiscard = false;
    if (topDiscard != null) {
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
      _showMessage('컴퓨터${computerIndex + 1}: 땡큐!');
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
    }

    hand.add(drawnCard);
    _sortHand(hand);

    // 2. 훌라 가능성 확인 후 등록 여부 결정 (스톱 위험도 포함)
    final shouldRegister = _shouldRegisterMelds(hand, melds, computerIndex: computerIndex + 1);

    if (shouldRegister) {
      // 2-1. 가능한 멜드 등록
      List<PlayingCard>? bestMeld;
      while ((bestMeld = _findBestMeld(hand)) != null) {
        final isRun = _isValidRun(bestMeld!);
        for (final card in bestMeld) {
          hand.remove(card);
        }
        melds.add(Meld(cards: bestMeld, isRun: isRun));

        if (hand.isEmpty) {
          // 컴퓨터 승리
          _endGame(currentTurn);
          return;
        }
      }

      // 2-2. 7 카드 스마트 등록 (Group vs Run 결정)
      final sevens = hand.where((c) => _isSeven(c)).toList();
      if (sevens.length >= 3) {
        // 3장 이상: Group vs 개별 Run 결정
        final decision = _decideSevensStrategy(sevens, hand);
        if (decision == 'group') {
          // Group으로 등록
          for (final seven in sevens.take(3)) {
            hand.remove(seven);
          }
          melds.add(Meld(cards: sevens.take(3).toList(), isRun: false));
          _showMessage('컴퓨터${computerIndex + 1}: 7 Group 등록!');

          if (hand.isEmpty) {
            _endGame(currentTurn);
            return;
          }

          // 남은 7이 있으면 단독 등록
          final remaining = hand.where((c) => _isSeven(c)).toList();
          for (final seven in remaining) {
            hand.remove(seven);
            melds.add(Meld(cards: [seven], isRun: false));
            if (hand.isEmpty) {
              _endGame(currentTurn);
              return;
            }
          }
        } else {
          // 개별 등록 (Run 가능성 높음)
          for (final seven in sevens) {
            hand.remove(seven);
            melds.add(Meld(cards: [seven], isRun: false));
            _showMessage('컴퓨터${computerIndex + 1}: 7 등록!');

            if (hand.isEmpty) {
              _endGame(currentTurn);
              return;
            }
          }
        }
      } else {
        // 2장 이하: 개별 등록
        for (final seven in sevens) {
          hand.remove(seven);
          melds.add(Meld(cards: [seven], isRun: false));
          _showMessage('컴퓨터${computerIndex + 1}: 7 등록!');

          if (hand.isEmpty) {
            _endGame(currentTurn);
            return;
          }
        }
      }

      // 2-3. 기존 멜드에 붙여놓기
      if (melds.isNotEmpty) {
        bool attached = true;
        while (attached) {
          attached = false;
          for (int i = hand.length - 1; i >= 0; i--) {
            final card = hand[i];
            final meldIndex = _canAttachToMeldList(card, melds);
            if (meldIndex >= 0) {
              _attachToMeldList(meldIndex, card, melds);
              hand.removeAt(i);
              attached = true;

              if (hand.isEmpty) {
                _endGame(currentTurn);
                return;
              }
            }
          }
        }
      }
    }

    // 3. 스마트 카드 버리기
    final discardCard = _selectCardToDiscard(hand);
    hand.remove(discardCard);
    discardPile.add(discardCard);
    _sortHand(hand);

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

    // 땡큐 확인: 플레이어 전 순서 컴퓨터는 즉시, 후 순서는 5초 후
    _lastDiscardTurn = currentTurn;
    Timer(const Duration(milliseconds: 500), () {
      if (mounted && !gameOver) {
        // 1. 플레이어 전 순서 컴퓨터 땡큐 확인 (즉시)
        final beforeResult = _checkComputerThankYouBeforePlayer(currentTurn);
        if (beforeResult != null) {
          _executeComputerThankYou(beforeResult);
        } else {
          // 2. 플레이어에게 5초 기회 부여 후 플레이어 후 순서 컴퓨터 확인
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

      // 7 카드는 항상 땡큐
      if (_isSeven(topCard)) {
        return computerIndex;
      }

      // 멜드를 만들 수 있으면 땡큐
      final testHand = [...hand, topCard];
      if (_findBestMeld(testHand) != null) {
        return computerIndex;
      }
    }
    return null;
  }

  // 플레이어 전 순서 컴퓨터만 땡큐 확인 (즉시 실행)
  int? _checkComputerThankYouBeforePlayer(int fromTurn) {
    return _checkComputerThankYou(fromTurn, beforePlayer: true);
  }

  // 플레이어 후 순서 컴퓨터만 땡큐 확인 (5초 후 실행)
  int? _checkComputerThankYouAfterPlayer(int fromTurn) {
    return _checkComputerThankYou(fromTurn, beforePlayer: false);
  }

  // 컴퓨터 땡큐 실행
  void _executeComputerThankYou(int computerIndex) {
    if (discardPile.isEmpty) return;

    final card = discardPile.removeLast();
    final hand = computerHands[computerIndex];
    final melds = computerMelds[computerIndex];

    hand.add(card);
    _sortHand(hand);
    _showMessage('컴퓨터${computerIndex + 1}: 땡큐! ${card.suitSymbol}${card.rankString}');

    // 훌라 가능성 확인 후 등록 여부 결정 (스톱 위험도 포함)
    final shouldRegister = _shouldRegisterMelds(hand, melds, computerIndex: computerIndex + 1);

    if (shouldRegister) {
      // 멜드 등록
      List<PlayingCard>? bestMeld;
      while ((bestMeld = _findBestMeld(hand)) != null) {
        final isRun = _isValidRun(bestMeld!);
        for (final c in bestMeld) {
          hand.remove(c);
        }
        melds.add(Meld(cards: bestMeld, isRun: isRun));

        if (hand.isEmpty) {
          _endGame(computerIndex + 1);
          return;
        }
      }

      // 7 카드 스마트 등록
      final sevens = hand.where((c) => _isSeven(c)).toList();
      if (sevens.length >= 3) {
        final decision = _decideSevensStrategy(sevens, hand);
        if (decision == 'group') {
          for (final seven in sevens.take(3)) {
            hand.remove(seven);
          }
          melds.add(Meld(cards: sevens.take(3).toList(), isRun: false));

          if (hand.isEmpty) {
            _endGame(computerIndex + 1);
            return;
          }

          final remaining = hand.where((c) => _isSeven(c)).toList();
          for (final seven in remaining) {
            hand.remove(seven);
            melds.add(Meld(cards: [seven], isRun: false));
            if (hand.isEmpty) {
              _endGame(computerIndex + 1);
              return;
            }
          }
        } else {
          for (final seven in sevens) {
            hand.remove(seven);
            melds.add(Meld(cards: [seven], isRun: false));
            if (hand.isEmpty) {
              _endGame(computerIndex + 1);
              return;
            }
          }
        }
      } else {
        for (final seven in sevens) {
          hand.remove(seven);
          melds.add(Meld(cards: [seven], isRun: false));
          if (hand.isEmpty) {
            _endGame(computerIndex + 1);
            return;
          }
        }
      }

      // 기존 멜드에 붙여놓기
      if (melds.isNotEmpty) {
        bool attached = true;
        while (attached) {
          attached = false;
          for (int i = hand.length - 1; i >= 0; i--) {
            final c = hand[i];
            final meldIndex = _canAttachToMeldList(c, melds);
            if (meldIndex >= 0) {
              _attachToMeldList(meldIndex, c, melds);
              hand.removeAt(i);
              attached = true;

              if (hand.isEmpty) {
                _endGame(computerIndex + 1);
                return;
              }
            }
          }
        }
      }
    }

    setState(() {});
    _saveGame();

    // 땡큐한 컴퓨터가 카드 버리기
    Timer(const Duration(milliseconds: 500), () {
      if (mounted && !gameOver) {
        _computerDiscardAfterThankYou(computerIndex);
      }
    });
  }

  // 땡큐 후 컴퓨터가 카드 버리기
  void _computerDiscardAfterThankYou(int computerIndex) {
    final hand = computerHands[computerIndex];

    // 스마트 카드 버리기
    final discardCard = _selectCardToDiscard(hand);
    hand.remove(discardCard);
    discardPile.add(discardCard);
    _sortHand(hand);

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

    // 땡큐 확인: 플레이어 전 순서 컴퓨터는 즉시, 후 순서는 5초 후
    final discardTurn = computerIndex + 1;
    _lastDiscardTurn = discardTurn;
    Timer(const Duration(milliseconds: 500), () {
      if (mounted && !gameOver) {
        // 1. 플레이어 전 순서 컴퓨터 땡큐 확인 (즉시)
        final beforeResult = _checkComputerThankYouBeforePlayer(discardTurn);
        if (beforeResult != null) {
          _executeComputerThankYou(beforeResult);
        } else {
          // 2. 플레이어에게 5초 기회 부여 후 플레이어 후 순서 컴퓨터 확인
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

  // 스톱 선언
  void _callStop() {
    if (gameOver) return;
    _calculateScoresAndEnd();
  }

  void _calculateScoresAndEnd() {
    // 모든 플레이어 점수 계산
    scores[0] = _calculateHandScore(playerHand);
    for (int i = 0; i < computerHands.length; i++) {
      scores[i + 1] = _calculateHandScore(computerHands[i]);
    }

    // 최저 점수 찾기
    int minScore = scores[0];
    int minIndex = 0;
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] < minScore) {
        minScore = scores[i];
        minIndex = i;
      }
    }

    _endGame(minIndex);
  }

  int _calculateHandScore(List<PlayingCard> hand) {
    return hand.fold(0, (sum, card) => sum + card.point);
  }

  void _endGame(int winnerIdx) {
    // 점수 계산
    scores[0] = _calculateHandScore(playerHand);
    for (int i = 0; i < computerHands.length; i++) {
      scores[i + 1] = _calculateHandScore(computerHands[i]);
    }

    setState(() {
      gameOver = true;
      winnerIndex = winnerIdx;
      if (winnerIdx == 0) {
        winner = '플레이어';
      } else {
        winner = '컴퓨터$winnerIdx';
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
              winnerIndex == 0 ? '🎉 승리!' : '😢 패배',
              style: TextStyle(
                color: winnerIndex == 0 ? Colors.amber : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
              textAlign: TextAlign.center,
            ),
            if (isHula && winnerIndex == 0)
              const Text(
                '🎊 훌라! 🎊',
                style: TextStyle(
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
              '$winner 승리!',
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 16),
            const Text(
              '남은 카드 점수:',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              '플레이어: ${scores[0]}점',
              style: TextStyle(
                color: winnerIndex == 0 ? Colors.amber : Colors.white70,
              ),
            ),
            ...List.generate(
              computerHands.length,
              (i) => Text(
                '컴퓨터${i + 1}: ${scores[i + 1]}점',
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
            child: const Text('다시 하기'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('나가기'),
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
            SystemChrome.setEnabledSystemUIMode(
              SystemUiMode.immersiveSticky,
              overlays: [],
            );
            return _buildLandscapeLayout();
          } else {
            SystemChrome.setEnabledSystemUIMode(
              SystemUiMode.edgeToEdge,
              overlays: SystemUiOverlay.values,
            );
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
        title: Text('훌라 (${playerCount}인)',
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
                      '훌라 (${playerCount}인)',
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
                      '${hand.length}장',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    if (melds.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${melds.length}멜드)',
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
            '${hand.length}장',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          if (melds.isNotEmpty)
            Text(
              '${melds.length}멜드',
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
              // 덱
              GestureDetector(
                onTap: currentTurn == 0 && !hasDrawn && !waitingForNextTurn
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
                      color: currentTurn == 0 && !hasDrawn && !waitingForNextTurn
                          ? Colors.yellow
                          : Colors.white24,
                      width: currentTurn == 0 && !hasDrawn && !waitingForNextTurn
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
                  // 땡큐 가능: 대기 중일 때 또는 플레이어 턴에서 아직 드로우 안했을 때
                  final canDraw = discardPile.isNotEmpty &&
                      ((currentTurn == 0 && !hasDrawn) || waitingForNextTurn);
                  // 땡큐 상태면 주황색, 일반 드로우면 녹색
                  final borderColor =
                      waitingForNextTurn && discardPile.isNotEmpty
                          ? Colors.orange
                          : (canDraw ? Colors.green : Colors.grey);

                  return GestureDetector(
                    onTap: canDraw ? _drawFromDiscard : null,
                    child: Container(
                      width: cardWidth,
                      height: cardHeight,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: borderColor,
                          width: canDraw ? 3 : 1,
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
                          ? const Center(
                              child: Text(
                                '버림',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : _buildCardFace(discardPile.last, small: true),
                    ),
                  );
                },
              ),
            ],
          ),
          // 다음 순서 버튼
          if (waitingForNextTurn)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ElevatedButton(
                onPressed: _onNextTurn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '다음 순서 ($_autoPlayCountdown)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
        'owner': '나',
        'ownerIndex': 0,
        'meldIndex': i,
        'meld': playerMelds[i],
        'melds': playerMelds,
      });
    }

    // 컴퓨터 멜드
    for (int c = 0; c < computerMelds.length; c++) {
      for (int i = 0; i < computerMelds[c].length; i++) {
        allMelds.add({
          'owner': 'COM${c + 1}',
          'ownerIndex': c + 1,
          'meldIndex': i,
          'meld': computerMelds[c][i],
          'melds': computerMelds[c],
        });
      }
    }

    if (allMelds.isEmpty) return const SizedBox();

    return Container(
      margin: EdgeInsets.only(top: isLandscape ? 8 : 12),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(
            '등록된 멜드 (탭하여 붙이기)',
            style: TextStyle(
              color: Colors.white70,
              fontSize: isLandscape ? 10 : 11,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: isLandscape ? 32 : 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: allMelds.length,
              itemBuilder: (context, index) {
                final meldInfo = allMelds[index];
                final meld = meldInfo['meld'] as Meld;
                final owner = meldInfo['owner'] as String;
                final melds = meldInfo['melds'] as List<Meld>;
                final meldIndex = meldInfo['meldIndex'] as int;

                // 선택된 카드가 이 멜드에 붙일 수 있는지 확인
                // 조건: 자신의 멜드가 1개 이상 있어야 붙여놓기 가능
                bool canAttach = false;
                if (selectedCards.length == 1 &&
                    currentTurn == 0 &&
                    hasDrawn &&
                    playerMelds.isNotEmpty) {
                  final card = selectedCards.first;
                  canAttach = _canAttachToMeldList(card, melds) == meldIndex;
                }

                return GestureDetector(
                  onTap: canAttach
                      ? () {
                          final card = selectedCards.first;
                          // 멜드에 붙이기
                          _attachToMeldList(meldIndex, card, melds);
                          playerHand.remove(card);
                          selectedCards.clear();

                          if (playerHand.isEmpty) {
                            _endGame(0);
                          } else {
                            setState(() {});
                            _saveGame();
                          }
                        }
                      : null,
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 4 : 6,
                      vertical: isLandscape ? 2 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: canAttach
                          ? Colors.yellow.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: canAttach ? Colors.yellow : Colors.white30,
                        width: canAttach ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$owner: ',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: isLandscape ? 8 : 9,
                          ),
                        ),
                        ...meld.cards.map((card) => Text(
                              '${card.suitSymbol}${card.rankString}',
                              style: TextStyle(
                                color: card.suitColor == Colors.red
                                    ? Colors.red.shade300
                                    : Colors.white,
                                fontSize: isLandscape ? 9 : 11,
                                fontWeight: FontWeight.bold,
                              ),
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
      // 1~2장 선택 시 붙이기 가능 여부 확인
      for (final idx in selectedCardIndices) {
        if (_canAttachToMeld(playerHand[idx]) >= 0) {
          canMeld = true;
          break;
        }
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
          // 멜드 등록
          ElevatedButton.icon(
            onPressed: currentTurn == 0 && canMeld ? _registerMeld : null,
            icon: Icon(Icons.check_circle, size: iconSize),
            label: Text('등록', style: TextStyle(fontSize: isLandscape ? 12 : 14)),
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
            label: Text('버리기', style: TextStyle(fontSize: isLandscape ? 12 : 14)),
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
            label: Text('스톱', style: TextStyle(fontSize: isLandscape ? 12 : 14)),
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
        title: const Text(
          '훌라 게임 규칙',
          style: TextStyle(color: Colors.amber),
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
                '손패의 카드 합을 최소화하여 승리하세요.\n'
                '한 번에 7장 모두 내면 "훌라"!',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '🃏 진행 방법',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '1. 덱 또는 버린 더미에서 1장 드로우\n'
                '2. 멜드(조합) 등록 (선택)\n'
                '3. 카드 1장 버리기',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '📋 멜드 종류',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• Run: 같은 무늬 연속 3장+\n'
                '  (예: ♠3-♠4-♠5)\n'
                '• Group: 같은 숫자 3~4장\n'
                '  (예: ♠7-♥7-♦7)',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '💯 점수 계산',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• A = 1점\n'
                '• 2~10 = 숫자 그대로\n'
                '• J, Q, K = 10점',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
