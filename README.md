# Arreglo para Recordly: la exportación se traba y las pantallas se apagan

Si usás [Recordly](https://github.com/webadderallorg/Recordly) en Windows y al exportar un video:

- las pantallas se apagan un segundo y vuelven,
- la exportación se queda clavada en un porcentaje bajo (1 %, 24 %…) o tarda una eternidad,
- aparece un error que dice `createBuffer failed` o menciona `webgpu`,
- o después queda el fondo de pantalla negro,

este arreglo es para vos. Pasa sobre todo con **gráficos integrados** (por ejemplo los Ryzen con Radeon Graphics),
pero puede pasar con otras placas.

## Qué pasa, en simple

Para exportar, Recordly dibuja cada cuadro del video usando la placa de video. Hay dos formas de pedirle a la placa
que dibuje: una vieja y muy probada (**WebGL**) y una nueva (**WebGPU**). Recordly usa siempre la nueva si está
disponible, y algunas placas se **congelan** con ella.

Cuando la placa se congela, Windows la reinicia en un par de segundos para que la PC no se cuelgue entera. Ese
reinicio es el que apaga las pantallas. Recordly no se entera y se queda esperando un cuadro que nunca llega: por
eso la exportación queda trabada.

El arreglo hace que Recordly use la forma vieja. Con eso exporta bien y, en las pruebas, hasta más rápido.

## Cómo se usa

1. Descargá el `.zip` de la sección [Releases](../../releases) y descomprimilo.
2. **Cerrá Recordly** (también desde el ícono junto al reloj, si está ahí). Guardá tu proyecto antes.
3. Hacé doble clic en `arreglar-recordly.bat` y elegí una opción:
   - **1**: arreglar la exportación.
   - **2**: arreglar la exportación y, además, que "Original" exporte a **1080p** cuando tu pantalla es más chica
     (por ejemplo 1366×768). Opcional.
   - **3**: deshacer y dejar Recordly como vino.
4. Abrí Recordly y exportá como siempre.

Si Windows muestra "Windows protegió su PC", tocá **Más información → Ejecutar de todas formas**. Aparece porque el
archivo no tiene firma digital. Si dice que no puede escribir en la carpeta, clic derecho en el `.bat` →
**Ejecutar como administrador**.

**Cuando Recordly se actualiza, el arreglo se pierde.** Si el problema vuelve, corrélo de nuevo.

## Qué cambia exactamente

Todo el código está en [`arreglar-recordly.ps1`](arreglar-recordly.ps1). Se puede leer antes de usarlo.

- Solo toca un archivo: `resources\app.asar`, dentro de la carpeta de Recordly. Antes guarda una copia del original
  al lado (`app.asar.original-<versión>`). La opción 3 la vuelve a poner.
- Cambia dos textos de ese archivo por otros del mismo largo, así el resto queda idéntico:
  1. Agrega una línea que desactiva WebGPU (`delete Navigator.prototype.gpu`). Sin WebGPU, Recordly usa WebGL.
  2. Solo con la opción 2: cambia el cálculo del tamaño "Original" para que llegue a 1080p.
- No descarga nada, no instala nada y no toca nada fuera de la carpeta de Recordly.
- Si tu versión de Recordly es distinta y no encuentra dónde aplicar el cambio, avisa y no modifica nada.

Probado con Recordly 1.4.0 en Windows 11, con un AMD Ryzen 7 5700G (gráficos integrados).

## ¿Cómo sé si es mi caso?

Si te pasa lo de arriba, casi seguro sí. Para confirmarlo: abrí el **Visor de eventos** → Registros de Windows →
Aplicación y buscá eventos de "Windows Error Reporting" que digan `LiveKernelEvent` con `P1: 141` a la hora en que
exportabas. Ese código significa que Windows tuvo que reiniciar la placa de video.

## English

Recordly renders exports with WebGPU whenever it is available, and forces it with `--enable-unsafe-webgpu`. On some
GPUs (notably AMD integrated graphics) WebGPU on Direct3D 12 hangs the GPU (`DXGI_ERROR_DEVICE_HUNG`), Windows
resets the display driver (screens flash black, `LiveKernelEvent 141`) and the export stalls or fails with
`createBuffer failed`. This script removes `navigator.gpu` from Recordly's pages so it falls back to WebGL, by
replacing two strings in `resources\app.asar` with same-length strings (a backup is kept; option 3 restores it).
Close Recordly, run `arreglar-recordly.bat`, choose 1 (fix) or 2 (fix + export "Original" at 1080p). Re-run after
Recordly updates.

## Licencia

MIT. Este proyecto no está hecho ni respaldado por los autores de Recordly.
