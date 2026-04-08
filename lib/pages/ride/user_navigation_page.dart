import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class UserNavigationPage extends StatefulWidget {
  final String bikeId;

  const UserNavigationPage({
    super.key,
    required this.bikeId,
  });

  @override
  State<UserNavigationPage> createState() => _UserNavigationPageState();
}

class _UserNavigationPageState extends State<UserNavigationPage> {
  GoogleMapController? _mapController;
  String? _lastGeofenceStatus;

  static const LatLng _defaultCenter = LatLng(8.2415, 124.2439);

  LatLng _currentCenter = _defaultCenter;
  bool _locationEnabled = false;
  bool _loadingLocation = true;
  bool _isEndingRide = false;

  final DatabaseReference _bikesRef =
  FirebaseDatabase.instance.ref().child('bikes');

  final DatabaseReference _usersRef =
  FirebaseDatabase.instance.ref().child('users');

  double _currentZoom = 17.0;

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<DatabaseEvent>? _bikeLiveSubscription;
  StreamSubscription<DatabaseEvent>? _trackSubscription;

  Timer? _bikeMoveTimer;

  BitmapDescriptor? _bikeIcon;
  Marker? _bikeMarker;
  LatLng? _bikeMarkerPosition;
  LatLng? _lastTrackedBikePosition;
  double _bikeMarkerRotation = 0;

  List<LatLng> _trackPoints = [];
  Set<Polyline> _polylines = {};

  double _totalDistanceMeters = 0;
  String? _lastSavedBikePointKey;

  final Set<Polygon> _msuIitPolygons = {
    const Polygon(
      polygonId: PolygonId('msu_iit_zone'),
      points: [
        LatLng(8.2440, 124.2430),
        LatLng(8.2440, 124.2431),
        LatLng(8.2437, 124.2433),
        LatLng(8.2435, 124.2433),
        LatLng(8.2430, 124.2439),
        LatLng(8.2432, 124.2441),
        LatLng(8.2431, 124.2442),
        LatLng(8.2431, 124.2443),
        LatLng(8.2431, 124.2444),
        LatLng(8.2431, 124.2445),
        LatLng(8.2422, 124.2443),
        LatLng(8.2419, 124.2449),
        LatLng(8.2401, 124.2446),
        LatLng(8.2399, 124.2448),
        LatLng(8.2399, 124.2449),
        LatLng(8.2394, 124.2445),
        LatLng(8.2391, 124.2443),
        LatLng(8.2394, 124.2434),
        LatLng(8.2395, 124.2430),
        LatLng(8.2400, 124.2430),
        LatLng(8.2399, 124.2428),
        LatLng(8.2400, 124.2426),
        LatLng(8.2407, 124.2427),
        LatLng(8.2410, 124.2430),
        LatLng(8.2418, 124.2432),
        LatLng(8.2418, 124.2430),
        LatLng(8.2422, 124.2430),
        LatLng(8.2423, 124.2426),
        LatLng(8.2423, 124.2421),
        LatLng(8.2430, 124.2422),
        LatLng(8.2430, 124.2424),
        LatLng(8.2435, 124.2426),
      ],
      strokeWidth: 2,
      strokeColor: Color(0xFF32CD32),
      fillColor: Color(0x4432CD32),
    ),
  };

  Set<Polygon> get _visiblePolygons {
    if (_currentZoom >= 18.0) {
      return {};
    }
    return _msuIitPolygons;
  }

  @override
  void initState() {
    super.initState();
    _totalDistanceMeters = 0;
    _lastTrackedBikePosition = null;
    _initLocation();
    _loadBikeIcon();
    _listenToAssignedBike();
    _startUserTracking();
    _listenToTrack();
  }

  Future<void> _loadBikeIcon() async {
    try {
      final icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(64, 64)),
        'assets/icons/blue_bike_marker.png',
      );

      if (!mounted) return;

