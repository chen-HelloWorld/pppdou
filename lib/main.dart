import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models/bead_models.dart';
import 'services/color_engine.dart';
import 'services/image_processor.dart';
import 'services/project_storage.dart';

const ink = Color(0xFF0A1145);
const purple = Color(0xFF655EF3);
const softPurple = Color(0xFFF1F2FF);
const muted = Color(0xFF8389AB);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final colors = ColorEngine();
  await colors.load();
  runApp(PindouApp(colors: colors));
}

class PindouApp extends StatelessWidget {
  const PindouApp({super.key, required this.colors});
  final ColorEngine colors;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '拼豆图纸',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFE),
        colorScheme: ColorScheme.fromSeed(seedColor: purple, brightness: Brightness.light),
        fontFamilyFallback: const ['Microsoft YaHei', 'PingFang SC', 'Noto Sans CJK SC'],
        textTheme: const TextTheme(bodyMedium: TextStyle(color: ink, fontSize: 16)),
      ),
      home: ImportScreen(colors: colors),
    );
  }
}

class AppFrame extends StatelessWidget {
  const AppFrame({
    super.key,
    required this.title,
    required this.body,
    this.bottom,
    this.onBack,
  });
  final String title;
  final Widget body;
  final Widget? bottom;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  child: Row(
                    children: [
                      CircleIcon(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack ?? () {}),
                      Expanded(child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w700, color: ink))),
                      const CircleIcon(icon: Icons.more_horiz_rounded),
                    ],
                  ),
                ),
                Expanded(child: body),
                if (bottom != null) bottom!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CircleIcon extends StatelessWidget {
  const CircleIcon({super.key, required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 52, height: 52, child: Icon(icon, color: onTap == null ? purple : ink)),
        ),
      );
}

class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF626AF8), Color(0xFF5548E8)]),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [BoxShadow(color: Color(0x30655EF3), blurRadius: 20, offset: Offset(0, 8))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(height: 58, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white), const SizedBox(width: 14), Text(label, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w600))])),
            ),
          ),
        ),
      );
}

class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.active});
  final int active;
  static const labels = ['图纸导入', '整理色号', '剪裁图例', '效果校对'];
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
        child: Row(
          children: List.generate(4, (index) => Expanded(
            child: Row(children: [
              Expanded(child: Column(children: [
                AnimatedContainer(duration: const Duration(milliseconds: 200), width: 42, height: 42, decoration: BoxDecoration(shape: BoxShape.circle, gradient: index == active ? const LinearGradient(colors: [Color(0xFF7A84FF), Color(0xFF5E55EA)]) : null, color: index == active ? null : const Color(0xFFECEEF7)), child: Center(child: Text('${index + 1}', style: TextStyle(color: index == active ? Colors.white : const Color(0xFF737895), fontSize: 18, fontWeight: FontWeight.w600)))),
                const SizedBox(height: 7),
                Text(labels[index], textAlign: TextAlign.center, maxLines: 1, style: TextStyle(color: index == active ? purple : muted, fontSize: 13, fontWeight: index == active ? FontWeight.w700 : FontWeight.w500)),
              ])),
              if (index < 3) const SizedBox(width: 8, child: Divider(color: Color(0xFFDDE0F1), thickness: 2)),
            ]),
          )),
        ),
      );
}

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, required this.colors});
  final ColorEngine colors;
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String? selectedPath;
  bool loading = false;
  String? error;

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp']);
    if (result?.files.single.path != null) setState(() { selectedPath = result!.files.single.path; error = null; });
  }

  Future<void> pickPhoto(ImageSource source) async {
    final result = await ImagePicker().pickImage(source: source, imageQuality: 100);
    if (result != null) setState(() { selectedPath = result.path; error = null; });
  }

  Future<void> recognize() async {
    if (selectedPath == null) { setState(() => error = '请先导入一张图片'); return; }
    setState(() { loading = true; error = null; });
    try {
      final project = await ImageProcessor(widget.colors).process(selectedPath!);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(colors: widget.colors, project: project)));
    } catch (e) {
      setState(() => error = '识别失败：$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppFrame(
        title: '图纸导入',
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          children: [
            const StepHeader(active: 0),
            Panel(
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCFD4FF), width: 1.5), borderRadius: BorderRadius.circular(24)),
                child: Column(children: [
                  SizedBox(height: 180, child: selectedPath == null ? const ImportIllustration() : ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.file(File(selectedPath!), fit: BoxFit.contain))),
                  const SizedBox(height: 10),
                  Text(selectedPath == null ? '导入图片，生成串珠图纸' : '图片已准备好', style: const TextStyle(fontSize: 23, color: ink, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(selectedPath == null ? '支持照片、手绘图、像素图等多种图片格式' : '点击底部按钮开始离线识别', style: const TextStyle(color: muted, fontSize: 15)),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: ImportAction(icon: Icons.photo_library_rounded, label: '从相册导入', onTap: () => pickPhoto(ImageSource.gallery))),
                    const SizedBox(width: 10),
                    Expanded(child: ImportAction(icon: Icons.photo_camera_rounded, label: '拍照导入', onTap: () => pickPhoto(ImageSource.camera))),
                    const SizedBox(width: 10),
                    Expanded(child: ImportAction(icon: Icons.insert_drive_file_rounded, label: '导入图片', onTap: pickFile)),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            const Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.tips_and_updates_rounded, color: purple), SizedBox(width: 10), Text('导入小贴士', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: ink))]),
              SizedBox(height: 12),
              Tip('建议使用清晰、对比度高的图片，效果更准确'),
              Tip('支持 JPG、PNG、JPEG、WEBP 等常见格式'),
              Tip('推荐图片尺寸大于 300 × 300 像素'),
            ])),
            if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent))),
            const SizedBox(height: 8),
          ],
        ),
        bottom: GradientButton(label: loading ? '正在识别图纸…' : '开始识别图纸', icon: Icons.grid_view_rounded, onTap: loading ? null : recognize),
      );
}

