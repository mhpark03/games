import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum BaseballDifficulty {
  easy,   // 3자리
  hard,   // 4자리
}

class GuessResult {
  final String guess;
  final int strikes;
  final int balls;

  GuessResult({
    required this.guess,
    required this.strikes,
    required this.balls,
  });

  bool get isCorrect => strikes == guess.length;
}

class BaseballScreen extends StatefulWidget {
  final BaseballDifficulty difficulty;

  const BaseballScreen({
    super.key,
    this.difficulty = BaseballDifficulty.easy,
  });

  @override
  State<BaseballScreen> createState() => _BaseballScreenState();
}

class _BaseballScreenState extends State<BaseballScreen> {
  late String secretNumber;
  late int digitCount;
  List<GuessResult> guessHistory = [];

  // 박스 선택 방식 입력
  late List<String?> inputDigits;
  int selectedIndex = 0;

  bool gameOver = false;
  bool gameWon = false;
  int maxAttempts = 10;
  String? errorMessage;

  // 힌트 기능
  int hintCount = 3;
  Set<int> revealedPositions = {};

  // 제외된 숫자
  Set<int> excludedNumbers = {};

  @override
  void initState() {
    super.initState();
    digitCount = widget.difficulty == BaseballDifficulty.easy ? 3 : 4;
    inputDigits = List.filled(digitCount, null);
    _generateSecretNumber();
  }

  void _generateSecretNumber() {
    final random = Random();
    List<int> digits = List.generate(10, (i) => i);
    digits.shuffle(random);

    // 첫 자리가 0이면 안됨
    if (digits[0] == 0) {
      int nonZeroIndex = digits.indexWhere((d) => d != 0);
      int temp = digits[0];
      digits[0] = digits[nonZeroIndex];
      digits[nonZeroIndex] = temp;
    }

    secretNumber = digits.take(digitCount).join();
  }

  void _onDigitInput(int digit) {
    if (gameOver) return;

    final digitStr = digit.toString();

    // 첫 자리에 0 입력 불가
    if (selectedIndex == 0 && digit == 0) {
      setState(() {
        errorMessage = '첫 자리는 0이 될 수 없습니다';
      });
      HapticFeedback.lightImpact();
      return;
    }

    // 중복 숫자 체크
    for (int i = 0; i < digitCount; i++) {
      if (i != selectedIndex && inputDigits[i] == digitStr) {
        setState(() {
          errorMessage = '이미 사용된 숫자입니다';
        });
        HapticFeedback.lightImpact();
        return;
      }
    }

    setState(() {
      errorMessage = null;
      inputDigits[selectedIndex] = digitStr;
      // 다음 빈 칸으로 이동
      if (selectedIndex < digitCount - 1) {
        selectedIndex++;
      }
    });
    HapticFeedback.selectionClick();
  }

  void _onDelete() {
    if (gameOver) return;

    setState(() {
      errorMessage = null;
      if (inputDigits[selectedIndex] != null) {
        inputDigits[selectedIndex] = null;
      } else if (selectedIndex > 0) {
        selectedIndex--;
        inputDigits[selectedIndex] = null;
      }
    });
    HapticFeedback.selectionClick();
  }

  void _onClear() {
    if (gameOver) return;

    setState(() {
      errorMessage = null;
      inputDigits = List.filled(digitCount, null);
      selectedIndex = 0;
    });
    HapticFeedback.selectionClick();
  }

  void _submitGuess() {
    // 모든 자리가 입력되었는지 확인
    if (inputDigits.any((d) => d == null)) {
      setState(() {
        errorMessage = '모든 자리를 입력하세요';
      });
      return;
    }

    final guess = inputDigits.join();

    // Strike와 Ball 계산
    int strikes = 0;
    int balls = 0;

    for (int i = 0; i < digitCount; i++) {
      if (guess[i] == secretNumber[i]) {
        strikes++;
      } else if (secretNumber.contains(guess[i])) {
        balls++;
      }
    }

    final result = GuessResult(
      guess: guess,
      strikes: strikes,
      balls: balls,
    );

    setState(() {
      guessHistory.add(result);
      errorMessage = null;
      inputDigits = List.filled(digitCount, null);
      selectedIndex = 0;

      if (result.isCorrect) {
        gameOver = true;
        gameWon = true;
      } else if (guessHistory.length >= maxAttempts) {
        gameOver = true;
        gameWon = false;
      }
    });

    HapticFeedback.mediumImpact();
  }

