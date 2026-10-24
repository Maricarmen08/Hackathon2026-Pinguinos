import 'package:flutter/material.dart';
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
              Color(0xFF07162E),
              Color(0xFF0F2D5E),
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
                  color: AppTheme.cyan.withValues(alpha: 0.12),
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
                  color: AppTheme.brandBlue.withValues(alpha: 0.22),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                child: Row(
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
                                    color:
                                        Colors.white.withValues(alpha: 0.22)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome_rounded,
                                      color: Color(0xFF38BDF8), size: 16),
                                  SizedBox(width: 8),
                                  Text(
                                    'HACKATHON 2026 · EQUIPO PINGÜINOS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),
                            Row(
                              children: [
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF185FC9),
                                        Color(0xFF09AFDC)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF09AFDC)
                                            .withValues(alpha: 0.35),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                      Icons.insights_rounded,
                                      color: Colors.white,
                                      size: 30),
                                ),
                                const SizedBox(width: 16),
                                const Text(
                                  'FINKI',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Las finanzas de tu negocio,\nclaras y al día.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Copiloto financiero móvil para emprendedores y MYPES. Registra ventas, compras, gastos, cobros y pagos en segundos, evalúa la salud de tu negocio y registra evidencias con IA.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 15.5,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 26),
                            const Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _FeatureCard(
                                  icon: Icons.point_of_sale_rounded,
                                  title: 'Caja y Operaciones',
                                  subtitle:
                                      'Ventas, gastos, cobros y transferencias al instante.',
                                ),
                                _FeatureCard(
                                  icon: Icons.people_alt_rounded,
                                  title: 'Por Cobrar y Pagar',
                                  subtitle:
                                      'Control de saldos pendientes con clientes y proveedores.',
                                ),
                                _FeatureCard(
                                  icon: Icons.psychology_rounded,
                                  title: 'Copiloto con IA',
                                  subtitle:
                                      'Consultas inteligentes, captura por voz y evidencias.',
                                ),
                                _FeatureCard(
                                  icon: Icons.verified_rounded,
                                  title: 'Salud y Constancias',
                                  subtitle:
                                      'Indicadores clave y reportes verificables del negocio.',
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            Wrap(
                              spacing: 14,
                              runSpacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF09AFDC),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 14),
                                  ),
                                  onPressed: () =>
                                      setState(() => _phoneFrame = false),
                                  icon: const Icon(Icons.fullscreen_rounded,
                                      size: 20),
                                  label: const Text('Expandir pantalla completa'),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.16)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.touch_app_rounded,
                                          color: Color(0xFF4ADE80), size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Interactúa en vivo con el teléfono a la derecha 👉',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 36),
                    Expanded(
                      flex: 9,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _PhoneMockup(
                            child: MediaQuery(
                              data: mq.copyWith(
                                size: const Size(390, 780),
                                padding:
                                    const EdgeInsets.only(top: 8, bottom: 8),
                                viewPadding:
                                    const EdgeInsets.only(top: 8, bottom: 8),
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
      width: 240,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF38BDF8), size: 22),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 12.5,
              height: 1.35,
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
