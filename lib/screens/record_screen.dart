import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../providers/data_provider.dart';
import '../theme/app_theme.dart';

/// Record entry screen — mirrors app/record/[eventId].tsx
class RecordScreen extends StatefulWidget {
  final String eventId;
  const RecordScreen({super.key, required this.eventId});
  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final Map<String, String> _formValues = {};

  EventTemplate? _event;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final data = DataScope.of(context);
    _event = data.events.firstWhere((e) => e.id == widget.eventId, orElse: () => _event!);
  }

  Future<void> _handleSave() async {
    final event = _event!;
    final data = DataScope.of(context);
    final parsed = <String, dynamic>{};
    for (final field in event.customFields) {
      final val = _formValues[field.id];
      if (val == null || val.trim().isEmpty) {
        parsed[field.id] = null;
      } else if ([FieldType.number, FieldType.duration, FieldType.cost].contains(field.type)) {
        parsed[field.id] = num.tryParse(val) ?? 0;
      } else {
        parsed[field.id] = val;
      }
    }
    await data.addRecord(event.id, parsed);
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  Future<void> _handleSkip() async {
    final data = DataScope.of(context);
    await data.addRecord(_event!.id, {});
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    if (event == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Text('加载中...', style: TextStyle(color: AppColors.textMuted))),
      );
    }

    final color = hexToColor(event.color);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Dark header ──
          Container(
            color: AppColors.dark,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      alignment: Alignment.center,
                      child: Text(event.name.characters.first,
                          style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900)),
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
                const SizedBox(height: 16),
                Text(event.name,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                const Text('填写本次打卡的详细信息',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 18),
                Container(height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              ],
            ),
          ),

          // ── Form ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                children: [
                  if (event.customFields.isEmpty)
                    _EmptyFieldHint(color: color)
                  else
                    ...event.customFields.map((field) => _FieldInput(
                          field: field,
                          value: _formValues[field.id] ?? '',
                          onChanged: (v) => setState(() => _formValues[field.id] = v),
                        )),

                  // Save button
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _handleSave,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: AppShadows.colored(color),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check, color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          const Text('保存打卡 (+1)',
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),

                  // Skip button
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _handleSkip,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.cardBorder, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: const Text('跳过字段，直接 +1',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),

                  // Cancel
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消', style: TextStyle(color: AppColors.textMuted, fontSize: 15, fontWeight: FontWeight.w600)),
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

class _EmptyFieldHint extends StatelessWidget {
  final Color color;
  const _EmptyFieldHint({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(36), boxShadow: AppShadows.sm),
          child: Icon(Icons.bolt, color: color, size: 28),
        ),
        const SizedBox(height: 16),
        const Text('无需填写字段，直接点击打卡即可！',
            style: TextStyle(color: AppColors.textMuted, fontSize: 15, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _FieldInput extends StatelessWidget {
  final FieldDefinition field;
  final String value;
  final ValueChanged<String> onChanged;
  const _FieldInput({required this.field, required this.value, required this.onChanged});

  IconData get _icon {
    switch (field.type) {
      case FieldType.number: return Icons.tag;
      case FieldType.text: return Icons.short_text;
      case FieldType.duration: return Icons.schedule;
      case FieldType.category: return Icons.place;
      case FieldType.cost: return Icons.attach_money;
      case FieldType.notes: return Icons.notes;
    }
  }

  Color get _color {
    switch (field.type) {
      case FieldType.number: return AppColors.textSecondary;
      case FieldType.text: return AppColors.textMuted;
      case FieldType.duration: return const Color(0xFF8B5CF6);
      case FieldType.category: return AppColors.success;
      case FieldType.cost: return AppColors.primary;
      case FieldType.notes: return const Color(0xFFF59E0B);
    }
  }

  String get _hint {
    switch (field.type) {
      case FieldType.number: return '普通记录 — 请输入数值';
      case FieldType.text: return '单行文本 — 请输入一段话';
      case FieldType.duration: return '时长记录 — 请输入长短';
      case FieldType.category: return '分类/地点 — (会自动生成排行)';
      case FieldType.cost: return '金额记录 — 请输入开支';
      case FieldType.notes: return '长篇笔记 — (纯文本记录流)';
    }
  }

  bool get _isNumeric => [FieldType.number, FieldType.duration, FieldType.cost].contains(field.type);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadows.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 3, color: _color),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${field.name} ${field.unit.isNotEmpty ? "(${field.unit})" : ""}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(_icon, size: 12, color: _color),
                    const SizedBox(width: 5),
                    Text(_hint, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: onChanged,
                  keyboardType: _isNumeric ? TextInputType.number : TextInputType.text,
                  inputFormatters: _isNumeric ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))] : null,
                  maxLines: field.type == FieldType.notes ? null : 1,
                  minLines: field.type == FieldType.notes ? 3 : 1,
                  decoration: InputDecoration(
                    hintText: _isNumeric ? '0' : '请输入...',
                    hintStyle: const TextStyle(color: AppColors.textLight),
                    filled: true, fillColor: AppColors.bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  ),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
