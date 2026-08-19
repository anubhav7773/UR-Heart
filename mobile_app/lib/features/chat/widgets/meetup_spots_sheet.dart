import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';

class MeetupSpot {
  final String id;
  final String name;
  final String category;
  final String categoryLabel;
  final int distanceMeters;
  final double distanceKm;
  final String distanceLabel;
  final String address;
  final double latitude;
  final double longitude;
  final String mapsUrl;
  final String? phone;
  final double? rating;

  const MeetupSpot({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryLabel,
    required this.distanceMeters,
    required this.distanceKm,
    required this.distanceLabel,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.mapsUrl,
    this.phone,
    this.rating,
  });

  factory MeetupSpot.fromJson(Map<String, dynamic> json) {
    return MeetupSpot(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Local Spot').toString(),
      category: (json['category'] ?? 'cafe').toString(),
      categoryLabel: (json['category_label'] ?? 'Spot').toString(),
      distanceMeters: (json['distance_meters'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      distanceLabel: (json['distance_label'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      mapsUrl: (json['maps_url'] ?? '').toString(),
      phone: json['phone']?.toString(),
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}

class MeetupSpotsSheet extends StatefulWidget {
  final Function(MeetupSpot spot) onSuggestSpot;

  const MeetupSpotsSheet({
    super.key,
    required this.onSuggestSpot,
  });

  static Future<void> show({
    required BuildContext context,
    required Function(MeetupSpot spot) onSuggestSpot,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeetupSpotsSheet(onSuggestSpot: onSuggestSpot),
    );
  }

  @override
  State<MeetupSpotsSheet> createState() => _MeetupSpotsSheetState();
}

class _MeetupSpotsSheetState extends State<MeetupSpotsSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  List<MeetupSpot> _spots = [];
  String _selectedCategory = 'all'; // all, chai, cafe, restaurant, hotel

  final List<Map<String, String>> _categories = const [
    {'key': 'all', 'label': 'Sabhi (All)', 'icon': 'explore'},
    {'key': 'chai', 'label': 'Chai & Snacks', 'icon': 'chai'},
    {'key': 'cafe', 'label': 'Cafes', 'icon': 'cafe'},
    {'key': 'restaurant', 'label': 'Restaurants', 'icon': 'restaurant'},
    {'key': 'hotel', 'label': 'Hotels', 'icon': 'hotel'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchSpots();
  }

  Future<void> _fetchSpots() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final pos = await LocationService.instance.getCurrentLocation();
      final double lat = pos?.latitude ?? 28.6139; // Default or live fix
      final double lon = pos?.longitude ?? 77.2090;

      final res = await ApiClient.instance.getMeetupSpots(
        lat: lat,
        lon: lon,
        radiusMeters: 15000,
        category: _selectedCategory == 'all' ? null : _selectedCategory,
      );

      if (res.data != null && res.data['data'] != null) {
        final data = res.data['data'];
        final rawSpots = data['spots'] as List<dynamic>? ?? [];
        setState(() {
          _spots = rawSpots
              .map((e) => MeetupSpot.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load date spots. Please check location permissions.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onCategorySelected(String categoryKey) {
    if (_selectedCategory == categoryKey) return;
    setState(() {
      _selectedCategory = categoryKey;
    });
    _fetchSpots();
  }

  Future<void> _launchMaps(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  IconData _getCategoryIcon(String key) {
    switch (key) {
      case 'chai':
        return Icons.local_cafe_outlined;
      case 'cafe':
        return Icons.coffee_outlined;
      case 'restaurant':
        return Icons.restaurant_outlined;
      case 'hotel':
        return Icons.hotel_outlined;
      default:
        return Icons.explore_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: AppTheme.cardBorderColor, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Handle Bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.mutedTextColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.place_rounded, color: AppTheme.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nearby Date Spot Radar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tea stalls to cafes & hotels, sorted nearest first',
                            style: TextStyle(fontSize: 12, color: AppTheme.mutedTextColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppTheme.mutedTextColor),
                    ),
                  ],
                ),
              ),

              // Filter Chips Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat['key'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        onSelected: (_) => _onCategorySelected(cat['key']!),
                        avatar: Icon(
                          _getCategoryIcon(cat['key']!),
                          size: 16,
                          color: isSelected ? Colors.white : AppTheme.mutedTextColor,
                        ),
                        label: Text(
                          cat['label']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppTheme.mutedTextColor,
                          ),
                        ),
                        backgroundColor: AppTheme.backgroundColor,
                        selectedColor: AppTheme.primaryColor,
                        side: BorderSide(
                          color: isSelected ? AppTheme.primaryColor : AppTheme.cardBorderColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const Divider(color: AppTheme.cardBorderColor, height: 1),

              // Spots List View
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryColor),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_off_outlined, size: 48, color: AppTheme.mutedTextColor),
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: AppTheme.mutedTextColor, fontSize: 13),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchSpots,
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                                    child: const Text('Retry', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _spots.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.explore_off_outlined, size: 44, color: AppTheme.mutedTextColor),
                                    SizedBox(height: 12),
                                    Text('No date spots found in this category', style: TextStyle(color: Colors.white70)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: _spots.length,
                                itemBuilder: (context, index) {
                                  final spot = _spots[index];
                                  return _buildSpotCard(spot);
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpotCard(MeetupSpot spot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Name, Category Badge & Distance Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.cardBorderColor),
                      ),
                      child: Text(
                        spot.categoryLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.secondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Distance Tag Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.navigation_outlined, size: 12, color: Colors.greenAccent),
                    const SizedBox(width: 4),
                    Text(
                      spot.distanceLabel,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Row 2: Address String
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.mutedTextColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  spot.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppTheme.mutedTextColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 3: Action Buttons (Maps & Suggest in Chat)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _launchMaps(spot.mapsUrl),
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Open Maps', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.cardBorderColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onSuggestSpot(spot);
                  },
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: const Text('Suggest in Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
