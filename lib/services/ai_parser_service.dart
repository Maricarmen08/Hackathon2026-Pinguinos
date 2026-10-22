import '../models/transaction_model.dart';

class AiParserService {
  static TransactionModel parseVoiceInput(String spokenText) {
    final normalized = spokenText.toLowerCase();
    final isExpense = normalized.contains('pagu') ||
        normalized.contains('compr') ||
        normalized.contains('gast') ||
        normalized.contains('boleta') ||
        normalized.contains('proveedor') ||
        normalized.contains('luz') ||
        normalized.contains('agua');

    final numberRegex = RegExp(r'(\d+(\.\d+)?)');
    final matches = numberRegex.allMatches(normalized).toList();
    double detectedAmount = 24.00;
    if (matches.isNotEmpty) {
      detectedAmount =
          double.tryParse(matches.last.group(0) ?? '24.00') ?? 24.00;
    }

    String category = isExpense ? 'Proveedores' : 'Venta mostrador';
    if (normalized.contains('arroz') ||
        normalized.contains('aceite') ||
        normalized.contains('azucar') ||
        normalized.contains('leche')) {
      category = 'Abarrotes';
    } else if (normalized.contains('gaseosa') ||
        normalized.contains('agua') ||
        normalized.contains('jugo')) {
      category = 'Bebidas';
    } else if (normalized.contains('luz') || normalized.contains('alquiler')) {
      category = 'Servicios';
    }

    String cleanConcept = spokenText.trim();
    if (cleanConcept.length > 36) {
      cleanConcept = '${cleanConcept.substring(0, 36)}...';
    }

    return TransactionModel(
      title: cleanConcept,
      category: category,
      amount: detectedAmount,
      isIncome: !isExpense,
      source: 'voz',
      originalPrompt: spokenText,
      timeLabel: 'Ahora mismo',
    );
  }

  static TransactionModel parseReceiptImage(String receiptSummary) {
    final numberRegex = RegExp(r'(\d+(\.\d+)?)');
    final matches = numberRegex.allMatches(receiptSummary).toList();
    double detectedAmount = 48.00;
    if (matches.isNotEmpty) {
      detectedAmount =
          double.tryParse(matches.last.group(0) ?? '48.00') ?? 48.00;
    }

    return TransactionModel(
      title: 'Boleta Mayorista Abarrotes',
      category: 'Compra mercadería',
      amount: detectedAmount,
      isIncome: false,
      source: 'foto',
      originalPrompt: receiptSummary,
      timeLabel: 'Ahora mismo',
    );
  }
}