class ImportIllustration extends StatelessWidget {
  const ImportIllustration({super.key});
  @override
  Widget build(BuildContext context) => Stack(alignment: Alignment.center, children: [
    Container(width: 210, height: 120, decoration: BoxDecoration(color: const Color(0xFFF0F1FF), borderRadius: BorderRadius.circular(60))),
    Transform.rotate(angle: -.05, child: Container(width: 145, height: 145, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE0E4FF), width: 3), boxShadow: const [BoxShadow(color: Color(0x180A1145), blurRadius: 16)]), child: const Icon(Icons.image_rounded, size: 76, color: purple))),
    const Positioned(right: 60, top: 20, child: Icon(Icons.add_rounded, color: Color(0xFFB7BCFF), size: 34)),
  ]);
}

class ImportAction extends StatelessWidget {
  const ImportAction({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon; final String label; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: const Color(0xFFF5F6FF), borderRadius: BorderRadius.circular(20), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4), child: Column(children: [Icon(icon, color: purple, size: 34), const SizedBox(height: 9), Text(label, textAlign: TextAlign.center, style: const TextStyle(color: ink, fontWeight: FontWeight.w600, fontSize: 14))]))));
}

class Tip extends StatelessWidget {
  const Tip(this.text, {super.key}); final String text;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(children: [const Icon(Icons.check_circle_rounded, size: 20, color: purple), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(color: muted, fontSize: 14))) ]));
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child}); final Widget child;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x0D0A1145), blurRadius: 22, offset: Offset(0, 8))]), child: child);
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.colors, required this.project});
  final ColorEngine colors; final BeadProject project;
  @override State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int tab = 1;
  late final TransformationController transform;
  @override void initState() { super.initState(); transform = TransformationController(); }
  @override void dispose() { transform.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final sorted = widget.project.counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return AppFrame(
      title: '图纸识别结果',
      onBack: () => Navigator.pop(context),
      body: ListView(padding: const EdgeInsets.symmetric(horizontal: 18), children: [
        Segments(labels: const ['原图', '像素图', '效果图'], selected: tab, onChanged: (value) => setState(() => tab = value)),
        const SizedBox(height: 14),
        Panel(child: SizedBox(height: math.min(MediaQuery.sizeOf(context).width - 70, 520), child: tab == 0 ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(widget.project.sourcePath), fit: BoxFit.contain)) : InteractiveViewer(transformationController: transform, minScale: .7, maxScale: 12, child: AspectRatio(aspectRatio: widget.project.columns / widget.project.rows, child: CustomPaint(painter: BeadPainter(project: widget.project, colors: widget.colors, effect: tab == 2)))))),
        const SizedBox(height: 14),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.description_rounded, color: purple), SizedBox(width: 10), Text('识别信息', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)), Spacer(), StatusPill()]),
          const SizedBox(height: 14),
          Wrap(runSpacing: 14, spacing: 28, children: [InfoItem(icon: Icons.palette_rounded, label: '颜色数', value: '${sorted.length} 种'), InfoItem(icon: Icons.view_in_ar_rounded, label: '豆数', value: '${widget.project.beadCount} 颗'), InfoItem(icon: Icons.fullscreen_rounded, label: '尺寸', value: '${widget.project.columns} × ${widget.project.rows} 格'), InfoItem(icon: Icons.rule_rounded, label: '待校对', value: '${widget.project.lowConfidenceCells.length} 格'), InfoItem(icon: Icons.schedule_rounded, label: '时间', value: '约 ${math.max(1, widget.project.beadCount ~/ 600)} 小时'), InfoItem(icon: Icons.description_rounded, label: '名称', value: widget.project.name)]),
        ])),
        const SizedBox(height: 14),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.palette_rounded, color: purple), const SizedBox(width: 10), Text('颜色清单（共 ${sorted.length} 种）', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: sorted.take(10).map((entry) { final color = widget.colors.byId(entry.key); return ColorChip(color: color, count: entry.value); }).toList()),
          if (sorted.length > 10) Padding(padding: const EdgeInsets.only(top: 10), child: Text('+ 还有 ${sorted.length - 10} 种颜色', style: const TextStyle(color: purple, fontWeight: FontWeight.w600))),
        ])),
        const SizedBox(height: 14),
      ]),
      bottom: GradientButton(label: '下一步 · 开始整理色号', icon: Icons.grid_on_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditorScreen(colors: widget.colors, project: widget.project)))),
    );
  }
}

