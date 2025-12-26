import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/game_save_service.dart';

// 화투 카드 종류
enum HwatuType {
  gwang, // 광
  tti, // 띠
  yeolkkeut, // 열끗 (동물)
  pi, // 피
  ssangpi, // 쌍피 (2장 가치)
}

// 띠 종류
enum TtiType {
  hongdan, // 홍단 (1, 2, 3월)
  chodan, // 초단 (4, 5, 7월)
  cheongdan, // 청단 (6, 9, 10월)
  none, // 띠 아님
}

// 화투 카드
class HwatuCard {
  final int month; // 1-12월
  final HwatuType type;
  final TtiType ttiType;
  final String name; // 카드 이름
  final bool isBiGwang; // 비광 여부 (12월 광)

  HwatuCard({
    required this.month,
    required this.type,
    this.ttiType = TtiType.none,
    required this.name,
    this.isBiGwang = false,
  });

  // 점수 가치 (피 계산용)
  int get piValue {
    if (type == HwatuType.ssangpi) return 2;
    if (type == HwatuType.pi) return 1;
    return 0;
  }

  // 월별 이모지/심볼
  String get monthSymbol {
    switch (month) {
      case 1:
        return '🌲'; // 송학
      case 2:
        return '🌸'; // 매화
      case 3:
        return '🌸'; // 벚꽃
      case 4:
        return '🌿'; // 등나무
      case 5:
        return '🌺'; // 창포
      case 6:
        return '🌺'; // 모란
      case 7:
        return '🍂'; // 홍싸리
      case 8:
        return '🌾'; // 공산
      case 9:
        return '🌼'; // 국화
      case 10:
        return '🍁'; // 단풍
      case 11:
        return '🌧️'; // 비
      case 12:
        return '🌳'; // 오동
      default:
        return '🎴';
    }
  }

  // 카드 배경색
  Color get cardColor {
    switch (type) {
      case HwatuType.gwang:
        return Colors.amber.shade100;
      case HwatuType.tti:
        switch (ttiType) {
          case TtiType.hongdan:
            return Colors.red.shade100;
          case TtiType.chodan:
            return Colors.green.shade100;
          case TtiType.cheongdan:
            return Colors.blue.shade100;
          default:
            return Colors.grey.shade100;
        }
      case HwatuType.yeolkkeut:
        return Colors.purple.shade100;
      case HwatuType.pi:
      case HwatuType.ssangpi:
        return Colors.grey.shade200;
    }
  }

