import 'package:flutter/material.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/core/models/dashboard_model.dart';
import 'package:tripgenie/core/services/auth_service.dart';
import 'package:tripgenie/core/services/dashboard_service.dart';
import 'package:tripgenie/core/services/offline_db_service.dart';
import 'package:tripgenie/core/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tripgenie/features/planner/models/itinerary_model.dart';

class ItineraryResultScreen extends StatefulWidget {
  final Itinerary itinerary;

  const ItineraryResultScreen({
    super.key,
    required this.itinerary,
  });

  @override
  State<ItineraryResultScreen> createState() => _ItineraryResultScreenState();
}

class _ItineraryResultScreenState extends State<ItineraryResultScreen> {
  bool _isSaving = false;
  bool _isLoadingWeather = true;
  String? _weatherSummary;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    try {
      final coordinates =
          await _resolveCoordinates(widget.itinerary.destination);
      if (coordinates == null) {
        if (!mounted) return;
        setState(() {
          _weatherError = 'Weather unavailable for this destination.';
          _isLoadingWeather = false;
        });
        return;
      }

      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=${coordinates['lat']}&longitude=${coordinates['lng']}&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Open-Meteo request failed');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final daily = decoded['daily'] as Map<String, dynamic>?;
      final temperaturesMax = (daily?['temperature_2m_max'] as List<dynamic>?);
      final temperaturesMin = (daily?['temperature_2m_min'] as List<dynamic>?);
      final weatherCodes = (daily?['weather_code'] as List<dynamic>?);

      final summary = _buildWeatherSummary(
        _firstNumberValue(weatherCodes)?.toInt(),
        _firstNumberValue(temperaturesMax)?.toDouble(),
        _firstNumberValue(temperaturesMin)?.toDouble(),
      );

      if (!mounted) return;
      setState(() {
        _weatherSummary = summary;
        _isLoadingWeather = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weatherError = 'Weather unavailable right now.';
        _isLoadingWeather = false;
      });
    }
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

  num? _firstNumberValue(List<dynamic>? values) {
    if (values == null || values.isEmpty) return null;
    final first = values.first;
    return first is num ? first : num.tryParse(first.toString());
  }

  String _buildWeatherSummary(
      int? weatherCode, double? maxTemp, double? minTemp) {
    final description = switch (weatherCode) {
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

  Future<void> _saveItinerary() async {
    if (_isSaving) return;

    final user = await AuthService.loadUser();
    if (!mounted) return;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save this itinerary.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final itineraryJson = {
      'destination': widget.itinerary.destination,
      'days': widget.itinerary.days,
      'budget': widget.itinerary.budget,
      'summary': widget.itinerary.summary,
      'day_plans': widget.itinerary.dayPlans
          .map(
            (dayPlan) => {
              'day': dayPlan.day,
              'date': dayPlan.date,
              'activities': dayPlan.activities
                  .map(
                    (activity) => {
                      'time': activity.time,
                      'title': activity.title,
                      'description': activity.description,
                      'type': activity.type,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };

    final saved = await DashboardService.saveItinerary(
      userId: user.id,
      destination: widget.itinerary.destination,
      days: widget.itinerary.days,
      budget: widget.itinerary.budget,
      summary: widget.itinerary.summary,
      itineraryJson: itineraryJson,
    );

    final record = saved ??
        SavedItinerary(
          id: '${user.id}_${DateTime.now().millisecondsSinceEpoch}',
          userId: user.id,
          destination: widget.itinerary.destination,
          days: widget.itinerary.days,
          budget: widget.itinerary.budget,
          summary: widget.itinerary.summary,
          itinerary: itineraryJson,
          status: 'planned',
          isFavorite: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

    await OfflineDbService.saveItineraryLocally(record);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved == null
              ? 'Saved locally. Will sync when the backend is available.'
              : 'Itinerary saved successfully.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.itinerary.destination),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveItinerary,
            icon: _isSaving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bookmark_add_outlined),
            label: Text(_isSaving ? 'Saving' : 'Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.itinerary.summary,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _InfoChip(
                          icon: Icons.calendar_month,
                          label: '${widget.itinerary.days} days'),
                      const SizedBox(width: 8),
                      _InfoChip(
                          icon: Icons.payments_outlined,
                          label:
                              '\$${widget.itinerary.budget.toStringAsFixed(0)}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Weather',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: _isLoadingWeather
                  ? const Center(child: CircularProgressIndicator())
                  : Text(_weatherSummary ??
                      _weatherError ??
                      'Weather unavailable.'),
            ),
            const SizedBox(height: 16),
            Text(
              'Daily Plan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            ...widget.itinerary.dayPlans.map(
              (dayPlan) => _DayPlanCard(dayPlan: dayPlan),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _DayPlanCard extends StatefulWidget {
  final DayPlan dayPlan;

  const _DayPlanCard({required this.dayPlan});

  @override
  State<_DayPlanCard> createState() => _DayPlanCardState();
}

class _DayPlanCardState extends State<_DayPlanCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Day ${widget.dayPlan.day}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.dayPlan.activities.length,
                    itemBuilder: (context, index) {
                      final activity = widget.dayPlan.activities[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    activity.time,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    activity.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 0),
                              child: Text(
                                activity.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
