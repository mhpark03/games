import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/samurai_game_state.dart';
import '../models/samurai_sudoku_generator.dart';
import '../widgets/game_control_panel.dart';
import '../widgets/game_status_bar.dart';
import '../../../services/ad_service.dart';

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

  // 마지막으로 설정한 방향 (SystemChrome 중복 호출 방지)
  Orientation? _lastOrientation;

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
    // 상태바는 부모 화면에서 관리하므로 여기서 복원하지 않음
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
              'common.pause'.tr(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'common.resumeMessage'.tr(),
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

    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return _buildLandscapeLayout(context, board, isFixed, notes);
        } else {
          return _buildPortraitLayout(context, board, isFixed, notes);
        }
      },
    );
  }

  // 세로 모드 레이아웃
  Widget _buildPortraitLayout(
    BuildContext context,
    List<List<int>> board,
    List<List<bool>> isFixed,
    List<List<Set<int>>> notes,
  ) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _popWithResult();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('games.sudoku.boardNum'.tr(namedArgs: {'num': '${widget.boardIndex + 1}'})),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _popWithResult,
          ),
        ),
        body: SafeArea(
          child: Padding(
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
                _buildControlPanel(isCompact: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 가로 모드 레이아웃 (오목 스타일)
  Widget _buildLandscapeLayout(
    BuildContext context,
    List<List<int>> board,
    List<List<bool>> isFixed,
    List<List<Set<int>>> notes,
  ) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _popWithResult();
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.deepPurple.shade700,
                Colors.deepPurple.shade900,
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
                    ),
                    // 오른쪽: 컨트롤 패널만 (상태 정보 제거)
                    Builder(
                      builder: (context) {
                        final screenHeight = MediaQuery.of(context).size.height;
                        // 화면 높이에 따른 동적 패널 너비 계산
                        final heightFactor = ((screenHeight - 300) / 600).clamp(0.0, 1.5);
                        final panelWidth = 220.0 + (heightFactor * 80.0); // 220~340
                        return SizedBox(
                          width: panelWidth,
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
                                  child: _buildControlPanel(isCompact: true, landscapeHeight: screenHeight),
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
                            onPressed: _popWithResult,
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
                              'games.sudoku.boardNum'.tr(namedArgs: {'num': '${widget.boardIndex + 1}'}),
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
                // 오른쪽 상단: 취소 버튼
                Positioned(
                  top: 4,
                  right: 4,
                  child: _buildCircleButton(
                    icon: Icons.undo,
                    onPressed: widget.gameState.canUndo ? _showUndoAdDialog : null,
                    tooltip: 'dialog.undoTitle'.tr(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 원형 버튼 위젯 (가로 모드용)
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
          // 시간 + 일시정지 버튼
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                _formatTime(_localElapsedSeconds),
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
                  _localIsPaused ? Icons.play_arrow : Icons.pause,
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
                '$_localFailureCount',
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

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  // 공통 컨트롤 패널
  Widget _buildControlPanel({required bool isCompact, double? landscapeHeight}) {
    return GameControlPanel(
      onNumberTap: _onNumberTap,
      onErase: _onErase,
      onUndo: _showUndoAdDialog,
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
      isCompact: isCompact,
      initialQuickInputMode: _isQuickInputMode,
      initialQuickInputNumber: _quickInputNumber,
      initialNoteMode: _isNoteMode,
      landscapeHeight: landscapeHeight,
    );
  }

  Widget _buildGrid(
    List<List<int>> board,
    List<List<bool>> isFixed,
    List<List<Set<int>>> notes,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = constraints.maxWidth / 9;
        final boxGap = (cellSize * 0.03).clamp(1.5, 3.0);
        final cellGap = (cellSize * 0.015).clamp(0.5, 1.5);

        return Container(
          color: Colors.grey.shade800,
          child: Column(
            children: List.generate(9, (row) {
              return Expanded(
                child: Row(
                  children: List.generate(9, (col) {
                    double rightPadding = (col == 2 || col == 5) ? boxGap : cellGap;
                    double bottomPadding = (row == 2 || row == 5) ? boxGap : cellGap;
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
      },
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cellSize = constraints.maxWidth < constraints.maxHeight
                  ? constraints.maxWidth
                  : constraints.maxHeight;

              if (value != 0) {
                final valueFontSize = (cellSize * 0.55).clamp(14.0, 40.0);
                return Center(
                  child: Text(
                    value.toString(),
                    style: TextStyle(
                      fontSize: valueFontSize,
                      fontWeight: fixed ? FontWeight.bold : FontWeight.normal,
                      color: textColor,
                    ),
                  ),
                );
              } else if (cellNotes.isNotEmpty) {
                return _buildNotesGrid(cellNotes, cellSize);
              } else {
                return const SizedBox.shrink();
              }
            },
          ),
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
              if (_localFailureCount >= 4) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showFailureAdDialog();
                });
              }
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

      // 추가 안전 검사: 모든 보드에 오류가 없는지 확인
      if (isGameComplete && _hasAnyError()) {
        isGameComplete = false;
      }

      // 사무라이 화면으로 돌아가기
      Navigator.pop(context, _getResult());

      // 전체 게임이 완료되었으면 완료 팝업 표시
      if (isGameComplete) {
        widget.onComplete?.call();
      }
    }
  }

  /// 모든 보드에 오류가 있는 셀이 있는지 확인
  bool _hasAnyError() {
    for (int b = 0; b < 5; b++) {
      for (int row = 0; row < 9; row++) {
        for (int col = 0; col < 9; col++) {
          if (widget.gameState.hasError(b, row, col)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  Widget _buildNotesGrid(Set<int> cellNotes, double cellSize) {
    final fontSize = (cellSize / 3 * 0.55).clamp(6.0, 18.0);

    return Column(
      children: List.generate(3, (row) {
        return Expanded(
          child: Row(
            children: List.generate(3, (col) {
              int num = row * 3 + col + 1;
              bool hasNote = cellNotes.contains(num);
              return Expanded(
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
          ),
        );
      }),
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
        if (_localFailureCount >= 4) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showFailureAdDialog();
          });
        }
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

    // 쿨다운 기간 내이면 광고 없이 바로 적용
    final adService = AdService();
    if (adService.isInRewardCooldown) {
      _applyFillAllNotes();
      return;
    }

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
      onAdNotAvailable: () {
        if (mounted) {
          _applyFillAllNotes();
        }
      },
    );
  }

  void _applyFillAllNotes() {
    setState(() {
      widget.gameState.fillAllNotes(widget.boardIndex);
    });
  }

  void _onUndo() {
    // 일시정지 상태에서는 입력 차단
    if (_localIsPaused) return;
    // Undo 히스토리가 비어있으면 무시
    if (!widget.gameState.canUndo) {
      debugPrint('Undo 불가: 히스토리 비어있음');
      return;
    }

    final undoSuccess = widget.gameState.undo();
    debugPrint('Undo 실행 결과: $undoSuccess');
    if (undoSuccess) {
      setState(() {});
    }
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
          '${'common.failureCount'.tr(namedArgs: {'count': '$_localFailureCount'})}\n${'dialog.adWatchContinue'.tr()}',
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
    if (_localIsPaused || !widget.gameState.canUndo) {
      debugPrint('Undo 다이얼로그 표시 불가: paused=$_localIsPaused, canUndo=${widget.gameState.canUndo}');
      return;
    }

    debugPrint('Undo 다이얼로그 표시, undoCount=${widget.gameState.undoCount}');
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
              debugPrint('광고 시청 시작');
              final result = await adService.showRewardedAd(
                onUserEarnedReward: (ad, reward) {
                  rewardEarned = true;
                  debugPrint('광고 보상 획득');
                },
                onAdDismissed: () {
                  debugPrint('광고 닫힘: mounted=$mounted, rewardEarned=$rewardEarned');
                  if (mounted && rewardEarned) {
                    _onUndo();
                  }
                },
              );
              debugPrint('showRewardedAd 반환: result=$result');
              if (!result && mounted) {
                // 광고가 없는 경우 되돌리기 실행
                debugPrint('광고 없음 - 무료 Undo');
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

  void _onHint() {
    // 일시정지 상태에서는 입력 차단
    if (_localIsPaused) return;

    if (selectedRow == null || selectedCol == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('games.sudoku.selectCell'.tr())),
      );
      return;
    }

    if (widget.gameState.isFixed[widget.boardIndex][selectedRow!][selectedCol!]) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.alreadyFilled'.tr())),
      );
      return;
    }

    // 광고 시청 확인 다이얼로그 표시
    _showAdConfirmDialog(selectedRow!, selectedCol!);
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
    widget.onHint(widget.boardIndex, row, col);
    _checkCompletion();
    setState(() {});
  }
}
