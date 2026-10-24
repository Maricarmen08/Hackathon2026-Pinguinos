import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';
import 'api_client.dart';
import 'google_android_access.dart';
import 'google_button_stub.dart'
    if (dart.library.js_interop) 'google_button_web.dart';

class GoogleAccess extends StatefulWidget {
  final ApiClient api;
  final bool link;
  final Future<String?> Function()? tokenRequest;
  const GoogleAccess(
      {super.key, required this.api, this.link = false, this.tokenRequest});
  static const webId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const serverId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static final nonce = const Uuid().v4();
  static Future<void>? initialization;
  @override
  State<GoogleAccess> createState() => _GoogleAccessState();
}

class _GoogleAccessState extends State<GoogleAccess> {
  bool ready = false, busy = false, choosing = false;
  String? message;
  StreamSubscription<GoogleSignInAuthenticationEvent>? subscription;
  bool get configured =>
      widget.tokenRequest != null ||
      (kIsWeb
          ? GoogleAccess.webId.isNotEmpty
          : GoogleAccess.serverId.isNotEmpty);
  @override
  void initState() {
    super.initState();
    unawaited(prepare());
  }

  Future<void> prepare() async {
    if (!configured) return;
    if (widget.tokenRequest != null ||
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)) {
      setState(() => ready = true);
      return;
    }
    try {
      await (GoogleAccess.initialization ??= GoogleSignIn.instance.initialize(
          clientId: kIsWeb ? GoogleAccess.webId : null,
          serverClientId:
              GoogleAccess.serverId.isEmpty ? null : GoogleAccess.serverId,
          nonce: GoogleAccess.nonce));
      if (!mounted) return;
      if (kIsWeb) {
        subscription =
            GoogleSignIn.instance.authenticationEvents.listen((event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            unawaited(complete(event.user.authentication.idToken));
          }
        }, onError: (Object _) {
          if (mounted) {
            setState(() => message =
                'No se pudo completar Google. Puedes usar tu acceso habitual.');
          }
        });
      }
      setState(() => ready = true);
    } catch (_) {
      if (mounted) {
        setState(() => message =
            'Google no está disponible. Puedes usar tu acceso habitual.');
      }
    }
  }

  Future<void> start() async {
    if (busy || choosing) return;
    setState(() => choosing = true);
    try {
      if (widget.tokenRequest == null &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android) {
        final credential = await androidGoogleCredential(GoogleAccess.serverId);
        await complete(credential.token, nonce: credential.nonce);
        return;
      }
      if (widget.tokenRequest == null) await GoogleSignIn.instance.signOut();
      final token = widget.tokenRequest != null
          ? await widget.tokenRequest!()
          : (await GoogleSignIn.instance.authenticate()).authentication.idToken;
      await complete(token);
    } on GoogleSignInException catch (e) {
      if (mounted && e.code != GoogleSignInExceptionCode.canceled) {
        setState(() => message =
            'No se pudo iniciar con Google. Revisa la conexión y la configuración.');
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            message = 'No se pudo iniciar con Google. Inténtalo nuevamente.');
      }
    } finally {
      if (mounted) setState(() => choosing = false);
    }
  }

  Future<void> complete(String? token, {String? nonce}) async {
    if (!mounted || busy || token == null) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      String? password;
      if (widget.link) {
        var proof = '';
        password = await showDialog<String>(
            context: context,
            builder: (c) => AlertDialog(
                    scrollable: true,
                    title: const Text('Vincular Google'),
                    content: TextField(
                        onChanged: (value) => proof = value,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'Contraseña actual de FINKI')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () => Navigator.pop(c, proof),
                          child: const Text('Comprobar y vincular'))
                    ]));
        if (password == null) return;
      }
      await widget.api.authenticateGoogle(token, nonce ?? GoogleAccess.nonce,
          password: password);
      if (mounted && widget.link) {
        setState(() => message = 'Google quedó vinculado a tu cuenta.');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => message = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            message = 'No se pudo completar el acceso. Inténtalo nuevamente.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 12),
        if (kIsWeb && ready && widget.tokenRequest == null)
          IgnorePointer(
              ignoring: busy,
              child: LayoutBuilder(
                  builder: (context, c) => Center(
                      child: googleWebButton(
                          c.maxWidth.clamp(200, 400).toDouble()))))
        else
          OutlinedButton(
              onPressed: ready && !busy && !choosing ? start : null,
              child: Text(busy || choosing
                  ? 'Conectando…'
                  : widget.link
                      ? 'Vincular Google'
                      : 'Continuar con Google')),
        if (!configured)
          const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                  'Google estará disponible cuando el equipo complete su configuración.',
                  style: TextStyle(fontSize: 12))),
        if (message != null)
          Padding(
              padding: const EdgeInsets.only(top: 8), child: Text(message!)),
      ]);
}
