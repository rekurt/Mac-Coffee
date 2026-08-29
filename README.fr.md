# Mac Coffee 2.0

[English](README.md) · [Русский](README.ru.md) · [Deutsch](README.de.md) · [简体中文](README.zh-Hans.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md)

Mac Coffee est une app macOS native et légère pour la barre des menus. Elle empêche la veille automatique tant que vous avez explicitement activé un mode d’éveil.

## Fonctionnalités

- Modes Désactivé, Garder le Mac éveillé et Garder l’écran éveillé.
- Sessions de 30 minutes, 1, 2, 4 ou 8 heures, ou sans limite.
- Protection de la batterie réglable de 10 à 30%, à 15% par défaut.
- Ouverture à la connexion avec `SMAppService`.
- Changement instantané entre huit langues sans relancer l’app ni interrompre la session active.
- Réglages, notifications, erreurs, À propos, confirmation de sortie et textes VoiceOver localisés.
- Même confirmation pour le bouton Quitter et `⌘Q`.
- Builds Direct et App Store séparés ; Sparkle est réservé au build Direct.
- Aucun privilège administrateur, assistant, compte, suivi ou serveur.

Mac Coffee empêche uniquement la veille due à l’inactivité. La mise en veille manuelle, la fermeture du capot, l’arrêt et les protections de macOS restent effectifs.

## Installation

```sh
brew bundle
./scripts/build-local.sh direct
open "dist/local/Mac Coffee.app"
```

Ouvrez l’icône du mode actuel dans la barre des menus, puis choisissez un mode et une durée. Les Réglages permettent de modifier la langue, le seuil de batterie et l’ouverture à la connexion. Le build local est signé ad hoc et ne doit pas être distribué.

Les instructions complètes de build, test, confidentialité et App Store figurent dans le [README anglais](README.md). Aide et bugs : [GitHub Issues](https://github.com/rekurt/Mac-Coffee/issues). Licence : [MIT](LICENSE).
