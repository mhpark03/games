/// Represents a cage in Killer Sudoku
class KillerCage {
  /// List of cell positions in the cage as [row, col] pairs
  final List<List<int>> cells;

  /// Target sum for this cage
  final int targetSum;

  /// Unique identifier for the cage
  final int cageId;

  KillerCage({
    required this.cells,
    required this.targetSum,
    required this.cageId,
  });

  /// Number of cells in the cage
  int get size => cells.length;

  /// Check if a cell is in this cage
  bool containsCell(int row, int col) {
    return cells.any((cell) => cell[0] == row && cell[1] == col);
  }

  /// Get the position of the cell that should display the sum (top-left most)
  List<int> get sumDisplayCell {
    return cells.reduce((a, b) {
      if (a[0] < b[0]) return a;
      if (a[0] == b[0] && a[1] < b[1]) return a;
      return b;
    });
  }

  /// JSON serialization
  Map<String, dynamic> toJson() => {
        'cells': cells,
        'targetSum': targetSum,
        'cageId': cageId,
      };

  factory KillerCage.fromJson(Map<String, dynamic> json) => KillerCage(
        cells: (json['cells'] as List)
            .map((c) => List<int>.from(c as List))
            .toList(),
        targetSum: json['targetSum'] as int,
        cageId: json['cageId'] as int,
      );
}
