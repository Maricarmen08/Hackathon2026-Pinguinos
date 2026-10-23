import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_client.dart';
import 'profile_photo_state.dart';

/// All locations observe the same user-scoped photo state.
class ProfileAvatar extends StatefulWidget {
  final ApiClient api;
  final double radius;
  final bool navigation;
  const ProfileAvatar(
      {super.key,
      required this.api,
      this.radius = 28,
      this.navigation = false});
  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  late final photo = ProfilePhotoState.of(widget.api);
  @override
  void initState() {
    super.initState();
    photo.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: photo,
      builder: (_, __) {
        final bytes = photo.bytes;
        if (widget.navigation && bytes == null) {
          return const Icon(Icons.person_outline);
        }
        return ExcludeSemantics(
            child: CircleAvatar(
                radius: widget.radius,
                backgroundColor: const Color(0xffeaf3ff),
                backgroundImage: bytes == null ? null : MemoryImage(bytes),
                child: bytes == null
                    ? Icon(Icons.person_outline, size: widget.radius * .9)
                    : null));
      });
}

class ProfilePhotoPage extends StatefulWidget {
  final ApiClient api;
  final Future<XFile?> Function(ImageSource)? selectImage;
  const ProfilePhotoPage({super.key, required this.api, this.selectImage});
  @override
  State<ProfilePhotoPage> createState() => _ProfilePhotoPageState();
}

class _ProfilePhotoPageState extends State<ProfilePhotoPage> {
  late final photo = ProfilePhotoState.of(widget.api);
  @override
  void initState() {
    super.initState();
    photo.load();
  }

  ui.Image? image;
  Uint8List? source;
  double x = .5, y = .5;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    image?.dispose();
    super.dispose();
  }

  Future<void> pick(ImageSource origin) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final picked = widget.selectImage != null
          ? await widget.selectImage!(origin)
          : await ImagePicker().pickImage(
              source: origin,
              maxWidth: 1024,
              maxHeight: 1024,
              imageQuality: 85);
      if (picked == null) return;
      if (await picked.length() > 10 * 1024 * 1024) {
        throw const FormatException(
            'La imagen es demasiado grande. Elige otra fotografía.');
      }
      final bytes = await picked.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      image?.dispose();
      setState(() {
        image = frame.image;
        source = bytes;
        x = .5;
        y = .5;
      });
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'No pudimos abrir la foto. Revisa los permisos o elige otra imagen.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> save({bool remove = false}) async {
    if (busy || (!remove && image == null)) return;
    if (remove) {
      final approved = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('¿Eliminar fotografía?'),
                  content:
                      const Text('Volverás a usar el avatar predeterminado.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Eliminar'))
                  ]));
      if (approved != true || !mounted) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final owner = widget.api.userId;
      String? savedImage;
      if (remove) {
        await widget.api.request('DELETE', '/perfil/foto');
      } else {
        final img = image!,
            side = math.min(image!.width, image!.height).toDouble();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawImageRect(
            img,
            Rect.fromLTWH(
                (img.width - side) * x, (img.height - side) * y, side, side),
            const Rect.fromLTWH(0, 0, 256, 256),
            Paint()..filterQuality = FilterQuality.high);
        final picture = recorder.endRecording();
        final normalized = await picture.toImage(256, 256);
        picture.dispose();
        final encoded =
            await normalized.toByteData(format: ui.ImageByteFormat.png);
        normalized.dispose();
        if (encoded == null) throw const FormatException('Imagen no válida');
        savedImage = base64Encode(encoded.buffer.asUint8List());
        await widget.api.request('PUT', '/perfil/foto',
            bytes: encoded.buffer.asUint8List(),
            headers: {'Content-Type': 'application/octet-stream'});
      }
      await photo.saved(owner, savedImage);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is ApiException
            ? e.message
            : 'No se pudo guardar la fotografía.');
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
      child: AnimatedBuilder(
          animation: photo,
          builder: (_, __) => Scaffold(
                appBar: AppBar(title: const Text('Fotografía de perfil')),
                body: ListView(padding: const EdgeInsets.all(20), children: [
                  const Text(
                      'Solo tú puedes acceder a tu fotografía desde tu cuenta.'),
                  const SizedBox(height: 24),
                  Center(
                      child: SizedBox(
                          width: 160,
                          height: 160,
                          child: ClipOval(
                              child: source == null
                                  ? Center(
                                      child: ProfileAvatar(
                                          api: widget.api, radius: 80))
                                  : Image.memory(source!,
                                      fit: BoxFit.cover,
                                      alignment:
                                          Alignment(x * 2 - 1, y * 2 - 1))))),
                  if (image != null) ...[
                    const SizedBox(height: 16),
                    const Text('Ajusta el encuadre y confirma para guardar.'),
                    if (image!.width > image!.height)
                      Slider(
                          value: x,
                          onChanged: busy ? null : (v) => setState(() => x = v),
                          semanticFormatterCallback: (v) =>
                              'Encuadre horizontal'),
                    if (image!.height > image!.width)
                      Slider(
                          value: y,
                          onChanged: busy ? null : (v) => setState(() => y = v),
                          semanticFormatterCallback: (v) =>
                              'Encuadre vertical'),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                      onPressed: busy || widget.api.offline
                          ? null
                          : () => pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Elegir de la galería')),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: busy || widget.api.offline
                          ? null
                          : () => pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Tomar fotografía')),
                  if (image != null) ...[
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: busy ? null : save,
                        child: const Text('Confirmar y guardar fotografía')),
                  ],
                  if (photo.hasPhoto) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                        onPressed: busy || widget.api.offline
                            ? null
                            : () => save(remove: true),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar fotografía')),
                  ],
                  if (busy) const Center(child: CircularProgressIndicator()),
                  if (error != null)
                    Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  if (widget.api.offline)
                    const Text(
                        'Sin conexión: ves la última fotografía guardada en este dispositivo. Conéctate para cambiarla.'),
                  const SizedBox(height: 16),
                  Text(
                      'Se guarda una copia de 256 × 256 píxeles, sin metadatos de ubicación. No se envía a servicios de IA.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5)),
                ]),
              )));
}
