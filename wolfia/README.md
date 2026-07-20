<<<<<<< HEAD
# Wolfia

Asistente personal de estudio de piano. Versión simplificada del documento
"Piano Studio SDD" pensada para **uso personal**, con **recursos 100%
gratuitos** y sin backend.

## Qué se simplificó respecto al documento original

El documento describe una arquitectura para escalar a miles de usuarios
(NestJS, PostgreSQL, Redis, S3, motor de sincronización, event sourcing,
CQRS, autenticación OAuth, etc). Para un solo pianista usando su propio
teléfono, nada de eso hace falta. Wolfia se queda con:

- **Flutter**, un solo código para Android e iOS. Gratis, open source.
- **SQLite local** (`sqflite`), todo vive en el teléfono, sin servidor.
- **Sin login, sin nube, sin sincronización.** Si más adelante querés
  respaldar los datos, alcanza con copiar el archivo `wolfia.db` a Google
  Drive manualmente, o (más adelante) agregar Supabase free tier si
  necesitás multi-dispositivo.

Se conserva la idea central del documento: la **sesión de estudio** es el
centro del sistema, las obras/ejercicios se organizan como
**Preparaciones** con **Segmentos** y **Objetivos**, y el **generador de
sesiones** prioriza automáticamente qué estudiar según hace cuánto no se
practica algo y cuántos objetivos quedan pendientes.

## Requisitos (todos gratuitos)

1. **Flutter SDK**: https://docs.flutter.dev/get-started/install (gratis)
2. **Android Studio** (para el emulador y el SDK de Android) o simplemente
   un teléfono Android con "depuración USB" activada — no hace falta
   Android Studio si probás en un dispositivo físico.
3. Para iOS necesitás una Mac con Xcode (gratis, pero requiere macOS).

## Cómo correrlo

```bash
cd wolfia
flutter pub get
flutter run
```

Esto instala la app en un emulador o en tu teléfono conectado por USB.

## Cómo generar un instalable (APK) para tu propio teléfono

No hace falta subirlo a ninguna tienda ni pagar la cuenta de desarrollador
de Google ($25 única vez) si solo la vas a usar vos:

```bash
flutter build apk --release
```

El archivo queda en:
`build/app/outputs/flutter-apk/app-release.apk`

Pasalo a tu teléfono (por cable, WhatsApp, Drive, lo que sea) y instalalo
directamente (vas a tener que habilitar "instalar apps de orígenes
desconocidos" la primera vez).

## Estructura del proyecto

```
lib/
  main.dart                    # navegación principal (bottom nav)
  theme.dart                   # colores y tipografía (paleta del SDD original)
  db/database.dart             # toda la persistencia local (SQLite)
  models/models.dart           # Elemento, Preparación, Segmento, Objetivo, Sesión, Tarea, Nota
  services/session_generator.dart  # algoritmo que arma la sesión del día
  screens/
    dashboard_screen.dart      # Inicio: "¿qué debo estudiar hoy?"
    repertorio_screen.dart     # Obras/ejercicios y sus preparaciones
    preparacion_screen.dart    # Detalle: segmentos y objetivos
    sesion_screen.dart         # Modo estudio con temporizador
    diario_screen.dart         # Historial de sesiones + notas
```

## Cómo sigue creciendo esto (si querés, y siempre gratis)

Ideas del documento original que podés ir sumando sin romper nada de lo
ya hecho, en orden de "vale la pena para uso personal":

1. **Banco de conocimiento**: una pantalla más para guardar ideas
   reutilizables ("la rotación del antebrazo elimina la tensión en
   octavas"), con una tabla `conocimiento` igual de simple que las demás.
2. **Backup manual**: un botón que copie `wolfia.db` a la carpeta de
   Descargas usando `path_provider`, para subirlo vos mismo a Drive.
3. **Notificaciones locales** (`flutter_local_notifications`, gratis):
   recordatorio diario para practicar.
4. **Grabaciones de audio** (`record` + reproducirlas con `just_audio`,
   ambos gratis) asociadas a una tarea o segmento.
5. **Sincronización multi-dispositivo real** solo si алgún día usás más
   de un teléfono: ahí sí conviene Supabase (tiene free tier generoso:
   Postgres + Auth + Storage gratis hasta cierto uso) en vez de armar tu
   propio backend NestJS.

Todo lo que NO se incluyó a propósito (event sourcing, CQRS, múltiples
profesores/alumnos, IA, sincronización entre dispositivos) es exactamente
la parte del documento pensada para una app comercial escalable, no para
uso personal.
=======
# wolfia
Asistente personal de estudio de piano.  Pensada para uso personal, con recursos 100% gratuitos y sin backend.
>>>>>>> 9e5cb259460e2b49d8a942a8fc56fde5e7c296f4
