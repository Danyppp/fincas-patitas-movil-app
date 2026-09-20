import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../repositories/auth/auth_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth/auth_card.dart';

class RegisterScreen extends StatefulWidget {
  final AuthRepository repository;

  const RegisterScreen({super.key, required this.repository});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();
  bool _cargando = false;
  bool _ocultarContrasena = true;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _contrasenaCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await widget.repository.registrar(
        nombreUsuario: _nombreCtrl.text.trim(),
        correoElectronico: _correoCtrl.text.trim(),
        contrasena: _contrasenaCtrl.text,
        telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta creada. Ahora inicia sesión.')),
      );
      Navigator.of(context).pop();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.badge_outlined, color: AppTheme.secondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'El rol se asigna automáticamente como Empleado; '
                              'un Administrador puede cambiarlo después.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.onSecondaryContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AuthCard(
                      children: [
                        TextFormField(
                          controller: _nombreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de usuario',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _correoCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _telefonoCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono (opcional)',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
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
                          // Sin mínimo de longitud: el backend solo valida que no
                          // esté vacía (decisión confirmada — no se agrega ninguna
                          // regla extra del lado del cliente).
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Ingresa una contraseña' : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: AppTheme.error)),
                        ],
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _cargando ? null : _registrar,
                          icon: _cargando
                              ? const SizedBox.shrink()
                              : const Icon(Icons.person_add_alt, size: 20),
                          label: _cargando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Crear cuenta'),
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
