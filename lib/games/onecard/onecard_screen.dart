import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 카드 무늬
enum Suit { spade, heart, diamond, club }

// 카드 클래스
class PlayingCard {
  final Suit? suit; // null이면 조커
  final int rank; // 1-13 (A, 2-10, J, Q, K), 0이면 조커

  PlayingCard({this.suit, required this.rank});

  bool get isJoker => suit == null;
  bool get isAttack => rank == 2 || rank == 1 || isJoker; // 2, A, Joker
  bool get isJump => rank == 11; // J
  bool get isReverse => rank == 12; // Q (방향 반대)
  bool get isChain => rank == 13; // K (같은 무늬 더내기)
  bool get isChange => rank == 7; // 7

  int get attackPower {
    if (rank == 2) return 2;
    if (rank == 1) return 3; // A
    if (isJoker) return 5;
    return 0;
  }

  String get rankString {
    if (isJoker) return 'JOKER';
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
    if (isJoker) return '';
    switch (suit) {
      case Suit.spade:
        return '♠';
      case Suit.heart:
        return '♥';
      case Suit.diamond:
        return '◆';
      case Suit.club:
        return '♣';
      default:
        return '';
    }
  }

  Color get suitColor {
    if (isJoker) return Colors.purple;
    if (suit == Suit.heart || suit == Suit.diamond) {
      return Colors.red;
    }
    return Colors.black;
  }

  bool canPlayOn(PlayingCard other, Suit? currentSuit) {
    // 조커는 항상 낼 수 있음
    if (isJoker) return true;

    // 7을 낸 후 선언된 무늬가 있으면 그 무늬만 가능
    if (currentSuit != null) {
      return suit == currentSuit || rank == 7 || isJoker;
    }

    // 상대가 조커를 냈으면 조커로만 방어 가능 (공격 상태)
    // 일반 상태에서는 같은 무늬 또는 같은 숫자
    if (other.isJoker) {
      return isJoker;
    }

    return suit == other.suit || rank == other.rank;
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
}

class OneCardScreen extends StatefulWidget {
  const OneCardScreen({super.key});

  @override
  State<OneCardScreen> createState() => _OneCardScreenState();
}

class _OneCardScreenState extends State<OneCardScreen> with TickerProviderStateMixin {
  List<PlayingCard> deck = [];
  List<PlayingCard> discardPile = [];
  List<PlayingCard> playerHand = [];
  List<List<PlayingCard>> computerHands = []; // 멀티 컴퓨터

  // 인원 설정
  int playerCount = 2;
  bool showPlayerSelect = true;

  // 턴 관리
  int currentTurn = 0; // 0 = 플레이어, 1+ = 컴퓨터
  int turnDirection = 1; // 1 = 정방향, -1 = 역방향
  bool waitingForNextTurn = false;
  PlayingCard? lastPlayedCard;
  int? lastPlayerIndex;
  String? lastPlayerName;

  bool gameOver = false;
  String? winner;

  // 공격 스택
  int attackStack = 0;

  // 무늬 변경 (7 카드)
  Suit? declaredSuit;
  bool showSuitPicker = false;
  PlayingCard? pendingCard;

  // 점프 상태 (J 카드)
  bool skipNextTurn = false;

  // 방향 반대 (Q 카드) - 2인 게임에서는 건너뛰기와 동일
  bool reverseDirection = false;

  // 체인 모드 (K 카드) - 같은 무늬 더내기
  bool chainMode = false;
  Suit? chainSuit;

  // 조커 이전 카드 (조커 공격 후 기준 카드)
  PlayingCard? lastNormalCard;

  // 파산 기준
  static const int bankruptcyLimit = 20;

  // 원카드 외치기
  bool playerCalledOneCard = false;
  List<bool> computerCalledOneCard = [];

  // 애니메이션
  late AnimationController _cardAnimController;
  late Animation<double> _cardAnimation;
  int? selectedCardIndex;

  // 메시지 표시
  String? gameMessage;

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _cardAnimation = CurvedAnimation(
      parent: _cardAnimController,
      curve: Curves.easeOut,
    );
    _initGame();
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    super.dispose();
  }

