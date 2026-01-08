import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/killer_game_state.dart';
import '../models/killer_sudoku_generator.dart';
import '../services/game_storage.dart';
import '../widgets/killer_sudoku_board.dart';
import '../widgets/game_control_panel.dart';
import '../widgets/game_status_bar.dart';
import '../../../services/ad_service.dart';

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
              if (_failureCount >= 4) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showFailureAdDialog();
                });
              }
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
        if (_failureCount >= 4) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showFailureAdDialog();
          });
        }
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
        SnackBar(content: Text('games.sudoku.selectCell'.tr())),
      );
      return;
    }

    int row = _gameState.selectedRow!;
    int col = _gameState.selectedCol!;

    if (_gameState.isFixed[row][col]) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.alreadyFilled'.tr())),
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
        title: Text('dialog.hintTitle'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text(
          'common.hintWatchAdFull'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('app.cancel'.tr()),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showAdForHint(row, col);
            },
            icon: const Icon(Icons.play_circle_outline),
            label: Text('common.watchAd'.tr()),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.adLoadingFreeHint'.tr())),
      );
      _applyHint(row, col);
      return;
    }

    bool rewardEarned = false;
    adService.showRewardedAd(
      onUserEarnedReward: (ad, reward) {
        rewardEarned = true;
      },
      onAdDismissed: () {
        if (mounted && rewardEarned) {
          _applyHint(row, col);
        }
      },
      onAdNotAvailable: () {
        if (mounted) {
          _applyHint(row, col);
        }
      },
    );
  }

  void _applyHint(int row, int col) {
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
        title: Text('common.congratulations'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('games.sudoku.killerCompletedMessage'.tr()),
            const SizedBox(height: 16),
            Text('common.elapsedTime'.tr(namedArgs: {'time': timeStr})),
            Text('common.failureCount'.tr(namedArgs: {'count': '$_failureCount'})),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('app.confirm'.tr()),
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
        return 'common.easy'.tr();
      case KillerDifficulty.medium:
        return 'common.normal'.tr();
      case KillerDifficulty.hard:
        return 'common.hard'.tr();
    }
  }

  void _showDifficultyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('dialog.selectDifficulty'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: KillerDifficulty.values.map((difficulty) {
            String label;
            switch (difficulty) {
              case KillerDifficulty.easy:
                label = 'common.easy'.tr();
                break;
              case KillerDifficulty.medium:
                label = 'common.normal'.tr();
                break;
              case KillerDifficulty.hard:
                label = 'common.hard'.tr();
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

  // 오답 시 광고 다이얼로그 (4번째 오답부터)
  void _showFailureAdDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text('dialog.wrongAnswer'.tr(), style: const TextStyle(color: Colors.redAccent)),
        content: Text(
          '${'common.failureCount'.tr(namedArgs: {'count': '$_failureCount'})}\n${'dialog.adWatchContinue'.tr()}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('app.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final adService = AdService();
              bool rewardEarned = false;
              final result = await adService.showRewardedAd(
                onUserEarnedReward: (ad, reward) {
                  rewardEarned = true;
                },
                onAdDismissed: () {
                  if (mounted && rewardEarned) {
                    // 광고 시청 완료 후 틀린 항목 되돌리기
                    _onUndo();
                  }
                },
              );
              if (!result && mounted) {
                // 광고가 없는 경우에도 되돌리기 실행
                _onUndo();
                adService.loadRewardedAd();
              }
            },
            child: Text('common.watchAd'.tr()),
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
        title: Text('dialog.undoTitle'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text(
          'dialog.undoMessage'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('app.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final adService = AdService();
              bool rewardEarned = false;
              final result = await adService.showRewardedAd(
                onUserEarnedReward: (ad, reward) {
                  rewardEarned = true;
                },
                onAdDismissed: () {
                  if (mounted && rewardEarned) {
                    _onUndo();
                  }
                },
              );
              if (!result && mounted) {
                // 광고가 없는 경우 되돌리기 실행
                _onUndo();
                adService.loadRewardedAd();
              }
            },
            child: Text('common.watchAd'.tr()),
          ),
        ],
      ),
    );
  }

  void _onFillAllNotes() {
    if (_isPaused) return;

    // 광고 시청 확인 다이얼로그 표시
    _showFillNotesAdDialog();
  }

  void _showFillNotesAdDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text('dialog.fillNotesTitle'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text(
          'dialog.fillNotesMessage'.tr(),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('app.cancel'.tr()),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showAdForFillNotes();
            },
            icon: const Icon(Icons.play_circle_outline),
            label: Text('common.watchAd'.tr()),
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
        SnackBar(content: Text('common.adLoadingFreeHint'.tr())),
      );
      _applyFillAllNotes();
      return;
    }

    bool rewardEarned = false;
    adService.showRewardedAd(
      onUserEarnedReward: (ad, reward) {
        rewardEarned = true;
      },
      onAdDismissed: () {
        if (mounted && rewardEarned) {
          _applyFillAllNotes();
        }
      },
    );
  }

  void _applyFillAllNotes() {
    setState(() {
      _gameState.fillAllNotes();
    });
  }

  Widget _buildControls({required bool isLandscape, double? landscapeHeight}) {
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
      landscapeHeight: landscapeHeight,
    );
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
        title: Text('games.sudoku.killerName'.tr()),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _showRulesDialog,
            icon: const Icon(Icons.help_outline, color: Colors.white),
            tooltip: 'app.rules'.tr(),
          ),
          TextButton.icon(
            onPressed: _showDifficultyDialog,
            icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
            label: Text(
              'app.newGame'.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('common.generatingPuzzle'.tr()),
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

  // 가로 모드 레이아웃 (오목 스타일)
  Widget _buildLandscapeLayout(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.teal.shade900,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text('common.generatingPuzzle'.tr(), style: const TextStyle(color: Colors.white)),
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
              Colors.teal.shade700,
              Colors.teal.shade900,
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
                      padding: const EdgeInsets.fromLTRB(120, 8, 8, 8),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _isPaused
                              ? _buildPausedOverlay()
                              : KillerSudokuBoard(
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
                  Builder(
                    builder: (context) {
                      final screenHeight = MediaQuery.of(context).size.height;
                      return SizedBox(
                        width: 220,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 48), // 상단 버튼 공간 (겹침 방지)
                              // 컨트롤 패널
                              Expanded(
                                child: _buildControls(isLandscape: true, landscapeHeight: screenHeight),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
                          tooltip: 'common.back'.tr(),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'games.sudoku.killerName'.tr(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 상태 정보 (세로 배치)
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
                      tooltip: 'common.undo'.tr(),
                    ),
                    const SizedBox(width: 8),
                    _buildCircleButton(
                      icon: Icons.refresh,
                      onPressed: _showDifficultyDialog,
                      tooltip: 'app.newGame'.tr(),
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
              color: Colors.teal.withValues(alpha: 0.4),
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
              'common.pause'.tr(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'common.resumeMessage'.tr(),
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
        title: Text(
          'games.sudoku.rulesTitle'.tr(),
          style: const TextStyle(color: Colors.teal),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'games.sudoku.rulesObjective'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.sudoku.killerRulesObjectiveDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.sudoku.rulesBasic'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.sudoku.killerRulesBasicDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.sudoku.killerRulesCage'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.sudoku.killerRulesCageDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.sudoku.rulesTips'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.sudoku.killerRulesTipsDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('app.confirm'.tr()),
          ),
        ],
      ),
    );
  }
}
