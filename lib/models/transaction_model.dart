class TransactionModel {
  final int? id;
  final int negocioId;
  final String title;
  final String category;
  final double amount;
  final bool isIncome;
  final String source;
  final String originalPrompt;
  final String timeLabel;

  TransactionModel({
    this.id,
    this.negocioId = 1,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    required this.source,
    required this.originalPrompt,
    required this.timeLabel,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    final tipo = (json['tipo'] ?? 'INGRESO').toString().toUpperCase();
    final origen = (json['origen_ia'] ?? 'VOZ').toString().toUpperCase();
    return TransactionModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}'),
      negocioId: json['negocio_id'] is int
          ? json['negocio_id']
          : int.tryParse('${json['negocio_id']}') ?? 1,
      title: (json['concepto'] ?? '').toString(),
      category: (json['categoria'] ?? 'General').toString(),
      amount: double.tryParse('${json['monto']}') ?? 0.0,
      isIncome: tipo == 'INGRESO',
      source: origen == 'FOTO_BOLETA' ? 'foto' : 'voz',
      originalPrompt: (json['prompt_original'] ?? '').toString(),
      timeLabel: (json['fecha_transaccion'] ?? 'Hoy').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'negocio_id': negocioId,
      'tipo': isIncome ? 'INGRESO' : 'GASTO',
      'concepto': title,
      'categoria': category,
      'monto': amount,
      'origen_ia': source == 'foto' ? 'FOTO_BOLETA' : 'VOZ',
      'prompt_original': originalPrompt,
    };
  }
}