      setState(() {
        _bikeIcon = icon;
      });
    } catch (e) {
      debugPrint('Failed to load bike icon: $e');
    }
  }

  Future<void> _initLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _loadingLocation = false;
        });
        return;
      }

      final rideSnapshot = await _usersRef.child('${user.uid}/currentRide').get();

      if (!rideSnapshot.exists) {
        if (!mounted) return;
        setState(() {
          _loadingLocation = false;
        });
        return;
      }

      final rideData = Map<dynamic, dynamic>.from(rideSnapshot.value as Map);
      final bikeId = rideData['bikeId']?.toString() ?? widget.bikeId;

      final bikeSnapshot = await _bikesRef.child(bikeId).get();
      if (!bikeSnapshot.exists) {
        if (!mounted) return;
        setState(() {
          _loadingLocation = false;
        });
        return;
      }

      final bikeData = Map<dynamic, dynamic>.from(bikeSnapshot.value as Map);
      final lat = (bikeData['latitude'] as num?)?.toDouble();
      final lng = (bikeData['longitude'] as num?)?.toDouble();

      if (lat == null || lng == null) {
        if (!mounted) return;
        setState(() {
          _loadingLocation = false;
        });
        return;
      }

      final bikeLatLng = LatLng(lat, lng);

      if (!mounted) return;

      setState(() {
        _currentCenter = bikeLatLng;
        _loadingLocation = false;
      });

      _setBikeMarker(bikeLatLng);
      await _moveCamera(bikeLatLng);
    } catch (e) {
      debugPrint('_initLocation error: $e');
      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
      });
    }
  }

  Future<void> _moveCamera(LatLng target) async {
    if (_mapController == null) return;

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 17),
      ),
    );
  }

  Future<void> _refreshCurrentLocation() async {
    if (_bikeMarkerPosition == null) return;
    await _moveCamera(_bikeMarkerPosition!);
  }

  LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final double lat1 = start.latitude * pi / 180.0;
    final double lon1 = start.longitude * pi / 180.0;
    final double lat2 = end.latitude * pi / 180.0;
    final double lon2 = end.longitude * pi / 180.0;

    final double dLon = lon2 - lon1;
    final double y = sin(dLon) * cos(lat2);
    final double x =
        cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final double bearing = atan2(y, x) * 180.0 / pi;
    return (bearing + 360.0) % 360.0;
  }

  void _setBikeMarker(LatLng position, {double rotation = 0}) {
    _bikeMarkerPosition = position;
    _bikeMarkerRotation = rotation;

    _bikeMarker = Marker(
      markerId: const MarkerId('assigned_bike'),
      position: position,
      icon: _bikeIcon ?? BitmapDescriptor.defaultMarker,
      flat: true,
      anchor: const Offset(0.5, 0.5),
      rotation: rotation,
      infoWindow: const InfoWindow(
        title: 'Your Bike 🚲',
        snippet: 'Currently in use',
      ),
    );
  }

  void _animateBikeMarkerTo(LatLng target) {
    final current = _bikeMarkerPosition;

    if (current == null) {
      if (!mounted) return;
      setState(() {
        _setBikeMarker(target);
      });
      return;
    }

    _bikeMoveTimer?.cancel();

    final double bearing = _calculateBearing(current, target);
    const int steps = 20;
    int step = 0;

    _bikeMoveTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) {
          step++;

          final double t = step / steps;
          final LatLng animatedPosition = _lerpLatLng(current, target, t);

          if (!mounted) {
            timer.cancel();
            return;
          }

          setState(() {
            _setBikeMarker(animatedPosition, rotation: bearing);
          });

          if (step >= steps) {
            timer.cancel();
            if (!mounted) return;
            setState(() {
              _setBikeMarker(target, rotation: bearing);
            });
          }
        });
  }

  Future<void> _saveBikeTrackPoint({
    required String uid,
    required double latitude,
    required double longitude,
    required int timestamp,
  }) async {
    final pointKey =
        '${latitude.toStringAsFixed(7)}_${longitude.toStringAsFixed(7)}';

    if (_lastSavedBikePointKey == pointKey) {
      return;
    }

    _lastSavedBikePointKey = pointKey;

    final trackRef = _usersRef.child('$uid/currentRide/track').push();

    await trackRef.set({
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
    });
  }

  Future<void> _listenToAssignedBike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final rideSnapshot = await _usersRef.child('${user.uid}/currentRide').get();
    if (!rideSnapshot.exists) return;

    final rideData = Map<dynamic, dynamic>.from(rideSnapshot.value as Map);
    final bikeId = rideData['bikeId']?.toString() ?? widget.bikeId;

    _bikeLiveSubscription?.cancel();

    _bikeLiveSubscription =
        _bikesRef.child(bikeId).onValue.listen((event) async {
          final raw = event.snapshot.value;
          if (raw == null || raw is! Map) return;

          final bikeData = Map<dynamic, dynamic>.from(raw);
          final lat = (bikeData['latitude'] as num?)?.toDouble();
          final lng = (bikeData['longitude'] as num?)?.toDouble();

          if (lat == null || lng == null) return;

          final timestampRaw = bikeData['timestamp'];
          final int timestamp = timestampRaw is int
              ? timestampRaw
              : int.tryParse(timestampRaw?.toString() ?? '') ??
              DateTime.now().millisecondsSinceEpoch;

          final newBikePosition = LatLng(lat, lng);

          await _updateGeofenceStatus(
            bikeId: bikeId,
            position: newBikePosition,
          );

          if (_lastTrackedBikePosition == null) {
            _lastTrackedBikePosition = newBikePosition;

            await _saveBikeTrackPoint(
              uid: user.uid,
              latitude: lat,
              longitude: lng,
              timestamp: timestamp,
            );
          } else {
            final segmentMeters = Geolocator.distanceBetween(
              _lastTrackedBikePosition!.latitude,
              _lastTrackedBikePosition!.longitude,
              newBikePosition.latitude,
              newBikePosition.longitude,
            );

            if (segmentMeters >= 1.5) {
              if (mounted) {
                setState(() {
                  _totalDistanceMeters += segmentMeters;
                });
              }

              _lastTrackedBikePosition = newBikePosition;

              await _saveBikeTrackPoint(
                uid: user.uid,
                latitude: lat,
                longitude: lng,
                timestamp: timestamp,
              );
            }
          }

          if (!mounted) return;

          setState(() {
            _currentCenter = newBikePosition;
          });

          _animateBikeMarkerTo(newBikePosition);
          await _moveCamera(newBikePosition);

          await _usersRef.child('${user.uid}/currentRide').update({
            'bikeLatitude': lat,
            'bikeLongitude': lng,
          });
        });
  }

  Future<void> _startUserTracking() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _locationEnabled = true;
    });
  }

  void _listenToTrack() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _trackSubscription?.cancel();

    _trackSubscription =
        _usersRef.child('${user.uid}/currentRide/track').onValue.listen((event) {
          final raw = event.snapshot.value;

          if (raw == null || raw is! Map) {
            if (!mounted) return;

            setState(() {
              _trackPoints = [];
              _polylines = {};

              if (!_isEndingRide) {
                _totalDistanceMeters = 0;
              }
            });
            return;
          }

          final data = Map<dynamic, dynamic>.from(raw);
          final entries = data.entries.toList();

          entries.sort((a, b) {
            final aMap = Map<dynamic, dynamic>.from(a.value);
            final bMap = Map<dynamic, dynamic>.from(b.value);
            final aTs = int.tryParse(aMap['timestamp'].toString()) ?? 0;
            final bTs = int.tryParse(bMap['timestamp'].toString()) ?? 0;
            return aTs.compareTo(bTs);
          });

          final List<LatLng> points = [];

          for (final entry in entries) {
            final point = Map<dynamic, dynamic>.from(entry.value);
            final lat = (point['latitude'] as num?)?.toDouble();
            final lng = (point['longitude'] as num?)?.toDouble();

            if (lat != null && lng != null) {
              points.add(LatLng(lat, lng));
            }
          }

          final double totalMeters = _calculateTrackDistance(points);

          if (!mounted) return;

          setState(() {
            _trackPoints = points;
            _totalDistanceMeters = totalMeters;
            _polylines = {
              Polyline(
                polylineId: const PolylineId('user_track'),
                points: _trackPoints,
                width: 5,
                color: Colors.blue,
              ),
            };
          });
        });
  }

  double _calculateTrackDistance(List<LatLng> points) {
    double totalMeters = 0;

    for (int i = 1; i < points.length; i++) {
      totalMeters += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }

    return totalMeters;
  }

  bool _isPointInsideAnyPolygon(LatLng point) {
    for (final polygon in _msuIitPolygons) {
      if (_isPointInPolygon(point, polygon.points)) {
        return true;
      }
    }
    return false;
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool isInside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final double xi = polygon[i].latitude;
      final double yi = polygon[i].longitude;
      final double xj = polygon[j].latitude;
      final double yj = polygon[j].longitude;

      final bool intersect =
          ((yi > point.longitude) != (yj > point.longitude)) &&
              (point.latitude <
                  (xj - xi) *
                      (point.longitude - yi) /
                      ((yj - yi) == 0 ? 0.0000001 : (yj - yi)) +
                      xi);

      if (intersect) {
        isInside = !isInside;
      }

      j = i;
    }

    return isInside;
  }

  Future<void> _updateGeofenceStatus({
    required String bikeId,
    required LatLng position,
  }) async {
    final bool isInside = _isPointInsideAnyPolygon(position);
    final String newStatus = isInside ? 'in' : 'out';

    if (_lastGeofenceStatus == newStatus) return;

    _lastGeofenceStatus = newStatus;

    try {
      await _bikesRef.child(bikeId).update({
        'notif': newStatus,
      });

      debugPrint('Geofence status updated: $newStatus');
    } catch (e) {
      debugPrint('Failed to update geofence status: $e');
    }
  }

  List<LatLng> _extractTrackPointsFromRoute(Map<dynamic, dynamic> routeData) {
    final entries = routeData.entries.toList();

    entries.sort((a, b) {
      final aMap = Map<dynamic, dynamic>.from(a.value);
      final bMap = Map<dynamic, dynamic>.from(b.value);

      final aTs = int.tryParse(aMap['timestamp'].toString()) ?? 0;
      final bTs = int.tryParse(bMap['timestamp'].toString()) ?? 0;

      return aTs.compareTo(bTs);
    });

    final List<LatLng> points = [];

    for (final entry in entries) {
      final point = Map<dynamic, dynamic>.from(entry.value);
      final lat = (point['latitude'] as num?)?.toDouble();
      final lng = (point['longitude'] as num?)?.toDouble();

      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }

    return points;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _formatCurrentDateTime() {
    final now = DateTime.now();

    int hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '${now.month}/${now.day}/${now.year.toString().substring(2)} @$hour:$minute $amPm';
  }

  String _buildTransactionId(String bikeId, int endedAtMillis) {
    return '${bikeId.toUpperCase()}-$endedAtMillis';
  }

  Future<void> _showEndRideDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    InkWell(
                      onTap: () => Navigator.pop(dialogContext),
                      child: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.priority_high_rounded,
                    color: Colors.blue,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Are you sure?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This action can’t be undone. Please confirm if you want to proceed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await _endRideAndShowPayment();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _endRideAndShowPayment() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _isEndingRide = true;

      final currentRideRef = _usersRef.child('${user.uid}/currentRide');
      final currentRideSnapshot = await currentRideRef.get();

      int? startedAt;
      Map<dynamic, dynamic> routeData = {};
      LatLng? startPoint;
      LatLng? endPoint;

      if (currentRideSnapshot.exists) {
        final rideData =
        Map<dynamic, dynamic>.from(currentRideSnapshot.value as Map);

        final startedAtValue = rideData['startedAt'];
        if (startedAtValue is int) {
          startedAt = startedAtValue;
        } else if (startedAtValue != null) {
          startedAt = int.tryParse(startedAtValue.toString());
        }

        final rawTrack = rideData['track'];
        if (rawTrack is Map) {
          routeData = Map<dynamic, dynamic>.from(rawTrack);

          final points = _extractTrackPointsFromRoute(routeData);

          if (points.isNotEmpty) {
            startPoint = points.first;
            endPoint = points.last;
          }
        }
      }

      final double finalDistanceMeters = routeData.isNotEmpty
          ? _calculateTrackDistance(_extractTrackPointsFromRoute(routeData))
          : _totalDistanceMeters;

      final endedAt = DateTime.now().millisecondsSinceEpoch;
      final transactionId = _buildTransactionId(widget.bikeId, endedAt);

      await _bikesRef.child(widget.bikeId).update({
        'padlock': 'locked',
        'reserveUntil': 0,
        'notif': 'not use',
      });

      await _usersRef.child('${user.uid}/history').push().set({
        'bikeId': widget.bikeId,
        'distanceMeters': finalDistanceMeters,
        'distanceText': _formatDistance(finalDistanceMeters),
        'startedAt': startedAt ?? endedAt,
        'endedAt': endedAt,
        'endedAtText': _formatCurrentDateTime(),
        'transactionId': transactionId,
        'status': 'completed',
        'route': routeData,
        'startPoint': startPoint == null
            ? null
            : {
          'latitude': startPoint.latitude,
          'longitude': startPoint.longitude,
        },
        'endPoint': endPoint == null
            ? null
            : {
          'latitude': endPoint.latitude,
          'longitude': endPoint.longitude,
        },
      });

      if (mounted) {
        setState(() {
          _totalDistanceMeters = finalDistanceMeters;
        });
      }

      await currentRideRef.remove();

      if (!mounted) return;

      _showPaymentConfirmedDialog(transactionId, finalDistanceMeters);
    } catch (e) {
      _isEndingRide = false;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to end ride: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPaymentConfirmedDialog(
      String transactionId,
      double finalDistanceMeters,
      ) {
    final parentContext = context;

    Widget infoRow({
      required String label,
      required String value,
      bool isBold = false,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                softWrap: true,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.green,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Payment\nConfirmed!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 28),

                  infoRow(
                    label: 'Distance',
                    value: _formatDistance(finalDistanceMeters),
                  ),
                  infoRow(
                    label: 'Date',
                    value: _formatCurrentDateTime(),
                  ),
                  infoRow(
                    label: 'Transaction ID',
                    value: transactionId,
                    isBold: true,
                  ),

                  const SizedBox(height: 26),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.of(parentContext)
                            .popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3F3F3F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'DONE',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isEndingRide = false;
    });
  }

  Widget _roundMapButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.95),
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.black54, size: 24),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _trackSubscription?.cancel();
    _bikeLiveSubscription?.cancel();
    _bikeMoveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 17,
            ),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            polygons: _visiblePolygons,
            polylines: _polylines,
            markers: {
              if (_bikeMarker != null) _bikeMarker!,
            },
            onCameraMove: (position) {
              if (_currentZoom != position.zoom) {
                setState(() {
                  _currentZoom = position.zoom;
                });
              }
            },
            onMapCreated: (controller) async {
              _mapController = controller;
              if (_bikeMarkerPosition != null) {
                await _moveCamera(_bikeMarkerPosition!);
              }
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _roundMapButton(
                    icon: Icons.person_outline,
                    onTap: () {},
                  ),
                  _roundMapButton(
                    icon: Icons.navigation_outlined,
                    onTap: _refreshCurrentLocation,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 90,
            child: SafeArea(
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Distance: ${_formatDistance(_totalDistanceMeters)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (_loadingLocation)
            const Positioned(
              top: 140,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text('Getting bike location...'),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 28,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 58,
                child: ElevatedButton(
                  onPressed: _showEndRideDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8BE08E),
                    foregroundColor: Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'End Ride',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
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