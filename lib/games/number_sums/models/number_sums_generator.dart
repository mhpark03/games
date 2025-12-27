import 'dart:math';

enum NumberSumsDifficulty { easy, medium, hard }

class NumberSumsGenerator {
  final Random _random = Random();

  Map<String, dynamic> generatePuzzle(NumberSumsDifficulty difficulty) {
    int gameSize;
    double fillRatio; // 정답 셀 비율
    int blockCount; // 블록 개수

    switch (difficulty) {
      case NumberSumsDifficulty.easy:
        gameSize = 5;
        fillRatio = 0.6; // 60% 정답 셀
        blockCount = 4; // 25칸 / 4블록 = 약 6칸씩
        break;
      case NumberSumsDifficulty.medium:
        gameSize = 6;
        fillRatio = 0.55;
        blockCount = 5; // 36칸 / 5블록 = 약 7칸씩
        break;
      case NumberSumsDifficulty.hard:
        gameSize = 7;
        fillRatio = 0.5;
        blockCount = 6; // 49칸 / 6블록 = 약 8칸씩
        break;
    }

    return _generateEliminationPuzzle(gameSize, difficulty, fillRatio, blockCount);
  }

  Map<String, dynamic> _generateEliminationPuzzle(
      int gameSize, NumberSumsDifficulty difficulty, double fillRatio, int blockCount) {
    final int gridSize = gameSize + 1;

    // 1. 정답 패턴 생성 (어떤 셀에 정답 숫자가 있는지)
    // solution: 정답 숫자가 있는 셀만 값이 있고, 나머지는 0
    final solution = List.generate(
      gridSize,
      (row) => List.generate(gridSize, (col) => 0),
    );

    // cellTypes: 0 = 헤더, 1 = 정답 셀, 2 = 빈 셀 (틀린 숫자로 채워질)
    final cellTypes = List.generate(
      gridSize,
      (row) => List.generate(gridSize, (col) {
        if (row == 0 || col == 0) return 0; // 헤더
        return 1; // 일단 모두 입력 셀로
      }),
    );

    // 정답 셀 위치 결정 - 각 행과 열에 최소 1개의 정답 셀 보장
    final allCells = <(int, int)>[];
    for (int row = 1; row < gridSize; row++) {
      for (int col = 1; col < gridSize; col++) {
        allCells.add((row, col));
      }
    }

    // 먼저 각 행과 열에 최소 1개의 정답 셀 배치
    final correctCellsSet = <(int, int)>{};
    final rowHasCorrect = List<bool>.filled(gridSize, false);
    final colHasCorrect = List<bool>.filled(gridSize, false);

    // 각 행에 최소 1개
    for (int row = 1; row < gridSize; row++) {
      int col = _random.nextInt(gameSize) + 1;
      correctCellsSet.add((row, col));
      rowHasCorrect[row] = true;
      colHasCorrect[col] = true;
    }

    // 각 열에 최소 1개 (아직 없는 열만)
    for (int col = 1; col < gridSize; col++) {
      if (!colHasCorrect[col]) {
        int row = _random.nextInt(gameSize) + 1;
        correctCellsSet.add((row, col));
        colHasCorrect[col] = true;
      }
    }

    // 나머지 정답 셀 추가
    int correctCellCount = (allCells.length * fillRatio).round();
    correctCellCount = max(correctCellCount, correctCellsSet.length);

    final remainingCells = allCells.where((c) => !correctCellsSet.contains(c)).toList();
    remainingCells.shuffle(_random);

    int additionalCount = correctCellCount - correctCellsSet.length;
    for (int i = 0; i < additionalCount && i < remainingCells.length; i++) {
      correctCellsSet.add(remainingCells[i]);
    }

    final correctCells = correctCellsSet;
    final emptyCells = allCells.where((c) => !correctCells.contains(c)).toList();

    // 정답 셀에 1-9 숫자 배치 (행/열 내 중복 허용)
    for (final (row, col) in correctCells) {
      solution[row][col] = _random.nextInt(9) + 1;
    }

    // 2. 행/열 합계 계산 (정답 셀 숫자만)
    final rowSums = List<int>.filled(gridSize, 0);
    final colSums = List<int>.filled(gridSize, 0);

    for (int row = 1; row < gridSize; row++) {
      for (int col = 1; col < gridSize; col++) {
        rowSums[row] += solution[row][col];
        colSums[col] += solution[row][col];
      }
    }

    // 3. 퍼즐 보드 생성: 정답 복사 + 빈 셀에 틀린 숫자 채우기
    final puzzle = solution.map((row) => List<int>.from(row)).toList();
    final wrongCells = List.generate(
      gridSize,
      (_) => List.generate(gridSize, (_) => false),
    );

    // 모든 빈 셀에 틀린 숫자 채우기 (빈 칸이 없도록)
    for (final (row, col) in emptyCells) {
      // 틀린 숫자 생성 (1-9)
      puzzle[row][col] = _random.nextInt(9) + 1;
      wrongCells[row][col] = true;
    }

    // 4. 블록 생성 (연결된 셀들을 그룹화)
    final blockIds = List.generate(
      gridSize,
      (row) => List.generate(gridSize, (col) => -1),
    );
    final blockSums = <int>[]; // 각 블록의 정답 합계

    _generateBlocks(blockIds, solution, gridSize, blockCount, blockSums);

    return {
      'solution': solution,
      'puzzle': puzzle,
      'cellTypes': cellTypes,
      'wrongCells': wrongCells.map((row) => row.map((v) => v ? 1 : 0).toList()).toList(),
      'rowSums': rowSums,
      'colSums': colSums,
      'blockIds': blockIds,
      'blockSums': blockSums,
      'gridSize': gridSize,
      'gameSize': gameSize,
      'difficulty': difficulty.index,
    };
  }

