import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_state.dart';
import '../models/sudoku_generator.dart';
import '../services/game_storage.dart';
import '../widgets/sudoku_board.dart';
import '../widgets/game_control_panel.dart';
import '../widgets/game_status_bar.dart';
import '../../../services/ad_service.dart';

class GameScreen extends StatefulWidget {
  final Difficulty? initialDifficulty;
  final GameState? savedGameState;

  const GameScreen({
    super.key,
    this.initialDifficulty,
    this.savedGameState,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late GameState _gameState;
  late Difficulty _selectedDifficulty;
  bool _isLoading = true;
  final GlobalKey<GameControlPanelState> _controlPanelKey = GlobalKey();

  // 빠른 입력 모드 상태 (하이라이트용)
  bool _isQuickInputMode = false;
  int? _quickInputNumber;
  bool _isEraseMode = false;

  // 게임 타이머 및 통계
  Timer? _timer;
  int _elapsedSeconds = 0;
  int _failureCount = 0;
  bool _isPaused = false;
  bool _isBackgrounded = false; // 백그라운드 상태 (타이머만 멈춤, 화면 표시 안함)

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
      _selectedDifficulty = widget.initialDifficulty ?? Difficulty.medium;
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
      generatePuzzleInIsolate,
      _selectedDifficulty,
    );

    if (mounted) {
      setState(() {
        _gameState = GameState.fromGeneratedData(data);
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
      GameStorage.saveRegularGame(_gameState);
    } else {
      // 게임 완료 시 저장된 게임 삭제
      GameStorage.deleteRegularGame();
    }
  }

  void _onCellTap(int row, int col) {
    if (_isPaused) return; // 일시정지 중에는 입력 불가

    final controlState = _controlPanelKey.currentState;
    if (controlState == null) return;

    setState(() {
      // 지우기 모드일 때
      if (controlState.isEraseMode) {
        if (!_gameState.isFixed[row][col]) {
          if (_gameState.currentBoard[row][col] != 0) {
            // Undo 히스토리에 저장
            _gameState.saveToUndoHistory(row, col);
            // 값이 있으면 값 지우기
            List<List<int>> newBoard =
                _gameState.currentBoard.map((r) => List<int>.from(r)).toList();
            newBoard[row][col] = 0;
            _gameState = _gameState.copyWith(
              currentBoard: newBoard,
              selectedRow: row,
              selectedCol: col,
            );
          } else if (_gameState.notes[row][col].isNotEmpty) {
            // Undo 히스토리에 저장
            _gameState.saveToUndoHistory(row, col);
            // 값이 없으면 메모 지우기
            _gameState.clearNotes(row, col);
            _gameState = _gameState.copyWith(selectedRow: row, selectedCol: col);
          } else {
            _gameState = _gameState.copyWith(selectedRow: row, selectedCol: col);
          }
        } else {
          _gameState = _gameState.copyWith(selectedRow: row, selectedCol: col);
        }
      }
      // 빠른 입력 모드일 때
      else if (controlState.isQuickInputMode && controlState.quickInputNumber != null) {
        // 고정 셀이 아니면 빠른 입력 숫자로 입력
        if (!_gameState.isFixed[row][col]) {
          // 빠른 입력 + 메모 모드: 메모로 입력
          if (controlState.isNoteMode) {
            if (_gameState.currentBoard[row][col] == 0) {
              // Undo 히스토리에 저장
              _gameState.saveToUndoHistory(row, col);
              _gameState.toggleNote(row, col, controlState.quickInputNumber!);
              _gameState = _gameState.copyWith(selectedRow: row, selectedCol: col);
            }
          } else {
            // 빠른 입력 모드만: 일반 숫자 입력
            int number = controlState.quickInputNumber!;
            int correctValue = _gameState.solution[row][col];

            // 정답 확인
            if (number != correctValue) {
              _failureCount++;
              if (_failureCount >= 4) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showFailureAdDialog();
                });
              }
            }

            List<List<int>> newBoard =
                _gameState.currentBoard.map((r) => List<int>.from(r)).toList();

            // 같은 숫자면 지우고, 다른 숫자면 입력
            if (newBoard[row][col] == controlState.quickInputNumber) {
              // Undo 히스토리에 저장 (지우기이므로 numberToInput 없음)
              _gameState.saveToUndoHistory(row, col);
              newBoard[row][col] = 0;
            } else {
              // Undo 히스토리에 저장 (숫자 입력이므로 numberToInput 전달)
              _gameState.saveToUndoHistory(row, col, numberToInput: number);
              newBoard[row][col] = number;

              // 유효한 입력이면 같은 행/열/박스의 메모에서 해당 숫자 삭제
              if (SudokuGenerator.isValidMove(newBoard, row, col, number)) {
                _gameState.removeNumberFromRelatedNotes(row, col, number);
                _gameState.clearNotes(row, col);
              }
            }

            bool isComplete = SudokuGenerator.isBoardComplete(newBoard, _gameState.solution);

            _gameState = _gameState.copyWith(
              currentBoard: newBoard,
              selectedRow: row,
              selectedCol: col,
              isCompleted: isComplete,
            );

            if (isComplete) {
              _timer?.cancel();
              _showCompletionDialog();
            }
          }
        } else {
          // 고정 셀을 탭하면 선택만
          _gameState = _gameState.copyWith(selectedRow: row, selectedCol: col);
        }
      } else {
        // 일반 모드: 기존 로직
        if (_gameState.selectedRow == row && _gameState.selectedCol == col) {
          _gameState = _gameState.copyWith(clearSelection: true);
        } else {
          _gameState = _gameState.copyWith(selectedRow: row, selectedCol: col);
        }
      }
    });
    _saveGame();
  }

  void _onNumberTap(int number, bool isNoteMode) {
    if (_isPaused) return; // 일시정지 중에는 입력 불가

    setState(() {
      // 일반 모드: 기존 로직
      if (!_gameState.hasSelection) return;

      int row = _gameState.selectedRow!;
      int col = _gameState.selectedCol!;

      if (_gameState.isFixed[row][col]) return;

      // 메모 모드일 때
      if (isNoteMode) {
        if (_gameState.currentBoard[row][col] == 0) {
          // Undo 히스토리에 저장
          _gameState.saveToUndoHistory(row, col);
          _gameState.toggleNote(row, col, number);
        }
        return;
      }

      // Undo 히스토리에 저장 (숫자 입력이므로 numberToInput 전달)
      _gameState.saveToUndoHistory(row, col, numberToInput: number);

      // 일반 입력 모드 - 정답 확인
      int correctValue = _gameState.solution[row][col];
      if (number != correctValue) {
        _failureCount++;
        if (_failureCount >= 4) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showFailureAdDialog();
          });
        }
      }

      List<List<int>> newBoard =
          _gameState.currentBoard.map((r) => List<int>.from(r)).toList();
      newBoard[row][col] = number;

      // 유효한 입력이면 같은 행/열/박스의 메모에서 해당 숫자 삭제
      if (SudokuGenerator.isValidMove(newBoard, row, col, number)) {
        _gameState.removeNumberFromRelatedNotes(row, col, number);
        _gameState.clearNotes(row, col);
      }

      bool isComplete = SudokuGenerator.isBoardComplete(newBoard, _gameState.solution);

      _gameState = _gameState.copyWith(
        currentBoard: newBoard,
        isCompleted: isComplete,
      );

      if (isComplete) {
        _timer?.cancel();
        _showCompletionDialog();
      }
    });
    _saveGame();
  }

  void _onErase() {
    if (_isPaused) return; // 일시정지 중에는 입력 불가

    if (!_gameState.hasSelection) return;

    int row = _gameState.selectedRow!;
    int col = _gameState.selectedCol!;

    if (_gameState.isFixed[row][col]) return;

    // 값이나 메모가 있을 때만 Undo 히스토리에 저장
    if (_gameState.currentBoard[row][col] != 0 || _gameState.notes[row][col].isNotEmpty) {
      _gameState.saveToUndoHistory(row, col);
    }

    setState(() {
      List<List<int>> newBoard =
          _gameState.currentBoard.map((r) => List<int>.from(r)).toList();
      newBoard[row][col] = 0;

      _gameState = _gameState.copyWith(currentBoard: newBoard);
    });
    _saveGame();
  }

  void _showHint() {
    if (_isPaused) return; // 일시정지 중에는 입력 불가

    if (!_gameState.hasSelection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('셀을 먼저 선택하세요')),
      );
      return;
    }

    int row = _gameState.selectedRow!;
    int col = _gameState.selectedCol!;

    if (_gameState.isFixed[row][col]) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 채워진 칸입니다')),
      );
      return;
    }

    // 광고 시청 확인 다이얼로그 표시
    _showAdConfirmDialog(row, col);
  }

  void _showAdConfirmDialog(int row, int col) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('힌트 사용', style: TextStyle(color: Colors.white)),
        content: const Text(
          '광고를 시청하고 힌트를 받으시겠습니까?\n\n※ 광고는 끝까지 시청해야 합니다.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showAdForHint(row, col);
            },
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('광고 보기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
            ),
          ),
        ],
      ),
    );
  }

  void _showAdForHint(int row, int col) {
    final adService = AdService();

    if (!adService.isAdLoaded) {
      // 광고가 로드되지 않은 경우 바로 힌트 제공
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('광고를 불러오는 중입니다. 힌트를 무료로 제공합니다.')),
      );
      _applyHint(row, col);
      return;
    }

    adService.showRewardedAd(
      onUserEarnedReward: (ad, reward) {
        _applyHint(row, col);
      },
      onAdDismissed: () {
        // 광고가 닫힌 후 처리 (필요시)
      },
    );
  }

  void _applyHint(int row, int col) {
    int correctValue = _gameState.solution[row][col];

    setState(() {
      List<List<int>> newBoard =
          _gameState.currentBoard.map((r) => List<int>.from(r)).toList();
      newBoard[row][col] = correctValue;

      // 같은 행/열/박스의 메모에서 해당 숫자 삭제
      _gameState.removeNumberFromRelatedNotes(row, col, correctValue);
      _gameState.clearNotes(row, col);

      bool isComplete = SudokuGenerator.isBoardComplete(newBoard, _gameState.solution);

      _gameState = _gameState.copyWith(
        currentBoard: newBoard,
        isCompleted: isComplete,
      );

      if (isComplete) {
        _timer?.cancel();
        _showCompletionDialog();
      }
    });
    _saveGame();
  }

  void _showCompletionDialog() {
    String timeStr = _formatTime(_elapsedSeconds);
    // 완료된 게임 삭제
    GameStorage.deleteRegularGame();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('축하합니다! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('스도쿠를 완성했습니다!'),
            const SizedBox(height: 16),
            Text('소요 시간: $timeStr'),
            Text('실패 횟수: $_failureCount회'),
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
        title: const Text('난이도 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: Difficulty.values.map((difficulty) {
            String label;
            switch (difficulty) {
              case Difficulty.easy:
                label = '쉬움';
                break;
              case Difficulty.medium:
                label = '보통';
                break;
              case Difficulty.hard:
                label = '어려움';
                break;
              case Difficulty.expert:
                label = '달인';
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
      case Difficulty.easy:
        return '쉬움';
      case Difficulty.medium:
        return '보통';
      case Difficulty.hard:
        return '어려움';
      case Difficulty.expert:
        return '달인';
    }
  }

  Widget _buildControls({required bool isLandscape}) {
    return GameControlPanel(
      key: _controlPanelKey,
      onNumberTap: _onNumberTap,
      onErase: _onErase,
      onUndo: _showUndoAdDialog,
      canUndo: _gameState.canUndo,
      onHint: _showHint,
      onFillAllNotes: _onFillAllNotes,
      onQuickInputModeChanged: (isQuickInput, number) {
        setState(() {
          _isQuickInputMode = isQuickInput;
          _quickInputNumber = number;
          // 빠른 입력 모드에서 숫자 선택 시 셀 선택 초기화
          if (isQuickInput && number != null) {
            _gameState = _gameState.copyWith(clearSelection: true);
          }
        });
      },
      onEraseModeChanged: (isErase) {
        setState(() {
          _isEraseMode = isErase;
        });
      },
      disabledNumbers: _gameState.getCompletedNumbers(),
      isCompact: isLandscape,
    );
  }

  void _onUndo() {
    if (_isPaused) return;

    setState(() {
      _gameState.undo();
    });
    _saveGame();
  }

  // 오답 시 광고 다이얼로그 (4번째 오답부터)
  void _showFailureAdDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('오답입니다', style: TextStyle(color: Colors.redAccent)),
        content: Text(
          '실패 횟수: $_failureCount회\n광고를 시청하고 계속 진행하시겠습니까?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final adService = AdService();
              final result = await adService.showRewardedAd(
                onUserEarnedReward: (ad, reward) {
                  // 광고 시청 완료
                },
              );
              if (!result) {
                adService.loadRewardedAd();
              }
            },
            child: const Text('광고 보기'),
          ),
        ],
      ),
    );
  }

  // 취소 버튼 광고 다이얼로그
  void _showUndoAdDialog() {
    if (_isPaused || !_gameState.canUndo) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('되돌리기', style: TextStyle(color: Colors.white)),
        content: const Text(
          '광고를 시청하고 되돌리기를 사용하시겠습니까?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final adService = AdService();
              final result = await adService.showRewardedAd(
                onUserEarnedReward: (ad, reward) {
                  _onUndo();
                },
              );
              if (!result && mounted) {
                // 광고가 없어도 기능 실행
                _onUndo();
                adService.loadRewardedAd();
              }
            },
            child: const Text('광고 보기'),
          ),
        ],
      ),
    );
  }

  void _onFillAllNotes() {
    if (_isPaused) return; // 일시정지 중에는 입력 불가

    // 광고 시청 확인 다이얼로그 표시
    _showFillNotesAdDialog();
  }

  void _showFillNotesAdDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('모든 메모 채우기', style: TextStyle(color: Colors.white)),
        content: const Text(
          '광고를 시청하고 모든 메모를 채우시겠습니까?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showAdForFillNotes();
            },
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('광고 보기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
            ),
          ),
        ],
      ),
    );
  }

  void _showAdForFillNotes() {
    final adService = AdService();

    if (!adService.isAdLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('광고를 불러오는 중입니다. 무료로 제공합니다.')),
      );
      _applyFillAllNotes();
      return;
    }

    adService.showRewardedAd(
      onUserEarnedReward: (ad, reward) {
        _applyFillAllNotes();
      },
      onAdDismissed: () {},
    );
  }

  void _applyFillAllNotes() {
    setState(() {
      _gameState.fillAllNotes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return _buildLandscapeLayout(context);
        } else {
          return _buildPortraitLayout(context);
        }
      },
    );
  }

  // 세로 모드 레이아웃
  Widget _buildPortraitLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스도쿠'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showRulesDialog,
            icon: const Icon(Icons.help_outline, color: Colors.white),
            tooltip: '게임 규칙',
          ),
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    GameStatusBar(
                      elapsedSeconds: _elapsedSeconds,
                      failureCount: _failureCount,
                      isPaused: _isPaused,
                      onPauseToggle: _togglePause,
                      isCompact: false,
                      difficultyText: _getDifficultyText(),
                      themeColor: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _isPaused
                        ? AspectRatio(
                            aspectRatio: 1,
                            child: _buildPausedOverlay(),
                          )
                        : SudokuBoard(
                            gameState: _gameState,
                            onCellTap: _onCellTap,
                            isQuickInputMode: _isQuickInputMode,
                            quickInputNumber: _quickInputNumber,
                          ),
                    const SizedBox(height: 20),
                    _buildControls(isLandscape: false),
                  ],
                ),
              ),
            ),
    );
  }

  // 가로 모드 레이아웃 (오목 스타일)
  Widget _buildLandscapeLayout(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.blue.shade900,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('퍼즐 생성 중...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade800,
              Colors.blue.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 메인 영역: 보드 + 컨트롤
              Row(
                children: [
                  // 왼쪽: 게임 보드 (최대 크기)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(100, 8, 8, 8),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _isPaused
                              ? _buildPausedOverlay()
                              : SudokuBoard(
                                  gameState: _gameState,
                                  onCellTap: _onCellTap,
                                  isQuickInputMode: _isQuickInputMode,
                                  quickInputNumber: _quickInputNumber,
                                ),
                        ),
                      ),
                    ),
                  ),
                  // 오른쪽: 컨트롤 패널만 (상태 정보 제거)
                  SizedBox(
                    width: 220,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 44), // 상단 버튼 공간
                          // 컨트롤 패널
                          Expanded(
                            child: _buildControls(isLandscape: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // 왼쪽 상단: 뒤로가기 + 제목 + 상태 정보
              Positioned(
                top: 4,
                left: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildCircleButton(
                          icon: Icons.arrow_back,
                          onPressed: () => Navigator.pop(context),
                          tooltip: '뒤로가기',
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '스도쿠',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 상태 정보 (가로 배치)
                    _buildLeftStatusInfo(),
                  ],
                ),
              ),
              // 오른쪽 상단: 취소 + 새 게임 버튼
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  children: [
                    _buildCircleButton(
                      icon: Icons.undo,
                      onPressed: _gameState.canUndo ? _showUndoAdDialog : null,
                      tooltip: '취소',
                    ),
                    const SizedBox(width: 8),
                    _buildCircleButton(
                      icon: Icons.refresh,
                      onPressed: _showDifficultyDialog,
                      tooltip: '새 게임',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 원형 버튼 위젯
  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    final isEnabled = onPressed != null;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.3,
      child: Material(
        color: Colors.black.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Tooltip(
            message: tooltip,
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Icon(
                icon,
                color: Colors.white70,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 왼쪽 상태 정보 (세로 배치)
  Widget _buildLeftStatusInfo() {
    return Container(
      margin: const EdgeInsets.only(left: 8, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 난이도
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getDifficultyText(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // 시간 + 일시정지 버튼
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                _formatTime(_elapsedSeconds),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _togglePause,
                child: Icon(
                  _isPaused ? Icons.play_arrow : Icons.pause,
                  size: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 실패 횟수
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.close, size: 14, color: Colors.red.shade300),
              const SizedBox(width: 2),
              Text(
                '$_failureCount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPausedOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade400, width: 2),
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
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '재개 버튼을 눌러 계속하세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
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
          '스도쿠 게임 규칙',
          style: TextStyle(color: Colors.blue),
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
                '9x9 격자의 모든 빈 칸을 1~9 숫자로 채우세요!',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '📏 기본 규칙',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• 각 가로줄에 1~9가 한 번씩만\n'
                '• 각 세로줄에 1~9가 한 번씩만\n'
                '• 각 3x3 박스에 1~9가 한 번씩만',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '🎮 조작 방법',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• 빈 칸을 탭 → 숫자 패드로 입력\n'
                '• 빠른 입력: 숫자 먼저 선택 → 셀 탭\n'
                '• 메모: 후보 숫자를 작게 기록\n'
                '• 빠른+메모: 셀 탭으로 메모 입력',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '💡 팁',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '• 확실한 숫자부터 채우세요\n'
                '• 모든 메모로 후보 자동 채우기\n'
                '• 실패 횟수가 기록됩니다',
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
