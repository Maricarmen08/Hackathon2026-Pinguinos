import 'dart:async';
import 'package:flutter/material.dart';
import 'daily_sales.dart';
import 'google_access.dart';
import 'api_client.dart';
import 'money.dart';
import 'presentation.dart';
import 'forms.dart';
import 'certificate_page.dart';
import 'intake_page.dart';
import 'intake_widgets.dart' show showIntakePrivacy;
import 'profile_edit_page.dart';
import 'profile_photo_page.dart';
import 'account_security_page.dart';
import 'transfer_page.dart';
import 'insights_page.dart';
import '../core/theme/app_theme.dart';
import '../ui/widgets/finki_brand.dart';
import '../ui/widgets/finki_components.dart';

void showError(BuildContext context, Object error) {
  final message = error is ApiException
      ? '${error.message}${error.status == 409 ? ' Actualiza los datos antes de corregir.' : ''}'
      : error is FormatException
          ? error.message
          : 'No se pudo completar la acción. Intenta nuevamente.';
  ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

class SessionGate extends StatefulWidget {
  final ApiClient api;
  const SessionGate({super.key, required this.api});
  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool loading = true;
  Object? error;
  @override
  void initState() {
    super.initState();
    widget.api.addListener(changed);
    restore();
  }

  void changed() {
    if (mounted) setState(() {});
    if (!widget.api.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  Future<void> restore() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.api.restore();
      if (widget.api.authenticated) await widget.api.request('GET', '/auth/me');
    } catch (e) {
      if (widget.api.authenticated || e is! ApiException || e.status != 401) {
        error = e;
      }
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    widget.api.removeListener(changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: FinkiLoading());
    }
    if (error != null) {
      return Scaffold(
          body: SafeArea(
              child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off, size: 48),
        const Text('No pudimos recuperar tu sesión.'),
        FilledButton(onPressed: restore, child: const Text('Reintentar'))
      ]))));
    }
    return widget.api.authenticated
        ? BusinessHome(api: widget.api)
        : AuthPage(api: widget.api);
  }
}

class AuthPage extends StatefulWidget {
  final ApiClient api;
  const AuthPage({super.key, required this.api});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      user = TextEditingController(),
      password = TextEditingController();
  bool register = false, busy = false, hidden = true, welcome = true;
  String? error;
  @override
  void dispose() {
    name.dispose();
    user.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.authenticate(
          register,
          register
              ? {
                  'nombre': name.text.trim(),
                  'telefono': user.text.trim(),
                  'clave': password.text
                }
              : {'usuario': user.text.trim(), 'clave': password.text});
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException
            ? e.message
            : 'No se pudo conectar. Revisa la dirección del servidor.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _formPanel(bool wide) => Container(
        padding: EdgeInsets.all(wide ? 34 : 24),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.borderBlue),
            boxShadow: const [
              BoxShadow(
                  color: AppTheme.shadow, blurRadius: 40, offset: Offset(0, 14))
            ]),
        child: Form(
            key: form,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(register ? 'TU PRIMER PASO' : 'TU ESPACIO EN FINKI',
                      style: const TextStyle(
                          color: AppTheme.brandBlue,
                          fontSize: 11,
                          letterSpacing: 1.7,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text(register ? 'Tu negocio empieza aquí' : 'Qué bueno verte',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navy,
                              letterSpacing: -.6,
                              height: 1.2)),
                  const SizedBox(height: 10),
                  Text(
                      register
                          ? 'Crea tu cuenta y empieza a organizar tu día a día.'
                          : 'Ingresa a tu cuenta. FINKI te acompaña en cada paso.',
                      style: const TextStyle(
                          color: AppTheme.textMuted, height: 1.5)),
                  const SizedBox(height: 28),
                  if (register) ...[
                    TextFormField(
                        controller: name,
                        decoration: const InputDecoration(
                            labelText: 'Tu nombre',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                            counterText: ''),
                        maxLength: 120,
                        validator: (v) =>
                            v!.trim().isEmpty ? 'Escribe tu nombre' : null),
                    const SizedBox(height: 18),
                  ],
                  TextFormField(
                      controller: user,
                      decoration: InputDecoration(
                          labelText: register
                              ? 'Celular peruano'
                              : 'Teléfono o correo electrónico',
                          prefixIcon:
                              const Icon(Icons.alternate_email_rounded)),
                      keyboardType: register
                          ? TextInputType.phone
                          : TextInputType.emailAddress,
                      validator: (v) => v!.trim().isEmpty
                          ? 'Completa este campo'
                          : register &&
                                  !RegExp(r'^\+?[1-9][0-9]{7,14}$')
                                      .hasMatch(v.trim())
                              ? 'Ingresa un celular válido'
                              : null),
                  const SizedBox(height: 18),
                  TextFormField(
                      controller: password,
                      onChanged: (_) => setState(() {}),
                      obscureText: hidden,
                      decoration: InputDecoration(
                          labelText: 'Contraseña',
                          counterText: '',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          helperText:
                              register ? 'De 12 a 128 caracteres' : null,
                          suffixIcon: IconButton(
                              onPressed: () => setState(() => hidden = !hidden),
                              tooltip: hidden
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              icon: Icon(hidden
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined))),
                      maxLength: 128,
                      validator: (v) => v!.isEmpty
                          ? 'Escribe tu contraseña'
                          : register && v.length < 12
                              ? 'Usa al menos 12 caracteres'
                              : null),
                  if (register) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                        value: password.text.isEmpty
                            ? 0
                            : password.text.length < 12
                                ? .3
                                : password.text.length < 16
                                    ? .65
                                    : 1,
                        backgroundColor: AppTheme.borderBlue,
                        color: password.text.length >= 12
                            ? AppTheme.success
                            : AppTheme.warning,
                        borderRadius: BorderRadius.circular(8)),
                    const SizedBox(height: 8),
                    Text(
                        password.text.length >= 12
                            ? 'Longitud válida. Evita claves que uses en otras apps.'
                            : 'Tu contraseña necesita al menos 12 caracteres.',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 12)),
                  ],
                  if (error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(error!,
                            style:
                                const TextStyle(color: AppTheme.expenseRed))),
                  const SizedBox(height: 24),
                  FilledButton(
                      onPressed: busy ? null : submit,
                      key: const ValueKey('auth-submit'),
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54)),
                      child: Text(busy
                          ? 'Conectando…'
                          : register
                              ? 'Crear mi cuenta'
                              : 'Ingresar')),
                  const SizedBox(height: 10),
                  TextButton(
                      key: const ValueKey('auth-register-toggle'),
                      onPressed: busy
                          ? null
                          : () => setState(() {
                                register = !register;
                                error = null;
                              }),
                      child: Text(register
                          ? 'Ya tengo cuenta'
                          : 'Soy nuevo · Registrarme')),
                  GoogleAccess(api: widget.api),
                ])),
      );

  @override
  Widget build(BuildContext context) => welcome
      ? Scaffold(
          body: SafeArea(
              child: Center(
                  child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                FinkiLogo(
                    height: (MediaQuery.sizeOf(context).height * .27)
                        .clamp(100, 208)),
                const SizedBox(height: 24),
                Text('Tu negocio, más fácil.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                const Text(
                    'Registra tus ventas, gastos y fiados. Consulta tus cuentas en un solo lugar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16, color: AppTheme.textMuted, height: 1.5)),
                const SizedBox(height: 32),
                SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: () => setState(() {
                              welcome = false;
                              register = true;
                            }),
                        child: const Text('Comenzar'))),
                const SizedBox(height: 12),
                SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                        onPressed: () => setState(() {
                              welcome = false;
                              register = false;
                            }),
                        child: const Text('Ya tengo cuenta'))),
                GoogleAccess(api: widget.api),
                const SizedBox(height: 24),
                const Text('FINKI · A tu lado, cada día.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              ])),
        ))))
      : Scaffold(
          appBar: AppBar(
              leading: IconButton(
                  tooltip: 'Volver a bienvenida',
                  onPressed: busy ? null : () => setState(() => welcome = true),
                  icon: const Icon(Icons.arrow_back)),
              title: FinkiBrandHeader(
                  subtitle:
                      register ? 'Crea tu cuenta' : 'Ingresa a tu cuenta')),
          body: SafeArea(
              child: Center(
                  child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _formPanel(false),
                  const SizedBox(height: 20),
                  const Text('FINKI · A tu lado, cada día.',
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ])),
          ))),
        );
}

