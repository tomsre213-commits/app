import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final DatabaseReference _usersRef =
  FirebaseDatabase.instance.ref().child('users');

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F4F4),
        appBar: AppBar(
          title: const Text('Rental History'),
        ),
        body: const Center(
          child: Text('No user logged in'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F4),
      body: StreamBuilder<DatabaseEvent>(
        stream: _usersRef.child('${user.uid}/history').onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final raw = snapshot.data?.snapshot.value;

          List<_HistoryRide> rides = [];

          if (raw != null && raw is Map) {
            final historyMap = Map<dynamic, dynamic>.from(raw);

            rides = historyMap.entries.map((entry) {
              final item = Map<dynamic, dynamic>.from(entry.value);
              return _HistoryRide.fromMap(
                key: entry.key.toString(),
                map: item,
              );
            }).toList();

            rides.sort((a, b) => b.endedAt.compareTo(a.endedAt));
          }

          final grouped = _groupByMonth(rides);
          final totalRentals = rides.length;
          final averageMinutes = rides.isEmpty
              ? 0
              : rides
              .map((e) => e.durationMinutes)
              .reduce((a, b) => a + b) ~/
              rides.length;

          return SafeArea(
            child: Column(
              children: [
                _buildTopGreenHeader(context),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    transform: Matrix4.translationValues(0, -26, 0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4F4F4),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(38),
                        topRight: Radius.circular(38),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 18),
                        _buildTopStats(
                          totalRentals: totalRentals,
                          averageMinutes: averageMinutes,
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: rides.isEmpty
                              ? _buildEmptyState()
                              : ListView(
                            padding:
                            const EdgeInsets.fromLTRB(22, 6, 22, 28),
                            children: grouped.entries.map((entry) {
                              return _buildMonthSection(
                                monthTitle: entry.key,
                                rides: entry.value,
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopGreenHeader(BuildContext context) {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF00E64D),
            Color(0xFF00CC44),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 14,
            top: 10,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: EdgeInsets.only(top: 14),
                child: Text(
                  'Rental History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStats({
    required int totalRentals,
    required int averageMinutes,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAEAEA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Rentals: $totalRentals',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.access_time,
              size: 22,
              color: Colors.black54,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Average Time: ${_formatAverageMinutes(averageMinutes)}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSection({
    required String monthTitle,
    required List<_HistoryRide> rides,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        ...rides.map((ride) => _buildRideItem(ride)),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildRideItem(_HistoryRide ride) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Color(0xFFD8D8D8),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ID: ${ride.displayId}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ride.dateRangeText,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Duration: ${ride.durationText}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Distance: ${ride.distanceText}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 108,
            child: Padding(
              padding: const EdgeInsets.only(top: 26),
              child: Text(
                _beautifyStatus(ride.status),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _statusColor(ride.status),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 60),
        child: Text(
          'No rental history yet',
          style: TextStyle(
            fontSize: 18,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Map<String, List<_HistoryRide>> _groupByMonth(List<_HistoryRide> rides) {
    final Map<String, List<_HistoryRide>> grouped = {};

    for (final ride in rides) {
      final title = DateFormat('MMMM yyyy').format(ride.endedDateTime);
      grouped.putIfAbsent(title, () => []).add(ride);
    }

    return grouped;
  }

  static String _formatAverageMinutes(int minutes) {
    if (minutes <= 0) return '0 mins';
    if (minutes < 60) return '$minutes mins';

    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (mins == 0) return '$hours hr';
    return '$hours hr $mins mins';
  }

  static String _beautifyStatus(String raw) {
    switch (raw.toLowerCase()) {
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'in_progress':
        return 'In Progress';
      default:
        return raw.replaceAll('_', ' ');
    }
  }

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.black87;
      case 'cancelled':
        return Colors.redAccent;
      case 'in_progress':
        return Colors.orange.shade700;
      default:
        return Colors.black87;
    }
  }
}

class _HistoryRide {
  final String key;
  final String bikeId;
  final String transactionId;
  final String status;
  final int startedAt;
  final int endedAt;
  final double distanceMeters;
  final String distanceText;

  _HistoryRide({
    required this.key,
    required this.bikeId,
    required this.transactionId,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.distanceMeters,
    required this.distanceText,
  });

  factory _HistoryRide.fromMap({
    required String key,
    required Map<dynamic, dynamic> map,
  }) {
    final startedAt = _toInt(map['startedAt']);
    final endedAt = _toInt(map['endedAt']);

    final distanceMeters = _toDouble(map['distanceMeters']);
    final distanceText = map['distanceText']?.toString() ??
        (distanceMeters > 0
            ? (distanceMeters < 1000
            ? '${distanceMeters.toStringAsFixed(0)} m'
            : '${(distanceMeters / 1000).toStringAsFixed(2)} km')
            : '0 m');

    return _HistoryRide(
      key: key,
      bikeId: map['bikeId']?.toString() ?? 'Unknown Bike',
      transactionId: map['transactionId']?.toString() ?? key,
      status: map['status']?.toString() ?? 'completed',
      startedAt: startedAt,
      endedAt: endedAt,
      distanceMeters: distanceMeters,
      distanceText: distanceText,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime get startedDateTime =>
      DateTime.fromMillisecondsSinceEpoch(startedAt);

  DateTime get endedDateTime =>
      DateTime.fromMillisecondsSinceEpoch(endedAt);

  int get durationMinutes {
    if (startedAt <= 0 || endedAt <= 0 || endedAt < startedAt) return 0;
    return endedDateTime.difference(startedDateTime).inMinutes;
  }

  String get durationText {
    final minutes = durationMinutes;

    if (minutes <= 0) return '0 mins';
    if (minutes < 60) return '$minutes mins';

    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (mins == 0) {
      return hours == 1 ? '1 hour' : '$hours hours';
    }

    return '${hours == 1 ? '1 hour' : '$hours hours'} $mins mins';
  }

  String get dateRangeText {
    final sameDay = startedDateTime.year == endedDateTime.year &&
        startedDateTime.month == endedDateTime.month &&
        startedDateTime.day == endedDateTime.day;

    if (sameDay) {
      final dayText = DateFormat('MMM d').format(startedDateTime);
      final startTime = DateFormat('h:mm a').format(startedDateTime);
      final endTime = DateFormat('h:mm a').format(endedDateTime);
      return '$dayText, $startTime - $dayText, $endTime';
    }

    final start = DateFormat('MMM d, h:mm a').format(startedDateTime);
    final end = DateFormat('MMM d, h:mm a').format(endedDateTime);
    return '$start - $end';
  }

  String get displayId {
    if (transactionId.isNotEmpty) {
      return transactionId;
    }
    return key;
  }
}