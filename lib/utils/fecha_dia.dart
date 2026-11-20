/// Ayudas para las fechas de CALENDARIO de Financiera: las que no tienen
/// hora (`gastos.fecha`, `ventas.fecha`, `fecha_pago`, `fecha_limite_pago`,
/// `precios_mercado.fecha`, `balance.periodo`, `fecha_inicio`, `fecha_fin`).
///
/// Por qué existe: el backend guarda estas columnas como `DATE` y las
/// devuelve como medianoche UTC (ej. `"2026-09-10T00:00:00.000Z"`). Si se
/// parsea con `DateTime.parse(...)` y luego `.toLocal()`, en Colombia
/// (UTC-5) queda el 9 de septiembre a las 19:00 -- es decir, el DÍA
/// ANTERIOR. Producción no tiene este problema porque `registrado_en` es
/// un instante real con hora; estas fechas son otro caso.
///
/// Regla: de la respuesta del backend solo se toma `AAAA-MM-DD` y se arma
/// un `DateTime` local a medianoche; al enviar, se manda `"AAAA-MM-DD"` sin
/// hora ni zona, y nunca `.toUtc()`.
class FechaDia {
  FechaDia._();

  static final RegExp _patron = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

  /// Lee `AAAA-MM-DD` (con o sin hora detrás) y devuelve esa fecha como
  /// `DateTime` local a medianoche. Devuelve `null` si [valor] es `null` o
  /// no tiene ese formato.
  static DateTime? parse(dynamic valor) {
    if (valor is! String) return null;
    final m = _patron.firstMatch(valor);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
  }

  /// Igual que [parse], pero para campos que el backend siempre manda:
  /// si falta o no es una fecha válida, lanza [FormatException].
  static DateTime parseRequerida(dynamic valor) {
    final fecha = parse(valor);
    if (fecha == null) {
      throw FormatException('Fecha de calendario no válida: $valor');
    }
    return fecha;
  }

  /// Fecha lista para enviar al backend: `"AAAA-MM-DD"`, sin hora ni zona
  /// horaria. Toma año, mes y día tal como están en [fecha] (sin convertir
  /// a UTC).
  static String formatear(DateTime fecha) {
    final a = fecha.year.toString().padLeft(4, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    final d = fecha.day.toString().padLeft(2, '0');
    return '$a-$m-$d';
  }

  /// Quita la hora de [fecha]: devuelve ese mismo día a medianoche local.
  static DateTime soloDia(DateTime fecha) =>
      DateTime(fecha.year, fecha.month, fecha.day);

  /// El día de hoy según el reloj del teléfono (día local, sin hora).
  static DateTime hoy() => soloDia(DateTime.now());

  /// Suma (o resta, con negativos) días de calendario. Se arma con
  /// `DateTime(año, mes, día + n)` en vez de sumar `Duration`, para no
  /// depender de cambios de hora.
  static DateTime sumarDias(DateTime fecha, int dias) =>
      DateTime(fecha.year, fecha.month, fecha.day + dias);
}
