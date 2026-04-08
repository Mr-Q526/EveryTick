import 'package:flutter/material.dart';
import '../models/models.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';
import '../constants/presets.dart';
import 'event_editor_chrome.dart';

/// Edit Event screen — allows modifying project config after creation
class EditEventScreen extends StatefulWidget {
  final EventTemplate event;
  const EditEventScreen({super.key, required this.event});
  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  late String _name;
  late String _selectedIcon;
  late String _selectedColor;
  late List<FieldDefinition> _fields;

  @override
  void initState() {
    super.initState();
    _name = widget.event.name;
    _selectedIcon = widget.event.icon;
    _selectedColor = widget.event.color;
    // Deep-copy fields so edits don't mutate the original
    _fields = widget.event.customFields.map((f) => f.copyWith()).toList();
  }

  void _addField(
    FieldType type,
    String defaultUnit, {
    List<String> options = const [],
  }) {
    setState(() {
      _fields.add(
        FieldDefinition(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: type,
          name: '',
          unit: defaultUnit,
          options: options,
        ),
      );
    });
  }

  void _updateField(
    String id, {
    String? name,
    String? unit,
    List<String>? options,
  }) {
    setState(() {
      _fields = _fields.map((f) {
        if (f.id != id) return f;
        return f.copyWith(
          name: name ?? f.name,
          unit: unit ?? f.unit,
          options: options ?? f.options,
        );
      }).toList();
    });
  }

  void _removeField(String id) {
    setState(() => _fields.removeWhere((f) => f.id == id));
  }

