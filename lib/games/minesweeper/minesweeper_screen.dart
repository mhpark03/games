import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/game_save_service.dart';

enum CellState { hidden, revealed, flagged }

enum MinesweeperDifficulty {
  easy,   // 9x9, 10개 지뢰
  medium, // 16x16, 40개 지뢰
  hard,   // 16x30, 99개 지뢰
}

class MinesweeperCell {
  bool hasMine;
  CellState state;
  int adjacentMines;

  MinesweeperCell({
    this.hasMine = false,
    this.state = CellState.hidden,
    this.adjacentMines = 0,
  });

  MinesweeperCell copy() {
    return MinesweeperCell(
      hasMine: hasMine,
      state: state,
      adjacentMines: adjacentMines,
    );
  }
}

class MinesweeperScreen extends StatefulWidget {
  final MinesweeperDifficulty difficulty;
  final bool resumeGame;

  const MinesweeperScreen({
    super.key,
    this.difficulty = MinesweeperDifficulty.easy,
    this.resumeGame = false,
  });

  static Future<bool> hasSavedGame() async {
    return await GameSaveService.hasSavedGame('minesweeper');
  }

  static Future<MinesweeperDifficulty?> getSavedDifficulty() async {
    final gameState = await GameSaveService.loadGame('minesweeper');
    if (gameState == null) return null;
    final difficultyIndex = gameState['difficulty'] as int?;
    if (difficultyIndex == null) return null;
    return MinesweeperDifficulty.values[difficultyIndex];
  }

  static Future<void> clearSavedGame() async {
    await GameSaveService.clearSave();
  }

  @override
  State<MinesweeperScreen> createState() => _MinesweeperScreenState();
}

class _MinesweeperScreenState extends State<MinesweeperScreen> {
  late int rows;
  late int cols;
  late int totalMines;
  late List<List<MinesweeperCell>> board;

  bool gameOver = false;
  bool gameWon = false;
  bool firstClick = true;
  int flagCount = 0;
  int revealedCount = 0;

  // 타이머
  int elapsedSeconds = 0;
  DateTime? startTime;

  @override
  void initState() {
    super.initState();
    _setupDifficulty();
    if (widget.resumeGame) {
      _loadGame();
    } else {
      _initBoard();
    }
  }

  void _setupDifficulty() {
    switch (widget.difficulty) {
      case MinesweeperDifficulty.easy:
        rows = 9;
        cols = 9;
        totalMines = 10;
        break;
      case MinesweeperDifficulty.medium:
        rows = 16;
        cols = 16;
        totalMines = 40;
        break;
      case MinesweeperDifficulty.hard:
        rows = 16;
        cols = 30;
        totalMines = 99;
        break;
    }
  }

  void _initBoard() {
    board = List.generate(
      rows,
      (_) => List.generate(cols, (_) => MinesweeperCell()),
    );
    gameOver = false;
    gameWon = false;
    firstClick = true;
    flagCount = 0;
    revealedCount = 0;
    elapsedSeconds = 0;
    startTime = null;
  }

  void _placeMines(int excludeRow, int excludeCol) {
    final random = Random();
    int placedMines = 0;

    while (placedMines < totalMines) {
      int r = random.nextInt(rows);
      int c = random.nextInt(cols);

      // 첫 클릭 위치와 주변 8칸은 지뢰 배치 제외
      if ((r - excludeRow).abs() <= 1 && (c - excludeCol).abs() <= 1) {
        continue;
      }

      if (!board[r][c].hasMine) {
        board[r][c].hasMine = true;
        placedMines++;
      }
    }

    // 인접 지뢰 수 계산
    _calculateAdjacentMines();
  }

