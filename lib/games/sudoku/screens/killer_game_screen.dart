import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/killer_game_state.dart';
import '../models/killer_sudoku_generator.dart';
import '../services/game_storage.dart';
import '../widgets/killer_sudoku_board.dart';
import '../widgets/game_control_panel.dart';
import '../widgets/game_status_bar.dart';

class KillerGameScreen extends StatefulWidget {
  final KillerDifficulty? initialDifficulty;
  final KillerGameState? savedGameState;

  const KillerGameScreen({
    super.key,
    this.initialDifficulty,
    this.savedGameState,
  });

  @override
  State<KillerGameScreen> createState() => _KillerGameScreenState();
}

class _KillerGameScreenState extends State<KillerGameScreen>
    with WidgetsBindingObserver {
  late KillerGameState _gameState;
  late KillerDifficulty _selectedDifficulty;
  bool _isLoading = true;
  final GlobalKey<GameControlPanelState> _controlPanelKey = GlobalKey();

  // 빠른 입력 모드 상태
  bool _isQuickInputMode = false;
  int? _quickInputNumber;
  bool _isEraseMode = false;

  // 게임 타이머 및 통계
  Timer? _timer;
  int _elapsedSeconds = 0;
  int _failureCount = 0;
  bool _isPaused = false;
  bool _isBackgrounded = false;

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
      _selectedDifficulty = widget.initialDifficulty ?? KillerDifficulty.medium;
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
      generateKillerPuzzleInIsolate,
      _selectedDifficulty,
    );

    if (mounted) {
      setState(() {
        _gameState = KillerGameState.fromGeneratedData(data);
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
      GameStorage.saveKillerGame(_gameState);
    } else {
      GameStorage.deleteKillerGame();
    }
  }

  void _onCellTap(int row, int col) {
    if (_isPaused) return;

    final controlState = _controlPanelKey.currentState;
    if (controlState == null) return;

    setState(() {
      // 지우기 모드
      if (controlState.isEraseMode) {
        if (!_gameState.isFixed[row][col]) {
          if (_gameState.currentBoard[row][col] != 0) {
            _gameState.saveToUndoHistory(row, col);
            List<List<int>> newBoard =
                _gameState.currentBoard.map((r) => List<int>.from(r)).toList();
            newBoard[row][col] = 0;
            _gameState = _gameState.copyWith(
              currentBoard: newBoard,
              selectedRow: row,
              selectedCol: col,
            );
          } else if (_gameState.notes[row][col].isNotEmpty) {
            _gameState.saveToUndoHistory(row, col);
            _gameState.clearNotes(row, col);
            _gameState = _gameState.copyWith(selectedRow: row, selectedCol: col);
          } else {
            _gameState = _gameState.copyWith(selectedRow: row, selectedCol: col);
          }
        } else {
          _gameState = _gameState.copyWith(selectedRow: row, selectedCol: col);
        }
      }
      // 빠른 입력 모드
      else if (controlState.isQuickInputMode &&
          controlState.quickInputNumber != null) {
        if (!_gameState.isFixed[row][col]) {
          if (controlState.isNoteMode) {
            int currentValue = _gameState.currentBoard[row][col];
            bool hasError = currentValue != 0 && _gameState.hasError(row, col);

            if (currentValue == 0 || hasError) {
              _gameState.saveToUndoHistory(row, col);

              // 오류가 있는 셀이면 값을 먼저 삭제
              if (hasError) {
                List<List<int>> newBoard =
                    _gameState.currentBoard.map((r) => List<int>.from(r)).toList();
                newBoard[row][col] = 0;
                _gameState = _gameState.copyWith(
                  currentBoard: newBoard,
                  selectedRow: row,
                  selectedCol: col,
                );
              }

              _gameState.toggleNote(row, col, controlState.quickInputNumber!);
              _gameState =
                  _gameState.copyWith(selectedRow: row, selectedCol: col);
            }
          } else {
            int number = controlState.quickInputNumber!;
            int correctValue = _gameState.solution[row][col];

            if (number != correctValue) {
              _failureCount++;
            }

            List<List<int>> newBoard =
                _gameState.currentBoard.map((r) => List<int>.from(r)).toList();

            if (newBoard[row][col] == controlState.quickInputNumber) {
              _gameState.saveToUndoHistory(row, col);
              newBoard[row][col] = 0;
            } else {
              _gameState.saveToUndoHistory(row, col, numberToInput: number);
              newBoard[row][col] = number;

              if (KillerSudokuGenerator.isValidMove(newBoard, row, col, number)) {
                _gameState.removeNumberFromRelatedNotes(row, col, number);
                _gameState.clearNotes(row, col);
              }
            }

            bool isComplete = KillerSudokuGenerator.isBoardComplete(newBoard);

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
          _gameState = _gameState.copyWith(selectedRow: row, selectedCol: col);
        }
      } else {
        // 일반 모드
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
    if (_isPaused) return;

    setState(() {
      if (!_gameState.hasSelection) return;

      int row = _gameState.selectedRow!;
      int col = _gameState.selectedCol!;

      if (_gameState.isFixed[row][col]) return;

      if (isNoteMode) {
        int currentValue = _gameState.currentBoard[row][col];
        bool hasError = currentValue != 0 && _gameState.hasError(row, col);

        if (currentValue == 0 || hasError) {
          _gameState.saveToUndoHistory(row, col);

          // 오류가 있는 셀이면 값을 먼저 삭제
          if (hasError) {
            List<List<int>> newBoard =
                _gameState.currentBoard.map((r) => List<int>.from(r)).toList();
            newBoard[row][col] = 0;
            _gameState = _gameState.copyWith(currentBoard: newBoard);
          }

          _gameState.toggleNote(row, col, number);
        }
        return;
      }

      _gameState.saveToUndoHistory(row, col, numberToInput: number);

      int correctValue = _gameState.solution[row][col];
      if (number != correctValue) {
        _failureCount++;
      }

      List<List<int>> newBoard =
          _gameState.currentBoard.map((r) => List<int>.from(r)).toList();
      newBoard[row][col] = number;

      if (KillerSudokuGenerator.isValidMove(newBoard, row, col, number)) {
        _gameState.removeNumberFromRelatedNotes(row, col, number);
        _gameState.clearNotes(row, col);
      }

      bool isComplete = KillerSudokuGenerator.isBoardComplete(newBoard);

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
    if (_isPaused) return;

    if (!_gameState.hasSelection) return;

    int row = _gameState.selectedRow!;
    int col = _gameState.selectedCol!;

    if (_gameState.isFixed[row][col]) return;

    if (_gameState.currentBoard[row][col] != 0 ||
        _gameState.notes[row][col].isNotEmpty) {
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
    if (_isPaused) return;

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

    int correctValue = _gameState.solution[row][col];

    setState(() {
      List<List<int>> newBoard =
          _gameState.currentBoard.map((r) => List<int>.from(r)).toList();
      newBoard[row][col] = correctValue;

      _gameState.removeNumberFromRelatedNotes(row, col, correctValue);
      _gameState.clearNotes(row, col);

      bool isComplete = KillerSudokuGenerator.isBoardComplete(newBoard);

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
    GameStorage.deleteKillerGame();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('축하합니다! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('킬러 스도쿠를 완성했습니다!'),
            const SizedBox(height: 16),
            Text('소요 시간: $timeStr'),
            Text('실패 횟수: $_failureCount회'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
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

  String _getDifficultyText() {
    switch (_selectedDifficulty) {
      case KillerDifficulty.easy:
        return '쉬움';
      case KillerDifficulty.medium:
        return '보통';
      case KillerDifficulty.hard:
        return '어려움';
    }
  }

  void _showDifficultyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('난이도 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: KillerDifficulty.values.map((difficulty) {
            String label;
            switch (difficulty) {
              case KillerDifficulty.easy:
                label = '쉬움';
                break;
              case KillerDifficulty.medium:
                label = '보통';
                break;
              case KillerDifficulty.hard:
                label = '어려움';
                break;
            }
            return ListTile(
              title: Text(label),
              leading: Icon(
                _selectedDifficulty == difficulty
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: Colors.teal,
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

  void _onUndo() {
    if (_isPaused) return;

    setState(() {
      _gameState.undo();
    });
    _saveGame();
  }

  void _onFillAllNotes() {
    if (_isPaused) return;

    setState(() {
      _gameState.fillAllNotes();
    });
  }

  Widget _buildControls({required bool isLandscape}) {
    return GameControlPanel(
      key: _controlPanelKey,
      onNumberTap: _onNumberTap,
      onErase: _onErase,
      onUndo: _onUndo,
      canUndo: _gameState.canUndo,
      onHint: _showHint,
      onFillAllNotes: _onFillAllNotes,
      onQuickInputModeChanged: (isQuickInput, number) {
        setState(() {
          _isQuickInputMode = isQuickInput;
          _quickInputNumber = number;
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

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text('킬러 스도쿠'),
        backgroundColor: Colors.teal,
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
                padding: EdgeInsets.all(isLandscape ? 8.0 : 16.0),
                child: isLandscape
                    ? Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                GameStatusBar(
                                  elapsedSeconds: _elapsedSeconds,
                                  failureCount: _failureCount,
                                  isPaused: _isPaused,
                                  onPauseToggle: _togglePause,
                                  isCompact: true,
                                  difficultyText: _getDifficultyText(),
                                  themeColor: Colors.teal,
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: _isPaused
                                          ? _buildPausedOverlay()
                                          : KillerSudokuBoard(
                                              gameState: _gameState,
                                              onCellTap: _onCellTap,
                                              isQuickInputMode:
                                                  _isQuickInputMode,
                                              quickInputNumber:
                                                  _quickInputNumber,
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: _buildControls(isLandscape: true),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          GameStatusBar(
                            elapsedSeconds: _elapsedSeconds,
                            failureCount: _failureCount,
                            isPaused: _isPaused,
                            onPauseToggle: _togglePause,
                            isCompact: false,
                            difficultyText: _getDifficultyText(),
                            themeColor: Colors.teal,
                          ),
                          const SizedBox(height: 12),
                          _isPaused
                              ? AspectRatio(
                                  aspectRatio: 1,
                                  child: _buildPausedOverlay(),
                                )
                              : KillerSudokuBoard(
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
}
