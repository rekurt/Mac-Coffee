# Mac Coffee 2.0

[English](README.md) · [Русский](README.ru.md) · [Français](README.fr.md) · [简体中文](README.zh-Hans.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

Mac Coffee ist eine schlanke, native macOS-Menüleisten-App. Sie verhindert den automatischen Ruhezustand, solange du einen Wachmodus ausdrücklich aktiviert hast.

## Funktionen

- Aus, Mac wach halten und Display wach halten.
- Sitzungen für 30 Minuten, 1, 2, 4 oder 8 Stunden sowie unbegrenzt.
- Einstellbarer Akkuschutz von 10–30%, standardmäßig 15%.
- Start bei der Anmeldung über `SMAppService`.
- Sofortiger Wechsel zwischen acht Sprachen, ohne Neustart oder Unterbrechung der laufenden Sitzung.
- Lokalisierte Einstellungen, Mitteilungen, Fehler, Info-Ansicht, Beenden-Dialoge und VoiceOver-Texte.
- Gemeinsame Beenden-Bestätigung für die Schaltfläche und `⌘Q`.
- Getrennte Direct- und App-Store-Builds; Sparkle ist nur im Direct-Build enthalten.
- Keine Administratorrechte, Hilfsprogramme, Analyse, Konten oder Server.

Mac Coffee verhindert ausschließlich den Ruhezustand bei Inaktivität. Manueller Ruhezustand, Zuklappen, Ausschalten und die Sicherheitsentscheidungen von macOS bleiben wirksam.

## Installation

```sh
brew bundle
./scripts/build-local.sh direct
open "dist/local/Mac Coffee.app"
```

Öffne das Symbol des aktuellen Modus in der Menüleiste und wähle Modus und Dauer. In den Einstellungen kannst du Sprache, Akkugrenze und den Start bei der Anmeldung ändern. Der lokale Build ist nur ad-hoc signiert und nicht zur Veröffentlichung bestimmt.

Ausführliche Build-, Test-, Datenschutz- und App-Store-Anweisungen stehen im [englischen README](README.md). Hilfe und Fehlerberichte: [GitHub Issues](https://github.com/rekurt/Mac-Coffee/issues). Lizenz: [MIT](LICENSE).
