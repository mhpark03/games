import 'package:flutter/material.dart';

class NumberPad extends StatelessWidget {
  final Function(int) onNumberTap;
  final VoidCallback onUndo; // 취소 버튼 콜백
  final bool canUndo; // 취소 가능 여부
  final bool isCompact;
  final int? quickInputNumber; // 빠른 입력 모드에서 선택된 숫자
  final VoidCallback? onQuickInputToggle; // 빠른 입력 모드 토글
  final Set<int> disabledNumbers; // 비활성화된 숫자들 (모두 채워진 숫자)

  const NumberPad({
    super.key,
    required this.onNumberTap,
    required this.onUndo,
    this.canUndo = false,
    this.isCompact = false,
    this.quickInputNumber,
    this.onQuickInputToggle,
    this.disabledNumbers = const {},
  });

  bool get isQuickInputMode => quickInputNumber != null;

  @override
  Widget build(BuildContext context) {
    final buttonSize = isCompact ? 36.0 : 60.0;
    final fontSize = isCompact ? 16.0 : 24.0;
    final iconSize = isCompact ? 16.0 : 24.0;
    final spacing = isCompact ? 4.0 : 10.0;

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
