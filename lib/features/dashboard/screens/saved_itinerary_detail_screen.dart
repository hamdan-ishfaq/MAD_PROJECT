import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/models/dashboard_model.dart';

class SavedItineraryDetailScreen extends StatelessWidget {
  final SavedItinerary itinerary;

  const SavedItineraryDetailScreen({super.key, required this.itinerary});

  @override
  Widget build(BuildContext context) {
    final days = itinerary.itinerary['day_plans'] as List<dynamic>? ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Saved Itinerary'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.splashGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itinerary.destination,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    itinerary.summary,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetaChip(
                          label: '${itinerary.days} days',
                          icon: Icons.calendar_today_rounded),
                      _MetaChip(
                          label: '${itinerary.budget.toStringAsFixed(0)}',
                          icon: Icons.attach_money_rounded),
                      _MetaChip(
                          label: itinerary.status.toUpperCase(),
                          icon: Icons.bookmark_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Created ${DateFormat('MMM d, y').format(itinerary.createdAt)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Day Plans',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (days.isEmpty)
              const Text(
                'No day plans were saved with this itinerary.',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ...days
                  .map((day) => _DayPlanCard(day: day as Map<String, dynamic>))
                  .toList(),
            const SizedBox(height: 8),
            const Text(
              'Weather',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            _SavedItineraryWeather(destination: itinerary.destination),
          ],
        ),
      ),
    );
  }
}

class _SavedItineraryWeather extends StatelessWidget {
  final String destination;

  const _SavedItineraryWeather({required this.destination});

  Future<String> _loadWeatherSummary() async {
    final coordinates = await _resolveCoordinates(destination);
    if (coordinates == null) {
      return 'Weather unavailable for this destination.';
    }

    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=${coordinates['lat']}&longitude=${coordinates['lng']}&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      return 'Weather unavailable right now.';
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final daily = decoded['daily'] as Map<String, dynamic>?;
    final maxTemp =
        _firstNumber(daily?['temperature_2m_max'] as List<dynamic>?);
    final minTemp =
        _firstNumber(daily?['temperature_2m_min'] as List<dynamic>?);
    final weatherCode = _firstNumber(daily?['weather_code'] as List<dynamic>?);

    final description = switch (weatherCode?.toInt()) {
      0 => 'Clear sky',
      1 || 2 => 'Partly cloudy',
      3 => 'Cloudy',
      45 || 48 => 'Foggy',
      51 || 53 || 55 => 'Drizzle',
      61 || 63 || 65 => 'Rain',
      71 || 73 || 75 => 'Snow',
      80 || 81 || 82 => 'Showers',
      95 || 96 || 99 => 'Thunderstorm',
      _ => 'Forecast available',
    };

    final tempText = maxTemp != null && minTemp != null
        ? '${maxTemp.toStringAsFixed(0)}° / ${minTemp.toStringAsFixed(0)}°'
        : 'Temperature unavailable';

    return '$description • $tempText';
  }

  Future<Map<String, double>?> _resolveCoordinates(String destination) async {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${Uri.encodeComponent(destination)}',
    );
    final response = await http.get(uri, headers: {
      'User-Agent': 'wanderland-app'
    }).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) return null;

    final first = decoded.first as Map<String, dynamic>;
    final latitude = double.tryParse(first['lat']?.toString() ?? '');
    final longitude = double.tryParse(first['lon']?.toString() ?? '');
    if (latitude == null || longitude == null) return null;

    return {'lat': latitude, 'lng': longitude};
  }

  num? _firstNumber(List<dynamic>? values) {
    if (values == null || values.isEmpty) return null;
    final value = values.first;
    return value is num ? value : num.tryParse(value.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: FutureBuilder<String>(
        future: _loadWeatherSummary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return Text(
            snapshot.data ?? 'Weather unavailable right now.',
            style: const TextStyle(
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          );
        },
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MetaChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayPlanCard extends StatelessWidget {
  final Map<String, dynamic> day;

  const _DayPlanCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final activities = day['activities'] as List<dynamic>? ?? const [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day ${day['day'] ?? ''} - ${day['date'] ?? ''}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...activities.map((activity) {
            final item = activity as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${item['time'] ?? ''}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['title'] ?? ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item['description'] ?? ''}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
