import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/storage_service.dart';

/// Global data provider (equivalent to useData hook in RN)
class DataProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();

  List<EventTemplate> _events = [];
  List<EventRecord> _records = [];
  bool _loading = true;

  List<EventTemplate> get events => _events;
  List<EventRecord> get records => _records;
  bool get loading => _loading;

  DataProvider() {
    loadData();
  }

  Future<void> loadData() async {
    _loading = true;
    notifyListeners();
    _events = await _storage.getEvents();
    _records = await _storage.getRecords();
    _loading = false;
    notifyListeners();
  }

  Future<void> addEvent({
    required String name,
    required String icon,
    required String color,
    required List<FieldDefinition> customFields,
  }) async {
    final event = EventTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      icon: icon,
      color: color,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      customFields: customFields,
    );
    await _storage.saveEvent(event);
    await loadData();
  }

  Future<void> addRecord(String eventId, Map<String, dynamic> fieldValues) async {
    final record = EventRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      eventId: eventId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      fieldValues: fieldValues,
    );
    await _storage.saveRecord(record);
    await loadData();
  }

  Future<void> deleteEvent(String eventId) async {
    await _storage.deleteEvent(eventId);
    await loadData();
  }

  Future<void> deleteRecord(String recordId) async {
    await _storage.deleteRecord(recordId);
    await loadData();
  }

  int recordCountFor(String eventId) =>
      _records.where((r) => r.eventId == eventId).length;

  List<EventRecord> recordsFor(String eventId) =>
      _records.where((r) => r.eventId == eventId).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
}

/// InheritedWidget wrapper so any descendant can access the provider
class DataScope extends InheritedNotifier<DataProvider> {
  const DataScope({
    super.key,
    required DataProvider provider,
    required super.child,
  }) : super(notifier: provider);

  static DataProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DataScope>()!.notifier!;
  }
}
