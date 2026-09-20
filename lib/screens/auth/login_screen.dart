import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/auth_session.dart';
import '../../repositories/auth/auth_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth/auth_card.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final AuthRepository repository;
  final AuthSession session;

  const LoginScreen({super.key, required this.repository, required this.session});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  bool _cargando = false;
  bool _ocultarContrasena = true;
  // "Recordar en este dispositivo" — 100% client-side (controla si el
  // token se persiste en SharedPreferences o solo vive en memoria).
  // Activado por defecto, igual que en el diseño de Stitch.
  bool _recordarDispositivo = true;
  String? _error;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _contrasenaCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final resultado = await widget.repository.iniciarSesion(
        correoElectronico: _correoCtrl.text.trim(),
        contrasena: _contrasenaCtrl.text,
      );
      await widget.session.guardarSesion(
        accessToken: resultado.accessToken,
        refreshToken: resultado.refreshToken,
        usuario: resultado.usuario,
        recordarEnDispositivo: _recordarDispositivo,
      );
      // No hace falta navegar: main.dart escucha AuthSession y cambia
      // automáticamente a HomeShell cuando isAuthenticated pasa a true.
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
                    // Logo circular — mismo tratamiento que en las pantallas
                    // de Stitch (círculo con fondo tintado + icono).
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.onSurface.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.agriculture_outlined,
                          size: 48,
                          color: AppTheme.primaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Fincas y Patitas',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Inicia sesión para continuar',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    AuthCard(
                      children: [
                        TextFormField(
                          controller: _correoCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Ingresa tu correo' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contrasenaCtrl,
                          obscureText: _ocultarContrasena,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _ocultarContrasena ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _ocultarContrasena = !_ocultarContrasena),
                            ),
                          ),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _cargando
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ForgotPasswordScreen(repository: widget.repository),
                                      ),
                                    ),
                            child: const Text('¿Olvidaste tu contraseña?'),
                          ),
                        ),
                        InkWell(
                          onTap: _cargando
                              ? null
                              : () => setState(
                                  () => _recordarDispositivo = !_recordarDispositivo),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _recordarDispositivo,
                                  onChanged: _cargando
                                      ? null
                                      : (v) =>
                                          setState(() => _recordarDispositivo = v ?? true),
                                ),
                                Expanded(
                                  child: Text(
                                    'Recordar en este dispositivo',
                                    style: textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!, style: TextStyle(color: AppTheme.error)),
                        ],
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _cargando ? null : _iniciarSesion,
                          icon: _cargando
                              ? const SizedBox.shrink()
                              : const Icon(Icons.login, size: 20),
                          label: _cargando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Iniciar sesión'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _cargando
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RegisterScreen(repository: widget.repository),
                                ),
                              ),
                      child: const Text('¿No tienes cuenta? Regístrate'),
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
