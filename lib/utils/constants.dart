/// ============================================================
/// FortRun Constants — Game Rules, Cities & Config
/// No external package imports — plain Dart types only.
/// ============================================================

class AppConstants {
  // ── Game Rules ──────────────────────────────────────────────
  static const int pointsPerKmOwn = 10;
  static const int pointsDeductOpponent = 5;
  static const int sabotagePointsMin = 50;
  static const int sabotagePointsMax = 100;
  static const int maxClanMembers = 10;

  // ── Streak Rules ───────────────────────────────────────────
  static const double streakMultiplier2Day = 1.5;
  static const double streakMultiplier7Day = 2.0;

  // ── Sabotage ───────────────────────────────────────────────
  static const Duration sabotageCooldown = Duration(hours: 4);
  static const double sabotageProximityMeters = 200.0;

  // ── Default map zoom ───────────────────────────────────────
  static const double defaultZoom = 13.0;

  // ── Islamabad (default) ────────────────────────────────────
  static const double islamabadLat = 33.6844;
  static const double islamabadLng = 73.0479;
  static const double islamabadMinLat = 33.55;
  static const double islamabadMaxLat = 33.82;
  static const double islamabadMinLng = 72.90;
  static const double islamabadMaxLng = 73.22;

  // ── Zone Polygon Opacity ───────────────────────────────────
  static const int ownerColorAlpha = 80;

  // ── All supported cities ───────────────────────────────────
  static final List<FortCity> cities = [
    FortCity(
      id: 'islamabad',
      name: 'Islamabad',
      country: 'Pakistan',
      lat: 33.6844,
      lng: 73.0479,
      emoji: '🏛️',
      description: 'The Capital — home of FortRun',
      fallbackSpots: [
        SabotageSpot(name: 'Monal Restaurant', sector: 'Margalla', lat: 33.7544, lng: 73.0567),
        SabotageSpot(name: 'Savour Foods', sector: 'G-5', lat: 33.7235, lng: 73.0891),
        SabotageSpot(name: 'Howdy', sector: 'F-7', lat: 33.7170, lng: 73.0590),
        SabotageSpot(name: 'Cheezious', sector: 'F-10', lat: 33.6932, lng: 73.0190),
        SabotageSpot(name: 'Chaaye Khana', sector: 'F-6', lat: 33.7260, lng: 73.0720),
        SabotageSpot(name: 'Tuscany Courtyard', sector: 'E-11', lat: 33.6970, lng: 72.9880),
      ],
    ),
    FortCity(
      id: 'muzaffarabad',
      name: 'Muzaffarabad',
      country: 'AJK',
      lat: 34.3700,
      lng: 73.4700,
      emoji: '🏔️',
      description: 'City of AJK — mountain territory',
      fallbackSpots: [
        SabotageSpot(name: 'Neelum Restaurant', sector: 'New Town', lat: 34.3720, lng: 73.4680),
        SabotageSpot(name: 'Shahi Darbar', sector: 'Old City', lat: 34.3700, lng: 73.4710),
        SabotageSpot(name: 'AJK Bakers', sector: 'Main Market', lat: 34.3740, lng: 73.4660),
        SabotageSpot(name: 'Jhelum View', sector: 'Riverside', lat: 34.3680, lng: 73.4730),
        SabotageSpot(name: 'Kashmir Point Café', sector: 'Kashmir Point', lat: 34.3760, lng: 73.4640),
      ],
    ),
    FortCity(
      id: 'lahore',
      name: 'Lahore',
      country: 'Pakistan',
      lat: 31.5204,
      lng: 74.3587,
      emoji: '🕌',
      description: 'City of Gardens — coming soon',
      comingSoon: true,
      fallbackSpots: [
        SabotageSpot(name: 'Cuckoo\'s Den', sector: 'Old Lahore', lat: 31.5890, lng: 74.3100),
        SabotageSpot(name: 'Haveli Restaurant', sector: 'Walled City', lat: 31.5900, lng: 74.3080),
      ],
    ),
    FortCity(
      id: 'karachi',
      name: 'Karachi',
      country: 'Pakistan',
      lat: 24.8607,
      lng: 67.0011,
      emoji: '🌊',
      description: 'City of Lights — coming soon',
      comingSoon: true,
      fallbackSpots: [
        SabotageSpot(name: 'BBQ Tonight', sector: 'Clifton', lat: 24.8086, lng: 67.0350),
      ],
    ),
    FortCity(
      id: 'rawalpindi',
      name: 'Rawalpindi',
      country: 'Pakistan',
      lat: 33.5651,
      lng: 73.0169,
      emoji: '🏙️',
      description: 'The Pindi — twin city territory',
      fallbackSpots: [
        SabotageSpot(name: 'Raja Sahib', sector: 'Saddar', lat: 33.5980, lng: 73.0430),
        SabotageSpot(name: 'Usmania', sector: 'Commercial Market', lat: 33.6010, lng: 73.0420),
        SabotageSpot(name: 'Pindi Food Street', sector: 'Raja Bazaar', lat: 33.5970, lng: 73.0500),
      ],
    ),
    FortCity(
      id: 'peshawar',
      name: 'Peshawar',
      country: 'Pakistan',
      lat: 34.0151,
      lng: 71.5249,
      emoji: '🦅',
      description: 'City of Flowers — coming soon',
      comingSoon: true,
      fallbackSpots: [],
    ),
  ];

  static FortCity cityById(String id) =>
      cities.firstWhere((c) => c.id == id, orElse: () => cities.first);

  // ── Fallback restaurant list (all cities combined) ─────────
  static List<SabotageSpot> get fallbackSabotageSpots =>
      cities.expand((c) => c.fallbackSpots).toList();
}

// ── City model ────────────────────────────────────────────────

class FortCity {
  final String id;
  final String name;
  final String country;
  final double lat;
  final double lng;
  final String emoji;
  final String description;
  final bool comingSoon;
  final List<SabotageSpot> fallbackSpots;

  const FortCity({
    required this.id,
    required this.name,
    required this.country,
    required this.lat,
    required this.lng,
    required this.emoji,
    required this.description,
    this.comingSoon = false,
    required this.fallbackSpots,
  });

  String get displayName => '$emoji $name';
}

// ── Sabotage spot model ───────────────────────────────────────

class SabotageSpot {
  final String name;
  final String sector;
  final double lat;
  final double lng;
  final String? cuisine;
  final bool isDynamic;

  const SabotageSpot({
    required this.name,
    required this.sector,
    required this.lat,
    required this.lng,
    this.cuisine,
    this.isDynamic = false,
  });
}
