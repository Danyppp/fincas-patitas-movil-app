import '../../utils/fecha_dia.dart';

/// Estados de pago válidos de una venta (validados también por el backend
/// en `venta.service.ts`).
const estadoPagado = 'Pagado';
const estadoPendiente = 'Pendiente';
const estadosPagoValidos = [estadoPagado, estadoPendiente];

/// Modelo de la tabla real `ventas` (`/api/ventas`).
///
/// - `cantidad`, `precio_unitario` y `total` son Decimal en Prisma: llegan
///   como STRING en el JSON, por eso se convierten con `_parseDouble`.
/// - `total` lo calcula SIEMPRE el servidor (cantidad × precio unitario,
///   redondeado a 2 decimales): el cliente nunca lo envía.
/// - `fecha`, `fechaPago` y `fechaLimitePago` son fechas de calendario
///   (columnas `DATE`): se leen con [FechaDia] para evitar el corrimiento
///   de día.
/// - Regla de negocio (Etapa 0, 2026-11-19): una venta `Pagado` tiene
///   `fechaPago`; una `Pendiente` no, y puede tener `fechaLimitePago`.
///   El balance solo suma ventas pagadas, por fecha de pago.
class Venta {
  final int id;
  final String producto;
  final double cantidad;
  final double precioUnitario;
  final double total;
  final String? comprador;
  final DateTime fecha;
  final String estadoPago;
  final DateTime? fechaPago;
  final DateTime? fechaLimitePago;

  const Venta({
    required this.id,
    required this.producto,
    required this.cantidad,
    required this.precioUnitario,
    required this.total,
    required this.fecha,
    this.comprador,
    this.estadoPago = estadoPagado,
    this.fechaPago,
    this.fechaLimitePago,
  });

  bool get estaPagada => estadoPago == estadoPagado;
  bool get estaPendiente => estadoPago == estadoPendiente;

  /// "Vencida" se deduce, no se guarda: es una venta pendiente cuya fecha
  /// límite ya pasó (hoy es posterior a la fecha límite). Una venta sin
  /// fecha límite nunca está vencida. [hoy] solo se pasa en pruebas; por
  /// defecto se usa el día local actual.
  bool estaVencida({DateTime? hoy}) {
    final limite = fechaLimitePago;
    if (!estaPendiente || limite == null) return false;
    return FechaDia.soloDia(hoy ?? FechaDia.hoy()).isAfter(limite);
  }

  factory Venta.fromJson(Map<String, dynamic> json) {
    return Venta(
      id: json['id'] as int,
      producto: json['producto'] as String,
      cantidad: _parseDouble(json['cantidad']) ?? 0,
      precioUnitario: _parseDouble(json['precio_unitario']) ?? 0,
      total: _parseDouble(json['total']) ?? 0,
      comprador: json['comprador'] as String?,
      fecha: FechaDia.parseRequerida(json['fecha']),
      // Si por algún motivo no viene, se asume el valor por defecto del
      // backend (las ventas existentes quedaron `Pagado`).
      estadoPago: json['estado_pago'] as String? ?? estadoPagado,
      fechaPago: FechaDia.parse(json['fecha_pago']),
      fechaLimitePago: FechaDia.parse(json['fecha_limite_pago']),
    );
  }

  static double? _parseDouble(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor);
    return null;
  }
}

/// DTO para `POST /api/ventas`. NO incluye `total` (lo calcula el servidor).
///
/// - Si [estadoPago] es null, el backend asume `Pagado` y usa la fecha de
///   la venta como fecha de pago.
/// - Una venta `Pendiente` no admite [fechaPago] (el backend responde
///   400); [fechaLimitePago] es opcional y no puede ser anterior a
///   [fecha].
class CrearVentaDTO {
  final String producto;
  final double cantidad;
  final double precioUnitario;
  final String? comprador;
  final DateTime fecha;
  final String? estadoPago;
  final DateTime? fechaPago;
  final DateTime? fechaLimitePago;

  const CrearVentaDTO({
    required this.producto,
    required this.cantidad,
    required this.precioUnitario,
    required this.fecha,
    this.comprador,
    this.estadoPago,
    this.fechaPago,
    this.fechaLimitePago,
  });

  Map<String, dynamic> toJson() => {
        'producto': producto,
        'cantidad': cantidad,
        'precio_unitario': precioUnitario,
        if (comprador != null && comprador!.trim().isNotEmpty)
          'comprador': comprador!.trim(),
        'fecha': FechaDia.formatear(fecha),
        if (estadoPago != null) 'estado_pago': estadoPago,
        if (fechaPago != null) 'fecha_pago': FechaDia.formatear(fechaPago!),
        if (fechaLimitePago != null)
          'fecha_limite_pago': FechaDia.formatear(fechaLimitePago!),
      };
}

/// DTO para `PUT /api/ventas/:id`. Solo se envía lo que no es nulo; el
/// servidor recalcula `total` con la cantidad y el precio resultantes.
///
/// Para "Marcar como pagada" se envía `estadoPago: estadoPagado` junto con
/// `fechaPago` (la de hoy local): el backend registra esa fecha y borra la
/// fecha límite. Siempre se manda `fechaPago` explícita porque, si no, el
/// servidor usaría su propia fecha UTC, que de noche en Colombia puede ser
/// ya el día siguiente.
class ActualizarVentaDTO {
  final String? producto;
  final double? cantidad;
  final double? precioUnitario;
  final String? comprador;
  final DateTime? fecha;
  final String? estadoPago;
  final DateTime? fechaPago;
  final DateTime? fechaLimitePago;

  const ActualizarVentaDTO({
    this.producto,
    this.cantidad,
    this.precioUnitario,
    this.comprador,
    this.fecha,
    this.estadoPago,
    this.fechaPago,
    this.fechaLimitePago,
  });

  Map<String, dynamic> toJson() => {
        if (producto != null) 'producto': producto,
        if (cantidad != null) 'cantidad': cantidad,
        if (precioUnitario != null) 'precio_unitario': precioUnitario,
        if (comprador != null) 'comprador': comprador!.trim(),
        if (fecha != null) 'fecha': FechaDia.formatear(fecha!),
        if (estadoPago != null) 'estado_pago': estadoPago,
        if (fechaPago != null) 'fecha_pago': FechaDia.formatear(fechaPago!),
        if (fechaLimitePago != null)
          'fecha_limite_pago': FechaDia.formatear(fechaLimitePago!),
      };
}
