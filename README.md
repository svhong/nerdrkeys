# NerdrKeys

A tiny macOS menu bar app that shows your [herdr](https://herdr.dev) keyboard shortcuts.

Click the glasses icon in the menu bar to open a cheat sheet of:

- **Your shortcuts**: every `[[keys.command]]` in your herdr config, with readable names for known plugin actions
- **herdr's built-in keys**: panes, tabs, workspaces and general, including any you've remapped under `[keys]`

It re-reads `~/.config/herdr/config.toml` (or `$HERDR_CONFIG_PATH`) each time it opens, so new bindings show up without rebuilding. Type in the filter box to narrow the list.

## Build and install

Needs macOS 13+ and the Swift compiler from Xcode or the Command Line Tools (`xcode-select --install`).

```bash
./build.sh
```

This compiles `main.swift`, bundles the font, installs `NerdrKeys.app` to `~/Applications` and launches it.

To see what the app parses from your config without opening the popover:

```bash
~/Applications/NerdrKeys.app/Contents/MacOS/NerdrKeys --dump
```

## Font

The app uses **Hurmit Nerd Font Light** for its text and draws its menu bar icon from glyph `U+F02AA` (`md-glasses`). The font is bundled in the app, so nothing needs to be installed. If the font can't load, the app falls back to the system font and a keyboard icon.

Hurmit Nerd Font is a patched version of Hermit by Pablo Caro, licensed under the SIL Open Font License 1.1. See [Fonts/OFL-LICENSE.txt](Fonts/OFL-LICENSE.txt).

## Roadmap

- v2: note tabs for free-typed text, saved as plain files
