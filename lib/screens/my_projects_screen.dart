import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart' show EditorScreen, purple, muted;
import '../services/color_engine.dart';
import '../models/bead_models.dart';
import '../services/cloud_project_storage.dart';

class MyProjectsScreen extends StatefulWidget {
  const MyProjectsScreen({super.key, required this.colors});

  final ColorEngine colors;

  @override
  State<MyProjectsScreen> createState() => _MyProjectsScreenState();
}

class _MyProjectsScreenState extends State<MyProjectsScreen> {
  late final CloudProjectStorage _storage = CloudProjectStorage(widget.colors);
  late Future<List<Map<String, dynamic>>> _projects = _storage.listProjects();
  final Map<String, Future<BeadProject>> _thumbnails = {};

  Future<void> _refresh() async {
    setState(() { _thumbnails.clear(); _projects = _storage.listProjects(); });
  }

  Future<void> _open(Map<String, dynamic> row) async {
    try {
      final project = await _storage.load(row['id'] as String);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EditorScreen(colors: widget.colors, project: project),
      ));
      if (mounted) await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开图纸失败：$error')),
      );
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的图纸'),
        actions: [
          IconButton(onPressed: _refresh, tooltip: '刷新', icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _signOut, tooltip: '退出登录', icon: const Icon(Icons.logout)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _projects,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('读取图纸失败，请确认 Supabase 表和账号权限已配置。\n${snapshot.error}',
                  textAlign: TextAlign.center, style: const TextStyle(color: muted)),
            ));
          }
          final projects = snapshot.data ?? const [];
          if (projects.isEmpty) {
            return const Center(child: Text('还没有保存的图纸', style: TextStyle(color: muted)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: projects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final project = projects[index];
              return Card(
                child: ListTile(
                  leading: FutureBuilder<BeadProject>(
                    future: _thumbnails.putIfAbsent(project['id'] as String, () => _storage.load(project['id'] as String)),
                    builder: (context, snapshot) => SizedBox(
                      width: 56, height: 56,
                      child: snapshot.hasData
                          ? CustomPaint(painter: _ThumbnailPainter(snapshot.data!, widget.colors))
                          : const ColoredBox(color: Color(0xFFF1F2FF), child: Icon(Icons.grid_on_rounded, color: purple)),
                    ),
                  ),
                  title: Text(project['name'] as String? ?? '未命名图纸'),
                  subtitle: Text('${project['columns']} × ${project['rows']} 格'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(project),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ThumbnailPainter extends CustomPainter {
  _ThumbnailPainter(this.project, this.colors);
  final BeadProject project;
  final ColorEngine colors;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / project.columns).clamp(0.0, size.height / project.rows);
    final left = (size.width - project.columns * scale) / 2;
    final top = (size.height - project.rows * scale) / 2;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF1F4F8));
    final palette = {for (final color in colors.colors) color.id: color.rgb};
    final paint = Paint();
    for (var i = 0; i < project.cells.length; i++) {
      final color = palette[project.cells[i]];
      if (color == null) continue;
      paint.color = color;
      canvas.drawRect(Rect.fromLTWH(left + (i % project.columns) * scale,
          top + (i ~/ project.columns) * scale, scale + .1, scale + .1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ThumbnailPainter oldDelegate) => oldDelegate.project != project;
}
