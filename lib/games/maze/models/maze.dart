import 'dart:math';

enum CellType { wall, path, start, end, player }

class Position {
  final int row;
  final int col;

  const Position(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is Position && other.row == row && other.col == col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  Position operator +(Position other) => Position(row + other.row, col + other.col);
}

class Maze {
  final int rows;
  final int cols;
  late List<List<CellType>> grid;
  late Position startPos;
  late Position endPos;
  late Position playerPos;
  final Set<Position> visitedPath = {};  // 지나온 경로 저장

  Maze({required this.rows, required this.cols}) {
    _generateMaze();
  }

  void _generateMaze() {
    // Initialize all cells as walls
    grid = List.generate(rows, (_) => List.filled(cols, CellType.wall));

    final random = Random();

    // Start from (1, 1)
    _carve(1, 1, random);

    // Set start position (top-left area)
    startPos = const Position(1, 1);
    grid[startPos.row][startPos.col] = CellType.start;

    // Set end position (bottom-right area)
    endPos = Position(rows - 2, cols - 2);
    // Ensure end position is accessible
    _ensurePathToEnd();
    grid[endPos.row][endPos.col] = CellType.end;

    // Set player at start
    playerPos = startPos;
  }

  void _carve(int row, int col, Random random) {
    grid[row][col] = CellType.path;

    // Directions: up, right, down, left (moving by 2 cells)
    final directions = [
      const Position(-2, 0),
      const Position(0, 2),
      const Position(2, 0),
      const Position(0, -2),
    ];

    directions.shuffle(random);

    for (final dir in directions) {
      final newRow = row + dir.row;
      final newCol = col + dir.col;

      if (_isValidCell(newRow, newCol) && grid[newRow][newCol] == CellType.wall) {
        // Carve the wall between current cell and new cell
        grid[row + dir.row ~/ 2][col + dir.col ~/ 2] = CellType.path;
        _carve(newRow, newCol, random);
      }
    }
  }

  void _ensurePathToEnd() {
    // Make sure the end position and surrounding cells are accessible
    if (grid[endPos.row][endPos.col] == CellType.wall) {
      grid[endPos.row][endPos.col] = CellType.path;
    }
    // Connect to nearest path if isolated
    final directions = [
      const Position(-1, 0),
      const Position(0, -1),
      const Position(1, 0),
      const Position(0, 1),
    ];

    bool hasPath = false;
    for (final dir in directions) {
      final checkRow = endPos.row + dir.row;
      final checkCol = endPos.col + dir.col;
      if (_isInBounds(checkRow, checkCol) &&
          grid[checkRow][checkCol] == CellType.path) {
        hasPath = true;
        break;
      }
    }

    if (!hasPath) {
      // Create a path connection
      if (endPos.row > 1) {
        grid[endPos.row - 1][endPos.col] = CellType.path;
      }
      if (endPos.col > 1) {
        grid[endPos.row][endPos.col - 1] = CellType.path;
      }
    }
  }

  bool _isValidCell(int row, int col) {
    return row > 0 && row < rows - 1 && col > 0 && col < cols - 1;
  }

  bool _isInBounds(int row, int col) {
    return row >= 0 && row < rows && col >= 0 && col < cols;
  }

  bool canMoveTo(Position pos) {
    if (!_isInBounds(pos.row, pos.col)) return false;
    final cell = grid[pos.row][pos.col];
    return cell != CellType.wall;
  }

  bool movePlayer(Position direction) {
    final newPos = playerPos + direction;
    if (canMoveTo(newPos)) {
      visitedPath.add(playerPos);  // 현재 위치를 지나온 경로에 추가
      playerPos = newPos;
      return true;
    }
    return false;
  }

  bool get isGameWon => playerPos == endPos;

  CellType getCell(int row, int col) {
    if (row == playerPos.row && col == playerPos.col) {
      return CellType.player;
    }
    return grid[row][col];
  }

  void reset() {
    playerPos = startPos;
    visitedPath.clear();  // 경로 초기화
  }

  void regenerate() {
    _generateMaze();
    visitedPath.clear();  // 경로 초기화
  }
}
