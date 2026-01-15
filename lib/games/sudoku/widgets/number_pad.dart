import 'package:flutter/material.dart';

class NumberPad extends StatelessWidget {
  final Function(int) onNumberTap;
  final VoidCallback onUndo; // 취소 버튼 콜백
  final bool canUndo; // 취소 가능 여부
  final bool isCompact;
  final int? quickInputNumber; // 빠른 입력 모드에서 선택된 숫자
  final VoidCallback? onQuickInputToggle; // 빠른 입력 모드 토글
  final Set<int> disabledNumbers; // 비활성화된 숫자들 (모두 채워진 숫자)
  final bool showUndoButton; // 취소 버튼 표시 여부
  final double? landscapeHeight; // 가로 모드에서 화면 높이 (동적 크기 계산용)

  const NumberPad({
    super.key,
    required this.onNumberTap,
    required this.onUndo,
    this.canUndo = false,
    this.isCompact = false,
    this.quickInputNumber,
    this.onQuickInputToggle,
    this.disabledNumbers = const {},
    this.showUndoButton = true,
    this.landscapeHeight,
  });

  bool get isQuickInputMode => quickInputNumber != null;

  @override
  Widget build(BuildContext context) {
    // 화면 높이에 따른 동적 버튼 크기 계산
    double buttonSize;
    double fontSize;
    double iconSize;
    double spacing;

    if (isCompact && landscapeHeight != null) {
      // 가로 모드: 화면 높이에 따라 동적 크기 조정
      // 높이가 클수록 버튼이 커짐 (300~900 범위 기준)
      final heightFactor = ((landscapeHeight! - 300) / 600).clamp(0.0, 1.5);
      buttonSize = 40.0 + (heightFactor * 40.0); // 40~100
      fontSize = 16.0 + (heightFactor * 16.0);   // 16~40
      iconSize = 16.0 + (heightFactor * 12.0);   // 16~34
      spacing = 4.0 + (heightFactor * 8.0);      // 4~16
    } else if (isCompact) {
      buttonSize = 40.0;
      fontSize = 16.0;
      iconSize = 16.0;
      spacing = 4.0;
    } else {
      buttonSize = 56.0;
      fontSize = 22.0;
      iconSize = 22.0;
      spacing = 8.0;
    }

    if (isCompact) {
      // 가로 모드: 3x3 + 지우기 버튼 그리드
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 빠른 입력 모드 토글 버튼
          if (onQuickInputToggle != null)
            Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: _buildQuickInputToggle(buttonSize, fontSize),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return Padding(
                padding: EdgeInsets.all(spacing / 2),
                child: _buildNumberButton(index + 1, buttonSize, fontSize),
              );
            }),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return Padding(
                padding: EdgeInsets.all(spacing / 2),
                child: _buildNumberButton(index + 4, buttonSize, fontSize),
              );
            }),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return Padding(
                padding: EdgeInsets.all(spacing / 2),
                child: _buildNumberButton(index + 7, buttonSize, fontSize),
              );
            }),
          ),
          if (showUndoButton)
            Padding(
              padding: EdgeInsets.all(spacing / 2),
              child: _buildUndoButton(buttonSize * 2 + spacing, buttonSize, iconSize),
            ),
        ],
      );
    } else {
      // 세로 모드: 기존 레이아웃 + 빠른 입력 토글
      return Column(
        children: [
          // 빠른 입력 모드 토글 버튼
          if (onQuickInputToggle != null)
            Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: _buildQuickInputToggle(buttonSize, fontSize),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              return _buildNumberButton(index + 1, buttonSize, fontSize);
            }),
          ),
          SizedBox(height: spacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ...List.generate(4, (index) {
                return _buildNumberButton(index + 6, buttonSize, fontSize);
              }),
              if (showUndoButton)
                _buildUndoButton(buttonSize, buttonSize, iconSize),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildQuickInputToggle(double buttonSize, double fontSize) {
    return Container(
      decoration: BoxDecoration(
        color: isQuickInputMode ? Colors.orange.shade100 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isQuickInputMode ? Colors.orange : Colors.grey.shade400,
          width: isQuickInputMode ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onQuickInputToggle,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12 : 16,
              vertical: isCompact ? 6 : 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isQuickInputMode ? Icons.flash_on : Icons.flash_off,
                  color: isQuickInputMode ? Colors.orange : Colors.grey.shade600,
                  size: isCompact ? 18 : 22,
                ),
                SizedBox(width: isCompact ? 4 : 8),
                Text(
                  isQuickInputMode
                    ? '빠른 입력: ${quickInputNumber!}'
                    : '빠른 입력',
                  style: TextStyle(
                    fontSize: isCompact ? 12 : 14,
                    fontWeight: isQuickInputMode ? FontWeight.bold : FontWeight.normal,
                    color: isQuickInputMode ? Colors.orange.shade700 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberButton(int number, double size, double fontSize) {
    final isSelected = quickInputNumber == number;
    final isDisabled = disabledNumbers.contains(number);

    return SizedBox(
      width: size,
      height: size,
      child: ElevatedButton(
        onPressed: isDisabled ? null : () => onNumberTap(number),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled
            ? Colors.grey.shade300
            : isSelected
              ? Colors.orange.shade400
              : Colors.blue.shade50,
          foregroundColor: isDisabled
            ? Colors.grey.shade500
            : isSelected
              ? Colors.white
              : Colors.blue.shade700,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: isDisabled ? 0 : isSelected ? 4 : 1,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
        ),
        child: Text(
          number.toString(),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildUndoButton(double width, double height, double iconSize) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: canUndo ? onUndo : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canUndo ? Colors.grey.shade100 : Colors.grey.shade200,
          foregroundColor: canUndo ? Colors.grey.shade700 : Colors.grey.shade400,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          disabledBackgroundColor: Colors.grey.shade200,
          disabledForegroundColor: Colors.grey.shade400,
        ),
        child: Icon(Icons.undo, size: iconSize),
      ),
    );
  }
}
