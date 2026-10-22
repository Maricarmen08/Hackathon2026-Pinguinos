import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/transaction_model.dart';
import '../../services/ai_parser_service.dart';

class AiConfirmationSheet extends StatefulWidget {
  final bool isVoice;
  final Function(TransactionModel) onConfirm;

  const AiConfirmationSheet({
    super.key,
    required this.isVoice,
    required this.onConfirm,
  });

  @override
  State<AiConfirmationSheet> createState() => _AiConfirmationSheetState();
}

class _AiConfirmationSheetState extends State<AiConfirmationSheet> {
  late TextEditingController _inputController;
  late TransactionModel _previewItem;

  final List<String> _voiceExamples = [
    'Vendí 2 botellas de aceite a 24 soles',
    'Vendí 3 kilos de arroz y azúcar por 19 soles',
    'Pagué 45 soles al proveedor de verduras',
  ];

  final List<String> _receiptExamples = [
    'BOLETA MAYORISTA: Sacos de papa y cebolla - S/ 48.00',
    'DISTRIBUIDORA LÁCTEOS: Cajas de leche - S/ 72.00',
  ];

  @override
  void initState() {
    super.initState();
    final initialText = widget.isVoice
        ? _voiceExamples.first
        : _receiptExamples.first;
    _inputController = TextEditingController(text: initialText);
    _recalculate(initialText);
  }

  void _recalculate(String text) {
    setState(() {
      _previewItem = widget.isVoice
          ? AiParserService.parseVoiceInput(text)
          : AiParserService.parseReceiptImage(text);
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final examples = widget.isVoice ? _voiceExamples : _receiptExamples;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppTheme.softGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.softGreen,
                  child: Icon(
                    widget.isVoice
                        ? Icons.graphic_eq_rounded
                        : Icons.document_scanner_rounded,
                    color: AppTheme.darkGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.isVoice
                        ? 'Asistente IA por Voz'
                        : 'Escáner IA de Boletas',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _inputController,
              onChanged: _recalculate,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.mintBackground,
                labelText: widget.isVoice
                    ? 'Frase escuchada por el micrófono'
                    : 'Texto detectado en la foto de la boleta',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.softGreen),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppTheme.softGreen),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: examples.map((sample) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: AppTheme.mintBackground,
                      side: const BorderSide(color: AppTheme.softGreen),
                      label: Text(
                        sample,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textDark,
                        ),
                      ),
                      onPressed: () {
                        _inputController.text = sample;
                        _recalculate(sample);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _previewItem.isIncome
                    ? AppTheme.mintBackground
                    : AppTheme.softRed.withOpacity(0.45),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _previewItem.isIncome
                      ? AppTheme.primaryGreen
                      : AppTheme.expenseRed,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _previewItem.isIncome
                              ? 'VENTA DETECTADA POR IA'
                              : 'GASTO DETECTADO POR IA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _previewItem.isIncome
                                ? AppTheme.darkGreen
                                : AppTheme.expenseRed,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _previewItem.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'Categoría: ${_previewItem.category}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_previewItem.isIncome ? '+' : '-'} S/ ${_previewItem.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: _previewItem.isIncome
                          ? AppTheme.darkGreen
                          : AppTheme.expenseRed,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onConfirm(_previewItem);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text(
                  'GUARDAR EN MI CAJA',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

