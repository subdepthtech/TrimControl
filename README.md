# TrimControl

Native macOS app for opening text-based files in Neovim through a configurable terminal backend.

TrimControl replaces the old AppleScript applet at `/Applications/OpenWithNeovim.app` with a real Swift/AppKit/SwiftUI app bundle:

- Bundle ID: `com.subdepthtech.trimcontrol`
- Built app: `dist/TrimControl.app`
- Installed app: `/Applications/TrimControl.app`
- Default terminal backend: Apple Terminal.app
- Default Neovim executable: `/opt/homebrew/bin/nvim`
- App icon source: `Assets/TrimControlIcon.png`

Finder open-file events route through the selected terminal backend stored in `UserDefaults`. Direct terminal backends use `Process` argument arrays:

TrimControl runs as a background menu-bar utility. Opening a claimed file from Finder routes that file to the selected backend without showing the TrimControl configuration window. Opening TrimControl directly, reopening it, or choosing **Open Settings** from the menu-bar extra brings the configuration window forward.

```sh
Ghostty:   /Applications/Ghostty.app/Contents/MacOS/ghostty -e <nvim> -- <files>
WezTerm:   /Applications/WezTerm.app/Contents/MacOS/wezterm start -- <nvim> -- <files>
Alacritty: /Applications/Alacritty.app/Contents/MacOS/alacritty -e <nvim> -- <files>
```

Terminal.app and iTerm2 are available as built-in choices and use AppleScript because those apps do not expose the same direct executable argument contract. macOS may prompt for Automation permission the first time TrimControl asks Terminal.app or iTerm2 to run Neovim.

Trident is not required. Users who want it can enable it from **Advanced: Custom Command** with the Trident preset:

```text
Name: Trident
Executable: /usr/bin/open
Arguments:
-n
-b
com.subdepthtech.trident
--args
-e
/opt/homebrew/bin/nvim
--
{files}
```

The Custom Command backend expands `{nvim}` and `{files}` as argument-array placeholders without shell interpolation. `{files}` is replaced by one or many selected file paths; when `{files}` is omitted, selected file paths are appended.

## Interface

The configuration window is a native SwiftUI macOS utility surface with grouped sidebar navigation, a dense file-type workspace, a separate Default Openers workspace, and operational tools/settings destinations. `ContentView` delegates to `TrimControlWindow`, which routes between:

- **File Types**: Markdown, Text, and Source modes with search, custom extension entry, import/export presets, row status chips, and the apply/remove/verify/open-test action bar.
- **Default Openers**: external app routing for companion files such as PDFs, images, videos, archives, office documents, web files, and optional code-file overrides.
- **Tools**: Verify Samples and Presets destinations for focused operational actions.
- **Settings**: General terminal backend setup and Advanced Custom Command utilities.

Reusable UI pieces live in `Sources/TrimControl/Views/TrimControlDesignSystem.swift`, `FileTypeComponents.swift`, `DefaultOpenersView.swift`, `TerminalBackendSurface.swift`, `WorkspaceUtilityViews.swift`, and `TrimControlCommands.swift`. Keep new UI work on these tokens and components instead of adding one-off colors, spacing, or button styles.

Supported keyboard paths include Command-A for selecting all rows in the active file-type mode, Escape for clearing that mode, arrow-key row focus, Return or Space for toggling the focused row, Command-R for refresh, Command-Shift-V for Verify Samples, and Command-Return for Open Test File.

Default Openers are stored separately from File Types selections. They control native external routing for files that should not go through Neovim by default, while Markdown/Text/Source defaults remain controlled by the File Types workflow. When a custom app is selected, TrimControl applies the matching macOS content-type defaults so Finder opens that category with the chosen app. Resetting a custom opener restores the previous handler when one was recorded. Overlapping code or web extensions stay on the Neovim path unless the user explicitly chooses a custom external opener for that category.

## Terminal Backend Setup

Open TrimControl and use the **Terminal Backend** section to choose one of:

- Apple Terminal.app
- iTerm2
- Ghostty
- WezTerm
- Alacritty
- Custom Command

Use **Choose Neovim...** if Neovim lives somewhere other than `/opt/homebrew/bin/nvim`. Use **Open test file** to create a temporary JSON file and open it through the selected backend before applying Finder defaults.

Ghostty, WezTerm, and Alacritty are launched through their app-bundle executables when present under `/Applications`. If a selected terminal app or Neovim is missing, TrimControl reports that in the status area instead of silently falling back to Trident.

Custom Command is the advanced escape hatch for local workflows. The Trident preset lives there as an optional shortcut, but it is not one of the main built-in terminal choices and is not required by TrimControl.

## File Groups

TrimControl v1 organizes file types into three tabs in its settings window. Use **Apply all defaults** for the normal setup path; Finder's manual **Change All** flow will ask for confirmation per extension. Use the per-file-type toggles when you only want TrimControl to claim a narrower set. Each tab also has an **Add extension** field for custom extensions; custom entries are saved in app preferences and included in Apply selected/all. Use **Import preset** and **Export preset** to move the current selected file types and custom extensions through a local JSON file.

