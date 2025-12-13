import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  final String apiKey;

  GeminiService(this.apiKey);

  /// 장기 보드 상태를 문자열로 변환
  static String boardToString(List<List<dynamic>> board) {
    final buffer = StringBuffer();
    buffer.writeln('  0 1 2 3 4 5 6 7 8');
    buffer.writeln('  -----------------');

    for (int row = 0; row < 10; row++) {
      buffer.write('$row|');
      for (int col = 0; col < 9; col++) {
        final piece = board[row][col];
        if (piece == null) {
          buffer.write('. ');
        } else {
          String symbol = _getPieceSymbol(piece);
          buffer.write('$symbol ');
        }
      }
      buffer.writeln('|');
    }
    buffer.writeln('  -----------------');
    return buffer.toString();
  }

  static String _getPieceSymbol(dynamic piece) {
    // JanggiPiece 객체에서 타입과 색상 추출
    final type = piece.type.toString().split('.').last;
    final isHan = piece.color.toString().contains('han');

    String symbol;
    switch (type) {
      case 'gung':
        symbol = isHan ? 'H궁' : 'C궁';
        break;
      case 'cha':
        symbol = isHan ? 'H차' : 'C차';
        break;
      case 'po':
        symbol = isHan ? 'H포' : 'C포';
        break;
      case 'ma':
        symbol = isHan ? 'H마' : 'C마';
        break;
      case 'sang':
        symbol = isHan ? 'H상' : 'C상';
        break;
      case 'sa':
        symbol = isHan ? 'H사' : 'C사';
        break;
      case 'byung':
        symbol = isHan ? 'H졸' : 'C병';
        break;
      default:
        symbol = '??';
    }
    return symbol;
  }

  /// Gemini에게 최선의 수를 요청
  Future<Map<String, int>?> getBestMove({
    required List<List<dynamic>> board,
    required String currentPlayer, // 'cho' or 'han'
    required List<Map<String, dynamic>> legalMoves,
  }) async {
    if (apiKey.isEmpty) {
      return null;
    }

    final boardStr = boardToString(board);
    final movesStr = legalMoves.map((m) {
      return '(${m['fromRow']},${m['fromCol']})->(${m['toRow']},${m['toCol']})';
    }).join(', ');

    final prompt = '''
당신은 한국 장기(Janggi) 전문가입니다. 현재 게임 상황을 분석하고 최선의 수를 선택하세요.

## 장기 규칙 요약
- 궁(왕): 궁성 내에서만 이동, 가장 중요한 말
- 차: 가로/세로 무제한 이동
- 포: 가로/세로로 다른 말 하나를 뛰어넘어 이동/공격 (포는 포를 뛰어넘을 수 없음)
- 마: ㄱ자로 이동 (첫 번째 칸에 말이 있으면 막힘)
- 상: 대각선으로 田자 이동 (중간에 말이 있으면 막힘)
- 사: 궁성 내에서 한 칸 이동
- 졸/병: 앞, 좌, 우로 한 칸 이동

## 현재 보드 상태 (H=한, C=초)
$boardStr

## 현재 턴: ${currentPlayer == 'cho' ? '초(C)' : '한(H)'}

## 가능한 수 목록:
$movesStr

## 전략 우선순위
1. 궁을 잡을 수 있으면 반드시 잡기
2. 장군(체크)을 걸 수 있으면 우선
3. 상대의 가치 높은 말 잡기 (차 > 포 > 마/상 > 사 > 졸)
4. 자신의 말을 보호하면서 공격적 위치로 이동
5. 중앙 통제와 진영 진출

## 응답 형식 (반드시 이 형식으로만 응답)
MOVE:fromRow,fromCol,toRow,toCol

예시: MOVE:7,1,5,2
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 100,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';

        // MOVE:fromRow,fromCol,toRow,toCol 파싱
        final regex = RegExp(r'MOVE:\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)');
        final match = regex.firstMatch(text);

        if (match != null) {
          final fromRow = int.parse(match.group(1)!);
          final fromCol = int.parse(match.group(2)!);
          final toRow = int.parse(match.group(3)!);
          final toCol = int.parse(match.group(4)!);

          // 유효한 수인지 확인
          final isValid = legalMoves.any((m) =>
              m['fromRow'] == fromRow &&
              m['fromCol'] == fromCol &&
              m['toRow'] == toRow &&
              m['toCol'] == toCol);

          if (isValid) {
            return {
              'fromRow': fromRow,
              'fromCol': fromCol,
              'toRow': toRow,
              'toCol': toCol,
            };
          }
        }
      }
    } catch (e) {
      // API 오류 시 null 반환 (로컬 AI 사용)
    }

    return null;
  }
}
