import 'package:flutter/material.dart';

/// Pantalla de relleno para los módulos que todavía no se han construido
/// (Reproducción, Producción, Inventario). Existe para que la navegación
/// base quede completa desde ya — cada una se reemplaza por su pantalla
/// real cuando le llegue el turno en el cronograma.
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
            Icon(icono, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('$titulo — próximamente', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