class BusinessHome extends StatefulWidget {
  final ApiClient api;
  const BusinessHome({super.key, required this.api});
  @override
  State<BusinessHome> createState() => _BusinessHomeState();
}

class _BusinessHomeState extends State<BusinessHome>
    with WidgetsBindingObserver {
  List<Json> businesses = [],
      accounts = [],
      categories = [],
      people = [],
      history = [],
      pending = [];
  Json? business, report, profile;
  DailySales? dailySales;
  bool dailyCached = false;
  Timer? dailyTimer;
  bool googleBusinessPrompted = false;
  bool loading = true;
  Object? error;
  int tab = 0;
  String filter = '', search = '', direction = 'COBRAR';
  int? nextOffset;
  bool more = false;
  String statusFilter = '';
  DateTimeRange? historyPeriod;
  String get path => '/negocios/${business!['id']}';
  ApiClient get api => widget.api;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    dailyTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !loading &&
        ModalRoute.of(context)?.isCurrent == true) {
      load();
    }
  }

  Future<void> load() async {
    dailyTimer?.cancel();
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
        dailySales = null;
      });
    }
    try {
      final me = await api.request('GET', '/auth/me');
      profile = me['usuario'] as Json;
      businesses = (me['negocios'] as List)
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
      business =
          businesses.where((x) => x['id'] == business?['id']).firstOrNull ??
              businesses.firstOrNull;
      if (business != null) {
        if (!api.offline && api.localEntries.isNotEmpty && !api.syncing) {
          try {
            await api.syncLocal();
          } on ApiException catch (e) {
            if (![0, 403, 404, 409, 422, 503].contains(e.status)) rethrow;
          }
        }
        report = await api.request('GET', '$path/indicadores');
        accounts = (report!['cuentas'] as List)
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList();
        await loadDailySales();
        categories = await api.all('$path/categorias');
        people = await api.all('$path/terceros');
        await loadList();
        if (!api.offline) await api.request('GET', '$path/sync/snapshot');
      }
    } catch (e) {
      error = e;
    }
    if (mounted) setState(() => loading = false);
    if (mounted &&
        error == null &&
        business == null &&
        api.session?['metodo_acceso'] == 'GOOGLE' &&
        !googleBusinessPrompted) {
      googleBusinessPrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          openForm('business');
        }
      });
    }
  }

  Future<void> loadDailySales() async {
    dailyTimer?.cancel();
    final id = business?['id'] as String?;
    if (id == null) return;
    DailySales? snapshot;
    var cached = false;
    try {
      final data = await api.request('GET', '/negocios/$id/ventas/hoy');
      cached = api.offline;
      snapshot = DailySales.parse(data, id);
    } catch (_) {
      // Other dashboard sections may still be available. Never substitute the
      // all-history report, an incomplete replica or an invented zero here.
    }
    if (!mounted || business?['id'] != id) return;
    setState(() {
      dailySales = snapshot;
      dailyCached = cached;
    });
    if (snapshot != null && snapshot.isToday(DateTime.now())) {
      dailyTimer = Timer(
          snapshot.end.difference(DateTime.now().toUtc()) +
              const Duration(milliseconds: 50), () {
        if (mounted) {
          setState(() {});
          loadDailySales();
        }
      });
    }
  }

  Future<void> loadList({bool append = false}) async {
    if (business == null) return;
    final params = <String, String>{
      'limit': '30',
      'offset': append ? '$nextOffset' : '0'
    };
    if (search.trim().isNotEmpty) params['q'] = search.trim();
    if (tab == 1) {
      if (statusFilter.isNotEmpty) params['estado'] = statusFilter;
      if (historyPeriod != null) {
        params['desde'] =
            historyPeriod!.start.toIso8601String().substring(0, 10);
        params['hasta'] = historyPeriod!.end.toIso8601String().substring(0, 10);
      }
    }
    if (tab == 2) {
      params['direccion'] = direction;
    } else if (filter.isNotEmpty) {
      params['tipo'] = filter;
    }
    final result = await api.request('GET',
        '$path/${tab == 2 ? 'pendientes' : 'historial'}?${Uri(queryParameters: params).query}');
    final items = (result['items'] as List)
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
    if (tab == 2) {
      pending = append ? [...pending, ...items] : items;
    } else {
      history = append ? [...history, ...items] : items;
    }
    nextOffset = result['next_offset'] as int?;
  }

  Future<void> action(Future<void> Function() work) async {
    try {
      await work();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> openForm(String kind, {Json? row}) async {
    if (business == null && kind != 'business') return;
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => EntryForm(
            api: api,
            kind: kind,
            business: business,
            accounts: accounts,
            categories: categories,
            people: people,
            row: row)));
    if (result == true && mounted) {
      await load();
    } else if (mounted) {
      setState(() {});
    }
  }

  Widget tile(String label, Object? value, IconData icon,
          {bool fillHeight = false}) =>
      FinkiMoneyCard(
          label: label,
          value: soles(value),
          icon: icon,
          fillHeight: fillHeight);
  bool get owner => business?['rol'] == 'PROPIETARIO';
  bool get writer => business?['rol'] != 'LECTOR';
  void selectTab(int value) {
    tab = value;
    search = '';
    filter = '';
    statusFilter = '';
    historyPeriod = null;
    load();
  }

  Widget metricPair(String a, String ak, String b, String bk) =>
      LayoutBuilder(builder: (context, c) {
        final pair = c.maxWidth >= 300;
        final children = [
          tile(a, report?[ak], Icons.receipt_long_outlined, fillHeight: pair),
          tile(b, report?[bk], Icons.account_balance_wallet_outlined,
              fillHeight: pair)
        ];
        return c.maxWidth < 300
            ? Column(children: children)
            : IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    Expanded(child: children[0]),
                    const SizedBox(width: 8),
                    Expanded(child: children[1])
                  ]));
      });
  Widget get overview =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
            firstName(profile?['nombre']).isEmpty
                ? '¡Hola!'
                : '¡Hola, ${firstName(profile?['nombre'])}!',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Así va tu negocio',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(business?['nombre'] ?? '',
            style:
                const TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
        const SizedBox(height: 20),
        Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppTheme.navy, borderRadius: BorderRadius.circular(24)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.storefront_outlined, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Ventas de hoy',
                        style: TextStyle(color: Colors.white)))
              ]),
              const SizedBox(height: 8),
              Text(
                  dailySales == null
                      ? 'Fecha del negocio pendiente de consulta'
                      : '${dailySales!.isToday(DateTime.now()) ? '' : 'Último dato: '}${dateEs(dailySales!.day)}',
                  style: const TextStyle(color: AppTheme.onBrandMuted)),
              const SizedBox(height: 12),
              FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                      dailySales?.isToday(DateTime.now()) == true
                          ? soles(dailySales!.amount)
                          : 'Sin datos de hoy',
                      style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: Colors.white))),
              const SizedBox(height: 8),
              const Text('Incluye ventas al contado y fiadas.',
                  style: TextStyle(color: AppTheme.onBrandMuted)),
              if (dailyCached ||
                  dailySales == null ||
                  !dailySales!.isToday(DateTime.now())) ...[
                const SizedBox(height: 8),
                Text(
                    dailySales == null
                        ? 'Conecta para consultar las ventas de hoy.'
                        : !dailySales!.isToday(DateTime.now())
                            ? 'Sin datos actuales. Último importe guardado: ${soles(dailySales!.amount)}; puede estar desactualizado.'
                            : 'Sin conexión · Datos guardados; pueden estar desactualizados.',
                    style: const TextStyle(
                        color: AppTheme.onBrandMuted, fontSize: 12)),
              ],
            ])),
        const SizedBox(height: 20),
        Card(
            child: Column(children: [
          if (writer)
            ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: const Icon(Icons.mic_none_rounded,
                    color: AppTheme.brandBlue, size: 30),
                title: const Text('Hablar con Finki',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Registra con tu voz, texto o una foto'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final saved = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                          builder: (_) => IntakePage(
                              api: api,
                              business: business!,
                              accounts: accounts,
                              categories: categories,
                              people: people)));
                  if (saved == true && mounted) await load();
                }),
          if (writer) const Divider(height: 1, indent: 20, endIndent: 20),
          ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              leading: const Icon(Icons.picture_as_pdf_outlined,
                  color: AppTheme.brandBlue, size: 30),
              title: const Text('Mi constancia',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Prepara un resumen de tu negocio en PDF'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      CertificatePage(api: api, business: business!)))),
        ])),
        const SizedBox(height: 12),
        const FinkiSection('¿Qué vas a registrar?'),
        if (writer)
          LayoutBuilder(
              builder: (context, c) =>
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    for (final item in [
                      (
                        'Venta',
                        Icons.add_rounded,
                        () => openForm('VENTA'),
                        FinkiButtonKind.primary
                      ),
                      (
                        'Gasto',
                        Icons.shopping_bag_outlined,
                        () => openForm('GASTO_OPERATIVO'),
                        FinkiButtonKind.secondary
                      ),
                      (
                        'Compra',
                        Icons.inventory_2_outlined,
                        () => openForm('COMPRA_MERCADERIA'),
                        FinkiButtonKind.secondary
                      ),
                      (
                        'Ver fiados',
                        Icons.people_outline,
                        () => selectTab(2),
                        FinkiButtonKind.secondary
                      ),
                    ])
                      SizedBox(
                          width: (c.maxWidth - 12) / 2,
                          child: FinkiButton(
                              label: item.$1,
                              icon: item.$2,
                              onPressed: item.$3,
                              kind: item.$4)),
                  ]))
        else
          const FinkiNotice('Tu acceso permite consultar este negocio.'),
        const FinkiSection('Dinero que se movió',
            subtitle: 'Cobros y pagos efectivamente registrados.'),
        metricPair('Cobros de ventas', 'cobros_ventas_minor',
            'Pagos operativos', 'pagos_operativos_minor'),
        metricPair('Clientes te deben', 'por_cobrar_minor', 'Debes pagar',
            'por_pagar_minor'),
        const FinkiSection('Mi dinero',
            subtitle: 'Saldo registrado en cada cuenta.'),
        if (accounts.isEmpty)
          const FinkiNotice('Crea una cuenta para registrar cobros o pagos.'),
        ...accounts.map((a) => FinkiMoneyCard(
            label: '${a['nombre']} · ${a['tipo']}',
            value: soles(a['saldo_registrado_minor']),
            icon: Icons.account_balance_wallet_outlined)),
        if (writer)
          const FinkiSection('Herramientas del negocio',
              subtitle: 'Organiza tus cuentas, categorías y contactos.'),
        if (writer)
          LayoutBuilder(
              builder: (context, constraints) =>
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    if (owner)
                      SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: FinkiButton(
                              onPressed: () => openForm('account'),
                              kind: FinkiButtonKind.outlined,
                              icon: Icons.add,
                              label: 'Cuenta')),
                    if (owner)
                      SizedBox(
                          width: (constraints.maxWidth - 12) / 2,
                          child: FinkiButton(
                              onPressed: () => openForm('category'),
                              kind: FinkiButtonKind.outlined,
                              icon: Icons.category_outlined,
                              label: 'Categoría')),
                    SizedBox(
                        width: constraints.maxWidth,
                        child: FinkiButton(
                            onPressed: () => openForm('person'),
                            kind: FinkiButtonKind.outlined,
                            icon: Icons.person_add_alt,
                            label: 'Cliente o proveedor')),
                  ])),
        FinkiSection('Actividad reciente',
            action: TextButton(
                onPressed: () => selectTab(1), child: const Text('Ver todo'))),
        if (history.isEmpty)
          FinkiEmpty(
              title: 'Aquí empieza tu historia',
              message:
                  'Tus ventas, compras y gastos aparecerán cuando los registres.',
              action: writer
                  ? FinkiButton(
                      label: 'Registrar mi primera venta',
                      onPressed: () => openForm('VENTA'))
                  : null),
        ...history.take(3).map(operationRow),
        const SizedBox(height: 24),
        if (writer && accounts.length >= 2)
          TextButton(
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                        builder: (_) => TransferPage(
                            api: api,
                            business: business!,
                            accounts: accounts)));
                if (saved == true && mounted) await load();
              },
              child: const Text('Mover dinero entre mis cuentas')),
      ]);

  Widget operationRow(Json r) {
    final person = people.where((p) => p['id'] == r['tercero_id']).firstOrNull;
    final incoming = ['VENTA', 'SALDO_CXC'].contains(r['tipo']);
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.borderBlue))),
        child: InkWell(
            onTap: () => details(r),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                                backgroundColor: AppTheme.paleBlue,
                                child: Icon(
                                    incoming
                                        ? Icons.south_west
                                        : Icons.north_east,
                                    size: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(r['concepto'] as String,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  Text(
                                      '${operationLabels[r['tipo']] ?? r['tipo']} · ${dateEs(r['fecha_operacion'], today: limaToday())}',
                                      style: const TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 12)),
                                  if (person != null)
                                    Text(person['nombre'] as String,
                                        style: const TextStyle(
                                            color: AppTheme.textMuted)),
                                  Text(stateEs(r['estado']),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textMuted)),
                                ])),
                          ]),
                      const SizedBox(height: 8),
                      Text('Total ${soles(r['total_minor'])}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (tab == 2) ...[
                        Text('Abonado ${soles(r['liquidado_minor'])}',
                            style: const TextStyle(color: AppTheme.textMuted)),
                        Text('Pendiente ${soles(r['pendiente_minor'])}',
                            style: const TextStyle(
                                color: AppTheme.brandBlue,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        if (writer)
                          TextButton.icon(
                              onPressed: () => details(r),
                              icon: const Icon(Icons.add_circle_outline),
                              label: Text(incoming
                                  ? 'Registrar abono'
                                  : 'Registrar pago')),
                      ],
                    ]))));
  }

  Widget get reportsPage =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Tus reportes', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Pregúntale a Finki'),
            subtitle:
                const Text('Consulta tus ventas, gastos, fiados y movimientos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => InsightsPage(
                    api: api, businessId: business!['id'] as String))),
          ),
        ),
        const SizedBox(height: 16),
        Text(
            periodEs(report?['desde'] ?? business?['inicio_historial'],
                report?['hasta'] ?? limaToday(),
                today: limaToday()),
            style: const TextStyle(color: AppTheme.textMuted)),
        const FinkiSection('Actividad del negocio'),
        tile('Ventas', report?['ventas_minor'], Icons.storefront_outlined),
        metricPair('Gastos operativos', 'gastos_minor', 'Compras de mercadería',
            'compras_minor'),
        tile(
            'Resultado estimado',
            report?['resultado_operativo_simplificado_minor'],
            Icons.calculate_outlined),
        const FinkiNotice(
            'Ventas menos compras y gastos registrados. Es un resultado simplificado: no representa utilidad contable ni dinero disponible.'),
        const FinkiSection('Ventas por mes',
            subtitle: 'Solo meses completos de tu historial.'),
        monthlyChart(),
        tile('Promedio de ventas mensual',
            report?['promedio_mensual_ventas_minor'], Icons.calendar_month),
        Text(
            '${report?['meses_completos'] ?? 0} meses completos · ${report?['dias_con_ventas'] ?? 0} días con ventas',
            style: const TextStyle(color: AppTheme.textMuted)),
        const FinkiSection('Tu historial económico'),
        Text('${report?['meses_historial'] ?? 0} meses de historial registrado',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    CertificatePage(api: api, business: business!))),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Mi constancia')),
      ]);

  Widget monthlyChart() {
    final months = (report?['ventas_mensuales'] as List? ?? []).cast<Map>();
    if (months.isEmpty) {
      return const FinkiEmpty(
          title: 'Tu historial está creciendo',
          message:
              'Al completar tu primer mes podrás consultar la evolución de tus ventas.');
    }
    final maxValue = months.fold<BigInt>(BigInt.one, (v, m) {
      final n = BigInt.parse(m['ventas_minor'] as String);
      return n > v ? n : v;
    });
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              for (final m in months)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(spacing: 16, children: [
                            Text(monthEs(m['mes'])),
                            Text(soles(m['ventas_minor']),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))
                          ]),
                          const SizedBox(height: 8),
                          Semantics(
                              label: '${m['mes']}: ${soles(m['ventas_minor'])}',
                              child: LinearProgressIndicator(
                                  value: (BigInt.parse(
                                                  m['ventas_minor'] as String) *
                                              BigInt.from(10000) ~/
                                              maxValue)
                                          .toDouble() /
                                      10000,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(8),
                                  backgroundColor: AppTheme.paleBlue)),
                        ])),
            ])));
  }

  Future<void> accountPage(Widget page, String success) async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => page));
    if (saved == true && mounted) {
      await load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    }
  }

  Widget get profilePage =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Tu perfil', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  ProfileAvatar(api: api),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(profile?['nombre'] ?? '',
                            style: Theme.of(context).textTheme.titleLarge),
                        if (profile?['telefono'] != null)
                          Text(profile!['telefono'] as String? ??
                              profile!['correo'] as String? ??
                              'Acceso con Google'),
                        if (profile?['correo'] != null)
                          Text(profile!['correo'] as String),
                      ])),
                ]))),
        const FinkiSection('Información personal'),
        Card(
            child: Column(children: [
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Editar mis datos'),
            subtitle: Text(api.offline
                ? 'Disponible al conectarte'
                : 'Nombre, teléfono y correo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: profile == null || api.offline || api.writing
                ? null
                : () async {
                    final saved = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                            builder: (_) =>
                                ProfileEditPage(api: api, profile: profile!)));
                    if (saved == true && mounted) {
                      await load();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Datos personales actualizados')));
                      }
                    }
                  },
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          ListTile(
            leading: const Icon(Icons.add_a_photo_outlined),
            title: const Text('Cambiar fotografía'),
            subtitle: const Text('Cámara, galería y encuadre'),
            trailing: const Icon(Icons.chevron_right),
            onTap: api.writing
                ? null
                : () => accountPage(
                    ProfilePhotoPage(api: api), 'Fotografía actualizada'),
          ),
        ])),
        const FinkiSection('Seguridad de la cuenta'),
        Card(
            child: Column(children: [
          ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(profile?['tiene_clave'] == false
                  ? 'Acceso con Google'
                  : 'Cambiar contraseña'),
              subtitle: Text(api.offline
                  ? 'Disponible al conectarte'
                  : profile?['tiene_clave'] == false
                      ? 'Entra con tu cuenta Google; no necesitas contraseña'
                      : 'Protege tu acceso a FINKI'),
              trailing: const Icon(Icons.chevron_right),
              onTap: api.offline || api.writing
                  ? null
                  : () => accountPage(
                      AccountSecurityPage(
                          api: api,
                          hasPassword: profile?['tiene_clave'] as bool?),
                      'Contraseña actualizada. Las demás sesiones se cerraron.')),
          const Divider(height: 1, indent: 20, endIndent: 20),
          ListTile(
              leading: const Icon(Icons.login_outlined),
              title: const Text('Tus identificadores de acceso'),
              subtitle: Text(
                  '${profile?['telefono'] ?? ''}${profile?['correo'] == null ? '\nPuedes agregar un correo opcional en tus datos.' : '\n${profile!['correo']}\nCorreo asociado sin verificación de titularidad. No se utiliza para recuperar contraseñas.'}')),
        ])),
        const FinkiSection('Negocio activo',
            subtitle: 'Cada negocio conserva sus propios registros.'),
        Card(
            child: Column(children: [
          for (final b in businesses)
            ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(b['nombre'] as String),
                subtitle: Text(
                    '${b['rol'] == 'PROPIETARIO' ? 'Propietario' : b['rol'] == 'COLABORADOR' ? 'Colaborador' : b['rol']} · ${b['id'] == business?['id'] ? 'Negocio actual' : 'Cambiar a este negocio'}'),
                trailing: b['id'] == business?['id']
                    ? const Icon(Icons.check_circle_outline,
                        color: AppTheme.success)
                    : const Icon(Icons.chevron_right),
                onTap: () {
                  business = b;
                  selectTab(0);
                }),
        ])),
        const FinkiSection('Gestión del negocio'),
        Card(
            child: Column(children: [
          if (owner)
            ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar mi negocio'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openForm('businessEdit')),
          ListTile(
              leading: const Icon(Icons.add_business_outlined),
              title: const Text('Crear otro negocio'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openForm('business')),
        ])),
        const FinkiSection('Sincronización y privacidad'),
        Card(
            child: Column(children: [
          ListTile(
              leading: Icon(api.offline
                  ? Icons.cloud_off_outlined
                  : Icons.cloud_done_outlined),
              title: Text(api.offline
                  ? 'Sin conexión al servidor'
                  : 'Conexión con el servidor disponible'),
              subtitle: Text(
                  '${api.localEntries.length} operaciones pendientes de sincronizar. Las propuestas por revisar aún no son operaciones.')),
          if (api.localEntries.isNotEmpty)
            ListTile(
                leading: const Icon(Icons.sync),
                title: Text(
                    api.syncing ? 'Sincronizando…' : 'Sincronizar pendientes'),
                onTap: api.syncing || api.writing
                    ? null
                    : () => action(() async {
                          await api.syncLocal();
                          await load();
                        })),
          const Divider(height: 1, indent: 20, endIndent: 20),
          ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacidad y consentimiento'),
              subtitle: const Text('Tú eliges cuándo pedir ayuda por internet'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showIntakePrivacy(context, 'Gemini')),
        ])),
        const FinkiSection('Ayuda e información'),
        Card(
            child: Column(children: [
          const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Versión de la aplicación'),
              subtitle: Text('FINKI 1.0.0 · Compilación 1')),
          ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Cómo usar FINKI'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showDialog<void>(
                  context: context,
                  builder: (c) => AlertDialog(
                          title: const Text('Registra, revisa y confirma'),
                          content: const Text(
                              'Habla, escribe o elige una foto. Revisa y corrige la propuesta antes de confirmar. La voz y el OCR locales funcionan sin internet en Android. La ayuda externa requiere tu autorización y conexión. Los registros pendientes se sincronizan al recuperar conexión con el servidor.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const Text('Entendido'))
                          ]))),
        ])),
        const SizedBox(height: 24),
        OutlinedButton.icon(
            onPressed: api.writing ? null : () => action(api.logout),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión')),
        const SizedBox(height: 20),
        const Center(
            child: Text('FINKI · Equipo Pingüinos',
                style: TextStyle(color: AppTheme.textMuted))),
      ]);
  Future<void> details(Json row) async {
    await action(() async {
      final detail = await api.request('GET', '$path/operaciones/${row['id']}');
      if (!mounted) return;
      await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (ctx) => SafeArea(
              child: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(detail['concepto'] as String,
                                style: Theme.of(context).textTheme.titleLarge),
                            Text(
                                '${dateEs(detail['fecha_operacion'], today: limaToday())} · ${stateEs(detail['estado'])}'),
                            const SizedBox(height: 16),
                            Text('Total: ${soles(detail['total_minor'])}'),
                            Text(
                                'Abonado: ${soles(detail['liquidado_minor'])}'),
                            Text(
                                'Pendiente: ${soles(detail['pendiente_minor'])}'),
                            if (writer &&
                                BigInt.parse(
                                        detail['pendiente_minor'] as String) >
                                    BigInt.zero)
                              FilledButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    openForm('payment', row: detail);
                                  },
                                  child: Text(detail['tipo'] == 'VENTA' ||
                                          detail['tipo'] == 'SALDO_CXC'
                                      ? 'Registrar abono'
                                      : 'Registrar pago'))
                          ])))));
    });
  }

  Widget listBody() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tab == 2 ? 'Fiados y pendientes' : 'Tus movimientos',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
            tab == 2
                ? 'Consulta quién te debe y qué debes pagar.'
                : 'Cada registro cuenta la historia de tu negocio.',
            style: const TextStyle(color: AppTheme.textMuted)),
        const SizedBox(height: 24),
        if (tab == 1)
          FinkiSelect(
              value: filter,
              label: 'Tipo de operación',
              required: false,
              items: const [
                DropdownMenuItem(value: '', child: Text('Todas')),
                DropdownMenuItem(value: 'VENTA', child: Text('Ventas')),
                DropdownMenuItem(
                    value: 'GASTO_OPERATIVO', child: Text('Gastos')),
                DropdownMenuItem(
                    value: 'COMPRA_MERCADERIA', child: Text('Compras'))
              ],
              onChanged: (v) {
                filter = v!;
                load();
              }),
        if (tab == 1) ...[
          const SizedBox(height: 12),
          FinkiSelect(
              label: 'Estado',
              value: statusFilter,
              required: false,
              items: const [
                DropdownMenuItem(value: '', child: Text('Todos los estados')),
                DropdownMenuItem(
                    value: 'CONFIRMADO', child: Text('Confirmado')),
                DropdownMenuItem(value: 'ANULADO', child: Text('Anulado'))
              ],
              onChanged: (v) {
                statusFilter = v ?? '';
                load();
              }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              icon: const Icon(Icons.date_range_outlined),
              label: Text(historyPeriod == null
                  ? 'Todas las fechas'
                  : periodEs(
                      historyPeriod!.start.toIso8601String().substring(0, 10),
                      historyPeriod!.end.toIso8601String().substring(0, 10),
                      today: limaToday())),
              onPressed: () async {
                final selected = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(1000),
                    lastDate: DateTime(9999, 12, 31),
                    initialDateRange: historyPeriod,
                    helpText: 'Elige el periodo del historial',
                    saveText: 'Aplicar');
                if (selected != null && mounted) {
                  historyPeriod = selected;
                  load();
                }
              }),
          if (historyPeriod != null)
            TextButton(
                onPressed: () {
                  historyPeriod = null;
                  load();
                },
                child: const Text('Quitar periodo')),
        ],
        if (tab == 2)
          tile(
              direction == 'COBRAR'
                  ? 'Total que te deben'
                  : 'Total que debes pagar',
              report?[direction == 'COBRAR'
                  ? 'por_cobrar_minor'
                  : 'por_pagar_minor'],
              Icons.people_outline),
        if (tab == 2)
          SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'COBRAR', label: Text('Me deben')),
                ButtonSegment(value: 'PAGAR', label: Text('Debo pagar'))
              ],
              selected: {
                direction
              },
              onSelectionChanged: (v) {
                direction = v.first;
                load();
              }),
        const SizedBox(height: 12),
        TextFormField(
            initialValue: search,
            maxLength: 100,
            decoration: InputDecoration(
                counterText: '',
                labelText: 'Buscar concepto',
                suffixIcon: IconButton(
                    onPressed: load, icon: const Icon(Icons.search))),
            onChanged: (v) => search = v,
            onFieldSubmitted: (_) => load()),
        const SizedBox(height: 12),
        if ((tab == 2 ? pending : history).isEmpty)
          FinkiEmpty(
              title: search.trim().isNotEmpty ||
                      filter.isNotEmpty ||
                      statusFilter.isNotEmpty ||
                      historyPeriod != null
                  ? 'Sin coincidencias'
                  : tab == 2
                      ? '¡Todo al día!'
                      : 'Aún no tienes movimientos',
              message: search.trim().isNotEmpty ||
                      filter.isNotEmpty ||
                      statusFilter.isNotEmpty ||
                      historyPeriod != null
                  ? 'Prueba con otro concepto o filtro.'
                  : tab == 2
                      ? (direction == 'COBRAR'
                          ? 'Todavía no tienes fiados pendientes.'
                          : 'No tienes pagos pendientes.')
                      : 'Cuando registres tu primera venta o gasto, aparecerá aquí.',
              action: writer &&
                      tab == 2 &&
                      direction == 'COBRAR' &&
                      search.trim().isEmpty
                  ? FinkiButton(
                      label: 'Registrar una venta fiada',
                      onPressed: () =>
                          openForm('VENTA', row: {'initial_mode': 'CREDITO'}))
                  : null),
        ...(tab == 2 ? pending : history).map(operationRow),
        if (nextOffset != null)
          TextButton(
              onPressed: more
                  ? null
                  : () => action(() async {
                        setState(() => more = true);
                        try {
                          await loadList(append: true);
                        } finally {
                          if (mounted) setState(() => more = false);
                        }
                      }),
              child: Text(more ? 'Cargando…' : 'Ver más')),
      ]);
  Future<void> discard() async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Revisa antes de descartar'),
                content: SelectableText(
                    'Comando: ${api.pending?['body']['command_id']}\nPuede haberse guardado. Comprueba el historial y conserva este código. Descartar no anula nada en el servidor.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Volver')),
                  TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Ya revisé, descartar'))
                ]));
    if (yes == true) {
      await api.discardPending();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            toolbarHeight: 76,
            title: FinkiBrandHeader(
                subtitle: business?['nombre'] ?? 'Mis negocios'),
            actions: [
              IconButton(
                  onPressed: loading ? null : load,
                  tooltip: 'Actualizar',
                  icon: const Icon(Icons.refresh)),
              PopupMenuButton<String>(
                  enabled: !loading && !api.writing,
                  onSelected: (v) => action(() async {
                        if (v == 'logout') {
                          await api.logout();
                        } else if (v == 'new') {
                          await openForm('business');
                        } else {
                          business = businesses.firstWhere((b) => b['id'] == v);
                          await load();
                        }
                      }),
                  itemBuilder: (_) => [
                        const PopupMenuItem<String>(
                            enabled: false,
                            child: SizedBox(
                                width: 220,
                                child: FinkiBrandHeader(
                                    subtitle: 'Tu negocio, más claro'))),
                        const PopupMenuDivider(),
                        ...businesses.map((b) => PopupMenuItem(
                            value: b['id'] as String,
                            child: Text(b['nombre'] as String))),
                        const PopupMenuItem(
                            value: 'new', child: Text('Crear otro negocio')),
                        PopupMenuItem(
                            enabled: false,
                            child: Text(profile?['nombre'] ?? '')),
                        const PopupMenuItem(
                            value: 'logout', child: Text('Cerrar sesión'))
                      ])
            ]),
        body: loading
            ? const FinkiLoading()
            : error != null
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.cloud_off, size: 48),
                          Text(error is ApiException
                              ? (error as ApiException).message
                              : 'No se pudieron cargar los datos.'),
                          FilledButton(
                              onPressed: load, child: const Text('Reintentar'))
                        ])))
                : RefreshIndicator(
                    onRefresh: load,
                    child: Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(
                                maxWidth: FinkiSpace.contentWidth),
                            child: ListView(
                                key: const ValueKey('business-content-scroll'),
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(20, 24, 20, 56),
                                children: [
                                  if (api.offline)
                                    const FinkiNotice(
                                        'Sin conexión. Ves los últimos datos guardados en este celular; los totales pueden haber cambiado.'),
                                  if (api.localEntries.isNotEmpty)
                                    Card(
                                        child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Text(
                                                      '${api.localEntries.length} registros de tus negocios guardados en este celular. Aún no están confirmados en tu cuenta.'),
                                                  for (final entry
                                                      in api.localEntries)
                                                    ListTile(
                                                        onTap:
                                                            entry['estado'] !=
                                                                    'REVISION'
                                                                ? null
                                                                : () async {
                                                                    final yes = await showDialog<
                                                                            bool>(
                                                                        context:
                                                                            context,
                                                                        builder: (c) =>
                                                                            AlertDialog(title: const Text('Revisa tu historial primero'), content: Text('${entry['error']}\nRetirar este envío del celular no anula nada que ya esté guardado. Después podrás corregirlo y registrarlo otra vez.'), actions: [
                                                                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Volver')),
                                                                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ya revisé: retirar envío'))
                                                                            ]));
                                                                    if (yes ==
                                                                        true) {
                                                                      await api.removeReviewedLocal(entry['body']
                                                                              [
                                                                              'command_id']
                                                                          as String);
                                                                      if (mounted) {
                                                                        setState(
                                                                            () {});
                                                                      }
                                                                    }
                                                                  },
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        title: Text((entry['body']['payload']['operacion']?['concepto'] ??
                                                                entry['body']['payload']
                                                                        ['movimiento']
                                                                    ?[
                                                                    'concepto'] ??
                                                                'Registro pendiente')
                                                            .toString()),
                                                        subtitle: Text(entry['estado'] ==
                                                                'REVISION'
                                                            ? 'Necesita revisión: ${entry['error']}'
                                                            : 'Pendiente de sincronizar')),
                                                  OutlinedButton(
                                                      onPressed: api.syncing
                                                          ? null
                                                          : () =>
                                                              action(() async {
                                                                await api
                                                                    .syncLocal();
                                                                await load();
                                                              }),
                                                      child: Text(api.syncing
                                                          ? 'Sincronizando…'
                                                          : 'Sincronizar ahora')),
                                                ]))),
                                  if (api.pending != null)
                                    Card(
                                        color: AppTheme.warningSurface,
                                        child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(children: [
                                              const Text(
                                                  'Un envío está pendiente de confirmar. No vuelvas a registrarlo.'),
                                              Wrap(children: [
                                                TextButton(
                                                    onPressed: api.writing
                                                        ? null
                                                        : () =>
                                                            action(() async {
                                                              await api
                                                                  .retryPending();
                                                              await load();
                                                            }),
                                                    child: const Text(
                                                        'Reintentar mismo envío')),
                                                TextButton(
                                                    onPressed: api.writing
                                                        ? null
                                                        : discard,
                                                    child: const Text(
                                                        'Revisar y descartar'))
                                              ])
                                            ]))),
                                  if (business == null)
                                    FinkiEmpty(
                                        title: 'Dale un espacio a tu negocio',
                                        message:
                                            'Empieza con su nombre. Tus registros estarán separados de otros negocios.',
                                        action: FilledButton(
                                            onPressed: () =>
                                                openForm('business'),
                                            child:
                                                const Text('Crear mi negocio')))
                                  else if (tab == 0)
                                    overview
                                  else if (tab == 3)
                                    reportsPage
                                  else if (tab == 4)
                                    profilePage
                                  else
                                    listBody(),
                                ])))),
        bottomNavigationBar: business == null
            ? null
            : ColoredBox(
                color: Colors.white,
                child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth: FinkiSpace.contentWidth),
                        child: NavigationBar(
                            selectedIndex: tab,
                            onDestinationSelected: loading ? null : selectTab,
                            destinations: [
                              const NavigationDestination(
                                  icon: Icon(Icons.dashboard_outlined),
                                  label: 'Inicio'),
                              const NavigationDestination(
                                  icon: Icon(Icons.receipt_long_outlined),
                                  label: 'Historial'),
                              const NavigationDestination(
                                  icon: Icon(Icons.people_outline),
                                  label: 'Fiados'),
                              const NavigationDestination(
                                  icon: Icon(Icons.bar_chart_outlined),
                                  label: 'Reportes'),
                              NavigationDestination(
                                  icon: ProfileAvatar(
                                      api: api, radius: 12, navigation: true),
                                  label: 'Perfil')
                            ])))),
      );
}