- Markdown and vault companions: `.md`, `.markdown`, `.mdown`, `.mkd`, `.mkdn`, `.mdx`, `.qmd`, `.rmd`, `.prompt`, `.plan`, `.todo`, `.prd`, `.runbook`, `.sop`, `.spec`, `.dashboard`
- Text/config/data: `.txt`, `.text`, `.log`, `.json`, `.jsonl`, `.jsonc`, `.yaml`, `.yml`, `.toml`, `.xml`, `.plist`, `.csv`, `.tsv`, `.ndjson`, `.json5`, `.hjson`, `.cson`, `.jsonlines`, `.ldjson`, `.env`, `.envrc`, `.dotenv`, `.env.example`, `.env.local`, `.env.production`, `.env.development`, `.env.test`, `.conf`, `.cfg`, `.config`, `.ini`, `.properties`, `.editorconfig`, `.gitignore`, `.gitattributes`, `.gitmodules`, `.gitconfig`, `.gitkeep`, `.dockerignore`, `.npmignore`, `.prettierignore`, `.eslintignore`, `.stylelintignore`, `.markdownlintignore`, `.ignore`, `.hgignore`, `.npmrc`, `.yarnrc`, `.prettierrc`, `.eslintrc`, `.babelrc`, `.browserslistrc`, `.commitlintrc`, `.stylelintrc`, `.yamllint`, `.markdownlint`, `.sqlfluff`, `.graphqlrc`, `.tool-versions`, `.nvmrc`, `.node-version`, `.ruby-version`, `.python-version`, `.lock`, `.ron`, `.edn`, `.base`, `.canvas`
- Scripts/source: `.sh`, `.zsh`, `.bash`, `.fish`, `.ps1`, `.py`, `.rb`, `.pl`, `.php`, `.js`, `.jsx`, `.mjs`, `.cjs`, `.tsx`, `.cts`, `.css`, `.scss`, `.sass`, `.html`, `.htm`, `.lua`, `.vim`, `.swift`, `.go`, `.rs`, `.zig`, `.c`, `.h`, `.cpp`, `.hpp`, `.cc`, `.cxx`, `.hh`, `.hxx`, `.ipp`, `.m`, `.mm`, `.java`, `.kt`, `.kts`, `.cs`, `.fs`, `.dart`, `.scala`, `.clj`, `.cljs`, `.cljc`, `.ex`, `.exs`, `.erl`, `.hrl`, `.hs`, `.jl`, `.r`, `.R`, `.sql`, `.vue`, `.svelte`, `.astro`, `.graphql`, `.gql`, `.proto`, `.tf`, `.tfvars`, `.hcl`, `.nix`, `.nu`, `.just`, `.make`, `.mk`, `.applescript`, `.bats`, `.awk`, `.sed`, `.groovy`, `.gradle`, `.qml`, `.cmake`, `.cmake.in`, `.bzl`, `.bazel`, `.star`, `.cue`, `.dhall`, `.elm`, `.gleam`, `.ml`, `.mli`, `.nim`, `.vala`, `.vapi`, `.wat`, `.pug`, `.haml`, `.slim`, `.erb`, `.ejs`, `.hbs`, `.handlebars`, `.liquid`, `.mustache`

`.ts`, `.mts`, and `.d.ts` are intentionally excluded because macOS treats `.ts` and `.mts` as MPEG transport stream formats, and `.d.ts` still collides with the `.ts` extension path.

## Build

```sh
swift build
script/build_app.sh
codesign --verify --deep --strict dist/TrimControl.app
script/verify_defaults.sh --app dist/TrimControl.app
```

`script/build_app.sh` builds the SwiftPM products, assembles `dist/TrimControl.app`, generates `TrimControl.icns` from `Assets/TrimControlIcon.png`, generates the bundle plist from the app-owned file-type catalog, and signs the result. Set `TRIMCONTROL_SIGN_IDENTITY` to a Developer ID identity for distribution signing, or leave it unset for ad-hoc local signing.

`script/verify_defaults.sh --app dist/TrimControl.app` verifies the bundle contract without requiring current LaunchServices defaults to point at the uninstalled app.

## Install

```sh
script/install_app.sh
script/verify_defaults.sh
osascript -e 'id of app "TrimControl"'
```

Expected bundle ID:

```text
com.subdepthtech.trimcontrol
```

The installer:

- Builds and verifies `dist/TrimControl.app`.
- Backs up `/Applications/OpenWithNeovim.app` to a timestamped sibling path before changing apps or defaults.
- Installs `/Applications/TrimControl.app`.
- Ad-hoc signs and registers the installed app.
- Applies all v1 file-group defaults to `com.subdepthtech.trimcontrol`.
- Verifies representative extensions resolve to `/Applications/TrimControl.app`.

## Rollback

The installer does not delete `/Applications/OpenWithNeovim.app`. To return defaults to the old wrapper from the app UI, use **Remove selected defaults** while the old wrapper is still installed. The current implementation restores selected types to `com.subdepthtech.openwithneovim` because LaunchServices does not provide a safe public "delete this default" API for content-type handlers.

You can also re-run the old wrapper registration manually:

```sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/OpenWithNeovim.app
```
