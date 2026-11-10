import 'package:flutter/material.dart';

/// Botón sólido "a la medida" (NO usa FilledButton/ElevatedButton/TextButton
/// ni Chip). Esos widgets heredan de `ButtonStyleButton`/`RawChip`, que
/// tienen un bug de layout conocido en esta versión de Flutter:
/// "BoxConstraints forces an infinite width" cuando quedan dentro de un
/// `Card` (su `Material` interno calcula intrínsecos para la sombra y ese
/// cálculo choca con `button_style_button.dart`). Se confirmó en pruebas
/// reales (2026-11-10): el mismo crash salía con el botón dentro de un
/// `ListTile`, dentro de un `FittedBox`, y dentro de un `Row` simple --
/// siempre fallaba en `button_style_button.dart [_computeSize]`. Por eso en
/// las pantallas de "Asignar" (Animales/Personal) se usan estos widgets de
/// reemplazo (`Material` + `InkWell` + `Padding` + `Text`) en vez de los de
/// Flutter Material, que no pertenecen a esa familia y no tienen el bug.
class BotonPill extends StatelessWidget {
  final String texto;
  final VoidCallback? onTap;
  final bool cargando;
  final Color? color;
  final Color? colorTexto;

  const BotonPill({
    super.key,
    required this.texto,
    required this.onTap,
    this.cargando = false,
    this.color,
    this.colorTexto,
  });

  @override
  Widget build(BuildContext context) {
    final habilitado = onTap != null && !cargando;
    final fondo = color ?? Theme.of(context).colorScheme.primary;
    return Material(
      color: habilitado ? fondo : fondo.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: habilitado ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: cargando
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colorTexto ?? Colors.white),
                )
              : Text(
                  texto,
                  style: TextStyle(
                    color: colorTexto ?? Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Botón "de texto" (reemplazo de TextButton) -- mismo motivo que [BotonPill].
class BotonTexto extends StatelessWidget {
  final String texto;
  final VoidCallback? onTap;

  const BotonTexto({super.key, required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final habilitado = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            texto,
            style: TextStyle(
              color: habilitado
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón "de ícono" (reemplazo de IconButton) -- mismo motivo que
/// [BotonPill]. Aunque IconButton no venía fallando en los logs, se unifica
/// para no dejar ningún ButtonStyleButton cerca de estas tarjetas.
class BotonIcono extends StatelessWidget {
  final IconData icono;
  final VoidCallback? onTap;
  final bool cargando;

  const BotonIcono({
    super.key,
    required this.icono,
    required this.onTap,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: cargando ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: cargando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icono, size: 22),
        ),
      ),
    );
  }
}

/// Etiqueta de solo lectura (reemplazo de Chip) -- mismo motivo que
/// [BotonPill].
class EtiquetaPill extends StatelessWidget {
  final String texto;

  const EtiquetaPill({super.key, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEBE9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
