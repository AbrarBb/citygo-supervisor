import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../providers/nfc_provider.dart';
import '../models/nfc.dart';
import '../models/card.dart';
import '../services/api_service.dart';
import '../constants.dart';

// Method channel for NFC intents from Android
const MethodChannel _nfcChannel = MethodChannel('com.example.flutter_application_1/nfc');

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
  String _statusText = 'Ready to Scan';
  String? _detectedNFCId;
  bool _isProcessing = false;
  bool _sessionActive = false;

  @override
  void initState() {
    super.initState();
    _checkNFCAvailability();
    // Set up method channel listener for NFC intents
    _setupNfcIntentListener();
    // Start NFC session immediately when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNFCSession();
    });
  }

  /// Set up listener for NFC intents from Android
  void _setupNfcIntentListener() {
    _nfcChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNfcIntent') {
        print('📱 Received NFC intent from Android: ${call.arguments}');
        // When Android sends NFC intent (user selected our app from dialog)
        // Try to read the tag immediately
        if (mounted && !_isProcessing) {
          _handleNfcIntent(call.arguments);
        }
      }
    });
  }

  /// Handle NFC intent received from Android
  Future<void> _handleNfcIntent(Map<dynamic, dynamic>? arguments) async {
    if (arguments == null) return;
    
    print('📱 Processing NFC intent: $arguments');
    
    // Check if Android already extracted the card ID from NDEF
    final cardIdFromIntent = arguments['cardId'] as String?;
    final hasNdef = arguments['hasNdef'] as bool? ?? false;
    
    if (cardIdFromIntent != null && cardIdFromIntent.isNotEmpty && hasNdef) {
      // Android already read the NDEF data, use it directly
      print('✅ Card ID extracted from intent NDEF: $cardIdFromIntent');
      if (mounted) {
        setState(() {
          _isProcessing = true;
          _statusText = 'Processing card...';
        });
        await _processDetectedCard(cardIdFromIntent);
      }
      return;
    }
    
    // If NDEF wasn't available, try to read the tag via session
    setState(() {
      _isProcessing = true;
      _statusText = 'Reading card from intent...';
    });

    try {
      final nfcService = ref.read(nfcServiceProvider);
      // Try to read the tag - the session should still be active
      final cardId = await nfcService.readNFCTag();
      
      if (cardId != null && mounted) {
        print('✅ Card ID read from session: $cardId');
        // Process the card
        await _processDetectedCard(cardId);
      } else {
        print('⚠️ Could not read card ID from intent or session');
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _statusText = 'Could not read card. Please tap again.';
          });
        }
      }
    } catch (e) {
      print('❌ Error handling NFC intent: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusText = 'Error reading card';
        });
      }
    }
  }

  /// Process a detected card (check registration and show info)
  Future<void> _processDetectedCard(String cardId) async {
    final apiService = ApiService();
    RegisteredCard? registeredCard;
    
    try {
      print('🔍 Checking card registration for: "$cardId"');
      registeredCard = await apiService.checkCardRegistration(cardId);
      print('🔍 Card registration check result: ${registeredCard != null ? "Found" : "Not found"}');
    } catch (e) {
      print('❌ Error checking card registration: $e');
    }
    
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _detectedNFCId = cardId;
      });
      
      if (registeredCard != null) {
        final cardToShow = RegisteredCard(
          cardId: registeredCard.cardId.isNotEmpty ? registeredCard.cardId : cardId,
          passengerName: registeredCard.passengerName,
          balance: registeredCard.balance,
          status: registeredCard.status,
          registeredAt: registeredCard.registeredAt,
          lastUsed: registeredCard.lastUsed,
        );
        
        _showCardInfoBottomSheet(cardToShow);
        final passengerName = registeredCard.passengerName;
        setState(() {
          _statusText = passengerName != null 
              ? 'Card registered - $passengerName' 
              : 'Card registered';
        });
      } else {
        _showCardNotRegisteredDialog(cardId);
        setState(() {
          _statusText = 'Card not registered';
        });
      }
    }
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

  /// Start NFC session immediately to detect tags as soon as screen loads
  Future<void> _startNFCSession() async {
    if (_sessionActive) {
      print('📱 NFC session already active');
      return;
    }

    try {
      final nfcService = ref.read(nfcServiceProvider);
      
      // Check if NFC is available
      final isAvailable = await nfcService.isAvailable();
      if (!isAvailable) {
        if (mounted) {
          setState(() {
            _statusText = 'NFC Not Available';
          });
        }
        print('⚠️ NFC not available on this device');
        return;
      }

      print('📱 Starting background NFC session...');
      
      // Set up callbacks for automatic tag detection
      nfcService.onSuccess = (response) {
        if (mounted) {
          HapticFeedback.mediumImpact();
          setState(() {
            _statusText = widget.isTapIn ? 'Tap-In Successful' : 'Tap-Out Successful';
            _isScanning = false;
            _isProcessing = false;
          });
          _showResultBottomSheet(response);
        }
      };

      nfcService.onError = (error) {
        if (mounted) {
          String displayError = error;
          String statusText = 'Ready to Scan';
          
          if (error.contains('Saved offline')) {
            statusText = 'Saved offline';
            final parts = error.split('Saved offline: ');
            if (parts.length > 1) {
              displayError = parts[1];
            }
          } else if (error.contains('No NFC') || error.contains('No card')) {
            statusText = 'Ready to Scan';
            // Don't show error snackbar for "no card" - it's normal
            return;
          } else {
            statusText = 'Error';
          }
          
          setState(() {
            _isScanning = false;
            _isProcessing = false;
            _statusText = statusText;
          });
          
          if (!error.contains('No NFC') && !error.contains('No card')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(displayError),
                backgroundColor: error.contains('offline') 
                    ? AppTheme.warningColor 
                    : AppTheme.errorColor,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      };

      nfcService.onProgress = (message) {
        if (mounted) {
          setState(() {
            _statusText = message;
          });
        }
      };

      // Start a continuous background session that listens for tags
      _sessionActive = true;
      if (mounted) {
        setState(() {
          _statusText = 'Ready - Tap your card';
        });
      }
      
      print('📱 About to start background NFC session...');
      
      // Start background session that checks registration and shows info
      nfcService.startBackgroundSession(
        onCardDetected: (cardId) async {
          if (mounted && !_isProcessing) {
            print('📱 Card detected in background: $cardId');
            setState(() {
              _isProcessing = true;
              _statusText = 'Checking card...';
              _detectedNFCId = cardId;
            });
            
            // First, check if card is registered
            final apiService = ApiService();
            RegisteredCard? registeredCard;
            try {
              print('🔍 Checking card registration for: "$cardId"');
              registeredCard = await apiService.checkCardRegistration(cardId);
              print('🔍 Card registration check result: ${registeredCard != null ? "Found" : "Not found"}');
            } catch (e) {
              print('❌ Error checking card registration: $e');
            }
            
            if (mounted) {
              setState(() {
                _isProcessing = false;
              });
              
              if (registeredCard != null) {
                // Card is registered - show user info with name and balance
                final cardToShow = RegisteredCard(
                  cardId: registeredCard.cardId.isNotEmpty ? registeredCard.cardId : cardId,
                  passengerName: registeredCard.passengerName,
                  balance: registeredCard.balance,
                  status: registeredCard.status,
                  registeredAt: registeredCard.registeredAt,
                  lastUsed: registeredCard.lastUsed,
                );
                
                _showCardInfoBottomSheet(cardToShow);
                final passengerName = registeredCard.passengerName;
                setState(() {
                  _statusText = passengerName != null 
                      ? 'Card registered - $passengerName' 
                      : 'Card registered';
                });
              } else {
                // Card is not registered
                _showCardNotRegisteredDialog(cardId);
                setState(() {
                  _statusText = 'Card not registered';
                });
              }
            }
          }
        },
        onError: (error) {
          if (mounted && !error.contains('No card')) {
            print('⚠️ Background session error: $error');
            setState(() {
              _statusText = 'Ready - Tap your card';
            });
          }
        },
      );
      
      print('✅ NFC session ready - waiting for card tap');
    } catch (e) {
      print('⚠️ Error starting NFC session: $e');
      if (mounted) {
        setState(() {
          _statusText = 'Error starting NFC';
        });
      }
    }
  }

  @override
  void dispose() {
    // Stop any active NFC sessions when screen is disposed
    _sessionActive = false;
    try {
      final nfcService = ref.read(nfcServiceProvider);
      // Stop background session
      nfcService.stopBackgroundSession();
      // Also stop regular session
      nfcService.stopSession();
      // Clear callbacks
      nfcService.onSuccess = null;
      nfcService.onError = null;
      nfcService.onProgress = null;
    } catch (e) {
      print('⚠️ Error stopping NFC session: $e');
    }
    super.dispose();
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
      
      // Ensure callbacks are set (they should already be set in _startNFCSession)
      nfcService.onSuccess = (response) {
        if (mounted) {
          HapticFeedback.mediumImpact();
          setState(() {
            _statusText = widget.isTapIn ? 'Tap-In Successful' : 'Tap-Out Successful';
            _isScanning = false;
            _isProcessing = false;
          });
          _showResultBottomSheet(response);
        }
      };

      nfcService.onError = (error) {
        if (mounted) {
          String displayError = error;
          String statusText = 'Error';
          
          if (error.contains('Saved offline')) {
            statusText = 'Saved offline';
            final parts = error.split('Saved offline: ');
            if (parts.length > 1) {
              displayError = parts[1];
            }
          } else if (error.contains('No NFC') || error.contains('No card')) {
            statusText = 'No card detected';
          } else {
            statusText = 'Error';
          }
          
          setState(() {
            _isScanning = false;
            _isProcessing = false;
            _statusText = statusText;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(displayError),
              backgroundColor: error.contains('offline') 
                  ? AppTheme.warningColor 
                  : AppTheme.errorColor,
              duration: const Duration(seconds: 4),
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

      // Read tag - this will start a new session if needed
      // The session should already be active from _startNFCSession
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
  /// Check if card is registered and show user info
  Future<void> _checkCardRegistration() async {
    if (_isScanning || _isProcessing) return;

    setState(() {
      _isScanning = true;
      _statusText = 'Reading card...';
      _detectedNFCId = null;
    });

    try {
      final nfcService = ref.read(nfcServiceProvider);
      
      // Read NFC tag
      print('🔍 Starting NFC card read for registration check...');
      final cardId = await nfcService.readNFCTag();
      
      if (cardId == null || cardId.isEmpty) {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _statusText = 'No card detected';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No NFC card detected. Please ensure the card is properly formatted with an NDEF text record containing "RC-XXXXXXXX".'),
              backgroundColor: AppTheme.errorColor,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      print('✅ Card ID read: "$cardId"');
      setState(() {
        _detectedNFCId = cardId;
        _statusText = 'Checking registration...';
      });

      // Check card registration
      print('🔍 Checking card registration for: "$cardId"');
      final apiService = ApiService();
      RegisteredCard? registeredCard;
      try {
        registeredCard = await apiService.checkCardRegistration(cardId);
        print('🔍 Card registration check result: ${registeredCard != null ? "Found" : "Not found"}');
      } catch (e) {
        print('❌ Error checking card registration: $e');
        if (mounted) {
          setState(() {
            _isScanning = false;
            _statusText = 'Error checking card';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error checking card registration: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isScanning = false;
        });

        if (registeredCard != null) {
          // Ensure card ID is set (use scanned cardId if API didn't return it)
          final cardToShow = RegisteredCard(
            cardId: registeredCard.cardId.isNotEmpty ? registeredCard.cardId : cardId,
            passengerName: registeredCard.passengerName,
            balance: registeredCard.balance,
            status: registeredCard.status,
            registeredAt: registeredCard.registeredAt,
            lastUsed: registeredCard.lastUsed,
          );
          
          // Card is registered - show user info
          _showCardInfoBottomSheet(cardToShow);
          setState(() {
            _statusText = 'Card registered';
          });
        } else {
          // Card is not registered
          _showCardNotRegisteredDialog(cardId);
          setState(() {
            _statusText = 'Card not registered';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusText = 'Error: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking card: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showCardInfoBottomSheet(RegisteredCard card) {
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
                const Text(
                  'Card Information',
                  style: TextStyle(
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
                  _buildInfoRow('Card ID', card.cardId),
                  if (card.passengerName != null) ...[
                    const SizedBox(height: AppTheme.spacingSM),
                    _buildInfoRow('Passenger Name', card.passengerName!),
                  ],
                  if (card.balance != null) ...[
                    const SizedBox(height: AppTheme.spacingSM),
                    _buildInfoRow('Balance', '৳${card.balance!.toStringAsFixed(2)}'),
                  ],
                  if (card.status != null) ...[
                    const SizedBox(height: AppTheme.spacingSM),
                    _buildInfoRow('Status', card.status!),
                  ],
                  if (card.registeredAt != null) ...[
                    const SizedBox(height: AppTheme.spacingSM),
                    _buildInfoRow(
                      'Registered',
                      '${card.registeredAt!.day}/${card.registeredAt!.month}/${card.registeredAt!.year}',
                    ),
                  ],
                  if (card.lastUsed != null) ...[
                    const SizedBox(height: AppTheme.spacingSM),
                    _buildInfoRow(
                      'Last Used',
                      '${card.lastUsed!.day}/${card.lastUsed!.month}/${card.lastUsed!.year}',
                    ),
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

  void _showCardNotRegisteredDialog(String cardId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text(
          'Card Not Registered',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This card is not registered in the system.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              'Card ID: $cardId',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppTheme.primaryGreen)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
          _statusText = widget.isTapIn ? 'Tap-In Successful' : 'Tap-Out Successful';
          _isProcessing = false;
        });
        _showResultBottomSheet(response);
      } catch (e) {
        // Save offline - with better error handling
        try {
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
        } catch (dbError) {
          // Database error - show error but don't crash
          print('❌ Database error saving offline: $dbError');
          setState(() {
            _statusText = 'Error saving offline';
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Network error: ${e.toString()}\nDatabase error: ${dbError.toString()}'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        print('❌ Simulation error: $e');
        print('Stack trace: $stackTrace');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Simulation error: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
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
                    _buildResultRow('Fare', '৳${response.fare!.toStringAsFixed(2)}'),
                  ],
                  if (response.balance != null) ...[
                    const SizedBox(height: AppTheme.spacingSM),
                    _buildResultRow('Balance', '৳${response.balance!.toStringAsFixed(2)}'),
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
            if (_sessionActive) ...[
              const SizedBox(height: AppTheme.spacingSM),
              const Text(
                'If Android shows "Choose an action",\nselect "CityGo Supervisor"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
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
            // Check Card Button
            PrimaryButton(
              text: 'Check Card Registration',
              icon: Icons.credit_card,
              onPressed: _checkCardRegistration,
              width: 280,
            ),
            const SizedBox(height: AppTheme.spacingMD),
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
