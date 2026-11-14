# Brawlers Online

Beat 'em up cooperativo (1–4 jugadores) para Android.
Flutter + Flame · Firebase (Auth anónima + Realtime Database) · compilado en la nube con Codemagic.

## Controles
- Joystick (izquierda): moverse en X e Y
- **A**: golpe (3 golpes seguidos = combo)
- **B**: salto (esquiva golpes en el aire)
- **X**: especial (golpea a todos los cercanos, cuesta 8 de vida)

## Personajes
Todos están en `lib/data/characters.dart` (RAYO, TITÁN, LUNA, CHISPA y los enemigos).
Cambia nombres, colores y estadísticas ahí. Se dibujan con formas simples;
para usar sprites propios edita `lib/game/draw.dart`.

## Puesta en marcha (todo desde el navegador)

### 1. GitHub
Crea un repositorio y sube todo el contenido de esta carpeta (rama `main`).

### 2. Firebase
1. console.firebase.google.com → Crear proyecto.
2. Añadir app **Android** con el nombre de paquete `com.tuestudio.brawlers_online`
   (si cambias `--org` en `codemagic.yaml`, usa el mismo paquete aquí).
3. Authentication → Método de acceso → activa **Anónimo**.
4. Realtime Database → Crear base de datos → pestaña **Reglas** → pega `database.rules.json`.
5. Configuración del proyecto → copia: API key, App ID, Sender ID, Project ID y la URL de la base de datos.
6. Pégalos en `codemagic.yaml` (sección `vars`).

### 3. Codemagic
1. codemagic.io → Add application → GitHub → elige tu repo → "Flutter App" con **codemagic.yaml**.
2. Start new build → workflow `android-apk`.
3. Descarga el APK desde *Artifacts* e instálalo en tu teléfono.

Si no configuras Firebase, el juego funciona igual pero solo en modo solo.

## Cómo funciona el multijugador
- El que crea la sala es el **anfitrión**: simula enemigos y oleadas y los publica 10 veces por segundo.
- Cada jugador publica su posición y estado; los demás los interpolan.
- Los golpes de los clientes viajan al anfitrión, que los aplica a los enemigos.
- Máximo 4 jugadores por sala. Se comparte el código de 5 letras.

## Antes de publicar en Google Play
- Crea un keystore y configura la firma en Codemagic (Code signing identities).
- Endurece las reglas de Firebase (ahora cualquier usuario autenticado puede escribir en las salas).
- Mantén los personajes originales (no uses marcas ni personajes con derechos de autor).
