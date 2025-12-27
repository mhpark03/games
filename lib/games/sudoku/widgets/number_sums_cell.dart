import 'package:flutter/material.dart';

/// 숫자가 표시되는 입력 셀
class NumberSumsInputCell extends StatelessWidget {
  final int value;
  final bool isSelected;
  final bool isEmpty;
  final bool isMarkedCorrect;
  final bool isError;
  final int? blockColor; // 블록 배경색 (null이면 흰색)
  final int? blockSum; // 블록 합계 (첫 번째 셀에만 표시)
  final VoidCallback onTap;

  const NumberSumsInputCell({
    super.key,
    required this.value,
    required this.isSelected,
    required this.isEmpty,
    this.isMarkedCorrect = false,
    this.isError = false,
    this.blockColor,
    this.blockSum,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color borderColor = const Color(0xFF4A4A4A);

    if (isSelected) {
      backgroundColor = const Color(0xFFFFEB3B);
      borderColor = const Color(0xFFFF9800);
    } else if (blockColor != null) {
      backgroundColor = Color(blockColor!);
    } else {
      backgroundColor = Colors.white; // 블록 완료 또는 기본색
    }

    // 텍스트 색상 결정
    Color textColor;
    if (isError) {
      textColor = Colors.red;
    } else if (isSelected) {
      textColor = const Color(0xFF1A237E);
    } else {
      textColor = const Color(0xFF333333);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Stack(
          children: [
            // 정답 표시 동그라미 (맨 아래)
            if (isMarkedCorrect && !isEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: _CirclePainter(),
                ),
              ),
            // 숫자
            Center(
              child: value != 0
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Text(
                          '$value',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            // 블록 합계 (맨 위에 표시, 배경 포함)
            if (blockSum != null && blockSum! > 0)
              Positioned(
                top: 1,
                left: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                  decoration: BoxDecoration(
                    color: backgroundColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    '$blockSum',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 동그라미 그리기 Painter
class _CirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width < size.height ? size.width : size.height) / 2 - 4;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 합계를 표시하는 헤더 셀
class NumberSumsSumCell extends StatelessWidget {
  final int totalSum; // 전체 합
  final int selectedSum; // 선택한 올바른 수의 합
  final bool isComplete; // 모든 셀이 결정되었는지

  const NumberSumsSumCell({
    super.key,
    required this.totalSum,
    required this.selectedSum,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        border: Border.all(color: const Color(0xFF4A4A4A), width: 1),
      ),
      child: totalSum > 0
          ? Stack(
              children: [
                // 전체 합 (중앙에 크게)
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        '$totalSum',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                // 선택한 합 (우하단에 작게, 아랫첨자 형태)
                // 0일 때와 모든 셀이 결정되었을 때 숨김
                if (selectedSum > 0 && !isComplete)
                  Positioned(
                    right: 2,
                    bottom: 1,
                    child: Text(
                      '$selectedSum',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow.shade300,
                      ),
                    ),
                  ),
              ],
            )
          : null,
    );
  }
}

/// 코너 셀 (투명하게 처리)
class NumberSumsCornerCell extends StatelessWidget {
  const NumberSumsCornerCell({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E), // 배경색과 동일하게
    );
  }
}

/// 블록 셀 (코너 등)
class NumberSumsBlockedCell extends StatelessWidget {
  const NumberSumsBlockedCell({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        border: Border.all(color: const Color(0xFF4A4A4A), width: 1),
      ),
    );
  }
}
