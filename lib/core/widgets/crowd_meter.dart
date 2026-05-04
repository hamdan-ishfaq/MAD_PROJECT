import 'package:flutter/material.dart';

class CrowdMeter extends StatelessWidget {
  final double crowdLevel;  // 0-100
  final String? customLabel;

  const CrowdMeter({
    Key? key,
    required this.crowdLevel,
    this.customLabel,
  }) : super(key: key);

  Color get _color {
    if (crowdLevel < 30) return Colors.green;
    if (crowdLevel < 60) return Colors.yellow.shade700;
    if (crowdLevel < 80) return Colors.orange;
    return Colors.red;
  }

  String get _label {
    if (crowdLevel < 30) return 'Not Busy';
    if (crowdLevel < 60) return 'Moderately Busy';
    if (crowdLevel < 80) return 'Busy';
    return 'Very Busy';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Crowd Level',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            Text(
              '${crowdLevel.toInt()}%',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: _color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Meter bar
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: crowdLevel / 100,
            minHeight: 16,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(_color),
          ),
        ),
        const SizedBox(height: 8),
        
        // Status label
        Text(
          customLabel ?? _label,
          style: TextStyle(
            fontSize: 12,
            color: _color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
