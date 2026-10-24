import 'package:flutter/material.dart';
import 'api_client.dart';

/// Uses the existing authenticated, version-checked profile endpoint.
class ProfileEditPage extends StatefulWidget {
  final ApiClient api;
  final Json profile;
  const ProfileEditPage({super.key, required this.api, required this.profile});
  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.profile['nombre']);
  late final phone = TextEditingController(text: widget.profile['telefono']);
  late final email = TextEditingController(text: widget.profile['correo']);
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    if (widget.api.offline) {
      setState(() => error = 'Conéctate para actualizar tus datos personales.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.api.request('PATCH', '/perfil', body: {
        'expected_version': widget.profile['version'].toString(),
        'nombre': name.text.trim(),
        if (phone.text.trim().isNotEmpty || widget.profile['telefono'] != null)
          'telefono': phone.text.trim(),
        'correo': email.text.trim().isEmpty ? null : email.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException
            ? '${e.message}${e.status == 409 ? ' Vuelve al perfil y actualiza antes de reintentar.' : ''}'
            : 'No pudimos actualizar tu perfil. Revisa tu conexión.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !busy,
        child: Scaffold(
          appBar: AppBar(title: const Text('Información personal')),
          body: Form(
              key: form,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                const Text('Actualiza tus datos de acceso y contacto.'),
                const SizedBox(height: 20),
                TextFormField(
                    controller: name,
                    enabled: !busy,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (v) => (v?.trim().isEmpty ?? true)
                        ? 'Escribe tu nombre'
                        : null),
                const SizedBox(height: 16),
                TextFormField(
                    controller: phone,
                    enabled: !busy,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Teléfono con código de país',
                        hintText: '+51987654321'),
                    validator: (v) => (widget.profile['telefono'] == null &&
                                (v?.trim().isEmpty ?? true)) ||
                            RegExp(r'^\+?[1-9]\d{7,14}$')
                                .hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Usa 987654321 o +51987654321'),
                const SizedBox(height: 16),
                TextFormField(
                    controller: email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(labelText: 'Correo (opcional)'),
                    validator: (v) => (v?.trim().isEmpty ?? true) ||
                            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(v!.trim())
                        ? null
                        : 'Revisa el correo'),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(error!)),
                const SizedBox(height: 12),
                const Text(
                    'El correo es opcional. Permite iniciar sesión junto con tu contraseña; no se usa para recuperarla y no verifica su titularidad.'),
                const SizedBox(height: 24),
                FilledButton(
                    onPressed: busy ? null : save,
                    child: Text(busy ? 'Guardando…' : 'Guardar cambios')),
              ])),
        ),
      );
}
