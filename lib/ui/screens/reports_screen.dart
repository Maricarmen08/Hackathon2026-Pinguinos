import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/transaction_model.dart';

class ReportsScreen extends StatelessWidget {
  final List<TransactionModel> transactions;

  const ReportsScreen({super.key, required this.transactions});

  double get _totalIncome => transactions
      .where((t) => t.isIncome)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get _totalExpense => transactions
      .where((t) => !t.isIncome)
      .fold(0.0, (sum, t) => sum + t.amount);

  @override
  Widget build(BuildContext context) {
    final net = _totalIncome - _totalExpense;
    final totalVolume = (_totalIncome + _totalExpense) == 0
        ? 1.0
        : (_totalIncome + _totalExpense);
    final incomeRatio = (_totalIncome / totalVolume).clamp(0.1, 0.9);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.softGreen, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.softGreen,
                    child: Icon(
                      Icons.insights_rounded,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Resumen de Flujo de Caja',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetricColumn(
                    label: 'Ingresos Totales',
                    value: 'S/ ${_totalIncome.toStringAsFixed(2)}',
                    color: AppTheme.darkGreen,
                  ),
                  _buildMetricColumn(
                    label: 'Gastos Totales',
                    value: 'S/ ${_totalExpense.toStringAsFixed(2)}',
                    color: AppTheme.expenseRed,
                  ),
                  _buildMetricColumn(
                    label: 'Margen Neto',
                    value: 'S/ ${net.toStringAsFixed(2)}',
                    color: AppTheme.primaryGreen,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Expanded(
                      flex: (incomeRatio * 100).round(),
                      child: Container(
                        height: 16,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    Expanded(
                      flex: ((1 - incomeRatio) * 100).round(),
                      child: Container(
                        height: 16,
                        color: AppTheme.expenseRed.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lo que entra (Ventas)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  Text(
                    'Lo que sale (Gastos)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.expenseRed,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.softGreen.withOpacity(0.55),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.primaryGreen, width: 1.2),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_rounded, color: AppTheme.darkGreen),
                  SizedBox(width: 8),
                  Text(
                    'Diagnóstico del Asistente IA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                'Tu negocio mantiene un flujo de caja positivo. Tus ventas en Abarrotes y Bebidas superan tus costos de reposición de mercadería, lo que demuestra capacidad de pago semanal.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricColumn({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

