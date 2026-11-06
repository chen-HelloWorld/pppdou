import 'dart:ui';

class BeadColor {
  const BeadColor({required this.id, required this.name, required this.rgb});

  final String id;
  final String name;
  final Color rgb;

  String get hex => '#${rgb.value.toRadixString(16).substring(2).toUpperCase()}';

  factory BeadColor.fromJson(Map<String, dynamic> json) {
    final values = (json['rgb'] as List).cast<int>();
    const prototypeNames = {
      'B2': '深棕',
      'H7': '深棕',
      'H12': '奶白',
      'D17': '咖啡',
      'C6': '粉色',
      'F1': '浅粉',
      'H3': '深灰',
      'H6': '黑色',
      'G2': '米色',
      'G1': '肉色',
      'C7': '深灰蓝',
      'M9': '棕色',
      'H2': '浅灰',
    };
    final id = json['id'] as String;
    return BeadColor(
      id: id,
      name: prototypeNames[id] ?? (json['name'] as String?) ?? id,
      rgb: Color.fromARGB(255, values[0], values[1], values[2]),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rgb': [rgb.red, rgb.green, rgb.blue],
        'hex': hex,
      };
}

class BeadProject {
  static const emptyCell = '__empty__';
  BeadProject({
    required this.name,
    required this.rows,
    required this.columns,
    required this.cells,
    required this.sourcePath,
    this.lowConfidenceCells = const <int>{},
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String name;
  final int rows;
  final int columns;
  final List<String> cells;
  final String sourcePath;
  final Set<int> lowConfidenceCells;
  final DateTime createdAt;

  Map<String, int> get counts {
    final result = <String, int>{};
    for (final id in cells) {
      if (id == emptyCell) continue;
      result[id] = (result[id] ?? 0) + 1;
    }
    return result;
  }

  int get beadCount => counts.values.fold(0, (sum, value) => sum + value);

  String cellAt(int row, int column) => cells[row * columns + column];
  void setCell(int row, int column, String colorId) =>
      cells[row * columns + column] = colorId;

  Map<String, dynamic> toJson() => {
        'name': name,
        'size': '${columns}x$rows',
        'rows': rows,
        'columns': columns,
        'colors': counts.length,
        'sourcePath': sourcePath,
        'createdAt': createdAt.toIso8601String(),
        'lowConfidenceCells': lowConfidenceCells.toList(),
        'cells': [
          for (var row = 0; row < rows; row++)
            for (var column = 0; column < columns; column++)
              if (cellAt(row, column) != emptyCell)
                {'row': row + 1, 'column': column + 1, 'color': cellAt(row, column)},
        ],
      };
}
