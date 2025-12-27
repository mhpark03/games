import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/samurai_game_state.dart';
import '../models/samurai_sudoku_generator.dart';

class ExpandedBoardDialog extends StatefulWidget {
  final SamuraiGameState gameState;
  final int boardIndex;
  final int? initialRow;
  final int? initialCol;
  final Function(int board, int row, int col, int value) onValueChanged;
  final Function(int board, int row, int col) onHint;
  final Function(int board, int row, int col, int number) onNoteToggle;
  final Function(int board) onFillAllNotes;

  const ExpandedBoardDialog({
    super.key,
    required this.gameState,
    required this.boardIndex,
    this.initialRow,
    this.initialCol,
    required this.onValueChanged,
    required this.onHint,
    required this.onNoteToggle,
    required this.onFillAllNotes,
  });

  @override
  State<ExpandedBoardDialog> createState() => _ExpandedBoardDialogState();
}

class _ExpandedBoardDialogState extends State<ExpandedBoardDialog> {
  int? selectedRow;
  int? selectedCol;
  bool isNoteMode = false; // 메모 모드
  bool isQuickInputMode = false; // 빠른 입력 모드
  int? quickInputNumber; // 빠른 입력에서 선택된 숫자

  @override
  void initState() {
    super.initState();
    selectedRow = widget.initialRow;
    selectedCol = widget.initialCol;
  }

