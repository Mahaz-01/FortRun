import 'dart:io';
import 'dart:convert';

void main() {
  final file = File('c:/fortrun/seed_zones.sql');
  List<String> sqlLines = [];

  sqlLines.add('-- ============================================================');
  sqlLines.add('-- FortRun: 33 Islamabad Sectors Seed Data');
  sqlLines.add('-- ============================================================');
  sqlLines.add('ALTER TABLE public.zones ADD COLUMN IF NOT EXISTS polygon_coords JSONB DEFAULT \'[]\'::jsonb;');
  sqlLines.add('');

  // Setup basic grid math.
  // We'll use F-7 as the anchor.
  // F-7 Center: lat 33.715, lng 73.060
  // Each sector is approx a box: width/height ~ 0.009 lat, ~0.015 lng
  
  Map<String, int> rowOffsets = {
    'D': -2,
    'E': -1,
    'F': 0,
    'G': 1,
    'H': 2,
    'I': 3,
  };

  List<String> requestedSectors = [
    'F-5', 'F-6', 'F-7', 'F-8', 'F-9', 'F-10', 'F-11',
    'G-5', 'G-6', 'G-7', 'G-8', 'G-9', 'G-10', 'G-11', 'G-13', 'G-14',
    'E-7', 'E-11',
    'H-8', 'H-9', 'H-11', 'H-12',
    'I-8', 'I-9', 'I-10', 'I-11', 'I-14',
    'D-12'
  ];

  Map<String, String> friendlyNames = {
    'F-9': 'F-9 (Fatima Jinnah Park)',
    'G-5': 'G-5 (Diplomatic Enclave)',
    'F-8': 'F-8 (Blue Area part)',
    'G-6': 'G-6 (Melody/Aabpara)',
    'Margalla Trails': 'Margalla Trails (Trail 3 & 5)',
    'Lake View Park': 'Lake View Park (Rawal Lake)',
    'Diplomatic Enclave': 'Diplomatic Enclave (Secured)',
  };

  sqlLines.add('INSERT INTO public.zones (id, name, polygon_coords, control_percentage, total_points)');
  sqlLines.add('VALUES');

  List<String> values = [];

  // Generate for grid sectors
  for (String sector in requestedSectors) {
    String rowLetter = sector.split('-')[0];
    int colNumber = int.parse(sector.split('-')[1]);

    int rowOffset = rowOffsets[rowLetter]!;
    int colOffset = colNumber - 7; // Relative to 7

    // calc center
    double centerLat = 33.715 + (rowOffset * -0.009) + (colOffset * -0.009);
    double centerLng = 73.060 + (rowOffset * 0.015)  + (colOffset * -0.015);

    double dLat = 0.0045;
    double dLng = 0.0075;

    // 4 corners
    List<Map<String, double>> poly = [
      {'lat': centerLat + dLat, 'lng': centerLng - dLng}, // NW
      {'lat': centerLat + dLat, 'lng': centerLng + dLng}, // NE
      {'lat': centerLat - dLat, 'lng': centerLng + dLng}, // SE
      {'lat': centerLat - dLat, 'lng': centerLng - dLng}, // SW
    ];

    String polyJson = jsonEncode(poly).replaceAll("'", "''");
    String name = friendlyNames[sector] ?? sector;

    values.add('  (\'$sector\', \'$name\', \'$polyJson\'::jsonb, 0.0, 0)');
  }

  // Generate special sectors manually
  List<Map<String, double>> margalla = [
    {'lat': 33.7650, 'lng': 73.0200},
    {'lat': 33.7650, 'lng': 73.1000},
    {'lat': 33.7400, 'lng': 73.1000},
    {'lat': 33.7350, 'lng': 73.0700},
    {'lat': 33.7400, 'lng': 73.0200},
  ];
  values.add('  (\'Margalla Trails\', \'${friendlyNames['Margalla Trails']}\', \'${jsonEncode(margalla)}\'::jsonb, 0.0, 0)');

  List<Map<String, double>> lakeView = [
    {'lat': 33.7150, 'lng': 73.1100},
    {'lat': 33.7150, 'lng': 73.1500},
    {'lat': 33.6900, 'lng': 73.1500},
    {'lat': 33.6900, 'lng': 73.1100},
  ];
  values.add('  (\'Lake View Park\', \'${friendlyNames['Lake View Park']}\', \'${jsonEncode(lakeView)}\'::jsonb, 0.0, 0)');

  List<Map<String, double>> diplo = [
    {'lat': 33.7350, 'lng': 73.1000},
    {'lat': 33.7350, 'lng': 73.1250},
    {'lat': 33.7200, 'lng': 73.1250},
    {'lat': 33.7200, 'lng': 73.1000},
  ];
  values.add('  (\'Diplomatic Enclave\', \'${friendlyNames['Diplomatic Enclave']}\', \'${jsonEncode(diplo)}\'::jsonb, 0.0, 0)');

  sqlLines.add(values.join(',\n') + ' ON CONFLICT (id) DO UPDATE SET polygon_coords = EXCLUDED.polygon_coords, name = EXCLUDED.name;');
  
  file.writeAsStringSync(sqlLines.join('\n'));
  print('Generated c:/fortrun/seed_zones.sql successfully.');
}
