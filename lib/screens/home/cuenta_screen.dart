import 'package:flutter/material.dart';

import '../../core/auth_session.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/inventario/insumo_repository.dart';
import '../../repositories/salud/evento_sanitario_repository.dart';
import '../salud/historial_salud_screen.dart';

class CuentaScreen extends StatelessWidget {
  final AuthSession session;
  final EventoSanitarioRepository eventoSanitarioRepository;
  final CatalogoRepository catalogoRepository;
  final InsumoRepository insumoRepository;

  const CuentaScreen({
    super.key,
    required this.session,
    required this.eventoSanitarioRepository,
    required this.catalogoRepository,
    required this.insumoRepository,
  });

  @override
  Widget build(BuildContext context) {
    final usuario = session.usuario;
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Column(
            children: [
              const CircleAvatar(
                  radius: 36, child: Icon(Icons.person, size: 36)),
              const SizedBox(height: 16),
              Text(
                usuario?.nombreUsuario ?? 'Usuario',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(usuario?.correoElectronico ?? '',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
              if (usuario != null)
                Chip(
                    label: Text(usuario.rolNombre),
                    visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: 32),
          Card(
            child: ListTile(
              leading: const Icon(Icons.health_and_safety_outlined),
              title: const Text('Eventos de salud registrados'),
              subtitle: const Text('Consultar, editar y eliminar'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HistorialSaludScreen(
                      repository: eventoSanitarioRepository,
                      catalogoRepository: catalogoRepository,
                      insumoRepository: insumoRepository,
                      session: session,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => session.cerrarSesion(),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