  void _calculateAdjacentMines() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!board[r][c].hasMine) {
          int count = 0;
          for (int dr = -1; dr <= 1; dr++) {
            for (int dc = -1; dc <= 1; dc++) {
              int nr = r + dr;
              int nc = c + dc;
              if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
                if (board[nr][nc].hasMine) count++;
              }
            }
          }
          board[r][c].adjacentMines = count;
        }
      }
    }
  }

  void _onCellTap(int row, int col) {
    if (gameOver || gameWon) return;
    if (board[row][col].state != CellState.hidden) return;

    if (firstClick) {
      firstClick = false;
      startTime = DateTime.now();
      _placeMines(row, col);
    }

    _revealCell(row, col);
    _saveGame();
  }

  void _revealCell(int row, int col) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) return;
    if (board[row][col].state != CellState.hidden) return;

    setState(() {
      board[row][col].state = CellState.revealed;
      revealedCount++;

      if (board[row][col].hasMine) {
        gameOver = true;
        _revealAllMines();
        HapticFeedback.heavyImpact();
        return;
      }

      // 주변 지뢰가 없으면 주변 셀도 열기
      if (board[row][col].adjacentMines == 0) {
        for (int dr = -1; dr <= 1; dr++) {
          for (int dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            _revealCell(row + dr, col + dc);
          }
        }
      }

      // 승리 체크
      _checkWin();
    });
  }

  void _onCellLongPress(int row, int col) {
    if (gameOver || gameWon) return;
    if (board[row][col].state == CellState.revealed) return;

    setState(() {
      if (board[row][col].state == CellState.hidden) {
        board[row][col].state = CellState.flagged;
        flagCount++;
      } else {
        board[row][col].state = CellState.hidden;
        flagCount--;
      }
    });
    HapticFeedback.lightImpact();
    _saveGame();
  }

  void _revealAllMines() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (board[r][c].hasMine) {
          board[r][c].state = CellState.revealed;
        }
      }
    }
  }

  void _checkWin() {
    int totalCells = rows * cols;
    int safeCells = totalCells - totalMines;
    if (revealedCount == safeCells) {
      gameWon = true;
      HapticFeedback.heavyImpact();
      MinesweeperScreen.clearSavedGame();
    }
  }

  Future<void> _saveGame() async {
    if (gameOver || gameWon || firstClick) {
      await MinesweeperScreen.clearSavedGame();
      return;
    }

    final boardData = board.map((row) => row.map((cell) {
      return {
        'hasMine': cell.hasMine,
        'state': cell.state.index,
        'adjacentMines': cell.adjacentMines,
      };
    }).toList()).toList();

    final gameState = {
      'board': boardData,
      'difficulty': widget.difficulty.index,
      'flagCount': flagCount,
      'revealedCount': revealedCount,
      'elapsedSeconds': elapsedSeconds,
    };

    await GameSaveService.saveGame('minesweeper', gameState);
  }

  Future<void> _loadGame() async {
    final gameState = await GameSaveService.loadGame('minesweeper');

    if (gameState == null) {
      _initBoard();
      return;
    }

    final boardData = gameState['board'] as List;
    board = boardData.map<List<MinesweeperCell>>((row) {
      return (row as List).map<MinesweeperCell>((cellData) {
        final cell = cellData as Map<String, dynamic>;
        return MinesweeperCell(
          hasMine: cell['hasMine'] as bool,
          state: CellState.values[cell['state'] as int],
          adjacentMines: cell['adjacentMines'] as int,
        );
      }).toList();
    }).toList();

    setState(() {
      flagCount = gameState['flagCount'] as int? ?? 0;
      revealedCount = gameState['revealedCount'] as int? ?? 0;
      elapsedSeconds = gameState['elapsedSeconds'] as int? ?? 0;
      firstClick = false;
      gameOver = false;
      gameWon = false;
    });
  }

  void _restartGame() {
    setState(() {
      _initBoard();
    });
    MinesweeperScreen.clearSavedGame();
  }

  String _getDifficultyText() {
    switch (widget.difficulty) {
      case MinesweeperDifficulty.easy:
        return '초급';
      case MinesweeperDifficulty.medium:
        return '중급';
      case MinesweeperDifficulty.hard:
        return '고급';
    }
  }

  Color _getNumberColor(int number) {
    switch (number) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.red;
      case 4:
        return Colors.purple;
      case 5:
        return Colors.brown;
      case 6:
        return Colors.cyan;
      case 7:
        return Colors.black;
      case 8:
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.terrain, color: Colors.blueGrey),
            const SizedBox(width: 8),
            Text(
              'MINESWEEPER',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.blueGrey.shade100,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _restartGame,
            tooltip: '다시 시작',
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;

            if (isLandscape) {
              return Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildGameBoard(constraints),
                  ),
                  Expanded(
                    flex: 1,
                    child: _buildInfoPanel(isLandscape: true),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildInfoPanel(isLandscape: false),
                  Expanded(
                    child: _buildGameBoard(constraints),
                  ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildInfoPanel({required bool isLandscape}) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: isLandscape
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatusCard(),
                const SizedBox(height: 16),
                if (gameOver || gameWon) _buildResultMessage(),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildInfoItem(
                      icon: Icons.flag,
                      iconColor: Colors.red,
                      value: '${totalMines - flagCount}',
                      label: '남은 지뢰',
                    ),
                    _buildInfoItem(
                      icon: Icons.grid_on,
                      iconColor: Colors.blueGrey,
                      value: _getDifficultyText(),
                      label: '난이도',
                    ),
                    _buildInfoItem(
                      icon: Icons.check_circle,
                      iconColor: Colors.green,
                      value: '$revealedCount/${rows * cols - totalMines}',
                      label: '진행률',
                    ),
                  ],
                ),
                if (gameOver || gameWon) ...[
                  const SizedBox(height: 12),
                  _buildResultMessage(),
                ],
              ],
            ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blueGrey.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          _buildInfoItem(
            icon: Icons.flag,
            iconColor: Colors.red,
            value: '${totalMines - flagCount}',
            label: '남은 지뢰',
          ),
          const SizedBox(height: 12),
          _buildInfoItem(
            icon: Icons.grid_on,
            iconColor: Colors.blueGrey,
            value: _getDifficultyText(),
            label: '난이도',
          ),
          const SizedBox(height: 12),
          _buildInfoItem(
            icon: Icons.check_circle,
            iconColor: Colors.green,
            value: '$revealedCount/${rows * cols - totalMines}',
            label: '진행률',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: gameWon
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: gameWon ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            gameWon ? Icons.emoji_events : Icons.sentiment_very_dissatisfied,
            color: gameWon ? Colors.amber : Colors.red,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            gameWon ? '축하합니다!' : '게임 오버',
            style: TextStyle(
              color: gameWon ? Colors.green : Colors.red,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameBoard(BoxConstraints constraints) {
    return Center(
      child: AspectRatio(
        aspectRatio: cols / rows,
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade700,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.blueGrey.shade600,
              width: 3,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
              ),
              itemCount: rows * cols,
              itemBuilder: (context, index) {
                final row = index ~/ cols;
                final col = index % cols;
                return _buildCell(row, col);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    final cell = board[row][col];

    return GestureDetector(
      onTap: () => _onCellTap(row, col),
      onLongPress: () => _onCellLongPress(row, col),
      child: Container(
        decoration: BoxDecoration(
          color: _getCellColor(cell),
          border: Border.all(
            color: Colors.grey.shade600,
            width: 0.5,
          ),
        ),
        child: Center(
          child: _getCellContent(cell),
        ),
      ),
    );
  }

  Color _getCellColor(MinesweeperCell cell) {
    if (cell.state == CellState.hidden || cell.state == CellState.flagged) {
      return Colors.blueGrey.shade500;
    }
    if (cell.hasMine) {
      return Colors.red.shade400;
    }
    return Colors.grey.shade300;
  }

  Widget? _getCellContent(MinesweeperCell cell) {
    if (cell.state == CellState.flagged) {
      return const Icon(
        Icons.flag,
        color: Colors.red,
        size: 18,
      );
    }

    if (cell.state == CellState.hidden) {
      return null;
    }

    if (cell.hasMine) {
      return Icon(
        Icons.brightness_7,
        color: Colors.black,
        size: 18,
      );
    }

    if (cell.adjacentMines > 0) {
      return Text(
        '${cell.adjacentMines}',
        style: TextStyle(
          color: _getNumberColor(cell.adjacentMines),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
    }

    return null;
  }
}
