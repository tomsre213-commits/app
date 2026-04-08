import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tindak/pages/ride/user_navigation_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _hasCameraPermission = false;
  bool _isCheckingPermission = true;
  bool _isScanned = false;
  bool _torchOn = false;
  bool _isUnlocking = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.request();

    if (!mounted) return;

    setState(() {
      _hasCameraPermission = status.isGranted;
      _isCheckingPermission = false;
    });

    if (_hasCameraPermission) {
      await _controller.start();
    }
  }

  Future<String> unlockBike(String bikeId) async {
    final ref = FirebaseDatabase.instance.ref('bikes/$bikeId');
    final snapshot = await ref.get();

    if (!snapshot.exists) {
      throw Exception('Bike not found');
    }

    final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

    final currentPadlock =
        data['padlock']?.toString().trim().toLowerCase() ?? 'locked';

    final reservedEmail = data['userEmail']?.toString().trim().toLowerCase() ?? '';
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserEmail = currentUser?.email?.trim().toLowerCase() ?? '';

    if (currentPadlock == 'unlocked') {
      return 'already_unlocked';
    }

    if (currentPadlock == 'reserve') {
      if (reservedEmail != currentUserEmail) {
        return 'reserved_by_other';
      }
    }

    await ref.update({
      'padlock': 'unlocked',
      'userEmail': null,
    });

    return 'unlocked';
  }

  Future<void> _assignBikeToUser(String bikeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseDatabase.instance.ref('users/${user.uid}/currentRide').set({
      'bikeId': bikeId,
      'startedAt': ServerValue.timestamp,
      'status': 'active',
    });
  }

  String _getButtonText(String padlock, String bikeEmail) {
    final userEmail =
        FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';
    final normalizedBikeEmail = bikeEmail.trim().toLowerCase();

    switch (padlock) {
      case 'reserve':
        return normalizedBikeEmail == userEmail ? 'Unlock Bike' : 'Reserved';
      case 'unlocked':
        return 'In Use';
      default:
        return 'Unlock Bike';
    }
  }

  bool _isButtonDisabled(String padlock, String bikeEmail) {
    final userEmail =
        FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';
    final normalizedBikeEmail = bikeEmail.trim().toLowerCase();

    if (_isUnlocking) return true;
    if (padlock == 'unlocked') return true;
    if (padlock == 'reserve' && normalizedBikeEmail != userEmail) return true;

    return false;
  }

  Color _getButtonColor(String padlock, String bikeEmail) {
    final userEmail =
        FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';
    final normalizedBikeEmail = bikeEmail.trim().toLowerCase();

    if (padlock == 'unlocked') {
      return Colors.grey;
    }

    if (padlock == 'reserve' && normalizedBikeEmail != userEmail) {
      return Colors.grey;
    }

    return const Color(0xFF7ED957);
  }

  String _getStatusText(String padlock, String bikeEmail) {
    final userEmail =
        FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';
    final normalizedBikeEmail = bikeEmail.trim().toLowerCase();

    if (padlock == 'unlocked') {
      return 'In Use';
    }

    if (padlock == 'reserve') {
      return normalizedBikeEmail == userEmail
          ? 'Reserved by You'
          : 'Reserved';
    }

    return 'Available';
  }

  String _getDescriptionText(String padlock, String bikeEmail) {
    final userEmail =
        FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';
    final normalizedBikeEmail = bikeEmail.trim().toLowerCase();

    if (padlock == 'reserve') {
      if (normalizedBikeEmail == userEmail) {
        return 'This bike is reserved for you. You can unlock it now.';
      }
      return 'This bike is currently reserved.';
    }

    if (padlock == 'unlocked') {
      return 'This bike is currently in use.';
    }

    return 'Ready to unlock this bike?';
  }

  Color _getStatusBackgroundColor(String padlock, String bikeEmail) {
    final userEmail =
        FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';
    final normalizedBikeEmail = bikeEmail.trim().toLowerCase();

    if (padlock == 'locked') return Colors.green.shade50;
    if (padlock == 'reserve' && normalizedBikeEmail == userEmail) {
      return Colors.orange.shade50;
    }
    if (padlock == 'reserve') return Colors.blue.shade50;
    return Colors.red.shade50;
  }

  Color _getStatusBorderColor(String padlock, String bikeEmail) {
    final userEmail =
        FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';
    final normalizedBikeEmail = bikeEmail.trim().toLowerCase();

    if (padlock == 'locked') return Colors.green.shade200;
    if (padlock == 'reserve' && normalizedBikeEmail == userEmail) {
      return Colors.orange.shade200;
    }
    if (padlock == 'reserve') return Colors.blue.shade200;
    return Colors.red.shade200;
  }

  Color _getStatusTextColor(String padlock, String bikeEmail) {
    final userEmail =
        FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';
    final normalizedBikeEmail = bikeEmail.trim().toLowerCase();

    if (padlock == 'locked') return Colors.green.shade800;
    if (padlock == 'reserve' && normalizedBikeEmail == userEmail) {
      return Colors.orange.shade800;
    }
    if (padlock == 'reserve') return Colors.blue.shade800;
    return Colors.red.shade800;
  }

  Color _getIconBackgroundColor(String padlock, String bikeEmail) {
    return _getStatusBackgroundColor(padlock, bikeEmail);
  }

  Color _getIconColor(String padlock, String bikeEmail) {
    final userEmail =
        FirebaseAuth.instance.currentUser?.email?.trim().toLowerCase() ?? '';
    final normalizedBikeEmail = bikeEmail.trim().toLowerCase();

    if (padlock == 'locked') return Colors.green.shade700;
    if (padlock == 'reserve' && normalizedBikeEmail == userEmail) {
      return Colors.orange.shade700;
    }
    if (padlock == 'reserve') return Colors.blue.shade700;
    return Colors.red.shade700;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isScanned || _isUnlocking) return;

    final Barcode? barcode =
    capture.barcodes.isNotEmpty ? capture.barcodes.first : null;

    final String code = barcode?.rawValue?.trim() ?? '';

    if (code.isEmpty) return;

    debugPrint('Scanned QR raw value: [$code]');

    String normalizedCode = code.toLowerCase().trim();
    normalizedCode = normalizedCode.replaceAll(' ', '');
    normalizedCode = normalizedCode.replaceAll('_', '');

    final match = RegExp(r'bike(\d+)').firstMatch(normalizedCode);
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid bike QR code: $code'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    normalizedCode = 'bike${match.group(1)}';

    setState(() {
      _isScanned = true;
    });

    final bikeRef = FirebaseDatabase.instance.ref('bikes/$normalizedCode');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StreamBuilder<DatabaseEvent>(
          stream: bikeRef.onValue,
          builder: (context, snapshot) {
            String currentPadlock = 'locked';
            String bikeEmail = '';

            if (snapshot.hasData &&
                snapshot.data!.snapshot.exists &&
                snapshot.data!.snapshot.value != null) {
              final data = Map<dynamic, dynamic>.from(
                snapshot.data!.snapshot.value as Map,
              );
              currentPadlock =
                  data['padlock']?.toString().trim().toLowerCase() ?? 'locked';
              bikeEmail =
                  data['userEmail']?.toString().trim().toLowerCase() ?? '';
            }

            final buttonText = _getButtonText(currentPadlock, bikeEmail);
            final isDisabled = _isButtonDisabled(currentPadlock, bikeEmail);

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: _getIconBackgroundColor(
                              currentPadlock,
                              bikeEmail,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.qr_code_2_rounded,
                            size: 38,
                            color: _getIconColor(currentPadlock, bikeEmail),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'QR Code Scanned',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getDescriptionText(currentPadlock, bikeEmail),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: SelectableText(
                            normalizedCode,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusBackgroundColor(
                              currentPadlock,
                              bikeEmail,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getStatusBorderColor(
                                currentPadlock,
                                bikeEmail,
                              ),
                            ),
                          ),
                          child: Text(
                            'Status: ${_getStatusText(currentPadlock, bikeEmail)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _getStatusTextColor(
                                currentPadlock,
                                bikeEmail,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isDisabled
                                ? null
                                : () async {
                              setDialogState(() {
                                _isUnlocking = true;
                              });

                              try {
                                final result =
                                await unlockBike(normalizedCode);

                                if (!mounted) return;

                                if (result == 'already_unlocked') {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Bike ${normalizedCode.replaceAll('bike', '')} is already in use',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );

                                  setDialogState(() {
                                    _isUnlocking = false;
                                  });
                                  return;
                                }

                                if (result == 'reserved_by_other') {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'This bike is reserved by another user',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );

                                  setDialogState(() {
                                    _isUnlocking = false;
                                  });
                                  return;
                                }

                                await _assignBikeToUser(normalizedCode);

                                if (!mounted) return;

                                Navigator.pop(dialogContext);

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Bike ${normalizedCode.replaceAll('bike', '')} unlocked 🚲',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );

                                setState(() {
                                  _isUnlocking = false;
                                });

                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserNavigationPage(
                                      bikeId: normalizedCode,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;

                                Navigator.pop(dialogContext);

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content:
                                    Text('Failed to unlock bike: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );

                                setState(() {
                                  _isScanned = false;
                                  _isUnlocking = false;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              _getButtonColor(currentPadlock, bikeEmail),
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade600,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isUnlocking
                                ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black,
                              ),
                            )
                                : Text(
                              buttonText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: _isUnlocking
                                ? null
                                : () {
                              Navigator.pop(dialogContext);
                              if (mounted) {
                                setState(() {
                                  _isScanned = false;
                                });
                              }
                            },
                            child: const Text(
                              'Scan Again',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
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
          },
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isScanned = false;
          _isUnlocking = false;
        });
      }
    });
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (!mounted) return;

    setState(() {
      _torchOn = !_torchOn;
    });
  }

  Widget _buildScannerBody() {
    if (_isCheckingPermission) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (!_hasCameraPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 60,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera permission required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _checkCameraPermission,
                child: const Text('Allow Camera'),
              ),
            ],
          ),
        ),
      );
    }

    return MobileScanner(
      controller: _controller,
      onDetect: _handleBarcode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildScannerBody(),
          Container(
            color: Colors.black.withOpacity(0.35),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Scan to Unlock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 30),
                ],
              ),
            ),
          ),
          if (_hasCameraPermission) ...[
            Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 5),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
            Positioned(
              bottom: 90,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _toggleTorch,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 10,
                            color: Colors.black26,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _torchOn ? Icons.flash_on : Icons.flashlight_off,
                        size: 34,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}