class Segments extends StatelessWidget {
  const Segments({super.key, required this.labels, required this.selected, required this.onChanged});
  final List<String> labels; final int selected; final ValueChanged<int> onChanged;
  @override Widget build(BuildContext context) => Container(height: 56, padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: const Color(0xFFF0F1FA), borderRadius: BorderRadius.circular(30)), child: Row(children: List.generate(labels.length, (index) => Expanded(child: InkWell(onTap: () => onChanged(index), borderRadius: BorderRadius.circular(28), child: AnimatedContainer(duration: const Duration(milliseconds: 180), decoration: BoxDecoration(gradient: index == selected ? const LinearGradient(colors: [Color(0xFF707BFA), Color(0xFF6658EC)]) : null, borderRadius: BorderRadius.circular(28)), child: Center(child: Text(labels[index], style: TextStyle(color: index == selected ? Colors.white : ink, fontWeight: FontWeight.w600, fontSize: 16)))))))));
}

class StatusPill extends StatelessWidget { const StatusPill({super.key}); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFECFAF0), borderRadius: BorderRadius.circular(18)), child: const Row(children: [Icon(Icons.check_circle, color: Color(0xFF44B869), size: 18), SizedBox(width: 5), Text('识别完成', style: TextStyle(color: Color(0xFF3AA65E), fontSize: 13))])); }

class InfoItem extends StatelessWidget { const InfoItem({super.key, required this.icon, required this.label, required this.value}); final IconData icon; final String label; final String value; @override Widget build(BuildContext context) => SizedBox(width: 205, child: Row(children: [Icon(icon, color: purple), const SizedBox(width: 10), Text('$label  ', style: const TextStyle(color: muted)), Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: ink)))])); }

