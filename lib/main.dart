import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'v1/api_client.dart';
import 'v1/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PinguinosAiApp(api: ApiClient()));
}

class PinguinosAiApp extends StatelessWidget {
  final ApiClient api;
  const PinguinosAiApp({super.key, required this.api});
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'FINKI',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es', 'PE'),
      supportedLocales: const [Locale('es', 'PE')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      theme: AppTheme.lightTheme,
      builder: (context, child) =>
          _FinkiDesktopShowcase(child: child ?? const SizedBox.shrink()),
      home: SessionGate(api: api));
}

class _FinkiDesktopShowcase extends StatefulWidget {
  final Widget child;
  const _FinkiDesktopShowcase({required this.child});
  @override
  State<_FinkiDesktopShowcase> createState() => _FinkiDesktopShowcaseState();
}

class _FinkiDesktopShowcaseState extends State<_FinkiDesktopShowcase> {
  bool _phoneFrame = true;
  bool _showMobileModal = false;
  bool _copied = false;

  static const String _publicUrl =
      'https://hackathon2026-pinguinos.onrender.com';

  Future<void> _copyLink() async {
    await Clipboard.setData(const ClipboardData(text: _publicUrl));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= 900) return widget.child;
    if (!_phoneFrame) {
      return Stack(
        children: [
          widget.child,
          Positioned(
            bottom: 16,
            left: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() => _phoneFrame = true),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.navy.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 12,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_iphone_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Volver a vista teléfono',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Material(
      color: const Color(0xFF0A1D3B),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF06152D),
              Color(0xFF0D2B59),
              Color(0xFF154B99),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -80,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.cyan.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              right: -60,
              child: Container(
                width: 440,
                height: 440,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.brandBlue.withValues(alpha: 0.20),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 64, vertical: 32),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 11,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.22)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded,
                                          color: Color(0xFF38BDF8), size: 16),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'DESAFÍO 4 · EQUIPO LOS PINGÜINOS DE MADAGASCAR',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.7,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Container(
                                      width: 58,
                                      height: 58,
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF09AFDC)
                                                .withValues(alpha: 0.35),
                                            blurRadius: 18,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Image.asset(
                                        'assets/branding/finki_logo_display.png',
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.insights_rounded,
                                                color: AppTheme.brandBlue,
                                                size: 32),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Text(
                                      'FINKI',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 44,
                                        height: 1.0,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1.0,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Asistente de IA por voz e imagen para pequeños negocios.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Digitaliza ingresos y gastos de pequeños negocios informales para ordenar sus finanzas y facilitar su acceso al crédito.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _FeatureCard(
                                        icon: Icons.mic_none_rounded,
                                        title: 'IA por Voz e Imagen',
                                        subtitle:
                                            'Registra ventas y gastos con audio o foto.',
                                      ),
                                    ),
                                    SizedBox(width: 14),
                                    Expanded(
                                      child: _FeatureCard(
                                        icon: Icons
                                            .account_balance_wallet_outlined,
                                        title: 'Finanzas Ordenadas',
                                        subtitle:
                                            'Controla caja diaria, cobros y pagos.',
                                      ),
                                    ),
                                    SizedBox(width: 14),
                                    Expanded(
                                      child: _FeatureCard(
                                        icon: Icons.verified_user_outlined,
                                        title: 'Acceso al Crédito',
                                        subtitle:
                                            'Constancias e indicadores de tu negocio.',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 30),
                                Center(
                                  child: Column(
                                    children: [
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 14,
                                        runSpacing: 10,
                                        children: [
                                          FilledButton.icon(
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF09AFDC),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 14),
                                            ),
                                            onPressed: () => setState(
                                                () => _phoneFrame = false),
                                            icon: const Icon(
                                                Icons.fullscreen_rounded,
                                                size: 20),
                                            label: const Text(
                                                'Expandir pantalla completa'),
                                          ),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              side: BorderSide(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.35)),
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: 0.08),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 14),
                                            ),
                                            onPressed: () => setState(
                                                () => _showMobileModal = true),
                                            icon: const Icon(
                                                Icons.qr_code_2_rounded,
                                                color: Color(0xFF38BDF8),
                                                size: 20),
                                            label:
                                                const Text('Abrir en celular'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.touch_app_rounded,
                                              color: Color(0xFF4ADE80),
                                              size: 17),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Interactúa en vivo con el teléfono a la derecha',
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.85),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 64),
                        Expanded(
                          flex: 8,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _PhoneMockup(
                                child: MediaQuery(
                                  data: mq.copyWith(
                                    size: const Size(390, 780),
                                    padding: const EdgeInsets.only(
                                        top: 8, bottom: 8),
                                    viewPadding: const EdgeInsets.only(
                                        top: 8, bottom: 8),
                                  ),
                                  child: SizedBox(
                                    width: 390,
                                    height: 780,
                                    child: widget.child,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_showMobileModal)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _showMobileModal = false),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.65),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: 420,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 32,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.smartphone_rounded,
                                        color: AppTheme.brandBlue, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      'Probar FINKI en tu celular',
                                      style: TextStyle(
                                        color: AppTheme.navy,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => _showMobileModal = false),
                                  icon: const Icon(Icons.close_rounded,
                                      color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Escanea el código QR con la cámara de tu teléfono o copia el enlace directo para abrir la aplicación en pantalla móvil completa.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.canvas,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppTheme.borderBlue),
                              ),
                              child: Image.network(
                                'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=https://hackathon2026-pinguinos.onrender.com',
                                width: 190,
                                height: 190,
                                errorBuilder: (_, __, ___) => const SizedBox(
                                  width: 190,
                                  height: 190,
                                  child: Center(
                                    child: Icon(Icons.qr_code_2_rounded,
                                        size: 96, color: AppTheme.brandBlue),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.canvas,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderBlue),
                              ),
                              child: const SelectableText(
                                _publicUrl,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.navy,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _copyLink,
                                icon: Icon(
                                    _copied
                                        ? Icons.check_rounded
                                        : Icons.copy_rounded,
                                    size: 18),
                                label: Text(_copied
                                    ? 'Enlace copiado al portapapeles'
                                    : 'Copiar enlace para celular'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF38BDF8), size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneMockup extends StatelessWidget {
  final Widget child;
  const _PhoneMockup({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1320),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFF334155), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: const Color(0xFF09AFDC).withValues(alpha: 0.2),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(38),
        child: Container(
          color: AppTheme.canvas,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 390,
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                color: AppTheme.pureWhite,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '9:41',
                      style: TextStyle(
                        color: AppTheme.navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Container(
                      width: 86,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1320),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.signal_cellular_alt_rounded,
                            size: 14, color: AppTheme.navy),
                        SizedBox(width: 4),
                        Icon(Icons.wifi_rounded,
                            size: 14, color: AppTheme.navy),
                        SizedBox(width: 4),
                        Icon(Icons.battery_full_rounded,
                            size: 15, color: AppTheme.navy),
                      ],
                    ),
                  ],
                ),
              ),
              child,
              Container(
                width: 390,
                height: 18,
                color: AppTheme.pureWhite,
                alignment: Alignment.center,
                child: Container(
                  width: 110,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppTheme.navy.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
