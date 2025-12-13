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
    this.x = 3,
    this.y = 0,
  });

  Color get color {
    switch (type) {
      case PieceType.I:
        return Colors.cyan;
      case PieceType.O:
        return Colors.yellow;
      case PieceType.T:
        return Colors.purple;
      case PieceType.S:
        return Colors.green;
      case PieceType.Z:
        return Colors.red;
      case PieceType.J:
        return Colors.blue;
      case PieceType.L:
        return Colors.orange;
    }
  }

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
