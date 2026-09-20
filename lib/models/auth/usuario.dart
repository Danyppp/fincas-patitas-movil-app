import 'dart:convert';

/// Usuario autenticado, tal como lo devuelve el backend real en
/// `login`/`register` (`auth.service.ts -> toPublicUser`).
///
/// Mapeo de roles confirmado directamente en la tabla `roles` de Neon y en
/// `auth.service.ts` (`const ROL_EMPLEADO_ID = 3`): rol_id=1 Administrador,
/// rol_id=2 Encargado, rol_id=3 Empleado. La duda anterior (el código viejo
/// asignaba rol_id=2 a "Empleado") ya quedó resuelta — ver
/// `docs/AUTH_CONTRACT.md`. Este dato solo se usa para mostrarlo en
/// pantalla; no se usa para lógica de permisos dentro de la app todavía.
class Usuario {
  final int id;
  final String nombreUsuario;
  final String correoElectronico;
  final String? telefono;
  final int rolId;

  const Usuario({
    required this.id,
    required this.nombreUsuario,
    required this.correoElectronico,
    required this.rolId,
    this.telefono,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'] as int,
      nombreUsuario: json['nombre_usuario'] as String,
      correoElectronico: json['correo_electronico'] as String,
      telefono: json['telefono'] as String?,
      rolId: json['rol_id'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre_usuario': nombreUsuario,
        'correo_electronico': correoElectronico,
        'telefono': telefono,
        'rol_id': rolId,
      };

  String toJsonString() => jsonEncode(toJson());

  factory Usuario.fromJsonString(String source) =>
      Usuario.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// Nombre legible del rol, mostrado en la UI (perfil / app bar).
  String get rolNombre {
    switch (rolId) {
      case 1:
        return 'Administrador';
      case 2:
        return 'Encargado';
      case 3:
        return 'Empleado';
      default:
        return 'Rol $rolId';
    }
  }
}