  /// 블록 생성 (연결된 셀들을 그룹화)
  /// 각 블록은 최소 하나의 정답 셀을 포함하여 합이 0이 되지 않도록 함
  void _generateBlocks(
    List<List<int>> blockIds,
    List<List<int>> solution,
    int gridSize,
    int blockCount,
    List<int> blockSums,
  ) {
    // 정답 셀과 틀린 셀을 분리
    final correctCells = <(int, int)>[];
    final wrongCells = <(int, int)>[];

    for (int row = 1; row < gridSize; row++) {
      for (int col = 1; col < gridSize; col++) {
        if (solution[row][col] > 0) {
          correctCells.add((row, col));
        } else {
          wrongCells.add((row, col));
        }
      }
    }

    // 정답 셀을 섞음
    correctCells.shuffle(_random);

    // 블록 수가 정답 셀 수보다 많으면 조정
    final actualBlockCount = min(blockCount, correctCells.length);

    final totalCells = correctCells.length + wrongCells.length;
    final avgBlockSize = totalCells ~/ actualBlockCount;

    int currentBlockId = 0;
    final unassigned = <(int, int)>{...correctCells, ...wrongCells};

    // 각 블록은 정답 셀에서 시작
    while (currentBlockId < actualBlockCount && correctCells.isNotEmpty) {
      // 남은 블록 수
      int remainingBlocks = actualBlockCount - currentBlockId;

      // 이 블록의 크기 결정 (최소 4칸 이상)
      int blockSize;
      const int minBlockSize = 4;
      if (remainingBlocks == 1) {
        blockSize = unassigned.length;
      } else {
        // 평균 크기 주변에서 랜덤하게 (최소 4칸)
        int minSize = max(minBlockSize, avgBlockSize - 2);
        int maxSize = min(unassigned.length - (remainingBlocks - 1) * minBlockSize, avgBlockSize + 2);
        maxSize = max(maxSize, minSize);
        blockSize = minSize + _random.nextInt(maxSize - minSize + 1);
      }

      // 정답 셀에서 시작 (블록 합이 0이 되지 않도록)
      (int, int)? start;
      for (final cell in correctCells) {
        if (unassigned.contains(cell)) {
          start = cell;
          break;
        }
      }

      if (start == null) break;

      unassigned.remove(start);
      correctCells.remove(start);

      blockIds[start.$1][start.$2] = currentBlockId;
      final blockCells = [start];
      int blockSum = solution[start.$1][start.$2];

      // BFS로 인접 셀 추가
      while (blockCells.length < blockSize && unassigned.isNotEmpty) {
        // 현재 블록에 인접한 미할당 셀 찾기
        final adjacentCells = <(int, int)>[];
        for (final cell in blockCells) {
          final neighbors = [
            (cell.$1 - 1, cell.$2),
            (cell.$1 + 1, cell.$2),
            (cell.$1, cell.$2 - 1),
            (cell.$1, cell.$2 + 1),
          ];
          for (final neighbor in neighbors) {
            if (unassigned.contains(neighbor)) {
              adjacentCells.add(neighbor);
            }
          }
        }

        if (adjacentCells.isEmpty) break;

        // 인접 셀 중 하나 선택
        final nextCell = adjacentCells[_random.nextInt(adjacentCells.length)];
        unassigned.remove(nextCell);
        correctCells.remove(nextCell); // 정답 셀 목록에서도 제거
        blockIds[nextCell.$1][nextCell.$2] = currentBlockId;
        blockCells.add(nextCell);
        blockSum += solution[nextCell.$1][nextCell.$2];
      }

      blockSums.add(blockSum);
      currentBlockId++;
    }

    // 남은 셀이 있으면 인접한 블록에 할당 (반복적으로 처리)
    int maxIterations = unassigned.length * 2; // 무한 루프 방지
    int iterations = 0;

    while (unassigned.isNotEmpty && iterations < maxIterations) {
      iterations++;
      final cellsToProcess = unassigned.toList();

      for (final cell in cellsToProcess) {
        // 인접한 블록 찾기
        int? foundBlockId;
        final neighbors = [
          (cell.$1 - 1, cell.$2),
          (cell.$1 + 1, cell.$2),
          (cell.$1, cell.$2 - 1),
          (cell.$1, cell.$2 + 1),
        ];

        for (final neighbor in neighbors) {
          if (neighbor.$1 >= 1 && neighbor.$1 < gridSize &&
              neighbor.$2 >= 1 && neighbor.$2 < gridSize &&
              blockIds[neighbor.$1][neighbor.$2] >= 0) {
            foundBlockId = blockIds[neighbor.$1][neighbor.$2];
            break;
          }
        }

        // 인접한 블록을 찾았으면 할당
        if (foundBlockId != null) {
          unassigned.remove(cell);
          blockIds[cell.$1][cell.$2] = foundBlockId;
          blockSums[foundBlockId] += solution[cell.$1][cell.$2];
        }
      }
    }

    // 여전히 미할당 셀이 있으면 가장 가까운 블록에 강제 할당
    while (unassigned.isNotEmpty) {
      final cell = unassigned.first;
      unassigned.remove(cell);

      // 가장 가까운 할당된 셀 찾기
      int nearestBlockId = 0;
      int minDistance = 999999;

      for (int r = 1; r < gridSize; r++) {
        for (int c = 1; c < gridSize; c++) {
          if (blockIds[r][c] >= 0) {
            int distance = (cell.$1 - r).abs() + (cell.$2 - c).abs();
            if (distance < minDistance) {
              minDistance = distance;
              nearestBlockId = blockIds[r][c];
            }
          }
        }
      }

      blockIds[cell.$1][cell.$2] = nearestBlockId;
      blockSums[nearestBlockId] += solution[cell.$1][cell.$2];
    }

    // 5. 작은 블록(4칸 미만) 병합
    _mergeSmallBlocks(blockIds, solution, gridSize, blockSums);
  }

