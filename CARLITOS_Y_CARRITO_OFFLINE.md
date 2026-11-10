# Carrito y Carlitos offline

## Instalar la actualización

Actualizar la app existente sin desinstalar ni borrar sus datos. SQLite se actualiza automáticamente de versión 1 a 2, conserva los pendientes y puede leer catálogos antiguos mayores que el límite CursorWindow de Android. Los catálogos nuevos se almacenan en bloques de 128 KiB. También se leen en bloques los comprobantes pendientes con imágenes grandes.

## Probar compra pendiente

1. Con Internet, iniciar sesión, elegir empresa/sucursal y abrir catálogo y wallet para descargar datos y saldo.
2. Desconectar Internet. Agregar una variante al carrito, elegir wallet y confirmar.
3. El saldo disponible local disminuye por el importe reservado. La compra muestra pendiente de sincronización; todavía no es un cobro confirmado por el servidor.
4. Cerrar y abrir la app: se conservan compra y saldo reservado.
5. Recuperar Internet y sincronizar: el servidor valida saldo, stock y precio; confirma una única operación o muestra un conflicto. PayPal y las recargas requieren conexión.

## Carlitos

Sin descargar modelo: búsqueda por color, prenda, talla y presupuesto sobre catálogo guardado y respuestas frecuentes de wallet, puntos, cambios, venta por mayor y delivery.

Modelo opcional: abrir Carlitos → Carlitos sin Internet → Descargar / reanudar · 409 MiB. Usa Qwen2.5 0.5B Instruct Q4_0, ejecutado localmente con llamadart y CPU. Permite pausar/reanudar y eliminar. La descarga se verifica por tamaño y SHA-256 antes de activarla. No se guarda historial de conversación ni se ejecutan compras mediante el modelo. El modelo puede equivocarse; no es fuente de precios, stock ni comprobantes. Consume RAM adicional y su velocidad depende del dispositivo.

Fuente: https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF
Revisión fijada: 9217f5db79a29953eb74d5343926648285ec7e67
Archivo: qwen2.5-0.5b-instruct-q4_0.gguf
Bytes: 428730208 (~409 MiB)
SHA-256: 7671c0c304e6ce5a7fc577bcb12aba01e2c155cc2efd29b2213c95b18edaf6ed
Licencia del modelo: Apache 2.0; copia en C:/Users/Felipe/Proyectos/CarlitosOffline/LICENSE-MODELO.txt.

Copia descargada en PC y demostración por consola: C:/Users/Felipe/Proyectos/CarlitosOffline. No se incluye el modelo dentro del APK. El celular debe descargar su propia copia con el botón de Carlitos. La descarga del modelo no requiere cambios ni secretos en Railway.
