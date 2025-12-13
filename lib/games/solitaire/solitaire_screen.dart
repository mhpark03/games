import 'package:flutter/material.dart';
import 'dart:math';
import '../../services/game_save_service.dart';

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

  @override
  void initState() {
    super.initState();
    _checkSavedGame();
  }

  Future<void> _checkSavedGame() async {
    final hasSave = await GameSaveService.hasSavedGame('solitaire');

    if (hasSave && mounted) {
      // 저장된 게임이 있으면 다이얼로그 표시
      // 먼저 기본 초기화를 해서 late 변수 오류 방지
      _initGame();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showContinueDialog();
      });
    } else {
      _initGame();
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
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
                _initGame();
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
    // 52장의 카드 생성
    List<PlayingCard> deck = [];
    for (var suit in Suit.values) {
      for (int rank = 1; rank <= 13; rank++) {
        deck.add(PlayingCard(rank, suit));
      }
    }

    // 셔플
    final random = Random();
    deck.shuffle(random);

    // 테이블 초기화 (7열, 1-7장씩)
    tableau = List.generate(7, (_) => []);
    int cardIndex = 0;
    for (int col = 0; col < 7; col++) {
      for (int row = 0; row <= col; row++) {
        tableau[col].add(deck[cardIndex]);
        cardIndex++;
      }
      // 맨 위 카드만 앞면
      tableau[col].last.faceUp = true;
    }

    // 파운데이션 초기화 (4개의 빈 파일)
    foundations = List.generate(4, (_) => []);

    // 나머지는 스톡으로
    stock = deck.sublist(cardIndex);
    waste = [];

    moves = 0;
    isGameWon = false;
    draggedCards = null;
    dragSource = null;
    dragSourceIndex = null;
  }

  void _drawFromStock() {
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
        // 스톡에서 1장 뒤집기
        final card = stock.removeLast();
        card.faceUp = true;
        waste.add(card);
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
    }
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
        return;
      }
    }

    // 2순위: 테이블로 이동 시도
    for (int i = 0; i < 7; i++) {
      // 같은 열로는 이동하지 않음
      if (source == 'tableau_$i') continue;

      if (_canPlaceOnTableau(card, i)) {
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
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.green.shade700,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('솔리테어'),
        backgroundColor: Colors.green.shade800,
        foregroundColor: Colors.white,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '이동: $moves',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _clearSavedGame();
              setState(() {
                _initGame();
              });
            },
          ),
        ],
      ),
      backgroundColor: Colors.green.shade700,
      body: SafeArea(
        child: Column(
          children: [
            // 상단: 스톡, 웨이스트, 파운데이션
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  // 스톡
                  _buildStock(),
                  const SizedBox(width: 8),
                  // 웨이스트
                  _buildWaste(),
                  const Spacer(),
                  // 파운데이션 4개
                  ...List.generate(4, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _buildFoundation(index),
                    );
                  }),
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
        ),
      ),
      // 승리 오버레이
      floatingActionButton: isGameWon
          ? null
          : null,
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
        final card = waste.last;
        return Draggable<Map<String, dynamic>>(
          data: {'cards': [card], 'source': 'waste', 'index': null},
          feedback: _buildCard(card, width: 50, height: 70),
          childWhenDragging: waste.length > 1
              ? _buildCard(waste[waste.length - 2], width: 50, height: 70)
              : _buildCardPlaceholder(),
          onDragStarted: () => _onCardDragStart([card], 'waste', null),
          onDragEnd: (_) => _onCardDragEnd(),
          child: GestureDetector(
            onDoubleTap: () => _autoMoveCard(card, 'waste', null),
            child: _buildCard(card, width: 50, height: 70),
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
                fontSize: 24,
                color: Colors.white.withAlpha(77),
              ),
            ),
          );
        } else {
          final card = pile.last;
          cardWidget = Draggable<Map<String, dynamic>>(
            data: {'cards': [card], 'source': 'foundation_$index', 'index': index},
            feedback: _buildCard(card, width: 50, height: 70),
            childWhenDragging: pile.length > 1
                ? _buildCard(pile[pile.length - 2], width: 50, height: 70)
                : _buildCardPlaceholder(
                    child: Text(
                      ['♠', '♥', '♣', '♦'][index],
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.white.withAlpha(77),
                      ),
                    ),
                  ),
            onDragStarted: () => _onCardDragStart([card], 'foundation_$index', index),
            onDragEnd: (_) => _onCardDragEnd(),
            child: _buildCard(card, width: 50, height: 70),
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
          return Container(
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isHighlighted ? Colors.yellow : Colors.white30,
                width: isHighlighted ? 3 : 2,
              ),
            ),
            child: const Center(
              child: Text(
                'K',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          child: Column(
            children: List.generate(cards.length, (cardIndex) {
              final card = cards[cardIndex];
              final isLast = cardIndex == cards.length - 1;

              // 드래그 중인 카드인지 확인 (첫 번째 카드 제외 - Draggable이 관리)
              final isDragging = draggedCards != null &&
                  dragSource == 'tableau_$columnIndex' &&
                  draggedCards!.contains(card) &&
                  draggedCards!.first != card;  // 첫 번째 카드는 Draggable이 처리

              // 앞면 카드는 드래그 가능
              if (card.faceUp) {
                // 이 카드부터 끝까지의 카드들
                final dragCards = cards.sublist(cardIndex);

                // 드래그 중인 카드는 숨김 (첫 번째 카드 제외)
                if (isDragging) {
                  return SizedBox(
                    height: isLast ? 70 : 20,
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
                        width: 50,
                        height: 70 + (dragCards.length - 1) * 20.0,
                        child: Stack(
                          children: dragCards
                              .asMap()
                              .entries
                              .map((entry) => Positioned(
                                    top: entry.key * 20.0,
                                    left: 0,
                                    child: _buildCard(entry.value,
                                        width: 50, height: 70),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                    childWhenDragging: SizedBox(
                      height: isLast ? 70 : 20,
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
                        height: isLast ? 70 : 20,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _buildCard(card,
                              width: double.infinity,
                              height: 70,
                              showPartial: !isLast),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                // 뒷면 카드
                return SizedBox(
                  height: 20,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _buildCardBack(
                        width: double.infinity, height: 70, showPartial: true),
                  ),
                );
              }
            }),
          ),
        );
      },
    );
  }

  Widget _buildCardPlaceholder({Widget? child}) {
    return Container(
      width: 50,
      height: 70,
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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: width - 10,
          height: showPartial ? 10 : height - 10,
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
        borderRadius: BorderRadius.circular(6),
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
              child: Text(
                '${card.rankString}${card.suitString}',
                style: TextStyle(
                  color: card.suitColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 상단: 랭크 + 수트
                  Text(
                    '${card.rankString}${card.suitString}',
                    style: TextStyle(
                      color: card.suitColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  // 중앙 영역: 큰 수트 심볼
                  Expanded(
                    child: Center(
                      child: Text(
                        card.suitString,
                        style: TextStyle(
                          color: card.suitColor,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                  // 하단: 뒤집힌 랭크 + 수트
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Transform.rotate(
                      angle: 3.14159,
                      child: Text(
                        '${card.rankString}${card.suitString}',
                        style: TextStyle(
                          color: card.suitColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
