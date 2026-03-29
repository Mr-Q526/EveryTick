import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Local JSON persistence layer (mirrors core/storage.ts)
class StorageService {
  static const _eventsKey = '@times_tracker_events';
  static const _recordsKey = '@times_tracker_records';

  // ── Events ──

  Future<List<EventTemplate>> getEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_eventsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List<dynamic>;
    return list.map((e) => EventTemplate.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveEvent(EventTemplate event) async {
    final events = await getEvents();
    events.add(event);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eventsKey, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  Future<void> updateEvent(EventTemplate updated) async {
    final events = await getEvents();
    final idx = events.indexWhere((e) => e.id == updated.id);
    if (idx != -1) events[idx] = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eventsKey, jsonEncode(events.map((e) => e.toJson()).toList()));
  }

  Future<void> deleteEvent(String eventId) async {
    final events = await getEvents();
    events.removeWhere((e) => e.id == eventId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eventsKey, jsonEncode(events.map((e) => e.toJson()).toList()));
    // Also remove related records
    final records = await getRecords();
    records.removeWhere((r) => r.eventId == eventId);
    await prefs.setString(_recordsKey, jsonEncode(records.map((r) => r.toJson()).toList()));
  }

  // ── Records ──

  Future<List<EventRecord>> getRecords({String? eventId}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_recordsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List<dynamic>;
    final records = list.map((e) => EventRecord.fromJson(e as Map<String, dynamic>)).toList();
    if (eventId != null) return records.where((r) => r.eventId == eventId).toList();
    return records;
  }

  Future<void> saveRecord(EventRecord record) async {
    final records = await getRecords();
    records.add(record);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recordsKey, jsonEncode(records.map((r) => r.toJson()).toList()));
  }

  Future<void> deleteRecord(String recordId) async {
    final records = await getRecords();
    records.removeWhere((r) => r.id == recordId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recordsKey, jsonEncode(records.map((r) => r.toJson()).toList()));
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_eventsKey);
    await prefs.remove(_recordsKey);
  }
}
