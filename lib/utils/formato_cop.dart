import 'package:intl/intl.dart';

/// Formatos de dinero y cantidades del módulo Financiera.
///
/// Los montos van en pesos colombianos, sin decimales y con punto como
/// separador de miles (ej. `$1.850.000`), igual que en los diseños.
class FormatoCOP {
  FormatoCOP._();

  static final NumberFormat _enteros = NumberFormat.decimalPattern('es');
  static final NumberFormat _cantidades = NumberFormat('#,##0.##', 'es');

  /// `1850000` -> `$1.850.000`; `-610000` -> `-$610.000`.
  static String pesos(double valor) {
    final redondeado = valor.round();
    final texto = _enteros.format(redondeado.abs());
    return redondeado < 0 ? '-\$$texto' : '\$$texto';
  }

  /// Cantidad sin ceros sobrantes: `20` -> `20`; `12.5` -> `12,5`.
  static String cantidad(double valor) => _cantidades.format(valor);

  /// Unidad con la que se mide un producto: litros para la leche y
  /// unidades para los huevos. Cualquier otro producto no tiene unidad.
  static String unidadDeProducto(String producto) {
    final p = producto.toLowerCase();
    if (p.contains('leche')) return 'L';
    if (p.contains('huevo')) return 'unid.';
    return '';
  }
}
