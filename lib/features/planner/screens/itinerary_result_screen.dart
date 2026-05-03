import 'package:flutter/material.dart';
import 'package:Wanderland/core/constants/app_colors.dart';
import 'package:Wanderland/core/services/itinerary_service.dart';
import 'package:Wanderland/features/planner/screens/itinerary_result_screen.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _destinationController = TextEditingController();
  int _days = 3;
  double _budget = 500;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _allInterests = [
    {'label': 'Food',      'icon': Icons.restaurant_outlined},
    {'label': 'History',   'icon': Icons.museum_outlined},
    {'label': 'Nature',    'icon': Icons.park_outlined},
    {'label': 'Shopping',  'icon': Icons.shopping_bag_outlined},
    {'label': 'Art',       'icon': Icons.palette_outlined},
    {'label': 'Adventure', 'icon': Icons.hiking_outlined},
  ];
  final List<String> _selectedInterests = [];

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _generateItinerary() async {
    if (_destinationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a destination')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final itinerary = await ItineraryService.generateItinerary(
      destination: _destinationController.text.trim(),
      days: _days,
      budget: _budget,
      interests:
      _selectedInterests.isEmpty ? ['General'] : _selectedInterests,
    );

    setState(() => _isLoading = false);
    if (!mounted) return;

    if (itinerary != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ItineraryResultScreen(itinerary: itinerary),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not generate. Check your Grok API key.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Trip Planner'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A73E8), Color(0xFF00C897)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Powered by Grok AI',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                        Text('Day-by-day plans with weather forecasts',
                            style:
                            TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Destination
            const Text('Where do you want to go?',
                style:
                TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                hintText: 'e.g. Paris, Lahore, Bangkok',
                prefixIcon: const Icon(Icons.flight_takeoff_rounded,
                    color: AppColors.primary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 2)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            // Days
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Number of Days',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                _Pill(label: '$_days days'),
              ],
            ),
            Slider(
              value: _days.toDouble(),
              min: 1,
              max: 14,
              divisions: 13,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _days = v.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1 day',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
                Text('14 days',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),

            const SizedBox(height: 20),

            // Budget
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Budget',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                _Pill(label: '\$${_budget.round()}'),
              ],
            ),
            Slider(
              value: _budget,
              min: 100,
              max: 5000,
              divisions: 49,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _budget = v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('\$100',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
                Text('\$5000',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),

            const SizedBox(height: 24),

            // Interests
            const Text('Your Interests',
                style:
                TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Select all that apply',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allInterests.map((item) {
                final label = item['label'] as String;
                final icon  = item['icon']  as IconData;
                final selected = _selectedInterests.contains(label);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selected
                          ? _selectedInterests.remove(label)
                          : _selectedInterests.add(label);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 15,
                            color: selected
                                ? Colors.white
                                : Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(label,
                            style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 36),

            // Generate button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _generateItinerary,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Text('Grok is planning your trip…',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ],
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Generate My Itinerary',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),
            Center(
              child: Text('Powered by Grok · xAI',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade400)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700)),
    );
  }
}