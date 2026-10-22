import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/transaction_model.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel item;

  const TransactionTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.pureWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: item.isIncome
              ? AppTheme.softGreen
              : AppTheme.softRed.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 23,
          backgroundColor:
              item.isIncome ? AppTheme.softGreen : AppTheme.softRed,
          child: Icon(
            item.isIncome
                ? Icons.shopping_bag_outlined
                : Icons.receipt_long_outlined,
            color: item.isIncome ? AppTheme.darkGreen : AppTheme.expenseRed,
          ),
        ),
        title: Text(
          item.title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppTheme.textDark,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.mintBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.source == 'voz'
                          ? Icons.mic_rounded
                          : Icons.camera_alt_rounded,
                      size: 13,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.source == 'voz' ? 'Voz IA' : 'Boleta IA',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${item.category} • ${item.timeLabel}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: Text(
          '${item.isIncome ? '+' : '-'} S/ ${item.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: item.isIncome ? AppTheme.darkGreen : AppTheme.expenseRed,
          ),
        ),
      ),
    );
  }
}

