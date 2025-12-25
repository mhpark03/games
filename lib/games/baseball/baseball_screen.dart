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
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool gameOver = false;
  bool gameWon = false;
  int maxAttempts = 10;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    digitCount = widget.difficulty == BaseballDifficulty.easy ? 3 : 4;
    _generateSecretNumber();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
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

  void _submitGuess() {
    final guess = _controller.text.trim();

    // 유효성 검사
    if (guess.length != digitCount) {
      setState(() {
        errorMessage = '$digitCount자리 숫자를 입력하세요';
      });
      return;
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(guess)) {
      setState(() {
        errorMessage = '숫자만 입력하세요';
      });
      return;
    }

    if (guess[0] == '0') {
      setState(() {
        errorMessage = '첫 자리는 0이 될 수 없습니다';
      });
      return;
    }

    // 중복 숫자 검사
    if (guess.split('').toSet().length != digitCount) {
      setState(() {
        errorMessage = '중복된 숫자가 있습니다';
      });
      return;
    }

    // 이미 시도한 숫자인지 검사
    if (guessHistory.any((r) => r.guess == guess)) {
      setState(() {
        errorMessage = '이미 시도한 숫자입니다';
      });
      return;
    }

    setState(() {
      errorMessage = null;
    });

    // 스트라이크, 볼 계산
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
      _controller.clear();

      if (result.isCorrect) {
        gameWon = true;
        gameOver = true;
        HapticFeedback.heavyImpact();
      } else if (guessHistory.length >= maxAttempts) {
        gameOver = true;
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    });
  }

  void _restartGame() {
    setState(() {
      guessHistory.clear();
      gameOver = false;
      gameWon = false;
      errorMessage = null;
      _controller.clear();
      _generateSecretNumber();
    });
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_baseball, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              '숫자야구',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.orange.shade100,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
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
                width: 160,
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
                    Expanded(
                      child: _buildGuessHistory(isLandscape: true),
                    ),
                  ],
                ),
              ),
              // 오른쪽 패널: 입력 영역
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
                    if (!gameOver) _buildCompactInputArea(),
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
                gameOver ? secretNumber : '???',
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

  Widget _buildCompactInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            maxLength: digitCount,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '0' * digitCount,
              hintStyle: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 24,
                letterSpacing: 8,
              ),
              filled: true,
              fillColor: Colors.grey.shade900,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Colors.deepOrange,
                  width: 2,
                ),
              ),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onSubmitted: (_) => _submitGuess(),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitGuess,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '확인',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'S=Strike  B=Ball',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 10,
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
            value: gameOver ? secretNumber : '???',
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 에러 메시지
          if (errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              // 숫자 입력 필드
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  maxLength: digitCount,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 12,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '0' * digitCount,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 28,
                      letterSpacing: 12,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade900,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.deepOrange,
                        width: 2,
                      ),
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onSubmitted: (_) => _submitGuess(),
                ),
              ),
              const SizedBox(width: 12),
              // 확인 버튼
              ElevatedButton(
                onPressed: _submitGuess,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 힌트
          Text(
            'S = Strike (숫자와 위치 모두 일치)  |  B = Ball (숫자만 일치)',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