  // 타입 표시 문자
  String get typeLabel {
    switch (type) {
      case HwatuType.gwang:
        return '光';
      case HwatuType.tti:
        return '띠';
      case HwatuType.yeolkkeut:
        return '열';
      case HwatuType.pi:
        return '피';
      case HwatuType.ssangpi:
        return '쌍';
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is HwatuCard) {
      return month == other.month && type == other.type && name == other.name;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(month, type, name);
}

// 화투 덱 생성
List<HwatuCard> createHwatuDeck() {
  return [
    // 1월 - 송학
    HwatuCard(month: 1, type: HwatuType.gwang, name: '송학'),
    HwatuCard(
        month: 1, type: HwatuType.tti, ttiType: TtiType.hongdan, name: '홍단'),
    HwatuCard(month: 1, type: HwatuType.pi, name: '피1'),
    HwatuCard(month: 1, type: HwatuType.pi, name: '피2'),

    // 2월 - 매화
    HwatuCard(month: 2, type: HwatuType.yeolkkeut, name: '꾀꼬리'),
    HwatuCard(
        month: 2, type: HwatuType.tti, ttiType: TtiType.hongdan, name: '홍단'),
    HwatuCard(month: 2, type: HwatuType.pi, name: '피1'),
    HwatuCard(month: 2, type: HwatuType.pi, name: '피2'),

    // 3월 - 벚꽃
    HwatuCard(month: 3, type: HwatuType.gwang, name: '벚꽃광'),
    HwatuCard(
        month: 3, type: HwatuType.tti, ttiType: TtiType.hongdan, name: '홍단'),
    HwatuCard(month: 3, type: HwatuType.pi, name: '피1'),
    HwatuCard(month: 3, type: HwatuType.pi, name: '피2'),

    // 4월 - 등나무
    HwatuCard(month: 4, type: HwatuType.yeolkkeut, name: '두견새'),
    HwatuCard(
        month: 4, type: HwatuType.tti, ttiType: TtiType.chodan, name: '초단'),
    HwatuCard(month: 4, type: HwatuType.pi, name: '피1'),
    HwatuCard(month: 4, type: HwatuType.pi, name: '피2'),

    // 5월 - 창포
    HwatuCard(month: 5, type: HwatuType.yeolkkeut, name: '다리'),
    HwatuCard(
        month: 5, type: HwatuType.tti, ttiType: TtiType.chodan, name: '초단'),
    HwatuCard(month: 5, type: HwatuType.pi, name: '피1'),
    HwatuCard(month: 5, type: HwatuType.pi, name: '피2'),

    // 6월 - 모란
    HwatuCard(month: 6, type: HwatuType.yeolkkeut, name: '나비'),
    HwatuCard(
        month: 6, type: HwatuType.tti, ttiType: TtiType.cheongdan, name: '청단'),
    HwatuCard(month: 6, type: HwatuType.pi, name: '피1'),
    HwatuCard(month: 6, type: HwatuType.pi, name: '피2'),

    // 7월 - 홍싸리
    HwatuCard(month: 7, type: HwatuType.yeolkkeut, name: '멧돼지'),
    HwatuCard(
        month: 7, type: HwatuType.tti, ttiType: TtiType.chodan, name: '초단'),
    HwatuCard(month: 7, type: HwatuType.pi, name: '피1'),
    HwatuCard(month: 7, type: HwatuType.pi, name: '피2'),

    // 8월 - 공산
    HwatuCard(month: 8, type: HwatuType.gwang, name: '공산'),
    HwatuCard(month: 8, type: HwatuType.yeolkkeut, name: '기러기'),
    HwatuCard(month: 8, type: HwatuType.pi, name: '피1'),
    HwatuCard(month: 8, type: HwatuType.pi, name: '피2'),

    // 9월 - 국화
    HwatuCard(month: 9, type: HwatuType.yeolkkeut, name: '술잔'),
    HwatuCard(
        month: 9, type: HwatuType.tti, ttiType: TtiType.cheongdan, name: '청단'),
    HwatuCard(month: 9, type: HwatuType.pi, name: '피1'),
    HwatuCard(month: 9, type: HwatuType.pi, name: '피2'),

    // 10월 - 단풍
    HwatuCard(month: 10, type: HwatuType.yeolkkeut, name: '사슴'),
    HwatuCard(
        month: 10, type: HwatuType.tti, ttiType: TtiType.cheongdan, name: '청단'),
    HwatuCard(month: 10, type: HwatuType.pi, name: '피1'),
    HwatuCard(month: 10, type: HwatuType.pi, name: '피2'),

    // 11월 - 비 (오동)
    HwatuCard(month: 11, type: HwatuType.gwang, name: '비광', isBiGwang: true),
    HwatuCard(month: 11, type: HwatuType.yeolkkeut, name: '제비'),
    HwatuCard(
        month: 11, type: HwatuType.tti, ttiType: TtiType.chodan, name: '초단'),
    HwatuCard(month: 11, type: HwatuType.ssangpi, name: '쌍피'),

    // 12월 - 오동
    HwatuCard(month: 12, type: HwatuType.gwang, name: '봉황'),
    HwatuCard(month: 12, type: HwatuType.pi, name: '피1'),
    HwatuCard(month: 12, type: HwatuType.pi, name: '피2'),
    HwatuCard(month: 12, type: HwatuType.pi, name: '피3'),
  ];
}

class HulaScreen extends StatefulWidget {
  final int playerCount;
  final bool resumeGame;

  const HulaScreen({
    super.key,
    this.playerCount = 2,
    this.resumeGame = false,
  });

  // 저장된 게임이 있는지 확인
  static Future<bool> hasSavedGame() async {
    return await GameSaveService.hasSavedGame('hula');
  }

  // 저장된 인원 수 가져오기
  static Future<int?> getSavedPlayerCount() async {
    final gameState = await GameSaveService.loadGame('hula');
    if (gameState == null) return null;
    return gameState['playerCount'] as int?;
  }

  // 저장된 게임 삭제
  static Future<void> clearSavedGame() async {
    await GameSaveService.clearSave();
  }

  @override
  State<HulaScreen> createState() => _HulaScreenState();
}

class _HulaScreenState extends State<HulaScreen> with TickerProviderStateMixin {
  // 덱과 카드
  List<HwatuCard> deck = [];
  List<HwatuCard> centerCards = []; // 바닥 패
  List<HwatuCard> playerHand = []; // 플레이어 손패
  List<List<HwatuCard>> computerHands = []; // 컴퓨터 손패

  // 획득한 카드
  List<HwatuCard> playerCaptured = [];
  List<List<HwatuCard>> computerCaptured = [];

  // 게임 상태
  late int playerCount;
  int currentTurn = 0; // 0 = 플레이어, 1+ = 컴퓨터
  bool gameOver = false;
  String? winner;
  int? winnerIndex;

  // 점수
  int playerScore = 0;
  List<int> computerScores = [];

  // 선택 상태
  HwatuCard? selectedHandCard;
  List<HwatuCard> matchingCenterCards = [];
  bool waitingForCenterSelection = false;

  // 덱에서 뒤집은 카드 처리
  HwatuCard? flippedCard;
  bool waitingForFlippedMatch = false;
  List<HwatuCard> flippedMatchingCards = [];

  // 메시지
  String? gameMessage;
  Timer? _messageTimer;

  // 애니메이션
  late AnimationController _cardAnimController;
  late Animation<double> _cardAnimation;

  // 목표 점수
  static const int targetScore = 3;

  @override
  void initState() {
    super.initState();
    playerCount = widget.playerCount;

    _cardAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _cardAnimation = CurvedAnimation(
      parent: _cardAnimController,
      curve: Curves.easeOut,
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
    _cardAnimController.dispose();
    super.dispose();
  }

  void _initGame() {
    deck = createHwatuDeck();
    deck.shuffle(Random());

    centerCards = [];
    playerHand = [];
    computerHands = List.generate(playerCount - 1, (_) => []);
    playerCaptured = [];
    computerCaptured = List.generate(playerCount - 1, (_) => []);
    computerScores = List.generate(playerCount - 1, (_) => 0);

    // 카드 배분: 각 플레이어 7장, 바닥 6장
    // 플레이어에게 7장
    for (int i = 0; i < 7; i++) {
      playerHand.add(deck.removeLast());
    }

    // 컴퓨터에게 각각 7장
    for (int c = 0; c < playerCount - 1; c++) {
      for (int i = 0; i < 7; i++) {
        computerHands[c].add(deck.removeLast());
      }
    }

    // 바닥에 6장
    for (int i = 0; i < 6; i++) {
      centerCards.add(deck.removeLast());
    }

    currentTurn = 0;
    gameOver = false;
    winner = null;
    winnerIndex = null;
    playerScore = 0;
    computerScores = List.generate(playerCount - 1, (_) => 0);

    selectedHandCard = null;
    matchingCenterCards = [];
    waitingForCenterSelection = false;
    flippedCard = null;
    waitingForFlippedMatch = false;
    flippedMatchingCards = [];

    setState(() {});
  }

  Future<void> _loadSavedGame() async {
    final gameState = await GameSaveService.loadGame('hula');
    if (gameState != null) {
      // 저장된 게임 로드 구현
      // 현재는 새 게임 시작
      _initGame();
    } else {
      _initGame();
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

  // 손패에서 카드 선택
  void _selectHandCard(HwatuCard card) {
    if (currentTurn != 0 || gameOver) return;
    if (waitingForFlippedMatch) return;

    // 같은 월의 바닥 카드 찾기
    final matches =
        centerCards.where((c) => c.month == card.month).toList();

    setState(() {
      selectedHandCard = card;
      matchingCenterCards = matches;

      if (matches.isEmpty) {
        // 매칭 카드 없음 - 바닥에 놓기
        waitingForCenterSelection = false;
      } else if (matches.length == 1) {
        // 1장 매칭 - 자동 획득
        waitingForCenterSelection = false;
      } else {
        // 2장 이상 매칭 - 선택 필요
        waitingForCenterSelection = true;
      }
    });
  }

  // 손패 카드 플레이
  void _playHandCard() {
    if (selectedHandCard == null) return;

    final card = selectedHandCard!;
    final matches = centerCards.where((c) => c.month == card.month).toList();

    playerHand.remove(card);

    if (matches.isEmpty) {
      // 바닥에 놓기
      centerCards.add(card);
      _showMessage('${card.month}월 카드를 바닥에 놓았습니다');
    } else if (matches.length == 1) {
      // 자동 획득
      final matched = matches.first;
      centerCards.remove(matched);
      playerCaptured.add(card);
      playerCaptured.add(matched);
      _showMessage('${card.month}월 카드 획득!');
    }

    setState(() {
      selectedHandCard = null;
      matchingCenterCards = [];
      waitingForCenterSelection = false;
    });

    // 덱에서 카드 뒤집기
    _flipCardFromDeck();
  }

  // 바닥에서 매칭 카드 선택 (2장 이상일 때)
  void _selectCenterCard(HwatuCard centerCard) {
    if (!waitingForCenterSelection || selectedHandCard == null) return;
    if (!matchingCenterCards.contains(centerCard)) return;

    final card = selectedHandCard!;
    playerHand.remove(card);
    centerCards.remove(centerCard);
    playerCaptured.add(card);
    playerCaptured.add(centerCard);

    _showMessage('${card.month}월 카드 획득!');

    setState(() {
      selectedHandCard = null;
      matchingCenterCards = [];
      waitingForCenterSelection = false;
    });

    // 덱에서 카드 뒤집기
    _flipCardFromDeck();
  }

  // 덱에서 카드 뒤집기
  void _flipCardFromDeck() {
    if (deck.isEmpty) {
      _endTurn();
      return;
    }

    final card = deck.removeLast();
    final matches = centerCards.where((c) => c.month == card.month).toList();

    setState(() {
      flippedCard = card;
      flippedMatchingCards = matches;
    });

    if (matches.isEmpty) {
      // 바닥에 놓기
      Timer(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          centerCards.add(card);
          flippedCard = null;
          flippedMatchingCards = [];
        });
        _showMessage('덱에서 ${card.month}월 - 바닥에 놓음');
        _endTurn();
      });
    } else if (matches.length == 1) {
      // 자동 획득
      Timer(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        final matched = matches.first;
        setState(() {
          centerCards.remove(matched);
          if (currentTurn == 0) {
            playerCaptured.add(card);
            playerCaptured.add(matched);
          } else {
            computerCaptured[currentTurn - 1].add(card);
            computerCaptured[currentTurn - 1].add(matched);
          }
          flippedCard = null;
          flippedMatchingCards = [];
        });
        _showMessage('덱에서 ${card.month}월 획득!');
        _endTurn();
      });
    } else {
      // 플레이어가 선택해야 함
      if (currentTurn == 0) {
        setState(() {
          waitingForFlippedMatch = true;
        });
        _showMessage('획득할 카드를 선택하세요');
      } else {
        // 컴퓨터는 첫 번째 카드 선택
        Timer(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          final matched = matches.first;
          setState(() {
            centerCards.remove(matched);
            computerCaptured[currentTurn - 1].add(card);
            computerCaptured[currentTurn - 1].add(matched);
            flippedCard = null;
            flippedMatchingCards = [];
          });
          _endTurn();
        });
      }
    }
  }

