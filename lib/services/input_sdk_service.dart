import 'package:flutter/services.dart';

/// Google Play Games for PC Input SDK 서비스
/// PC 환경에서 키보드/마우스 매핑 UI를 제공합니다.
class InputSdkService {
  static const _channel = MethodChannel('com.mhpark.gamecenter/input_sdk');

  /// PC용 Google Play Games 환경인지 확인
  static Future<bool> isGooglePlayGamesOnPC() async {
    try {
      final result = await _channel.invokeMethod<bool>('isGooglePlayGamesOnPC');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Input Mapping 초기화 (앱 시작 시 호출)
  static Future<void> init() async {
    try {
      await _channel.invokeMethod('initInputMapping');
    } on PlatformException catch (e) {
      // PC가 아닌 환경에서는 무시
      print('Input SDK 초기화 실패 (PC 환경 아님): ${e.message}');
    }
  }

  /// 메뉴 컨텍스트로 설정 (홈 화면, 게임 선택 등)
  static Future<void> setMenuContext() async {
    await _setContext('menu');
  }

  /// 보드 게임 컨텍스트로 설정 (오목, 오델로, 체스, 장기 등)
  static Future<void> setBoardGameContext() async {
    await _setContext('board');
  }

  /// 퍼즐 게임 컨텍스트로 설정 (스도쿠, 숫자야구, 지뢰찾기 등)
  static Future<void> setPuzzleGameContext() async {
    await _setContext('puzzle');
  }

  /// 액션 게임 컨텍스트로 설정 (테트리스, 두더지잡기, 버블슈터 등)
  static Future<void> setActionGameContext() async {
    await _setContext('action');
  }

  /// 게임 타입에 따라 자동으로 적절한 컨텍스트 설정
  static Future<void> setContextForGame(String gameName) async {
    final context = _getContextForGame(gameName);
    await _setContext(context);
  }

  static String _getContextForGame(String gameName) {
    switch (gameName.toLowerCase()) {
      // 보드 게임
      case 'gomoku':
      case 'othello':
      case 'chess':
      case 'janggi':
      case 'yutnori':
      case 'onecard':
      case 'hula':
      case 'solitaire':
        return 'board';

      // 퍼즐 게임
      case 'sudoku':
      case 'samurai_sudoku':
      case 'killer_sudoku':
      case 'baseball':
      case 'minesweeper':
      case 'number_sums':
      case 'maze':
        return 'puzzle';

      // 액션 게임
      case 'tetris':
      case 'mole':
      case 'bubble':
        return 'action';

      default:
        return 'menu';
    }
  }

  static Future<void> _setContext(String contextName) async {
    try {
      await _channel.invokeMethod('setInputContext', {'context': contextName});
    } on PlatformException {
      // PC가 아닌 환경에서는 무시
    }
  }

  /// Input Mapping 정리 (앱 종료 시)
  static Future<void> clear() async {
    try {
      await _channel.invokeMethod('clearInputMapping');
    } on PlatformException {
      // 무시
    }
  }
}

/// 게임 타입 enum
enum GameInputContext {
  menu,
  board,
  puzzle,
  action,
}
