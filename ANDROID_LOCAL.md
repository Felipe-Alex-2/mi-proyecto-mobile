# Android: ejecución y diagnóstico

Abre `mobile` como proyecto Flutter en Android Studio, con entrada `lib/main.dart` y un dispositivo Android seleccionado. Requiere Android 7.0 (API 24) o superior.

## Emulador

Desde PowerShell en la carpeta `mobile`:

```powershell
flutter pub get
flutter emulators --launch Pixel_7
flutter devices
flutter run -d emulator-5554
```

Usa el identificador de `flutter devices` si es distinto. El backend local debe estar iniciado en el puerto 8000. El emulador utiliza `10.0.2.2` para acceder al equipo.

## Celular físico

Con depuración USB activada y el equipo autorizado:

```powershell
adb -s ID_DEL_CELULAR reverse tcp:8000 tcp:8000
flutter run -d ID_DEL_CELULAR --dart-define=API_URL=http://127.0.0.1:8000/api/v1
```

Por Wi-Fi, inicia el backend con `--host 0.0.0.0` y usa la IP local del equipo. Ambos dispositivos deben estar en la misma red, con el backend permitido por el firewall:

```powershell
flutter build apk --release --dart-define=API_URL=http://IP_DEL_EQUIPO:8000/api/v1
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`. La configuración release actual utiliza la firma debug para pruebas. `10.0.2.2` es exclusivo del emulador, no del celular.

## Si Android rechaza la instalación

Obtén el motivo exacto mediante USB:

```powershell
adb -s ID_DEL_CELULAR install -r build/app/outputs/flutter-apk/app-release.apk
```

- `INSTALL_FAILED_UPDATE_INCOMPATIBLE`: firma distinta de la app instalada. Conserva los cambios offline pendientes antes de considerar desinstalarla.
- `INSTALL_FAILED_INSUFFICIENT_STORAGE`: falta de espacio.
- `INSTALL_FAILED_OLDER_SDK`: versión de Android inferior a la requerida.

Transfiere el APK completo, no el archivo `.sha1`.

## Pruebas

```powershell
flutter analyze
flutter test
flutter test integration_test/android_startup_test.dart -d emulator-5554
```

La prueba de integración verifica SQLite nativo, WAL, persistencia y el arranque hasta el login. SQLite FFI en escritorio no reproduce todas las restricciones de Android.

La versión 1.0.1 corrige el bloqueo antes del primer frame: Android exige ejecutar `PRAGMA busy_timeout` mediante `rawQuery`, porque devuelve filas; usar `execute` provocaba una excepción antes de mostrar la app.

## Perfil y asistente offline (1.0.2)

Los cambios del perfil permanecen en SQLite y se proyectan inmediatamente en la pantalla. Al recuperar conexión, la cola existente se sincroniza en primer plano mediante conectividad, reanudación y reintentos periódicos; en segundo plano Android decide cuándo ejecutar WorkManager. Los errores de validación del servidor quedan visibles en la cola para corregirlos.

La versión 1.0.2 corrige los mapas de las proyecciones offline: deben conservar claves `String` para que los modelos del perfil, medidas, notificaciones y reservas puedan leerlos. Los cambios que ya estaban pendientes no se borran.

Carlitos utiliza la API cuando hay conexión. Offline, o ante un fallo de conexión/servidor, ofrece una búsqueda local por prenda, color, talla y presupuesto sobre el catálogo SQLite de la cuenta activa. Reconoce saludos, explica sus límites y no genera productos inexistentes. Requiere haber guardado el catálogo previamente; stock y precios corresponden a esa copia.

Este modo local es un buscador de reglas, no un modelo de lenguaje generativo instalado en el celular. Las consultas locales no se encolan ni se envían después. Los errores de autenticación requieren iniciar sesión y no se ocultan como respuestas locales.

```powershell
flutter test integration_test/offline_profile_test.dart -d emulator-5554
```

Ejecuta las pruebas antes de generar el APK, de forma secuencial: Flutter regenera los archivos de registro de plugins para cada modo, por lo que una prueba y una compilación release simultáneas pueden interferir.

## Confirmaciones de guardado (1.0.3)

Perfil, medidas, carrito y reservas distinguen entre confirmación del servidor y cambios pendientes. Un cambio confirmado muestra un aviso verde; un cambio local muestra un aviso ámbar con «pendiente de sincronizar». Se utiliza el resultado de esa operación, no la conectividad ni el número global de pendientes. Una reserva pendiente no se presenta como confirmada ni con instrucciones de recogida. Los errores conservan su mensaje de error.
