# ScreenRec

Grabador de pantalla por área para macOS (13+). Vive en la barra de menús: dibujas
un recuadro con el ratón y graba esa zona hasta que lo detienes. Guarda en MP4
(H.264/HEVC). Además convierte vídeos a MP4 o GIF desde el clic derecho de Finder.

## Uso

| Acción | Cómo |
|---|---|
| Iniciar selección | `⌃⌥R` (configurable) o clic izquierdo en el icono de la barra |
| Dibujar el área | Arrastra con la cruceta; ESC o clic suelto cancelan |
| Grabar | Empieza al soltar el ratón; verás un recuadro de color (no sale en el vídeo) |
| Detener | `⌃⌥S` (configurable), clic izquierdo en el icono, o menú |
| Guardar | Panel de guardado, o carpeta fija según Ajustes |
| Menú / Ajustes | Clic **derecho** en el icono de la barra |

## Primer uso: permiso de Grabación de pantalla

La primera vez que intentes grabar, macOS pedirá el permiso:

1. Actívalo en **Ajustes del Sistema → Privacidad y seguridad → Grabación de
   pantalla y audio del sistema** (la alerta de ScreenRec te lleva directamente).
2. Pulsa **Relanzar ScreenRec** (macOS solo aplica el permiso al reiniciar la app).

## Convertir vídeos desde el clic derecho

ScreenRec añade dos **Acciones rápidas** al menú contextual de Finder sobre
archivos de vídeo:

- **Convertir vídeo con ScreenRec** → re-codifica a MP4 (pregunta codec y calidad).
- **Convertir a GIF con ScreenRec** → exporta a GIF con los ajustes de la pestaña GIF.

Se activan desde **Ajustes → General → «Convertir vídeos con el clic derecho» →
Instalar** (o con `make quick-actions`). Aparecen en clic derecho → **Acciones
rápidas**. Si no salen al instante, reinicia Finder (`killall Finder`).

> Nota técnica: se implementan como Acciones rápidas de Automator (que llaman al
> binario de ScreenRec), no como Servicios de la app, porque macOS no muestra los
> Servicios de apps con firma ad-hoc. Para GIF, si el tamaño estimado supera el
> límite configurable (por defecto 100 MB) avisa antes de empezar y cancela por
> defecto, para no bloquear el sistema con vídeos largos.

## Ajustes

- **General**: preguntar dónde guardar o carpeta fija; abrir ScreenRec al iniciar
  sesión; instalar/quitar las acciones de clic derecho.
- **Vídeo**: codec H.264/HEVC, calidad Alta/Media/Baja o bitrate manual (Mb/s),
  15/24/30/60 fps, resolución nativa Retina (2x) o reducida (1x), grabar o no el puntero.
- **Recuadro**: color (con opacidad) del borde visible durante la grabación.
- **GIF**: fps y escala de la conversión, y el límite de tamaño para el aviso.
- **Atajos**: ambos atajos globales, personalizables (exigen ⌃, ⌥ o ⌘).

## Compilar

Requisitos: Command Line Tools (no hace falta Xcode).

```sh
make app                     # compila y ensambla build/ScreenRec.app
make run                     # compila, cierra la instancia anterior y abre la app
make dmg                     # crea build/ScreenRec-1.0.0.dmg (arrastrar a Aplicaciones)
make pkg                     # crea build/ScreenRec-1.0.0.pkg (instalador a /Applications)
make quick-actions           # instala las Acciones rápidas de Finder
make uninstall-quick-actions # las quita
make clean
```

Notas:
- El script compila con `swiftc` directamente porque los CLT sin Xcode no traen
  el "platform path" que necesita `swift build`. El `Package.swift` se mantiene
  por si algún día se compila con Xcode/SPM completo.
- Prueba de humo del motor sin interfaz (requiere permiso de pantalla en el
  proceso que la lanza): `build/ScreenRec.app/Contents/MacOS/ScreenRec --selftest 3`

## Instalar

**Descarga la última versión** en la página de [Releases](https://github.com/nwride/ScreenRec/releases/latest):

- **DMG** (recomendado): abre `ScreenRec-1.0.0.dmg` y arrastra **ScreenRec** a **Aplicaciones**.
- **PKG**: abre `ScreenRec-1.0.0.pkg` y sigue el asistente; instala en `/Applications`.

O compílalos tú con `make dmg` / `make pkg` (quedan en `build/`).

Como la app está firmada de forma local (ad-hoc, sin Developer ID), macOS mostrará
un aviso la primera vez: ábrela con **clic derecho → Abrir**. Conviene instalar en
`/Applications` (no ejecutar desde `build/`) para que «Abrir al iniciar sesión»
apunte a una ubicación estable.

## macOS vuelve a pedir el permiso tras recompilar

Con firma ad-hoc, cada build tiene una firma distinta y macOS puede desconfiar.
Solución: crea una vez un certificado local estable y recompila:

```sh
bash scripts/make-signing-cert.sh   # pedirá tu contraseña (llavero)
make app
```

## Limitaciones (v1)

- Sin audio (previsto como mejora).
- El área de grabación no puede abarcar dos monitores a la vez (la selección se
  limita a la pantalla donde empiezas a arrastrar).
- Los ajustes se aplican a la siguiente grabación, no a la que está en curso.
