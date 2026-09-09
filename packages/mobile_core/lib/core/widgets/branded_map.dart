import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

const dhakaCenter = LatLng(23.8103, 90.4125);

class MapMarkerData {
  const MapMarkerData({
    required this.point,
    required this.kind,
  });

  final LatLng point;
  final MapPinKind kind;
}

enum MapPinKind { me, pickup, drop, driver, sos }

class BrandedMap extends StatelessWidget {
  const BrandedMap({
    super.key,
    this.center = dhakaCenter,
    this.zoom = 14,
    this.markers = const [],
    this.onTap,
    this.onMapReady,
    this.interactive = true,
    this.controller,
  });

  final LatLng center;
  final double zoom;
  final List<MapMarkerData> markers;
  final void Function(LatLng)? onTap;
  final VoidCallback? onMapReady;
  final bool interactive;
  final MapController? controller;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        onTap: onTap == null ? null : (tap, p) => onTap!(p),
        onMapReady: onMapReady,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.bdrideshare.app',
        ),
        MarkerLayer(
          markers: [
            for (final m in markers)
              Marker(
                point: m.point,
                width: 36,
                height: 36,
                child: _Pin(kind: m.kind),
              ),
          ],
        ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.kind});
  final MapPinKind kind;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (kind) {
      MapPinKind.me => (AppColors.navy900, PhosphorIconsFill.navigationArrow),
      MapPinKind.pickup => (AppColors.pickupPin, PhosphorIconsFill.mapPin),
      MapPinKind.drop => (AppColors.dropPin, PhosphorIconsFill.mapPin),
      MapPinKind.driver => (AppColors.navy900, PhosphorIconsFill.car),
      MapPinKind.sos => (AppColors.sosMarker, PhosphorIconsFill.shieldWarning),
    };
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      child: Icon(
        icon,
        size: 16,
        color: kind == MapPinKind.drop
            ? AppColors.textOnAccent
            : AppColors.textOnPrimary,
      ),
    );
  }
}
