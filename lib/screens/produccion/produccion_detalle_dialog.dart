import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/produccion/produccion_huevos.dart';
import '../../models/produccion/produccion_leche.dart';
import '../../theme/app_theme.dart';

/// Diálogo de "ver detalles" de un registro de producción (punto 3 del
/// reporte de pruebas, 2026-10-02): muestra el resumen del registro y
/// quién lo hizo (`creado_por`), y si fue eliminado, cuándo y por quién.
/// Es de solo lectura — para editar se sigue usando el formulario normal
/// (tocar la fila en la lista).
void mostrarDetalleLeche(BuildContext context, ProduccionLeche r) {
  final origen = r.esPorLote
      ? (r.loteNombre ?? 'Lote #${r.loteId}')
      : (r.animal?.nombreVisible ?? 'Animal #${r.animalId}');
  _mostrarDetalle(
    context,
    icono: Icons.water_drop,
    titulo: '${r.litros} L de leche',
    filas: [
      _FilaDetalle('Modalidad', r.esPorLote ? 'Por lote' : 'Por animal'),
      _FilaDetalle(r.esPorLote ? 'Lote' : 'Animal', origen),
      _FilaDetalle('Turno', r.jornada ?? 'Sin jornada'),
      if (r.observaciones != null && r.observaciones!.isNotEmpty)
        _FilaDetalle('Observaciones', r.observaciones!),
    ],
    registradoEn: r.registradoEn,
    creadoPorNombre: r.creadoPorNombre,
    eliminadoEn: r.eliminadoEn,
    eliminadoPorNombre: r.eliminadoPorNombre,
  );
}

void mostrarDetalleHuevos(BuildContext context, ProduccionHuevos r) {
  final origen = r.esPorLote
      ? (r.loteNombre ?? 'Lote #${r.loteId}')
      : (r.animalId != null
          ? (r.animal?.nombreVisible ?? 'Animal #${r.animalId}')
          : 'Sin lote ni animal');
  _mostrarDetalle(
    context,
    icono: Icons.egg,
    titulo: r.cantidadRotos > 0
        ? '${r.cantidad} huevos (${r.cantidadRotos} rotos)'
        : '${r.cantidad} huevos',
    filas: [
      _FilaDetalle('Modalidad', r.esPorLote ? 'Por lote' : 'Por animal'),
      _FilaDetalle(r.esPorLote ? 'Lote' : 'Origen', origen),
      _FilaDetalle('Turno', r.jornada ?? 'Sin jornada'),
      _FilaDetalle('Buenos', '${r.cantidadBuenos}'),
      if (r.cantidadRotos > 0) _FilaDetalle('Rotos', '${r.cantidadRotos}'),
      if (r.observaciones != null && r.observaciones!.isNotEmpty)
        _FilaDetalle('Observaciones', r.observaciones!),
    ],
    registradoEn: r.registradoEn,
    creadoPorNombre: r.creadoPorNombre,
    eliminadoEn: r.eliminadoEn,
    eliminadoPorNombre: r.eliminadoPorNombre,
  );
}

class _FilaDetalle {
  final String etiqueta;
  final String valor;
  _FilaDetalle(this.etiqueta, this.valor);
}

void _mostrarDetalle(
  BuildContext context, {
  required IconData icono,
  required String titulo,
  required List<_FilaDetalle> filas,
  required DateTime registradoEn,
  String? creadoPorNombre,
  DateTime? eliminadoEn,
  String? eliminadoPorNombre,
}) {
  final formatoFecha = DateFormat('yyyy-MM-dd HH:mm');
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(icono, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(titulo, style: const TextStyle(fontSize: 17))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilaDetalleWidget(
                etiqueta: 'Fecha de registro',
                valor: formatoFecha.format(registradoEn.toLocal())),
            ...filas.map((f) =>
                _FilaDetalleWidget(etiqueta: f.etiqueta, valor: f.valor)),
            const Divider(height: 24),
            _FilaDetalleWidget(
              etiqueta: 'Registrado por',
              valor: creadoPorNombre ?? 'No disponible',
            ),
            if (eliminadoEn != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.delete_forever,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Registro eliminado',
                          style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Fecha: ${formatoFecha.format(eliminadoEn.toLocal())}'),
                    Text(
                        'Responsable: ${eliminadoPorNombre ?? 'No disponible'}'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar')),
      ],
    ),
  );
}

class _FilaDetalleWidget extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _FilaDetalleWidget({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(etiqueta,
                style: TextStyle(color: AppTheme.outline, fontSize: 13)),
          ),
          Expanded(
            child: Text(valor,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
