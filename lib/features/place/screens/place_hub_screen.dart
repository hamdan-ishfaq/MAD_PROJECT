import 'package:flutter/material.dart';
import 'package:tripgenie/core/models/place_model.dart';
import 'package:tripgenie/core/services/places_service.dart';
import 'package:tripgenie/core/widgets/crowd_meter.dart';
import 'package:tripgenie/features/social/widgets/community_updates_sheet.dart';

class PlaceHubScreen extends StatefulWidget {
  final String placeXid;

  const PlaceHubScreen({Key? key, required this.placeXid}) : super(key: key);

  @override
  State<PlaceHubScreen> createState() => _PlaceHubScreenState();
}

class _PlaceHubScreenState extends State<PlaceHubScreen> {
  late Future<Place?> _placeFuture;

  @override
  void initState() {
    super.initState();
    _placeFuture = PlacesService.getPlaceDetails(widget.placeXid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Place?>(
      future: _placeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Place Details')),
            body: const Center(child: Text('Place not found')),
          );
        }

        final place = snapshot.data!;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // App bar with hero image
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(place.name,
                      style: const TextStyle(color: Colors.white, shadows: [
                        Shadow(color: Colors.black54, blurRadius: 4)
                      ])),
                  background: place.photos.isNotEmpty
                      ? Image.network(
                          place.photos.first,
                          fit: BoxFit.cover,
                        )
                      : Container(color: Colors.grey.shade300),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          place.category.toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Rating
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text('${place.rating > 0 ? place.rating : "N/A"}/5',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text('(${place.reviewCount} reviews)',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Crowd Meter
                      CrowdMeter(crowdLevel: place.crowdLevel),
                      const SizedBox(height: 24),

                      // Address
                      if (place.address.isNotEmpty) ...[
                        Text(
                          'Address',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on,
                                size: 20, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(child: Text(place.address)),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Contact
                      if (place.phoneNumber != null ||
                          place.website != null) ...[
                        Text(
                          'Contact',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        if (place.phoneNumber != null)
                          Row(
                            children: [
                              const Icon(Icons.phone,
                                  size: 20, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(place.phoneNumber!),
                            ],
                          ),
                        if (place.website != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.language,
                                  size: 20, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  place.website!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],

                      // Description
                      if (place.description.isNotEmpty) ...[
                        Text(
                          'About',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(place.description,
                            style: const TextStyle(height: 1.5)),
                        const SizedBox(height: 24),
                      ],

                      // Action buttons
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Add to itinerary
                          },
                          icon: const Icon(Icons.add_location_alt),
                          label: const Text('Add to Itinerary'),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            CommunityUpdatesSheet.show(
                              context,
                              placeId: place.id,
                              placeName: place.name,
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Chat with Travelers'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
