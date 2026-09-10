import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class PlaceHit {
  const PlaceHit({required this.label, required this.detail, required this.point});

  final String label;
  final String detail;
  final LatLng point;
}

/// OpenStreetMap Nominatim geocoding, biased to Bangladesh.
///
/// Nominatim allows ~1 request/second, so callers must debounce typing.
class GeoService {
  GeoService({Dio? client})
      : _dio = client ??
            Dio(BaseOptions(
              baseUrl: 'https://nominatim.openstreetmap.org',
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
              headers: const {'User-Agent': 'BDRideShare/1.0 (support@bdride.share)'},
            ));

  final Dio _dio;

  /// Bounding box for Bangladesh so "Banani" does not resolve to another country.
  static const _viewbox = '88.0,26.7,92.7,20.5';

  Future<List<PlaceHit>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    try {
      final res = await _dio.get<List<dynamic>>('/search', queryParameters: {
        'q': q,
        'format': 'jsonv2',
        'addressdetails': 1,
        'limit': 8,
        'countrycodes': 'bd',
        'viewbox': _viewbox,
        'bounded': 1,
      });
      return (res.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_toHit)
          .whereType<PlaceHit>()
          .toList();
    } on DioException {
      return const [];
    }
  }

  /// Human-readable label for a dropped pin. Null when offline.
  Future<String?> reverse(LatLng point) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/reverse', queryParameters: {
        'lat': point.latitude,
        'lon': point.longitude,
        'format': 'jsonv2',
        'addressdetails': 1,
        'zoom': 17,
      });
      final data = res.data;
      if (data == null) return null;
      final address = data['address'];
      if (address is Map<String, dynamic>) {
        final short = _shortName(address);
        if (short != null) return short;
      }
      final display = data['display_name'];
      return display is String ? _firstParts(display, 2) : null;
    } on DioException {
      return null;
    }
  }

  PlaceHit? _toHit(Map<String, dynamic> json) {
    final lat = double.tryParse('${json['lat']}');
    final lon = double.tryParse('${json['lon']}');
    if (lat == null || lon == null) return null;

    final display = json['display_name'] is String ? json['display_name'] as String : '';
    final address = json['address'];
    final label = (address is Map<String, dynamic> ? _shortName(address) : null) ??
        _firstParts(display, 1);
    if (label.isEmpty) return null;

    return PlaceHit(
      label: label,
      detail: _firstParts(display, 3),
      point: LatLng(lat, lon),
    );
  }

  String? _shortName(Map<String, dynamic> address) {
    for (final key in const [
      'name',
      'amenity',
      'building',
      'road',
      'neighbourhood',
      'suburb',
      'quarter',
      'city_district',
      'city',
    ]) {
      final value = address[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String _firstParts(String display, int count) {
    final parts = display
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    return parts.take(count).join(', ');
  }
}
