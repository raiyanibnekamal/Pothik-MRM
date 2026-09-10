import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class RoutePath {
  const RoutePath({
    required this.points,
    required this.distanceKm,
    required this.durationMin,
    required this.snapped,
  });

  final List<LatLng> points;
  final double distanceKm;
  final int durationMin;

  /// False when the road network could not be reached and we drew a direct line.
  final bool snapped;
}

/// Road geometry from the public OSRM demo server, with a direct-line fallback.
class RouteService {
  RouteService({Dio? client})
      : _dio = client ??
            Dio(BaseOptions(
              baseUrl: 'https://router.project-osrm.org',
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
            ));

  final Dio _dio;
  final _cache = <String, RoutePath>{};

  Future<RoutePath> driving(LatLng from, LatLng to) async {
    final key = _key(from, to);
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
        queryParameters: const {
          'overview': 'full',
          'geometries': 'geojson',
          'alternatives': 'false',
          'steps': 'false',
        },
      );
      final route = _parse(res.data);
      if (route != null) {
        _cache[key] = route;
        return route;
      }
    } on DioException {
      // Fall through to the direct line below.
    }
    return _direct(from, to);
  }

  RoutePath? _parse(Map<String, dynamic>? data) {
    final routes = data?['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final first = routes.first;
    if (first is! Map<String, dynamic>) return null;

    final coords = first['geometry']?['coordinates'];
    if (coords is! List || coords.length < 2) return null;

    final points = <LatLng>[];
    for (final c in coords) {
      if (c is List && c.length >= 2) {
        final lon = (c[0] as num?)?.toDouble();
        final lat = (c[1] as num?)?.toDouble();
        if (lat != null && lon != null) points.add(LatLng(lat, lon));
      }
    }
    if (points.length < 2) return null;

    final meters = (first['distance'] as num?)?.toDouble() ?? 0;
    final seconds = (first['duration'] as num?)?.toDouble() ?? 0;
    return RoutePath(
      points: points,
      distanceKm: meters / 1000,
      durationMin: (seconds / 60).ceil(),
      snapped: true,
    );
  }

  RoutePath _direct(LatLng from, LatLng to) {
    const distance = Distance();
    final km = distance.as(LengthUnit.Kilometer, from, to);
    return RoutePath(
      points: [from, to],
      distanceKm: km,
      // Dhaka traffic averages roughly 20 km/h door to door.
      durationMin: (km / 20 * 60).ceil().clamp(1, 999),
      snapped: false,
    );
  }

  String _key(LatLng a, LatLng b) =>
      '${a.latitude.toStringAsFixed(4)},${a.longitude.toStringAsFixed(4)}'
      '|${b.latitude.toStringAsFixed(4)},${b.longitude.toStringAsFixed(4)}';
}