  void _restartGame() {
    setState(() {
      _generateSecretNumber();
      guessHistory.clear();
      inputDigits = List.filled(digitCount, null);
      selectedIndex = 0;
      gameOver = false;
      gameWon = false;
      errorMessage = null;
      hintCount = 3;
      revealedPositions.clear();
      excludedNumbers.clear();
    });
    HapticFeedback.mediumImpact();
  }

  void _toggleExclude(int number) {
    if (gameOver) return;

    setState(() {
      if (excludedNumbers.contains(number)) {
        excludedNumbers.remove(number);
      } else {
        excludedNumbers.add(number);
      }
    });
    HapticFeedback.selectionClick();
  }

  void _useHint() {
    if (hintCount <= 0 || gameOver) return;

    // 아직 공개되지 않은 위치들 찾기
    List<int> hiddenPositions = [];
    for (int i = 0; i < digitCount; i++) {
      if (!revealedPositions.contains(i)) {
        hiddenPositions.add(i);
      }
    }

    if (hiddenPositions.isEmpty) return;

    // 랜덤으로 하나 선택
    final random = Random();
    final positionToReveal = hiddenPositions[random.nextInt(hiddenPositions.length)];

    setState(() {
      revealedPositions.add(positionToReveal);
      hintCount--;
    });
    HapticFeedback.mediumImpact();
  }

  String _getHintedAnswer() {
    if (gameOver) return secretNumber;

    String result = '';
    for (int i = 0; i < secretNumber.length; i++) {
      if (revealedPositions.contains(i)) {
        result += secretNumber[i];
      } else {
        result += '?';
      }
    }
    return result;
  }

