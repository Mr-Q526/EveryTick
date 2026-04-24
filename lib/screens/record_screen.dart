import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../providers/data_provider.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';
import 'event_editor_chrome.dart';

class RecordScreenArgs {
  final String eventId;
  final String? recordId;

  const RecordScreenArgs({required this.eventId, this.recordId});
}

/// Record entry screen — mirrors app/record/[eventId].tsx
class RecordScreen extends StatefulWidget {
  final String eventId;
  final String? recordId;
  final bool modalPresentation;

  const RecordScreen({
    super.key,
    required this.eventId,
    this.recordId,
    this.modalPresentation = false,
  });

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final Map<String, dynamic> _formValues = {};
  DateTime _selectedTime = DateTime.now();
  bool _isRetroactive = false; // 补打卡模式
  bool _didPrefill = false;
  bool _saving = false;
  bool _showSuccess = false;
  String _successLabel = '打卡成功';

  EventTemplate? _event;
  EventRecord? _editingRecord;

  bool get _isEditing => _editingRecord != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final data = DataScope.of(context);
    EventTemplate? foundEvent;
    for (final event in data.events) {
      if (event.id == widget.eventId) {
        foundEvent = event;
        break;
      }
    }
    _event = foundEvent;

    if (_didPrefill || foundEvent == null) {
      return;
    }

    if (widget.recordId != null) {
      for (final record in data.records) {
        if (record.id == widget.recordId) {
          _editingRecord = record;
          _selectedTime = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
          _isRetroactive = true;
          _seedFormValues(foundEvent, record);
          break;
        }
      }
    }

