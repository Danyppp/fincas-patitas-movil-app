import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema visual de la app, extraído directamente del design system exportado
/// por Stitch (`stitch_fincas_y_patitas_ui_design/alegre_y_colorida_farm_management/DESIGN.md`)
/// y de las pantallas HTML de referencia (Iniciar sesión, Recuperar
/// contraseña, Registro).
///
/// Antes de esto, `main.dart` solo usaba `colorSchemeSeed` con un verde
/// genérico y dejaba que Material 3 generara toda la paleta y la
/// tipografía por defecto — por eso la app se veía con el look plano de
/// Flutter en vez del diseño real preparado en Stitch.
class AppTheme {
  AppTheme._();

  // Paleta exacta del token `colors` en DESIGN.md.
  static const Color primary = Color(0xFF006E1C);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer =
      Color(0xFF4CAF50); // verde vivo de marca (botones)
  static const Color onPrimaryContainer = Color(0xFF003C0B);

  static const Color secondary = Color(0xFF785900);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFDC003); // ámbar de marca
  static const Color onSecondaryContainer = Color(0xFF6C5000);

  static const Color tertiary = Color(0xFFAE2F34);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFFF6B6B); // coral de alerta
  static const Color onTertiaryContainer = Color(0xFF6D0010);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color surface = Color(0xFFFFF8F6); // fondo crema, no blanco puro
  static const Color onSurface = Color(0xFF2B1611); // texto espresso, no negro
  static const Color surfaceDim = Color(0xFFF9D1C8);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFFF0ED);
  static const Color surfaceContainerColor = Color(0xFFFFE9E4);
  static const Color surfaceContainerHigh = Color(0xFFFFE2DB);
  static const Color surfaceContainerHighest = Color(0xFFFFDAD2);
  static const Color onSurfaceVariant = Color(0xFF3F4A3C);
  static const Color outline = Color(0xFF6F7A6B);
  static const Color outlineVariant = Color(0xFFBECAB9);
  static const Color inverseSurface = Color(0xFF432A25);
  static const Color onInverseSurface = Color(0xFFFFEDE9);
  static const Color inversePrimary = Color(0xFF78DC77);

  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: tertiary,
    onTertiary: onTertiary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: onSurface,
    surfaceContainerLowest: surfaceContainerLowest,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainer: surfaceContainerColor,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
    inverseSurface: inverseSurface,
    onInverseSurface: onInverseSurface,
    inversePrimary: inversePrimary,
    surfaceTint: primary,
  );

  /// Radios de esquina del token `rounded` en DESIGN.md.
  static const double radiusSm = 8; // rounded-sm: 0.5rem
  static const double radiusDefault = 16; // rounded: 1rem
  static const double radiusMd = 24; // rounded-md: 1.5rem
  static const double radiusLg = 32; // rounded-lg: 2rem
  static const double radiusFull = 9999; // pill

  static TextTheme _textTheme(TextTheme base) {
    // Tamaños/pesos tomados 1:1 del token `typography` en DESIGN.md.
    final jakarta = GoogleFonts.plusJakartaSansTextTheme(base);
    return jakarta.copyWith(
      displayLarge: jakarta.displayLarge?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 34 / 28,
        letterSpacing: -0.28,
        color: onSurface,
      ),
      headlineLarge: jakarta.headlineLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 32 / 24,
        letterSpacing: -0.24,
        color: onSurface,
      ),
      headlineMedium: jakarta.headlineMedium?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 28 / 20,
        color: onSurface,
      ),
      headlineSmall: jakarta.headlineSmall?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 24 / 18,
        color: onSurface,
      ),
      bodyLarge: jakarta.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 24 / 16,
        color: onSurface,
      ),
      bodyMedium: jakarta.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: onSurfaceVariant,
      ),
      bodySmall: jakarta.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: outline,
      ),
      labelLarge: jakarta.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 18 / 14,
        color: onSurface,
      ),
      labelMedium: jakarta.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 0.24,
        color: onSurface,
      ),
      labelSmall: jakarta.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 14 / 11,
        letterSpacing: 0.44,
        color: outline,
      ),
    );
  }

  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    final textTheme = _textTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: surface,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        iconTheme: const IconThemeData(color: onSurface),
      ),

      // Tarjetas (rounded-2xl/rounded-3xl, sombra tibia difusa según DESIGN.md).
      cardTheme: CardThemeData(
        color: surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd)),
        shadowColor: onSurface.withValues(alpha: 0.12),
      ),

      // Botón principal: pill, verde vivo (#4CAF50), texto blanco, 52px alto.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: onPrimary,
          disabledBackgroundColor: primaryContainer.withValues(alpha: 0.4),
          disabledForegroundColor: onPrimary.withValues(alpha: 0.8),
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle:
              textTheme.labelLarge?.copyWith(color: onPrimary, fontSize: 16),
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle:
              textTheme.labelLarge?.copyWith(color: onPrimary, fontSize: 16),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: outlineVariant, width: 1.5),
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge?.copyWith(color: primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: textTheme.labelLarge?.copyWith(color: primary),
        ),
      ),

      // Inputs: fondo tintado suave, sin borde hasta el foco (verde de marca).
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: textTheme.labelMedium,
        hintStyle: textTheme.bodyMedium?.copyWith(color: outline),
        errorStyle: textTheme.bodySmall?.copyWith(color: error),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: primaryContainer, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: error, width: 2),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm)),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primaryContainer
              : Colors.transparent,
        ),
        side: const BorderSide(color: onSurfaceVariant, width: 2),
      ),

      // Chips (filtros de Estado y Especie en el listado de Animales):
      // blanco con borde sutil inactivo, verde sólido + texto blanco
      // seleccionado, forma pill — según el token `Filter Chips` de
      // DESIGN.md. El color del texto según selección se define en cada
      // pantalla (el tema solo deja la base consistente para toda la app).
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerLowest,
        selectedColor: primaryContainer,
        disabledColor: surfaceContainerHigh,
        checkmarkColor: onPrimary,
        showCheckmark: false,
        labelStyle: textTheme.labelMedium?.copyWith(color: onSurface),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: onPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: const StadiumBorder(
            side: BorderSide(color: outlineVariant, width: 1)),
        side: const BorderSide(color: outlineVariant, width: 1),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: inverseSurface,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusDefault)),
      ),

      dividerTheme:
          const DividerThemeData(color: surfaceContainerHighest, thickness: 1),

      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: primaryContainer),
    );
  }
}
