import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/auth/usuario.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../repositories/ubicacion/ubicacion_repository.dart';
import '../../repositories/usuarios/usuario_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/boton_pill.dart';

/// Asignar Personal — Lote: selección única de un encargado por Lote, vía
/// `PATCH /lotes-animales/{id}/encargado` (ver
/// decisiones-diseno-vs-backend-ubicacion.md, sección 8).
///
/// Se excluye de la lista de candidatos al rol Administrador (rol_id=1):
/// "se mantiene la exclusión del usuario administrador activo para
/// labores operativas de campo".
///
/// `GET /users` (para listar candidatos) exige rol Administrador en el
/// backend real -- si la sesión activa no lo es, se muestra un aviso en
/// vez de la lista.
///
/// 2026-11-10 (Fase 2, Estilos): tarjeta de "Encargado actual" con acento
/// ámbar (mismo color que "Asignar Personal" en el Inicio de Ubicación) y
/// filas de persona con ícono en círculo. El "cargo" que mostraba el
/// mockup se descartó desde la sección 8 del documento de decisiones --
/// se usa el rol real del sistema (`rolNombre`), ya presente aquí. El
/// teléfono/botón "Llamar" del mockup tampoco se agregó: el modelo de
/// Usuario de este proyecto no tiene un campo de teléfono.
class AsignarPersonalLoteScreen extends StatefulWidget {
  final UbicacionRepository repository;
  final UsuarioRepository usuarioRepository;

  const AsignarPersonalLoteScreen({
    super.key,
    required this.repository,
    required this.usuarioRepository,
  });

  @override
  State<AsignarPersonalLoteScreen> createState() =>
      _AsignarPersonalLoteScreenState();
}

class _AsignarPersonalLoteScreenState extends State<AsignarPersonalLoteScreen> {
  List<LoteAnimal> _lotes = [];
  List<Usuario> _usuarios = [];
  LoteAnimal? _loteSeleccionado;

  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  String? _errorUsuarios;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
      _errorUsuarios = null;
    });
    try {
      final lotes = await widget.repository.listarLotes();
      if (!mounted) return;
      setState(() {
        _lotes = lotes;
        if (_loteSeleccionado != null) {
          try {
            _loteSeleccionado =
                lotes.firstWhere((l) => l.id == _loteSeleccionado!.id);
          } catch (_) {
            _loteSeleccionado = null;
          }
        }
      });
    } catch (e) {
      setState(() => _error = 'No se pudieron cargar los lotes: $e');
    }

    try {
      final usuarios = await widget.usuarioRepository.listarUsuarios();
      if (!mounted) return;
      setState(() => _usuarios = usuarios.where((u) => u.rolId != 1).toList());
    } on ApiException catch (e) {
      setState(() => _errorUsuarios = e.statusCode == 403
          ? 'Tu cuenta no tiene permiso para ver la lista de personal (requiere rol Administrador).'
          : e.message);
    } catch (e) {
      setState(() => _errorUsuarios = 'No se pudo cargar el personal: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _asignar(Usuario usuario) async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final actualizado = await widget.repository
          .asignarEncargadoLote(_loteSeleccionado!.id, usuario.id);
      if (!mounted) return;
      setState(() {
        _loteSeleccionado = actualizado;
        _lotes = [
          for (final l in _lotes) l.id == actualizado.id ? actualizado : l,
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('${usuario.nombreUsuario} asignado(a) como encargado(a)')),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _quitarEncargado() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final actualizado = await widget.repository
          .asignarEncargadoLote(_loteSeleccionado!.id, null);
      if (!mounted) return;
      setState(() {
        _loteSeleccionado = actualizado;
        _lotes = [
          for (final l in _lotes) l.id == actualizado.id ? actualizado : l,
        ];
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Asignar Personal — Lote')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<LoteAnimal>(
                  value: _loteSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Lote',
                    prefixIcon: Icon(Icons.grid_view_outlined),
                  ),
                  items: _lotes
                      .map((l) =>
                          DropdownMenuItem(value: l, child: Text(l.nombre)))
                      .toList(),
                  onChanged: (l) => setState(() => _loteSeleccionado = l),
                ),
                const SizedBox(height: 16),
                if (_loteSeleccionado != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          AppTheme.secondaryContainer.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppTheme.secondaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.badge_outlined,
                              color: AppTheme.onSecondaryContainer, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Encargado actual',
                                  style: textTheme.labelMedium),
                              Text(
                                _loteSeleccionado!.encargado?.nombreUsuario ??
                                    'Sin encargado',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              if (_loteSeleccionado!.encargado != null)
                                Text(
                                    _loteSeleccionado!
                                        .encargado!.correoElectronico,
                                    style: textTheme.bodySmall),
                            ],
                          ),
                        ),
                        if (_loteSeleccionado!.encargado != null)
                          BotonTexto(
                            texto: 'Quitar',
                            onTap: _guardando ? null : _quitarEncargado,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Elegir encargado', style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  if (_errorUsuarios != null)
                    Text(_errorUsuarios!,
                        style: const TextStyle(color: Colors.red))
                  else if (_usuarios.isEmpty)
                    Text('No hay usuarios disponibles',
                        style: textTheme.bodyMedium)
                  else
                    ..._usuarios.map((u) {
                      final yaEsEncargado =
                          _loteSeleccionado!.encargado?.id == u.id;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryContainer
                                      .withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_outline,
                                    color: AppTheme.secondary, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(u.nombreUsuario,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(
                                        '${u.correoElectronico} · ${u.rolNombre}',
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Colors.black54)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              yaEsEncargado
                                  ? EtiquetaPill(
                                      texto: 'Encargado actual',
                                      color: AppTheme.primaryContainer
                                          .withValues(alpha: 0.5),
                                      colorTexto: AppTheme.primary,
                                    )
                                  : BotonPill(
                                      texto: 'Asignar',
                                      color: AppTheme.primaryContainer,
                                      onTap:
                                          _guardando ? null : () => _asignar(u),
                                    ),
                            ],
                          ),
                        ),
                      );
                    }),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('Elige un Lote para ver/cambiar su encargado',
                        style: textTheme.bodyMedium),
                  ),
              ],
            ),
    );
  }
}
