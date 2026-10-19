import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../widgets/profile_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late String _avatar;
  String? _photo;
  bool _saving = false;
  bool _picking = false;
  String? _error;
  static const _avatars = {
    'terracotta': 'Terracota',
    'sage': 'Salvia',
    'sand': 'Arena',
  };

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _name = TextEditingController(text: user?.fullName ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _avatar = user?.avatarId ?? 'terracotta';
    _photo = user?.profilePhoto;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_saving || _picking) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 512 * 1024) {
        setState(
          () => _error = 'La foto debe ocupar como máximo 512 KB. Elige una imagen más pequeña.',
        );
        return;
      }
      final png = bytes.length > 4 && bytes[0] == 137 && bytes[1] == 80;
      final webp = bytes.length > 12 && bytes[0] == 82 && bytes[8] == 87;
      final mime = png
          ? 'png'
          : webp
          ? 'webp'
          : 'jpeg';
      setState(() => _photo = 'data:image/$mime;base64,${base64Encode(bytes)}');
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'No se pudo abrir la cámara o galería. Revisa el permiso y vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _picking || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final auth = context.read<AuthService>();
    final saved = await auth.updateProfile(
      fullName: _name.text,
      email: _email.text,
      avatarId: _avatar,
      profilePhoto: _photo,
      updateImage: true,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) _photo = auth.currentUser?.profilePhoto;
      if (!saved) _error = auth.errorMessage ?? 'No se pudo guardar el perfil.';
    });
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cambios guardados. Si no hay conexión, quedarán pendientes de sincronizar.',
          ),
          backgroundColor: AppTheme.sageInk,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        'Mi perfil',
        style: AppTheme.editorial.copyWith(fontSize: 28),
      ),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ProfileAvatar(avatarId: _avatar, photo: _photo, size: 112),
          ),
          const SizedBox(height: 20),
          const Text(
            'Una imagen para ti',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Escoge un avatar o utiliza tu propia foto.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.brownMedium, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: _avatars.entries
                .map(
                  (entry) => Semantics(
                    selected: _photo == null && _avatar == entry.key,
                    button: true,
                    label: 'Avatar ${entry.value}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _saving || _picking
                          ? null
                          : () => setState(() {
                              _avatar = entry.key;
                              _photo = null;
                              _error = null;
                            }),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppTheme.surface,
                          border: Border.all(
                            width: 2,
                            color: _photo == null && _avatar == entry.key
                                ? AppTheme.terracotta
                                : AppTheme.border,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ProfileAvatar(avatarId: entry.key, size: 56),
                            const SizedBox(height: 8),
                            Text(
                              entry.value,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _saving || _picking
                    ? null
                    : () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Tomar foto'),
              ),
              OutlinedButton.icon(
                onPressed: _saving || _picking
                    ? null
                    : () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Galería'),
              ),
            ],
          ),
          if (_picking) const LinearProgressIndicator(),
          const SizedBox(height: 28),
          TextFormField(
            controller: _name,
            enabled: !_saving,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Nombre completo'),
            validator: (value) => AppValidators.validateRequired(
              value,
              'tu nombre',
              minLength: 2,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            enabled: !_saving,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Correo electrónico'),
            validator: AppValidators.validateEmail,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                _error!,
                style: const TextStyle(color: AppTheme.errorColor),
              ),
            ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving || _picking ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
          ),
          if (context.watch<AuthService>().biometrics != null)
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Desbloqueo con huella / biometría'),
              subtitle: const Text(
                'Usa la biometría registrada en este dispositivo. Tu contraseña no se guarda.',
              ),
              value: context.watch<AuthService>().biometricEnabled,
              onChanged: (enabled) async {
                final auth = context.read<AuthService>();
                final ok = await auth.setBiometric(enabled);
                if (!context.mounted) return;
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No se pudo activar. Registra una huella en los ajustes del dispositivo o vuelve a intentarlo.',
                      ),
                    ),
                  );
                }
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}
