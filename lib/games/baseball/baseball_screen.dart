import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/ad_service.dart';

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
    secretNumber = digits.take(digitCount).join();
  }

  void _onDigitInput(int digit) {
    if (gameOver) return;

    // 힌트로 공개된 위치는 입력 불가
    if (revealedPositions.contains(selectedIndex)) {
      // 다음 입력 가능한 위치로 이동
      _moveToNextEditablePosition();
      return;
    }

    final digitStr = digit.toString();

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
      // 다음 편집 가능한 칸으로 이동
      _moveToNextEditablePosition();
    });
    HapticFeedback.selectionClick();
  }

  void _moveToNextEditablePosition() {
    for (int i = selectedIndex + 1; i < digitCount; i++) {
      if (!revealedPositions.contains(i)) {
        setState(() {
          selectedIndex = i;
        });
        return;
      }
    }
    // 뒤에 없으면 앞에서 찾기
    for (int i = 0; i < selectedIndex; i++) {
      if (!revealedPositions.contains(i) && inputDigits[i] == null) {
        setState(() {
          selectedIndex = i;
        });
        return;
      }
    }
  }

  void _onDelete() {
    if (gameOver) return;

    setState(() {
      errorMessage = null;
      // 현재 위치가 공개된 위치면 이전 편집 가능한 위치로 이동
      if (revealedPositions.contains(selectedIndex)) {
        _moveToPrevEditablePosition();
        return;
      }

      if (inputDigits[selectedIndex] != null) {
        inputDigits[selectedIndex] = null;
      } else {
        // 이전 편집 가능한 위치로 이동 후 삭제
        _moveToPrevEditablePosition();
        if (!revealedPositions.contains(selectedIndex)) {
          inputDigits[selectedIndex] = null;
        }
      }
    });
    HapticFeedback.selectionClick();
  }

  void _moveToPrevEditablePosition() {
    for (int i = selectedIndex - 1; i >= 0; i--) {
      if (!revealedPositions.contains(i)) {
        selectedIndex = i;
        return;
      }
    }
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
      }
    });

    // 시도 횟수 소진 시 추가 시도 다이얼로그 표시
    if (!result.isCorrect && guessHistory.length >= maxAttempts) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showExtendAdDialog();
        }
      });
    }

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
      revealedPositions.clear();
      excludedNumbers.clear();
      maxAttempts = 10;
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

  // 힌트 광고 확인 다이얼로그
  void _showHintAdDialog() {
    if (gameOver) return;

    // 아직 공개되지 않은 위치들 찾기
    List<int> hiddenPositions = [];
    for (int i = 0; i < digitCount; i++) {
      if (!revealedPositions.contains(i)) {
        hiddenPositions.add(i);
      }
    }

    if (hiddenPositions.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text('dialog.hintTitle'.tr(), style: const TextStyle(color: Colors.white)),
        content: Text(
          'dialog.hintMessage'.tr(),
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
              final result = await adService.showRewardedAd(
                onUserEarnedReward: (ad, reward) {
                  _useHint();
                },
              );
              if (!result && mounted) {
                // 광고가 없어도 기능 실행
                _useHint();
                adService.loadRewardedAd();
              }
            },
            child: Text('common.watchAd'.tr()),
          ),
        ],
      ),
    );
  }

  void _useHint() {
    if (gameOver) return;

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
    final revealedDigit = secretNumber[positionToReveal];
    final revealedNumber = int.parse(revealedDigit);

    setState(() {
      revealedPositions.add(positionToReveal);
      // 입력 박스에 자동 입력
      inputDigits[positionToReveal] = revealedDigit;
      // 해당 숫자 버튼 제외 처리
      excludedNumbers.add(revealedNumber);
      // 현재 선택된 위치가 공개되었다면 다른 위치로 이동
      if (selectedIndex == positionToReveal) {
        for (int i = 0; i < digitCount; i++) {
          if (!revealedPositions.contains(i)) {
            selectedIndex = i;
            break;
          }
        }
      }
    });
    HapticFeedback.mediumImpact();
  }

  // 추가 시도 광고 다이얼로그
  void _showExtendAdDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Row(
          children: [
            Icon(Icons.sports_baseball, color: Colors.deepOrange, size: 28),
            SizedBox(width: 8),
            Text(
              '시도 횟수 소진!',
              style: TextStyle(color: Colors.deepOrange),
            ),
          ],
        ),
        content: const Text(
          '광고를 시청하면 5회 추가 시도할 수 있습니다.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                gameOver = true;
                gameWon = false;
              });
            },
            child: const Text('포기'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final adService = AdService();
              final result = await adService.showRewardedAd(
                onUserEarnedReward: (ad, reward) {
                  _extendAttempts();
                },
              );
              if (!result && mounted) {
                // 광고가 없어도 기능 실행
                _extendAttempts();
                adService.loadRewardedAd();
              }
            },
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('광고 보고 계속하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
            ),
          ),
        ],
      ),
    );
  }

  void _extendAttempts() {
    setState(() {
      maxAttempts += 5;
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
    final count = widget.difficulty == BaseballDifficulty.easy ? '3' : '4';
    return 'games.baseball.digitCount'.tr(namedArgs: {'count': count});
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return _buildLandscapeLayout();
        } else {
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
          'games.baseball.name'.tr(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.orange.shade100,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showRulesDialog,
            tooltip: 'app.rules'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: !gameOver ? _showHintAdDialog : null,
            tooltip: 'common.hint'.tr(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _restartGame,
            tooltip: 'app.restart'.tr(),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 동적 크기 계산
    final scaleFactor = min(screenHeight / 400, screenWidth / 900).clamp(1.0, 2.5);

    // 패널 너비 동적 계산
    final leftPanelWidth = (screenWidth * 0.18).clamp(160.0, 320.0);
    final rightPanelWidth = (screenWidth * 0.28).clamp(220.0, 400.0);

    return Scaffold(
      body: Container(
        color: Colors.grey.shade900,
        child: SafeArea(
          child: Row(
            children: [
              // 왼쪽 패널: 뒤로가기, 제목, 정보
              SizedBox(
                width: leftPanelWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back, color: Colors.white70, size: 24 * scaleFactor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    SizedBox(height: 8 * scaleFactor),
                    Icon(Icons.sports_baseball, color: Colors.deepOrange, size: 32 * scaleFactor),
                    SizedBox(height: 4 * scaleFactor),
                    Text(
                      'games.baseball.name'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20 * scaleFactor,
                        color: Colors.orange.shade100,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20 * scaleFactor),
                    _buildCompactInfo(scaleFactor: scaleFactor),
                    SizedBox(height: 16 * scaleFactor),
                    // 힌트 버튼
                    if (!gameOver)
                      GestureDetector(
                        onTap: _showHintAdDialog,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16 * scaleFactor, vertical: 10 * scaleFactor),
                          margin: EdgeInsets.symmetric(horizontal: 8 * scaleFactor),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8 * scaleFactor),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: Colors.amber,
                                size: 20 * scaleFactor,
                              ),
                              SizedBox(width: 6 * scaleFactor),
                              Text(
                                'common.hint'.tr(),
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15 * scaleFactor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (gameOver) ...[
                      SizedBox(height: 16 * scaleFactor),
                      _buildCompactResultMessage(scaleFactor: scaleFactor),
                    ],
                  ],
                ),
              ),
              // 중앙: 기록 목록
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24 * scaleFactor),
                  child: _buildGuessHistory(isLandscape: true, scaleFactor: scaleFactor),
                ),
              ),
              // 오른쪽 패널: 입력 박스 + 숫자 버튼
              SizedBox(
                width: rightPanelWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.help_outline, color: Colors.white70, size: 24 * scaleFactor),
                          onPressed: _showRulesDialog,
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh, color: Colors.white70, size: 24 * scaleFactor),
                          onPressed: _restartGame,
                        ),
                      ],
                    ),
                    SizedBox(height: 16 * scaleFactor),
                    // 입력 박스
                    if (!gameOver)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8 * scaleFactor, vertical: 8 * scaleFactor),
                        child: _buildDigitBoxes(isLandscape: true, scaleFactor: scaleFactor),
                      ),
                    SizedBox(height: 8 * scaleFactor),
                    // 숫자 패드 (3x4)
                    if (!gameOver) _buildNumberPad(isLandscape: true, scaleFactor: scaleFactor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDigitBoxes({bool isLandscape = false, double scaleFactor = 1.0}) {
    final baseBoxSize = isLandscape ? 40.0 : 56.0;
    final baseFontSize = isLandscape ? 20.0 : 32.0;
    final boxSize = baseBoxSize * scaleFactor;
    final fontSize = baseFontSize * scaleFactor;

    return Column(
      children: [
        if (errorMessage != null)
          Container(
            margin: EdgeInsets.only(bottom: 8 * scaleFactor),
            padding: EdgeInsets.symmetric(horizontal: 12 * scaleFactor, vertical: 6 * scaleFactor),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8 * scaleFactor),
            ),
            child: Text(
              errorMessage!,
              style: TextStyle(
                color: Colors.red,
                fontSize: (isLandscape ? 11 : 13) * scaleFactor,
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(digitCount, (index) {
            final isSelected = index == selectedIndex;
            final hasValue = inputDigits[index] != null;
            final isRevealed = revealedPositions.contains(index);

            return GestureDetector(
              onTap: () {
                // 힌트로 공개된 위치는 선택 불가
                if (!gameOver && !isRevealed) {
                  setState(() {
                    selectedIndex = index;
                  });
                  HapticFeedback.selectionClick();
                }
              },
              child: Container(
                width: boxSize,
                height: boxSize,
                margin: EdgeInsets.symmetric(horizontal: (isLandscape ? 3 : 6) * scaleFactor),
                decoration: BoxDecoration(
                  color: isRevealed
                      ? Colors.amber.withValues(alpha: 0.2)
                      : isSelected
                          ? Colors.deepOrange.withValues(alpha: 0.2)
                          : Colors.grey.shade800,
                  borderRadius: BorderRadius.circular((isLandscape ? 8 : 12) * scaleFactor),
                  border: Border.all(
                    color: isRevealed
                        ? Colors.amber
                        : isSelected
                            ? Colors.deepOrange
                            : Colors.grey.shade600,
                    width: ((isSelected || isRevealed) ? 3 : 2) * scaleFactor,
                  ),
                ),
                child: Center(
                  child: Text(
                    hasValue ? inputDigits[index]! : '',
                    style: TextStyle(
                      color: isRevealed ? Colors.amber : Colors.white,
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

  Widget _buildNumberPad({bool isLandscape = false, double scaleFactor = 1.0}) {
    if (isLandscape) {
      return _buildLandscapeNumberPad(scaleFactor: scaleFactor);
    }
    return _buildPortraitNumberPad();
  }

  Widget _buildPortraitNumberPad() {
    const buttonSize = 56.0;
    const fontSize = 24.0;
    const spacing = 8.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1-5
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [1, 2, 3, 4, 5].map((n) => _buildNumberButton(n, buttonSize, fontSize, spacing)).toList(),
          ),
          const SizedBox(height: spacing),
          // 6-0
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [6, 7, 8, 9, 0].map((n) => _buildNumberButton(n, buttonSize, fontSize, spacing)).toList(),
          ),
          const SizedBox(height: spacing + 2),
          // 삭제, 확인 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                icon: Icons.clear_all,
                onTap: _onClear,
                size: buttonSize,
                color: Colors.grey,
                margin: spacing / 2,
              ),
              const SizedBox(width: spacing),
              _buildActionButton(
                icon: Icons.backspace_outlined,
                onTap: _onDelete,
                size: buttonSize,
                color: Colors.orange,
                margin: spacing / 2,
              ),
              const SizedBox(width: spacing),
              GestureDetector(
                onTap: _submitGuess,
                child: Container(
                  width: buttonSize * 2 + spacing,
                  height: buttonSize,
                  margin: const EdgeInsets.all(spacing / 2),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'common.confirm'.tr(),
                      style: const TextStyle(
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
          const SizedBox(height: 8),
          Text(
            '${'games.baseball.strike'.tr()} : ${'games.baseball.strikeDesc'.tr()}  |  ${'games.baseball.ball'.tr()} : ${'games.baseball.ballDesc'.tr()}',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeNumberPad({double scaleFactor = 1.0}) {
    final buttonSize = 44.0 * scaleFactor;
    final fontSize = 18.0 * scaleFactor;
    final spacing = 4.0 * scaleFactor;

    return Container(
      padding: EdgeInsets.all(6 * scaleFactor),
      margin: EdgeInsets.symmetric(horizontal: 4 * scaleFactor),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12 * scaleFactor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1, 2, 3
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [1, 2, 3].map((n) => _buildNumberButton(n, buttonSize, fontSize, spacing)).toList(),
          ),
          SizedBox(height: spacing),
          // 4, 5, 6
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [4, 5, 6].map((n) => _buildNumberButton(n, buttonSize, fontSize, spacing)).toList(),
          ),
          SizedBox(height: spacing),
          // 7, 8, 9
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [7, 8, 9].map((n) => _buildNumberButton(n, buttonSize, fontSize, spacing)).toList(),
          ),
          SizedBox(height: spacing),
          // 삭제, 0, 백스페이스
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildActionButton(
                icon: Icons.clear_all,
                onTap: _onClear,
                size: buttonSize,
                color: Colors.grey,
                margin: spacing / 2,
              ),
              _buildNumberButton(0, buttonSize, fontSize, spacing),
              _buildActionButton(
                icon: Icons.backspace_outlined,
                onTap: _onDelete,
                size: buttonSize,
                color: Colors.orange,
                margin: spacing / 2,
              ),
            ],
          ),
          SizedBox(height: spacing + 2 * scaleFactor),
          // 확인 버튼
          GestureDetector(
            onTap: _submitGuess,
            child: Container(
              width: buttonSize * 3 + spacing * 4,
              height: buttonSize,
              margin: EdgeInsets.all(spacing / 2),
              decoration: BoxDecoration(
                color: Colors.deepOrange,
                borderRadius: BorderRadius.circular(8 * scaleFactor),
              ),
              child: Center(
                child: Text(
                  'common.confirm'.tr(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(int number, double size, double fontSize, double margin) {
    // 이미 사용된 숫자 체크
    final isUsed = inputDigits.contains(number.toString()) &&
        inputDigits[selectedIndex] != number.toString();
    // 제외된 숫자 체크
    final isExcluded = excludedNumbers.contains(number);

    return GestureDetector(
      onTap: (isUsed || isExcluded) ? null : () => _onDigitInput(number),
      onLongPress: () => _toggleExclude(number),
      onDoubleTap: () => _toggleExclude(number),
      child: Container(
        width: size,
        height: size,
        margin: EdgeInsets.all(margin),
        decoration: BoxDecoration(
          color: isExcluded
              ? Colors.red.withValues(alpha: 0.15)
              : isUsed
                  ? Colors.grey.shade700
                  : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(size > 40 ? 12 : 8),
          border: Border.all(
            color: isExcluded
                ? Colors.red.withValues(alpha: 0.5)
                : isUsed
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
                    : isUsed
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

  Widget _buildCompactInfo({double scaleFactor = 1.0}) {
    final iconSize = 18.0 * scaleFactor;
    final fontSize = 16.0 * scaleFactor;
    final padding = 14.0 * scaleFactor;
    final spacing = 10.0 * scaleFactor;

    return Container(
      padding: EdgeInsets.all(padding),
      margin: EdgeInsets.symmetric(horizontal: 8 * scaleFactor),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12 * scaleFactor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.tag, color: Colors.deepOrange, size: iconSize),
              SizedBox(width: 4 * scaleFactor),
              Text(
                _getDifficultyText(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.format_list_numbered, color: Colors.blue, size: iconSize),
              SizedBox(width: 4 * scaleFactor),
              Text(
                '${guessHistory.length}/$maxAttempts',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber, size: iconSize),
              SizedBox(width: 4 * scaleFactor),
              Text(
                _getHintedAnswer(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactResultMessage({double scaleFactor = 1.0}) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8 * scaleFactor),
      padding: EdgeInsets.all(14 * scaleFactor),
      decoration: BoxDecoration(
        color: gameWon
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12 * scaleFactor),
        border: Border.all(
          color: gameWon ? Colors.green : Colors.red,
          width: 2 * scaleFactor,
        ),
      ),
      child: Column(
        children: [
          Icon(
            gameWon ? Icons.emoji_events : Icons.sentiment_very_dissatisfied,
            color: gameWon ? Colors.amber : Colors.red,
            size: 28 * scaleFactor,
          ),
          SizedBox(height: 4 * scaleFactor),
          Text(
            gameWon ? 'games.baseball.correct'.tr() : 'common.gameOver'.tr(),
            style: TextStyle(
              color: gameWon ? Colors.green : Colors.red,
              fontSize: 16 * scaleFactor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            gameWon ? 'games.baseball.attempts'.tr(args: [guessHistory.length.toString()]) : secretNumber,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14 * scaleFactor,
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
            label: 'common.difficulty'.tr(),
          ),
          _buildInfoItem(
            icon: Icons.format_list_numbered,
            iconColor: Colors.blue,
            value: '${guessHistory.length}/$maxAttempts',
            label: 'games.baseball.attempts'.tr(),
          ),
          _buildInfoItem(
            icon: Icons.lightbulb_outline,
            iconColor: Colors.amber,
            value: _getHintedAnswer(),
            label: 'common.answer'.tr(),
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
                gameWon ? 'games.baseball.correct'.tr() : 'common.gameOver'.tr(),
                style: TextStyle(
                  color: gameWon ? Colors.green : Colors.red,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                gameWon
                    ? 'games.baseball.attempts'.tr(args: [guessHistory.length.toString()])
                    : '${'common.answer'.tr()}: $secretNumber',
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

  Widget _buildGuessHistory({bool isLandscape = false, double scaleFactor = 1.0}) {
    final iconSize = (isLandscape ? 48.0 : 64.0) * scaleFactor;
    final titleFontSize = (isLandscape ? 14.0 : 18.0) * scaleFactor;
    final subtitleFontSize = (isLandscape ? 11.0 : 14.0) * scaleFactor;

    if (guessHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_baseball,
              size: iconSize,
              color: Colors.grey.shade700,
            ),
            SizedBox(height: 16 * scaleFactor),
            Text(
              'games.baseball.guessInstruction'.tr(namedArgs: {'count': '$digitCount'}),
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: titleFontSize,
              ),
            ),
            SizedBox(height: 8 * scaleFactor),
            Text(
              'games.baseball.noDuplicates'.tr(),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: subtitleFontSize,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: (isLandscape ? 8 : 16) * scaleFactor, vertical: 8 * scaleFactor),
      itemCount: guessHistory.length,
      reverse: true,
      itemBuilder: (context, index) {
        final result = guessHistory[guessHistory.length - 1 - index];
        final attemptNumber = guessHistory.length - index;
        return _buildGuessCard(result, attemptNumber, isLandscape: isLandscape, scaleFactor: scaleFactor);
      },
    );
  }

  Widget _buildGuessCard(GuessResult result, int attemptNumber, {bool isLandscape = false, double scaleFactor = 1.0}) {
    final circleSize = (isLandscape ? 24.0 : 32.0) * scaleFactor;
    final guessFontSize = (isLandscape ? 18.0 : 24.0) * scaleFactor;
    final numberFontSize = (isLandscape ? 12.0 : 14.0) * scaleFactor;

    return Container(
      margin: EdgeInsets.only(bottom: 8 * scaleFactor),
      padding: EdgeInsets.all((isLandscape ? 8 : 12) * scaleFactor),
      decoration: BoxDecoration(
        color: result.isCorrect
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12 * scaleFactor),
        border: result.isCorrect
            ? Border.all(color: Colors.green, width: 2 * scaleFactor)
            : null,
      ),
      child: Row(
        children: [
          // 시도 번호
          Container(
            width: circleSize,
            height: circleSize,
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
                  fontSize: numberFontSize,
                ),
              ),
            ),
          ),
          SizedBox(width: (isLandscape ? 8 : 12) * scaleFactor),
          // 추측한 숫자
          Text(
            result.guess,
            style: TextStyle(
              color: Colors.white,
              fontSize: guessFontSize,
              fontWeight: FontWeight.bold,
              letterSpacing: (isLandscape ? 4 : 8) * scaleFactor,
            ),
          ),
          const Spacer(),
          // 결과
          _buildResultBadge(
            label: 'games.baseball.strike'.tr(),
            count: result.strikes,
            color: Colors.red,
            isLandscape: isLandscape,
            scaleFactor: scaleFactor,
          ),
          SizedBox(width: (isLandscape ? 4 : 8) * scaleFactor),
          _buildResultBadge(
            label: 'games.baseball.ball'.tr(),
            count: result.balls,
            color: Colors.blue,
            isLandscape: isLandscape,
            scaleFactor: scaleFactor,
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
    double scaleFactor = 1.0,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (isLandscape ? 8 : 12) * scaleFactor,
        vertical: (isLandscape ? 4 : 6) * scaleFactor,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8 * scaleFactor),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: (isLandscape ? 14 : 18) * scaleFactor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: (isLandscape ? 10 : 14) * scaleFactor,
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

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'games.baseball.rulesTitle'.tr(),
          style: const TextStyle(color: Colors.deepOrange),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'games.baseball.rulesObjective'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.baseball.rulesObjectiveDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.baseball.rulesStrikeBall'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.baseball.rulesStrikeBallDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.baseball.rulesExample'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.baseball.rulesExampleDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'games.baseball.rulesTips'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'games.baseball.rulesTipsDesc'.tr(),
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('app.confirm'.tr()),
          ),
        ],
      ),
    );
  }
}
