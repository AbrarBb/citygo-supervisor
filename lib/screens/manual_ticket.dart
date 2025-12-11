import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../services/api_service.dart';
import '../services/local_db.dart';
import '../models/ticket.dart';

/// Manual Ticket Screen - Form for issuing manual tickets
class ManualTicketScreen extends StatefulWidget {
  final String busId;

  const ManualTicketScreen({
    super.key,
    required this.busId,
  });

  @override
  State<ManualTicketScreen> createState() => _ManualTicketScreenState();
}

class _ManualTicketScreenState extends State<ManualTicketScreen> {
  final ApiService _apiService = ApiService();
  final LocalDB _localDB = LocalDB();
  final _formKey = GlobalKey<FormState>();
  
  int _passengerCount = 1;
  double _farePerPassenger = 2.50;
  String _notes = '';
  bool _isSubmitting = false;

  double get _totalFare => _passengerCount * _farePerPassenger;

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Issue ticket
      final ticket = ManualTicket(
        busId: widget.busId,
        passengerCount: _passengerCount,
        fare: _totalFare,
        latitude: position.latitude,
        longitude: position.longitude,
        notes: _notes.isEmpty ? null : _notes,
        timestamp: DateTime.now(),
      );
      
      print('🎫 Issuing manual ticket...');
      print('📦 Ticket data: busId=${ticket.busId}, passengers=${ticket.passengerCount}, fare=${ticket.fare}');
      
      final result = await _apiService.issueManualTicket(ticket);

      print('✅ Ticket issued successfully: ${result.ticketId}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Ticket issued successfully!'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context, result);
      }
    } catch (e) {
      print('❌ Error issuing ticket: $e');
      
      // Extract error message
      String errorMessage = 'Failed to issue ticket';
      if (e is Exception) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      } else {
        errorMessage = e.toString();
      }
      
      // Save to offline storage on error
      try {
        print('💾 Attempting to save ticket offline...');
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final ticket = ManualTicket(
          busId: widget.busId,
          passengerCount: _passengerCount,
          fare: _totalFare,
          latitude: position.latitude,
          longitude: position.longitude,
          notes: _notes.isEmpty ? null : _notes,
          timestamp: DateTime.now(),
        );
        
        await _localDB.saveManualTicket(ticket);
        print('✅ Ticket saved offline successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved offline. Will sync when connection is available.\nError: $errorMessage'),
              backgroundColor: AppTheme.warningColor,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pop(context);
        }
      } catch (locationError) {
        print('❌ Failed to save offline: $locationError');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMessage'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: TopBar(
        title: 'Manual Ticket',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Passenger Counter
              PassengerCounter(
                value: _passengerCount,
                onChanged: (value) {
                  setState(() => _passengerCount = value);
                },
                label: 'Number of Passengers',
              ),

              // Fare per Passenger Input
              CityGoCard(
                margin: const EdgeInsets.all(AppTheme.spacingMD),
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fare per Passenger',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    TextFormField(
                      initialValue: _farePerPassenger.toStringAsFixed(2),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                      decoration: InputDecoration(
                        prefixText: '৳ ',
                        prefixStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      onChanged: (value) {
                        final fare = double.tryParse(value);
                        if (fare != null && fare > 0) {
                          setState(() => _farePerPassenger = fare);
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter fare';
                        }
                        final fare = double.tryParse(value);
                        if (fare == null || fare <= 0) {
                          return 'Please enter a valid fare';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              // Total Fare Preview Card
              CityGoCard(
                margin: const EdgeInsets.all(AppTheme.spacingMD),
                padding: const EdgeInsets.all(AppTheme.spacingLG),
                backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Total Fare',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '৳${_totalFare.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),

              // Notes Input
              CityGoCard(
                margin: const EdgeInsets.all(AppTheme.spacingMD),
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notes (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    TextFormField(
                      maxLines: 3,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Add any additional notes...',
                        hintStyle: TextStyle(color: AppTheme.textTertiary),
                      ),
                      onChanged: (value) {
                        setState(() => _notes = value);
                      },
                    ),
                  ],
                ),
              ),

              // Issue Ticket Button
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: PrimaryButton(
                  text: 'Issue Ticket',
                  icon: Icons.check_circle,
                  onPressed: _isSubmitting ? null : _submitTicket,
                  isLoading: _isSubmitting,
                  width: double.infinity,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

