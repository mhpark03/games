import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/number_sums_game_state.dart';
import '../models/number_sums_generator.dart';

class GameStorage {
  static const String _numberSumsGameKey = 'number_sums_game_state';

  /// 넘버 썸즈 게임 저장
  static Future<void> saveNumberSumsGame(NumberSumsGameState gameState) async {
    final prefs = await SharedPreferences.getInstance();
    final json = _numberSumsGameStateToJson(gameState);
    await prefs.setString(_numberSumsGameKey, jsonEncode(json));
  }

  /// 넘버 썸즈 게임 불러오기
  static Future<NumberSumsGameState?> loadNumberSumsGame() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_numberSumsGameKey);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return _numberSumsGameStateFromJson(json);
    } catch (e) {
      await prefs.remove(_numberSumsGameKey);
      return null;
    }
  }

  /// 넘버 썸즈 게임 삭제
  static Future<void> deleteNumberSumsGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_numberSumsGameKey);
  }

  /// 저장된 게임이 있는지 확인
  static Future<bool> hasNumberSumsGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_numberSumsGameKey);
  }

  // ========== NumberSumsGameState 직렬화 ==========

  static Map<String, dynamic> _numberSumsGameStateToJson(NumberSumsGameState state) {
    return {
      'solution': state.solution,
      'puzzle': state.puzzle,
      'currentBoard': state.currentBoard,
      'cellTypes': state.cellTypes,
      'wrongCells': state.wrongCells.map((row) => row.map((v) => v ? 1 : 0).toList()).toList(),
      'markedCorrectCells': state.markedCorrectCells.map((row) => row.map((v) => v ? 1 : 0).toList()).toList(),
      'rowSums': state.rowSums,
      'colSums': state.colSums,
      'blockIds': state.blockIds,
      'blockSums': state.blockSums,
      'gridSize': state.gridSize,
      'gameSize': state.gameSize,
      'difficulty': state.difficulty.index,
      'mistakes': state.mistakes,
      'isCompleted': state.isCompleted,
      'elapsedSeconds': state.elapsedSeconds,
      'failureCount': state.failureCount,
    };
  }

  static NumberSumsGameState _numberSumsGameStateFromJson(Map<String, dynamic> json) {
    final gridSize = json['gridSize'] as int;
    final gameSize = (json['gameSize'] as int?) ?? (gridSize - 1);
    final solution = (json['solution'] as List)
        .map((row) => (row as List).map((e) => e as int).toList())
        .toList();
    final puzzle = (json['puzzle'] as List)
        .map((row) => (row as List).map((e) => e as int).toList())
        .toList();
    final currentBoard = (json['currentBoard'] as List)
        .map((row) => (row as List).map((e) => e as int).toList())
        .toList();
    final cellTypes = (json['cellTypes'] as List)
        .map((row) => (row as List).map((e) => e as int).toList())
        .toList();
    final wrongCellsData = json['wrongCells'] as List?;
    final wrongCells = wrongCellsData != null
        ? (wrongCellsData as List)
            .map((row) => (row as List).map((v) => v == 1).toList())
            .toList()
        : List.generate(gridSize, (_) => List.filled(gridSize, false));
    final markedCorrectCellsData = json['markedCorrectCells'] as List?;
    final markedCorrectCells = markedCorrectCellsData != null
        ? (markedCorrectCellsData as List)
            .map((row) => (row as List).map((v) => v == 1).toList())
            .toList()
        : List.generate(gridSize, (_) => List.filled(gridSize, false));
    final rowSums = List<int>.from((json['rowSums'] as List?) ?? List.filled(gridSize, 0));
    final colSums = List<int>.from((json['colSums'] as List?) ?? List.filled(gridSize, 0));
    final blockIdsData = json['blockIds'] as List?;
    final blockIds = blockIdsData != null
        ? (blockIdsData as List)
            .map((row) => (row as List).map((e) => e as int).toList())
            .toList()
        : List.generate(gridSize, (_) => List.filled(gridSize, 0));
    final blockSums = List<int>.from((json['blockSums'] as List?) ?? <int>[]);

    return NumberSumsGameState(
      solution: solution,
      puzzle: puzzle,
      currentBoard: currentBoard,
      cellTypes: cellTypes,
      wrongCells: wrongCells,
      markedCorrectCells: markedCorrectCells,
      rowSums: rowSums,
      colSums: colSums,
      blockIds: blockIds,
      blockSums: blockSums,
      gridSize: gridSize,
      gameSize: gameSize,
      difficulty: NumberSumsDifficulty.values[json['difficulty'] as int],
      mistakes: json['mistakes'] as int,
      isCompleted: json['isCompleted'] as bool,
      elapsedSeconds: (json['elapsedSeconds'] as int?) ?? 0,
      failureCount: (json['failureCount'] as int?) ?? 0,
    );
  }
}
