import 'dart:async';
import 'package:flutter/material.dart';
import '../models/samurai_game_state.dart';
import '../models/samurai_sudoku_generator.dart';
import '../widgets/game_control_panel.dart';
import '../widgets/game_status_bar.dart';

/// 확장 보드 화면에서 반환하는 빠른 입력 모드 상태
class ExpandedBoardResult {
  final bool isQuickInputMode;
  final int? quickInputNumber;
  final bool isNoteMode;

  ExpandedBoardResult({
    required this.isQuickInputMode,
    this.quickInputNumber,
    required this.isNoteMode,
  });
}

class ExpandedBoardScreen extends StatefulWidget {
  final SamuraiGameState gameState;
  final int boardIndex;
  final int? initialRow;
  final int? initialCol;
  final Function(int board, int row, int col, int value) onValueChanged;
  final Function(int board, int row, int col) onHint;
  final Function(int board, int row, int col, int number) onNoteToggle;
  final Function(int board) onFillAllNotes;
  final VoidCallback? onComplete;

  // 부모로부터 전달받는 게임 통계
  final int elapsedSeconds;
  final int failureCount;
  final bool isPaused;
  final VoidCallback onPauseToggle;
  final VoidCallback onFailure;
  final Function(int) onElapsedSecondsUpdate;

  // 빠른 입력 모드 상태 (보드 간 이동 시 유지)
  final bool initialQuickInputMode;
  final int? initialQuickInputNumber;
  final bool initialNoteMode;

  const ExpandedBoardScreen({
    super.key,
    required this.gameState,
    required this.boardIndex,
    this.initialRow,
    this.initialCol,
    required this.onValueChanged,
    required this.onHint,
    required this.onNoteToggle,
    required this.onFillAllNotes,
    this.onComplete,
    required this.elapsedSeconds,
    required this.failureCount,
    required this.isPaused,
    required this.onPauseToggle,
    required this.onFailure,
    required this.onElapsedSecondsUpdate,
    this.initialQuickInputMode = false,
    this.initialQuickInputNumber,
    this.initialNoteMode = false,
  });

  @override
  State<ExpandedBoardScreen> createState() => _ExpandedBoardScreenState();
}

class _ExpandedBoardScreenState extends State<ExpandedBoardScreen> {
  int? selectedRow;
  int? selectedCol;

  // 빠른 입력 모드 상태 (하이라이트용)
  bool _isQuickInputMode = false;
  int? _quickInputNumber;
  bool _isEraseMode = false;
  bool _isNoteMode = false;

  // 로컬 타이머 (부모의 시간을 업데이트하기 위함)
  Timer? _timer;
  late int _localElapsedSeconds;
  late int _localFailureCount;
  late bool _localIsPaused;

