import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../services/api_service.dart';
import '../models/card.dart';

/// Provider for registered cards
final registeredCardsProvider = FutureProvider<List<RegisteredCard>>((ref) async {
  final apiService = ApiService();
  return await apiService.getRegisteredCards();
});

/// Registered Cards Screen - Display all registered NFC cards
class RegisteredCardsScreen extends ConsumerWidget {
  const RegisteredCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(registeredCardsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Registered Cards'),
        backgroundColor: AppTheme.surfaceDark,
        foregroundColor: AppTheme.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(registeredCardsProvider);
            },
          ),
        ],
      ),
      body: cardsAsync.when(
        data: (cards) {
          if (cards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.credit_card_off,
                    size: 64,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  Text(
                    'No Cards Found',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    'No registered cards found.\nCards will appear here once issued by admin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLG),
                  PrimaryButton(
                    text: 'Refresh',
                    icon: Icons.refresh,
                    onPressed: () {
                      ref.invalidate(registeredCardsProvider);
                    },
                    width: 200,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(registeredCardsProvider);
              await ref.read(registeredCardsProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                return _buildCardItem(card);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.errorColor,
                ),
                const SizedBox(height: AppTheme.spacingMD),
                Text(
                  'Error Loading Cards',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                Text(
                  error.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLG),
                PrimaryButton(
                  text: 'Retry',
                  icon: Icons.refresh,
                  onPressed: () {
                    ref.invalidate(registeredCardsProvider);
                  },
                  width: 200,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardItem(RegisteredCard card) {
    return CityGoCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card ID Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.credit_card,
                      color: AppTheme.primaryGreen,
                      size: 24,
                    ),
                    const SizedBox(width: AppTheme.spacingSM),
                    Expanded(
                      child: Text(
                        card.cardId,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSM,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: card.status == 'active'
                      ? AppTheme.primaryGreen.withOpacity(0.2)
                      : AppTheme.textTertiary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Text(
                  card.status?.toUpperCase() ?? 'UNKNOWN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: card.status == 'active'
                        ? AppTheme.primaryGreen
                        : AppTheme.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          
          // Passenger Name
          if (card.passengerName != null) ...[
            Row(
              children: [
                Icon(
                  Icons.person,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  card.passengerName!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSM),
          ],
          
          // Balance
          if (card.balance != null) ...[
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 16,
                  color: AppTheme.accentCyanReal,
                ),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  'Balance: ৳${card.balance!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentCyanReal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSM),
          ],
          
          // Dates
          if (card.registeredAt != null || card.lastUsed != null) ...[
            const Divider(color: AppTheme.surfaceDark),
            if (card.registeredAt != null)
              _buildInfoRow(
                Icons.calendar_today,
                'Registered: ${DateFormat('MMM dd, yyyy').format(card.registeredAt!)}',
              ),
            if (card.lastUsed != null) ...[
              const SizedBox(height: AppTheme.spacingXS),
              _buildInfoRow(
                Icons.access_time,
                'Last Used: ${DateFormat('MMM dd, yyyy HH:mm').format(card.lastUsed!)}',
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: AppTheme.textTertiary,
        ),
        const SizedBox(width: AppTheme.spacingXS),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }
}

