import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 게임 저장 관리 서비스
/// 메모리 효율을 위해 최근 하나의 게임만 저장
class GameSaveService {
  static const String _saveKey = 'game_save';
  static const String _gameTypeKey = 'game_save_type';

  /// 저장된 게임 타입 확인
  static Future<String?> getSavedGameType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_gameTypeKey);
  }

  /// 저장된 게임 데이터 가져오기
  static Future<Map<String, dynamic>?> loadGame(String gameType) async {
    final prefs = await SharedPreferences.getInstance();
    final savedType = prefs.getString(_gameTypeKey);

    // 저장된 게임 타입이 다르면 null 반환
    if (savedType != gameType) {
      return null;
    }

    final savedData = prefs.getString(_saveKey);
    if (savedData != null) {
      try {
        return jsonDecode(savedData) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// 게임 저장 (기존 저장 덮어쓰기)
  static Future<void> saveGame(String gameType, Map<String, dynamic> gameState) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gameTypeKey, gameType);
    await prefs.setString(_saveKey, jsonEncode(gameState));
  }

  /// 저장된 게임 삭제
  static Future<void> clearSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
    await prefs.remove(_gameTypeKey);
  }

  /// 특정 게임 타입의 저장 확인
  static Future<bool> hasSavedGame(String gameType) async {
    final savedType = await getSavedGameType();
    return savedType == gameType;
  }
}