  @override
  void didUpdateWidget(ExpandedBoardDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 빠른 입력 모드에서 선택된 숫자가 비활성화되면 다음 활성화된 숫자 자동 선택
    if (isQuickInputMode && quickInputNumber != null) {
      final completedNumbers = widget.gameState.getCompletedNumbers(widget.boardIndex);
      if (completedNumbers.contains(quickInputNumber)) {
        // 다음 활성화된 숫자 찾기
        int? nextNumber = _findNextActiveNumber(quickInputNumber!, completedNumbers);
        if (nextNumber != quickInputNumber) {
          // 빌드 완료 후 setState 호출
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                quickInputNumber = nextNumber;
              });
            }
          });
        }
      }
    }
  }

  /// 다음 활성화된 숫자 찾기 (현재 숫자부터 순환)
  int? _findNextActiveNumber(int currentNumber, Set<int> disabledNumbers) {
    // 현재 숫자 다음부터 9까지 확인
    for (int i = currentNumber + 1; i <= 9; i++) {
      if (!disabledNumbers.contains(i)) {
        return i;
      }
    }
    // 1부터 현재 숫자 전까지 확인
    for (int i = 1; i < currentNumber; i++) {
      if (!disabledNumbers.contains(i)) {
        return i;
      }
    }
    // 모든 숫자가 비활성화된 경우
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final board = widget.gameState.currentBoards[widget.boardIndex];
    final isFixed = widget.gameState.isFixed[widget.boardIndex];
    final notes = widget.gameState.notes[widget.boardIndex];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '보드 ${widget.boardIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      // 빠른 입력 토글
                      _buildHeaderToggle(
                        icon: Icons.flash_on,
                        label: '빠른',
                        isActive: isQuickInputMode,
                        activeColor: Colors.orange,
                        onTap: () {
                          setState(() {
                            isQuickInputMode = !isQuickInputMode;
                            if (!isQuickInputMode) {
                              quickInputNumber = null;
                            }
                            // 빠른 입력 모드 활성화 시 메모 모드 비활성화
                            if (isQuickInputMode) {
                              isNoteMode = false;
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      // 메모 모드 토글
                      _buildHeaderToggle(
                        icon: Icons.edit_note,
                        label: '메모',
                        isActive: isNoteMode,
                        activeColor: Colors.orange,
                        onTap: () {
                          setState(() {
                            isNoteMode = !isNoteMode;
                            // 메모 모드 활성화 시 빠른 입력 모드 비활성화
                            if (isNoteMode) {
                              isQuickInputMode = false;
                              quickInputNumber = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 9x9 보드
            Padding(
              padding: const EdgeInsets.all(10),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 3),
                  ),
                  child: _buildGrid(board, isFixed, notes),
                ),
              ),
            ),
            // 빠른 입력 모드 안내
            if (isQuickInputMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Text(
                        quickInputNumber != null
                            ? '숫자 $quickInputNumber 선택됨 - 셀을 탭하여 입력'
                            : '아래에서 숫자를 먼저 선택하세요',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // 기능 버튼들
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFeatureButton(
                    icon: Icons.grid_on,
                    label: '모든 메모',
                    onTap: () {
                      widget.onFillAllNotes(widget.boardIndex);
                      setState(() {});
                    },
                  ),
                  _buildFeatureButton(
                    icon: Icons.lightbulb_outline,
                    label: '힌트',
                    onTap: _onHint,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 숫자 패드
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: _buildNumberPad(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderToggle({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white24,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(
    List<List<int>> board,
    List<List<bool>> isFixed,
    List<List<Set<int>>> notes,
  ) {
    return Container(
      color: Colors.black,
      child: Column(
        children: List.generate(9, (row) {
          return Expanded(
            child: Row(
              children: List.generate(9, (col) {
                // 셀 오른쪽 간격 (3, 6번째 열 뒤에 두꺼운 선)
                double rightPadding = (col == 2 || col == 5) ? 2 : 1;
                // 셀 아래쪽 간격 (3, 6번째 행 뒤에 두꺼운 선)
                double bottomPadding = (row == 2 || row == 5) ? 2 : 1;
                // 마지막 열/행은 간격 없음
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

  Widget _buildFeatureButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? Colors.blue).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color ?? Colors.blue),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
    bool isSameRowOrCol = selectedRow != null && selectedCol != null &&
        (selectedRow == row || selectedCol == col);
    bool isSameBox = _isSameBox(row, col);
    bool isSameValue = selectedRow != null &&
        selectedCol != null &&
        value != 0 &&
        value == board[selectedRow!][selectedCol!];
    // 빠른 입력 모드에서 선택된 숫자와 같은 값 하이라이트
    bool isQuickInputValue = isQuickInputMode && quickInputNumber != null && value == quickInputNumber;
    bool hasError = value != 0 &&
        !SamuraiSudokuGenerator.isValidMove(board, row, col, value);

    // 배경색: 기본 흰색, 선택된 행/열/박스는 연한 파란색
    Color backgroundColor;
    if (isSelected) {
      backgroundColor = Colors.blue.shade300;
    } else if (isQuickInputValue) {
      backgroundColor = Colors.orange.shade200;
    } else if (isSameValue) {
      backgroundColor = Colors.blue.shade200;
    } else if (isSameRowOrCol || isSameBox) {
      backgroundColor = Colors.blue.shade50;
    } else {
      backgroundColor = Colors.white;
    }

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
                : const SizedBox(),
      ),
    );
  }

  void _onCellTap(int row, int col, bool isFixed) {
    setState(() {
      // 빠른 입력 모드일 때
      if (isQuickInputMode && quickInputNumber != null) {
        if (!isFixed) {
          // 일반 스도쿠와 동일하게 처리: 무조건 값 입력, 오류는 빨간색으로 표시
          int currentValue = widget.gameState.currentBoards[widget.boardIndex][row][col];
          if (currentValue == quickInputNumber) {
            // 같은 숫자면 지우기
            widget.onValueChanged(widget.boardIndex, row, col, 0);
          } else {
            // 다른 숫자면 입력
            widget.onValueChanged(widget.boardIndex, row, col, quickInputNumber!);
          }
          selectedRow = row;
          selectedCol = col;
        } else {
          // 고정 셀 탭: 선택만
          selectedRow = row;
          selectedCol = col;
        }
      } else {
        // 일반 모드 또는 메모 모드: 셀 선택/해제
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

  Widget _buildNotesGrid(Set<int> cellNotes) {
    return Padding(
      padding: const EdgeInsets.all(1),
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(9, (index) {
          int num = index + 1;
          bool hasNote = cellNotes.contains(num);
          return Center(
            child: Text(
              hasNote ? num.toString() : '',
              style: TextStyle(
                fontSize: 9,
                color: Colors.blue.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }),
      ),
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

  Widget _buildNumberPad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) => _buildNumberButton(index + 1)),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ...List.generate(4, (index) => _buildNumberButton(index + 6)),
            _buildEraseButton(),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberButton(int number) {
    // 빠른 입력 모드에서 선택된 숫자인지 확인
    bool isSelectedQuickInput = isQuickInputMode && quickInputNumber == number;

    Color bgColor;
    Color fgColor;

    if (isSelectedQuickInput) {
      bgColor = Colors.orange;
      fgColor = Colors.white;
    } else if (isQuickInputMode) {
      bgColor = Colors.orange.shade50;
      fgColor = Colors.orange.shade700;
    } else if (isNoteMode) {
      bgColor = Colors.amber.shade50;
      fgColor = Colors.amber.shade700;
    } else {
      bgColor = Colors.blue.shade50;
      fgColor = Colors.blue.shade700;
    }

    return SizedBox(
      width: 48,
      height: 48,
      child: ElevatedButton(
        onPressed: () => _onNumberTap(number),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          padding: EdgeInsets.zero,
          elevation: isSelectedQuickInput ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          number.toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEraseButton() {
    return SizedBox(
      width: 48,
      height: 48,
      child: ElevatedButton(
        onPressed: _onErase,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red.shade700,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Icon(Icons.cleaning_services, size: 20),
      ),
    );
  }

  void _onNumberTap(int number) {
    // 빠른 입력 모드: 숫자 선택/해제
    if (isQuickInputMode) {
      setState(() {
        if (quickInputNumber == number) {
          quickInputNumber = null; // 같은 숫자 탭하면 해제
        } else {
          quickInputNumber = number; // 다른 숫자 선택
        }
      });
      return;
    }

    // 일반 모드 또는 메모 모드: 기존 로직
    if (selectedRow == null || selectedCol == null) return;
    if (widget.gameState.isFixed[widget.boardIndex][selectedRow!][selectedCol!]) {
      return;
    }

    if (isNoteMode) {
      // 메모 모드: 메모 토글
      widget.onNoteToggle(widget.boardIndex, selectedRow!, selectedCol!, number);
    } else {
      // 일반 모드: 값 입력
      widget.onValueChanged(widget.boardIndex, selectedRow!, selectedCol!, number);
    }
    setState(() {});
  }

  void _onErase() {
    // 빠른 입력 모드에서는 숫자 선택 해제
    if (isQuickInputMode) {
      setState(() {
        quickInputNumber = null;
      });
      return;
    }

    if (selectedRow == null || selectedCol == null) return;
    if (widget.gameState.isFixed[widget.boardIndex][selectedRow!][selectedCol!]) {
      return;
    }

    // 값이 있으면 값 삭제, 없으면 메모 삭제
    if (widget.gameState.currentBoards[widget.boardIndex][selectedRow!][selectedCol!] != 0) {
      widget.onValueChanged(widget.boardIndex, selectedRow!, selectedCol!, 0);
    } else {
      widget.gameState.clearNotes(widget.boardIndex, selectedRow!, selectedCol!);
    }
    setState(() {});
  }

  void _onHint() {
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
    setState(() {});
  }
}