  // 덱에서 뒤집은 카드로 바닥 카드 선택
  void _selectFlippedMatch(HwatuCard centerCard) {
    if (!waitingForFlippedMatch || flippedCard == null) return;
    if (!flippedMatchingCards.contains(centerCard)) return;

    final card = flippedCard!;
    centerCards.remove(centerCard);

    if (currentTurn == 0) {
      playerCaptured.add(card);
      playerCaptured.add(centerCard);
    } else {
      computerCaptured[currentTurn - 1].add(card);
      computerCaptured[currentTurn - 1].add(centerCard);
    }

    setState(() {
      flippedCard = null;
      flippedMatchingCards = [];
      waitingForFlippedMatch = false;
    });

    _showMessage('${card.month}월 카드 획득!');
    _endTurn();
  }

  void _endTurn() {
    // 점수 계산
    _calculateScores();

    // 승리 체크
    if (_checkWin()) {
      return;
    }

    // 게임 종료 체크 (모든 손패 소진)
    if (_checkGameEnd()) {
      return;
    }

    // 다음 턴
    setState(() {
      currentTurn = (currentTurn + 1) % playerCount;
    });

    if (currentTurn != 0) {
      Timer(const Duration(milliseconds: 1000), () {
        if (mounted && !gameOver) {
          _computerTurn();
        }
      });
    }
  }

