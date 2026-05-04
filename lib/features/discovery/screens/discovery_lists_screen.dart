import 'package:flutter/material.dart';
import 'package:tripgenie/core/models/place_model.dart';
import 'package:tripgenie/core/services/places_service.dart';
import 'package:tripgenie/features/social/widgets/community_updates_sheet.dart';

class DiscoveryListsScreen extends StatefulWidget {
  final String city;
  const DiscoveryListsScreen({Key? key, required this.city}) : super(key: key);

  @override
  State<DiscoveryListsScreen> createState() => _DiscoveryListsScreenState();
}

class _DiscoveryListsScreenState extends State<DiscoveryListsScreen> {
  late Future<List<Place>> _trendingFuture;

  @override
  void initState() {
    super.initState();
    _trendingFuture = PlacesService.getTrendingPlaces(city: widget.city);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Discover ${widget.city}'),
      ),
      body: FutureBuilder<List<Place>>(
        future: _trendingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final places = snapshot.data ?? [];

          if (places.isEmpty) {
            return const Center(
              child: Text('No trending places found here.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: place.photos.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(place.photos.first,
                              width: 60, height: 60, fit: BoxFit.cover),
                        )
                      : Container(
                          width: 60, height: 60, color: Colors.grey.shade300),
                  title: Text(place.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(place.category),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: place.crowdColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${place.crowdLevel.toInt()}% Busy',
                      style: TextStyle(
                          color: place.crowdColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                  onTap: () {
                    CommunityUpdatesSheet.show(
                      context,
                      placeId: place.id,
                      placeName: place.name,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
