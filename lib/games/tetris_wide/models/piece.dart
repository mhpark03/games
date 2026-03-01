import 'package:flutter/material.dart';

enum PieceType { I, O, T, S, Z, J, L }

class Piece {
  PieceType type;
  int rotationState;
  int x;
  int y;

  Piece({
    required this.type,
    this.rotationState = 0,
    this.x = 8,
    this.y = 0,
  });

  /// 초기 채움 블록 색 (중립 회청색)
  static const Color blockColor = Color(0xFF546E7A);

  /// 블록 타입별 고유 색 (테트리스 표준)
  static const Map<PieceType, Color> typeColors = {
    PieceType.I: Color(0xFF00BCD4), // 청록
    PieceType.O: Color(0xFFFFD600), // 노랑
    PieceType.T: Color(0xFF9C27B0), // 보라
    PieceType.S: Color(0xFF43A047), // 초록
    PieceType.Z: Color(0xFFE53935), // 빨강
    PieceType.J: Color(0xFF1E88E5), // 파랑
    PieceType.L: Color(0xFFFF7043), // 주황
  };

  /// 신규 배치 직후 밝은 색 (구분용)
  static const Map<PieceType, Color> typeNewColors = {
    PieceType.I: Color(0xFF80DEEA),
    PieceType.O: Color(0xFFFFF176),
    PieceType.T: Color(0xFFCE93D8),
    PieceType.S: Color(0xFFA5D6A7),
    PieceType.Z: Color(0xFFEF9A9A),
    PieceType.J: Color(0xFF90CAF9),
    PieceType.L: Color(0xFFFFAB91),
  };

  /// newColor → typeColor 매핑 (정규화용)
  static final Map<Color, Color> _newToNormal = Map.fromEntries(
    typeNewColors.entries.map((e) => MapEntry(e.value, typeColors[e.key]!)),
  );

  static bool isNewColor(Color? color) =>
      color != null && _newToNormal.containsKey(color);

  static Color normalizeColor(Color color) => _newToNormal[color] ?? color;

  Color get color => typeColors[type]!;
  Color get newColor => typeNewColors[type]!;

  List<List<int>> get shape {
    switch (type) {
      case PieceType.I:
        return _iShapes[rotationState % 4];
      case PieceType.O:
        return _oShapes[0];
      case PieceType.T:
        return _tShapes[rotationState % 4];
      case PieceType.S:
        return _sShapes[rotationState % 4];
      case PieceType.Z:
        return _zShapes[rotationState % 4];
      case PieceType.J:
        return _jShapes[rotationState % 4];
      case PieceType.L:
        return _lShapes[rotationState % 4];
    }
  }

  List<List<int>> get cells {
    List<List<int>> result = [];
    for (int row = 0; row < shape.length; row++) {
      for (int col = 0; col < shape[row].length; col++) {
        if (shape[row][col] == 1) {
          result.add([y + row, x + col]);
        }
      }
    }
    return result;
  }

  Piece copy() {
    return Piece(
      type: type,
      rotationState: rotationState,
      x: x,
      y: y,
    );
  }

  void rotate() {
    rotationState = (rotationState + 1) % 4;
  }

  void rotateBack() {
    rotationState = (rotationState - 1) % 4;
    if (rotationState < 0) rotationState = 3;
  }

  static const List<List<List<int>>> _iShapes = [
    [[0, 0, 0, 0], [1, 1, 1, 1], [0, 0, 0, 0], [0, 0, 0, 0]],
    [[0, 0, 1, 0], [0, 0, 1, 0], [0, 0, 1, 0], [0, 0, 1, 0]],
    [[0, 0, 0, 0], [0, 0, 0, 0], [1, 1, 1, 1], [0, 0, 0, 0]],
    [[0, 1, 0, 0], [0, 1, 0, 0], [0, 1, 0, 0], [0, 1, 0, 0]],
  ];

  static const List<List<List<int>>> _oShapes = [
    [[1, 1], [1, 1]],
  ];

  static const List<List<List<int>>> _tShapes = [
    [[0, 1, 0], [1, 1, 1], [0, 0, 0]],
    [[0, 1, 0], [0, 1, 1], [0, 1, 0]],
    [[0, 0, 0], [1, 1, 1], [0, 1, 0]],
    [[0, 1, 0], [1, 1, 0], [0, 1, 0]],
  ];

  static const List<List<List<int>>> _sShapes = [
    [[0, 1, 1], [1, 1, 0], [0, 0, 0]],
    [[0, 1, 0], [0, 1, 1], [0, 0, 1]],
    [[0, 0, 0], [0, 1, 1], [1, 1, 0]],
    [[1, 0, 0], [1, 1, 0], [0, 1, 0]],
  ];

  static const List<List<List<int>>> _zShapes = [
    [[1, 1, 0], [0, 1, 1], [0, 0, 0]],
    [[0, 0, 1], [0, 1, 1], [0, 1, 0]],
    [[0, 0, 0], [1, 1, 0], [0, 1, 1]],
    [[0, 1, 0], [1, 1, 0], [1, 0, 0]],
  ];

  static const List<List<List<int>>> _jShapes = [
    [[1, 0, 0], [1, 1, 1], [0, 0, 0]],
    [[0, 1, 1], [0, 1, 0], [0, 1, 0]],
    [[0, 0, 0], [1, 1, 1], [0, 0, 1]],
    [[0, 1, 0], [0, 1, 0], [1, 1, 0]],
  ];

  static const List<List<List<int>>> _lShapes = [
    [[0, 0, 1], [1, 1, 1], [0, 0, 0]],
    [[0, 1, 0], [0, 1, 0], [0, 1, 1]],
    [[0, 0, 0], [1, 1, 1], [1, 0, 0]],
    [[1, 1, 0], [0, 1, 0], [0, 1, 0]],
  ];
}
