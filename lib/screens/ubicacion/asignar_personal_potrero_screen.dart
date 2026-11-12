import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/auth/usuario.dart';
import '../../models/catalogo/potrero.dart';
import '../../repositories/ubicacion/ubicacion_repository.dart';
import '../../repositories/usuarios/usuario_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/boton_pill.dart';

/// Asignar Personal — Potrero: selección MÚLTIPLE de encargados por
/// Potrero, vía `POST`/`DELETE /ubicaciones-potreros/{id}/encargados[/{usuarioId}]`
/// (ver decisiones-diseno-vs-backend-ubicacion.md, sección 8).
///
/// Se excluye de la lista de candidatos al rol Administrador (rol_id=1),
/// igual que en "Asignar Personal — Lote".
///
/// 2026-11-10 (Fase 2, Estilos): mismo lenguaje visual que
/// `asignar_personal_lote_screen.dart` -- acento ámbar, íconos en círculo.
/// Igual que allá, no se agregó el "cargo" de ejemplo del mockup (se usa
/// el rol real) ni el teléfono/"Llamar" (no existe ese campo en Usuario).
class AsignarPersonalPotreroScreen extends StatefulWidget {
  final UbicacionRepository repository;
  final UsuarioRepository usuarioRepository;

  const AsignarPersonalPotreroScreen({
    super.key,
    required this.repository,
    required this.usuarioRepository,
  });

  @override
  State<AsignarPersonalPotreroScreen> createState() =>
      _AsignarPersonalPotreroScreenState();
}

class _AsignarPersonalPotreroScreenState
    extends State<AsignarPersonalPotreroScreen> {
  List<Potrero> _potreros = [];
  List<Usuario> _usuarios = [];
  Potrero? _potreroSeleccionado;

  bool _cargando = true;
  final Set<int> _guardando = {};
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
      final potreros = await widget.repository.listarPotreros();
      if (!mounted) return;
      setState(() {
        _potreros = potreros;
        if (_potreroSeleccionado != null) {
          try {
            _potreroSeleccionado =
                potreros.firstWhere((p) => p.id == _potreroSeleccionado!.id);
          } catch (_) {
            _potreroSeleccionado = null;
          }
        }
      });
    } catch (e) {
      setState(() => _error = 'No se pudieron cargar los potreros: $e');
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

  bool _esEncargado(Usuario u) =>
      _potreroSeleccionado!.encargados.any((pe) => pe.usuario.id == u.id);

  Future<void> _agregar(Usuario usuario) async {
    setState(() {
      _guardando.add(usuario.id);
      _error = null;
    });
    try {
      final actualizado = await widget.repository
          .agregarEncargadoPotrero(_potreroSeleccionado!.id, usuario.id);
      if (!mounted) return;
      setState(() {
        _potreroSeleccionado = actualizado;
        _potreros = [
          for (final p in _potreros) p.id == actualizado.id ? actualizado : p
        ];
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _guardando.remove(usuario.id));
    }
  }

  Future<void> _quitar(int usuarioId) async {
    setState(() {
      _guardando.add(usuarioId);
      _error = null;
    });
    try {
      final actualizado = await widget.repository
          .quitarEncargadoPotrero(_potreroSeleccionado!.id, usuarioId);
      if (!mounted) return;
      setState(() {
        _potreroSeleccionado = actualizado;
        _potreros = [
          for (final p in _potreros) p.id == actualizado.id ? actualizado : p
        ];
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } on NetworkException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _guardando.remove(usuarioId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Asignar Personal — Potrero')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<Potrero>(
                  value: _potreroSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Potrero',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: _potreros
                      .map((p) =>
                          DropdownMenuItem(value: p, child: Text(p.nombre)))
                      .toList(),
                  onChanged: (p) => setState(() => _potreroSeleccionado = p),
                ),
                const SizedBox(height: 16),
                if (_potreroSeleccionado != null) ...[
                  Row(
                    children: [
                      Text('Encargados actuales',
                          style: textTheme.headlineSmall),
                      const SizedBox(width: 8),
                      EtiquetaPill(
                        texto: '${_potreroSeleccionado!.encargados.length}',
                        color:
                            AppTheme.secondaryContainer.withValues(alpha: 0.5),
                        colorTexto: AppTheme.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_potreroSeleccionado!.encargados.isEmpty)
                    Text('Sin encargados asignados',
                        style: textTheme.bodyMedium)
                  else
                    ..._potreroSeleccionado!.encargados.map((pe) {
                      final guardandoEste = _guardando.contains(pe.usuario.id);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
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
                                    Text(pe.usuario.nombreUsuario,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text(pe.usuario.correoElectronico,
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Colors.black54)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              BotonIcono(
                                icono: Icons.close,
                                cargando: guardandoEste,
                                onTap: () => _quitar(pe.usuario.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                  Text('Agregar encargado', style: textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  if (_errorUsuarios != null)
                    Text(_errorUsuarios!,
                        style: const TextStyle(color: Colors.red))
                  else if (_usuarios.where((u) => !_esEncargado(u)).isEmpty)
                    Text('No hay más usuarios disponibles para agregar',
                        style: textTheme.bodyMedium)
                  else
                    ..._usuarios.where((u) => !_esEncargado(u)).map((u) {
                      final guardandoEste = _guardando.contains(u.id);
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
                                  color: AppTheme.surfaceContainerHigh,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_outline,
                                    color: AppTheme.onSurfaceVariant, size: 18),
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
                              BotonPill(
                                texto: 'Agregar',
                                color: AppTheme.secondaryContainer,
                                colorTexto: AppTheme.onSecondaryContainer,
                                cargando: guardandoEste,
                                onTap: () => _agregar(u),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                        'Elige un Potrero para ver/cambiar sus encargados',
                        style: textTheme.bodyMedium),
                  ),
              ],
            ),
    );
  }
}
