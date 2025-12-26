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

    if (currentTurn != 0 && !gameOver) {
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

    _endTurn();
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
      final testHand = [...hand, topDiscard];
      if (_findBestMeld(testHand) != null) {
        takeDiscard = true;
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

    // 2. 가능한 멜드 등록
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

    // 3. 가장 높은 점수 카드 버리기
    hand.sort((a, b) => b.point.compareTo(a.point));
    final discardCard = hand.removeAt(0);
    discardPile.add(discardCard);
    _sortHand(hand);

    setState(() {});
    _saveGame();

    if (hand.isEmpty) {
      _endGame(currentTurn);
      return;
    }

    Timer(const Duration(milliseconds: 500), () {
      if (mounted && !gameOver) {
        _endTurn();
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
      backgroundColor: const Color(0xFF0D5C2E), // 녹색 테이블
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('훌라 (${playerCount}인)', style: const TextStyle(color: Colors.white)),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;
            return Column(
              children: [
                // 상단 컴퓨터: 2인은 COM1, 3인은 COM2, 4인은 COM2
                if (computerHands.isNotEmpty)
                  _buildTopComputerHand(computerHands.length == 1 ? 0 : 1, isLandscape),

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
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: isLandscape ? 4 : 8),
                    margin: EdgeInsets.only(bottom: isLandscape ? 4 : 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      gameMessage!,
                      style: TextStyle(color: Colors.white, fontSize: isLandscape ? 12 : 14),
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
          },
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
    final cardWidth = isLandscape ? 40.0 : 55.0;
    final cardHeight = isLandscape ? 58.0 : 80.0;
    final containerHeight = isLandscape ? 75.0 : 120.0;
    final symbolSize = isLandscape ? 16.0 : 22.0;
    final rankSize = isLandscape ? 14.0 : 18.0;

    return Container(
      height: containerHeight,
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: isLandscape ? 4 : 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: playerHand.length,
        itemBuilder: (context, index) {
          final card = playerHand[index];
          final isSelected = selectedCardIndices.contains(index);

          return GestureDetector(
            onTap: () => _toggleCardSelection(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              transform: Matrix4.translationValues(0, isSelected ? (isLandscape ? -8 : -15) : 0, 0),
              margin: EdgeInsets.symmetric(horizontal: isLandscape ? 2 : 3),
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isLandscape ? 6 : 8),
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
        },
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
