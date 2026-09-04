import 'package:flutter/material.dart';

import '../../models/reproduccion/reproductive_event.dart';
import '../../repositories/reproduction_repository.dart';
import '../../widgets/reproduction_event_card.dart';

/// Pantalla principal del módulo de Reproducción: lista los eventos
/// reproductivos (montas e inseminaciones) registrados. Mismo patrón
/// que [AnimalesListScreen]: recibe el repositorio por constructor, no
/// le importa si es [MockReproductionRepository] o
/// [ApiReproductionRepository].
class ReproduccionListScreen extends StatefulWidget {
  final ReproductionRepository repository;

  const ReproduccionListScreen({super.key, required this.repository});

  @override
  State<ReproduccionListScreen> createState() => _ReproduccionListScreenState();
}

class _ReproduccionListScreenState extends State<ReproduccionListScreen> {
  late Future<List<ReproductiveEvent>> _futureEventos;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _futureEventos = widget.repository.getAll();
  }

  Future<void> _refrescar() async {
    setState(_cargar);
    await _futureEventos;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reproducción')),
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: FutureBuilder<List<ReproductiveEvent>>(
          future: _futureEventos,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _ErrorState(
                mensaje: 'No se pudo cargar la lista de eventos reproductivos.',
                detalle: snapshot.error.toString(),
                onReintentar: _refrescar,
              );
            }
            final eventos = snapshot.data ?? const [];
            if (eventos.isEmpty) {
              return const _EmptyState();
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: eventos.length,
              itemBuilder: (context, index) => ReproductionEventCard(evento: eventos[index]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registrar evento reproductivo — próximo paso del módulo')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nuevo evento'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.favorite_outline, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('Todavía no hay eventos reproductivos registrados.'),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String mensaje;
  final String detalle;
  final VoidCallback onReintentar;

  const _ErrorState({
    required this.mensaje,
    required this.detalle,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
