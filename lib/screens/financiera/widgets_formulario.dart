import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Piezas visuales compartidas por los formularios del módulo Financiera
/// (gasto, venta y precio), según los diseños de Stitch. No tienen lógica:
/// solo dan el mismo estilo a las tres pantallas.

/// Tarjeta blanca redondeada que agrupa los campos del formulario.
class FormTarjeta extends StatelessWidget {
  final List<Widget> children;

  const FormTarjeta({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppTheme.onSurface.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Título de un campo: icono verde + texto, y una etiqueta a la derecha
/// ("Requerido", "Opcional", "Bloqueado"...).
class FormTitulo extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String? etiqueta;
  final bool etiquetaDestacada;

  const FormTitulo({
    super.key,
    required this.icono,
    required this.texto,
    this.etiqueta,
    this.etiquetaDestacada = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icono, size: 19, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          if (etiqueta != null)
            Text(etiqueta!,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: etiquetaDestacada
                        ? AppTheme.primary
                        : AppTheme.outline)),
        ],
      ),
    );
  }
}

/// Opción tipo píldora (producto, categoría, medio de pago, estado...).
class FormChip extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final bool seleccionado;
  final VoidCallback onTap;

  const FormChip({
    super.key,
    required this.texto,
    required this.seleccionado,
    required this.onTap,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    final color = seleccionado ? AppTheme.onPrimary : AppTheme.onSurface;
    return Material(
      color: seleccionado
          ? AppTheme.primaryContainer
          : AppTheme.surfaceContainerColor,
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[
                Icon(icono, size: 18, color: color),
                const SizedBox(width: 6),
              ],
              Text(texto,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo que se toca para elegir (por ejemplo una fecha): muestra el valor
/// con su icono y un icono de acción a la derecha.
class FormSelector extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String? etiquetaSuperior;
  final IconData iconoDerecho;
  final VoidCallback onTap;

  const FormSelector({
    super.key,
    required this.icono,
    required this.texto,
    required this.onTap,
    this.etiquetaSuperior,
    this.iconoDerecho = Icons.edit_calendar_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusDefault),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, size: 19, color: AppTheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (etiquetaSuperior != null)
                      Text(etiquetaSuperior!.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppTheme.outline)),
                    Text(texto,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(iconoDerecho, size: 20, color: AppTheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Texto pequeño de ayuda bajo un campo.
class FormAyuda extends StatelessWidget {
  final String texto;

  const FormAyuda(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, top: 6),
      child: Text(texto,
          style: const TextStyle(fontSize: 12, color: AppTheme.outline)),
    );
  }
}

/// Botones del final: guardar (verde, en píldora) y cancelar.
class FormBotones extends StatelessWidget {
  final String textoGuardar;
  final bool guardando;
  final VoidCallback onGuardar;
  final VoidCallback onCancelar;

  const FormBotones({
    super.key,
    required this.textoGuardar,
    required this.guardando,
    required this.onGuardar,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: guardando ? null : onGuardar,
            icon: guardando
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(textoGuardar),
          ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: guardando ? null : onCancelar,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Cancelar'),
          style: TextButton.styleFrom(foregroundColor: AppTheme.onSurface),
        ),
      ],
    );
  }
}
