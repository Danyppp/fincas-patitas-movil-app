import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/auth/usuario.dart';
import '../../models/catalogo/potrero.dart';
import '../../repositories/ubicacion/ubicacion_repository.dart';
import '../../repositories/usuarios/usuario_repository.dart';
import '../../widgets/boton_pill.dart';

/// Asignar Personal — Potrero: selección MÚLTIPLE de encargados por
/// Potrero, vía `POST`/`DELETE /ubicaciones-potreros/{id}/encargados[/{usuarioId}]`
/// (ver decisiones-diseno-vs-backend-ubicacion.md, sección 8).
///
/// Se excluye de la lista de candidatos al rol Administrador (rol_id=1),
/// igual que en "Asignar Personal — Lote".
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
                    border: OutlineInputBorder(),
                  ),
                  items: _potreros
                      .map((p) =>
                          DropdownMenuItem(value: p, child: Text(p.nombre)))
                      .toList(),
                  onChanged: (p) => setState(() => _potreroSeleccionado = p),
                ),
                const SizedBox(height: 16),
                if (_potreroSeleccionado != null) ...[
                  Text(
                      'Encargados actuales (${_potreroSeleccionado!.encargados.length})',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_potreroSeleccionado!.encargados.isEmpty)
                    const Text('Sin encargados asignados',
                        style: TextStyle(color: Colors.black54))
                  else
                    // 2026-11-05: Row en vez de ListTile -- ver nota en
                    // asignar_animales_screen.dart.
                    ..._potreroSeleccionado!.encargados.map((pe) {
                      final guardandoEste = _guardando.contains(pe.usuario.id);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(pe.usuario.nombreUsuario,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
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
                  Text('Agregar encargado',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_errorUsuarios != null)
                    Text(_errorUsuarios!,
                        style: const TextStyle(color: Colors.red))
                  else if (_usuarios.where((u) => !_esEncargado(u)).isEmpty)
                    const Text('No hay más usuarios disponibles para agregar',
                        style: TextStyle(color: Colors.black54))
                  else
                    // 2026-11-05: Row en vez de ListTile -- ver nota en
                    // asignar_animales_screen.dart.
                    ..._usuarios.where((u) => !_esEncargado(u)).map((u) {
                      final guardandoEste = _guardando.contains(u.id);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.person_outline),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(u.nombreUsuario,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
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
                                cargando: guardandoEste,
                                onTap: () => _agregar(u),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ] else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                        'Elige un Potrero para ver/cambiar sus encargados',
                        style: TextStyle(color: Colors.black54)),
                  ),
              ],
            ),
    );
  }
}