class ColorChip extends StatelessWidget { const ColorChip({super.key, required this.color, required this.count}); final BeadColor color; final int count; @override Widget build(BuildContext context) => Container(width: 116, padding: const EdgeInsets.all(9), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE3E6F1)), borderRadius: BorderRadius.circular(14)), child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: color.rgb, shape: BoxShape.circle, border: Border.all(color: Colors.black12))), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(color.id, style: const TextStyle(fontWeight: FontWeight.w700, color: ink)), Text('$count 颗', style: const TextStyle(fontSize: 12, color: muted))]))])); }

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.colors, required this.project}); final ColorEngine colors; final BeadProject project;
  @override State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  int row = 0, column = 0; String? highlighted;
  late final TransformationController transform;
  @override void initState() { super.initState(); transform = TransformationController(); }
  @override void dispose() { transform.dispose(); super.dispose(); }

  void selectCell(Offset normalized) {
    setState(() { column = (normalized.dx * widget.project.columns).floor().clamp(0, widget.project.columns - 1).toInt(); row = (normalized.dy * widget.project.rows).floor().clamp(0, widget.project.rows - 1).toInt(); });
  }

  Future<void> changeColor() async {
    final picked = await showModalBottomSheet<BeadColor>(context: context, isScrollControlled: true, showDragHandle: true, builder: (context) => ColorPicker(colors: widget.colors.colors));
    if (picked != null) setState(() { widget.project.setCell(row, column, picked.id); widget.project.lowConfidenceCells.remove(row * widget.project.columns + column); });
  }

  @override
  Widget build(BuildContext context) {
    final currentId = widget.project.cellAt(row, column);
    final current = currentId == BeadProject.emptyCell ? null : widget.colors.byId(currentId);
    final sorted = widget.project.counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final palette = SizedBox(height: wide ? null : 88, width: wide ? 155 : null, child: ListView(scrollDirection: wide ? Axis.vertical : Axis.horizontal, children: sorted.map((entry) { final color = widget.colors.byId(entry.key); final selected = highlighted == entry.key; return Padding(padding: const EdgeInsets.all(4), child: InkWell(onTap: () => setState(() => highlighted = selected ? null : entry.key), child: Container(width: wide ? null : 104, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: selected ? softPurple : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? purple : const Color(0xFFE7E9F2))), child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: color.rgb, shape: BoxShape.circle, border: Border.all(color: Colors.black12))), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(color.id, style: const TextStyle(fontWeight: FontWeight.w700)), Text(color.name, style: const TextStyle(fontSize: 12, color: muted))])])))); }).toList()));
    final board = Panel(child: LayoutBuilder(builder: (context, constraints) { final side = math.min(constraints.maxWidth, wide ? 610.0 : MediaQuery.sizeOf(context).width - 68); return Center(child: SizedBox(width: side, height: side, child: GestureDetector(onTapUp: (details) { final point = transform.toScene(details.localPosition); selectCell(Offset(point.dx / side, point.dy / side)); }, child: InteractiveViewer(transformationController: transform, minScale: .8, maxScale: 15, child: CustomPaint(size: Size.square(side), painter: BeadPainter(project: widget.project, colors: widget.colors, highlighted: highlighted, selectedRow: row, selectedColumn: column, effect: true))))); }));
    return AppFrame(
      title: '效果校对',
      onBack: () => Navigator.pop(context),
      body: ListView(padding: const EdgeInsets.symmetric(horizontal: 14), children: [
        Segments(labels: const ['原图', '像素图', '效果图'], selected: 2, onChanged: (_) {}),
        const SizedBox(height: 14),
        if (wide) SizedBox(height: 640, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Panel(child: SizedBox(width: 155, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('🎨 颜色清单', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)), const SizedBox(height: 6), Expanded(child: palette)]))), const SizedBox(width: 12), Expanded(child: board)])) else ...[Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('颜色清单  共 ${sorted.length} 种', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)), const SizedBox(height: 6), palette])), const SizedBox(height: 12), board],
        const SizedBox(height: 12),
        const Center(child: Text('双指缩放查看细节，单击格子可查看颜色信息', style: TextStyle(color: purple, fontSize: 14))),
        const SizedBox(height: 12),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.my_location_rounded, color: purple), SizedBox(width: 10), Text('当前格子', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19))]),
          const SizedBox(height: 12),
          Row(children: [Container(width: 104, height: 104, decoration: BoxDecoration(color: current?.rgb ?? const Color(0xFFF2F6F8), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFD8E1E8))), child: Icon(current == null ? Icons.grid_4x4_rounded : Icons.close_rounded, color: current == null ? muted : Colors.white70, size: 42)), const SizedBox(width: 18), Expanded(child: Column(children: [DetailRow(label: '当前格子：', value: '${row + 1}行  ${column + 1}列'), DetailRow(label: '颜色：', value: current == null ? '空白格（不计颜色）' : '${current.id}  ${current.name}', swatch: current?.rgb), DetailRow(label: '数量：', value: current == null ? '0 颗' : '${widget.project.counts[current.id]} 颗'), DetailRow(label: '占比：', value: current == null ? '0%' : '${((widget.project.counts[current.id] ?? 0) / math.max(1, widget.project.beadCount) * 100).toStringAsFixed(1)}%')]))]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: changeColor, icon: const Icon(Icons.palette_rounded), label: const Text('修改当前格子颜色'), style: OutlinedButton.styleFrom(foregroundColor: purple, side: const BorderSide(color: purple), padding: const EdgeInsets.symmetric(vertical: 14)))),
        ])),
        const SizedBox(height: 12),
      ]),
      bottom: GradientButton(label: '确认生成图纸', icon: Icons.grid_view_rounded, onTap: () async { final file = await ProjectStorage().save(widget.project); if (!context.mounted) return; await showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('图纸已保存'), content: Text('已保存到本地：\n${file.path}'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('完成'))])); }),
    );
  }
}

