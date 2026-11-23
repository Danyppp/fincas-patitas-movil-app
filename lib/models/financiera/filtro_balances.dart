import '../../utils/fecha_dia.dart';
import 'balance.dart';

/// Búsqueda por fechas y paginación de la lista "Balances generados".
///
/// - Un balance entra en la búsqueda si su rango (fecha inicio – fecha fin) se
///   CRUZA con el rango buscado. Los balances sin rango (solo periodo) se
///   comparan como si su rango fuera ese único día.
/// - Desde y Hasta son opcionales; con uno solo, el filtro es abierto del
///   otro lado.
class FiltroBalances {
  /// Balances que se muestran por página.
  static const int porPagina = 5;

  static List<Balance> filtrar(
    List<Balance> balances, {
    DateTime? desde,
    DateTime? hasta,
  }) {
    final d = desde == null ? null : FechaDia.soloDia(desde);
    final h = hasta == null ? null : FechaDia.soloDia(hasta);
    if (d == null && h == null) return List.of(balances);

    return balances.where((b) {
      final inicio = FechaDia.soloDia(b.fechaInicio ?? b.periodo);
      final fin = FechaDia.soloDia(b.fechaFin ?? b.fechaInicio ?? b.periodo);
      if (d != null && fin.isBefore(d)) return false;
      if (h != null && inicio.isAfter(h)) return false;
      return true;
    }).toList();
  }

  /// Número de páginas (mínimo 1, aunque no haya balances).
  static int totalPaginas(int cantidad) {
    if (cantidad <= 0) return 1;
    return (cantidad + porPagina - 1) ~/ porPagina;
  }

  /// Balances de la [pagina] (empieza en 0). Si la página se pasa del final,
  /// se usa la última.
  static List<Balance> pagina(List<Balance> balances, int pagina) {
    final ultima = totalPaginas(balances.length) - 1;
    final p = pagina.clamp(0, ultima);
    final desde = p * porPagina;
    final hasta = (desde + porPagina).clamp(0, balances.length);
    return balances.sublist(desde, hasta);
  }
}
