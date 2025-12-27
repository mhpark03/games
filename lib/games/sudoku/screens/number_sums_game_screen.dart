import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/number_sums_game_state.dart';
import '../models/number_sums_generator.dart';
import '../services/game_storage.dart';
import '../widgets/number_sums_board.dart';

class NumberSumsGameScreen extends StatefulWidget {
  final NumberSumsDifficulty? initialDifficulty;
  final NumberSumsGameState? savedGameState;

  const NumberSumsGameScreen({
    super.key,
    this.initialDifficulty,
    this.savedGameState,
  });

  @override
  State<NumberSumsGameScreen> createState() => _NumberSumsGameScreenState();
}

class _NumberSumsGameScreenState extends State<NumberSumsGameScreen>
    with WidgetsBindingObserver {
  late NumberSumsGameState _gameState;
  late NumberSumsDifficulty _selectedDifficulty;
  bool _isLoading = true;

  Timer? _timer;
  int _elapsedSeconds = 0;
  int _failureCount = 0;
  bool _isPaused = false;
  bool _isBackgrounded = false;
  NumberSumsGameMode _gameMode = NumberSumsGameMode.select; // 현재 게임 모드
  int? _errorRow; // 오류 발생한 셀
  int? _errorCol;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.savedGameState != null) {
      _gameState = widget.savedGameState!;
      _selectedDifficulty = _gameState.difficulty;
      _elapsedSeconds = _gameState.elapsedSeconds;
      _failureCount = _gameState.failureCount;
      _isLoading = false;
      _startTimer();
    } else {
      _selectedDifficulty =
          widget.initialDifficulty ?? NumberSumsDifficulty.medium;
      _startNewGame();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!_isLoading && !_gameState.isCompleted) {
        setState(() {
          _isBackgrounded = true;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      setState(() {
        _isBackgrounded = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && !_isBackgrounded && !_gameState.isCompleted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  Future<void> _startNewGame() async {
    await GameStorage.deleteAllGames();

    setState(() {
      _isLoading = true;
    });

    final data = await compute(
      generateNumberSumsPuzzleInIsolate,
      _selectedDifficulty,
    );

    if (mounted) {
      setState(() {
        _gameState = NumberSumsGameState.fromGeneratedData(data);
        _isLoading = false;
        _elapsedSeconds = 0;
        _failureCount = 0;
        _isPaused = false;
      });
      _startTimer();
      _saveGame();
    }
  }

  void _saveGame() {
    if (!_gameState.isCompleted) {
      _gameState.elapsedSeconds = _elapsedSeconds;
      _gameState.failureCount = _failureCount;
      GameStorage.saveNumberSumsGame(_gameState);
    } else {
      GameStorage.deleteNumberSumsGame();
    }
  }

  void _onCellTap(int row, int col) {
    if (_isPaused) return;
    if (_gameState.cellTypes[row][col] != 1) return;
    if (_gameState.currentBoard[row][col] == 0) return; // 이미 제거된 셀
    if (_gameState.isMarkedCorrect(row, col)) return; // 이미 정답으로 표시됨

    setState(() {
      // 이전 오류 표시 초기화
      _errorRow = null;
      _errorCol = null;

      if (_gameMode == NumberSumsGameMode.select) {
        // 선택 모드: 올바른 수인지 확인
        bool isWrong = _gameState.isWrongCell(row, col);
        if (!isWrong) {
          // 올바른 수! 동그라미 표시
          List<List<bool>> newMarkedCorrect =
              _gameState.markedCorrectCells.map((r) => List<bool>.from(r)).toList();
          newMarkedCorrect[row][col] = true;
          _gameState = _gameState.copyWith(markedCorrectCells: newMarkedCorrect);
        } else {
          // 틀린 수를 올바른 수로 선택 -> 실패!
          _failureCount++;
          _errorRow = row;
          _errorCol = col;
        }
      } else if (_gameMode == NumberSumsGameMode.remove) {
        // 제거 모드: 틀린 수인지 확인
        bool isWrong = _gameState.isWrongCell(row, col);
        if (isWrong) {
          // 틀린 수! 제거
          List<List<int>> newBoard =
              _gameState.currentBoard.map((r) => List<int>.from(r)).toList();
          newBoard[row][col] = 0;

          // 완성 체크
          bool isComplete = NumberSumsGenerator.isBoardComplete(
            newBoard,
            _gameState.solution,
            _gameState.gridSize,
          );

          _gameState = _gameState.copyWith(
            currentBoard: newBoard,
            isCompleted: isComplete,
          );

          if (isComplete) {
            _timer?.cancel();
            _showCompletionDialog();
          }
        } else {
          // 올바른 수를 제거하려고 함 -> 실패!
          _failureCount++;
          _errorRow = row;
          _errorCol = col;
        }
      } else if (_gameMode == NumberSumsGameMode.hint) {
        // 힌트 모드: 자동으로 정답 처리
        bool isWrong = _gameState.isWrongCell(row, col);
        if (isWrong) {
          // 틀린 수 -> 제거
          List<List<int>> newBoard =
              _gameState.currentBoard.map((r) => List<int>.from(r)).toList();
          newBoard[row][col] = 0;

          bool isComplete = NumberSumsGenerator.isBoardComplete(
            newBoard,
            _gameState.solution,
            _gameState.gridSize,
          );

          _gameState = _gameState.copyWith(
            currentBoard: newBoard,
            isCompleted: isComplete,
          );

          if (isComplete) {
            _timer?.cancel();
            _showCompletionDialog();
          }
        } else {
          // 올바른 수 -> 동그라미 표시
          List<List<bool>> newMarkedCorrect =
              _gameState.markedCorrectCells.map((r) => List<bool>.from(r)).toList();
          newMarkedCorrect[row][col] = true;
          _gameState = _gameState.copyWith(markedCorrectCells: newMarkedCorrect);
        }
      }
    });
    _saveGame();
  }

  void _setGameMode(NumberSumsGameMode mode) {
    setState(() {
      _gameMode = mode;
    });
  }

  void _showCompletionDialog() {
    String timeStr = _formatTime(_elapsedSeconds);
    GameStorage.deleteNumberSumsGame();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('축하합니다!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('모든 틀린 숫자를 제거했습니다!'),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 18),
                const SizedBox(width: 8),
                Text('소요 시간: $timeStr'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.close, size: 18, color: Colors.red.shade400),
                const SizedBox(width: 8),
                Text('실패 횟수: $_failureCount회'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showDifficultyDialog();
            },
            child: const Text('새 게임'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showDifficultyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('난이도 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: NumberSumsDifficulty.values.map((difficulty) {
            String label;
            switch (difficulty) {
              case NumberSumsDifficulty.easy:
                label = '쉬움 (5x5)';
                break;
              case NumberSumsDifficulty.medium:
                label = '보통 (6x6)';
                break;
              case NumberSumsDifficulty.hard:
                label = '어려움 (7x7)';
                break;
            }
            return ListTile(
              title: Text(label),
              leading: Icon(
                _selectedDifficulty == difficulty
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: Colors.deepOrange,
              ),
              onTap: () {
                setState(() {
                  _selectedDifficulty = difficulty;
                });
                Navigator.pop(context);
                _startNewGame();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text(
          '넘버 썸즈',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showDifficultyDialog,
            icon: const Icon(Icons.refresh),
            tooltip: '새 게임',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.deepOrange),
                  SizedBox(height: 16),
                  Text(
                    '퍼즐 생성 중...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: OrientationBuilder(
                builder: (context, orientation) {
                  if (orientation == Orientation.landscape) {
                    return _buildLandscapeLayout();
                  }
                  return _buildPortraitLayout();
                },
              ),
            ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        _buildStatusBar(),
        const SizedBox(height: 8),
        _buildHelpText(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Center(
              child: _isPaused
                  ? _buildPausedOverlay()
                  : NumberSumsBoard(
                      gameState: _gameState,
                      onCellTap: _onCellTap,
                      errorRow: _errorRow,
                      errorCol: _errorCol,
                    ),
            ),
          ),
        ),
        _buildToolBar(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // 왼쪽: 게임 보드
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Center(
              child: _isPaused
                  ? _buildPausedOverlay()
                  : NumberSumsBoard(
                      gameState: _gameState,
                      onCellTap: _onCellTap,
                      errorRow: _errorRow,
                      errorCol: _errorCol,
                    ),
            ),
          ),
        ),
        // 오른쪽: 정보 및 도구 모음
        Expanded(
          flex: 2,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF16213E),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLandscapeStatusBar(),
                  _buildHelpText(),
                  const SizedBox(height: 8),
                  _buildLandscapeToolBar(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeStatusBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined, size: 20, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                _formatTime(_elapsedSeconds),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _togglePause,
                icon: Icon(
                  _isPaused ? Icons.play_arrow : Icons.pause,
                  color: Colors.white,
                  size: 20,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Difficulty
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _getDifficultyLabel(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepOrange,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Failure count
              Row(
                children: [
                  Icon(Icons.close, size: 18, color: Colors.red.shade300),
                  const SizedBox(width: 4),
                  Text(
                    '$_failureCount',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade300,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeToolBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactModeButton(
            icon: Icons.check_circle_outline,
            label: '선택',
            isSelected: _gameMode == NumberSumsGameMode.select,
            onTap: () => _setGameMode(NumberSumsGameMode.select),
          ),
          const SizedBox(height: 6),
          _buildCompactModeButton(
            icon: Icons.remove_circle_outline,
            label: '제거',
            isSelected: _gameMode == NumberSumsGameMode.remove,
            onTap: () => _setGameMode(NumberSumsGameMode.remove),
          ),
          const SizedBox(height: 6),
          _buildCompactModeButton(
            icon: Icons.lightbulb_outline,
            label: '힌트',
            isSelected: _gameMode == NumberSumsGameMode.hint,
            onTap: () => _setGameMode(NumberSumsGameMode.hint),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepOrange.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: Colors.deepOrange, width: 2)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.deepOrange : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.deepOrange : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Timer
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 20, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                _formatTime(_elapsedSeconds),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          // Difficulty
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.deepOrange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getDifficultyLabel(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.deepOrange,
              ),
            ),
          ),
          // Failure count
          Row(
            children: [
              Icon(Icons.close, size: 20, color: Colors.red.shade300),
              const SizedBox(width: 4),
              Text(
                '$_failureCount',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade300,
                ),
              ),
            ],
          ),
          // Pause button
          IconButton(
            onPressed: _togglePause,
            icon: Icon(
              _isPaused ? Icons.play_arrow : Icons.pause,
              color: Colors.white,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpText() {
    final remainingWrong = _gameState.remainingWrongCount;
    String helpMessage;
    if (_gameMode == NumberSumsGameMode.select) {
      helpMessage = '올바른 숫자를 선택하세요! (남은 틀린 숫자: $remainingWrong)';
    } else if (_gameMode == NumberSumsGameMode.remove) {
      helpMessage = '틀린 숫자를 제거하세요! (남은 개수: $remainingWrong)';
    } else {
      helpMessage = '힌트: 셀을 선택하면 자동으로 처리됩니다 (남은 개수: $remainingWrong)';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        helpMessage,
        style: TextStyle(
          fontSize: 14,
          color: Colors.white.withValues(alpha: 0.7),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _getDifficultyLabel() {
    switch (_selectedDifficulty) {
      case NumberSumsDifficulty.easy:
        return '쉬움';
      case NumberSumsDifficulty.medium:
        return '보통';
      case NumberSumsDifficulty.hard:
        return '어려움';
    }
  }

  Widget _buildToolBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildModeButton(
            icon: Icons.check_circle_outline,
            label: '선택',
            isSelected: _gameMode == NumberSumsGameMode.select,
            onTap: () => _setGameMode(NumberSumsGameMode.select),
          ),
          _buildModeButton(
            icon: Icons.remove_circle_outline,
            label: '제거',
            isSelected: _gameMode == NumberSumsGameMode.remove,
            onTap: () => _setGameMode(NumberSumsGameMode.remove),
          ),
          _buildModeButton(
            icon: Icons.lightbulb_outline,
            label: '힌트',
            isSelected: _gameMode == NumberSumsGameMode.hint,
            onTap: () => _setGameMode(NumberSumsGameMode.hint),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepOrange.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Colors.deepOrange, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.deepOrange : Colors.white70,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.deepOrange : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPausedOverlay() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D2D2D),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pause_circle_outline,
                size: 64,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                '일시정지',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '재개 버튼을 눌러 계속하세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
