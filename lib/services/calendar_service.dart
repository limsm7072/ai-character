import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/calendar_event.dart';
import '../models/work_type.dart';

class CalendarService {
  static const _key = 'calendar_events_data';
  static const _workTypesKey = 'work_types';
  static const _workTypeDatesKey = 'work_type_dates';
  final SharedPreferences _prefs;
  List<CalendarEvent> _events = [];
  List<WorkType> _workTypes = [];
  Map<String, String> _workTypeDates = {}; // date → workTypeId

  CalendarService(this._prefs) {
    _load();
  }

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      _events = CalendarEvent.decode(raw);
    }
    // Load work types
    final wtRaw = _prefs.getString(_workTypesKey);
    if (wtRaw != null && wtRaw.isNotEmpty) {
      _workTypes = WorkType.decode(wtRaw);
    }
    // Load date → workType mapping
    final wdRaw = _prefs.getString(_workTypeDatesKey);
    if (wdRaw != null && wdRaw.isNotEmpty) {
      try {
        _workTypeDates = (jsonDecode(wdRaw) as Map).cast<String, String>();
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    await _prefs.setString(_key, CalendarEvent.encode(_events));
  }

  List<CalendarEvent> getAll() => List.unmodifiable(_events);

  List<CalendarEvent> getByDate(String date) =>
      _events.where((e) => e.date == date).toList()
        ..sort((a, b) {
          final aTime = (a.startHour ?? 99) * 60 + (a.startMinute ?? 0);
          final bTime = (b.startHour ?? 99) * 60 + (b.startMinute ?? 0);
          return aTime.compareTo(bTime);
        });

  Set<String> getDatesWithEvents() => _events.map((e) => e.date).toSet();

  List<CalendarEvent> getUpcoming({int limit = 5}) {
    final today = _todayStr();
    final upcoming = _events.where((e) => e.date.compareTo(today) >= 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return upcoming.take(limit).toList();
  }

  int countByDate(String date) => _events.where((e) => e.date == date).length;

  Future<CalendarEvent> add(CalendarEvent event) async {
    _events.add(event);
    await _save();
    return event;
  }

  Future<void> update(CalendarEvent event) async {
    final idx = _events.indexWhere((e) => e.id == event.id);
    if (idx >= 0) {
      _events[idx] = event;
      await _save();
    }
  }

  Future<void> delete(String id) async {
    _events.removeWhere((e) => e.id == id);
    await _save();
  }

  /// Get all D-Day events, sorted by date (nearest first).
  List<CalendarEvent> getDDayEvents() {
    return _events.where((e) => e.isDDay).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ─── Work Type ──────────────────────────────────────

  List<WorkType> getWorkTypes() => List.unmodifiable(_workTypes);

  WorkType? getWorkTypeById(String id) {
    final idx = _workTypes.indexWhere((w) => w.id == id);
    return idx >= 0 ? _workTypes[idx] : null;
  }

  Future<void> addWorkType(WorkType wt) async {
    _workTypes.add(wt);
    await _prefs.setString(_workTypesKey, WorkType.encode(_workTypes));
  }

  Future<void> updateWorkType(WorkType wt) async {
    final idx = _workTypes.indexWhere((w) => w.id == wt.id);
    if (idx >= 0) {
      _workTypes[idx] = wt;
      await _prefs.setString(_workTypesKey, WorkType.encode(_workTypes));
    }
  }

  Future<void> deleteWorkType(String id) async {
    _workTypes.removeWhere((w) => w.id == id);
    // Remove date assignments referencing this work type
    _workTypeDates.removeWhere((_, v) => v == id);
    await _prefs.setString(_workTypesKey, WorkType.encode(_workTypes));
    await _prefs.setString(_workTypeDatesKey, jsonEncode(_workTypeDates));
  }

  // ─── Date → WorkType mapping ────────────────────────

  String? getDateWorkType(String date) => _workTypeDates[date];

  Future<void> setDateWorkType(String date, String? workTypeId) async {
    if (workTypeId == null) {
      _workTypeDates.remove(date);
    } else {
      _workTypeDates[date] = workTypeId;
    }
    await _prefs.setString(_workTypeDatesKey, jsonEncode(_workTypeDates));
  }

  /// All dates that have a work type assigned (for calendar cell rendering).
  Map<String, String> get workTypeDates => Map.unmodifiable(_workTypeDates);
}
