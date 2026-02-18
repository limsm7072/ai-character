import 'package:health/health.dart';

class DailySteps {
  final String date;
  final int steps;
  DailySteps({required this.date, required this.steps});
}

class SleepData {
  final DateTime bedTime;
  final DateTime wakeTime;
  final Duration total;
  final Duration deep;
  final Duration rem;
  final Duration light;
  SleepData({
    required this.bedTime,
    required this.wakeTime,
    required this.total,
    required this.deep,
    required this.rem,
    required this.light,
  });
}

class HeartRateData {
  final int bpm;
  final DateTime time;
  HeartRateData({required this.bpm, required this.time});
}

class HeartRateRange {
  final int min;
  final int max;
  final int avg;
  HeartRateRange({required this.min, required this.max, required this.avg});
}

class HealthService {
  final Health _health = Health();
  bool _authorized = false;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.HEART_RATE,
  ];

  static const _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  bool get isAuthorized => _authorized;

  /// Check if we already have permissions by trying to read data.
  /// hasPermissions() is unreliable (often returns null even when granted),
  /// so we attempt a lightweight read instead.
  Future<bool> checkExistingPermissions() async {
    try {
      // First try the API method
      final hasPermissions = await _health.hasPermissions(_types, permissions: _permissions);
      if (hasPermissions == true) {
        _authorized = true;
        return true;
      }
      // hasPermissions often returns null even when granted.
      // Try an actual read to confirm.
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      await _health.getTotalStepsInInterval(midnight, now);
      // If no exception, we have access
      _authorized = true;
      return true;
    } catch (e) {
      print('[HealthService] checkExistingPermissions: $e');
      _authorized = false;
      return false;
    }
  }

  Future<bool> requestAuthorization() async {
    try {
      if (_authorized) return true;
      final granted = await _health.requestAuthorization(_types, permissions: _permissions);
      if (granted) {
        _authorized = true;
        return true;
      }
      // requestAuthorization can also return false even when granted.
      // Verify with an actual read.
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      await _health.getTotalStepsInInterval(midnight, now);
      _authorized = true;
      return true;
    } catch (e) {
      print('[HealthService] Authorization error: $e');
      _authorized = false;
      return false;
    }
  }

  Future<int> getTodaySteps() async {
    if (!_authorized) return 0;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps ?? 0;
    } catch (e) {
      print('[HealthService] getTodaySteps error: $e');
      return 0;
    }
  }

  Future<List<DailySteps>> getWeeklySteps() async {
    if (!_authorized) return [];
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final result = <DailySteps>[];

      for (int i = 6; i >= 0; i--) {
        final dayStart = today.subtract(Duration(days: i));
        final dayEnd = i == 0
            ? now
            : dayStart.add(const Duration(days: 1));
        final steps = await _health.getTotalStepsInInterval(dayStart, dayEnd);
        final dateStr =
            '${dayStart.year}-${dayStart.month.toString().padLeft(2, '0')}-${dayStart.day.toString().padLeft(2, '0')}';
        result.add(DailySteps(date: dateStr, steps: steps ?? 0));
      }
      return result;
    } catch (e) {
      print('[HealthService] getWeeklySteps error: $e');
      return [];
    }
  }

  Future<SleepData?> getLastSleep() async {
    if (!_authorized) return null;
    try {
      final now = DateTime.now();
      // 36시간 전까지 조회 (어젯밤 수면을 놓치지 않도록)
      final since = now.subtract(const Duration(hours: 36));

      // 1) SLEEP_SESSION으로 전체 수면 세션 조회 (삼성헬스 기본)
      final sessionPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_SESSION, HealthDataType.SLEEP_IN_BED],
        startTime: since,
        endTime: now,
      );

      // 2) 수면 단계 데이터 조회 (스마트워치 있으면 제공)
      final stagePoints = await _health.getHealthDataFromTypes(
        types: [
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_REM,
          HealthDataType.SLEEP_LIGHT,
        ],
        startTime: since,
        endTime: now,
      );

      // 세션도 단계도 없으면 수면 데이터 없음
      if (sessionPoints.isEmpty && stagePoints.isEmpty) return null;

      DateTime? earliest;
      DateTime? latest;
      Duration sessionTotal = Duration.zero;

      // 세션 데이터에서 취침/기상 시간 및 총 수면 시간 추출
      for (final dp in sessionPoints) {
        final duration = dp.dateTo.difference(dp.dateFrom);
        if (earliest == null || dp.dateFrom.isBefore(earliest)) {
          earliest = dp.dateFrom;
        }
        if (latest == null || dp.dateTo.isAfter(latest)) {
          latest = dp.dateTo;
        }
        if (dp.type == HealthDataType.SLEEP_SESSION) {
          sessionTotal += duration;
        }
      }

      // 단계 데이터에서 세부 시간 추출
      Duration deep = Duration.zero;
      Duration rem = Duration.zero;
      Duration light = Duration.zero;
      Duration totalAsleep = Duration.zero;

      for (final dp in stagePoints) {
        final duration = dp.dateTo.difference(dp.dateFrom);
        if (earliest == null || dp.dateFrom.isBefore(earliest)) {
          earliest = dp.dateFrom;
        }
        if (latest == null || dp.dateTo.isAfter(latest)) {
          latest = dp.dateTo;
        }

        switch (dp.type) {
          case HealthDataType.SLEEP_ASLEEP:
            totalAsleep += duration;
            break;
          case HealthDataType.SLEEP_DEEP:
            deep += duration;
            break;
          case HealthDataType.SLEEP_REM:
            rem += duration;
            break;
          case HealthDataType.SLEEP_LIGHT:
            light += duration;
            break;
          default:
            break;
        }
      }

      if (earliest == null || latest == null) return null;

      // 총 수면 시간 우선순위: 단계 합산 > 세션 총합 > 기상-취침 차이
      final stageSum = deep + rem + light;
      Duration total;
      if (totalAsleep.inMinutes > 0) {
        total = totalAsleep;
      } else if (stageSum.inMinutes > 0) {
        total = stageSum;
      } else if (sessionTotal.inMinutes > 0) {
        total = sessionTotal;
      } else {
        total = latest.difference(earliest);
      }

      return SleepData(
        bedTime: earliest,
        wakeTime: latest,
        total: total,
        deep: deep,
        rem: rem,
        light: light,
      );
    } catch (e) {
      print('[HealthService] getLastSleep error: $e');
      return null;
    }
  }

  Future<HeartRateData?> getLatestHeartRate() async {
    if (!_authorized) return null;
    try {
      final now = DateTime.now();
      final since = now.subtract(const Duration(hours: 4));

      final dataPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: since,
        endTime: now,
      );

      if (dataPoints.isEmpty) return null;

      dataPoints.sort((a, b) => b.dateTo.compareTo(a.dateTo));
      final latest = dataPoints.first;
      final value = latest.value;
      if (value is NumericHealthValue) {
        return HeartRateData(
          bpm: value.numericValue.round(),
          time: latest.dateTo,
        );
      }
      return null;
    } catch (e) {
      print('[HealthService] getLatestHeartRate error: $e');
      return null;
    }
  }

  Future<HeartRateRange?> getTodayHeartRateRange() async {
    if (!_authorized) return null;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      final dataPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: midnight,
        endTime: now,
      );

      if (dataPoints.isEmpty) return null;

      int minBpm = 999;
      int maxBpm = 0;
      int total = 0;

      for (final dp in dataPoints) {
        final value = dp.value;
        if (value is NumericHealthValue) {
          final bpm = value.numericValue.round();
          if (bpm < minBpm) minBpm = bpm;
          if (bpm > maxBpm) maxBpm = bpm;
          total += bpm;
        }
      }

      if (maxBpm == 0) return null;

      return HeartRateRange(
        min: minBpm,
        max: maxBpm,
        avg: total ~/ dataPoints.length,
      );
    } catch (e) {
      print('[HealthService] getTodayHeartRateRange error: $e');
      return null;
    }
  }

  Future<String> buildHealthSummary() async {
    if (!_authorized) return '';

    final parts = <String>[];

    try {
      final steps = await getTodaySteps();
      if (steps > 0) {
        final pct = (steps / 10000 * 100).round();
        parts.add('- 오늘 걸음 수: ${_formatNumber(steps)}보 (목표 $pct%)');
      }

      final sleep = await getLastSleep();
      if (sleep != null) {
        final h = sleep.total.inHours;
        final m = sleep.total.inMinutes.remainder(60);
        final sleepStr = StringBuffer('- 어젯밤 수면: ${h}시간 ${m}분');
        if (sleep.deep.inMinutes > 0 || sleep.rem.inMinutes > 0) {
          sleepStr.write(' (');
          final details = <String>[];
          if (sleep.deep.inMinutes > 0) {
            details.add('깊은 ${sleep.deep.inHours}h ${sleep.deep.inMinutes.remainder(60)}m');
          }
          if (sleep.rem.inMinutes > 0) {
            details.add('렘 ${sleep.rem.inHours}h ${sleep.rem.inMinutes.remainder(60)}m');
          }
          sleepStr.write(details.join(', '));
          sleepStr.write(')');
        }
        parts.add(sleepStr.toString());
      }

      final hr = await getLatestHeartRate();
      if (hr != null) {
        parts.add('- 현재 심박수: ${hr.bpm} bpm');
      }
    } catch (e) {
      print('[HealthService] buildHealthSummary error: $e');
    }

    if (parts.isEmpty) return '';
    return '사용자 건강 데이터:\n${parts.join('\n')}';
  }

  String _formatNumber(int n) {
    if (n < 1000) return '$n';
    final str = n.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
