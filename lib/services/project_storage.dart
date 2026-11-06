import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/bead_models.dart';

class ProjectStorage {
  Future<File> save(BeadProject project) async {
    final base = await getApplicationDocumentsDirectory();
    final folder = Directory(path.join(base.path, 'PindouStudio', 'projects'));
    await folder.create(recursive: true);
    final safeName = project.name.replaceAll(RegExp(r'[^\w\u4e00-\u9fa5-]'), '_');
    final file = File(path.join(folder.path, '$safeName.json'));
    return file.writeAsString(const JsonEncoder.withIndent('  ').convert(project.toJson()));
  }
}

