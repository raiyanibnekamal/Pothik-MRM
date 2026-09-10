import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile_core/core/l10n/app_strings.dart';
import 'package:mobile_core/core/location/geo_service.dart';
import 'package:mobile_core/core/location/location_cubit.dart';
import 'package:mobile_core/core/theme/app_colors.dart';
import 'package:mobile_core/core/theme/app_radius.dart';
import 'package:mobile_core/core/theme/app_shadows.dart';
import 'package:mobile_core/core/theme/app_text.dart';
import 'package:mobile_core/core/widgets/app_button.dart';
import 'package:mobile_core/core/widgets/app_chrome.dart';
import 'package:mobile_core/core/widgets/branded_map.dart';
import 'package:mobile_core/core/widgets/location_widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

class PickedPlace {
  const PickedPlace(this.point, this.label);

  final LatLng point;
  final String label;
}

enum MapPickMode { pickup, drop }

/// Centre-pin picker. Returns the confirmed point and its resolved address.
Future<PickedPlace?> showMapPicker(
  BuildContext context, {
  required MapPickMode mode,
  LatLng? initial,
}) {
  return Navigator.of(context).push<PickedPlace>(
    MaterialPageRoute(
      builder: (_) => MapPickScreen(mode: mode, initial: initial),
    ),
  );
}

class MapPickScreen extends StatefulWidget {
  const MapPickScreen({super.key, required this.mode, this.initial});

  final MapPickMode mode;
  final LatLng? initial;

  @override
  State<MapPickScreen> createState() => _MapPickScreenState();
}

class _MapPickScreenState extends State<MapPickScreen> {
  Timer? _debounce;
  LatLng? _center;
  String? _label;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _center = widget.initial ?? context.read<LocationCubit>().state.point;
    if (_center != null) _resolve(_center!);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onCameraChanged(LatLng center, bool hasGesture) {
    _center = center;
    if (!hasGesture) return;
    setState(() => _resolving = true);
    _debounce?.cancel();
    // Nominatim asks for at most one lookup per second.
    _debounce = Timer(const Duration(milliseconds: 700), () => _resolve(center));
  }

  Future<void> _resolve(LatLng point) async {
    setState(() => _resolving = true);
    final label = await context.read<GeoService>().reverse(point);
    if (!mounted) return;
    setState(() {
      _resolving = false;
      _label = label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final live = context.watch<LocationCubit>().state;
    final title =
        widget.mode == MapPickMode.pickup ? s.pickupPointTitle : s.dropPointTitle;
    final start = widget.initial ?? live.point ?? dhakaCenter;

    return Scaffold(
      appBar: AppBarBack(title: title),
      body: Stack(
        children: [
          BrandedMap(
            center: start,
            zoom: 16.5,
            showRecenter: true,
            overlayPadding: const EdgeInsets.only(bottom: 150),
            onCameraChanged: _onCameraChanged,
          ),
          // The pin sits at the optical centre of the map viewport.
          const IgnorePointer(child: Center(child: _CentrePin())),
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: LocationHealthCard(compact: true),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.sheetTop,
                boxShadow: AppShadows.md,
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.dragMapHint, style: AppText.helper()),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          PhosphorIconsFill.mapPin,
                          size: 18,
                          color: widget.mode == MapPickMode.pickup
                              ? AppColors.pickupPin
                              : AppColors.dropPin,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _resolving
                                ? s.locationSearching
                                : (_label ?? s.currentLocation),
                            style: AppText.label(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: s.confirmLocation,
                      height: 52,
                      onPressed: () {
                        final point = _center ?? start;
                        Navigator.pop(
                          context,
                          PickedPlace(point, _label ?? s.currentLocation),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CentrePin extends StatelessWidget {
  const _CentrePin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(PhosphorIconsFill.mapPin, size: 40, color: AppColors.navy900),
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.navy900,
            shape: BoxShape.circle,
          ),
        ),
        // Offsets the pin so its tip, not its middle, marks the centre.
        const SizedBox(height: 46),
      ],
    );
  }
}