    _didPrefill = true;
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTime),
    );
    if (time == null || !mounted) return;
    setState(() {
      _selectedTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _isRetroactive = true;
    });
  }

  Future<void> _handleSave() async {
    if (_saving) {
      return;
    }
    final event = _event!;
    final data = DataScope.of(context);
    final parsed = <String, dynamic>{};
    for (final field in event.customFields) {
      final val = _formValues[field.id];
      if (field.type == FieldType.toggle) {
        parsed[field.id] = val == true;
      } else if (field.type == FieldType.multiSelect) {
        parsed[field.id] = val is List ? val : <String>[];
      } else if (field.type == FieldType.singleSelect) {
        parsed[field.id] = val is String && val.isNotEmpty ? val : null;
      } else if (field.type == FieldType.taggedValues) {
        // Store as Map<String, num>
        parsed[field.id] = val is Map ? val : <String, dynamic>{};
      } else if (val == null || (val is String && val.trim().isEmpty)) {
        parsed[field.id] = null;
      } else if ([
        FieldType.number,
        FieldType.duration,
        FieldType.cost,
      ].contains(field.type)) {
        parsed[field.id] = num.tryParse(val as String) ?? 0;
      } else {
        parsed[field.id] = val;
      }
    }
    setState(() => _saving = true);
    if (_isEditing) {
      await data.updateRecord(
        id: _editingRecord!.id,
        fieldValues: parsed,
        timestamp: _selectedTime.millisecondsSinceEpoch,
      );
      await _playSuccessAndClose('修改已保存');
      return;
    }
    await data.addRecord(
      event.id,
      parsed,
      timestamp: _selectedTime.millisecondsSinceEpoch,
    );
    await _playSuccessAndClose('打卡成功 +1');
  }

  Future<void> _handleSkip() async {
    if (_saving) {
      return;
    }
    final data = DataScope.of(context);
    setState(() => _saving = true);
    await data.addRecord(
      _event!.id,
      {},
      timestamp: _selectedTime.millisecondsSinceEpoch,
    );
    await _playSuccessAndClose('打卡成功 +1');
  }

  Future<void> _handleDelete() async {
    final record = _editingRecord;
    if (record == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这次打卡'),
        content: const Text('确定删除这条记录吗？删除后不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '删除',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await DataScope.of(context).deleteRecord(record.id);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _playSuccessAndClose(String label) async {
    if (!(widget.modalPresentation && !_isEditing)) {
      await HapticService.recordSaved();
    }
    if (widget.modalPresentation) {
      if (mounted) {
        Navigator.pop(context, true);
      }
      return;
    }
    if (mounted) {
      setState(() {
        _showSuccess = true;
        _successLabel = label;
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 820));
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _seedFormValues(EventTemplate event, EventRecord record) {
    for (final field in event.customFields) {
      final raw = record.fieldValues[field.id];
      switch (field.type) {
        case FieldType.toggle:
          _formValues[field.id] = raw == true;
          break;
        case FieldType.multiSelect:
          _formValues[field.id] = raw is List
              ? raw.whereType<String>().toList()
              : <String>[];
          break;
        case FieldType.singleSelect:
        case FieldType.category:
        case FieldType.text:
        case FieldType.notes:
          _formValues[field.id] = raw is String ? raw : (raw?.toString() ?? '');
          break;
        case FieldType.taggedValues:
          _formValues[field.id] = raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};
          break;
        case FieldType.number:
        case FieldType.duration:
        case FieldType.cost:
          _formValues[field.id] = _editableString(raw);
          break;
      }
    }
  }

  String _editableString(dynamic raw) {
    if (raw == null) {
      return '';
    }
    if (raw is int) {
      return raw.toString();
    }
    if (raw is double) {
      return raw == raw.roundToDouble()
          ? raw.round().toString()
          : raw.toString();
    }
    return raw.toString();
  }

  @override
  Widget build(BuildContext context) {
    final event = _event;
    if (event == null) {
      return const Scaffold(
        backgroundColor: eventEditorBg,
        body: EventEditorBackground(
          child: Center(
            child: Text('加载中...', style: TextStyle(color: AppColors.textMuted)),
          ),
        ),
      );
    }

    final color = hexToColor(event.color);
    final timeStr = DateFormat('yyyy-MM-dd HH:mm').format(_selectedTime);
    final content = _RecordScreenScaffold(
      event: event,
      color: color,
      timeStr: timeStr,
      isEditing: _isEditing,
      isRetroactive: _isRetroactive,
      saving: _saving,
      showSuccess: _showSuccess,
      successLabel: _successLabel,
      onClose: () => Navigator.pop(context),
      onPickDateTime: _pickDateTime,
      onSave: _handleSave,
      onSkip: _handleSkip,
      onDelete: _handleDelete,
      fields: event.customFields.isEmpty
          ? [_EmptyFieldHint(color: color)]
          : event.customFields.map((field) => _buildFieldInput(field, color)).toList(),
    );

    if (widget.modalPresentation) {
      return Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: FractionallySizedBox(
                  heightFactor: 0.88,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(eventEditorRadius),
                      border: Border.all(color: eventEditorLine),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 30,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(eventEditorRadius),
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(backgroundColor: eventEditorBg, body: content);
  }

  Widget _buildFieldInput(FieldDefinition field, Color eventColor) {
    switch (field.type) {
      case FieldType.toggle:
        return _ToggleInput(
          field: field,
          value: _formValues[field.id] == true,
          onChanged: (v) => setState(() => _formValues[field.id] = v),
        );
      case FieldType.singleSelect:
        return _SingleSelectInput(
          field: field,
          selected: _formValues[field.id] as String? ?? '',
          onChanged: (v) => setState(() => _formValues[field.id] = v),
        );
      case FieldType.multiSelect:
        return _MultiSelectInput(
          field: field,
          selected: (_formValues[field.id] as List<String>?) ?? [],
          onChanged: (v) => setState(() => _formValues[field.id] = v),
        );
      case FieldType.taggedValues:
        return _TaggedValuesInput(
          field: field,
          values: (_formValues[field.id] as Map<String, dynamic>?) ?? {},
          onChanged: (v) => setState(() => _formValues[field.id] = v),
        );
      default:
        return _TextFieldInput(
          field: field,
          value: (_formValues[field.id] as String?) ?? '',
          onChanged: (v) => setState(() => _formValues[field.id] = v),
        );
    }
  }
}

class _RecordScreenScaffold extends StatelessWidget {
  final EventTemplate event;
  final Color color;
  final String timeStr;
  final bool isEditing;
  final bool isRetroactive;
  final bool saving;
  final bool showSuccess;
  final String successLabel;
  final VoidCallback onClose;
  final VoidCallback onPickDateTime;
  final VoidCallback onSave;
  final VoidCallback onSkip;
  final VoidCallback onDelete;
  final List<Widget> fields;

  const _RecordScreenScaffold({
    required this.event,
    required this.color,
    required this.timeStr,
    required this.isEditing,
    required this.isRetroactive,
    required this.saving,
    required this.showSuccess,
    required this.successLabel,
    required this.onClose,
    required this.onPickDateTime,
    required this.onSave,
    required this.onSkip,
    required this.onDelete,
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        EventEditorBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: EventEditorHeader(
                    title: event.name,
                    subtitle: isEditing ? '修改这次打卡的数据' : '填写本次打卡的详细信息',
                    mark:
                        event.icon.isNotEmpty && event.icon.characters.length == 1
                        ? event.icon
                        : event.name.characters.first,
                    color: color,
                    onClose: onClose,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: onPickDateTime,
                          child: EventEditorGlassPanel(
                            margin: const EdgeInsets.only(bottom: 16),
                            accent: color,
                            borderColor: isRetroactive
                                ? color.withValues(alpha: 0.3)
                                : eventEditorLine,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  isRetroactive ? Icons.history : Icons.access_time,
                                  size: 18,
                                  color: isRetroactive
                                      ? color
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEditing
                                            ? '记录时间'
                                            : isRetroactive
                                            ? '补打卡'
                                            : '打卡时间',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isRetroactive
                                              ? color
                                              : AppColors.textMuted,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: isRetroactive
                                              ? color
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '点击修改',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isRetroactive
                                        ? color
                                        : AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ...fields,
                        const SizedBox(height: 16),
                        EventEditorPrimaryButton(
                          label: saving
                              ? (isEditing ? '保存中...' : '提交中...')
                              : isEditing
                              ? '保存修改'
                              : isRetroactive
                              ? '补打卡 (+1)'
                              : '保存打卡 (+1)',
                          color: color,
                          onTap: onSave,
                        ),
                        if (!isEditing) ...[
                          const SizedBox(height: 12),
                          EventEditorPressableScale(
                            child: Material(
                              color: Colors.white.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(eventEditorRadius),
                              child: InkWell(
                                onTap: onSkip,
                                borderRadius: BorderRadius.circular(
                                  eventEditorRadius,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      eventEditorRadius,
                                    ),
                                    border: Border.all(color: eventEditorLine),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '跳过字段，直接 +1',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 12),
                          EventEditorPressableScale(
                            child: Material(
                              color: Colors.white.withValues(alpha: 0.82),
                              borderRadius: BorderRadius.circular(eventEditorRadius),
                              child: InkWell(
                                onTap: onDelete,
                                borderRadius: BorderRadius.circular(
                                  eventEditorRadius,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      eventEditorRadius,
                                    ),
                                    border: Border.all(
                                      color: AppColors.danger.withValues(alpha: 0.24),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Text(
                                    '删除这次记录',
                                    style: TextStyle(
                                      color: AppColors.danger,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: onClose,
                          child: const Text(
                            '取消',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showSuccess)
          Positioned.fill(
            child: IgnorePointer(
              child: _RecordSuccessOverlay(color: color, label: successLabel),
            ),
          ),
      ],
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
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: eventEditorLine),
          ),
          child: Icon(Icons.bolt, color: color, size: 28),
        ),
        const SizedBox(height: 16),
        const Text(
          '无需填写字段，直接点击打卡即可！',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RecordSuccessOverlay extends StatelessWidget {
  final Color color;
  final String label;

  const _RecordSuccessOverlay({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final rise = 22 * (1 - value);
        return Container(
          color: Colors.white.withValues(alpha: 0.18 * value),
          alignment: Alignment.center,
          child: Transform.translate(
            offset: Offset(0, rise),
            child: Opacity(
              opacity: value.clamp(0, 1),
              child: child,
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 122,
            height: 122,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
                stops: const [0.2, 0.62, 1],
              ),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(Icons.check_rounded, color: color, size: 42),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            label,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '这一下很顺',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle (是否) field - Switch
class _ToggleInput extends StatelessWidget {
  final FieldDefinition field;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleInput({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFDB2777);
    return EventEditorGlassPanel(
      margin: const EdgeInsets.only(bottom: 16),
      accent: color,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(height: 3, color: color),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Icon(Icons.toggle_on, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    field.name.isEmpty ? '是否' : field.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeTrackColor: color,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// SingleSelect field - Radio-like chips
class _SingleSelectInput extends StatelessWidget {
  final FieldDefinition field;
  final String selected;
  final ValueChanged<String> onChanged;
  const _SingleSelectInput({
    required this.field,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF0891B2);
    return EventEditorGlassPanel(
      margin: const EdgeInsets.only(bottom: 16),
      accent: color,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 3, color: color),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.radio_button_checked,
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      field.name.isEmpty ? '单选项' : field.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '点击选择一项',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: field.options.map((opt) {
                    final isSelected = opt == selected;
                    return GestureDetector(
                      onTap: () => onChanged(isSelected ? '' : opt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? color : eventEditorInputFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? color : eventEditorLine,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// MultiSelect field - Checkbox-like chips
class _MultiSelectInput extends StatelessWidget {
  final FieldDefinition field;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  const _MultiSelectInput({
    required this.field,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF7C3AED);
    return EventEditorGlassPanel(
      margin: const EdgeInsets.only(bottom: 16),
      accent: color,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 3, color: color),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.checklist, size: 14, color: color),
                    const SizedBox(width: 8),
                    Text(
                      field.name.isEmpty ? '多选项' : field.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '已选 ${selected.length} 项',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: field.options.map((opt) {
                    final isSelected = selected.contains(opt);
                    return GestureDetector(
                      onTap: () {
                        final updated = [...selected];
                        if (isSelected) {
                          updated.remove(opt);
                        } else {
                          updated.add(opt);
                        }
                        onChanged(updated);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? color : eventEditorInputFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? color : eventEditorLine,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              opt,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// TaggedValues field — multi-select with per-option numeric input
class _TaggedValuesInput extends StatelessWidget {
  final FieldDefinition field;
  final Map<String, dynamic> values;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const _TaggedValuesInput({
    required this.field,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF059669);
    final selectedTags = values.keys.toList();
    // Calculate total
    num total = 0;
    for (var v in values.values) {
      if (v is num) total += v;
    }

    return EventEditorGlassPanel(
      margin: const EdgeInsets.only(bottom: 16),
      accent: color,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 3, color: color),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sell, size: 14, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        field.name.isEmpty ? '标签数值' : field.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (total > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '合计 $total${field.unit}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '点击标签选择，输入${field.unit.isNotEmpty ? field.unit : "数值"}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 14),

                // Tag chips
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: field.options.map((opt) {
                    final isSelected = selectedTags.contains(opt);
                    return GestureDetector(
                      onTap: () {
                        final updated = Map<String, dynamic>.from(values);
                        if (isSelected) {
                          updated.remove(opt);
                        } else {
                          updated[opt] = 0;
                        }
                        onChanged(updated);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? color : eventEditorInputFill,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? color : eventEditorLine,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              opt,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Per-tag value inputs
                if (selectedTags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(color: eventEditorLine),
                  const SizedBox(height: 12),
                  ...selectedTags.map(
                    (tag) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: values[tag]?.toString() ?? '',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]'),
                                ),
                              ],
                              onChanged: (v) {
                                final updated = Map<String, dynamic>.from(
                                  values,
                                );
                                updated[tag] = num.tryParse(v) ?? 0;
                                onChanged(updated);
                              },
                              decoration: InputDecoration(
                                hintText: '0',
                                hintStyle: const TextStyle(
                                  color: AppColors.textLight,
                                ),
                                suffixText: field.unit,
                                suffixStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
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
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Text/Number/Duration/Cost/Category/Notes field input
class _TextFieldInput extends StatefulWidget {
  final FieldDefinition field;
  final String value;
  final ValueChanged<String> onChanged;
  const _TextFieldInput({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_TextFieldInput> createState() => _TextFieldInputState();
}

class _TextFieldInputState extends State<_TextFieldInput> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isNotes => widget.field.type == FieldType.notes;
  bool get _isText => widget.field.type == FieldType.text;

  IconData get _icon {
    switch (widget.field.type) {
      case FieldType.number:
        return Icons.tag;
      case FieldType.text:
        return Icons.short_text;
      case FieldType.duration:
        return Icons.schedule;
      case FieldType.category:
        return Icons.place;
      case FieldType.cost:
        return Icons.attach_money;
      case FieldType.notes:
        return Icons.edit_note;
      default:
        return Icons.short_text;
    }
  }

  Color get _color {
    switch (widget.field.type) {
      case FieldType.number:
        return AppColors.textSecondary;
      case FieldType.text:
        return AppColors.textMuted;
      case FieldType.duration:
        return const Color(0xFF8B5CF6);
      case FieldType.category:
        return AppColors.success;
      case FieldType.cost:
        return AppColors.primary;
      case FieldType.notes:
        return const Color(0xFFF59E0B);
      default:
        return AppColors.textMuted;
    }
  }

  String get _hint {
    switch (widget.field.type) {
      case FieldType.number:
        return '普通记录 — 请输入数值';
      case FieldType.text:
        return '文本 — 请输入一段话';
      case FieldType.duration:
        return '时长记录 — 请输入长短';
      case FieldType.category:
        return '分类/地点 — (会自动生成排行)';
      case FieldType.cost:
        return '金额记录 — 请输入开支';
      case FieldType.notes:
        return '日记 / 长篇笔记';
      default:
        return '请输入...';
    }
  }

  bool get _isNumeric => [
    FieldType.number,
    FieldType.duration,
    FieldType.cost,
  ].contains(widget.field.type);

  String get _hintBody {
    if (_isNotes) return '今天发生了什么？写下你的想法…';
    if (_isText) return '请输入…';
    return '0';
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _ctrl.text.length;

    return EventEditorGlassPanel(
      margin: const EdgeInsets.only(bottom: 16),
      accent: _color,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 3, color: _color),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────
                Row(
                  children: [
                    Icon(_icon, size: 13, color: _color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${widget.field.name}${widget.field.unit.isNotEmpty ? "  (${widget.field.unit})" : ""}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Text(
                      _hint,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Input ──────────────────────────────────────────
                TextField(
                  controller: _ctrl,
                  onChanged: widget.onChanged,
                  keyboardType: _isNumeric
                      ? TextInputType.number
                      : TextInputType.multiline,
                  textInputAction: (_isNotes || _isText)
                      ? TextInputAction.newline
                      : TextInputAction.done,
                  inputFormatters: _isNumeric
                      ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
                      : null,
                  maxLines: _isNotes ? null : (_isText ? 4 : 1),
                  minLines: _isNotes ? 8 : 1,
                  cursorColor: _color,
                  decoration: InputDecoration(
                    hintText: _hintBody,
                    hintStyle: TextStyle(
                      color: AppColors.textLight,
                      fontSize: _isNotes ? 16 : 18,
                      fontWeight: FontWeight.w400,
                      height: _isNotes ? 1.7 : 1.4,
                    ),
                    filled: true,
                    fillColor: eventEditorInputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(eventEditorRadius),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(eventEditorRadius),
                      borderSide: BorderSide(color: _color.withValues(alpha: 0.4), width: 1.5),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: _isNotes ? 18 : 16,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: _isNotes ? 16 : 18,
                    fontWeight: _isNotes ? FontWeight.w400 : FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: _isNotes ? 1.75 : 1.4,
                  ),
                ),

                // ── Word count (notes only) ────────────────────────
                if (_isNotes) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$charCount 字',
                        style: TextStyle(
                          fontSize: 11,
                          color: charCount > 0
                              ? _color.withValues(alpha: 0.8)
                              : AppColors.textLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
