import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/business_model.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final BusinessModel business;

  const ProfileScreen({super.key, required this.business});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _continuousVoice = true;
  bool _autoScanReceipt = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.softGreen, width: 1.4),
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: AppTheme.softGreen,
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 34,
                  color: AppTheme.darkGreen,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.business.nombreNegocio,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Titular: ${widget.business.propietario} • ${widget.business.rubro}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.softGreen, width: 1.4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configuración del Asistente IA',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppTheme.primaryGreen,
                title: const Text(
                  'Reconocimiento continuo de voz',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                value: _continuousVoice,
                onChanged: (val) => setState(() => _continuousVoice = val),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: AppTheme.primaryGreen,
                title: const Text(
                  'Escaneo inteligente de boletas',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                value: _autoScanReceipt,
                onChanged: (val) => setState(() => _autoScanReceipt = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.expenseRed,
            side: const BorderSide(color: AppTheme.expenseRed, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.logout_rounded),
          label: const Text(
            'CERRAR SESIÓN',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

