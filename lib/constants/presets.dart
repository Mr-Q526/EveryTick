import '../models/models.dart';

/// Preset templates with category grouping for scalable menu display
class PresetTemplate {
  final String name;
  final String icon; // emoji character, e.g. '💪'
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

/// Category grouping for preset menu
class PresetCategory {
  final String name;
  final String icon;
  final List<PresetTemplate> presets;
  const PresetCategory({required this.name, required this.icon, required this.presets});
}

/// Curated emoji icons for event icon picker
const kIconPresets = [
  // Row 1: Sports & Fitness
  '💪', '🏃', '🧘', '🏊', '🚴', '⚽', '🏀', '🎾', '⛷️', '🏋️',
  // Row 2: Food & Drink
  '🍲', '☕', '🍺', '🧋', '🍕', '🍔', '🎂', '🍣', '🥗', '🍳',
  // Row 3: Travel & Transport
  '✈️', '🚄', '🚗', '🚢', '🏕️', '🏨', '🗺️', '📸', '🧳', '⛰️',
  // Row 4: Learning & Work
  '📖', '📝', '💻', '🎓', '🔬', '🎨', '🎸', '🎹', '💡', '📊',
  // Row 5: Daily Life & Habits
  '🌅', '💧', '💊', '💤', '🧹', '🧘', '🧴', '🚶', '🧘', '❤️',
  // Row 6: Entertainment & Social
  '🎬', '🎮', '🎵', '🎤', '📺', '🎲', '🎭', '🎪', '📱', '💬',
  // Row 7: Finance & Goals
  '💰', '🧧', '💳', '📈', '🎯', '🏆', '⭐', '🔥', '✅', '🌟',
];

const kPresetCategories = [
  // ── 运动健康 ──
  PresetCategory(
    name: '运动健康',
    icon: '💪',
    presets: [
      PresetTemplate(
        name: '💪 健身',
        icon: '💪',
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
      PresetTemplate(
        name: '🏃 跑步',
        icon: '🏃',
        color: '#3B82F6',
        fields: [
          _PresetField(type: FieldType.number, name: '距离', unit: '公里'),
          _PresetField(type: FieldType.duration, name: '用时', unit: '分钟'),
          _PresetField(type: FieldType.toggle, name: '是否破纪录'),
        ],
      ),
      PresetTemplate(
        name: '🧘 瑜伽',
        icon: '🧘',
        color: '#8B5CF6',
        fields: [
          _PresetField(type: FieldType.duration, name: '练习时长', unit: '分钟'),
          _PresetField(
            type: FieldType.singleSelect,
            name: '练习类型',
            options: ['哈他', '流瑜伽', '阴瑜伽', '热瑜伽', '冥想'],
          ),
        ],
      ),
      PresetTemplate(
        name: '💊 吃药',
        icon: '💊',
        color: '#EF4444',
        fields: [
          _PresetField(
            type: FieldType.multiSelect,
            name: '药物',
            options: ['维生素', '钙片', '鱼油', '益生菌'],
          ),
        ],
      ),
      PresetTemplate(
        name: '💤 睡眠',
        icon: '💤',
        color: '#6366F1',
        fields: [
          _PresetField(type: FieldType.duration, name: '睡眠时长', unit: '小时'),
          _PresetField(
            type: FieldType.singleSelect,
            name: '睡眠质量',
            options: ['很好', '一般', '较差', '失眠'],
          ),
        ],
      ),
      PresetTemplate(
        name: '💧 喝水',
        icon: '💧',
        color: '#06B6D4',
        fields: [
          _PresetField(type: FieldType.number, name: '饮水量', unit: 'ml'),
        ],
      ),
    ],
  ),

  // ── 生活记录 ──
  PresetCategory(
    name: '生活记录',
    icon: '🌟',
    presets: [
      PresetTemplate(
        name: '✈️ 起飞',
        icon: '✈️',
        color: '#3B82F6',
        fields: [
          _PresetField(type: FieldType.category, name: '航线'),
          _PresetField(type: FieldType.duration, name: '飞行时长', unit: '小时'),
        ],
      ),
      PresetTemplate(
        name: '🍲 美食',
        icon: '🍲',
        color: '#EF4444',
        fields: [
          _PresetField(type: FieldType.category, name: '地点/分类'),
          _PresetField(type: FieldType.cost, name: '金额', unit: '¥'),
          _PresetField(
            type: FieldType.singleSelect,
            name: '评分',
            options: ['⭐', '⭐⭐', '⭐⭐⭐', '⭐⭐⭐⭐', '⭐⭐⭐⭐⭐'],
          ),
        ],
      ),
      PresetTemplate(
        name: '🎬 观影',
        icon: '🎬',
        color: '#F59E0B',
        fields: [
          _PresetField(type: FieldType.text, name: '影片名称'),
          _PresetField(
            type: FieldType.singleSelect,
            name: '评分',
            options: ['⭐', '⭐⭐', '⭐⭐⭐', '⭐⭐⭐⭐', '⭐⭐⭐⭐⭐'],
          ),
          _PresetField(type: FieldType.notes, name: '短评'),
        ],
      ),
      PresetTemplate(
        name: '☕ 咖啡',
        icon: '☕',
        color: '#92400E',
        fields: [
          _PresetField(type: FieldType.category, name: '品牌/店铺'),
          _PresetField(type: FieldType.cost, name: '金额', unit: '¥'),
        ],
      ),
      PresetTemplate(
        name: '🎮 游戏',
        icon: '🎮',
        color: '#7C3AED',
        fields: [
          _PresetField(type: FieldType.text, name: '游戏名'),
          _PresetField(type: FieldType.duration, name: '游玩时长', unit: '小时'),
        ],
      ),
    ],
  ),

  // ── 学习成长 ──
  PresetCategory(
    name: '学习成长',
    icon: '📚',
    presets: [
      PresetTemplate(
        name: '📖 读书',
        icon: '📖',
        color: '#059669',
        fields: [
          _PresetField(type: FieldType.text, name: '书名'),
          _PresetField(type: FieldType.number, name: '页数', unit: '页'),
          _PresetField(type: FieldType.duration, name: '阅读时长', unit: '分钟'),
          _PresetField(type: FieldType.toggle, name: '读完了吗'),
        ],
      ),
      PresetTemplate(
        name: '📝 学习',
        icon: '📝',
        color: '#2563EB',
        fields: [
          _PresetField(
            type: FieldType.taggedValues,
            name: '学科',
            unit: '分钟',
            options: ['数学', '英语', '物理', '化学', '编程'],
          ),
        ],
      ),
      PresetTemplate(
        name: '🎸 练琴',
        icon: '🎸',
        color: '#DB2777',
        fields: [
          _PresetField(type: FieldType.duration, name: '练习时长', unit: '分钟'),
          _PresetField(type: FieldType.text, name: '练习曲目'),
        ],
      ),
    ],
  ),

  // ── 财务管理 ──
  PresetCategory(
    name: '财务管理',
    icon: '💰',
    presets: [
      PresetTemplate(
        name: '💰 日常开销',
        icon: '💰',
        color: '#F59E0B',
        fields: [
          _PresetField(
            type: FieldType.taggedValues,
            name: '支出分类',
            unit: '¥',
            options: ['餐饮', '交通', '购物', '娱乐', '居住'],
          ),
        ],
      ),
      PresetTemplate(
        name: '🧧 收入',
        icon: '🧧',
        color: '#10B981',
        fields: [
          _PresetField(type: FieldType.cost, name: '金额', unit: '¥'),
          _PresetField(type: FieldType.category, name: '来源'),
        ],
      ),
    ],
  ),

  // ── 习惯养成 ──
  PresetCategory(
    name: '习惯养成',
    icon: '🎯',
    presets: [
      PresetTemplate(
        name: '🌅 早起',
        icon: '🌅',
        color: '#F97316',
        fields: [
          _PresetField(
            type: FieldType.singleSelect,
            name: '起床时间段',
            options: ['5:00前', '5:00-6:00', '6:00-7:00', '7:00后'],
          ),
        ],
      ),
      PresetTemplate(
        name: '📵 戒手机',
        icon: '📵',
        color: '#64748B',
        fields: [
          _PresetField(type: FieldType.duration, name: '屏幕时间', unit: '小时'),
          _PresetField(type: FieldType.toggle, name: '达成目标'),
        ],
      ),
      PresetTemplate(
        name: '✍️ 日记',
        icon: '✍️',
        color: '#0891B2',
        fields: [
          _PresetField(type: FieldType.notes, name: '今日记录'),
          _PresetField(
            type: FieldType.singleSelect,
            name: '今日心情',
            options: ['😊 开心', '😐 平静', '😢 难过', '😤 沮丧', '🤩 兴奋'],
          ),
        ],
      ),
    ],
  ),
];

/// Flat preset list (backward compatible)
final kPresets = kPresetCategories.expand((c) => c.presets).toList();
