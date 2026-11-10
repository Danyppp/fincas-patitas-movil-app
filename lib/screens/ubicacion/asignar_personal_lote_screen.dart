import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/auth/usuario.dart';
import '../../models/catalogo/lote_animal.dart';
import '../../repositories/ubicacion/ubicacion_repository.dart';
import '../../repositories/usuarios/usuario_repository.dart';
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
                    border: OutlineInputBorder(),
                  ),
                  items: _lotes
                      .map((l) =>
                          DropdownMenuItem(value: l, child: Text(l.nombre)))
                      .toList(),
                  onChanged: (l) => setState(() => _loteSeleccionado = l),
                ),
                const SizedBox(height: 16),
                if (_loteSeleccionado != null) ...[
                  // 2026-11-05: Row en vez de ListTile -- ver nota en
                  // asignar_animales_screen.dart (un botón como trailing de
                  // ListTile puede disparar "BoxConstraints forces an
                  // infinite width" y dejar la fila invisible).
                  Card(
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
                                Text(
                                    _loteSeleccionado!
                                            .encargado?.nombreUsuario ??
                                        'Sin encargado',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                    _loteSeleccionado!
                                            .encargado?.correoElectronico ??
                                        '—',
                                    style: const TextStyle(
                                        fontSize: 12.5, color: Colors.black54)),
                              ],
                            ),
                          ),
                          if (_loteSeleccionado!.encargado != null) ...[
                            const SizedBox(width: 10),
                            BotonTexto(
                              texto: 'Quitar',
                              onTap: _guardando ? null : _quitarEncargado,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Elegir encargado',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_errorUsuarios != null)
                    Text(_errorUsuarios!,
                        style: const TextStyle(color: Colors.red))
                  else if (_usuarios.isEmpty)
                    const Text('No hay usuarios disponibles',
                        style: TextStyle(color: Colors.black54))
                  else
                    ..._usuarios.map((u) {
                      final yaEsEncargado =
                          _loteSeleccionado!.encargado?.id == u.id;
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
                              yaEsEncargado
                                  ? const EtiquetaPill(
                                      texto: 'Encargado actual')
                                  : BotonPill(
                                      texto: 'Asignar',
                                      onTap:
                                          _guardando ? null : () => _asignar(u),
                                    ),
                            ],
                          ),
                        ),
                      );
                    }),
                ] else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Elige un Lote para ver/cambiar su encargado',
                        style: TextStyle(color: Colors.black54)),
                  ),
              ],
            ),
    );
  }
}
