import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:mercato/core/app_theme.dart';
import 'package:mercato/providers/location_provider.dart';

String _tx(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen(
      {super.key, this.initialLatitude, this.initialLongitude});

  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const _tripoli = LatLng(32.8872, 13.1913);
  final _controller = MapController();
  late LatLng _selected;
  String? _error;
  bool _locating = false;
  bool _satellite = false;
  bool _autoLocateStarted = false;

  bool get _arabic => Localizations.localeOf(context).languageCode == 'ar';
  String get _city => LocationProvider.nearestLibyanCity(
      _selected.latitude, _selected.longitude,
      arabic: _arabic);

  @override
  void initState() {
    super.initState();
    _selected =
        widget.initialLatitude != null && widget.initialLongitude != null
            ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
            : _tripoli;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_autoLocateStarted ||
        (widget.initialLatitude != null && widget.initialLongitude != null)) {
      return;
    }
    _autoLocateStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _useCurrentLocation(silentFailure: true, force: true);
      }
    });
  }

  Future<void> _useCurrentLocation(
      {bool silentFailure = false, bool force = true}) async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final position =
          await context.read<LocationProvider>().locate(force: force);
      if (!mounted) return;
      if (position == null) {
        if (silentFailure) return;
        throw StateError('location unavailable');
      }
      final point = LatLng(position.latitude, position.longitude);
      _controller.move(point, 16);
      setState(() => _selected = point);
    } catch (_) {
      if (mounted && !silentFailure)
        setState(() => _error = _tx(
            context,
            'تعذّر تحديد موقعك. فعّل خدمة الموقع واسمح للتطبيق بالوصول إليها، أو حرّك الخريطة يدويًا.',
            'Could not get your location. Enable location access or move the map manually.'));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _finish() => Navigator.of(context).pop(<String, dynamic>{
        'latitude': _selected.latitude,
        'longitude': _selected.longitude,
        'city': _city,
        'district': _tx(context, 'موقعي الحالي', 'My location'),
        'address_text': _tx(context, 'موقع التسليم المحدد على الخريطة',
            'Delivery point selected on the map'),
      });

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
                _tx(context, 'اختر موقع التوصيل', 'Choose delivery location')),
            actions: [
              IconButton(
                tooltip: _tx(context, 'موقعي الحالي', 'My location'),
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
              ),
            ],
          ),
          body: Stack(children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: _selected,
                initialZoom: 13,
                onTap: (_, point) {
                  _controller.move(point, _controller.camera.zoom);
                  setState(() => _selected = point);
                },
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture) setState(() => _selected = camera.center);
                },
              ),
              children: [
                const _FallbackMapLayer(),
                TileLayer(
                  urlTemplate: _satellite
                      ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mercato.customer',
                ),
              ],
            ),
            Positioned(
              top: 14,
              left: 16,
              right: 16,
              child: Material(
                elevation: 3,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                          color: AppColors.jade.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.location_on_rounded,
                          color: AppColors.jade),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              _tx(context, 'عنوان التوصيل', 'Delivery address'),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                      color: Theme.of(context).hintColor)),
                          const SizedBox(height: 3),
                          Text(_city,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ])),
                    IconButton(
                      tooltip: _satellite
                          ? _tx(context, 'عرض الخريطة', 'Map view')
                          : _tx(context, 'عرض القمر الصناعي', 'Satellite view'),
                      onPressed: () => setState(() => _satellite = !_satellite),
                      icon: Icon(_satellite
                          ? Icons.map_outlined
                          : Icons.satellite_alt_outlined),
                    ),
                  ]),
                ),
              ),
            ),
            const IgnorePointer(
                child: Center(
                    child: Icon(Icons.location_pin,
                        size: 54, color: AppColors.jade))),
            if (_error != null)
              Positioned(
                  top: 78,
                  left: 16,
                  right: 16,
                  child: Material(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!, textAlign: TextAlign.center)),
                  )),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(30)),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 22,
                            offset: Offset(0, -5))
                      ],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(
                              color: Theme.of(context).dividerColor,
                              borderRadius: BorderRadius.circular(4))),
                      const SizedBox(height: 16),
                      Row(children: [
                        const Icon(Icons.place_rounded,
                            color: AppColors.jade, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  _tx(context, 'الموقع المحدد',
                                      'Selected location'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                          color: Theme.of(context).hintColor)),
                              Text(_city,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                            ])),
                        OutlinedButton.icon(
                          onPressed: _locating ? null : _useCurrentLocation,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: Text(_tx(context, 'موقعي', 'My location')),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.jade,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16))),
                            onPressed: _finish,
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(
                                _tx(context, 'اختر هذا الموقع',
                                    'Use this location'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          )),
                    ]),
                  )),
            ),
          ]),
        ),
      );
}

/// A neutral decorative map visible underneath network tiles when offline.
class _FallbackMapLayer extends StatelessWidget {
  const _FallbackMapLayer();

  @override
  Widget build(BuildContext context) => const Positioned.fill(
        child:
            IgnorePointer(child: CustomPaint(painter: _FallbackMapPainter())),
      );
}

class _FallbackMapPainter extends CustomPainter {
  const _FallbackMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFFF5F6F8), BlendMode.src);
    final block = Paint()..color = const Color(0xFFE8EBEF);
    final outline = Paint()
      ..color = const Color(0xFFD9DEE5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var row = 0; row < 7; row++) {
      for (var col = 0; col < 5; col++) {
        final left = size.width * (.06 + col * .22) + (row.isOdd ? 12 : 0);
        final top = size.height * (.12 + row * .13);
        final rect =
            Rect.fromLTWH(left, top, size.width * .12, size.height * .065);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(5)), block);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(5)), outline);
      }
    }
    final road = Paint()
      ..color = const Color(0xFFD1D9E2)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-20, size.height * .36),
        Offset(size.width + 20, size.height * .29), road);
    canvas.drawLine(Offset(size.width * .27, -20),
        Offset(size.width * .68, size.height + 20), road);
    final smallRoad = Paint()
      ..color = const Color(0xFFE0E4E9)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-10, size.height * .72),
        Offset(size.width + 10, size.height * .76), smallRoad);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
