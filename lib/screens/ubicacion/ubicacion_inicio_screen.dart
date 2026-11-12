import 'package:flutter/material.dart';

import '../../core/auth_session.dart';
import '../../repositories/animales/animal_repository.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/ubicacion/ubicacion_repository.dart';
import '../../repositories/usuarios/usuario_repository.dart';
import '../../theme/app_theme.dart';
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
///
/// 2026-11-10 (Fase 2, Estilos): tarjetas de atajo con ícono en círculo de
/// color (mismo patrón ya usado en `produccion_dashboard_screen.dart`),
/// siguiendo los colores del mockup de Stitch para cada módulo -- verde
/// (primario) para "Lotes y Potreros", coral (terciario) para "Asignar
/// Animales", ámbar (secundario) para las dos pantallas de "Asignar
/// Personal". El encabezado ("Finca La Esperanza" + subtítulo) usa ahora
/// la tipografía del tema en vez de estilos sueltos; se mantiene sin la
/// tarjeta de estadísticas del mockup (descartada, ver sección 4 del
/// documento de decisiones -- no hay datos reales que mostrar ahí).
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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ubicación')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Finca La Esperanza', style: textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Lotes, potreros y asignación de animales y personal',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _atajo(
            context,
            icono: Icons.forest_outlined,
            colorFondo: AppTheme.primaryContainer,
            colorIcono: AppTheme.primary,
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
            icono: Icons.swap_horiz,
            colorFondo: AppTheme.tertiaryContainer,
            colorIcono: AppTheme.tertiary,
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
            icono: Icons.badge_outlined,
            colorFondo: AppTheme.secondaryContainer,
            colorIcono: AppTheme.secondary,
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
            colorFondo: AppTheme.secondaryContainer,
            colorIcono: AppTheme.secondary,
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
    required Color colorFondo,
    required Color colorIcono,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    // Card + InkWell en vez de ListTile con trailing clicable: no hay
    // ningún ButtonStyleButton acá (el chevron es solo un Icon), así que
    // esta fila no corre el riesgo del bug documentado en
    // decisiones-diseno-vs-backend-ubicacion.md sección 12 -- se mantiene
    // igual por consistencia visual con el resto del módulo.
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorFondo.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: colorIcono, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text(subtitulo,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
