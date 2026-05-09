import 'package:flutter/material.dart';
import 'package:tripgenie/core/models/place_model.dart';
import 'package:tripgenie/core/services/places_service.dart';

class AttractionsExplorerScreen extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  
  const AttractionsExplorerScreen({
    Key? key,
    required this.initialLatitude,
    required this.initialLongitude,
  }) : super(key: key);

  @override
  State<AttractionsExplorerScreen> createState() => _AttractionsExplorerScreenState();
}

class _AttractionsExplorerScreenState extends State<AttractionsExplorerScreen> {
  late Future<List<Place>> _placesFuture;
  String? _selectedCategory;
  final List<String> _categories = ['Culture', 'Food', 'Parks', 'Shopping', 'Hotels'];

  @override
  void initState() {
    super.initState();
    _fetchPlaces();
  }

  void _fetchPlaces() {
    setState(() {
      _placesFuture = PlacesService.getNearbyPlaces(
        latitude: widget.initialLatitude,
        longitude: widget.initialLongitude,
        category: _selectedCategory,
        limit: 50,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attractions Explorer'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _selectedCategory == null,
                      onSelected: (selected) {
                        if (selected) {
                          _selectedCategory = null;
                          _fetchPlaces();
                        }
                      },
                    ),
                  );
                }
                final category = _categories[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: _selectedCategory == category,
                    onSelected: (selected) {
                      _selectedCategory = selected ? category : null;
                      _fetchPlaces();
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Place>>(
        future: _placesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final places = snapshot.data ?? [];
          
          if (places.isEmpty) {
            return const Center(child: Text('No places found nearby.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
            ),
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];
              return InkWell(
                onTap: () {
                  // Navigate to details
                  // context.push('/place/${place.id}');
                },
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: place.photos.isNotEmpty
                            ? Image.network(
                                place.photos.first,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey.shade300,
                                width: double.infinity,
                                child: const Icon(Icons.image, color: Colors.grey, size: 40),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              place.category,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  place.rating > 0 ? place.rating.toString() : 'New',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
