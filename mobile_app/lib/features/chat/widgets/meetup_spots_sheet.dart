import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/map_launcher.dart';

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
  final String? placeId;
  final bool isVerified;

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
    this.placeId,
    this.isVerified = true,
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
      placeId: json['place_id']?.toString(),
      isVerified: json['is_verified'] != false,
    );
  }
}

class MeetupSpotsSheet extends StatefulWidget {
  final Function(MeetupSpot spot) onSuggestSpot;
  final double? partnerLat;
  final double? partnerLon;
  final String? partnerName;

  const MeetupSpotsSheet({
    super.key,
    required this.onSuggestSpot,
    this.partnerLat,
    this.partnerLon,
    this.partnerName,
  });

  static Future<void> show({
    required BuildContext context,
    required Function(MeetupSpot spot) onSuggestSpot,
    double? partnerLat,
    double? partnerLon,
    String? partnerName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MeetupSpotsSheet(
        onSuggestSpot: onSuggestSpot,
        partnerLat: partnerLat,
        partnerLon: partnerLon,
        partnerName: partnerName,
      ),
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
  bool _isMidpoint = false;
  double? _userDistanceKm;
  String? _notice;

  final List<Map<String, String>> _categories = const [
    {'key': 'all', 'label': 'Sabhi (All)', 'icon': 'explore'},
    {'key': 'chai', 'label': 'Chai & Snacks', 'icon': 'chai'},
    {'key': 'cafe', 'label': 'Cafes & Bakes', 'icon': 'cafe'},
    {'key': 'restaurant', 'label': 'Restaurants', 'icon': 'restaurant'},
    {'key': 'hotel', 'label': 'Hotels & Lounges', 'icon': 'hotel'},
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
      final double myLat = pos?.latitude ?? 28.6139;
      final double myLon = pos?.longitude ?? 77.2090;

      final bool hasPartnerCoords =
          widget.partnerLat != null && widget.partnerLon != null;

      final res = await ApiClient.instance.getMeetupSpots(
        lat: hasPartnerCoords ? null : myLat,
        lon: hasPartnerCoords ? null : myLon,
        lat1: hasPartnerCoords ? myLat : null,
        lon1: hasPartnerCoords ? myLon : null,
        lat2: hasPartnerCoords ? widget.partnerLat : null,
        lon2: hasPartnerCoords ? widget.partnerLon : null,
        category: _selectedCategory == 'all' ? null : _selectedCategory,
      );

      if (res.data != null && res.data['data'] != null) {
        final data = res.data['data'];
        final rawSpots = data['spots'] as List<dynamic>? ?? [];
        setState(() {
          _spots = rawSpots
              .map((e) => MeetupSpot.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _isMidpoint = data['is_midpoint'] == true;
          _userDistanceKm = (data['user_distance_km'] as num?)?.toDouble();
          _notice = data['notice']?.toString();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Could not load commercial date spots. Please check network or location permissions.';
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

  /// Precise Coordinate-Locked Map Navigation with Zero Geographic Drift
  Future<void> _launchMaps(MeetupSpot spot) async {
    await MapLauncher.openExactLocation(
      latitude: spot.latitude,
      longitude: spot.longitude,
      placeName: spot.name,
    );
  }

  Future<void> _openDirectGoogleMapsSearch() async {
    try {
      final pos = await LocationService.instance.getCurrentLocation();
      final double myLat = pos?.latitude ?? 28.6139;
      final double myLon = pos?.longitude ?? 77.2090;
      final String searchUrl =
          'https://www.google.com/maps/search/cafes+and+restaurants/@$myLat,$myLon,12z';
      final uri = Uri.parse(searchUrl);
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
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.96,
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
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(Icons.place_rounded,
                          color: AppTheme.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _isMidpoint
                                    ? 'Midpoint Date Radar'
                                    : 'Nearby Date Spot Radar',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (_isMidpoint) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'MIDWAY',
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isMidpoint && _userDistanceKm != null
                                ? 'Fair midway zone (${_userDistanceKm!.toStringAsFixed(1)} km between you & ${widget.partnerName ?? "partner"})'
                                : 'Tea stalls, cafes, restaurants & hotels nearest to you (0-70 km)',
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.mutedTextColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: AppTheme.mutedTextColor),
                    ),
                  ],
                ),
              ),

              // Midpoint Notice Card (if midway mode active)
              if (_isMidpoint && _userDistanceKm != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.compare_arrows_rounded,
                          size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _notice ??
                              'Spot distance measured from exact midway point between both users.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Filter Chips Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                          color: isSelected
                              ? Colors.white
                              : AppTheme.mutedTextColor,
                        ),
                        label: Text(
                          cat['label']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.mutedTextColor,
                          ),
                        ),
                        backgroundColor: AppTheme.backgroundColor,
                        selectedColor: AppTheme.primaryColor,
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.cardBorderColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 4),
              const Divider(color: AppTheme.cardBorderColor, height: 1),

              // Spots List View / Strict 70km Empty State
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primaryColor),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_off_outlined,
                                      size: 48,
                                      color: AppTheme.mutedTextColor),
                                  const SizedBox(height: 12),
                                  Text(
                                    _errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: AppTheme.mutedTextColor,
                                        fontSize: 13),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchSpots,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor),
                                    child: const Text('Retry',
                                        style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : _spots.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(28.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: AppTheme.backgroundColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: AppTheme.cardBorderColor),
                                        ),
                                        child: const Icon(
                                            Icons.location_off_outlined,
                                            size: 44,
                                            color: AppTheme.mutedTextColor),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No registered meetup spots nearby',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Aapke 0-70 km ke radius me koi registered cafe ya hotel verified nahi mila. Aap directly Google Maps par search kar sakte hain.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppTheme.mutedTextColor,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed:
                                                _openDirectGoogleMapsSearch,
                                            icon: const Icon(
                                                Icons.travel_explore_rounded,
                                                size: 16),
                                            label: const Text(
                                                'Search on Google Maps',
                                                style: TextStyle(fontSize: 12)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.primaryColor,
                                              side: const BorderSide(
                                                  color: AppTheme.primaryColor),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          ElevatedButton.icon(
                                            onPressed: _fetchSpots,
                                            icon: const Icon(
                                                Icons.refresh_rounded,
                                                size: 16),
                                            label: const Text('Retry',
                                                style: TextStyle(fontSize: 12)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.surfaceColor,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 10),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
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
          // Row 1: Name & Verified Badge + Distance Pill
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            spot.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (spot.isVerified) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.verifiedBlue
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppTheme.verifiedBlue
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded,
                                    size: 11, color: AppTheme.verifiedBlue),
                                SizedBox(width: 3),
                                Text(
                                  'Verified',
                                  style: TextStyle(
                                    color: AppTheme.verifiedBlue,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.greenAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.navigation_outlined,
                        size: 12, color: Colors.greenAccent),
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
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppTheme.mutedTextColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  spot.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.mutedTextColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 3: Action Buttons (Maps Navigation & Suggest in Chat)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _launchMaps(spot),
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Open Maps',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.cardBorderColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
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
                  label: const Text('Suggest in Chat',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
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
