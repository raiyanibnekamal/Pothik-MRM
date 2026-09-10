import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/location/location_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_shadows.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

const dhakaCenter = LatLng(23.8103, 90.4125);

class MapMarkerData {
  const MapMarkerData({
    required this.point,
    required this.kind,
    this.headingDeg,
  });

  final LatLng point;
  final MapPinKind kind;
  final double? headingDeg;
}

enum MapPinKind { me, pickup, drop, driver, sos }

class BrandedMap extends StatefulWidget {
  const BrandedMap({
    super.key,
    this.center = dhakaCenter,
    this.zoom = 14,
    this.markers = const [],
    this.onTap,
    this.onMapReady,
    this.interactive = true,
    this.controller,
    this.showMe = true,
    this.follow = false,
    this.followZoom,
    this.route = const [],
    this.routeSnapped = true,
    this.fitPoints = const [],
    this.showRecenter = false,
    this.overlayPadding = EdgeInsets.zero,
    this.onCameraChanged,
  });

  final LatLng center;
  final double zoom;
  final List<MapMarkerData> markers;
  final void Function(LatLng)? onTap;
  final VoidCallback? onMapReady;
  final bool interactive;
  final MapController? controller;

  /// Draw the device's live position with an accuracy halo.
  final bool showMe;

  /// Keep the camera locked to the live position until the user pans.
  final bool follow;
  final double? followZoom;

  /// Road geometry to trace, usually from [RouteService].
  final List<LatLng> route;
  final bool routeSnapped;

  /// Points the camera should frame once the map is ready.
  final List<LatLng> fitPoints;

  final bool showRecenter;

  /// Keeps the recenter button and attribution clear of sheets.
  final EdgeInsets overlayPadding;

  /// Fires on every camera change, for centre-pin pickers.
  final void Function(LatLng center, bool hasGesture)? onCameraChanged;

  @override
  State<BrandedMap> createState() => _BrandedMapState();
}

class _BrandedMapState extends State<BrandedMap> {
  MapController? _own;
  bool _ready = false;
  bool _userMoved = false;
  String _fittedSignature = '';

  MapController get _map => widget.controller ?? (_own ??= MapController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _onReady() {
    _ready = true;
    _fitIfNeeded();
    widget.onMapReady?.call();
  }

  void _fitIfNeeded() {
    if (!_ready || _userMoved) return;
    final points = widget.fitPoints;
    if (points.length < 2) return;

    final signature = points
        .map((p) =>
            '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}')
        .join(';');
    if (signature == _fittedSignature) return;
    _fittedSignature = signature;

    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(56) + widget.overlayPadding,
        maxZoom: 16.5,
      ),
    );
  }

  void _recenter(LatLng point) {
    _userMoved = false;
    _map.move(point, widget.followZoom ?? 16.5);
  }

  @override
  Widget build(BuildContext context) {
    final live = widget.showMe || widget.follow
        ? context.watch<LocationCubit>().state
        : const LocationState();
    final mePoint = live.point;

    WidgetsBinding.instance.addPostFrameCallback((_) => _fitIfNeeded());

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: mePoint != null && widget.fitPoints.isEmpty
                ? mePoint
                : widget.center,
            initialZoom: widget.zoom,
            minZoom: 4,
            maxZoom: 19,
            backgroundColor: AppColors.gray100,
            onTap: widget.onTap == null ? null : (_, p) => widget.onTap!(p),
            onMapReady: _onReady,
            onPositionChanged: (camera, hasGesture) {
              widget.onCameraChanged?.call(camera.center, hasGesture);
              if (hasGesture && !_userMoved) {
                setState(() => _userMoved = true);
              }
            },
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? InteractiveFlag.all & ~InteractiveFlag.rotate
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.bdrideshare.app',
              retinaMode: RetinaMode.isHighDensity(context),
            ),
            if (widget.route.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.route,
                    strokeWidth: 5,
                    color: AppColors.navy900,
                    borderStrokeWidth: 2,
                    borderColor: AppColors.surface,
                    pattern: widget.routeSnapped
                        ? const StrokePattern.solid()
                        : StrokePattern.dashed(segments: const [10, 8]),
                  ),
                ],
              ),
            if (widget.showMe && mePoint != null && live.accuracyM != null)
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: mePoint,
                    radius: live.accuracyM!.clamp(8, 250),
                    useRadiusInMeter: true,
                    color: AppColors.navy500.withValues(alpha: 0.12),
                    borderColor: AppColors.navy500.withValues(alpha: 0.35),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final m in widget.markers)
                  Marker(
                    point: m.point,
                    width: 40,
                    height: 40,
                    child: _Pin(kind: m.kind, headingDeg: m.headingDeg),
                  ),
                if (widget.showMe && mePoint != null)
                  Marker(
                    point: mePoint,
                    width: 44,
                    height: 44,
                    child: _MeDot(headingDeg: live.headingDeg),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 8 + widget.overlayPadding.left,
          bottom: 6 + widget.overlayPadding.bottom,
          child: const _Attribution(),
        ),
        if (widget.showRecenter)
          Positioned(
            right: 16 + widget.overlayPadding.right,
            bottom: 16 + widget.overlayPadding.bottom,
            child: _RecenterButton(
              active: mePoint != null && !_userMoved,
              onTap: () async {
                final cubit = context.read<LocationCubit>();
                final point = cubit.state.point;
                if (point != null) _recenter(point);
                if (await cubit.ensure() && mounted) {
                  final next = cubit.state.point;
                  if (next != null) _recenter(next);
                }
              },
            ),
          ),
        if (widget.follow && mePoint != null && !_userMoved)
          _FollowCamera(point: mePoint, onMove: _recenter),
      ],
    );
  }
}

