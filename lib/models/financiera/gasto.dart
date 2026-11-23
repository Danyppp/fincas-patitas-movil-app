import '../../utils/fecha_dia.dart';

/// Medios de pago válidos de un gasto (validados también por el backend en
/// `gasto.service.ts`: cualquier otro valor responde 400). Decisión de
/// Dany (2026-11-19): por ahora solo estos dos y solo en gastos.
const metodosPagoValidos = ['Efectivo', 'Transferencia'];

/// Modelo de la tabla real `gastos` (`/api/gastos`).
///
/// - `monto` es Decimal en Prisma: el backend lo serializa como STRING
///   (ej. `"10000"`), por eso se convierte con `_parseDouble`.
/// - `fecha` es una fecha de calendario (columna `DATE`): se lee con
///   [FechaDia] para que no se corra un día por la zona horaria.
/// - `metodoPago` es opcional: los gastos anteriores a la Etapa 0 de
///   Financiera (2026-11-19) no lo tienen.
class Gasto {
  final int id;
  final String categoria;
  final String? descripcion;
  final double monto;
  final DateTime fecha;
  final String? metodoPago;

  const Gasto({
    required this.id,
    required this.categoria,
    required this.monto,
    required this.fecha,
    this.descripcion,
    this.metodoPago,
  });

  factory Gasto.fromJson(Map<String, dynamic> json) {
    return Gasto(
      id: json['id'] as int,
      categoria: json['categoria'] as String,
      descripcion: json['descripcion'] as String?,
      monto: _parseDouble(json['monto']) ?? 0,
      fecha: FechaDia.parseRequerida(json['fecha']),
      metodoPago: json['metodo_pago'] as String?,
    );
  }

  static double? _parseDouble(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor);
    return null;
  }
}

/// DTO para `POST /api/gastos`. Obligatorios: categoría, monto (> 0) y
/// fecha. El backend rechaza con 400 un `metodo_pago` fuera de
/// [metodosPagoValidos].
class CrearGastoDTO {
  final String categoria;
  final String? descripcion;
  final double monto;
  final DateTime fecha;
  final String? metodoPago;

  const CrearGastoDTO({
    required this.categoria,
    required this.monto,
    required this.fecha,
    this.descripcion,
    this.metodoPago,
  });

  Map<String, dynamic> toJson() => {
        'categoria': categoria,
        if (descripcion != null && descripcion!.trim().isNotEmpty)
          'descripcion': descripcion!.trim(),
        'monto': monto,
        'fecha': FechaDia.formatear(fecha),
        if (metodoPago != null) 'metodo_pago': metodoPago,
      };
}

/// DTO para `PUT /api/gastos/:id`. Solo se envía lo que no es nulo.
/// Nota (aprobado por Dany, 2026-11-20): una vez puesto, el medio de pago
/// no se puede borrar desde la app, solo cambiar a otro válido.
class ActualizarGastoDTO {
  final String? categoria;
  final String? descripcion;
  final double? monto;
  final DateTime? fecha;
  final String? metodoPago;

  const ActualizarGastoDTO({
    this.categoria,
    this.descripcion,
    this.monto,
    this.fecha,
    this.metodoPago,
  });

  Map<String, dynamic> toJson() => {
        if (categoria != null) 'categoria': categoria,
        if (descripcion != null) 'descripcion': descripcion!.trim(),
        if (monto != null) 'monto': monto,
        if (fecha != null) 'fecha': FechaDia.formatear(fecha!),
        if (metodoPago != null) 'metodo_pago': metodoPago,
      };
}
