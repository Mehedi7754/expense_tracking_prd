import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/attendance_model.dart';

class AttendanceMapView extends StatefulWidget {
  final List<AttendanceRecordModel> records;
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final Function(AttendanceRecordModel record)? onMarkerTap;

  const AttendanceMapView({
    super.key,
    required this.records,
    this.initialLat = 23.8103, // Default centroid (Dhaka / Central)
    this.initialLng = 90.4125,
    this.initialZoom = 12.0,
    this.onMarkerTap,
  });

  @override
  State<AttendanceMapView> createState() => _AttendanceMapViewState();
}

class _AttendanceMapViewState extends State<AttendanceMapView> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _recenter() {
    final validRecords = widget.records.where((r) => r.latitude != null && r.longitude != null).toList();
    if (validRecords.isNotEmpty) {
      final first = validRecords.first;
      _mapController.move(LatLng(first.latitude!, first.longitude!), 13.5);
    } else {
      _mapController.move(LatLng(widget.initialLat, widget.initialLng), widget.initialZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final validRecords = widget.records.where((r) => r.latitude != null && r.longitude != null).toList();

    LatLng center = LatLng(widget.initialLat, widget.initialLng);
    if (validRecords.isNotEmpty) {
      center = LatLng(validRecords.first.latitude!, validRecords.first.longitude!);
    }

    final markers = validRecords.map((record) {
      final isMorning = record.isMorning;
      final markerColor = isMorning ? const Color(0xFF4F46E5) : const Color(0xFF10B981);
      final initial = record.userName.isNotEmpty ? record.userName[0].toUpperCase() : 'U';

      return Marker(
        point: LatLng(record.latitude!, record.longitude!),
        width: 100,
        height: 90,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () {
            if (widget.onMarkerTap != null) {
              widget.onMarkerTap!(record);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Employee Name Tag Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: markerColor.withAlpha(140),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(35),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: markerColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        record.userName.split(' ').first,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),

              // 2. Teardrop Map Pin Head with User Initial & Session Badge
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: markerColor.withAlpha(120),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isMorning ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                        size: 9,
                        color: markerColor,
                      ),
                    ),
                  ),
                ],
              ),

              // 3. Pin Needle Pointer pointing straight down to coordinate
              Transform.translate(
                offset: const Offset(0, -7),
                child: Icon(
                  Icons.arrow_drop_down,
                  color: markerColor,
                  size: 20,
                ),
              ),

              // Ground Shadow
              Container(
                width: 12,
                height: 2.5,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(50),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: validRecords.isNotEmpty ? 15.0 : widget.initialZoom,
              minZoom: 4,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.gw.project',
              ),
              MarkerLayer(markers: markers),
            ],
          ),

          // Map Control Overlays
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'map_recenter',
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                  foregroundColor: const Color(0xFF4F46E5),
                  elevation: 4,
                  onPressed: _recenter,
                  child: const Icon(Icons.my_location_rounded, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'map_zoom_in',
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  elevation: 4,
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom + 1);
                  },
                  child: const Icon(Icons.add, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'map_zoom_out',
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  elevation: 4,
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom - 1);
                  },
                  child: const Icon(Icons.remove, size: 20),
                ),
              ],
            ),
          ),

          // Session Legend
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.darkSurface : Colors.white).withAlpha(235),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4F46E5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Morning Session', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 12),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Afternoon Session', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
