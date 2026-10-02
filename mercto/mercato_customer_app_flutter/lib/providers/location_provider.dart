import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

class LocationProvider extends ChangeNotifier {
  static const _libyanCities = <(String, String, double, double)>[
    ('طرابلس', 'Tripoli', 32.8872, 13.1913),
    ('بنغازي', 'Benghazi', 32.1194, 20.0868),
    ('مصراتة', 'Misrata', 32.3754, 15.0925),
    ('الزاوية', 'Zawiya', 32.7520, 12.7270),
    ('صبراتة', 'Sabratha', 32.7934, 12.4885),
    ('صرمان', 'Surman', 32.7560, 12.5716),
    ('الخمس', 'Khoms', 32.6486, 14.2619),
    ('زليتن', 'Zliten', 32.4674, 14.5687),
    ('سرت', 'Sirte', 31.2089, 16.5887),
    ('سبها', 'Sabha', 27.0377, 14.4283),
    ('درنة', 'Derna', 32.7670, 22.6370),
    ('طبرق', 'Tobruk', 32.0836, 23.9764),
    ('غريان', 'Gharyan', 32.1722, 13.0203),
    ('بني وليد', 'Bani Walid', 31.7566, 14.0014),
    ('جنزور', 'Janzour', 32.8150, 13.0180),
    ('تاجوراء', 'Tajura', 32.8820, 13.3500),
  ];

  static String nearestLibyanCity(
    double latitude,
    double longitude, {
    required bool arabic,
  }) {
    final nearest = _libyanCities.reduce((a, b) {
      double distance((String, String, double, double) city) {
        final northSouth = (city.$3 - latitude) * 111.0;
        final eastWest = (city.$4 - longitude) *
            111.0 *
            math.cos(latitude * math.pi / 180);
        return northSouth * northSouth + eastWest * eastWest;
      }

      return distance(a) <= distance(b) ? a : b;
    });
    final latDelta = (nearest.$3 - latitude) * 111.0;
    final lonDelta = (nearest.$4 - longitude) *
        111.0 *
        math.cos(latitude * math.pi / 180);
    final distanceKm = math.sqrt(latDelta * latDelta + lonDelta * lonDelta);
    if (distanceKm > 80) return arabic ? 'موقعي الحالي' : 'My location';
    return arabic ? nearest.$1 : nearest.$2;
  }

  Position? _position;
  bool _attempted = false;
  bool _locating = false;
  Future<Position?>? _pending;

  Position? get position => _position;
  bool get locating => _locating;

  Future<Position?> locate({bool force = false}) {
    if (!force && _position != null) return Future.value(_position);
    if (_pending != null) return _pending!;
    if (!force && _attempted) return Future.value(null);

    _pending = _locate().whenComplete(() => _pending = null);
    return _pending!;
  }

  Future<Position?> _locate() async {
    _attempted = true;
    _locating = true;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      _position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return _position;
    } catch (_) {
      return null;
    } finally {
      _locating = false;
      notifyListeners();
    }
  }
}
