import 'package:flutter_test/flutter_test.dart';
import 'package:fortrun/models/user_model.dart';
import 'package:fortrun/models/run_model.dart';
import 'package:fortrun/models/zone_model.dart';

void main() {
  group('UserModel.fromMap', () {
    test('parses core stats and streak fields', () {
      final u = UserModel.fromMap({
        'id': 'abc',
        'name': 'Runner One',
        'points': 1200,
        'total_km': 42.5,
        'streak_count': 6,
      });
      expect(u.id, 'abc');
      expect(u.name, 'Runner One');
      expect(u.points, 1200);
      expect(u.totalKm, 42.5);
      expect(u.streakCount, 6);
    });

    test('falls back gracefully on missing fields', () {
      final u = UserModel.fromMap({'id': 'x'});
      expect(u.name, '');
      expect(u.points, 0);
      expect(u.totalKm, 0.0);
    });
  });

  group('RunModel.fromMap polyline', () {
    test('parses a normal JSONB list', () {
      final r = RunModel.fromMap({
        'user_id': 'u1',
        'distance_km': 3.2,
        'polyline_coords': [
          {'lat': 33.7, 'lng': 73.0},
          {'lat': 33.71, 'lng': 73.01},
        ],
      });
      expect(r.polylineCoords.length, 2);
      expect(r.polylineCoords.first['lat'], 33.7);
    });

    test('parses JSONB delivered as a String (realtime payload case)', () {
      // Supabase realtime can deliver jsonb columns as encoded strings.
      final r = RunModel.fromMap({
        'user_id': 'u1',
        'distance_km': 1.0,
        'polyline_coords': '[{"lat":1.5,"lng":2.5}]',
      });
      expect(r.polylineCoords.length, 1);
      expect(r.polylineCoords.first['lng'], 2.5);
    });
  });

  group('ZoneModel.fromMap', () {
    test('parses polygon from a String payload', () {
      final z = ZoneModel.fromMap({
        'id': 'sector_1_2',
        'polygon_coords': '[{"lat":0.0,"lng":0.0},{"lat":1.0,"lng":1.0}]',
        'total_points': 50,
      });
      expect(z.id, 'sector_1_2');
      expect(z.polygonCoords.length, 2);
      expect(z.totalPoints, 50);
    });
  });
}
