import 'package:flutter/material.dart';

import '../../core/auth_session.dart';

class CuentaScreen extends StatelessWidget {
  final AuthSession session;

  const CuentaScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final usuario = session.usuario;
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 36)),
              const SizedBox(height: 16),
              Text(
                usuario?.nombreUsuario ?? 'Usuario',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(usuario?.correoElectronico ?? '', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
              if (usuario != null)
                Chip(label: Text(usuario.rolNombre), visualDensity: VisualDensity.compact),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => session.cerrarSesion(),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
