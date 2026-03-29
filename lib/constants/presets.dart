import '../models/models.dart';

/// Preset templates (mirrors constants/presets.ts)
class PresetTemplate {
  final String name;
  final String icon;
  final String color;
  final List<_PresetField> fields;

  const PresetTemplate({
    required this.name,
    required this.icon,
    required this.color,
    required this.fields,
  });

  List<FieldDefinition> toFieldDefinitions() {
    return fields.asMap().entries.map((e) {
      return FieldDefinition(
        id: (DateTime.now().millisecondsSinceEpoch + e.key).toString(),
        type: e.value.type,
        name: e.value.name,
        unit: e.value.unit,
        options: e.value.options,
      );
    }).toList();
  }
}

class _PresetField {
  final FieldType type;
  final String name;
  final String unit;
  final List<String> options;
  const _PresetField({required this.type, required this.name, this.unit = '', this.options = const []});
}

const kPresets = [
  PresetTemplate(
    name: '✈️ 起飞',
    icon: 'plane',
    color: '#3B82F6',
    fields: [
      _PresetField(type: FieldType.duration, name: '持续时间', unit: '分钟'),
    ],
  ),
  PresetTemplate(
    name: '🍲 美食',
    icon: 'utensils',
    color: '#EF4444',
    fields: [
      _PresetField(type: FieldType.category, name: '地点/分类'),
      _PresetField(type: FieldType.cost, name: '金额', unit: '¥'),
    ],
  ),
  PresetTemplate(
    name: '💪 健身',
    icon: 'dumbbell',
    color: '#10B981',
    fields: [
      _PresetField(
        type: FieldType.taggedValues,
        name: '训练部位',
        unit: '分钟',
        options: ['胸', '背', '腿', '肩', '手臂', '核心'],
      ),
    ],
  ),
];
