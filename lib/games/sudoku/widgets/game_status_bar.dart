import 'package:flutter/material.dart';

/// 게임 상태 표시 바 (시간, 실패 횟수, 일시정지 버튼)
class GameStatusBar extends StatelessWidget {
  /// 경과 시간 (초)
  final int elapsedSeconds;

  /// 실패 횟수
  final int failureCount;

  /// 일시정지 상태
  final bool isPaused;

  /// 일시정지 토글 콜백
  final VoidCallback onPauseToggle;

  /// 컴팩트 모드 (가로 모드)
  final bool isCompact;

  /// 난이도 텍스트 (선택)
  final String? difficultyText;

  /// 테마 색상 (기본: 파란색)
  final Color themeColor;

  const GameStatusBar({
    super.key,
    required this.elapsedSeconds,
    required this.failureCount,
    required this.isPaused,
    required this.onPauseToggle,
    this.isCompact = false,
    this.difficultyText,
    this.themeColor = Colors.blue,
  });

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 20,
        vertical: isCompact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 시간 표시
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: isCompact ? 18 : 20,
                color: Colors.white70,
              ),
              SizedBox(width: isCompact ? 4 : 6),
              Text(
                _formatTime(elapsedSeconds),
                style: TextStyle(
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          // 난이도 (있는 경우)
          if (difficultyText != null)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 10 : 12,
                vertical: isCompact ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                difficultyText!,
                style: TextStyle(
                  fontSize: isCompact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: themeColor,
                ),
              ),
            ),
          // 실패 횟수
          Row(
            children: [
              Icon(
                Icons.close,
                size: isCompact ? 18 : 20,
                color: Colors.red.shade300,
              ),
              SizedBox(width: isCompact ? 2 : 4),
              Text(
                '$failureCount',
                style: TextStyle(
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade300,
                ),
              ),
            ],
          ),
          // 일시정지 버튼
          IconButton(
            onPressed: onPauseToggle,
            icon: Icon(
              isPaused ? Icons.play_arrow : Icons.pause,
              color: Colors.white,
              size: isCompact ? 20 : 24,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              padding: EdgeInsets.all(isCompact ? 6 : 8),
            ),
          ),
        ],
      ),
    );
  }
}