  void _computerTurn() {
    if (gameOver) return;

    final computerIndex = currentTurn - 1;
    final hand = computerHands[computerIndex];

    if (hand.isEmpty) {
      _endTurn();
      return;
    }

    // AI: 매칭 가능한 카드 우선, 없으면 낮은 점수 카드
    HwatuCard? bestCard;
    HwatuCard? bestMatch;

    // 매칭 가능한 카드 찾기
    for (final card in hand) {
      final matches = centerCards.where((c) => c.month == card.month).toList();
      if (matches.isNotEmpty) {
        // 높은 점수 카드 우선
        if (bestCard == null ||
            _getCardPriority(card) > _getCardPriority(bestCard)) {
          bestCard = card;
          bestMatch = matches.first;
        }
      }
    }

    // 매칭 카드 없으면 가장 낮은 우선순위 카드
    bestCard ??= hand.reduce((a, b) =>
        _getCardPriority(a) < _getCardPriority(b) ? a : b);

    hand.remove(bestCard);

    if (bestMatch != null) {
      // 매칭 획득
      centerCards.remove(bestMatch);
      computerCaptured[computerIndex].add(bestCard);
      computerCaptured[computerIndex].add(bestMatch);
      _showMessage('컴퓨터${computerIndex + 1}: ${bestCard.month}월 획득');
    } else {
      // 바닥에 놓기
      centerCards.add(bestCard);
      _showMessage('컴퓨터${computerIndex + 1}: ${bestCard.month}월 버림');
    }

    setState(() {});

    // 덱에서 카드 뒤집기
    Timer(const Duration(milliseconds: 800), () {
      if (mounted && !gameOver) {
        _flipCardFromDeck();
      }
    });
  }

