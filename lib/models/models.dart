// EveryTick (万物打卡) data models.

enum FieldType {
  number,
  text,
  duration,
  category,
  cost,
  notes,
  singleSelect,
  multiSelect,
  toggle,
  taggedValues;

  static FieldType fromString(String s) => FieldType.values.firstWhere(
    (e) => e.name == s,
    orElse: () => FieldType.text,
  );
}

class FieldDefinition {
  final String id;
  final FieldType type;
  final String name;
  final String unit;
  final List<String> options; // for singleSelect / multiSelect

  FieldDefinition({
    required this.id,
    required this.type,
    required this.name,
    this.unit = '',
    this.options = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'unit': unit,
    if (options.isNotEmpty) 'options': options,
  };

  factory FieldDefinition.fromJson(Map<String, dynamic> json) =>
      FieldDefinition(
        id: json['id'] as String,
        type: FieldType.fromString(json['type'] as String),
        name: json['name'] as String,
        unit: json['unit'] as String? ?? '',
        options:
            (json['options'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  FieldDefinition copyWith({
    String? id,
    FieldType? type,
    String? name,
    String? unit,
    List<String>? options,
  }) => FieldDefinition(
    id: id ?? this.id,
    type: type ?? this.type,
    name: name ?? this.name,
    unit: unit ?? this.unit,
    options: options ?? this.options,
  );
}

class EventTemplate {
  final String id;
  final String name;
  final String icon;
  final String color; // hex string like '#3B82F6'
  final int createdAt;
  final List<FieldDefinition> customFields;

  EventTemplate({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.createdAt,
    required this.customFields,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'color': color,
    'created_at': createdAt,
    'custom_fields': customFields.map((f) => f.toJson()).toList(),
  };

  factory EventTemplate.fromJson(Map<String, dynamic> json) => EventTemplate(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String? ?? 'star',
    color: json['color'] as String? ?? '#3B82F6',
    createdAt: json['created_at'] as int? ?? 0,
    customFields:
        (json['custom_fields'] as List<dynamic>?)
            ?.map((e) => FieldDefinition.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

class EventRecord {
  final String id;
  final String eventId;
  final int timestamp;
  final Map<String, dynamic>
  fieldValues; // values can be String, num, bool, List<String>, or null

  EventRecord({
    required this.id,
    required this.eventId,
    required this.timestamp,
    required this.fieldValues,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'event_id': eventId,
    'timestamp': timestamp,
    'field_values': fieldValues,
  };

  factory EventRecord.fromJson(Map<String, dynamic> json) => EventRecord(
    id: json['id'] as String,
    eventId: json['event_id'] as String,
    timestamp: json['timestamp'] as int? ?? 0,
    fieldValues: Map<String, dynamic>.from(json['field_values'] as Map? ?? {}),
  );

  EventRecord copyWith({
    String? id,
    String? eventId,
    int? timestamp,
    Map<String, dynamic>? fieldValues,
  }) => EventRecord(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    timestamp: timestamp ?? this.timestamp,
    fieldValues: fieldValues ?? this.fieldValues,
  );
}
