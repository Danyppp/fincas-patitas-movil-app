import '../produccion/produccion_huevos.dart';
import '../produccion/produccion_leche.dart';
import 'precio_mercado.dart';

/// Valor estimado de la producción de hoy (pantalla Balance).
///
/// Se calcula en el teléfono, igual que en la web (`MercadoBalance.tsx`):
/// - Litros de hoy: suma de los litros de los registros de leche de hoy que
///   no están eliminados.
/// - Huevos de hoy: suma de (cantidad - rotos, nunca menos de 0) de los
///   registros de huevos de hoy que no están eliminados. Los huevos rotos no
///   se cuentan como vendibles.
/// - "Hoy" es el día LOCAL del teléfono (no el día UTC del servidor).
/// - Precio de cada producto: el último registrado (coincidencia parcial
///   sin distinguir mayúsculas; desempate por fecha y luego por id).
///
/// Es solo una estimación: no genera ventas ni mueve stock.
class ValorEstimadoHoy {
  final double litrosHoy;
  final int huevosHoy;
  final PrecioMercado? precioLeche;
  final PrecioMercado? precioHuevos;

  const ValorEstimadoHoy({
    required this.litrosHoy,
    required this.huevosHoy,
    this.precioLeche,
    this.precioHuevos,
  });

  /// null si no hay precio de mercado de la leche.
  double? get valorLeche =>
      precioLeche == null ? null : litrosHoy * precioLeche!.precio;

  /// null si no hay precio de mercado de los huevos.
  double? get valorHuevos =>
      precioHuevos == null ? null : huevosHoy * precioHuevos!.precio;

  /// Suma de lo que tiene precio (un producto sin precio aporta 0).
  double get total => (valorLeche ?? 0) + (valorHuevos ?? 0);

  /// Último precio de los productos cuyo nombre contiene [palabra].
  static PrecioMercado? ultimoPrecio(
      List<PrecioMercado> precios, String palabra) {
    PrecioMercado? mejor;
    for (final p in precios) {
      if (!p.producto.toLowerCase().contains(palabra)) continue;
      if (mejor == null ||
          p.fecha.isAfter(mejor.fecha) ||
          (p.fecha == mejor.fecha && p.id > mejor.id)) {
        mejor = p;
      }
    }
    return mejor;
  }

  static bool _esHoy(DateTime momento, DateTime hoy) {
    final local = momento.toLocal();
    return local.year == hoy.year &&
        local.month == hoy.month &&
        local.day == hoy.day;
  }

  /// [hoy] solo se pasa en pruebas; por defecto es el día local actual.
  static ValorEstimadoHoy calcular({
    required List<ProduccionLeche> leche,
    required List<ProduccionHuevos> huevos,
    required List<PrecioMercado> precios,
    DateTime? hoy,
  }) {
    final dia = hoy ?? DateTime.now();

    var litros = 0.0;
    for (final r in leche) {
      if (r.eliminadoEn != null || !_esHoy(r.registradoEn, dia)) continue;
      litros += r.litros;
    }

    var vendibles = 0;
    for (final r in huevos) {
      if (r.eliminadoEn != null || !_esHoy(r.registradoEn, dia)) continue;
      final buenos = r.cantidad - r.cantidadRotos;
      vendibles += buenos > 0 ? buenos : 0;
    }

    return ValorEstimadoHoy(
      litrosHoy: litros,
      huevosHoy: vendibles,
      precioLeche: ultimoPrecio(precios, 'leche'),
      precioHuevos: ultimoPrecio(precios, 'huevo'),
    );
  }
}