/// Moves the camera on every new fix without rebuilding the tile layer.
class _FollowCamera extends StatefulWidget {
  const _FollowCamera({required this.point, required this.onMove});

  final LatLng point;
  final void Function(LatLng) onMove;

  @override
  State<_FollowCamera> createState() => _FollowCameraState();
}

class _FollowCameraState extends State<_FollowCamera> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onMove(widget.point));
  }

  @override
  void didUpdateWidget(_FollowCamera old) {
    super.didUpdateWidget(old);
    if (old.point != widget.point) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => widget.onMove(widget.point));
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _MeDot extends StatefulWidget {
  const _MeDot({this.headingDeg});

  final double? headingDeg;

  @override
  State<_MeDot> createState() => _MeDotState();
}

class _MeDotState extends State<_MeDot> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heading = widget.headingDeg;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_pulse.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 20 + 24 * t,
              height: 20 + 24 * t,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.navy500.withValues(alpha: 0.22 * (1 - t)),
              ),
            ),
            if (heading != null && heading >= 0)
              Transform.rotate(
                angle: heading * math.pi / 180,
                child: const Icon(
                  PhosphorIconsFill.navigationArrow,
                  size: 14,
                  color: AppColors.navy900,
                ),
              ),
            if (heading == null || heading < 0)
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.navy900,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 3),
                  boxShadow: AppShadows.sm,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            active
                ? PhosphorIconsFill.crosshair
                : PhosphorIconsRegular.crosshair,
            size: 20,
            color: AppColors.navy900,
          ),
        ),
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.78),
        borderRadius: AppRadius.smAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          '© OpenStreetMap · CARTO',
          style: AppText.caption(AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.kind, this.headingDeg});

  final MapPinKind kind;
  final double? headingDeg;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (kind) {
      MapPinKind.me => (AppColors.navy900, PhosphorIconsFill.navigationArrow),
      MapPinKind.pickup => (AppColors.pickupPin, PhosphorIconsFill.mapPin),
      MapPinKind.drop => (AppColors.dropPin, PhosphorIconsFill.mapPin),
      MapPinKind.driver => (AppColors.navy900, PhosphorIconsFill.car),
      MapPinKind.sos => (AppColors.sosMarker, PhosphorIconsFill.shieldWarning),
    };
    final glyph = Icon(
      icon,
      size: 18,
      color: kind == MapPinKind.drop
          ? AppColors.textOnAccent
          : AppColors.textOnPrimary,
    );
    return Center(
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 2),
          boxShadow: AppShadows.sm,
        ),
        child: headingDeg == null
            ? glyph
            : Transform.rotate(angle: headingDeg! * math.pi / 180, child: glyph),
      ),
    );
  }
}
