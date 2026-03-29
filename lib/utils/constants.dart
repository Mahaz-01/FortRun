import 'package:google_maps_flutter/google_maps_flutter.dart';

/// ============================================================
/// FortRun Constants
/// Islamabad Sector Bounding Boxes & Sabotage Spots
/// ============================================================
///
/// Each zone is defined as a list of LatLng polygon vertices.
/// These are approximate boundaries based on real Islamabad sector grids.
/// The Islamabad grid system makes sectors roughly rectangular.

class AppConstants {
  // ── Game Rules ──────────────────────────────────────────────
  static const int pointsPerKmOwn = 10;       // Running in own territory
  static const int pointsDeductOpponent = 5;   // Opponent runs in your zone
  static const int sabotagePointsMin = 50;     // Sabotage base deduction
  static const int sabotagePointsMax = 100;    // Sabotage max deduction
  static const int maxClanMembers = 10;

  // ── Islamabad Center (for initial map camera) ──────────────
  static const LatLng islamabadCenter = LatLng(33.6844, 73.0479);
  static const double defaultZoom = 12.5;

  // ── Zones are now loaded dynamically from Supabase ────────

  // ── Hardcoded Sabotage Restaurants ─────────────────────────
  /// Popular Islamabad food spots mapped to their sector.
  /// For MVP we skip Google Places API; user selects from this list.
  static final List<SabotageSpot> sabotageSpots = [
    SabotageSpot(name: 'Monal Restaurant', sector: 'Margalla Trails', lat: 33.7544, lng: 73.0567),
    SabotageSpot(name: 'Savour Foods', sector: 'G-5', lat: 33.7235, lng: 73.0891),
    SabotageSpot(name: 'Howdy', sector: 'F-7', lat: 33.7170, lng: 73.0590),
    SabotageSpot(name: 'Cheezious F-10', sector: 'F-10', lat: 33.6932, lng: 73.0190),
    SabotageSpot(name: 'Burning Brownie', sector: 'F-6', lat: 33.7250, lng: 73.0760),
    SabotageSpot(name: 'Jessie\'s Burger', sector: 'F-6', lat: 33.7242, lng: 73.0745),
    SabotageSpot(name: 'OPTP F-7', sector: 'F-7', lat: 33.7155, lng: 73.0605),
    SabotageSpot(name: 'Tehzeeb Bakers', sector: 'G-9', lat: 33.6890, lng: 73.0450),
    SabotageSpot(name: 'Naan Stop', sector: 'G-8', lat: 33.6975, lng: 73.0600),
    SabotageSpot(name: 'Chaaye Khana', sector: 'F-6', lat: 33.7260, lng: 73.0720),
    SabotageSpot(name: 'Maro Tandoor', sector: 'F-10', lat: 33.6945, lng: 73.0210),
    SabotageSpot(name: 'Des Pardes', sector: 'G-6', lat: 33.7160, lng: 73.0900),
    SabotageSpot(name: 'Street 1 Café', sector: 'F-8', lat: 33.7060, lng: 73.0460),
    SabotageSpot(name: 'Xander\'s', sector: 'F-7', lat: 33.7180, lng: 73.0620),
    SabotageSpot(name: 'Tuscany Courtyard', sector: 'E-11', lat: 33.6970, lng: 72.9880),
  ];

  // ── Colors for zone ownership on map ───────────────────────
  /// Zone fill colors are assigned dynamically based on ownership,
  /// but we define base palette here (ARGB hex).
  static const int ownerColorAlpha = 80; // Semi-transparent polygon fill
}

/// A hardcoded sabotage restaurant.
class SabotageSpot {
  final String name;
  final String sector;
  final double lat;
  final double lng;

  const SabotageSpot({
    required this.name,
    required this.sector,
    required this.lat,
    required this.lng,
  });
}
