import 'package:flutter/material.dart';
import 'api_client.dart';
import 'google_access.dart';

class AccountSecurityPage extends StatefulWidget {
  final ApiClient api;
  final bool? hasPassword;
  const AccountSecurityPage({super.key, required this.api, this.hasPassword});
  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  final form = GlobalKey<FormState>();
  final fields = List.generate(3, (_) => TextEditingController());
  final hidden = [true, true, true];
  bool busy = false;
  String? error;
  bool get googleOnly =>
      (widget.hasPassword ?? widget.api.session?['usuario']?['tiene_clave']) ==
      false;
  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.request('POST', '/perfil/contrasena', body: {
        'actual': fields[0].text,
        'nueva': fields[1].text,
        'confirmacion': fields[2].text,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException
            ? e.message
            : 'No se pudo cambiar la contraseña.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
            title:
                Text(googleOnly ? 'Acceso con Google' : 'Cambiar contraseña')),
        body: googleOnly
            ? const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                    'Tu cuenta utiliza Google. No necesitas una contraseña de FINKI para entrar.'))
            : Form(
                key: form,
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  const Text('Protege tu cuenta'),
                  GoogleAccess(api: widget.api, link: true),
                  const SizedBox(height: 8),
                  const Text(
                      'Usa una contraseña diferente de 12 a 128 caracteres. Tu sesión actual seguirá abierta; las demás se cerrarán.'),
                  const SizedBox(height: 24),
                  for (int i = 0; i < 3; i++) ...[
                    TextFormField(
                        controller: fields[i],
                        enabled: !busy,
                        obscureText: hidden[i],
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                            labelText: [
                              'Contraseña actual',
                              'Nueva contraseña',
                              'Confirmar nueva contraseña'
                            ][i],
                            suffixIcon: IconButton(
                                tooltip: hidden[i]
                                    ? 'Mostrar contraseña'
                                    : 'Ocultar contraseña',
                                onPressed: busy
                                    ? null
                                    : () =>
                                        setState(() => hidden[i] = !hidden[i]),
                                icon: Icon(hidden[i]
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined))),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Completa este campo';
                          }
                          if (v.length > 128 || (i > 0 && v.length < 12)) {
                            return 'Usa de 12 a 128 caracteres';
                          }
                          if (i == 1 && v == fields[0].text) {
                            return 'Elige una contraseña diferente';
                          }
                          if (i == 2 && v != fields[1].text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        }),
                    const SizedBox(height: 16),
                  ],
                  if (error != null)
                    Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 8),
                  FilledButton(
                      onPressed: busy || widget.api.offline ? null : save,
                      child: Text(busy ? 'Guardando…' : 'Guardar contraseña')),
                  if (widget.api.offline)
                    const Text('Conéctate para cambiar tu contraseña.'),
                ])),
      ));
}