  @override
  void initState() {
    super.initState();
    selectedRow = widget.initialRow;
    selectedCol = widget.initialCol;
    _localElapsedSeconds = widget.elapsedSeconds;
    _localFailureCount = widget.failureCount;
    _localIsPaused = widget.isPaused;
    // 빠른 입력 모드 상태 초기화
    _isQuickInputMode = widget.initialQuickInputMode;
    _quickInputNumber = widget.initialQuickInputNumber;
    _isNoteMode = widget.initialNoteMode;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    // 화면 종료 시 부모에게 현재 시간 전달
    widget.onElapsedSecondsUpdate(_localElapsedSeconds);
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_localIsPaused) {
        setState(() {
          _localElapsedSeconds++;
        });
      }
    });
  }

  void _togglePause() {
    setState(() {
      _localIsPaused = !_localIsPaused;
    });
    // 부모에게도 상태 전달
    widget.onPauseToggle();
  }

  Widget _buildPausedOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        border: Border.all(color: Colors.black, width: 3),
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

  /// 현재 빠른 입력 모드 상태를 반환
  ExpandedBoardResult _getResult() {
    return ExpandedBoardResult(
      isQuickInputMode: _isQuickInputMode,
      quickInputNumber: _quickInputNumber,
      isNoteMode: _isNoteMode,
    );
  }

  /// 화면을 닫고 결과 반환
  void _popWithResult() {
    Navigator.pop(context, _getResult());
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.gameState.currentBoards[widget.boardIndex];
    final isFixed = widget.gameState.isFixed[widget.boardIndex];
    final notes = widget.gameState.notes[widget.boardIndex];
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _popWithResult();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('보드 ${widget.boardIndex + 1}'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          toolbarHeight: isLandscape ? 45 : kToolbarHeight,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _popWithResult,
          ),
        ),
        body: SafeArea(
          child: isLandscape
              ? _buildLandscapeLayout(board, isFixed, notes)
              : _buildPortraitLayout(board, isFixed, notes),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(
    List<List<int>> board,
    List<List<bool>> isFixed,
    List<List<Set<int>>> notes,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 게임 상태 표시 바
          GameStatusBar(
            elapsedSeconds: _localElapsedSeconds,
            failureCount: _localFailureCount,
            isPaused: _localIsPaused,
            onPauseToggle: _togglePause,
          ),
          const SizedBox(height: 12),
          // 9x9 보드 또는 일시정지 오버레이
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: _localIsPaused
                    ? _buildPausedOverlay()
                    : Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 3),
                        ),
                        child: _buildGrid(board, isFixed, notes),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 공통 게임 컨트롤 패널
          GameControlPanel(
            onNumberTap: _onNumberTap,
            onErase: _onErase,
            onUndo: _onUndo,
            canUndo: widget.gameState.canUndo,
            onHint: _onHint,
            onFillAllNotes: _onFillAllNotes,
            onQuickInputModeChanged: (isQuickInput, number) {
              setState(() {
                _isQuickInputMode = isQuickInput;
                _quickInputNumber = number;
                // 빠른 입력 모드에서 숫자 선택 시 셀 선택 초기화
                if (isQuickInput && number != null) {
                  selectedRow = null;
                  selectedCol = null;
                }
              });
            },
            onEraseModeChanged: (isErase) {
              setState(() {
                _isEraseMode = isErase;
              });
            },
            onNoteModeChanged: (isNote) {
              setState(() {
                _isNoteMode = isNote;
              });
            },
            disabledNumbers: widget.gameState.getCompletedNumbers(widget.boardIndex),
            isCompact: false,
            initialQuickInputMode: _isQuickInputMode,
            initialQuickInputNumber: _quickInputNumber,
            initialNoteMode: _isNoteMode,
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(
    List<List<int>> board,
    List<List<bool>> isFixed,
    List<List<Set<int>>> notes,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          // 9x9 보드 또는 일시정지 오버레이
          Expanded(
            flex: 1,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: _localIsPaused
                    ? _buildPausedOverlay()
                    : Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 3),
                        ),
                        child: _buildGrid(board, isFixed, notes),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 오른쪽: 상태 바 + 컨트롤 패널
          Expanded(
            flex: 1,
            child: Column(
              children: [
                // 게임 상태 표시 바 (컴팩트)
                GameStatusBar(
                  elapsedSeconds: _localElapsedSeconds,
                  failureCount: _localFailureCount,
                  isPaused: _localIsPaused,
                  onPauseToggle: _togglePause,
                  isCompact: true,
                ),
                const SizedBox(height: 8),
                // 공통 게임 컨트롤 패널
                Expanded(
                  child: GameControlPanel(
                    onNumberTap: _onNumberTap,
                    onErase: _onErase,
                    onUndo: _onUndo,
                    canUndo: widget.gameState.canUndo,
                    onHint: _onHint,
                    onFillAllNotes: _onFillAllNotes,
                    onQuickInputModeChanged: (isQuickInput, number) {
                      setState(() {
                        _isQuickInputMode = isQuickInput;
                        _quickInputNumber = number;
                        // 빠른 입력 모드에서 숫자 선택 시 셀 선택 초기화
                        if (isQuickInput && number != null) {
                          selectedRow = null;
                          selectedCol = null;
                        }
                      });
                    },
                    onEraseModeChanged: (isErase) {
                      setState(() {
                        _isEraseMode = isErase;
                      });
                    },
                    onNoteModeChanged: (isNote) {
                      setState(() {
                        _isNoteMode = isNote;
                      });
                    },
                    disabledNumbers: widget.gameState.getCompletedNumbers(widget.boardIndex),
                    isCompact: true,
                    initialQuickInputMode: _isQuickInputMode,
                    initialQuickInputNumber: _quickInputNumber,
                    initialNoteMode: _isNoteMode,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    List<List<int>> board,
    List<List<bool>> isFixed,
    List<List<Set<int>>> notes,
  ) {
    return Container(
      color: Colors.grey.shade800,
      child: Column(
        children: List.generate(9, (row) {
          return Expanded(
            child: Row(
              children: List.generate(9, (col) {
                double rightPadding = (col == 2 || col == 5) ? 2 : 1;
                double bottomPadding = (row == 2 || row == 5) ? 2 : 1;
                if (col == 8) rightPadding = 0;
                if (row == 8) bottomPadding = 0;

                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                      right: rightPadding,
                      bottom: bottomPadding,
                    ),
                    child: _buildCell(board, isFixed, notes, row, col),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCell(
    List<List<int>> board,
    List<List<bool>> isFixed,
    List<List<Set<int>>> notes,
    int row,
    int col,
  ) {
    int value = board[row][col];
    bool fixed = isFixed[row][col];
    Set<int> cellNotes = notes[row][col];
    bool isSelected = selectedRow == row && selectedCol == col;
    bool isSameRowOrCol = selectedRow != null &&
        selectedCol != null &&
        (selectedRow == row || selectedCol == col);
    bool isSameBox = _isSameBox(row, col);

    // 빠른 입력 모드에서 선택된 숫자와 같은 값을 가진 셀 하이라이트
    bool isQuickInputHighlight = _isQuickInputMode &&
        _quickInputNumber != null &&
        value != 0 &&
        value == _quickInputNumber;
    // 메모에 선택된 숫자가 포함된 셀 하이라이트 (빠른 입력 모드 또는 일반 모드)
    bool isNoteHighlight = _shouldHighlightNote(value, cellNotes);
    // 일반 모드에서는 선택된 셀과 같은 값 하이라이트
    bool isSameValue = !_isQuickInputMode &&
        selectedRow != null &&
        selectedCol != null &&
        value != 0 &&
        value == board[selectedRow!][selectedCol!];
    // 오류 체크 (일반 스도쿠와 동일)
    bool hasError = widget.gameState.hasError(widget.boardIndex, row, col);

    Color backgroundColor;
    if (isSelected) {
      backgroundColor = Colors.blue.shade300;
    } else if (isQuickInputHighlight) {
      // 숫자가 결정된 셀: 진한 파란색
      backgroundColor = Colors.blue.shade200;
    } else if (isNoteHighlight) {
      // 메모에 포함된 셀: 연한 녹색
      backgroundColor = Colors.green.shade100;
    } else if (isSameValue) {
      backgroundColor = Colors.blue.shade200;
    } else if (!_isQuickInputMode && (isSameRowOrCol || isSameBox)) {
      // 빠른 입력 모드에서는 행/열/박스 하이라이트 비활성화
      backgroundColor = Colors.blue.shade50;
    } else {
      backgroundColor = Colors.white;
    }

    // 텍스트 색상: 오류는 빨간색, 고정 셀은 검은색, 입력 셀은 파란색
    Color textColor;
    if (hasError) {
      textColor = Colors.red;
    } else if (fixed) {
      textColor = Colors.black;
    } else {
      textColor = Colors.blue.shade700;
    }

    return GestureDetector(
      onTap: () => _onCellTap(row, col, fixed),
      child: SizedBox.expand(
        child: Container(
          color: backgroundColor,
          child: value != 0
              ? Center(
                  child: Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: fixed ? FontWeight.bold : FontWeight.normal,
                      color: textColor,
                    ),
                  ),
                )
              : cellNotes.isNotEmpty
                  ? _buildNotesGrid(cellNotes)
                  : null,
        ),
      ),
    );
  }

  void _onCellTap(int row, int col, bool isFixed) {
    // 일시정지 상태에서는 입력 차단
    if (_localIsPaused) return;

    setState(() {
      // 지우기 모드일 때
      if (_isEraseMode) {
        if (!isFixed) {
          if (widget.gameState.currentBoards[widget.boardIndex][row][col] != 0) {
            // Undo 히스토리에 저장
            widget.gameState.saveToUndoHistory(widget.boardIndex, row, col);
            // 값이 있으면 값 지우기
            widget.onValueChanged(widget.boardIndex, row, col, 0);
          } else if (widget.gameState.notes[widget.boardIndex][row][col].isNotEmpty) {
            // Undo 히스토리에 저장
            widget.gameState.saveToUndoHistory(widget.boardIndex, row, col);
            // 값이 없으면 메모 지우기
            widget.gameState.clearNotes(widget.boardIndex, row, col);
          }
        }
        selectedRow = row;
        selectedCol = col;
      }
      // 빠른 입력 모드일 때
      else if (_isQuickInputMode && _quickInputNumber != null) {
        if (!isFixed) {
          // 빠른 입력 + 메모 모드: 메모로 입력
          if (_isNoteMode) {
            if (widget.gameState.currentBoards[widget.boardIndex][row][col] == 0) {
              // Undo 히스토리에 저장
              widget.gameState.saveToUndoHistory(widget.boardIndex, row, col);
              widget.onNoteToggle(widget.boardIndex, row, col, _quickInputNumber!);
            }
            selectedRow = row;
            selectedCol = col;
          } else {
            // 빠른 입력 모드만: 일반 숫자 입력 (일반 스도쿠와 동일하게 처리)
            int number = _quickInputNumber!;
            int correctValue = widget.gameState.solutions[widget.boardIndex][row][col];

            // 오답이면 실패 횟수 증가
            if (number != correctValue) {
              _localFailureCount++;
              widget.onFailure();
            }

            // 같은 숫자면 지우고, 다른 숫자면 입력 (무조건 입력)
            int currentValue = widget.gameState.currentBoards[widget.boardIndex][row][col];
            if (currentValue == number) {
              // Undo 히스토리에 저장 (지우기이므로 numberToInput 없음)
              widget.gameState.saveToUndoHistory(widget.boardIndex, row, col);
              widget.onValueChanged(widget.boardIndex, row, col, 0);
            } else {
              // Undo 히스토리에 저장 (숫자 입력이므로 numberToInput 전달)
              widget.gameState.saveToUndoHistory(widget.boardIndex, row, col, numberToInput: number);
              widget.onValueChanged(widget.boardIndex, row, col, number);
            }

            selectedRow = row;
            selectedCol = col;
            _checkCompletion();
          }
        } else {
          selectedRow = row;
          selectedCol = col;
        }
      } else {
        if (selectedRow == row && selectedCol == col) {
          selectedRow = null;
          selectedCol = null;
        } else {
          selectedRow = row;
          selectedCol = col;
        }
      }
    });
  }

  /// 현재 보드의 모든 셀이 채워졌는지 확인
  bool _isCurrentBoardFilled() {
    final board = widget.gameState.currentBoards[widget.boardIndex];
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (board[row][col] == 0) {
          return false;
        }
      }
    }
    return true;
  }

  void _checkCompletion() {
    // 현재 보드가 모두 채워졌는지 확인
    if (_isCurrentBoardFilled()) {
      // 전체 게임이 완료되었는지 확인 (solutions와 비교)
      bool isGameComplete = SamuraiSudokuGenerator.areAllBoardsComplete(
          widget.gameState.currentBoards, widget.gameState.solutions);

      // 사무라이 화면으로 돌아가기
      Navigator.pop(context, _getResult());

      // 전체 게임이 완료되었으면 완료 팝업 표시
      if (isGameComplete) {
        widget.onComplete?.call();
      }
    }
  }

  Widget _buildNotesGrid(Set<int> cellNotes) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 너비와 높이 중 작은 값을 사용하여 오버플로우 방지
        final size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final cellSize = size / 3;
        final fontSize = (cellSize * 0.55).clamp(6.0, 12.0);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (row) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (col) {
                int num = row * 3 + col + 1;
                bool hasNote = cellNotes.contains(num);
                return SizedBox(
                  width: cellSize,
                  height: cellSize,
                  child: Center(
                    child: Text(
                      hasNote ? num.toString() : '',
                      style: TextStyle(
                        fontSize: fontSize,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
        );
      },
    );
  }

  bool _isSameBox(int row, int col) {
    if (selectedRow == null || selectedCol == null) return false;
    int selectedBoxRow = (selectedRow! ~/ 3) * 3;
    int selectedBoxCol = (selectedCol! ~/ 3) * 3;
    int cellBoxRow = (row ~/ 3) * 3;
    int cellBoxCol = (col ~/ 3) * 3;
    return selectedBoxRow == cellBoxRow && selectedBoxCol == cellBoxCol;
  }

  /// 메모 하이라이트 여부 판단
  /// 빠른 입력 모드: quickInputNumber가 메모에 포함된 경우
  /// 일반 모드: 선택된 셀의 숫자가 메모에 포함된 경우
  bool _shouldHighlightNote(int cellValue, Set<int> cellNotes) {
    // 현재 셀에 값이 있으면 하이라이트 안함
    if (cellValue != 0) return false;

    // 메모가 없으면 하이라이트 안함
    if (cellNotes.isEmpty) return false;

    if (_isQuickInputMode) {
      // 빠른 입력 모드
      if (_quickInputNumber == null) return false;
      return cellNotes.contains(_quickInputNumber);
    } else {
      // 일반 모드: 선택된 셀의 숫자가 메모에 포함된 경우
      if (selectedRow == null || selectedCol == null) return false;
      int selectedValue = widget.gameState.currentBoards[widget.boardIndex]
          [selectedRow!][selectedCol!];
      if (selectedValue == 0) return false;
      return cellNotes.contains(selectedValue);
    }
  }

  void _onNumberTap(int number, bool isNoteMode) {
    // 일시정지 상태에서는 입력 차단
    if (_localIsPaused) return;

    if (selectedRow == null || selectedCol == null) return;
    if (widget.gameState.isFixed[widget.boardIndex][selectedRow!][selectedCol!]) {
      return;
    }

    if (isNoteMode) {
      // Undo 히스토리에 저장
      widget.gameState.saveToUndoHistory(widget.boardIndex, selectedRow!, selectedCol!);
      widget.onNoteToggle(widget.boardIndex, selectedRow!, selectedCol!, number);
    } else {
      // Undo 히스토리에 저장 (숫자 입력이므로 numberToInput 전달)
      widget.gameState.saveToUndoHistory(widget.boardIndex, selectedRow!, selectedCol!, numberToInput: number);

      // 일반 입력 모드 - 정답 확인 (일반 스도쿠와 동일하게 처리)
      int correctValue = widget.gameState.solutions[widget.boardIndex][selectedRow!][selectedCol!];
      if (number != correctValue) {
        setState(() {
          _localFailureCount++;
        });
        widget.onFailure();
      }

      // 무조건 값 입력
      widget.onValueChanged(widget.boardIndex, selectedRow!, selectedCol!, number);
      _checkCompletion();
    }
    setState(() {});
  }

  void _onErase() {
    // 일시정지 상태에서는 입력 차단
    if (_localIsPaused) return;

    if (selectedRow == null || selectedCol == null) return;
    if (widget.gameState.isFixed[widget.boardIndex][selectedRow!][selectedCol!]) {
      return;
    }

    // 값이나 메모가 있을 때만 Undo 히스토리에 저장
    if (widget.gameState.currentBoards[widget.boardIndex][selectedRow!][selectedCol!] != 0 ||
        widget.gameState.notes[widget.boardIndex][selectedRow!][selectedCol!].isNotEmpty) {
      widget.gameState.saveToUndoHistory(widget.boardIndex, selectedRow!, selectedCol!);
    }

    if (widget.gameState.currentBoards[widget.boardIndex][selectedRow!][selectedCol!] !=
        0) {
      widget.onValueChanged(widget.boardIndex, selectedRow!, selectedCol!, 0);
    } else {
      widget.gameState.clearNotes(widget.boardIndex, selectedRow!, selectedCol!);
    }
    setState(() {});
  }

  void _onFillAllNotes() {
    // 일시정지 상태에서는 입력 차단
    if (_localIsPaused) return;

    setState(() {
      widget.gameState.fillAllNotes(widget.boardIndex);
    });
  }

  void _onUndo() {
    // 일시정지 상태에서는 입력 차단
    if (_localIsPaused) return;

    setState(() {
      widget.gameState.undo();
    });
  }

  void _onHint() {
    // 일시정지 상태에서는 입력 차단
    if (_localIsPaused) return;

    if (selectedRow == null || selectedCol == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('셀을 먼저 선택하세요')),
      );
      return;
    }

    if (widget.gameState.isFixed[widget.boardIndex][selectedRow!][selectedCol!]) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 채워진 칸입니다')),
      );
      return;
    }

    widget.onHint(widget.boardIndex, selectedRow!, selectedCol!);
    _checkCompletion();
    setState(() {});
  }
}
