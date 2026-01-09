import 'dart:async';
import 'dart:math';

class MoleGame {
  final int gridSize;
  final int gameDuration; // 초 단위
  final List<bool> holes; // 두더지 출현 상태
  final Random _random = Random();

  int score = 0;
  int timeLeft;
  bool isPlaying = false;
  Timer? _moleTimer;
  Timer? _gameTimer;

  void Function()? onUpdate;
  void Function()? onGameEnd;

  MoleGame({this.gridSize = 9, this.gameDuration = 30})
      : holes = List.filled(9, false),
        timeLeft = gameDuration;

  void start() {
    score = 0;
    timeLeft = gameDuration;
    isPlaying = true;

    // 모든 구멍 초기화
    for (int i = 0; i < holes.length; i++) {
      holes[i] = false;
    }

    // 두더지 출현 타이머
    _moleTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      _showRandomMole();
    });

    // 게임 시간 타이머
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      timeLeft--;
      onUpdate?.call();

      if (timeLeft <= 0) {
        end();
      }
    });

    // 첫 두더지 바로 출현
    _showRandomMole();
    onUpdate?.call();
  }

  void _showRandomMole() {
    if (!isPlaying) return;

    // 기존 두더지 숨기기 (50% 확률)
    for (int i = 0; i < holes.length; i++) {
      if (holes[i] && _random.nextBool()) {
        holes[i] = false;
      }
    }

    // 새 두더지 출현 (1~2마리)
    final moleCount = _random.nextInt(2) + 1;
    for (int j = 0; j < moleCount; j++) {
      final emptyHoles = <int>[];
      for (int i = 0; i < holes.length; i++) {
        if (!holes[i]) emptyHoles.add(i);
      }

      if (emptyHoles.isNotEmpty) {
        final index = emptyHoles[_random.nextInt(emptyHoles.length)];
        holes[index] = true;
      }
    }

    onUpdate?.call();
  }

  bool whack(int index) {
    if (!isPlaying || index < 0 || index >= holes.length) return false;

    if (holes[index]) {
      holes[index] = false;
      score += 10;
      onUpdate?.call();
      return true;
    }
    return false;
  }

  void end() {
    isPlaying = false;
    _moleTimer?.cancel();
    _gameTimer?.cancel();

    // 모든 두더지 숨기기
    for (int i = 0; i < holes.length; i++) {
      holes[i] = false;
    }

    onUpdate?.call();
    onGameEnd?.call();
  }

  void dispose() {
    _moleTimer?.cancel();
    _gameTimer?.cancel();
  }
}