  String _getDifficultyText() {
    return widget.difficulty == BaseballDifficulty.easy ? '3자리' : '4자리';
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.immersiveSticky,
            overlays: [],
          );
          return _buildLandscapeLayout();
        } else {
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.edgeToEdge,
            overlays: SystemUiOverlay.values,
          );
          return _buildPortraitLayout();
        }
      },
    );
  }

  Widget _buildPortraitLayout() {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.deepOrange.shade800,
        foregroundColor: Colors.white,
        title: Text(
          '숫자야구',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.orange.shade100,
          ),
        ),
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.lightbulb_outline),
                onPressed: (hintCount > 0 && !gameOver) ? _useHint : null,
                tooltip: '힌트 ($hintCount)',
              ),
              if (hintCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$hintCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _restartGame,
            tooltip: '다시 시작',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildInfoPanel(),
            if (gameOver) _buildResultMessage(),
            Expanded(
              child: _buildGuessHistory(),
            ),
            if (!gameOver) _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Scaffold(
      body: Container(
        color: Colors.grey.shade900,
        child: SafeArea(
          child: Row(
            children: [
              // 왼쪽 패널: 뒤로가기, 제목, 정보
              SizedBox(
                width: 140,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Icon(Icons.sports_baseball, color: Colors.deepOrange, size: 28),
                    const SizedBox(height: 4),
                    Text(
                      '숫자',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.orange.shade100,
                      ),
                    ),
                    Text(
                      '야구',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.orange.shade100,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCompactInfo(),
                    const SizedBox(height: 12),
                    // 힌트 버튼
                    if (!gameOver)
                      GestureDetector(
                        onTap: hintCount > 0 ? _useHint : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: hintCount > 0
                                ? Colors.amber.withValues(alpha: 0.2)
                                : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hintCount > 0
                                  ? Colors.amber.withValues(alpha: 0.5)
                                  : Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: hintCount > 0 ? Colors.amber : Colors.grey,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '힌트 $hintCount',
                                style: TextStyle(
                                  color: hintCount > 0 ? Colors.amber : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (gameOver) ...[
                      _buildCompactResultMessage(),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              // 중앙: 기록 목록
              Expanded(
                child: Column(
                  children: [
                    // 숫자 입력 박스
                    if (!gameOver)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: _buildDigitBoxes(isLandscape: true),
                      ),
                    // 기록 목록
                    Expanded(
                      child: _buildGuessHistory(isLandscape: true),
                    ),
                  ],
                ),
              ),
              // 오른쪽 패널: 숫자 버튼
              SizedBox(
                width: 200,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white70),
                          onPressed: _restartGame,
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (!gameOver) _buildNumberPad(isLandscape: true),
                    const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDigitBoxes({bool isLandscape = false}) {
    final boxSize = isLandscape ? 44.0 : 56.0;
    final fontSize = isLandscape ? 24.0 : 32.0;

    return Column(
      children: [
        if (errorMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              errorMessage!,
              style: TextStyle(
                color: Colors.red,
                fontSize: isLandscape ? 11 : 13,
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(digitCount, (index) {
            final isSelected = index == selectedIndex;
            final hasValue = inputDigits[index] != null;

            return GestureDetector(
              onTap: () {
                if (!gameOver) {
                  setState(() {
                    selectedIndex = index;
                  });
                  HapticFeedback.selectionClick();
                }
              },
              child: Container(
                width: boxSize,
                height: boxSize,
                margin: EdgeInsets.symmetric(horizontal: isLandscape ? 4 : 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.deepOrange.withValues(alpha: 0.2)
                      : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.deepOrange : Colors.grey.shade600,
                    width: isSelected ? 3 : 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    hasValue ? inputDigits[index]! : '',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildNumberPad({bool isLandscape = false}) {
    final buttonSize = isLandscape ? 32.0 : 56.0;
    final fontSize = isLandscape ? 16.0 : 24.0;
    final spacing = isLandscape ? 3.0 : 8.0;

    return Container(
      padding: EdgeInsets.all(isLandscape ? 6 : 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: isLandscape
            ? BorderRadius.circular(12)
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1-5
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [1, 2, 3, 4, 5].map((n) => _buildNumberButton(n, buttonSize, fontSize, spacing)).toList(),
          ),
          SizedBox(height: spacing),
          // 6-0
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [6, 7, 8, 9, 0].map((n) => _buildNumberButton(n, buttonSize, fontSize, spacing)).toList(),
          ),
          SizedBox(height: spacing + 2),
          // 삭제, 확인 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 전체 삭제
              _buildActionButton(
                icon: Icons.clear_all,
                onTap: _onClear,
                size: buttonSize,
                color: Colors.grey,
                margin: spacing / 2,
              ),
              SizedBox(width: spacing),
              // 삭제
              _buildActionButton(
                icon: Icons.backspace_outlined,
                onTap: _onDelete,
                size: buttonSize,
                color: Colors.orange,
                margin: spacing / 2,
              ),
              SizedBox(width: spacing),
              // 확인
              GestureDetector(
                onTap: _submitGuess,
                child: Container(
                  width: buttonSize * 2 + spacing,
                  height: buttonSize,
                  margin: EdgeInsets.all(spacing / 2),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
                  ),
                  child: Center(
                    child: Text(
                      '확인',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: fontSize * 0.85,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!isLandscape) ...[
            const SizedBox(height: 8),
            Text(
              'S = Strike  |  B = Ball',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNumberButton(int number, double size, double fontSize, double margin) {
    // 첫 자리 선택 시 0 비활성화
    final isDisabled = selectedIndex == 0 && number == 0;
    // 이미 사용된 숫자 체크
    final isUsed = inputDigits.contains(number.toString()) &&
        inputDigits[selectedIndex] != number.toString();
    // 제외된 숫자 체크
    final isExcluded = excludedNumbers.contains(number);

    return GestureDetector(
      onTap: (isDisabled || isUsed || isExcluded) ? null : () => _onDigitInput(number),
      onLongPress: () => _toggleExclude(number),
      onDoubleTap: () => _toggleExclude(number),
      child: Container(
        width: size,
        height: size,
        margin: EdgeInsets.all(margin),
        decoration: BoxDecoration(
          color: isExcluded
              ? Colors.red.withValues(alpha: 0.15)
              : (isDisabled || isUsed)
                  ? Colors.grey.shade700
                  : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(size > 40 ? 12 : 8),
          border: Border.all(
            color: isExcluded
                ? Colors.red.withValues(alpha: 0.5)
                : (isDisabled || isUsed)
                    ? Colors.grey.shade600
                    : Colors.grey.shade500,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$number',
              style: TextStyle(
                color: isExcluded
                    ? Colors.red.withValues(alpha: 0.5)
                    : (isDisabled || isUsed)
                        ? Colors.grey.shade600
                        : Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isExcluded)
              Icon(
                Icons.close,
                color: Colors.red.withValues(alpha: 0.7),
                size: size * 0.7,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
    required Color color,
    double margin = 3,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        margin: EdgeInsets.all(margin),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(size > 40 ? 12 : 8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Icon(icon, color: color, size: size * 0.5),
        ),
      ),
    );
  }

  Widget _buildCompactInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.tag, color: Colors.deepOrange, size: 16),
              const SizedBox(width: 4),
              Text(
                _getDifficultyText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.format_list_numbered, color: Colors.blue, size: 16),
              const SizedBox(width: 4),
              Text(
                '${guessHistory.length}/$maxAttempts',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                _getHintedAnswer(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactResultMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: gameWon
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: gameWon ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            gameWon ? Icons.emoji_events : Icons.sentiment_very_dissatisfied,
            color: gameWon ? Colors.amber : Colors.red,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            gameWon ? '정답!' : '게임 오버',
            style: TextStyle(
              color: gameWon ? Colors.green : Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            gameWon ? '${guessHistory.length}번' : secretNumber,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInfoItem(
            icon: Icons.tag,
            iconColor: Colors.deepOrange,
            value: _getDifficultyText(),
            label: '난이도',
          ),
          _buildInfoItem(
            icon: Icons.format_list_numbered,
            iconColor: Colors.blue,
            value: '${guessHistory.length}/$maxAttempts',
            label: '시도 횟수',
          ),
          _buildInfoItem(
            icon: Icons.lightbulb_outline,
            iconColor: Colors.amber,
            value: _getHintedAnswer(),
            label: '정답',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildResultMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gameWon
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: gameWon ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            gameWon ? Icons.emoji_events : Icons.sentiment_very_dissatisfied,
            color: gameWon ? Colors.amber : Colors.red,
            size: 32,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gameWon ? '정답입니다!' : '게임 오버',
                style: TextStyle(
                  color: gameWon ? Colors.green : Colors.red,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                gameWon
                    ? '${guessHistory.length}번 만에 맞추셨습니다!'
                    : '정답: $secretNumber',
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuessHistory({bool isLandscape = false}) {
    if (guessHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_baseball,
              size: isLandscape ? 48 : 64,
              color: Colors.grey.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              '${digitCount}자리 숫자를 맞춰보세요!',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: isLandscape ? 14 : 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '각 자리의 숫자는 중복되지 않습니다',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: isLandscape ? 11 : 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isLandscape ? 8 : 16, vertical: 8),
      itemCount: guessHistory.length,
      reverse: true,
      itemBuilder: (context, index) {
        final result = guessHistory[guessHistory.length - 1 - index];
        final attemptNumber = guessHistory.length - index;
        return _buildGuessCard(result, attemptNumber, isLandscape: isLandscape);
      },
    );
  }

  Widget _buildGuessCard(GuessResult result, int attemptNumber, {bool isLandscape = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isLandscape ? 8 : 12),
      decoration: BoxDecoration(
        color: result.isCorrect
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: result.isCorrect
            ? Border.all(color: Colors.green, width: 2)
            : null,
      ),
      child: Row(
        children: [
          // 시도 번호
          Container(
            width: isLandscape ? 24 : 32,
            height: isLandscape ? 24 : 32,
            decoration: BoxDecoration(
              color: Colors.deepOrange.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$attemptNumber',
                style: TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: isLandscape ? 12 : 14,
                ),
              ),
            ),
          ),
          SizedBox(width: isLandscape ? 8 : 12),
          // 추측한 숫자
          Text(
            result.guess,
            style: TextStyle(
              color: Colors.white,
              fontSize: isLandscape ? 18 : 24,
              fontWeight: FontWeight.bold,
              letterSpacing: isLandscape ? 4 : 8,
            ),
          ),
          const Spacer(),
          // 결과
          _buildResultBadge(
            label: 'S',
            count: result.strikes,
            color: Colors.red,
            isLandscape: isLandscape,
          ),
          SizedBox(width: isLandscape ? 4 : 8),
          _buildResultBadge(
            label: 'B',
            count: result.balls,
            color: Colors.blue,
            isLandscape: isLandscape,
          ),
        ],
      ),
    );
  }

  Widget _buildResultBadge({
    required String label,
    required int count,
    required Color color,
    bool isLandscape = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 8 : 12,
        vertical: isLandscape ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: isLandscape ? 14 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: isLandscape ? 10 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Column(
      children: [
        // 숫자 입력 박스
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _buildDigitBoxes(),
        ),
        // 숫자 패드
        _buildNumberPad(),
      ],
    );
  }
}
