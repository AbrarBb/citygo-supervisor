import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../services/api_service.dart';
import '../models/report.dart';

/// Reports Screen - Daily reports and statistics
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _selectedDate = DateTime.now();

  Future<ReportResponse> _loadReports(DateTime date) async {
    final apiService = ApiService();
    return await apiService.getReport(date: date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: TopBar(
        title: 'Daily Reports',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<ReportResponse>(
        future: _loadReports(_selectedDate),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: AppTheme.spacingMD),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          final report = snapshot.data!;
          
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Date Picker
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    child: CityGoCard(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.spacingMD),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Icon(Icons.calendar_today, color: AppTheme.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Summary Cards Row
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    child: Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'CO₂ Saved',
                            value: '${report.co2Saved.toStringAsFixed(2)} kg',
                            icon: Icons.eco,
                            iconColor: AppTheme.primaryGreen,
                            valueColor: AppTheme.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMD),
                        Expanded(
                          child: StatCard(
                            label: 'Distance',
                            value: '${report.totalDistance.toStringAsFixed(1)} km',
                            icon: Icons.route,
                            iconColor: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Fare Card
                  CityGoCard(
                    margin: const EdgeInsets.all(AppTheme.spacingMD),
                    padding: const EdgeInsets.all(AppTheme.spacingLG),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacingMD),
                              decoration: BoxDecoration(
                                color: AppTheme.accentCyanReal.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                              ),
                              child: const Icon(
                                Icons.attach_money,
                                color: AppTheme.accentCyanReal,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingMD),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Fare',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppTheme.spacingXS),
                                Text(
                                  '৳${report.totalFare.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Hourly Chart Card (Placeholder)
                  CityGoCard(
                    margin: const EdgeInsets.all(AppTheme.spacingMD),
                    padding: const EdgeInsets.all(AppTheme.spacingLG),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hourly Activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingLG),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceDark,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.bar_chart,
                                  size: 48,
                                  color: AppTheme.textTertiary,
                                ),
                                const SizedBox(height: AppTheme.spacingMD),
                                Text(
                                  'Chart placeholder',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Additional Stats
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    child: Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Trips',
                            value: report.tripCount.toString(),
                            icon: Icons.directions_bus,
                            iconColor: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMD),
                        Expanded(
                          child: StatCard(
                            label: 'Passengers',
                            value: report.passengerCount.toString(),
                            icon: Icons.people,
                            iconColor: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
