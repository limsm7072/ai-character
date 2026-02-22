import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 루나가 사용자에 대해 기억하는 정보를 관리합니다.
/// 대화 중 학습한 사실을 저장하고 시스템 프롬프트에 주입합니다.
class MemoryService {
  static const _memoriesKey = 'luna_memories';
  final SharedPreferences _prefs;

  MemoryService(this._prefs);

  /// 모든 기억 조회 (key → value)
  Map<String, String> getAll() {
    final raw = _prefs.getString(_memoriesKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, String>();
    } catch (_) {
      return {};
    }
  }

  /// 특정 기억 조회
  String? get(String key) => getAll()[key];

  /// 기억 저장/업데이트
  Future<void> set(String key, String value) async {
    final map = getAll();
    map[key] = value;
    await _prefs.setString(_memoriesKey, jsonEncode(map));
  }

  /// 기억 삭제
  Future<void> remove(String key) async {
    final map = getAll();
    map.remove(key);
    await _prefs.setString(_memoriesKey, jsonEncode(map));
  }

  /// 전체 삭제
  Future<void> clear() async {
    await _prefs.remove(_memoriesKey);
  }

  /// 시스템 프롬프트에 주입할 메모리 블록 생성
  String buildPromptBlock() {
    final memories = getAll();
    if (memories.isEmpty) return '';

    final lines = memories.entries
        .map((e) => '- ${e.key}: ${e.value}')
        .join('\n');
    return '\n\n사용자에 대해 기억하고 있는 정보:\n$lines';
  }

  int get count => getAll().length;
}