  /// 작은 블록을 인접 블록에 병합
  void _mergeSmallBlocks(
    List<List<int>> blockIds,
    List<List<int>> solution,
    int gridSize,
    List<int> blockSums,
  ) {
    const int minBlockSize = 4;

    // 각 블록의 셀 수 계산
    Map<int, int> blockCellCounts = {};
    for (int row = 1; row < gridSize; row++) {
      for (int col = 1; col < gridSize; col++) {
        int bid = blockIds[row][col];
        if (bid >= 0) {
          blockCellCounts[bid] = (blockCellCounts[bid] ?? 0) + 1;
        }
      }
    }

    // 작은 블록 찾기 및 병합
    bool merged = true;
    while (merged) {
      merged = false;

      for (int smallBlockId in blockCellCounts.keys.toList()) {
        if ((blockCellCounts[smallBlockId] ?? 0) < minBlockSize &&
            (blockCellCounts[smallBlockId] ?? 0) > 0) {
          // 이 블록의 셀들 찾기
          List<(int, int)> smallBlockCells = [];
          for (int row = 1; row < gridSize; row++) {
            for (int col = 1; col < gridSize; col++) {
              if (blockIds[row][col] == smallBlockId) {
                smallBlockCells.add((row, col));
              }
            }
          }

          // 인접한 다른 블록 찾기
          int? targetBlockId;
          for (final cell in smallBlockCells) {
            final neighbors = [
              (cell.$1 - 1, cell.$2),
              (cell.$1 + 1, cell.$2),
              (cell.$1, cell.$2 - 1),
              (cell.$1, cell.$2 + 1),
            ];
            for (final neighbor in neighbors) {
              if (neighbor.$1 >= 1 && neighbor.$1 < gridSize &&
                  neighbor.$2 >= 1 && neighbor.$2 < gridSize) {
                int neighborBlockId = blockIds[neighbor.$1][neighbor.$2];
                if (neighborBlockId >= 0 && neighborBlockId != smallBlockId) {
                  targetBlockId = neighborBlockId;
                  break;
                }
              }
            }
            if (targetBlockId != null) break;
          }

          // 병합 실행
          if (targetBlockId != null) {
            for (final cell in smallBlockCells) {
              blockIds[cell.$1][cell.$2] = targetBlockId;
            }
            // 합계 이동
            blockSums[targetBlockId] += blockSums[smallBlockId];
            blockSums[smallBlockId] = 0;
            // 카운트 업데이트
            blockCellCounts[targetBlockId] =
                (blockCellCounts[targetBlockId] ?? 0) + smallBlockCells.length;
            blockCellCounts[smallBlockId] = 0;
            merged = true;
          }
        }
      }
    }
  }

  /// 보드가 완성되었는지 확인 (모든 틀린 숫자가 제거됨)
  static bool isBoardComplete(
    List<List<int>> currentBoard,
    List<List<int>> solution,
    int gridSize,
  ) {
    for (int row = 1; row < gridSize; row++) {
      for (int col = 1; col < gridSize; col++) {
        if (currentBoard[row][col] != solution[row][col]) {
          return false;
        }
      }
    }
    return true;
  }
}
