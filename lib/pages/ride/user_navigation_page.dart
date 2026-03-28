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

  static const LatLng _defaultCenter = LatLng(8.2415, 124.2439);

  LatLng _currentCenter = _defaultCenter;
  bool _locationEnabled = false;
  bool _loadingLocation = true;

  final DatabaseReference _bikesRef =
  FirebaseDatabase.instance.ref().child('bikes');

  double _currentZoom = 17.0;

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
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
          _loadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _loadingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {
        _currentCenter = userLatLng;
        _locationEnabled = true;
        _loadingLocation = false;
      });

      await _moveCamera(userLatLng);
    } catch (_) {
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
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {
        _currentCenter = userLatLng;
        _locationEnabled = true;
      });

      await _moveCamera(userLatLng);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get current location')),
      );
    }
  }

  Future<void> _endRide() async {
    try {
      await _bikesRef.child(widget.bikeId).update({
        'padlock': 'locked',
        'reserveUntil': 0,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bike ${widget.bikeId.replaceAll('bike', '')} ride ended',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to end ride: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showEndRideDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
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
                      onTap: () => Navigator.pop(context),
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
                        onPressed: () => Navigator.pop(context),
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
                          Navigator.pop(context);
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
      await _bikesRef.child(widget.bikeId).update({
        'padlock': 'locked',
        'reserveUntil': 0,
      });

      if (!mounted) return;

      _showPaymentConfirmedDialog();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to end ride: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPaymentConfirmedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.green,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Payment Confirmed!',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                Row(
                  children: const [
                    Expanded(
                      child: Text(
                        'Distance',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      '0.8 km',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: const [
                    Expanded(
                      child: Text(
                        'Date',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      '3/26/26 @5:00 PM',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: const [
                    Expanded(
                      child: Text(
                        'Transaction ID',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      'xxx',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 26),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.popUntil(this.context, (route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F3F3F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'DONE',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentCenter,
              zoom: 17,
            ),
            myLocationEnabled: _locationEnabled,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            polygons: _visiblePolygons,
            onCameraMove: (position) {
              if (_currentZoom != position.zoom) {
                setState(() {
                  _currentZoom = position.zoom;
                });
              }
            },
            onMapCreated: (controller) {
              _mapController = controller;
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

          if (_loadingLocation)
            const Positioned(
              top: 90,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text('Getting location...'),
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