  void _initGame() {
    deck = _createDeck();
    deck.shuffle(Random());

    playerHand = [];
    computerHands = List.generate(playerCount - 1, (_) => <PlayingCard>[]);
    discardPile = [];

    // 각자 7장씩 분배
    for (int i = 0; i < 7; i++) {
      playerHand.add(deck.removeLast());
      for (int j = 0; j < playerCount - 1; j++) {
        computerHands[j].add(deck.removeLast());
      }
    }

    // 첫 카드 오픈 (공격/특수 카드가 아닌 것으로)
    PlayingCard firstCard;
    do {
      firstCard = deck.removeLast();
      if (firstCard.isAttack || firstCard.isJump || firstCard.isReverse ||
          firstCard.isChain || firstCard.isChange) {
        deck.insert(0, firstCard);
      } else {
        break;
      }
    } while (true);

    discardPile.add(firstCard);
    lastNormalCard = firstCard;

    currentTurn = 0;
    turnDirection = 1;
    waitingForNextTurn = false;
    lastPlayedCard = null;
    lastPlayerIndex = null;
    lastPlayerName = null;
    gameOver = false;
    winner = null;
    attackStack = 0;
    declaredSuit = null;
    skipNextTurn = false;
    reverseDirection = false;
    chainMode = false;
    chainSuit = null;
    playerCalledOneCard = false;
    computerCalledOneCard = List.generate(playerCount - 1, (_) => false);
    gameMessage = null;
    selectedCardIndex = null;
  }

  // 현재 플레이어 턴인지 확인
  bool get isPlayerTurn => currentTurn == 0;

  // 다음 턴으로 이동
  int _getNextTurn(int current) {
    int next = current + turnDirection;
    if (next >= playerCount) next = 0;
    if (next < 0) next = playerCount - 1;
    return next;
  }

  // 플레이어 이름
  String _getPlayerName(int turn) {
    if (turn == 0) return '플레이어';
    return '컴퓨터 $turn';
  }

  // 특정 턴의 핸드 가져오기
  List<PlayingCard> _getHandForTurn(int turn) {
    if (turn == 0) return playerHand;
    return computerHands[turn - 1];
  }

  List<PlayingCard> _createDeck() {
    List<PlayingCard> newDeck = [];

    for (var suit in Suit.values) {
      for (int rank = 1; rank <= 13; rank++) {
        newDeck.add(PlayingCard(suit: suit, rank: rank));
      }
    }

    // 조커 2장 추가
    newDeck.add(PlayingCard(rank: 0));
    newDeck.add(PlayingCard(rank: 0));

    return newDeck;
  }

  void _reshuffleDeck() {
    if (discardPile.length <= 1) return;

    final topCard = discardPile.removeLast();
    deck.addAll(discardPile);
    discardPile = [topCard];
    deck.shuffle(Random());
  }

  PlayingCard? _drawCard() {
    if (deck.isEmpty) {
      _reshuffleDeck();
    }
    if (deck.isEmpty) return null;
    return deck.removeLast();
  }

  void _drawCards(List<PlayingCard> hand, int count) {
    for (int i = 0; i < count; i++) {
      final card = _drawCard();
      if (card != null) {
        hand.add(card);
      }
    }
  }

  PlayingCard get topCard => discardPile.last;

  List<PlayingCard> _getPlayableCards(List<PlayingCard> hand) {
    // 체인 모드 (K 카드) - 같은 무늬만 가능
    if (chainMode && chainSuit != null) {
      return hand.where((card) => card.suit == chainSuit).toList();
    }

    // 공격 상태에서는 특정 공격 카드로만 방어 가능
    // - 2 공격: 아무 2 / 같은 무늬 A / 조커
    // - A 공격: 아무 A / 조커
    // - 조커 공격: 조커만 가능
    if (attackStack > 0) {
      return hand.where((card) {
        if (!card.isAttack) return false;

        // 조커 공격은 조커로만 방어
        if (topCard.isJoker) {
          return card.isJoker;
        }

        // 조커는 항상 방어 가능
        if (card.isJoker) return true;

        // A 공격: 아무 A로 방어 가능
        if (topCard.rank == 1) {
          return card.rank == 1; // A만 가능
        }

        // 2 공격: 아무 2 또는 같은 무늬 A로 방어 가능
        if (topCard.rank == 2) {
          if (card.rank == 2) return true; // 아무 2
          if (card.rank == 1 && card.suit == topCard.suit) return true; // 같은 무늬 A
          return false;
        }

        return false;
      }).toList();
    }

    // 조커가 나온 후 공격을 받은 경우, 조커 이전 카드 기준으로 판단
    final referenceCard = (topCard.isJoker && lastNormalCard != null)
        ? lastNormalCard!
        : topCard;

    return hand.where((card) => card.canPlayOn(referenceCard, declaredSuit)).toList();
  }

