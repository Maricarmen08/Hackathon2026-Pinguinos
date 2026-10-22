import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/business_model.dart';

class CreditScoreScreen extends StatelessWidget {
  final BusinessModel business;
  final int transactionCount;

  const CreditScoreScreen({
    super.key,
    required this.business,
    required this.transactionCount,
  });

  @override
  Widget build(BuildContext context) {
    final calculatedScore =
        (business.scoreCrediticio + (transactionCount * 2)).clamp(0, 100);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.softGreen, width: 1.5),
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.softGreen,
                child: Icon(
                  Icons.verified_user_rounded,
                  size: 32,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Índice de Confianza Crediticia',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$calculatedScore / 100 Puntos',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: calculatedScore / 100,
                  minHeight: 14,
                  backgroundColor: AppTheme.mintBackground,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Cada venta por voz y foto de boleta registrada construye tu historial formal para acceder a capital de trabajo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppTheme.darkGreen,
                        content: Text(
                          'Reporte Financiero Certificado generado y listo para compartir.',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text(
                    'DESCARGAR CARPETA PARA CRÉDITO',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppTheme.softGreen,
                    child: Icon(
                      Icons.group_add_rounded,
                      color: AppTheme.darkGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Invita a otros comerciantes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'Código: ${business.codigoReferido} • ${business.puntosDifusion} pts acumulados',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.darkGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.darkGreen,
                      content: Text(
                        'Código ${business.codigoReferido} copiado para compartir con otros negocios.',
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.darkGreen,
                  side: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.share_rounded),
                label: const Text(
                  'COMPARTIR MI CÓDIGO DE REFERIDO',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

