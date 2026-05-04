import 'package:flutter/material.dart';
import 'package:tripgenie/core/constants/app_colors.dart';
import 'package:tripgenie/features/social/models/trip_model.dart';

// PostTripScreen  –- Phase 7
//  User fills in their trip details to appear in the
//  Travel Buddies feed for others to join.

class PostTripScreen extends StatefulWidget {
  const PostTripScreen({super.key});

  @override
  State<PostTripScreen> createState() => _PostTripScreenState();
}

class _PostTripScreenState extends State<PostTripScreen> {
  final _destController = TextEditingController();
  final _descController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  int _groupSize = 4;
  final List<String> _allInterests = [
    'Food',
    'History',
    'Nature',
    'Shopping',
    'Art',
    'Adventure'
  ];
  final List<String> _selectedInterests = [];
  bool _isPosting = false;

  @override
  void dispose() {
    _destController.dispose();
    _descController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      controller.text = '${_monthName(picked.month)} ${picked.day}';
    }
  }

  String _monthName(int m) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[m];
  }

  void _post() async {
    if (_destController.text.trim().isEmpty ||
        _startController.text.isEmpty ||
        _endController.text.isEmpty ||
        _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isPosting = true);
    await Future.delayed(const Duration(milliseconds: 800)); // simulate

    final newTrip = TripPost(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userName: 'You',
      userInitials: 'ME',
      destination: _destController.text.trim(),
      startDate: _startController.text,
      endDate: _endController.text,
      groupSize: _groupSize,
      currentMembers: 1,
      interests: _selectedInterests.isEmpty ? ['Travel'] : _selectedInterests,
      description: _descController.text.trim(),
      postedAgo: 'Just now',
    );

    if (mounted) {
      setState(() => _isPosting = false);
      Navigator.of(context).pop(newTrip); // return to TravelersScreen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Post a Trip'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.group_add_outlined,
                      color: AppColors.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Post your trip to find travel buddies heading the same way',
                      style: TextStyle(fontSize: 13, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Destination
            _Label('Destination'),
            const SizedBox(height: 8),
            _Field(
              controller: _destController,
              hint: 'e.g. Istanbul, Hunza, Tokyo',
              prefix: Icons.flight_takeoff_rounded,
            ),

            const SizedBox(height: 20),

            // Dates
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Start Date'),
                      const SizedBox(height: 8),
                      _TapField(
                        controller: _startController,
                        hint: 'May 10',
                        onTap: () => _pickDate(_startController),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('End Date'),
                      const SizedBox(height: 8),
                      _TapField(
                        controller: _endController,
                        hint: 'May 17',
                        onTap: () => _pickDate(_endController),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Group size
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Label('Max Group Size'),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_groupSize > 2) {
                          setState(() => _groupSize--);
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline,
                          color: AppColors.primary),
                    ),
                    Text('$_groupSize',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 18)),
                    IconButton(
                      onPressed: () {
                        if (_groupSize < 20) {
                          setState(() => _groupSize++);
                        }
                      },
                      icon: const Icon(Icons.add_circle_outline,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Interests
            _Label('Trip Interests'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allInterests.map((label) {
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : Colors.grey.shade300),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            color:
                                selected ? Colors.white : Colors.grey.shade700,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 13)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Description
            _Label('Trip Description'),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Tell others what you\'re planning, your travel style, budget range…',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 2)),
              ),
            ),

            const SizedBox(height: 32),

            // Post button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isPosting ? null : _post,
                icon: _isPosting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_isPosting ? 'Posting…' : 'Post My Trip',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// helper widgets
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14));
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefix;
  const _Field(
      {required this.controller, required this.hint, required this.prefix});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(prefix, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
    );
  }
}

class _TapField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onTap;
  const _TapField(
      {required this.controller, required this.hint, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.calendar_today_outlined,
            color: AppColors.primary, size: 18),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
    );
  }
}
