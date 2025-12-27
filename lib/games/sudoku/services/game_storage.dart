import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_state.dart';
import '../models/samurai_game_state.dart';
import '../models/killer_game_state.dart';
import '../models/killer_cage.dart';
import '../models/killer_sudoku_generator.dart';

class GameStorage {
  static const String _regularGameKey = 'regular_game_state';
  static const String _samuraiGameKey = 'samurai_game_state';
  static const String _killerGameKey = 'killer_game_state';

  /// 일반 스도쿠 게임 저장
  static Future<void> saveRegularGame(GameState gameState) async {
    final prefs = await SharedPreferences.getInstance();
    final json = _gameStateToJson(gameState);
    await prefs.setString(_regularGameKey, jsonEncode(json));
  }

  /// 일반 스도쿠 게임 불러오기
  static Future<GameState?> loadRegularGame() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_regularGameKey);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return _gameStateFromJson(json);
    } catch (e) {
      // 파싱 실패 시 저장된 데이터 삭제
      await prefs.remove(_regularGameKey);
      return null;
    }
  }

  /// 일반 스도쿠 게임 삭제
  static Future<void> deleteRegularGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_regularGameKey);
  }

  /// 사무라이 스도쿠 게임 저장
  static Future<void> saveSamuraiGame(SamuraiGameState gameState) async {
    final prefs = await SharedPreferences.getInstance();
    final json = _samuraiGameStateToJson(gameState);
    await prefs.setString(_samuraiGameKey, jsonEncode(json));
  }

  /// 사무라이 스도쿠 게임 불러오기
  static Future<SamuraiGameState?> loadSamuraiGame() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_samuraiGameKey);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return _samuraiGameStateFromJson(json);
    } catch (e) {
      // 파싱 실패 시 저장된 데이터 삭제
      await prefs.remove(_samuraiGameKey);
      return null;
    }
  }

  /// 사무라이 스도쿠 게임 삭제
  static Future<void> deleteSamuraiGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_samuraiGameKey);
  }

  /// 킬러 스도쿠 게임 저장
  static Future<void> saveKillerGame(KillerGameState gameState) async {
    final prefs = await SharedPreferences.getInstance();
    final json = _killerGameStateToJson(gameState);
    await prefs.setString(_killerGameKey, jsonEncode(json));
  }

  /// 킬러 스도쿠 게임 불러오기
  static Future<KillerGameState?> loadKillerGame() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_killerGameKey);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return _killerGameStateFromJson(json);
    } catch (e) {
      await prefs.remove(_killerGameKey);
      return null;
    }
  }

  /// 킬러 스도쿠 게임 삭제
  static Future<void> deleteKillerGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_killerGameKey);
  }

  /// 모든 저장된 게임 삭제
  static Future<void> deleteAllGames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_regularGameKey);
    await prefs.remove(_samuraiGameKey);
    await prefs.remove(_killerGameKey);
  }

  /// 저장된 게임이 있는지 확인
  static Future<bool> hasRegularGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_regularGameKey);
  }

  static Future<bool> hasSamuraiGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_samuraiGameKey);
  }

  static Future<bool> hasKillerGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_killerGameKey);
  }

  // ========== GameState 직렬화 ==========

  static Map<String, dynamic> _gameStateToJson(GameState state) {
    return {
      'solution': state.solution,
      'puzzle': state.puzzle,
      'currentBoard': state.currentBoard,
      'isFixed': state.isFixed,
      'notes': state.notes
          .map((row) => row.map((set) => set.toList()).toList())
          .toList(),
      'difficulty': state.difficulty.index,
      'mistakes': state.mistakes,
      'isCompleted': state.isCompleted,
      'elapsedSeconds': state.elapsedSeconds,
      'failureCount': state.failureCount,
    };
  }

  static GameState _gameStateFromJson(Map<String, dynamic> json) {
    final solution = (json['solution'] as List)
        .map((row) => (row as List).map((e) => e as int).toList())
        .toList();
    final puzzle = (json['puzzle'] as List)
        .map((row) => (row as List).map((e) => e as int).toList())
        .toList();
    final currentBoard = (json['currentBoard'] as List)
        .map((row) => (row as List).map((e) => e as int).toList())
        .toList();
    final isFixed = (json['isFixed'] as List)
        .map((row) => (row as List).map((e) => e as bool).toList())
        .toList();
    final notes = (json['notes'] as List)
        .map((row) => (row as List)
            .map((set) => (set as List).map((e) => e as int).toSet())
            .toList())
        .toList();

    return GameState(
      solution: solution,
      puzzle: puzzle,
      currentBoard: currentBoard,
      isFixed: isFixed,
      notes: notes,
      difficulty: Difficulty.values[json['difficulty'] as int],
      mistakes: json['mistakes'] as int,
      isCompleted: json['isCompleted'] as bool,
      elapsedSeconds: (json['elapsedSeconds'] as int?) ?? 0,
      failureCount: (json['failureCount'] as int?) ?? 0,
    );
  }

  // ========== SamuraiGameState 직렬화 ==========

  static Map<String, dynamic> _samuraiGameStateToJson(SamuraiGameState state) {
    return {
      'solutions': state.solutions,
      'puzzles': state.puzzles,
      'currentBoards': state.currentBoards,
      'isFixed': state.isFixed,
      'notes': state.notes
          .map((board) => board
              .map((row) => row.map((set) => set.toList()).toList())
              .toList())
          .toList(),
      'difficulty': state.difficulty.index,
      'selectedBoard': state.selectedBoard,
      'isCompleted': state.isCompleted,
      'elapsedSeconds': state.elapsedSeconds,
      'failureCount': state.failureCount,
    };
  }

  static SamuraiGameState _samuraiGameStateFromJson(Map<String, dynamic> json) {
    final solutions = (json['solutions'] as List)
        .map((board) => (board as List)
            .map((row) => (row as List).map((e) => e as int).toList())
            .toList())
        .toList();
    final puzzles = (json['puzzles'] as List)
        .map((board) => (board as List)
            .map((row) => (row as List).map((e) => e as int).toList())
            .toList())
        .toList();
    final currentBoards = (json['currentBoards'] as List)
        .map((board) => (board as List)
            .map((row) => (row as List).map((e) => e as int).toList())
            .toList())
        .toList();
    final isFixed = (json['isFixed'] as List)
        .map((board) => (board as List)
            .map((row) => (row as List).map((e) => e as bool).toList())
            .toList())
        .toList();
    final notes = (json['notes'] as List)
        .map((board) => (board as List)
            .map((row) => (row as List)
                .map((set) => (set as List).map((e) => e as int).toSet())
                .toList())
            .toList())
        .toList();

    return SamuraiGameState(
      solutions: solutions,
      puzzles: puzzles,
      currentBoards: currentBoards,
      isFixed: isFixed,
      notes: notes,
      difficulty: SamuraiDifficulty.values[json['difficulty'] as int],
      selectedBoard: json['selectedBoard'] as int,
      isCompleted: json['isCompleted'] as bool,
      elapsedSeconds: (json['elapsedSeconds'] as int?) ?? 0,
      failureCount: (json['failureCount'] as int?) ?? 0,
    );
  }

  // ========== KillerGameState 직렬화 ==========

  static Map<String, dynamic> _killerGameStateToJson(KillerGameState state) {
    return {
      'solution': state.solution,
      'puzzle': state.puzzle,
      'currentBoard': state.currentBoard,
      'isFixed': state.isFixed,
      'notes': state.notes
          .map((row) => row.map((set) => set.toList()).toList())
          .toList(),
      'cages': state.cages.map((c) => c.toJson()).toList(),
      'difficulty': state.difficulty.index,
      'mistakes': state.mistakes,
      'isCompleted': state.isCompleted,
      'elapsedSeconds': state.elapsedSeconds,
      'failureCount': state.failureCount,
    };
  }

  static KillerGameState _killerGameStateFromJson(Map<String, dynamic> json) {
    final solution = (json['solution'] as List)
        .map((row) => (row as List).map((e) => e as int).toList())
        .toList();
    final puzzle = (json['puzzle'] as List)
        .map((row) => (row as List).map((e) => e as int).toList())
        .toList();
    final currentBoard = (json['currentBoard'] as List)
        .map((row) => (row as List).map((e) => e as int).toList())
        .toList();
    final isFixed = (json['isFixed'] as List)
        .map((row) => (row as List).map((e) => e as bool).toList())
        .toList();
    final notes = (json['notes'] as List)
        .map((row) => (row as List)
            .map((set) => (set as List).map((e) => e as int).toSet())
            .toList())
        .toList();
    final cages = (json['cages'] as List)
        .map((c) => KillerCage.fromJson(c as Map<String, dynamic>))
        .toList();

    return KillerGameState(
      solution: solution,
      puzzle: puzzle,
      currentBoard: currentBoard,
      isFixed: isFixed,
      notes: notes,
      cages: cages,
      difficulty: KillerDifficulty.values[json['difficulty'] as int],
      mistakes: json['mistakes'] as int,
      isCompleted: json['isCompleted'] as bool,
      elapsedSeconds: (json['elapsedSeconds'] as int?) ?? 0,
      failureCount: (json['failureCount'] as int?) ?? 0,
    );
  }
}
