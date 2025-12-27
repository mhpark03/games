import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/samurai_game_state.dart';
import '../models/samurai_sudoku_generator.dart';
import '../services/game_storage.dart';
import '../widgets/samurai_board.dart';
import '../widgets/game_status_bar.dart';
import 'expanded_board_screen.dart';

class SamuraiGameScreen extends StatefulWidget {
  final SamuraiDifficulty? initialDifficulty;
  final SamuraiGameState? savedGameState;

  const SamuraiGameScreen({
    super.key,
    this.initialDifficulty,
    this.savedGameState,
  });

  @override
  State<SamuraiGameScreen> createState() => _SamuraiGameScreenState();
}

class _SamuraiGameScreenState extends State<SamuraiGameScreen>
    with WidgetsBindingObserver {
  late SamuraiGameState _gameState;
  late SamuraiDifficulty _selectedDifficulty;
  bool _isLoading = true;

  // 게임 타이머 및 통계
  Timer? _timer;
  int _elapsedSeconds = 0;
  int _failureCount = 0;
  bool _isPaused = false;
  bool _isBackgrounded = false; // 백그라운드 상태 (타이머만 멈춤, 화면 표시 안함)

  // 빠른 입력 모드 상태 (보드 간 이동 시 유지)
  bool _isQuickInputMode = false;
  int? _quickInputNumber;
  bool _isNoteMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.savedGameState != null) {
      // 저장된 게임 불러오기
      _gameState = widget.savedGameState!;
      _selectedDifficulty = _gameState.difficulty;
      // 저장된 게임 통계 복원
      _elapsedSeconds = _gameState.elapsedSeconds;
      _failureCount = _gameState.failureCount;
      _isLoading = false;
      _startTimer();
    } else {
      // 새 게임 시작
      _selectedDifficulty = widget.initialDifficulty ?? SamuraiDifficulty.medium;
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
    // 앱이 백그라운드로 갈 때 타이머만 멈춤 (일시정지 화면 표시 안함)
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!_isLoading && !_gameState.isCompleted) {
        setState(() {
          _isBackgrounded = true;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아오면 백그라운드 상태 해제
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
    // 새 게임 시작 시 모든 저장된 게임 삭제
    await GameStorage.deleteAllGames();

    setState(() {
      _isLoading = true;
    });

    // 별도 isolate에서 퍼즐 생성 (메인 스레드 블로킹 방지)
    final data = await compute(
      generateSamuraiPuzzleInIsolate,
      _selectedDifficulty,
    );

    if (mounted) {
      setState(() {
        _gameState = SamuraiGameState.fromGeneratedData(data);
        _isLoading = false;
        _elapsedSeconds = 0;
        _failureCount = 0;
        _isPaused = false;
      });
      _startTimer();
      _saveGame();
    }
  }

  /// 게임 상태 저장
  void _saveGame() {
    if (!_gameState.isCompleted) {
      // 현재 게임 통계를 게임 상태에 업데이트
      _gameState.elapsedSeconds = _elapsedSeconds;
      _gameState.failureCount = _failureCount;
      GameStorage.saveSamuraiGame(_gameState);
    } else {
      // 게임 완료 시 저장된 게임 삭제
      GameStorage.deleteSamuraiGame();
    }
  }

  void _onBoardSelect(int boardIndex) {
    setState(() {
      _gameState = _gameState.copyWith(
        selectedBoard: boardIndex,
        clearSelection: true,
      );
    });
  }

  void _onCellTap(int board, int row, int col) {
    // 셀 탭 시 확대 다이얼로그 표시
    _showExpandedBoard(board, row, col);
  }

  void _showExpandedBoard(int board, int? row, int? col) async {
    final result = await Navigator.push<ExpandedBoardResult>(
      context,
      MaterialPageRoute(
        builder: (context) => ExpandedBoardScreen(
          gameState: _gameState,
          boardIndex: board,
          initialRow: row,
          initialCol: col,
          elapsedSeconds: _elapsedSeconds,
          failureCount: _failureCount,
          isPaused: _isPaused,
          onPauseToggle: _togglePause,
          onFailure: () {
            setState(() {
              _failureCount++;
            });
          },
          onElapsedSecondsUpdate: (seconds) {
            _elapsedSeconds = seconds;
          },
          onValueChanged: (b, r, c, value) {
            _gameState.currentBoards[b][r][c] = value;
            _gameState.syncOverlapValue(b, r, c, value);
            // 값 입력 시 해당 셀의 메모 삭제 및 관련 셀의 메모에서 숫자 제거
            if (value != 0) {
              _gameState.clearNotes(b, r, c);
              _gameState.removeNumberFromAllRelatedNotes(b, r, c, value);
            }
          },
          onHint: (b, r, c) {
            int correctValue = _gameState.solutions[b][r][c];
            _gameState.currentBoards[b][r][c] = correctValue;
            _gameState.syncOverlapValue(b, r, c, correctValue);
            _gameState.clearNotes(b, r, c);
            _gameState.removeNumberFromAllRelatedNotes(b, r, c, correctValue);
          },
          onNoteToggle: (b, r, c, number) {
            _gameState.toggleNote(b, r, c, number);
          },
          onFillAllNotes: (b) {
            _gameState.fillAllNotes(b);
          },
          onComplete: () {
            _timer?.cancel();
            _gameState.isCompleted = true;
            _showCompletionDialog();
          },
          // 빠른 입력 모드 상태 전달
          initialQuickInputMode: _isQuickInputMode,
          initialQuickInputNumber: _quickInputNumber,
          initialNoteMode: _isNoteMode,
        ),
      ),
    );
    // ExpandedBoardScreen에서 돌아온 후 빠른 입력 모드 상태 저장
    if (result != null) {
      _isQuickInputMode = result.isQuickInputMode;
      _quickInputNumber = result.quickInputNumber;
      _isNoteMode = result.isNoteMode;
    }
    // 상태 갱신 및 저장
    setState(() {});
    _saveGame();
  }

  String _formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int secs = seconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showCompletionDialog() {
    // 완료된 게임 삭제
    GameStorage.deleteSamuraiGame();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('축하합니다! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('사무라이 스도쿠를 완성했습니다!'),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.timer, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Text('소요 시간: ${_formatTime(_elapsedSeconds)}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.close, size: 20, color: Colors.red),
                const SizedBox(width: 8),
                Text('실패 횟수: $_failureCount회'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 팝업 닫기
              Navigator.pop(context); // 홈 화면으로 이동
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showDifficultyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('난이도 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SamuraiDifficulty.values.map((difficulty) {
            String label;
            switch (difficulty) {
              case SamuraiDifficulty.easy:
                label = '쉬움';
                break;
              case SamuraiDifficulty.medium:
                label = '보통';
                break;
              case SamuraiDifficulty.hard:
                label = '어려움';
                break;
            }
            return ListTile(
              title: Text(label),
              leading: Icon(
                _selectedDifficulty == difficulty
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: Colors.blue,
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

  String _getDifficultyText() {
    switch (_selectedDifficulty) {
      case SamuraiDifficulty.easy:
        return '쉬움';
      case SamuraiDifficulty.medium:
        return '보통';
      case SamuraiDifficulty.hard:
        return '어려움';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text('사무라이 스도쿠'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        toolbarHeight: isLandscape ? 45 : kToolbarHeight,
        actions: [
          TextButton.icon(
            onPressed: _showDifficultyDialog,
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            label: const Text(
              '새 게임',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('퍼즐 생성 중...'),
                ],
              ),
            )
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.all(isLandscape ? 4.0 : 8.0),
                child: isLandscape
                    ? _buildLandscapeLayout()
                    : _buildPortraitLayout(),
              ),
            ),
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // 게임 상태 표시 바
        GameStatusBar(
          elapsedSeconds: _elapsedSeconds,
          failureCount: _failureCount,
          isPaused: _isPaused,
          onPauseToggle: _togglePause,
          difficultyText: _getDifficultyText(),
          themeColor: Colors.deepPurple,
        ),
        const SizedBox(height: 8),
        // 안내 텍스트
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '셀을 탭하면 편집 화면으로 이동합니다',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        // 사무라이 보드 또는 일시정지 오버레이
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: _isPaused
                  ? _buildPausedOverlay()
                  : SamuraiBoard(
                      gameState: _gameState,
                      onCellTap: _onCellTap,
                      onBoardSelect: _onBoardSelect,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPausedOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pause_circle_outline,
              size: 64,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              '일시정지',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '재개 버튼을 눌러 계속하세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // 사무라이 보드
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Text(
                '셀을 탭하면 편집 화면으로 이동합니다',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _isPaused
                        ? _buildPausedOverlay()
                        : SamuraiBoard(
                            gameState: _gameState,
                            onCellTap: _onCellTap,
                            onBoardSelect: _onBoardSelect,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // 상태 바
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GameStatusBar(
              elapsedSeconds: _elapsedSeconds,
              failureCount: _failureCount,
              isPaused: _isPaused,
              onPauseToggle: _togglePause,
              isCompact: true,
              difficultyText: _getDifficultyText(),
              themeColor: Colors.deepPurple,
            ),
          ],
        ),
      ],
    );
  }
}
