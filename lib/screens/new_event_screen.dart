import 'package:flutter/material.dart';
import '../models/models.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../constants/presets.dart';

/// New Event creation screen — mirrors app/event/new.tsx
class NewEventScreen extends StatefulWidget {
  const NewEventScreen({super.key});
  @override
  State<NewEventScreen> createState() => _NewEventScreenState();
}

class _NewEventScreenState extends State<NewEventScreen> {
  String _name = '';
  String _selectedColor = AppColors.eventColorHexes[0];
  List<FieldDefinition> _fields = [];

  void _addField(FieldType type, String defaultUnit) {
    setState(() {
      _fields.add(FieldDefinition(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: type,
        name: '',
        unit: defaultUnit,
      ));
    });
  }

  void _updateField(String id, {String? name, String? unit}) {
    setState(() {
      _fields = _fields.map((f) {
        if (f.id != id) return f;
        return f.copyWith(name: name ?? f.name, unit: unit ?? f.unit);
      }).toList();
    });
  }

  void _removeField(String id) {
    setState(() => _fields.removeWhere((f) => f.id == id));
  }

  void _applyPreset(PresetTemplate preset) {
    setState(() {
      _name = preset.name == '🍲 美食' ? '' : preset.name;
      _selectedColor = preset.color;
      _fields = preset.toFieldDefinitions();
    });
  }

  Future<void> _handleSave() async {
    if (_name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入项目名称'), backgroundColor: AppColors.danger),
      );
      return;
    }
    final data = DataScope.of(context);
    await data.addEvent(
      name: _name,
      icon: 'star',
      color: _selectedColor,
      customFields: _fields,
    );
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Dark Header ──
          Container(
            decoration: const BoxDecoration(
              color: AppColors.dark,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('新建项目',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                    SizedBox(height: 4),
                    Text('自定义你的打卡模板',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: AppColors.darkSoft, borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // ── Form ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Presets
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                    child: Text('快速创建',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  ),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: kPresets.map((p) => _PresetCard(preset: p, onTap: () => _applyPreset(p))).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.cardBorder)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('或者自定义',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const Expanded(child: Divider(color: AppColors.cardBorder)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Name input
                  _CardSection(
                    label: '项目名称',
                    child: TextField(
                      onChanged: (v) => setState(() => _name = v),
                      controller: TextEditingController(text: _name)..selection = TextSelection.collapsed(offset: _name.length),
                      decoration: InputDecoration(
                        hintText: '例如：坐飞机、吃火锅、读书...',
                        hintStyle: const TextStyle(color: AppColors.textMuted),
                        filled: true, fillColor: AppColors.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      ),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Color picker
                  _CardSection(
                    label: '颜色',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: AppColors.eventColorHexes.map((hex) {
                        final c = hexToColor(hex);
                        final selected = hex == _selectedColor;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = hex),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: c, shape: BoxShape.circle,
                              border: selected ? Border.all(color: Colors.white, width: 3) : null,
                              boxShadow: selected ? AppShadows.colored(c) : null,
                            ),
                            child: selected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Custom fields header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('自定义字段',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        Text('可选',
                            style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Field cards
                  ..._fields.map((field) => _FieldCard(
                        field: field,
                        onRemove: () => _removeField(field.id),
                        onNameChanged: (v) => _updateField(field.id, name: v),
                        onUnitChanged: (v) => _updateField(field.id, unit: v),
                      )),

                  // Add field buttons
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _AddFieldChip('+ 分类/地点', AppColors.success, const Color(0xFFECFDF5), const Color(0xFFA7F3D0),
                          () => _addField(FieldType.category, '')),
                      _AddFieldChip('+ 货币金额', AppColors.primary, const Color(0xFFEFF6FF), const Color(0xFFBFDBFE),
                          () => _addField(FieldType.cost, '¥')),
                      _AddFieldChip('+ 花费时长', const Color(0xFF7C3AED), const Color(0xFFF5F3FF), const Color(0xFFDDD6FE),
                          () => _addField(FieldType.duration, '分钟')),
                      _AddFieldChip('+ 长篇笔记', const Color(0xFFD97706), const Color(0xFFFEF3C7), const Color(0xFFFDE68A),
                          () => _addField(FieldType.notes, '')),
                      _AddFieldChip('+ 普通数值', AppColors.textSecondary, AppColors.bg, AppColors.cardBorder,
                          () => _addField(FieldType.number, '')),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Save button
                  GestureDetector(
                    onTap: _handleSave,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.dark,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: AppShadows.lg,
                      ),
                      alignment: Alignment.center,
                      child: const Text('保存项目',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub widgets ──

class _PresetCard extends StatelessWidget {
  final PresetTemplate preset;
  final VoidCallback onTap;
  const _PresetCard({required this.preset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = hexToColor(preset.color);
    final parts = preset.name.split(' ');
    final emoji = parts[0];
    final label = parts.sublist(1).join(' ');
    final w = (MediaQuery.of(context).size.width - 32 - 10) / 2;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: AppShadows.sm,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(height: 3, color: color),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text('${preset.fields.length} 个字段',
                            style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  final String label;
  final Widget child;
  const _CardSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final FieldDefinition field;
  final VoidCallback onRemove;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onUnitChanged;
  const _FieldCard({required this.field, required this.onRemove, required this.onNameChanged, required this.onUnitChanged});

  String get _typeLabel {
    switch (field.type) {
      case FieldType.category: return '分类/地点';
      case FieldType.cost: return '金额';
      case FieldType.duration: return '时长';
      case FieldType.notes: return '多行笔记';
      case FieldType.number: return '数字';
      case FieldType.text: return '文本';
    }
  }

  IconData get _typeIcon {
    switch (field.type) {
      case FieldType.category: return Icons.place;
      case FieldType.cost: return Icons.attach_money;
      case FieldType.duration: return Icons.schedule;
      case FieldType.notes: return Icons.notes;
      case FieldType.number: return Icons.tag;
      case FieldType.text: return Icons.short_text;
    }
  }

  Color get _typeColor {
    switch (field.type) {
      case FieldType.category: return AppColors.success;
      case FieldType.cost: return AppColors.primary;
      case FieldType.duration: return const Color(0xFF8B5CF6);
      case FieldType.notes: return const Color(0xFFF59E0B);
      case FieldType.number: return AppColors.textSecondary;
      case FieldType.text: return AppColors.textMuted;
    }
  }

  bool get _showUnitField =>
      ![FieldType.duration, FieldType.notes, FieldType.category, FieldType.text].contains(field.type);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(9999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_typeIcon, size: 13, color: _typeColor),
                    const SizedBox(width: 5),
                    Text(_typeLabel,
                        style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textSecondary, fontSize: 11, letterSpacing: 0.5)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(9999)),
                  child: const Icon(Icons.delete_outline, color: AppColors.danger, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: onNameChanged,
            decoration: InputDecoration(
              hintText: '字段名称',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true, fillColor: AppColors.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          if (_showUnitField) ...[
            const SizedBox(height: 10),
            TextField(
              onChanged: onUnitChanged,
              decoration: InputDecoration(
                hintText: '单位（例如：元、公斤）',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true, fillColor: AppColors.bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddFieldChip extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;
  const _AddFieldChip(this.label, this.textColor, this.bgColor, this.borderColor, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: borderColor),
        ),
        child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 14)),
      ),
    );
  }
}
