import 'package:flutter/material.dart';

class SudokuCell extends StatelessWidget {
  final int value;
  final bool isFixed;
  final bool isSelected;
  final bool isHighlighted;
  final bool isSameValue;
  final bool hasError;
  final Set<int> notes;
  final VoidCallback onTap;
  final bool isQuickInputHighlight;
  final bool isQuickInputNoteHighlight;

  const SudokuCell({
    super.key,
    required this.value,
    required this.isFixed,
    required this.isSelected,
    required this.isHighlighted,
    required this.isSameValue,
    required this.hasError,
    required this.notes,
    required this.onTap,
    this.isQuickInputHighlight = false,
    this.isQuickInputNoteHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    if (isSelected) {
      backgroundColor = Colors.blue.shade300;
    } else if (isQuickInputHighlight) {
      // 숫자가 결정된 셀: 진한 파란색
      backgroundColor = Colors.blue.shade200;
    } else if (isQuickInputNoteHighlight) {
      // 메모에 포함된 셀: 연한 녹색
      backgroundColor = Colors.green.shade100;
    } else if (isSameValue && value != 0) {
      backgroundColor = Colors.blue.shade100;
    } else if (isHighlighted) {
      backgroundColor = Colors.blue.shade50;
    } else {
      backgroundColor = Colors.white;
    }

    Color textColor;
    if (hasError) {
      textColor = Colors.red;
    } else if (isFixed) {
      textColor = Colors.black;
    } else {
      textColor = Colors.blue.shade700;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
        child: value != 0
            ? Center(
                child: Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: isFixed ? FontWeight.bold : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              )
            : notes.isNotEmpty
                ? _buildNotesGrid()
                : const SizedBox.expand(),
      ),
    );
  }

  Widget _buildNotesGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 셀 크기에 비례해서 폰트 크기 결정
        final cellSize = constraints.maxWidth;
        final fontSize = (cellSize / 4.5).clamp(6.0, 12.0);

        return Padding(
          padding: const EdgeInsets.all(1),
          child: Column(
            children: List.generate(3, (rowIndex) {
              return Expanded(
                child: Row(
                  children: List.generate(3, (colIndex) {
                    int num = rowIndex * 3 + colIndex + 1;
                    bool hasNote = notes.contains(num);
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
          ),
        );
      },
    );
  }
}
