import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../repositories/auth/auth_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth/auth_card.dart';

/// HU-03, paso 2 — pantalla que no existía en el diseño original de Stitch
/// (esas 15 pantallas asumían que el código llegaba por correo). Hace
/// falta porque el backend actual entrega el `reset_token` directo en la
/// respuesta del paso anterior, no por email.
class ResetPasswordScreen extends StatefulWidget {
  final AuthRepository repository;
  final String? tokenInicial;

  const ResetPasswordScreen({super.key, required this.repository, this.tokenInicial});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tokenCtrl;
  final _nuevaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  bool _cargando = false;
  bool _ocultarNueva = true;
  bool _ocultarConfirmar = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tokenCtrl = TextEditingController(text: widget.tokenInicial ?? '');
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _nuevaCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _restablecer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await widget.repository.restablecerContrasena(
        token: _tokenCtrl.text.trim(),
        nuevaContrasena: _nuevaCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada. Ya puedes iniciar sesión.')),
      );
      // Vuelve hasta la pantalla de Login (raíz del stack de Auth).
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ingresa el código de recuperación que obtuviste en el '
                      'paso anterior y tu nueva contraseña.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    AuthCard(
                      children: [
                        TextFormField(
                          controller: _tokenCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Código de recuperación',
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Ingresa el código' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nuevaCtrl,
                          obscureText: _ocultarNueva,
                          decoration: InputDecoration(
                            labelText: 'Nueva contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_ocultarNueva ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _ocultarNueva = !_ocultarNueva),
                            ),
                          ),
                          // Sin mínimo de longitud, igual que en Registro — el
                          // backend solo exige que no esté vacía.
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Ingresa una contraseña' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmarCtrl,
                          obscureText: _ocultarConfirmar,
                          decoration: InputDecoration(
                            labelText: 'Confirmar contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _ocultarConfirmar ? Icons.visibility_off : Icons.visibility),
                              onPressed: () =>
                                  setState(() => _ocultarConfirmar = !_ocultarConfirmar),
                            ),
                          ),
                          validator: (v) =>
                              (v != _nuevaCtrl.text) ? 'Las contraseñas no coinciden' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: AppTheme.error)),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _cargando ? null : _restablecer,
                          child: _cargando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Restablecer contraseña'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
