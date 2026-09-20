import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../repositories/auth/auth_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth/auth_card.dart';
import 'reset_password_screen.dart';

/// HU-03, paso 1.
///
/// Copy honesto con lo que el backend realmente hace hoy: NO envía correo
/// (confirmado en `auth.service.ts`). El backend responde con un mensaje
/// genérico exista o no el correo, y solo incluye `reset_token` en la
/// respuesta cuando sí existe. Por eso esta pantalla no promete un enlace
/// por email ni valida en vivo si el correo está registrado.
class ForgotPasswordScreen extends StatefulWidget {
  final AuthRepository repository;

  const ForgotPasswordScreen({super.key, required this.repository});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  bool _cargando = false;
  String? _error;
  String? _mensajeResultado;
  String? _resetToken;

  @override
  void dispose() {
    _correoCtrl.dispose();
    super.dispose();
  }

  Future<void> _solicitar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
      _mensajeResultado = null;
      _resetToken = null;
    });

    try {
      final resultado = await widget.repository.solicitarRecuperacion(
        correoElectronico: _correoCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _mensajeResultado = resultado.mensaje;
        _resetToken = resultado.resetToken;
      });
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

  void _continuarConToken() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResetPasswordScreen(
          repository: widget.repository,
          tokenInicial: _resetToken,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
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
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.vpn_key_outlined,
                          size: 40,
                          color: AppTheme.primaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      // Copy honesto: no se promete envío de correo, porque el
                      // backend hoy no lo hace (MVP sin servicio de email).
                      'Ingresa tu correo electrónico. Si está registrado, te '
                      'daremos un código de recuperación para usar en el '
                      'siguiente paso.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    AuthCard(
                      children: [
                        TextFormField(
                          controller: _correoCtrl,
                          keyboardType: TextInputType.emailAddress,
                          enabled: _mensajeResultado == null,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Ingresa tu correo' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: AppTheme.error)),
                        ],
                        if (_mensajeResultado != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryContainer.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_mensajeResultado!, style: textTheme.bodyMedium),
                                if (_resetToken != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tu código de recuperación:',
                                    style: textTheme.labelMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    _resetToken!,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (_mensajeResultado == null)
                          FilledButton(
                            onPressed: _cargando ? null : _solicitar,
                            child: _cargando
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Solicitar recuperación'),
                          )
                        else if (_resetToken != null)
                          FilledButton(
                            onPressed: _continuarConToken,
                            child: const Text('Continuar con este código'),
                          )
                        else
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ResetPasswordScreen(repository: widget.repository),
                              ),
                            ),
                            child: const Text('Ya tengo un código'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Volver a iniciar sesión'),
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