  void _playCard(PlayingCard card, {Suit? newSuit}) {
    setState(() {
      // 현재 턴 플레이어의 핸드에서 카드 제거
      final currentHand = _getHandForTurn(currentTurn);
      currentHand.remove(card);

      // 마지막으로 낸 카드/플레이어 기록
      lastPlayedCard = card;
      lastPlayerIndex = currentTurn;
      lastPlayerName = _getPlayerName(currentTurn);

      discardPile.add(card);
      declaredSuit = null; // 초기화

      // 조커가 아닌 카드는 기준 카드로 저장
      if (!card.isJoker) {
        lastNormalCard = card;
      }

      // 체인 모드 해제 (K 이후 카드를 냈으므로)
      if (chainMode) {
        chainMode = false;
        chainSuit = null;
      }

      // 카드 효과 처리
      if (card.isAttack) {
        attackStack += card.attackPower;
        gameMessage = '${_getPlayerName(currentTurn)}: 공격! +${card.attackPower}장 (총 $attackStack장)';
      } else if (card.isJump) {
        skipNextTurn = true;
        gameMessage = '${_getPlayerName(currentTurn)}: J! 다음 턴 건너뛰기';
      } else if (card.isReverse) {
        // Q: 방향 반대
        if (playerCount == 2) {
          skipNextTurn = true;
          gameMessage = '${_getPlayerName(currentTurn)}: Q! 턴 건너뛰기';
        } else {
          turnDirection *= -1;
          gameMessage = '${_getPlayerName(currentTurn)}: Q! 방향 반대';
        }
      } else if (card.isChain) {
        // K: 같은 무늬 더내기
        chainMode = true;
        chainSuit = card.suit;
        gameMessage = '${_getPlayerName(currentTurn)}: K! 같은 무늬(${_getSuitName(card.suit!)}) 더내기';
      } else if (card.isChange) {
        if (newSuit != null) {
          declaredSuit = newSuit;
          gameMessage = '${_getPlayerName(currentTurn)}: 7! 무늬 변경: ${_getSuitName(newSuit)}';
        }
      } else {
        gameMessage = '${_getPlayerName(currentTurn)}이(가) 카드를 냈습니다';
      }

      // 승리 체크
      if (playerHand.isEmpty) {
        gameOver = true;
        winner = '플레이어';
        return;
      }
      for (int i = 0; i < computerHands.length; i++) {
        if (computerHands[i].isEmpty) {
          gameOver = true;
          winner = '컴퓨터 ${i + 1}';
          return;
        }
      }

      // 원카드 체크 - 카드 낸 후 1장 남았을 때
      if (currentTurn == 0 && playerHand.length == 1 && !playerCalledOneCard) {
        // 원카드 안 외침 - 벌칙은 턴 넘길 때 체크
      }
      if (currentTurn > 0 && computerHands[currentTurn - 1].length == 1) {
        // 컴퓨터는 자동으로 원카드 외침
        computerCalledOneCard[currentTurn - 1] = true;
        gameMessage = '${_getPlayerName(currentTurn)}: 원카드!';
      }

      // 카드가 2장 이상이면 원카드 상태 리셋
      if (playerHand.length > 1) {
        playerCalledOneCard = false;
      }
      for (int i = 0; i < computerHands.length; i++) {
        if (computerHands[i].length > 1) {
          computerCalledOneCard[i] = false;
        }
      }

      // 체인 모드면 같은 플레이어가 계속
      if (chainMode) {
        if (currentTurn > 0 && !gameOver) {
          // 컴퓨터 턴이면 다음 버튼 대기
          waitingForNextTurn = true;
        } else {
          waitingForNextTurn = false;
        }
        return;
      }

      // 턴 전환
      if (skipNextTurn) {
        skipNextTurn = false;
        // 한 턴 건너뛰기
        currentTurn = _getNextTurn(currentTurn);
      }

      // 원카드 벌칙 체크 (턴 넘기기 전)
      if (currentTurn == 0 && playerHand.length == 1 && !playerCalledOneCard) {
        // 플레이어가 원카드 안 외침 - 2장 벌칙
        _drawCards(playerHand, 2);
        gameMessage = '원카드를 외치지 않아 2장 벌칙!';
        playerCalledOneCard = false;
      }

      // 다음 턴으로
      currentTurn = _getNextTurn(currentTurn);

      // 다음이 컴퓨터면 대기 상태 설정
      if (currentTurn > 0 && !gameOver) {
        if (lastPlayerIndex == 0) {
          // 플레이어가 행동한 후 → 자동으로 컴퓨터 턴 (버튼 대기 없음)
          waitingForNextTurn = false;
        } else {
          // 컴퓨터가 행동한 후 → 다음 순서 버튼 대기
          waitingForNextTurn = true;
        }
      } else {
        waitingForNextTurn = false;
      }
    });

    HapticFeedback.mediumImpact();

    // 플레이어가 행동했고 다음이 컴퓨터면 자동 진행
    if (lastPlayerIndex == 0 && currentTurn > 0 && !gameOver) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!gameOver && currentTurn > 0) {
          _computerTurn(currentTurn);
        }
      });
    }
  }

  // 다음 순서 버튼 눌렀을 때
  void _onNextTurn() {
    setState(() {
      waitingForNextTurn = false;
    });
    if (currentTurn > 0 && !gameOver) {
      Future.delayed(const Duration(milliseconds: 300), () => _computerTurn(currentTurn));
    }
  }

  void _callOneCard() {
    if (!isPlayerTurn || gameOver) return;
    if (playerHand.length > 2) return; // 2장 이하일 때만 가능

    setState(() {
      playerCalledOneCard = true;
      gameMessage = '원카드!';
    });
    HapticFeedback.heavyImpact();
  }

  void _playerDrawCards() {
    if (!isPlayerTurn || gameOver || waitingForNextTurn) return;

    setState(() {
      if (chainMode) {
        // 체인 모드: 같은 무늬 카드 없으면 1장 먹기
        _drawCards(playerHand, 1);
        gameMessage = '같은 무늬 카드가 없어 1장을 뽑았습니다';
        chainMode = false;
        chainSuit = null;
      } else if (attackStack > 0) {
        // 공격 받기
        _drawCards(playerHand, attackStack);
        gameMessage = '$attackStack장을 받았습니다';
        attackStack = 0;
      } else {
        // 일반 드로우
        _drawCards(playerHand, 1);
        gameMessage = '카드를 1장 뽑았습니다';
      }

      // 파산 체크
      if (playerHand.length >= bankruptcyLimit) {
        gameOver = true;
        winner = _getBankruptcyWinner();
        gameMessage = '파산! 카드가 ${playerHand.length}장이 되었습니다';
        return;
      }

      // 다음 턴으로
      currentTurn = _getNextTurn(currentTurn);

      // 플레이어가 행동했으므로 버튼 대기 없이 자동 진행
      waitingForNextTurn = false;
    });

    HapticFeedback.lightImpact();

    // 다음이 컴퓨터면 자동 진행
    if (!gameOver && currentTurn > 0) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!gameOver && currentTurn > 0) {
          _computerTurn(currentTurn);
        }
      });
    }
  }

  String _getBankruptcyWinner() {
    // 파산하지 않은 플레이어 중 카드가 가장 적은 사람
    if (playerCount == 2) return playerHand.length >= bankruptcyLimit ? '컴퓨터 1' : '플레이어';
    return '다른 플레이어';
  }

  void _computerTurn(int computerIndex) {
    if (gameOver || computerIndex == 0) return;

    final computerHand = computerHands[computerIndex - 1];
    final playable = _getPlayableCards(computerHand);
    final computerName = _getPlayerName(computerIndex);

    if (playable.isEmpty) {
      // 낼 카드 없음
      setState(() {
        if (chainMode) {
          // 체인 모드: 같은 무늬 카드 없으면 1장 먹기
          _drawCards(computerHand, 1);
          gameMessage = '$computerName: 같은 무늬 카드가 없어 1장을 뽑았습니다';
          chainMode = false;
          chainSuit = null;
        } else if (attackStack > 0) {
          _drawCards(computerHand, attackStack);
          gameMessage = '$computerName: $attackStack장을 받았습니다';
          attackStack = 0;
        } else {
          _drawCards(computerHand, 1);
          gameMessage = '$computerName: 1장을 뽑았습니다';
        }

        lastPlayedCard = null;
        lastPlayerIndex = computerIndex;
        lastPlayerName = computerName;

        // 파산 체크
        if (computerHand.length >= bankruptcyLimit) {
          gameOver = true;
          winner = '플레이어';
          gameMessage = '$computerName 파산! 카드가 ${computerHand.length}장이 되었습니다';
          return;
        }

        // 다음 턴
        currentTurn = _getNextTurn(currentTurn);

        // 다음이 플레이어면 대기 해제, 컴퓨터면 계속 대기
        if (currentTurn == 0) {
          waitingForNextTurn = false;
        } else {
          waitingForNextTurn = true;
        }
      });
    } else {
      // 카드 선택 (우선순위: 공격 > 점프 > 무늬변경 > 일반)
      PlayingCard cardToPlay;

      // 공격 상태면 가장 강한 공격 카드
      if (attackStack > 0) {
        playable.sort((a, b) => b.attackPower.compareTo(a.attackPower));
        cardToPlay = playable.first;
      } else if (chainMode) {
        // 체인 모드면 같은 무늬 카드 중 아무거나
        cardToPlay = playable[Random().nextInt(playable.length)];
      } else {
        // 전략적 선택
        final attacks = playable.where((c) => c.isAttack).toList();
        final jumps = playable.where((c) => c.isJump).toList();
        final reverses = playable.where((c) => c.isReverse).toList();
        final chains = playable.where((c) => c.isChain).toList();
        final changes = playable.where((c) => c.isChange).toList();
        final normals = playable.where((c) =>
            !c.isAttack && !c.isJump && !c.isReverse && !c.isChain && !c.isChange).toList();

        if (attacks.isNotEmpty && Random().nextDouble() < 0.5) {
          cardToPlay = attacks[Random().nextInt(attacks.length)];
        } else if (jumps.isNotEmpty && Random().nextDouble() < 0.3) {
          cardToPlay = jumps.first;
        } else if (reverses.isNotEmpty && Random().nextDouble() < 0.3) {
          cardToPlay = reverses.first;
        } else if (chains.isNotEmpty && Random().nextDouble() < 0.4) {
          // K는 같은 무늬 카드가 많을 때 유리
          final kCard = chains.first;
          final sameSuitCount = computerHand.where((c) => c.suit == kCard.suit).length;
          if (sameSuitCount >= 2) {
            cardToPlay = kCard;
          } else if (normals.isNotEmpty) {
            cardToPlay = normals[Random().nextInt(normals.length)];
          } else {
            cardToPlay = playable[Random().nextInt(playable.length)];
          }
        } else if (normals.isNotEmpty) {
          cardToPlay = normals[Random().nextInt(normals.length)];
        } else if (changes.isNotEmpty) {
          cardToPlay = changes.first;
        } else {
          cardToPlay = playable[Random().nextInt(playable.length)];
        }
      }

      // 7이면 가장 많은 무늬로 변경
      Suit? newSuit;
      if (cardToPlay.isChange) {
        final suitCounts = <Suit, int>{};
        for (var card in computerHand) {
          if (card.suit != null) {
            suitCounts[card.suit!] = (suitCounts[card.suit!] ?? 0) + 1;
          }
        }
        if (suitCounts.isNotEmpty) {
          newSuit = suitCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
        } else {
          newSuit = Suit.values[Random().nextInt(4)];
        }
      }

      _playCard(cardToPlay, newSuit: newSuit);
    }
  }

  String _getSuitName(Suit suit) {
    switch (suit) {
      case Suit.spade:
        return '스페이드';
      case Suit.heart:
        return '하트';
      case Suit.diamond:
        return '다이아몬드';
      case Suit.club:
        return '클로버';
    }
  }

  void _onPlayerCardTap(int index) {
    if (!isPlayerTurn || gameOver || showSuitPicker) return;

    final card = playerHand[index];
    final playable = _getPlayableCards(playerHand);

    if (!playable.contains(card)) {
      setState(() {
        gameMessage = '이 카드는 낼 수 없습니다';
      });
      HapticFeedback.lightImpact();
      return;
    }

    // 7이면 무늬 선택 UI
    if (card.isChange) {
      setState(() {
        pendingCard = card;
        showSuitPicker = true;
      });
      return;
    }

    _playCard(card);
  }

  void _selectSuit(Suit suit) {
    if (pendingCard == null) return;

    setState(() {
      showSuitPicker = false;
    });

    _playCard(pendingCard!, newSuit: suit);
    pendingCard = null;
  }

  void _restartGame() {
    setState(() {
      _initGame();
    });
    HapticFeedback.mediumImpact();
  }

  void _selectPlayerCount(int count) {
    setState(() {
      playerCount = count;
      showPlayerSelect = false;
      _initGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (showPlayerSelect) {
      return _buildPlayerSelectScreen();
    }

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

  Widget _buildPlayerSelectScreen() {
    return Scaffold(
      backgroundColor: Colors.green.shade900,
      appBar: AppBar(
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        title: const Text('원카드', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '인원 선택',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPlayerCountButton(2),
                const SizedBox(width: 16),
                _buildPlayerCountButton(3),
                const SizedBox(width: 16),
                _buildPlayerCountButton(4),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '컴퓨터 상대와 게임합니다',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCountButton(int count) {
    return GestureDetector(
      onTap: () => _selectPlayerCount(count),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.green.shade700,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 2),
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
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '인',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Scaffold(
      backgroundColor: Colors.green.shade900,
      appBar: AppBar(
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        title: Text(
          '원카드 (${playerCount}인)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () => setState(() => showPlayerSelect = true),
            tooltip: '인원 변경',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _restartGame,
            tooltip: '다시 시작',
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // 상단 컴퓨터 (컴퓨터 1)
                if (computerHands.isNotEmpty) _buildComputerHandWidget(0),
                // 게임 정보
                _buildGameInfo(),
                // 중앙 영역 (좌우 컴퓨터 + 카드)
                Expanded(
                  child: playerCount > 2
                      ? Row(
                          children: [
                            // 왼쪽 컴퓨터 (컴퓨터 2)
                            if (computerHands.length >= 2)
                              _buildSideComputerHand(1),
                            // 중앙 카드 영역
                            Expanded(child: _buildCenterArea()),
                            // 오른쪽 컴퓨터 (컴퓨터 3)
                            if (computerHands.length >= 3)
                              _buildSideComputerHand(2),
                          ],
                        )
                      : _buildCenterArea(),
                ),
                // 메시지
                if (gameMessage != null) _buildMessage(),
                // 다음 순서 버튼
                if (waitingForNextTurn) _buildNextTurnButton(),
                // 원카드 버튼
                if (!waitingForNextTurn) _buildOneCardButton(),
                // 플레이어 핸드
                _buildPlayerHand(),
              ],
            ),
            // 무늬 선택 UI
            if (showSuitPicker) _buildSuitPicker(),
            // 게임 오버 오버레이
            if (gameOver) _buildGameOverOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildNextTurnButton() {
    return GestureDetector(
      onTap: _onNextTurn,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade700,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow, color: Colors.white, size: 24),
            const SizedBox(width: 8),
            Text(
              '다음 순서 (${_getPlayerName(currentTurn)})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideComputerHand(int computerIndex) {
    if (computerIndex >= computerHands.length) return const SizedBox();

    final hand = computerHands[computerIndex];
    final isCurrentTurn = currentTurn == computerIndex + 1;

    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 컴퓨터 이름
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isCurrentTurn ? Colors.blue : Colors.black38,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'C${computerIndex + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          // 카드 수
          Text(
            '${hand.length}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 8),
          // 카드 뒷면 스택
          Expanded(
            child: _buildVerticalCardStack(hand.length),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalCardStack(int cardCount) {
    final overlap = 12.0;
    final cardHeight = 35.0;
    final maxVisible = 8;
    final visibleCount = cardCount > maxVisible ? maxVisible : cardCount;
    final totalHeight = cardHeight + (visibleCount - 1) * overlap;

    return Center(
      child: SizedBox(
        width: 30,
        height: totalHeight,
        child: Stack(
          children: List.generate(visibleCount, (index) {
            return Positioned(
              top: index * overlap,
              child: Container(
                width: 30,
                height: cardHeight,
                decoration: BoxDecoration(
                  color: Colors.blue.shade800,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: Colors.white, width: 0.5),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Scaffold(
      body: Container(
        color: Colors.green.shade900,
        child: SafeArea(
          child: Stack(
            children: [
              // 메인 게임 레이아웃
              Row(
                children: [
                  // 왼쪽: 컴퓨터 핸드 (세로 배치)
                  _buildLandscapeComputerHand(),
                  // 중앙: 게임 영역
                  Expanded(
                    child: Column(
                      children: [
                        // 게임 정보
                        _buildLandscapeGameInfo(),
                        // 중앙 카드 영역
                        Expanded(
                          child: _buildCenterArea(),
                        ),
                        // 메시지
                        if (gameMessage != null) _buildMessage(),
                      ],
                    ),
                  ),
                  // 오른쪽: 플레이어 핸드 (세로 배치)
                  _buildLandscapePlayerHand(),
                ],
              ),
              // 왼쪽 상단: 뒤로가기 버튼
              Positioned(
                top: 8,
                left: 8,
                child: Row(
                  children: [
                    _buildCircleButton(
                      icon: Icons.arrow_back,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        '원카드',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 오른쪽 상단: 새 게임 버튼
              Positioned(
                top: 8,
                right: 8,
                child: _buildCircleButton(
                  icon: Icons.refresh,
                  onPressed: _restartGame,
                ),
              ),
              // 하단 중앙: 다음 순서 버튼 또는 원카드 버튼
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: waitingForNextTurn
                      ? _buildNextTurnButton()
                      : _buildOneCardButton(),
                ),
              ),
              // 무늬 선택 UI
              if (showSuitPicker) _buildSuitPicker(),
              // 게임 오버 오버레이
              if (gameOver) _buildGameOverOverlay(),
            ],
          ),
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildLandscapeComputerHand() {
    if (computerHands.isEmpty) return const SizedBox();
    final hand = computerHands[0];

    // 카드 겹침 정도 계산
    final cardHeight = 56.0;
    final overlap = 18.0;
    final totalHeight = cardHeight + (hand.length - 1) * overlap;

    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: SizedBox(
          width: 40,
          height: totalHeight,
          child: Stack(
            children: List.generate(hand.length, (index) {
              return Positioned(
                top: index * overlap,
                child: _buildSmallCardBack(),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapePlayerHand() {
    final playable = _getPlayableCards(playerHand);

    // 3열로 배열
    const int columns = 3;
    final int rows = (playerHand.length / columns).ceil();
    final List<List<int>> grid = [];

    for (int row = 0; row < rows; row++) {
      final List<int> rowIndices = [];
      for (int col = 0; col < columns; col++) {
        final index = row * columns + col;
        if (index < playerHand.length) {
          rowIndices.add(index);
        }
      }
      grid.add(rowIndices);
    }

    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 4),
      child: Center(
        child: SingleChildScrollView(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: List.generate(playerHand.length, (index) {
              final card = playerHand[index];
              final canPlay = playable.contains(card) && isPlayerTurn && !gameOver && !waitingForNextTurn;

              return GestureDetector(
                onTap: () => _onPlayerCardTap(index),
                child: Opacity(
                  opacity: canPlay ? 1.0 : 0.7,
                  child: _buildSmallPlayingCard(card, highlight: canPlay),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallCardBack() {
    return Container(
      width: 40,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.blue.shade800,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.blue.shade300, width: 1),
          ),
          child: const Center(
            child: Icon(Icons.style, color: Colors.white54, size: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallPlayingCard(PlayingCard card, {bool highlight = false}) {
    return Container(
      width: 48,
      height: 67,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: highlight ? Colors.yellow : Colors.grey.shade400,
          width: highlight ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlight
                ? Colors.yellow.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: highlight ? 6 : 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: card.isJoker
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.purple, size: 16),
                  Text(
                    'JKR',
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 6,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                Positioned(
                  left: 3,
                  top: 2,
                  child: Column(
                    children: [
                      Text(
                        card.rankString,
                        style: TextStyle(
                          color: card.suitColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        card.suitSymbol,
                        style: TextStyle(
                          color: card.suitColor,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: Text(
                    card.suitSymbol,
                    style: TextStyle(
                      color: card.suitColor,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLandscapeGameInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 컴퓨터 카드 수
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.computer, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  computerHands.isNotEmpty ? '${computerHands[0].length}' : '0',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 공격 스택
          if (attackStack > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.yellow, size: 16),
                  const SizedBox(width: 2),
                  Text(
                    '+$attackStack',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          if (attackStack > 0) const SizedBox(width: 12),
          // 체인 모드 (K)
          if (chainMode && chainSuit != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('K', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 2),
                  Text(
                    _getSuitSymbol(chainSuit!),
                    style: TextStyle(
                      color: _getSuitColor(chainSuit!),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (chainMode && chainSuit != null) const SizedBox(width: 12),
          // 선언된 무늬
          if (declaredSuit != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getSuitSymbol(declaredSuit!),
                style: TextStyle(
                  color: _getSuitColor(declaredSuit!),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (declaredSuit != null) const SizedBox(width: 12),
          // 턴 표시 (2인용에서만)
          if (playerCount == 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isPlayerTurn ? Colors.blue.withValues(alpha: 0.7) : Colors.orange.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isPlayerTurn ? '내 턴' : '상대 턴',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          if (playerCount == 2) const SizedBox(width: 12),
          // 플레이어 카드 수
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${playerHand.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComputerHandWidget(int computerIndex) {
    if (computerIndex >= computerHands.length) return const SizedBox();

    final hand = computerHands[computerIndex];
    final isCurrentTurn = currentTurn == computerIndex + 1;

    // 카드 겹침 정도 계산 (카드 수에 따라 동적)
    final cardWidth = 50.0;
    final overlap = 25.0; // 겹침 정도
    final totalWidth = cardWidth + (hand.length - 1) * overlap;

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          // 컴퓨터 이름과 카드 수
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isCurrentTurn ? Colors.blue : Colors.black38,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '컴퓨터 ${computerIndex + 1} (${hand.length}장)',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          // 카드 스택
          Expanded(
            child: Center(
              child: SizedBox(
                width: totalWidth,
                height: 60,
                child: Stack(
                  children: List.generate(hand.length, (index) {
                    return Positioned(
                      left: index * overlap,
                      child: _buildSmallCardBackForTop(),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallCardBackForTop() {
    return Container(
      width: 45,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.blue.shade800,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Center(
        child: Container(
          width: 35,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.blue.shade300, width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: 50,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.blue.shade800,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 40,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.blue.shade700,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue.shade300, width: 1),
          ),
          child: const Center(
            child: Icon(Icons.style, color: Colors.white54, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildGameInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 컴퓨터 카드 수
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.computer, color: Colors.white70, size: 18),
                const SizedBox(width: 6),
                Text(
                  computerHands.isNotEmpty ? '${computerHands[0].length}장' : '0장',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          // 공격 스택
          if (attackStack > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Colors.yellow, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '+$attackStack',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          // 체인 모드 (K)
          if (chainMode && chainSuit != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text('K', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Text(
                    _getSuitSymbol(chainSuit!),
                    style: TextStyle(
                      color: _getSuitColor(chainSuit!),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          // 선언된 무늬
          if (declaredSuit != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getSuitSymbol(declaredSuit!),
                style: TextStyle(
                  color: _getSuitColor(declaredSuit!),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          // 턴 표시 (2인용에서만)
          if (playerCount == 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isPlayerTurn ? Colors.blue.withValues(alpha: 0.7) : Colors.orange.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isPlayerTurn ? '내 턴' : '상대 턴',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  String _getSuitSymbol(Suit suit) {
    switch (suit) {
      case Suit.spade:
        return '♠';
      case Suit.heart:
        return '♥';
      case Suit.diamond:
        return '◆';
      case Suit.club:
        return '♣';
    }
  }

  Color _getSuitColor(Suit suit) {
    if (suit == Suit.heart || suit == Suit.diamond) {
      return Colors.red;
    }
    return Colors.black;
  }

  Widget _buildCenterArea() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 덱
          GestureDetector(
            onTap: isPlayerTurn && !gameOver ? _playerDrawCards : null,
            child: Stack(
              children: [
                _buildCardBack(),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${deck.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // 버린 카드 더미 (현재 카드)
          _buildPlayingCard(topCard, size: 1.2),
        ],
      ),
    );
  }

  Widget _buildPlayingCard(PlayingCard card, {double size = 1.0, bool highlight = false}) {
    final width = 60.0 * size;
    final height = 84.0 * size;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8 * size),
        border: Border.all(
          color: highlight ? Colors.yellow : Colors.grey.shade400,
          width: highlight ? 3 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlight
                ? Colors.yellow.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: highlight ? 8 : 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: card.isJoker
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.purple, size: 20 * size),
                  Text(
                    'JOKER',
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 8 * size,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // 좌상단
                Positioned(
                  left: 4 * size,
                  top: 4 * size,
                  child: Column(
                    children: [
                      Text(
                        card.rankString,
                        style: TextStyle(
                          color: card.suitColor,
                          fontSize: 14 * size,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        card.suitSymbol,
                        style: TextStyle(
                          color: card.suitColor,
                          fontSize: 12 * size,
                        ),
                      ),
                    ],
                  ),
                ),
                // 중앙
                Center(
                  child: Text(
                    card.suitSymbol,
                    style: TextStyle(
                      color: card.suitColor,
                      fontSize: 28 * size,
                    ),
                  ),
                ),
                // 우하단 (뒤집힌)
                Positioned(
                  right: 4 * size,
                  bottom: 4 * size,
                  child: Transform.rotate(
                    angle: 3.14159,
                    child: Column(
                      children: [
                        Text(
                          card.rankString,
                          style: TextStyle(
                            color: card.suitColor,
                            fontSize: 14 * size,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          card.suitSymbol,
                          style: TextStyle(
                            color: card.suitColor,
                            fontSize: 12 * size,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        gameMessage!,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }

  Widget _buildOneCardButton() {
    // 카드가 2장 이하일 때만 버튼 표시
    final showButton = playerHand.length <= 2 && isPlayerTurn && !gameOver;
    final alreadyCalled = playerCalledOneCard;

    if (!showButton) {
      return const SizedBox(height: 40);
    }

    return GestureDetector(
      onTap: alreadyCalled ? null : _callOneCard,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: alreadyCalled
              ? Colors.grey.shade600
              : Colors.orange.shade700,
          borderRadius: BorderRadius.circular(20),
          boxShadow: alreadyCalled
              ? []
              : [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              alreadyCalled ? Icons.check_circle : Icons.campaign,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              alreadyCalled ? '원카드!' : '원카드',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerHand() {
    final playable = _getPlayableCards(playerHand);

    // 2줄로 배열
    final int cardsPerRow = (playerHand.length / 2).ceil();
    final List<List<int>> rows = [];
    for (int i = 0; i < playerHand.length; i += cardsPerRow) {
      rows.add(List.generate(
        (i + cardsPerRow > playerHand.length) ? playerHand.length - i : cardsPerRow,
        (j) => i + j,
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows.map((rowIndices) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: rowIndices.map((index) {
                final card = playerHand[index];
                final canPlay = playable.contains(card) && isPlayerTurn && !gameOver;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () => _onPlayerCardTap(index),
                    child: Opacity(
                      opacity: canPlay ? 1.0 : 0.7,
                      child: _buildPlayingCard(card, size: 0.85, highlight: canPlay),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSuitPicker() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '무늬를 선택하세요',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSuitButton(Suit.spade, '♠', Colors.black),
                  const SizedBox(width: 12),
                  _buildSuitButton(Suit.heart, '♥', Colors.red),
                  const SizedBox(width: 12),
                  _buildSuitButton(Suit.diamond, '◆', Colors.red),
                  const SizedBox(width: 12),
                  _buildSuitButton(Suit.club, '♣', Colors.black),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuitButton(Suit suit, String symbol, Color color) {
    return GestureDetector(
      onTap: () => _selectSuit(suit),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Text(
            symbol,
            style: TextStyle(
              color: color,
              fontSize: 36,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay() {
    final isPlayerWinner = winner == '플레이어';

    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPlayerWinner ? Colors.amber : Colors.red,
              width: 3,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPlayerWinner ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                color: isPlayerWinner ? Colors.amber : Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                isPlayerWinner ? '승리!' : '패배',
                style: TextStyle(
                  color: isPlayerWinner ? Colors.amber : Colors.red,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$winner 승리',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _restartGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  '다시 하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
