import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../models/recorded_run.dart';

class RunRouteMap extends StatefulWidget {
  const RunRouteMap({
    super.key,
    required this.segments,
    this.position,
    this.live = false,
    this.showTiles = true,
  });

  final List<List<RunFix>> segments;
  final RunFix? position;
  final bool live;
  final bool showTiles;

  @override
  State<RunRouteMap> createState() => _RunRouteMapState();
}

class _RunRouteMapState extends State<RunRouteMap> {
  final _controller = MapController();
  bool _ready = false;
  bool _tileError = false;
  late bool _follow = widget.live;

  LatLng _latLng(RunFix point) => LatLng(point.latitude, point.longitude);
  List<LatLng> get _points =>
      widget.segments.expand((s) => s).map(_latLng).toList();

  @override
  void didUpdateWidget(RunRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && oldWidget.live && !widget.live) {
      _recenter();
      return;
    }
    if (_ready &&
        _follow &&
        widget.position != null &&
        widget.position != oldWidget.position) {
      _controller.move(
        _latLng(widget.position!),
        oldWidget.position == null && oldWidget.segments.isEmpty
            ? 16
            : _controller.camera.zoom,
      );
    }
  }

  void _recenter() {
    _follow = widget.live;
    if (widget.live && widget.position != null) {
      _controller.move(_latLng(widget.position!), _controller.camera.zoom);
    } else if (_points.length > 1) {
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(_points),
          padding: const EdgeInsets.all(35),
          maxZoom: 17,
        ),
      );
    } else if (_points.isNotEmpty) {
      _controller.move(_points.first, 16);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final color = Theme.of(context).colorScheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: widget.position != null
                  ? _latLng(widget.position!)
                  : points.firstOrNull ?? const LatLng(0, 0),
              initialZoom: points.isEmpty && widget.position == null ? 2 : 16,
              initialCameraFit: !widget.live && points.length > 1
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(points),
                      padding: const EdgeInsets.all(35),
                      maxZoom: 17,
                    )
                  : null,
              onMapReady: () => _ready = true,
              onPositionChanged: (_, hasGesture) {
                if (hasGesture) _follow = false;
              },
            ),
            children: [
              if (widget.showTiles)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.runnyai.app',
                  errorTileCallback: (_, _, _) {
                    if (!_tileError && mounted) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _tileError = true);
                      });
                    }
                  },
                ),
              PolylineLayer(
                polylines: [
                  for (final segment in widget.segments)
                    if (segment.length > 1)
                      Polyline(
                        points: segment.map(_latLng).toList(),
                        strokeWidth: 5,
                        color: color,
                      ),
                ],
              ),
              if (widget.position != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _latLng(widget.position!),
                      radius: widget.position!.accuracy,
                      useRadiusInMeter: true,
                      color: color.withValues(alpha: 0.12),
                      borderColor: color.withValues(alpha: 0.5),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (widget.position != null)
                    Marker(
                      point: _latLng(widget.position!),
                      width: 28,
                      height: 28,
                      child: Icon(
                        Icons.my_location,
                        color: color,
                        semanticLabel: context.translate(
                          'run_current_position',
                        ),
                      ),
                    )
                  else if (!widget.live && points.isNotEmpty) ...[
                    Marker(
                      point: points.first,
                      width: 28,
                      height: 28,
                      child: Icon(
                        Icons.trip_origin,
                        color: color,
                        semanticLabel: context.translate('run_route_start'),
                      ),
                    ),
                    Marker(
                      point: points.last,
                      width: 28,
                      height: 28,
                      child: Icon(
                        Icons.flag,
                        color: color,
                        semanticLabel: context.translate('run_route_end'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (widget.live && widget.position == null && points.isEmpty)
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(context.translate('run_map_waiting_location')),
                ),
              ),
            ),
          if (widget.position != null)
            Positioned(
              bottom: 28,
              left: 8,
              right: 8,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Material(
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      context.translate('run_gps_accuracy', [
                        widget.position!.accuracy.ceil().toString(),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          if (_tileError)
            Positioned(
              top: 8,
              left: 8,
              right: 56,
              child: Material(
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(context.translate('run_tiles_unavailable')),
                ),
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filledTonal(
              onPressed: _recenter,
              icon: const Icon(Icons.center_focus_strong),
              tooltip: context.translate('run_recenter'),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Material(
              color: Colors.white,
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    context.translate('run_map_attribution'),
                    style: const TextStyle(color: Colors.black, fontSize: 11),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
