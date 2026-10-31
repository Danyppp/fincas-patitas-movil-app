import 'package:flutter/material.dart';

import '../../core/auth_session.dart';
import '../../repositories/catalogo/catalogo_repository.dart';
import '../../repositories/inventario/insumo_repository.dart';
import '../../repositories/salud/evento_sanitario_repository.dart';
import '../../theme/app_theme.dart';
import '../salud/historial_salud_screen.dart';

/// Pantalla "Cuenta" -- antes solo tenía la tarjeta de "Eventos de salud
/// registrados" con el estilo plano por defecto de Flutter. El resto de
/// las opciones del mockup `cuenta_y_gesti_n_fincas_y_patitas` (Datos de
/// la finca, Gestión de usuarios y operarios, Seguridad y contraseña) no
/// tenían ninguna pantalla todavía, así que quedan acá como tarjetas de
/// diseño (sin funcionalidad real -- al tocarlas se avisa que están
/// pendientes) para que la pantalla de Cuenta se vea completa, tal como
/// pidió Dany (Etapa 2: Estilos, 2026-11-01).
///
/// La navegación inferior (Animales/Reproducción/Producción/Inventario/
/// Cuenta) del mockup no se toca acá -- ya vive en `home_shell.dart`.
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

  void _proximamente(BuildContext context, String seccion) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$seccion estará disponible próximamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = session.usuario;
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // -- Perfil: avatar circular verde + nombre + correo + rol --
          Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppTheme.primaryContainer.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child:
                        const Icon(Icons.person, size: 48, color: Colors.white),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 1,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () =>
                            _proximamente(context, 'Cambiar foto de perfil'),
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Icon(Icons.camera_alt_outlined,
                              size: 15, color: AppTheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                usuario?.nombreUsuario ?? 'Usuario',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(usuario?.correoElectronico ?? '',
                  style: TextStyle(color: AppTheme.outline, fontSize: 13.5)),
              if (usuario != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    border: Border.all(color: AppTheme.outlineVariant),
                  ),
                  child: Text(
                    usuario.rolNombre,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 28),

          // -- Gestión Sanitaria y Registros --
          _tituloSeccion('GESTIÓN SANITARIA Y REGISTROS'),
          const SizedBox(height: 8),
          _grupoOpciones([
            _opcion(
              context,
              icono: Icons.health_and_safety_outlined,
              iconoFondo: const Color(0xFFF0F7ED),
              iconoColor: const Color(0xFF2E7D32),
              titulo: 'Eventos de salud registrados',
              subtitulo: 'Consultar, editar y eliminar',
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
          ]),
          const SizedBox(height: 22),

          // -- Configuración de la Finca y Cuenta --
          _tituloSeccion('CONFIGURACIÓN DE LA FINCA Y CUENTA'),
          const SizedBox(height: 8),
          _grupoOpciones([
            _opcion(
              context,
              icono: Icons.home_work_outlined,
              iconoFondo: const Color(0xFFEFEBE9),
              iconoColor: const Color(0xFF5D4037),
              titulo: 'Datos de la finca',
              subtitulo: 'Ubicación, lotes y potreros',
              onTap: () => _proximamente(context, 'Datos de la finca'),
            ),
            _opcion(
              context,
              icono: Icons.groups_outlined,
              iconoFondo: const Color(0xFFEDE7F6),
              iconoColor: const Color(0xFF512DA8),
              titulo: 'Gestión de usuarios y operarios',
              subtitulo: 'Permisos y accesos del personal',
              onTap: () =>
                  _proximamente(context, 'Gestión de usuarios y operarios'),
            ),
            _opcion(
              context,
              icono: Icons.lock_outline,
              iconoFondo: const Color(0xFFE0F2F1),
              iconoColor: const Color(0xFF00796B),
              titulo: 'Seguridad y contraseña',
              subtitulo: 'Actualizar clave de acceso',
              onTap: () => _proximamente(context, 'Seguridad y contraseña'),
            ),
          ]),
          const SizedBox(height: 28),

          FilledButton.icon(
            onPressed: () => session.cerrarSesion(),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  Widget _tituloSeccion(String texto) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppTheme.outline,
        ),
      ),
    );
  }

  /// Tarjeta blanca redondeada que agrupa varias filas de opción,
  /// separadas por una línea delgada -- igual al mockup.
  Widget _grupoOpciones(List<Widget> filas) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < filas.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  thickness: 1,
                  color: AppTheme.surfaceContainerHigh),
            filas[i],
          ],
        ],
      ),
    );
  }

  Widget _opcion(
    BuildContext context, {
    required IconData icono,
    required Color iconoFondo,
    required Color iconoColor,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconoFondo,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm + 4),
              ),
              child: Icon(icono, color: iconoColor, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitulo,
                      style: TextStyle(fontSize: 12, color: AppTheme.outline)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.outline, size: 20),
          ],
        ),
      ),
    );
  }
}
