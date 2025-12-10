import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../providers/nfc_provider.dart';
import '../models/nfc.dart';
import '../constants.dart';

/// NFC Reader Screen - Large circular NFC button with status
class NFCReaderScreen extends ConsumerStatefulWidget {
  final String busId;
  final bool isTapIn;

  const NFCReaderScreen({
    super.key,
    required this.busId,
    required this.isTapIn,
  });

  @override
  ConsumerState<NFCReaderScreen> createState() => _NFCReaderScreenState();
}

class _NFCReaderScreenState extends ConsumerState<NFCReaderScreen> {
  bool _isScanning = false;
  String _statusText = 'Tap to Scan';
  String? _detectedNFCId;
  bool _isProcessing = false;
  NfcTapResponse? _lastResponse;

  @override
  void initState() {
    super.initState();
    _checkNFCAvailability();
  }

  Future<void> _checkNFCAvailability() async {
    final nfcService = ref.read(nfcServiceProvider);
    final isAvailable = await nfcService.isAvailable();
    if (!isAvailable && mounted) {
      setState(() {
        _statusText = 'NFC Not Available';
      });
    }
  }

  Future<void> _startScan() async {
    if (_isScanning || _isProcessing) return;

    setState(() {
      _isScanning = true;
      _statusText = 'Waiting for NFC tag...';
      _detectedNFCId = null;
    });

    try {
      final nfcService = ref.read(nfcServiceProvider);
      
      // Set up callbacks
      nfcService.onSuccess = (response) {
        if (mounted) {
          HapticFeedback.mediumImpact();
          setState(() {
            _lastResponse = response;
            _statusText = widget.isTapIn ? 'Tap-In Successful' : 'Tap-Out Successful';
            _isScanning = false;
            _isProcessing = false;
          });
          _showResultBottomSheet(response);
        }
      };

      nfcService.onError = (error) {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _isProcessing = false;
            _statusText = error.contains('offline') ? 'Saved offline' : 'Error: $error';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: error.contains('offline') 
                  ? AppTheme.warningColor 
                  : AppTheme.errorColor,
            ),
          );
        }
      };

      nfcService.onProgress = (message) {
        if (mounted) {
          setState(() {
            _statusText = message;
          });
        }
      };

      // Read tag
      await nfcService.readTag(
        busId: widget.busId,
        isTapIn: widget.isTapIn,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusText = 'Error: ${e.toString()}';
          _isProcessing = false;
        });
      }
    }
  }

  /// Simulate NFC tap for testing (without NFC hardware)
  Future<void> _simulateNFCTap() async {
    if (_isScanning || _isProcessing) return;

    // Use first test card ID
    final testCardId = TEST_NFC_CARDS[0];
    
    setState(() {
      _detectedNFCId = testCardId;
      _statusText = 'Simulating...';
      _isProcessing = true;
    });

    try {
      final nfcService = ref.read(nfcServiceProvider);
      final apiService = nfcService.apiService;
      
      // Create event
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final event = NfcEvent(
        cardId: testCardId,
        busId: widget.busId,
        eventType: widget.isTapIn ? 'tap_in' : 'tap_out',
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: DateTime.now(),
      );

      // Try to process online
      try {
        NfcTapResponse response;
        if (widget.isTapIn) {
          response = await apiService.tapIn(event);
        } else {
          response = await apiService.tapOut(event);
        }

        HapticFeedback.mediumImpact();
        setState(() {
          _lastResponse = response;
          _statusText = widget.isTapIn ? 'Tap-In Successful' : 'Tap-Out Successful';
          _isProcessing = false;
        });
        _showResultBottomSheet(response);
      } catch (e) {
        // Save offline
        await nfcService.localDB.saveNFCLog(event);
        setState(() {
          _statusText = 'Saved offline (No connection)';
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved offline: ${e.toString()}'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Simulation error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        setState(() {
          _isProcessing = false;
          _statusText = 'Tap to Scan';
        });
      }
    }
  }

  void _showResultBottomSheet(NfcTapResponse response) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppTheme.spacingLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isTapIn ? 'Tap-In Result' : 'Tap-Out Result',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            CityGoCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (response.userName != null) ...[
                    _buildResultRow('Name', response.userName!),
                    const SizedBox(height: AppTheme.spacingSM),
                  ],
                  _buildResultRow('NFC ID', response.cardId ?? _detectedNFCId ?? 'N/A'),
                  const SizedBox(height: AppTheme.spacingSM),
                  _buildResultRow('Status', 'Success'),
                  if (response.fare != null) ...[
                    const SizedBox(height: AppTheme.spacingSM),
                    _buildResultRow('Fare', '\$${response.fare!.toStringAsFixed(2)}'),
                  ],
                  if (response.balance != null) ...[
                    const SizedBox(height: AppTheme.spacingSM),
                    _buildResultRow('Balance', '\$${response.balance!.toStringAsFixed(2)}'),
                  ],
                  if (response.co2Saved != null) ...[
                    const SizedBox(height: AppTheme.spacingSM),
                    _buildResultRow('CO₂ Saved', '${response.co2Saved!.toStringAsFixed(2)} kg'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            PrimaryButton(
              text: 'Done',
              onPressed: () => Navigator.pop(context),
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: TopBar(
        title: widget.isTapIn ? 'NFC Tap-In' : 'NFC Tap-Out',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large NFC Button
            NFCCircularButton(
              onPressed: _startScan,
              isScanning: _isScanning || _isProcessing,
              statusText: _statusText,
            ),
            const SizedBox(height: AppTheme.spacingXL),
            // Status Text
            Text(
              _statusText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            if (_detectedNFCId != null) ...[
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                'Card: $_detectedNFCId',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spacingXL),
            // Simulate Button (for testing)
            SecondaryButton(
              text: 'Simulate Tap-In',
              icon: Icons.sim_card,
              onPressed: _simulateNFCTap,
            ),
          ],
        ),
      ),
    );
  }
}
