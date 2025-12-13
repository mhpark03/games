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

  // 카드 뽑기 수 (1장 또는 3장)
  int drawCount = 1;

  // Undo 히스토리
  List<Map<String, dynamic>> _undoHistory = [];

  @override
  void initState() {
    super.initState();
    _checkSavedGame();
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
    // 항상 풀 수 있는 게임 생성 (역방향 딜 방식)
    _generateSolvableGame();

    moves = 0;
    isGameWon = false;
    draggedCards = null;
    dragSource = null;
    dragSourceIndex = null;
    _undoHistory = [];
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
    }
  }

  // 모든 카드가 열려있는지 확인 (자동 완료 가능 여부)
  bool _canAutoComplete() {
    // 스톡에 카드가 남아있으면 불가
    if (stock.isNotEmpty) return false;

    // 웨이스트에 카드가 남아있으면 불가
    if (waste.isNotEmpty) return false;

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

      // 테이블에서 파운데이션으로 이동할 수 있는 카드 찾기
      for (int col = 0; col < 7; col++) {
        if (tableau[col].isEmpty) continue;

        final card = tableau[col].last;

        // 파운데이션에 놓을 수 있는지 확인
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
                '이동: $moves (${drawCount}장)',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undoHistory.isEmpty ? null : _undo,
            tooltip: '되돌리기',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _clearSavedGame();
              _showDrawModeDialog();
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

        // 3장 모드일 때 최대 3장까지 겹쳐서 표시
        if (drawCount == 3 && waste.length > 1) {
          // 표시할 카드 수 (최대 3장)
          final visibleCount = min(3, waste.length);
          final startIndex = waste.length - visibleCount;
          final topCard = waste.last;

          return SizedBox(
            width: 50 + (visibleCount - 1) * 15.0,
            height: 70,
            child: Stack(
              children: List.generate(visibleCount, (i) {
                final cardIndex = startIndex + i;
                final card = waste[cardIndex];
                final isTop = i == visibleCount - 1;

                final cardWidget = _buildCard(card, width: 50, height: 70);

                if (isTop) {
                  // 맨 위 카드만 드래그 가능
                  return Positioned(
                    left: i * 15.0,
                    child: Draggable<Map<String, dynamic>>(
                      data: {'cards': [topCard], 'source': 'waste', 'index': null},
                      feedback: _buildCard(topCard, width: 50, height: 70),
                      childWhenDragging: i > 0
                          ? _buildCard(waste[cardIndex - 1], width: 50, height: 70)
                          : const SizedBox(width: 50, height: 70),
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
                    left: i * 15.0,
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
                        height: isEffectivelyLast ? 70 : 20,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: _buildCard(card,
                              width: double.infinity,
                              height: 70,
                              showPartial: !isEffectivelyLast),
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                // 뒷면 카드
                return SizedBox(
                  height: isEffectivelyLast ? 70 : 20,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _buildCardBack(
                        width: double.infinity,
                        height: 70,
                        showPartial: !isEffectivelyLast),
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
