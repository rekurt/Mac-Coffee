# Mac Coffee 2.0

[English](README.md) · [Русский](README.ru.md) · [Deutsch](README.de.md) · [Français](README.fr.md) · [简体中文](README.zh-Hans.md) · [日本語](README.ja.md) · [한국어](README.ko.md)

Mac Coffee es una app nativa y ligera para la barra de menús de macOS. Solo evita el reposo automático por inactividad mientras hayas activado explícitamente un modo.

## Funciones

- Modos Desactivado, Mantener el Mac activo y Mantener activa la pantalla.
- Sesiones de 30 minutos, 1, 2, 4 u 8 horas, o sin límite.
- Protección de batería ajustable del 10% al 30%, con 15% de forma predeterminada.
- Inicio de sesión mediante `SMAppService`.
- Cambio instantáneo entre ocho idiomas sin reiniciar la app ni interrumpir la sesión activa.
- Ajustes, notificaciones, errores, información, confirmación de salida y textos de VoiceOver localizados.
- La salida del pie y `⌘Q` comparten la misma confirmación.
- Versiones Direct y App Store separadas; Sparkle solo existe en Direct.
- Sin privilegios de administrador, asistente, cuenta, análisis ni servidor.

Mac Coffee solo evita el reposo por inactividad. El reposo manual, cerrar la tapa, apagar el equipo y las protecciones de macOS siempre siguen vigentes.

## Instalación

```sh
brew bundle
./scripts/build-local.sh direct
open "dist/local/Mac Coffee.app"
```

Abre el icono del modo actual en la barra de menús y elige el modo y la duración. En Ajustes puedes cambiar el idioma, el límite de batería y el inicio de sesión. La compilación local tiene firma ad hoc y no debe distribuirse como versión oficial.

Las instrucciones completas de compilación, pruebas, privacidad y App Store están en el [README en inglés](README.md). Ayuda y errores: [GitHub Issues](https://github.com/rekurt/Mac-Coffee/issues). Licencia: [MIT](LICENSE).
