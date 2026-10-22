class BusinessModel {
  final int id;
  final String nombreNegocio;
  final String propietario;
  final String rubro;
  final String codigoReferido;
  final int puntosDifusion;
  final int scoreCrediticio;

  BusinessModel({
    required this.id,
    required this.nombreNegocio,
    required this.propietario,
    required this.rubro,
    required this.codigoReferido,
    required this.puntosDifusion,
    required this.scoreCrediticio,
  });

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: int.tryParse('${json['id']}') ?? 1,
      nombreNegocio: (json['nombre_negocio'] ?? 'Bodega Doña Rosa').toString(),
      propietario: (json['propietario'] ?? 'Rosa Quispe').toString(),
      rubro: (json['rubro'] ?? 'Bodega y Abarrotes').toString(),
      codigoReferido: (json['codigo_referido'] ?? 'ROSA2026').toString(),
      puntosDifusion: int.tryParse('${json['puntos_difusion']}') ?? 30,
      scoreCrediticio: int.tryParse('${json['score_crediticio']}') ?? 78,
    );
  }
}

