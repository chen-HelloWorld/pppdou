import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bead_models.dart';
import 'color_engine.dart';

class CloudProjectStorage {
  CloudProjectStorage(this.colors) : _client = Supabase.instance.client;

  final ColorEngine colors;
  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> listProjects() async {
    final rows = await _client
        .from('projects')
        .select('id, name, rows, columns, created_at, updated_at')
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> save(BeadProject project) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('请先登录');

    final gridCells = <List<dynamic>>[];
    for (var row = 0; row < project.rows; row++) {
      for (var column = 0; column < project.columns; column++) {
        final index = row * project.columns + column;
        final colorId = project.cellAt(row, column);
        final hasBead = colorId != BeadProject.emptyCell;
        final uncertain = project.lowConfidenceCells.contains(index);
        gridCells.add([hasBead ? colorId : null, hasBead ? colors.byId(colorId).hex : null, uncertain, uncertain, false]);
      }
    }
    final projectRow = <String, dynamic>{
      'user_id': userId,
      'name': project.name,
      'rows': project.rows,
      'columns': project.columns,
      'palette_code': 'MARD',
      'schema_version': 2,
      'grid_data': {'version': 1, 'cells': gridCells},
    };
    final projectId = project.cloudId;
    if (projectId == null) {
      final created = await _client.from('projects').insert(projectRow).select('id').single();
      project.cloudId = created['id'] as String;
    } else {
      await _client.from('projects').update(projectRow).eq('id', projectId).select('id').single();
    }
  }

  Future<BeadProject> load(String projectId) async {
    final row = await _client
        .from('projects')
        .select()
        .eq('id', projectId)
        .single();
    final rows = row['rows'] as int;
    final columns = row['columns'] as int;
    final total = rows * columns;
    final cells = List<String>.filled(total, BeadProject.emptyCell);
    final uncertain = <int>{};
    final grid = row['grid_data'];
    if (grid != null) {
      if (grid is! Map || grid['version'] != 1 || grid['cells'] is! List || (grid['cells'] as List).length != total) {
        throw StateError('图纸数据格式或格子数量不正确');
      }
      final gridCells = grid['cells'] as List;
      for (var index = 0; index < total; index++) {
        final cell = gridCells[index];
        if (cell is! List || cell.length < 5) throw StateError('图纸格子数据格式错误');
        if (cell[0] != null) cells[index] = cell[0] as String;
        if (cell[2] == true || cell[3] == true) uncertain.add(index);
      }
    } else {
      final cellRows = <Map<String, dynamic>>[];
      const pageSize = 500;
      for (var start = 0; start < total; start += pageSize) {
        final page = await _client.from('project_cells')
            .select('row_index, column_index, has_bead, color_id, is_uncertain, needs_review')
            .eq('project_id', projectId).order('row_index').order('column_index')
            .range(start, start + pageSize - 1);
        cellRows.addAll(List<Map<String, dynamic>>.from(page));
        if (page.length < pageSize) break;
      }
      if (cellRows.length != total) throw StateError('图纸格子数据不完整');
      for (final cell in cellRows) {
        final index = (cell['row_index'] as int) * columns + (cell['column_index'] as int);
        if (index < 0 || index >= total) throw StateError('图纸格子坐标无效');
        if (cell['has_bead'] == true && cell['color_id'] != null) cells[index] = cell['color_id'] as String;
        if (cell['is_uncertain'] == true || cell['needs_review'] == true) uncertain.add(index);
      }
    }

    return BeadProject(
      name: row['name'] as String,
      rows: rows,
      columns: columns,
      cells: cells,
      sourcePath: '',
      lowConfidenceCells: uncertain,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
      cloudId: projectId,
    );
  }
}
