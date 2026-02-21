class BriefingData {
  final String greeting;
  final BriefingWeather? weather;
  final List<BriefingEvent> todayEvents;
  final int pendingTodoCount;
  final int todayRoutineCount;
  final int completedRoutineCount;
  final String? lunaComment;
  final String date;

  const BriefingData({
    required this.greeting,
    this.weather,
    this.todayEvents = const [],
    this.pendingTodoCount = 0,
    this.todayRoutineCount = 0,
    this.completedRoutineCount = 0,
    this.lunaComment,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'greeting': greeting,
    'weather': weather?.toJson(),
    'todayEvents': todayEvents.map((e) => e.toJson()).toList(),
    'pendingTodoCount': pendingTodoCount,
    'todayRoutineCount': todayRoutineCount,
    'completedRoutineCount': completedRoutineCount,
    'lunaComment': lunaComment,
    'date': date,
  };

  factory BriefingData.fromJson(Map<String, dynamic> json) => BriefingData(
    greeting: json['greeting'] as String? ?? '',
    weather: json['weather'] != null ? BriefingWeather.fromJson(json['weather']) : null,
    todayEvents: (json['todayEvents'] as List?)?.map((e) => BriefingEvent.fromJson(e)).toList() ?? [],
    pendingTodoCount: json['pendingTodoCount'] as int? ?? 0,
    todayRoutineCount: json['todayRoutineCount'] as int? ?? 0,
    completedRoutineCount: json['completedRoutineCount'] as int? ?? 0,
    lunaComment: json['lunaComment'] as String?,
    date: json['date'] as String? ?? '',
  );
}

class BriefingWeather {
  final double temperature;
  final int weatherCode;
  final double? high;
  final double? low;
  final String description;

  const BriefingWeather({
    required this.temperature,
    required this.weatherCode,
    this.high,
    this.low,
    this.description = '',
  });

  Map<String, dynamic> toJson() => {
    'temperature': temperature,
    'weatherCode': weatherCode,
    'high': high,
    'low': low,
    'description': description,
  };

  factory BriefingWeather.fromJson(Map<String, dynamic> json) => BriefingWeather(
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
    weatherCode: json['weatherCode'] as int? ?? 0,
    high: (json['high'] as num?)?.toDouble(),
    low: (json['low'] as num?)?.toDouble(),
    description: json['description'] as String? ?? '',
  );
}

class BriefingEvent {
  final String title;
  final String? time; // "09:00" or null (종일)

  const BriefingEvent({required this.title, this.time});

  Map<String, dynamic> toJson() => {'title': title, 'time': time};

  factory BriefingEvent.fromJson(Map<String, dynamic> json) => BriefingEvent(
    title: json['title'] as String? ?? '',
    time: json['time'] as String?,
  );
}
