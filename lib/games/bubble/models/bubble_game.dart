import 'dart:math';

enum BubbleColor { red, blue, green, yellow, purple, orange, empty }

class Bubble {
  BubbleColor color;
  double x;
  double y;
  bool isMoving;
  double vx;
  double vy;

  Bubble({
    required this.color,
    this.x = 0,
    this.y = 0,
    this.isMoving = false,
    this.vx = 0,
    this.vy = 0,
  });
}

class BubbleShooterGame {
  static const int rows = 12;
  static const int cols = 8;
  static const double bubbleRadius = 20.0;

  late List<List<Bubble?>> grid;
  final Random _random = Random();

  Bubble? currentBubble;
  Bubble? nextBubble;
  Bubble? shootingBubble;

  double shooterX = 0;
  double shooterY = 0;
  double aimAngle = -pi / 2; // 위쪽 방향

  int score = 0;
  bool isGameOver = false;
  bool isShooting = false;

  List<Bubble> fallingBubbles = [];
  List<Bubble> poppingBubbles = [];

  void Function()? onUpdate;
  void Function()? onGameOver;

  BubbleShooterGame() {
    _initGame();
  }

  void _initGame() {
    score = 0;
    isGameOver = false;
    isShooting = false;
    fallingBubbles.clear();
    poppingBubbles.clear();

    // 그리드 초기화
    grid = List.generate(rows, (_) => List.filled(cols, null));

    // 상단 5줄에 버블 배치
    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < cols; col++) {
        // 홀수 행은 오프셋
        if (row % 2 == 1 && col == cols - 1) continue;
        grid[row][col] = Bubble(color: _randomColor());
      }
    }

    _prepareNextBubble();
    _prepareNextBubble();
  }

  BubbleColor _randomColor() {
    final colors = [
      BubbleColor.red,
      BubbleColor.blue,
      BubbleColor.green,
      BubbleColor.yellow,
      BubbleColor.purple,
      BubbleColor.orange,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  void _prepareNextBubble() {
    currentBubble = nextBubble;
    nextBubble = Bubble(color: _randomColor());
  }

  void setShooterPosition(double x, double y) {
    shooterX = x;
    shooterY = y;
  }

  void aim(double targetX, double targetY) {
    if (isShooting) return;

    final dx = targetX - shooterX;
    final dy = targetY - shooterY;
    aimAngle = atan2(dy, dx);

    // 각도 제한 (위쪽 방향만)
    if (aimAngle > -0.1) aimAngle = -0.1;
    if (aimAngle < -pi + 0.1) aimAngle = -pi + 0.1;
  }

  void shoot() {
    if (isShooting || currentBubble == null) return;

    isShooting = true;
    shootingBubble = Bubble(
      color: currentBubble!.color,
      x: shooterX,
      y: shooterY,
      isMoving: true,
      vx: cos(aimAngle) * 15,
      vy: sin(aimAngle) * 15,
    );

    _prepareNextBubble();
  }

  void update(double width, double height) {
    if (shootingBubble != null && shootingBubble!.isMoving) {
      // 버블 이동
      shootingBubble!.x += shootingBubble!.vx;
      shootingBubble!.y += shootingBubble!.vy;

      // 좌우 벽 반사
      if (shootingBubble!.x < bubbleRadius) {
        shootingBubble!.x = bubbleRadius;
        shootingBubble!.vx = -shootingBubble!.vx;
      }
      if (shootingBubble!.x > width - bubbleRadius) {
        shootingBubble!.x = width - bubbleRadius;
        shootingBubble!.vx = -shootingBubble!.vx;
      }

      // 상단 벽 또는 다른 버블과 충돌 체크
      if (shootingBubble!.y < bubbleRadius) {
        _snapBubbleToGrid(width);
      } else if (_checkCollision(width)) {
        _snapBubbleToGrid(width);
      }
    }

    // 떨어지는 버블 업데이트
    for (final bubble in fallingBubbles) {
      bubble.vy += 0.5; // 중력
      bubble.y += bubble.vy;
    }
    fallingBubbles.removeWhere((b) => b.y > height + 50);

    // 터지는 버블 업데이트
    poppingBubbles.removeWhere((b) {
      b.x += (b.vx);
      b.y += (b.vy);
      b.vy += 0.3;
      return b.y > height + 50;
    });

    onUpdate?.call();
  }

  bool _checkCollision(double width) {
    if (shootingBubble == null) return false;

    final cellWidth = width / cols;
    final cellHeight = bubbleRadius * 2 * 0.866; // 육각형 패킹

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (grid[row][col] == null) continue;

        final offset = (row % 2 == 1) ? cellWidth / 2 : 0;
        final bx = col * cellWidth + cellWidth / 2 + offset;
        final by = row * cellHeight + bubbleRadius;

        final dx = shootingBubble!.x - bx;
        final dy = shootingBubble!.y - by;
        final dist = sqrt(dx * dx + dy * dy);

        if (dist < bubbleRadius * 1.8) {
          return true;
        }
      }
    }
    return false;
  }

  void _snapBubbleToGrid(double width) {
    if (shootingBubble == null) return;

    final cellWidth = width / cols;
    final cellHeight = bubbleRadius * 2 * 0.866;

    // 가장 가까운 빈 셀 찾기 (기존 버블과 인접한 셀만)
    int bestRow = 0;
    int bestCol = 0;
    double bestDist = double.infinity;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (row % 2 == 1 && col == cols - 1) continue;
        if (grid[row][col] != null) continue;

        // 첫 번째 행이 아니면, 인접한 버블이 있어야 함
        if (row > 0 && !_hasAdjacentBubble(row, col)) continue;

        final offset = (row % 2 == 1) ? cellWidth / 2 : 0;
        final bx = col * cellWidth + cellWidth / 2 + offset;
        final by = row * cellHeight + bubbleRadius;

        final dx = shootingBubble!.x - bx;
        final dy = shootingBubble!.y - by;
        final dist = sqrt(dx * dx + dy * dy);

        if (dist < bestDist) {
          bestDist = dist;
          bestRow = row;
          bestCol = col;
        }
      }
    }

    // 그리드에 버블 배치
    grid[bestRow][bestCol] = Bubble(color: shootingBubble!.color);

    // 같은 색 버블 체크 및 제거
    final connected = _findConnected(bestRow, bestCol, shootingBubble!.color);
    if (connected.length >= 3) {
      // 버블 터뜨리기
      for (final pos in connected) {
        final row = pos.$1;
        final col = pos.$2;
        final offset = (row % 2 == 1) ? cellWidth / 2 : 0;

        poppingBubbles.add(Bubble(
          color: grid[row][col]!.color,
          x: col * cellWidth + cellWidth / 2 + offset,
          y: row * cellHeight + bubbleRadius,
          vx: (_random.nextDouble() - 0.5) * 8,
          vy: (_random.nextDouble() - 0.5) * 8,
        ));

        grid[row][col] = null;
      }
      score += connected.length * connected.length * 10;

      // 연결되지 않은 버블 떨어뜨리기
      _dropFloatingBubbles(cellWidth, cellHeight);
    }

    shootingBubble = null;
    isShooting = false;

    // 게임 오버 체크
    _checkGameOver();
  }

  Set<(int, int)> _findConnected(int row, int col, BubbleColor color) {
    final connected = <(int, int)>{};
    final toCheck = <(int, int)>[(row, col)];

    while (toCheck.isNotEmpty) {
      final current = toCheck.removeLast();
      final r = current.$1;
      final c = current.$2;

      if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
      if (connected.contains((r, c))) continue;
      if (grid[r][c] == null || grid[r][c]!.color != color) continue;

      connected.add((r, c));

      // 육각형 이웃
      final neighbors = _getNeighbors(r, c);
      toCheck.addAll(neighbors);
    }

    return connected;
  }

  List<(int, int)> _getNeighbors(int row, int col) {
    final neighbors = <(int, int)>[];

    // 8방향 모두 체크 (더 관대한 연결 판정)
    neighbors.add((row - 1, col));     // 상
    neighbors.add((row + 1, col));     // 하
    neighbors.add((row, col - 1));     // 좌
    neighbors.add((row, col + 1));     // 우
    neighbors.add((row - 1, col - 1)); // 좌상
    neighbors.add((row - 1, col + 1)); // 우상
    neighbors.add((row + 1, col - 1)); // 좌하
    neighbors.add((row + 1, col + 1)); // 우하

    return neighbors;
  }

  bool _hasAdjacentBubble(int row, int col) {
    final neighbors = _getNeighbors(row, col);
    for (final neighbor in neighbors) {
      final r = neighbor.$1;
      final c = neighbor.$2;
      if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
      if (grid[r][c] != null) return true;
    }
    return false;
  }

  void _dropFloatingBubbles(double cellWidth, double cellHeight) {
    // 상단에 연결된 버블 찾기
    final attached = <(int, int)>{};
    final toCheck = <(int, int)>[];

    // 첫 번째 행의 모든 버블에서 시작
    for (int col = 0; col < cols; col++) {
      if (grid[0][col] != null) {
        toCheck.add((0, col));
      }
    }

    while (toCheck.isNotEmpty) {
      final current = toCheck.removeLast();
      final r = current.$1;
      final c = current.$2;

      if (r < 0 || r >= rows || c < 0 || c >= cols) continue;
      if (attached.contains((r, c))) continue;
      if (grid[r][c] == null) continue;

      attached.add((r, c));

      final neighbors = _getNeighbors(r, c);
      toCheck.addAll(neighbors);
    }

    // 연결되지 않은 버블 떨어뜨리기
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (grid[row][col] != null && !attached.contains((row, col))) {
          final offset = (row % 2 == 1) ? cellWidth / 2 : 0;

          fallingBubbles.add(Bubble(
            color: grid[row][col]!.color,
            x: col * cellWidth + cellWidth / 2 + offset,
            y: row * cellHeight + bubbleRadius,
            vy: 0,
          ));

          score += 20;
          grid[row][col] = null;
        }
      }
    }
  }

  void _checkGameOver() {
    // 마지막 행에 버블이 있으면 게임 오버
    for (int col = 0; col < cols; col++) {
      if (grid[rows - 1][col] != null) {
        isGameOver = true;
        onGameOver?.call();
        return;
      }
    }
  }

  void reset() {
    _initGame();
    onUpdate?.call();
  }
}