  int _getCardPriority(HwatuCard card) {
    switch (card.type) {
      case HwatuType.gwang:
        return 100;
      case HwatuType.tti:
        return 50;
      case HwatuType.yeolkkeut:
        return 30;
      case HwatuType.ssangpi:
        return 15;
      case HwatuType.pi:
        return 10;
    }
  }

  void _calculateScores() {
    playerScore = _calculateScore(playerCaptured);
    for (int i = 0; i < computerCaptured.length; i++) {
      computerScores[i] = _calculateScore(computerCaptured[i]);
    }
  }

  int _calculateScore(List<HwatuCard> captured) {
    int score = 0;

    // 광 계산
    final gwangs = captured.where((c) => c.type == HwatuType.gwang).toList();
    final hasBiGwang = gwangs.any((c) => c.isBiGwang);

    if (gwangs.length == 5) {
      score += 15; // 5광
    } else if (gwangs.length == 4) {
      score += 4; // 4광
    } else if (gwangs.length == 3) {
      if (hasBiGwang) {
        score += 2; // 비광 포함 3광
      } else {
        score += 3; // 3광
      }
    }

    // 띠 계산
    final ttis = captured.where((c) => c.type == HwatuType.tti).toList();
    final hongdans =
        ttis.where((c) => c.ttiType == TtiType.hongdan).toList();
    final chodans =
        ttis.where((c) => c.ttiType == TtiType.chodan).toList();
    final cheongdans =
        ttis.where((c) => c.ttiType == TtiType.cheongdan).toList();

    if (hongdans.length >= 3) score += 3; // 홍단
    if (chodans.length >= 3) score += 3; // 초단
    if (cheongdans.length >= 3) score += 3; // 청단

    if (ttis.length >= 5) {
      score += 1 + (ttis.length - 5); // 띠 5장 이상
    }

    // 열끗 계산
    final yeolkkeuts =
        captured.where((c) => c.type == HwatuType.yeolkkeut).toList();
    if (yeolkkeuts.length >= 5) {
      score += 1 + (yeolkkeuts.length - 5); // 열끗 5장 이상
    }

    // 피 계산
    int piCount = 0;
    for (final card in captured) {
      piCount += card.piValue;
    }
    if (piCount >= 10) {
      score += 1 + (piCount - 10); // 피 10장 이상
    }

    return score;
  }

