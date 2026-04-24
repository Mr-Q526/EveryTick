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
    try {
      _events = await _storage.getEvents();
      _records = await _storage.getRecords();
    } catch (e) {
      // Storage may fail on first launch; fall back to empty data
      _events = [];
      _records = [];
    }
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

  Future<void> addRecord(String eventId, Map<String, dynamic> fieldValues, {int? timestamp}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final record = EventRecord(
      id: now.toString(),
      eventId: eventId,
      timestamp: timestamp ?? now,
      fieldValues: fieldValues,
    );
    await _storage.saveRecord(record);
    await loadData();
  }

  Future<void> updateRecord({
    required String id,
    required Map<String, dynamic> fieldValues,
    int? timestamp,
  }) async {
    final existing = _records.firstWhere((r) => r.id == id);
    final updated = existing.copyWith(
      timestamp: timestamp ?? existing.timestamp,
      fieldValues: fieldValues,
    );
    await _storage.updateRecord(updated);
    await loadData();
  }

  Future<void> updateEvent({
    required String id,
    required String name,
    required String icon,
    required String color,
    required List<FieldDefinition> customFields,
  }) async {
    final existing = _events.firstWhere((e) => e.id == id);
    final updated = EventTemplate(
      id: existing.id,
      name: name,
      icon: icon,
      color: color,
      createdAt: existing.createdAt,
      customFields: customFields,
    );
    await _storage.updateEvent(updated);
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
