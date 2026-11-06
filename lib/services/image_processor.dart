import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

import '../models/bead_models.dart';
import 'color_engine.dart';

class ImageProcessor {
  const ImageProcessor(this.colors);
  final ColorEngine colors;

  Future<BeadProject> process(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('无法读取这张图片');
    final columns = _detectAxis(decoded, vertical: true);
    final rows = _detectAxis(decoded, vertical: false);
    final samples = <_CellSample>[
      for (var row = 0; row < rows; row++)
        for (var column = 0; column < columns; column++)
          _sampleCell(decoded, row, column, rows, columns),
    ];
    final borderSamples = <_CellSample>[];
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        if (row < 2 || column < 2 || row >= rows - 2 || column >= columns - 2) {
          borderSamples.add(samples[row * columns + column]);
        }
      }
    }
    final background = _medianColor(borderSamples.map((sample) => sample.color).toList());
    final borderDistances = borderSamples
        .map((sample) => colors.distance(sample.color, background))
        .toList()..sort();
    final backgroundSpread = borderDistances[(borderDistances.length * .9).floor().clamp(0, borderDistances.length - 1).toInt()];
    final blankThreshold = math.max(3.5, backgroundSpread + 1.5);
    final cells = <String>[];
    final lowConfidence = <int>{};
    for (var index = 0; index < samples.length; index++) {
      final sample = samples[index];
      final backgroundDistance = colors.distance(sample.color, background);
      final hasCenteredLabel = sample.inkRatio >= .010 && sample.inkRatio <= .42;
      // 拼豆由格子中央的色号文字确认。浅色豆可能与底板颜色很接近，
      // 因此背景距离只能降低置信度，不能覆盖文字证据并把它删掉。
      final isBlank = !hasCenteredLabel;
      if (isBlank) {
        cells.add(BeadProject.emptyCell);
        if ((backgroundDistance - blankThreshold).abs() < 1.0) {
          lowConfidence.add(index);
        }
        continue;
      }
      final match = colors.match(sample.color);
      cells.add(match.color.id);
      if (match.margin < 1.25 || match.distance > 8 || sample.variance > 260) {
        lowConfidence.add(index);
      }
    }
    _repairSupportedGaps(cells, lowConfidence, samples, rows, columns);
    final fitted = _fitToPegboards(cells, lowConfidence, rows, columns);
    return BeadProject(
      name: path.basenameWithoutExtension(sourcePath),
      rows: fitted.rows,
      columns: fitted.columns,
      cells: fitted.cells,
      sourcePath: sourcePath,
      lowConfidenceCells: fitted.lowConfidence,
    );
  }

  void _repairSupportedGaps(
    List<String> cells,
    Set<int> lowConfidence,
    List<_CellSample> samples,
    int rows,
    int columns,
  ) {
    final original = List<String>.from(cells);
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final index = row * columns + column;
        if (original[index] != BeadProject.emptyCell) continue;
        final left = column > 0 ? original[index - 1] : BeadProject.emptyCell;
        final right = column + 1 < columns ? original[index + 1] : BeadProject.emptyCell;
        final up = row > 0 ? original[index - columns] : BeadProject.emptyCell;
        final down = row + 1 < rows ? original[index + columns] : BeadProject.emptyCell;
        String? candidate;
        if (left != BeadProject.emptyCell && left == right) candidate = left;
        if (up != BeadProject.emptyCell && up == down) {
          candidate = candidate == null || candidate == up ? up : null;
        }
        final neighbours = [left, right, up, down]
            .where((id) => id != BeadProject.emptyCell)
            .toList();
        final frequencies = <String, int>{};
        for (final id in neighbours) {
          frequencies[id] = (frequencies[id] ?? 0) + 1;
        }
        for (final entry in frequencies.entries) {
          if (entry.value >= 3) candidate ??= entry.key;
        }
        if (candidate == null) continue;
        final target = colors.byId(candidate).rgb;
        // 只有检测到格子中心确实存在色号笔画，才允许补回一个空格。
        // 仅凭周围颜色相近会把网格线、底图纹理和水印误补成拼豆，
        // 造成豆子数量膨胀；一个格子必须对应一个真实色号。
        final hasWeakText = samples[index].inkRatio >= .010;
        final fillAgrees = colors.distance(samples[index].color, target) <= 8.0;
        if (hasWeakText && fillAgrees) {
          cells[index] = candidate;
          lowConfidence.add(index);
        }
      }
    }
  }

  ({List<String> cells, Set<int> lowConfidence, int rows, int columns}) _fitToPegboards(
    List<String> sourceCells,
    Set<int> sourceLowConfidence,
    int sourceRows,
    int sourceColumns,
  ) {
    var minRow = sourceRows, minColumn = sourceColumns, maxRow = -1, maxColumn = -1;
    for (var index = 0; index < sourceCells.length; index++) {
      if (sourceCells[index] == BeadProject.emptyCell) continue;
      final row = index ~/ sourceColumns;
      final column = index % sourceColumns;
      minRow = math.min(minRow, row);
      minColumn = math.min(minColumn, column);
      maxRow = math.max(maxRow, row);
      maxColumn = math.max(maxColumn, column);
    }
    if (maxRow < minRow || maxColumn < minColumn) {
      return (
        cells: List<String>.filled(29 * 29, BeadProject.emptyCell),
        lowConfidence: <int>{},
        rows: 29,
        columns: 29,
      );
    }
    final contentRows = maxRow - minRow + 1;
    final contentColumns = maxColumn - minColumn + 1;
    final targetRows = math.max(29, (contentRows / 29).ceil() * 29);
    final targetColumns = math.max(29, (contentColumns / 29).ceil() * 29);
    final rowOffset = (targetRows - contentRows) ~/ 2;
    final columnOffset = (targetColumns - contentColumns) ~/ 2;
    final targetCells = List<String>.filled(targetRows * targetColumns, BeadProject.emptyCell);
    final targetLowConfidence = <int>{};
    for (var row = minRow; row <= maxRow; row++) {
      for (var column = minColumn; column <= maxColumn; column++) {
        final sourceIndex = row * sourceColumns + column;
        final targetRow = row - minRow + rowOffset;
        final targetColumn = column - minColumn + columnOffset;
        final targetIndex = targetRow * targetColumns + targetColumn;
        targetCells[targetIndex] = sourceCells[sourceIndex];
        if (sourceLowConfidence.contains(sourceIndex)) targetLowConfidence.add(targetIndex);
      }
    }
    return (
      cells: targetCells,
      lowConfidence: targetLowConfidence,
      rows: targetRows,
      columns: targetColumns,
    );
  }

  _CellSample _sampleCell(img.Image source, int row, int column, int rows, int columns) {
    final left = column * source.width / columns;
    final top = row * source.height / rows;
    final cellWidth = source.width / columns;
    final cellHeight = source.height / rows;
    final pixels = <(int, int, int)>[];
    const ranges = [(0.16, 0.36), (0.64, 0.84)];
    for (final xr in ranges) {
      for (final yr in ranges) {
        final x0 = (left + xr.$1 * cellWidth).floor();
        final x1 = (left + xr.$2 * cellWidth).ceil();
        final y0 = (top + yr.$1 * cellHeight).floor();
        final y1 = (top + yr.$2 * cellHeight).ceil();
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            final pixel = source.getPixel(x.clamp(0, source.width - 1).toInt(), y.clamp(0, source.height - 1).toInt());
            pixels.add((pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()));
          }
        }
      }
    }
    final buckets = <int, List<(int, int, int)>>{};
    for (final pixel in pixels) {
      final key = (pixel.$1 ~/ 12 << 16) | (pixel.$2 ~/ 12 << 8) | pixel.$3 ~/ 12;
      buckets.putIfAbsent(key, () => []).add(pixel);
    }
    final dominant = buckets.values.reduce((a, b) => a.length >= b.length ? a : b);
    final red = dominant.map((p) => p.$1).reduce((a, b) => a + b) ~/ dominant.length;
    final green = dominant.map((p) => p.$2).reduce((a, b) => a + b) ~/ dominant.length;
    final blue = dominant.map((p) => p.$3).reduce((a, b) => a + b) ~/ dominant.length;
    final color = Color.fromARGB(255, red, green, blue);
    var variance = 0.0;
    for (final pixel in dominant) {
      variance += math.pow(pixel.$1 - red, 2) + math.pow(pixel.$2 - green, 2) + math.pow(pixel.$3 - blue, 2);
    }
    variance /= dominant.length;
    final baseLuminance = red * .299 + green * .587 + blue * .114;
    var darkInk = 0, lightInk = 0, centerSamples = 0;
    for (var y = (top + .14 * cellHeight).floor(); y < (top + .86 * cellHeight).ceil(); y++) {
      for (var x = (left + .08 * cellWidth).floor(); x < (left + .92 * cellWidth).ceil(); x++) {
        final pixel = source.getPixel(x.clamp(0, source.width - 1).toInt(), y.clamp(0, source.height - 1).toInt());
        final luminance = pixel.r * .299 + pixel.g * .587 + pixel.b * .114;
        final colorDelta = math.sqrt(
          math.pow(pixel.r - red, 2) +
              math.pow(pixel.g - green, 2) +
              math.pow(pixel.b - blue, 2),
        );
        if (luminance < baseLuminance - 22 ||
            (colorDelta > 58 && luminance < baseLuminance)) darkInk++;
        if (luminance > baseLuminance + 22 ||
            (colorDelta > 58 && luminance > baseLuminance)) lightInk++;
        centerSamples++;
      }
    }
    return _CellSample(
      color,
      variance,
      math.max(darkInk, lightInk) / math.max(1, centerSamples),
    );
  }

  Color _medianColor(List<Color> values) {
    int median(List<int> channels) { channels.sort(); return channels[channels.length ~/ 2]; }
    return Color.fromARGB(255, median(values.map((c) => c.red).toList()), median(values.map((c) => c.green).toList()), median(values.map((c) => c.blue).toList()));
  }

  int _detectAxis(img.Image source, {required bool vertical}) {
    final length = vertical ? source.width : source.height;
    final cross = vertical ? source.height : source.width;
    final profile = List<double>.filled(length, 0);
    final crossStep = mathMax(1, cross ~/ 240);
    for (var position = 1; position < length; position++) {
      var score = 0.0, samples = 0;
      for (var c = 0; c < cross; c += crossStep) {
        final a = vertical ? source.getPixel(position - 1, c) : source.getPixel(c, position - 1);
        final b = vertical ? source.getPixel(position, c) : source.getPixel(c, position);
        final la = a.r * .299 + a.g * .587 + a.b * .114;
        final lb = b.r * .299 + b.g * .587 + b.b * .114;
        score += (la - lb).abs(); samples++;
      }
      profile[position] = score / samples;
    }
    final minPeriod = mathMax(4, length ~/ 140);
    final maxPeriod = mathMax(minPeriod + 1, length ~/ 8);
    var bestPeriod = 0, bestScore = 0.0;
    for (var period = minPeriod; period <= maxPeriod; period++) {
      var dot = 0.0, left = 0.0, right = 0.0;
      for (var i = 1; i + period < length; i++) {
        dot += profile[i] * profile[i + period];
        left += profile[i] * profile[i]; right += profile[i + period] * profile[i + period];
      }
      final correlation = dot / ((left * right).sqrtSafe());
      final score = correlation / (1 + period * .002);
      if (score > bestScore) { bestScore = score; bestPeriod = period; }
    }
    if (bestPeriod == 0 || bestScore < .16) return 29;
    return (length / bestPeriod).round().clamp(6, 140).toInt();
  }
}

class _CellSample {
  const _CellSample(this.color, this.variance, this.inkRatio);
  final Color color;
  final double variance;
  final double inkRatio;
}

int mathMin(int a, int b) => a < b ? a : b;
int mathMax(int a, int b) => a > b ? a : b;

extension on double {
  double sqrtSafe() => this <= 0 ? 1 : math.sqrt(this);
}
