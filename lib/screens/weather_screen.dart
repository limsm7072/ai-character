import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/weather_service.dart';
import '../services/settings_service.dart';
import '../models/weather_data.dart';
import '../theme/app_colors.dart';

class WeatherScreen extends StatefulWidget {
  final WeatherService weatherService;
  final SettingsService settingsService;

  const WeatherScreen({
    super.key,
    required this.weatherService,
    required this.settingsService,
  });

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  WeatherData? _weather;
  bool _loading = false;
  bool _gpsLoading = false;

  @override
  void initState() {
    super.initState();
    _weather = widget.weatherService.getCached();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final lat = widget.settingsService.weatherLat;
    final lon = widget.settingsService.weatherLon;
    final data = await widget.weatherService.forceRefresh(lat, lon);
    if (mounted) {
      setState(() {
        if (data != null) _weather = data;
        _loading = false;
      });
    }
  }

  Future<void> _updateGpsLocation() async {
    setState(() => _gpsLoading = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('위치 권한이 거부되었습니다. 설정에서 허용해주세요.')),
          );
        }
        setState(() => _gpsLoading = false);
        return;
      }
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)),
        );
        await widget.settingsService.setWeatherLocation(pos.latitude, pos.longitude);
        final data = await widget.weatherService.forceRefresh(pos.latitude, pos.longitude);
        if (data != null && data.locationName.isNotEmpty) {
          await widget.settingsService.setWeatherLocationName(data.locationName);
        }
        if (mounted) {
          setState(() {
            if (data != null) _weather = data;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치를 가져올 수 없습니다: $e')),
        );
      }
    }
    if (mounted) setState(() => _gpsLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('날씨'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
        ],
      ),
      body: _weather == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  _buildCurrentWeather(theme),
                  const SizedBox(height: 20),
                  _buildHourlyForecast(theme),
                  const SizedBox(height: 20),
                  _buildWeeklyForecast(theme),
                  const SizedBox(height: 20),
                  _buildDetailInfo(theme),
                  const SizedBox(height: 20),
                  _buildLocationSection(theme),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentWeather(ThemeData theme) {
    final w = _weather!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(w.icon, size: 56, color: w.iconColor),
          const SizedBox(height: 8),
          Text(
            '${w.temperature.round()}°',
            style: TextStyle(fontSize: 52, fontWeight: FontWeight.w300, color: theme.colorScheme.onSurface),
          ),
          Text(
            w.description,
            style: TextStyle(fontSize: 18, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (w.locationName.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text(w.locationName, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            '체감 ${w.apparentTemperature.round()}°',
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyForecast(ThemeData theme) {
    final w = _weather!;
    if (w.hourly.isEmpty) return const SizedBox.shrink();

    // Show next 24 hours from current hour
    final nowHour = DateTime.now().hour;
    final nowDate = DateTime.now();
    final todayStr = '${nowDate.year}-${nowDate.month.toString().padLeft(2, '0')}-${nowDate.day.toString().padLeft(2, '0')}';

    // Find current hour index
    int startIdx = 0;
    for (int i = 0; i < w.hourly.length; i++) {
      if (w.hourly[i].time.startsWith(todayStr) && w.hourly[i].hour >= nowHour) {
        startIdx = i;
        break;
      }
    }
    final items = w.hourly.skip(startIdx).take(24).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('시간별 예보', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (_, i) {
              final h = items[i];
              final isCurrent = i == 0;
              return Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                      : theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isCurrent ? '지금' : '${h.hour}시',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                        color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(h.icon, size: 22, color: h.iconColor),
                    const SizedBox(height: 8),
                    Text(
                      '${h.temperature.round()}°',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyForecast(ThemeData theme) {
    final w = _weather!;
    if (w.daily.isEmpty) return const SizedBox.shrink();

    // Find temp range for bar scaling
    double minAll = double.infinity, maxAll = double.negativeInfinity;
    for (final d in w.daily) {
      if (d.minTemp < minAll) minAll = d.minTemp;
      if (d.maxTemp > maxAll) maxAll = d.maxTemp;
    }
    final range = maxAll - minAll;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('주간 예보', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: w.daily.map((d) {
              final isToday = d.dayLabel == '오늘';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        d.dayLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                          color: isToday ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 36,
                      child: Text(
                        d.dateLabel,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                      ),
                    ),
                    Icon(d.icon, size: 20, color: d.iconColor),
                    const SizedBox(width: 12),
                    Text(
                      '${d.minTemp.round()}°',
                      style: TextStyle(fontSize: 13, color: AppColors.info),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: range > 0
                          ? _buildTempBar(theme, d.minTemp, d.maxTemp, minAll, range)
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${d.maxTemp.round()}°',
                      style: TextStyle(fontSize: 13, color: AppColors.error),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTempBar(ThemeData theme, double min, double max, double globalMin, double range) {
    final leftFrac = (min - globalMin) / range;
    final widthFrac = (max - min) / range;
    return LayoutBuilder(builder: (_, constraints) {
      final totalW = constraints.maxWidth;
      return Stack(
        children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Positioned(
            left: leftFrac * totalW,
            child: Container(
              width: (widthFrac * totalW).clamp(6.0, totalW),
              height: 6,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.info, AppColors.warning, AppColors.error],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildDetailInfo(ThemeData theme) {
    final w = _weather!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('상세 정보', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _detailCard(theme, Icons.thermostat_outlined, '체감온도', '${w.apparentTemperature.round()}°')),
            const SizedBox(width: 8),
            Expanded(child: _detailCard(theme, Icons.air, '풍속', '${w.windSpeed.round()} km/h')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _detailCard(theme, Icons.water_drop_outlined, '습도', '${w.humidity}%')),
            const SizedBox(width: 8),
            Expanded(child: _detailCard(theme, Icons.wb_sunny_outlined, 'UV 지수', '${w.uvIndex.round()} (${w.uvLabel})')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _detailCard(theme, Icons.wb_twilight, '일출', w.sunriseTime)),
            const SizedBox(width: 8),
            Expanded(child: _detailCard(theme, Icons.nightlight_outlined, '일몰', w.sunsetTime)),
          ],
        ),
      ],
    );
  }

  Widget _detailCard(ThemeData theme, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildLocationSection(ThemeData theme) {
    final locName = widget.settingsService.weatherLocationName;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('현재 위치', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
                const SizedBox(height: 2),
                Text(
                  locName.isNotEmpty ? locName : '${widget.settingsService.weatherLat.toStringAsFixed(2)}, ${widget.settingsService.weatherLon.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          ),
          _gpsLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: _updateGpsLocation,
                  tooltip: 'GPS 위치 업데이트',
                ),
        ],
      ),
    );
  }
}
