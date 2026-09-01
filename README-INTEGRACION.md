# Cómo integrar esto en tu repo (fincas-patitas-movil-app)

Esta carpeta trae solo el código Dart (`lib/`) y el `pubspec.yaml` — no
trae las carpetas `android/`, `ios/`, etc. porque esas las genera el
propio Flutter según tu máquina, y este entorno no tiene el SDK de
Flutter instalado para generarlas por ti.

## Pasos

1. Clona tu repo vacío (si no lo has hecho):
   ```
   git clone https://github.com/Danyppp/fincas-patitas-movil-app.git
   cd fincas-patitas-movil-app
   ```

2. Genera el proyecto base de Flutter ahí mismo:
   ```
   flutter create .
   ```
   Esto crea `android/`, `ios/`, `pubspec.yaml`, `lib/main.dart`, etc.

3. Reemplaza el `pubspec.yaml` generado por el de esta carpeta, y copia
   toda la carpeta `lib/` (reemplaza el `lib/main.dart` de ejemplo).

4. Instala las dependencias:
   ```
   flutter pub get
   ```

5. Corre la app:
   ```
   flutter run
   ```
   Deberías ver la barra de navegación con 4 pestañas y, en "Animales",
   una lista con 3 animales de referencia (Lola, Toro Bravo, Pecas) —
   son datos de ejemplo, no vienen de ninguna base de datos todavía.

6. Cuando quieras, haz commit y push a tu repo normalmente.

## Qué hay en `lib/`

- `models/` — clases de dominio (`Animal`, `Species`, `Breed`, `Sexo`),
  traducidas 1:1 desde `src/types/domain/animal.schema.ts` del proyecto
  web (solo se leyó ese repo como referencia, no se tocó).
- `repositories/` — contrato `AnimalRepository` + dos implementaciones:
  `MockAnimalRepository` (datos de referencia, la que está activa ahora)
  y `ApiAnimalRepository` (ya escrita, apuntando a los endpoints que
  Milena todavía tiene que confirmar — desactivada hasta entonces).
- `screens/` — `HomeShell` (navegación con 4 pestañas), el módulo de
  Animales completo (lista + detalle) y una pantalla "próximamente" para
  los otros tres módulos.
- `widgets/` — `AnimalCard`, reutilizable y sin lógica de negocio.
- `config/app_config.dart` — el único interruptor para pasar de datos de
  referencia a la API real cuando esté lista.

## Siguiente paso natural

Cuando Milena tenga el primer endpoint de animales funcionando y te
pase la URL real, solo hay que: 1) poner esa URL en `app_config.dart`,
2) poner `useRealApi = true`, 3) ajustar `ApiAnimalRepository` si el
JSON que devuelve el backend no calza exacto con lo que espera
`Animal.fromJson`. Ninguna pantalla cambia.
