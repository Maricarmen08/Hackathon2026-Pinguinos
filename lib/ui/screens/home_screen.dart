import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/transaction_model.dart';
import '../widgets/balance_summary_card.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/voice_camera_dock.dart';
import '../widgets/ai_confirmation_sheet.dart';

class HomeScreen extends StatefulWidget {
  final List<TransactionModel> transactions;
  final Function(TransactionModel) onAddTransaction;

  const HomeScreen({
    super.key,
    required this.transactions,
    required this.onAddTransaction,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isListening = false;

  double get _totalIncome => widget.transactions
      .where((t) => t.isIncome)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get _totalExpense => widget.transactions
      .where((t) => !t.isIncome)
      .fold(0.0, (sum, t) => sum + t.amount);

  void _openAssistantSheet({required bool isVoice}) {
    if (isVoice) {
      setState(() => _isListening = true);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiConfirmationSheet(
        isVoice: isVoice,
        onConfirm: widget.onAddTransaction,
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() => _isListening = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BalanceSummaryCard(
              totalIncome: _totalIncome,
              totalExpense: _totalExpense,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Text(
                'Movimientos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: widget.transactions.length,
                itemBuilder: (context, index) {
                  return TransactionTile(item: widget.transactions[index]);
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: VoiceCameraDock(
            isListening: _isListening,
            onVoiceTap: () => _openAssistantSheet(isVoice: true),
            onCameraTap: () => _openAssistantSheet(isVoice: false),
          ),
        ),
      ],
    );
  }
}