class DetailRow extends StatelessWidget { const DetailRow({super.key, required this.label, required this.value, this.swatch}); final String label, value; final Color? swatch; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [SizedBox(width: 88, child: Text(label, style: const TextStyle(color: muted))), if (swatch != null) ...[Container(width: 24, height: 24, decoration: BoxDecoration(color: swatch, shape: BoxShape.circle)), const SizedBox(width: 8)], Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: ink))) ])); }

class ColorPicker extends StatelessWidget { const ColorPicker({super.key, required this.colors}); final List<BeadColor> colors; @override Widget build(BuildContext context) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .72, child: Column(children: [const Text('选择 MRAD 色号', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)), const SizedBox(height: 12), Expanded(child: GridView.builder(padding: const EdgeInsets.all(14), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 150, childAspectRatio: 2.2, crossAxisSpacing: 8, mainAxisSpacing: 8), itemCount: colors.length, itemBuilder: (_, index) { final color = colors[index]; return InkWell(onTap: () => Navigator.pop(context, color), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE1E4EF)), borderRadius: BorderRadius.circular(12)), child: Row(children: [Container(width: 34, height: 34, decoration: BoxDecoration(color: color.rgb, shape: BoxShape.circle, border: Border.all(color: Colors.black12))), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(color.id, style: const TextStyle(fontWeight: FontWeight.w700)), Text(color.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: muted))]))]))); }))]))); }

class BeadPainter extends CustomPainter {
  const BeadPainter({required this.project, required this.colors, this.effect = false, this.highlighted, this.selectedRow, this.selectedColumn});
  final BeadProject project; final ColorEngine colors; final bool effect; final String? highlighted; final int? selectedRow, selectedColumn;
  @override void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / project.columns;
    final cellHeight = size.height / project.rows;
    final background = Paint()..color = const Color(0xFFEAF3F6);
    canvas.drawRect(Offset.zero & size, background);
    for (var row = 0; row < project.rows; row++) {
      for (var column = 0; column < project.columns; column++) {
        final id = project.cellAt(row, column);
        if (id == BeadProject.emptyCell) continue;
        final base = colors.byId(id).rgb;
        final opacity = highlighted == null || highlighted == id ? 1.0 : .12;
        final paint = Paint()..color = base.withOpacity(opacity);
        final center = Offset((column + .5) * cellWidth, (row + .5) * cellHeight);
        if (effect) {
          final radius = math.min(cellWidth, cellHeight) * .38;
          canvas.drawCircle(center, radius, paint);
          canvas.drawCircle(center.translate(-radius * .28, -radius * .30), radius * .23, Paint()..color = Colors.white.withOpacity(.42 * opacity));
        } else {
          canvas.drawRect(Rect.fromLTWH(column * cellWidth, row * cellHeight, cellWidth + .25, cellHeight + .25), paint);
        }
      }
    }
    final grid = Paint()..style = PaintingStyle.stroke;
    for (var column = 0; column <= project.columns; column++) {
      final major = column % 10 == 0;
      grid.color = major ? const Color(0xFF8D9AA5) : const Color(0xFFD8E3E8);
      grid.strokeWidth = major ? 1.6 : .55;
      canvas.drawLine(Offset(column * cellWidth, 0), Offset(column * cellWidth, size.height), grid);
    }
    for (var row = 0; row <= project.rows; row++) {
      final major = row % 10 == 0;
      grid.color = major ? const Color(0xFF8D9AA5) : const Color(0xFFD8E3E8);
      grid.strokeWidth = major ? 1.6 : .55;
      canvas.drawLine(Offset(0, row * cellHeight), Offset(size.width, row * cellHeight), grid);
    }
    if (selectedRow != null && selectedColumn != null) {
      canvas.drawRect(Rect.fromLTWH(selectedColumn! * cellWidth, selectedRow! * cellHeight, cellWidth, cellHeight), Paint()..style = PaintingStyle.stroke..strokeWidth = math.max(1.5, math.min(cellWidth, cellHeight) * .14)..color = const Color(0xFFFF2F91));
    }
  }
  @override bool shouldRepaint(covariant BeadPainter oldDelegate) => true;
}
