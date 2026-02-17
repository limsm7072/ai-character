import 'package:shared_preferences/shared_preferences.dart';
import '../models/calendar_event.dart';

class CalendarService {
  static const _key = 'calendar_events_data';
  final SharedPreferences _prefs;
  List<CalendarEvent> _events = [];

  CalendarService(this._prefs) {
    _load();
  }

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      _events = CalendarEvent.decode(raw);
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
}
