import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Searchable map pin picker. The optional radius is drawn as a visible boundary.
class LocationPinPicker extends StatefulWidget {
  final LatLng initialLocation;
  final double? radiusMeters;
  final String title;

  const LocationPinPicker({
    super.key,
    required this.initialLocation,
    required this.title,
    this.radiusMeters,
  });

  static Future<LatLng?> show(
    BuildContext context, {
    required LatLng initialLocation,
    required String title,
    double? radiusMeters,
  }) => Navigator.of(context).push<LatLng>(
    MaterialPageRoute(
      builder:
          (_) => LocationPinPicker(
            initialLocation: initialLocation,
            title: title,
            radiusMeters: radiusMeters,
          ),
    ),
  );

  @override
  State<LocationPinPicker> createState() => _LocationPinPickerState();
}

class _LocationPinPickerState extends State<LocationPinPicker> {
  late LatLng _selected;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _searchError = null;
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    _searchDebounce = Timer(
      const Duration(milliseconds: 500),
      () => _search(query),
    );
  }

  Future<void> _search(String query) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query.trim(),
        'format': 'jsonv2',
        'limit': '5',
      });
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'GWProjectMobile/1.0 (location picker)',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const FormatException(
          'Location search is unavailable. Try again.',
        );
      }
      final data = jsonDecode(response.body);
      final results =
          data is List
              ? data.whereType<Map<String, dynamic>>().toList()
              : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        _searchError = results.isEmpty ? 'No matching locations found.' : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _searching = false;
          _searchError = 'Could not search locations. Check your connection.';
        });
      }
    }
  }

  void _selectResult(Map<String, dynamic> result) {
    final lat = double.tryParse(result['lat']?.toString() ?? '');
    final lng = double.tryParse(result['lon']?.toString() ?? '');
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) return;
    final point = LatLng(lat, lng);
    setState(() {
      _selected = point;
      _searchController.text =
          result['display_name']?.toString().split(',').take(2).join(',') ?? '';
      _results = [];
      _searchError = null;
    });
    _mapController.move(point, 16);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Column(
      children: [
        Expanded(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selected,
              initialZoom: 16,
              minZoom: 3,
              maxZoom: 19,
              onTap: (_, point) => setState(() => _selected = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gw.project',
              ),
              if (widget.radiusMeters != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _selected,
                      radius: widget.radiusMeters!,
                      useRadiusInMeter: true,
                      color: const Color(0x334F46E5),
                      borderColor: const Color(0xFF4F46E5),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selected,
                    width: 48,
                    height: 48,
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 44,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      elevation: 5,
                      borderRadius: BorderRadius.circular(14),
                      color: Theme.of(context).colorScheme.surface,
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _search,
                        decoration: InputDecoration(
                          hintText: 'Search address, area, or landmark',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon:
                              _searching
                                  ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                  : IconButton(
                                    tooltip: 'Search location',
                                    onPressed:
                                        () => _search(_searchController.text),
                                    icon: const Icon(
                                      Icons.arrow_forward_rounded,
                                    ),
                                  ),
                          isDense: true,
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    if (_results.isNotEmpty || _searchError != null)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        constraints: const BoxConstraints(maxHeight: 220),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 12),
                          ],
                        ),
                        child:
                            _results.isEmpty
                                ? ListTile(
                                  dense: true,
                                  title: Text(
                                    _searchError!,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                )
                                : ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _results.length,
                                  separatorBuilder:
                                      (_, __) => const Divider(height: 1),
                                  itemBuilder:
                                      (context, index) => ListTile(
                                        dense: true,
                                        leading: const Icon(
                                          Icons.place_outlined,
                                          size: 18,
                                          color: Color(0xFF4F46E5),
                                        ),
                                        title: Text(
                                          _results[index]['display_name']
                                                  ?.toString() ??
                                              'Location',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        onTap:
                                            () =>
                                                _selectResult(_results[index]),
                                      ),
                                ),
                      ),
                  ],
                ),
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Search or tap the map to place the pin  •  ${_selected.latitude.toStringAsFixed(6)}, ${_selected.longitude.toStringAsFixed(6)}',
                  textAlign: TextAlign.center,
                ),
                if (widget.radiusMeters != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${widget.radiusMeters!.toInt()} m geofence boundary',
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Use this location'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
