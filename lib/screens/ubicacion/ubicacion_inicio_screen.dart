import 'package:flutter/material.dart';

import '../../core/auth_session.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/ubicacion/ubicacion_repository.dart';
import '../../repositories/usuarios/usuario_repository.dart';
import 'asignar_animales_screen.dart';
import 'asignar_personal_lote_screen.dart';
import 'asignar_personal_potrero_screen.dart';
import 'lotes_potreros_list_screen.dart';

/// "Inicio" / Menú Principal de Ubicación -- hub con atajos a Lotes y
/// Potreros, Asignar Animales y Asignar Personal. Se llega desde
/// Cuenta -> "Datos de la finca".
///
/// Fase 1 (funcional, pocos estilos -- la Etapa 2 ajusta esto al mockup de
/// Stitch): solo navega de verdad a donde ya hay pantalla construida
/// (Lotes y Potreros); el resto apunta a `ProximamenteScreen` hasta que se
/// construyan en una entrega posterior -- mismo patrón que ya usa Cuenta
/// para sus propias secciones todavía no implementadas.
///
/// 2026-11-05 (decisiones-diseno-vs-backend-ubicacion.md sección 4): se
/// descartó por completo "Monitoreo satelital", "Rotación recomendada" y
/// "Capacidad de Carga General" del mockup original -- no existen en el
/// backend ni fueron parte del alcance pedido. El nombre de la finca
/// queda fijo como "Finca La Esperanza" (no hay tabla para eso).
///
/// 2026-11-05 (Entrega 2, Crear/Editar): ahora recibe también
/// `catalogoRepository` -- lo necesita `LotesPotrerosListScreen` para
/// pasárselo al formulario de Crear/Editar Lote (dropdown de especies).
class UbicacionInicioScreen extends StatelessWidget {
  final UbicacionRepository repository;
  final CatalogoRepository catalogoRepository;
  final AnimalRepository animalRepository;
  final UsuarioRepository usuarioRepository;
  final AuthSession session;

  const UbicacionInicioScreen({
    super.key,
    required this.repository,
    required this.catalogoRepository,
    required this.animalRepository,
    required this.usuarioRepository,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubicación')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Finca La Esperanza',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lotes, potreros y asignación de animales y personal',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          _atajo(
            context,
            icono: Icons.map_outlined,
            titulo: 'Lotes y Potreros',
            subtitulo: 'Ver, crear y administrar',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LotesPotrerosListScreen(
                  repository: repository,
                  catalogoRepository: catalogoRepository,
                  animalRepository: animalRepository,
                  session: session,
                ),
              ),
            ),
          ),
          _atajo(
            context,
            icono: Icons.pets_outlined,
            titulo: 'Asignar Animales',
            subtitulo: 'A un Lote o a un Potrero',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AsignarAnimalesScreen(
                  repository: repository,
                  animalRepository: animalRepository,
                ),
              ),
            ),
          ),
          _atajo(
            context,
            icono: Icons.person_outline,
            titulo: 'Asignar Personal — Lote',
            subtitulo: 'Un encargado por lote',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AsignarPersonalLoteScreen(
                  repository: repository,
                  usuarioRepository: usuarioRepository,
                ),
              ),
            ),
          ),
          _atajo(
            context,
            icono: Icons.groups_outlined,
            titulo: 'Asignar Personal — Potrero',
            subtitulo: 'Varios encargados por potrero',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AsignarPersonalPotreroScreen(
                  repository: repository,
                  usuarioRepository: usuarioRepository,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _atajo(
    BuildContext context, {
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icono),
        title: Text(titulo),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