  bool _checkWin() {
    if (playerScore >= targetScore) {
      setState(() {
        gameOver = true;
        winner = '플레이어';
        winnerIndex = 0;
      });
      _showGameOverDialog();
      return true;
    }

    for (int i = 0; i < computerScores.length; i++) {
      if (computerScores[i] >= targetScore) {
        setState(() {
          gameOver = true;
          winner = '컴퓨터${i + 1}';
          winnerIndex = i + 1;
        });
        _showGameOverDialog();
        return true;
      }
    }

    return false;
  }

  bool _checkGameEnd() {
    // 모든 손패가 비었으면 게임 종료
    if (playerHand.isEmpty &&
        computerHands.every((hand) => hand.isEmpty)) {
      // 최고 점수 플레이어 결정
      int maxScore = playerScore;
      int maxIndex = 0;

      for (int i = 0; i < computerScores.length; i++) {
        if (computerScores[i] > maxScore) {
          maxScore = computerScores[i];
          maxIndex = i + 1;
        }
      }

      setState(() {
        gameOver = true;
        if (maxIndex == 0) {
          winner = '플레이어';
        } else {
          winner = '컴퓨터$maxIndex';
        }
        winnerIndex = maxIndex;
      });
      _showGameOverDialog();
      return true;
    }

    return false;
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
            color: winnerIndex == 0
                ? Colors.amber
                : Colors.red.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        title: Text(
          winnerIndex == 0 ? '🎉 승리!' : '😢 패배',
          style: TextStyle(
            color: winnerIndex == 0 ? Colors.amber : Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$winner 승리!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '플레이어: $playerScore점',
              style: TextStyle(
                color: winnerIndex == 0 ? Colors.amber : Colors.white70,
              ),
            ),
            ...List.generate(
              computerScores.length,
              (i) => Text(
                '컴퓨터${i + 1}: ${computerScores[i]}점',
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
              setState(() {
                _initGame();
              });
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
      backgroundColor: const Color(0xFF1A472A), // 녹색 테이블
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('훌라', style: TextStyle(color: Colors.white)),
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
        child: Column(
          children: [
            // 점수판
            _buildScoreBoard(),

            // 컴퓨터 손패 (뒷면)
            if (playerCount > 1) _buildComputerHands(),

            // 바닥 카드
            Expanded(
              child: _buildCenterArea(),
            ),

            // 메시지
            if (gameMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  gameMessage!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),

            // 플레이어 손패
            _buildPlayerHand(),

            // 액션 버튼
            if (selectedHandCard != null && !waitingForCenterSelection)
              _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBoard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildScoreChip('플레이어', playerScore, currentTurn == 0),
          ...List.generate(
            computerScores.length,
            (i) => _buildScoreChip(
              '컴퓨터${i + 1}',
              computerScores[i],
              currentTurn == i + 1,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.brown.shade700,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '덱: ${deck.length}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreChip(String name, int score, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.amber.shade700 : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.amber : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$score점',
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey.shade300,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComputerHands() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(computerHands.length, (i) {
          final hand = computerHands[i];
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'COM${i + 1}:',
                style: TextStyle(
                  color: currentTurn == i + 1 ? Colors.amber : Colors.white54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 4),
              ...List.generate(
                min(hand.length, 7),
                (j) => Container(
                  width: 20,
                  height: 30,
                  margin: const EdgeInsets.only(left: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade800, Colors.red.shade900],
                    ),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Center(
                    child: Text('🎴', style: TextStyle(fontSize: 10)),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCenterArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 덱에서 뒤집은 카드
          if (flippedCard != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '뒤집은 카드: ',
                    style: TextStyle(color: Colors.white70),
                  ),
                  _buildCard(flippedCard!, isFlipped: true),
                ],
              ),
            ),

          // 바닥 카드
          Expanded(
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: centerCards.map((card) {
                  final isMatchable = waitingForCenterSelection &&
                      matchingCenterCards.contains(card);
                  final isFlippedMatchable = waitingForFlippedMatch &&
                      flippedMatchingCards.contains(card);

                  return GestureDetector(
                    onTap: () {
                      if (isMatchable) {
                        _selectCenterCard(card);
                      } else if (isFlippedMatchable) {
                        _selectFlippedMatch(card);
                      }
                    },
                    child: _buildCard(
                      card,
                      isHighlighted: isMatchable || isFlippedMatchable,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 획득 카드 표시
          _buildCapturedCards(),
        ],
      ),
    );
  }

  Widget _buildCapturedCards() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildCapturedSummary('나', playerCaptured),
          ...List.generate(
            computerCaptured.length,
            (i) => _buildCapturedSummary('COM${i + 1}', computerCaptured[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildCapturedSummary(String name, List<HwatuCard> captured) {
    final gwangs = captured.where((c) => c.type == HwatuType.gwang).length;
    final ttis = captured.where((c) => c.type == HwatuType.tti).length;
    final yeols = captured.where((c) => c.type == HwatuType.yeolkkeut).length;
    int pis = 0;
    for (final c in captured) {
      pis += c.piValue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('光$gwangs ',
                  style: const TextStyle(color: Colors.amber, fontSize: 10)),
              Text('띠$ttis ',
                  style: const TextStyle(color: Colors.red, fontSize: 10)),
              Text('열$yeols ',
                  style: const TextStyle(color: Colors.purple, fontSize: 10)),
              Text('피$pis',
                  style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerHand() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: playerHand.length,
        itemBuilder: (context, index) {
          final card = playerHand[index];
          final isSelected = selectedHandCard == card;

          return GestureDetector(
            onTap: () => _selectHandCard(card),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.translationValues(
                0,
                isSelected ? -10 : 0,
                0,
              ),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildCard(
                card,
                isSelected: isSelected,
                size: 1.2,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(
    HwatuCard card, {
    bool isSelected = false,
    bool isHighlighted = false,
    bool isFlipped = false,
    double size = 1.0,
  }) {
    final width = 50.0 * size;
    final height = 75.0 * size;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: card.cardColor,
        borderRadius: BorderRadius.circular(6 * size),
        border: Border.all(
          color: isSelected
              ? Colors.amber
              : isHighlighted
                  ? Colors.green
                  : isFlipped
                      ? Colors.cyan
                      : Colors.grey.shade600,
          width: isSelected || isHighlighted || isFlipped ? 3 : 1,
        ),
        boxShadow: [
          if (isSelected || isHighlighted || isFlipped)
            BoxShadow(
              color: isSelected
                  ? Colors.amber.withValues(alpha: 0.5)
                  : isHighlighted
                      ? Colors.green.withValues(alpha: 0.5)
                      : Colors.cyan.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            card.monthSymbol,
            style: TextStyle(fontSize: 16 * size),
          ),
          Text(
            '${card.month}월',
            style: TextStyle(
              fontSize: 10 * size,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: 4 * size,
              vertical: 1 * size,
            ),
            decoration: BoxDecoration(
              color: _getTypeBadgeColor(card),
              borderRadius: BorderRadius.circular(4 * size),
            ),
            child: Text(
              card.typeLabel,
              style: TextStyle(
                fontSize: 8 * size,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeBadgeColor(HwatuCard card) {
    switch (card.type) {
      case HwatuType.gwang:
        return Colors.amber.shade700;
      case HwatuType.tti:
        switch (card.ttiType) {
          case TtiType.hongdan:
            return Colors.red.shade700;
          case TtiType.chodan:
            return Colors.green.shade700;
          case TtiType.cheongdan:
            return Colors.blue.shade700;
          default:
            return Colors.grey;
        }
      case HwatuType.yeolkkeut:
        return Colors.purple.shade700;
      case HwatuType.pi:
      case HwatuType.ssangpi:
        return Colors.grey.shade700;
    }
  }

  Widget _buildActionButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: _playHandCard,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        ),
        child: Text(
          matchingCenterCards.isEmpty
              ? '${selectedHandCard!.month}월 버리기'
              : '${selectedHandCard!.month}월 획득',
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
                '🎴 기본 규칙',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• 각 플레이어 7장, 바닥 6장으로 시작\n'
                '• 손패에서 카드를 내고 같은 월 카드 획득\n'
                '• 덱에서 한 장 뒤집어 추가 매칭\n'
                '• 먼저 3점 달성 시 승리',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 16),
              Text(
                '⭐ 점수 계산',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '• 3광: 3점 (비광 포함시 2점)\n'
                '• 4광: 4점, 5광: 15점\n'
                '• 홍단/초단/청단: 각 3점\n'
                '• 띠 5장: 1점 (+1점/장)\n'
                '• 열끗 5장: 1점 (+1점/장)\n'
                '• 피 10장: 1점 (+1점/장)',
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