  Future<void> _handleSave() async {
    if (_name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入项目名称'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    final data = DataScope.of(context);
    await data.updateEvent(
      id: widget.event.id,
      name: _name,
      icon: _selectedIcon,
      color: _selectedColor,
      customFields: _fields,
    );
    if (mounted) Navigator.pop(context, true); // return true = changed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eventEditorBg,
      body: EventEditorBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: EventEditorHeader(
                  title: '编辑项目',
                  subtitle: '修改打卡项目的配置',
                  mark: _selectedIcon,
                  color: hexToColor(_selectedColor),
                  onClose: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 4),

              // ── Form ──
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name input
                      _CardSection(
                        label: '项目名称',
                        child: TextField(
                          onChanged: (v) => setState(() => _name = v),
                          controller: TextEditingController(text: _name)
                            ..selection = TextSelection.collapsed(
                              offset: _name.length,
                            ),
                          decoration: InputDecoration(
                            hintText: '例如：坐飞机、吃火锅、读书...',
                            hintStyle: const TextStyle(
                              color: AppColors.textMuted,
                            ),
                            filled: true,
                            fillColor: eventEditorInputFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                eventEditorRadius,
                              ),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Icon picker
                      _CardSection(
                        label: '图标',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Current icon preview
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: hexToColor(
                                      _selectedColor,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _selectedIcon,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Text(
                                    '点击下方选择图标',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Emoji grid
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: kIconPresets.map((emoji) {
                                final selected = emoji == _selectedIcon;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedIcon = emoji),
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? hexToColor(
                                              _selectedColor,
                                            ).withValues(alpha: 0.15)
                                          : eventEditorInputFill,
                                      borderRadius: BorderRadius.circular(12),
                                      border: selected
                                          ? Border.all(
                                              color: hexToColor(_selectedColor),
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
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
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: selected
                                      ? Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        )
                                      : null,
                                  boxShadow: selected
                                      ? AppShadows.colored(c)
                                      : null,
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null,
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
                            const Text(
                              '自定义字段',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '可选',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Field cards
                      ..._fields.map(
                        (field) => _FieldCard(
                          field: field,
                          onRemove: () => _removeField(field.id),
                          onNameChanged: (v) => _updateField(field.id, name: v),
                          onUnitChanged: (v) => _updateField(field.id, unit: v),
                          onOptionsChanged: (v) =>
                              _updateField(field.id, options: v),
                        ),
                      ),

                      // Add field buttons
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _AddFieldChip(
                            '+ 分类/地点',
                            AppColors.success,
                            const Color(0xFFECFDF5),
                            const Color(0xFFA7F3D0),
                            () => _addField(FieldType.category, ''),
                          ),
                          _AddFieldChip(
                            '+ 货币金额',
                            AppColors.primary,
                            const Color(0xFFEFF6FF),
                            const Color(0xFFBFDBFE),
                            () => _addField(FieldType.cost, '¥'),
                          ),
                          _AddFieldChip(
                            '+ 花费时长',
                            const Color(0xFF7C3AED),
                            const Color(0xFFF5F3FF),
                            const Color(0xFFDDD6FE),
                            () => _addField(FieldType.duration, '分钟'),
                          ),
                          _AddFieldChip(
                            '+ 单选项',
                            const Color(0xFF0891B2),
                            const Color(0xFFECFEFF),
                            const Color(0xFFA5F3FC),
                            () => _addField(
                              FieldType.singleSelect,
                              '',
                              options: ['选项1', '选项2'],
                            ),
                          ),
                          _AddFieldChip(
                            '+ 多选项',
                            const Color(0xFF7C3AED),
                            const Color(0xFFF5F3FF),
                            const Color(0xFFDDD6FE),
                            () => _addField(
                              FieldType.multiSelect,
                              '',
                              options: ['标签1', '标签2'],
                            ),
                          ),
                          _AddFieldChip(
                            '+ 是否',
                            const Color(0xFFDB2777),
                            const Color(0xFFFDF2F8),
                            const Color(0xFFFBCFE8),
                            () => _addField(FieldType.toggle, ''),
                          ),
                          _AddFieldChip(
                            '+ 标签数值',
                            const Color(0xFF059669),
                            const Color(0xFFECFDF5),
                            const Color(0xFF6EE7B7),
                            () => _addField(
                              FieldType.taggedValues,
                              '分钟',
                              options: ['标签1', '标签2'],
                            ),
                          ),
                          _AddFieldChip(
                            '+ 长篇笔记',
                            const Color(0xFFD97706),
                            const Color(0xFFFEF3C7),
                            const Color(0xFFFDE68A),
                            () => _addField(FieldType.notes, ''),
                          ),
                          _AddFieldChip(
                            '+ 普通数值',
                            AppColors.textSecondary,
                            eventEditorInputFill,
                            eventEditorLine,
                            () => _addField(FieldType.number, ''),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Save button
                      EventEditorPrimaryButton(
                        label: '保存修改',
                        color: hexToColor(_selectedColor),
                        onTap: _handleSave,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub widgets — copied from NewEventScreen to keep each screen self-contained ──

class _CardSection extends StatelessWidget {
  final String label;
  final Widget child;
  const _CardSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return EventEditorGlassPanel(
      accent: AppColors.primary,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _FieldCard extends StatefulWidget {
  final FieldDefinition field;
  final VoidCallback onRemove;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onUnitChanged;
  final ValueChanged<List<String>> onOptionsChanged;
  const _FieldCard({
    required this.field,
    required this.onRemove,
    required this.onNameChanged,
    required this.onUnitChanged,
    required this.onOptionsChanged,
  });
  @override
  State<_FieldCard> createState() => _FieldCardState();
}

class _FieldCardState extends State<_FieldCard> {
  final _optionController = TextEditingController();
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.field.name);
    _unitController = TextEditingController(text: widget.field.unit);
  }

  String get _typeLabel {
    switch (widget.field.type) {
      case FieldType.category:
        return '分类/地点';
      case FieldType.cost:
        return '金额';
      case FieldType.duration:
        return '时长';
      case FieldType.notes:
        return '多行笔记';
      case FieldType.number:
        return '数字';
      case FieldType.text:
        return '文本';
      case FieldType.singleSelect:
        return '单选项';
      case FieldType.multiSelect:
        return '多选项';
      case FieldType.toggle:
        return '是否';
      case FieldType.taggedValues:
        return '标签数值';
    }
  }

  IconData get _typeIcon {
    switch (widget.field.type) {
      case FieldType.category:
        return Icons.place;
      case FieldType.cost:
        return Icons.attach_money;
      case FieldType.duration:
        return Icons.schedule;
      case FieldType.notes:
        return Icons.notes;
      case FieldType.number:
        return Icons.tag;
      case FieldType.text:
        return Icons.short_text;
      case FieldType.singleSelect:
        return Icons.radio_button_checked;
      case FieldType.multiSelect:
        return Icons.checklist;
      case FieldType.toggle:
        return Icons.toggle_on;
      case FieldType.taggedValues:
        return Icons.sell;
    }
  }

  Color get _typeColor {
    switch (widget.field.type) {
      case FieldType.category:
        return AppColors.success;
      case FieldType.cost:
        return AppColors.primary;
      case FieldType.duration:
        return const Color(0xFF8B5CF6);
      case FieldType.notes:
        return const Color(0xFFF59E0B);
      case FieldType.number:
        return AppColors.textSecondary;
      case FieldType.text:
        return AppColors.textMuted;
      case FieldType.singleSelect:
        return const Color(0xFF0891B2);
      case FieldType.multiSelect:
        return const Color(0xFF7C3AED);
      case FieldType.toggle:
        return const Color(0xFFDB2777);
      case FieldType.taggedValues:
        return const Color(0xFF059669);
    }
  }

  bool get _showUnitField => [
    FieldType.number,
    FieldType.cost,
    FieldType.taggedValues,
  ].contains(widget.field.type);

  bool get _showOptionsEditor => [
    FieldType.singleSelect,
    FieldType.multiSelect,
    FieldType.taggedValues,
  ].contains(widget.field.type);

  void _addOption() {
    final text = _optionController.text.trim();
    if (text.isEmpty) return;
    final updated = [...widget.field.options, text];
    widget.onOptionsChanged(updated);
    _optionController.clear();
  }

  void _removeOption(int index) {
    final updated = [...widget.field.options]..removeAt(index);
    widget.onOptionsChanged(updated);
  }

  @override
  void dispose() {
    _optionController.dispose();
    _nameController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EventEditorGlassPanel(
      margin: const EdgeInsets.only(bottom: 14),
      accent: _typeColor,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: eventEditorInputFill,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_typeIcon, size: 13, color: _typeColor),
                    const SizedBox(width: 5),
                    Text(
                      _typeLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: AppColors.danger,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            onChanged: widget.onNameChanged,
            decoration: InputDecoration(
              hintText: widget.field.type == FieldType.toggle
                  ? '例如：是否破纪录'
                  : '字段名称',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: eventEditorInputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(eventEditorRadius),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (_showUnitField) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _unitController,
              onChanged: widget.onUnitChanged,
              decoration: InputDecoration(
                hintText: '单位（例如：元、公斤）',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: eventEditorInputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(eventEditorRadius),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          // Options editor for singleSelect / multiSelect
          if (_showOptionsEditor) ...[
            const SizedBox(height: 14),
            const Text(
              '候选项',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.field.options.asMap().entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _typeColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _typeColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _removeOption(e.key),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: _typeColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _optionController,
                    onSubmitted: (_) => _addOption(),
                    decoration: InputDecoration(
                      hintText: '输入选项名，回车添加',
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: eventEditorInputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(eventEditorRadius),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addOption,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _typeColor,
                      borderRadius: BorderRadius.circular(eventEditorRadius),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ],
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
  const _AddFieldChip(
    this.label,
    this.textColor,
    this.bgColor,
    this.borderColor,
    this.onTap,
  );

  @override
  Widget build(BuildContext context) {
    return EventEditorPressableScale(
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(eventEditorRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(eventEditorRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(eventEditorRadius),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
