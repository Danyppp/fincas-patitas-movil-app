import 'package:flutter/material.dart';

/// Placeholder para módulos que no son prioridad de este sprint (Salud
/// Animal/Potreros, Inventario/Financiero). El backend ya los tiene
/// implementados; se conectan cuando el cronograma lo permita.
class ProximamenteScreen extends StatelessWidget {
  final String titulo;
  final IconData icono;

  const ProximamenteScreen({super.key, required this.titulo, required this.icono});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 64, color: Colors.black26),
            const SizedBox(height: 12),
            Text('$titulo — próximamente', style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
